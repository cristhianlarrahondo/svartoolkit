function PosteriorParams = build_posterior(Dataset, Cfg)
%BUILD_POSTERIOR  Construye Y, X, B, U y parametros posterior NIW.
%
%   PosteriorParams = BUILD_POSTERIOR(Dataset, Cfg)
%
%   Replica exactamente la logica de calculo de run_mainfile.m del original:
%     - Aplica Cfg.SCALE_FACTOR a los datos crudos
%     - Arma Y y X en notacion Rubio-Waggoner-Zha (RES 2010)
%     - Calcula OLS: B, U
%     - Prior configurable via Cfg.PRIOR.type (default: 'diffuse')
%     - Calcula parametros posterior NIW
%
%   Cfg.PRIOR.type admite:
%     'diffuse'           — NIW impropio (paper original, default)
%     'minnesota'         — Shrinkage hacia RW (lambda1, lambda2, lambda3)
%     'sims_zha'          — Dummy observations (mu5, mu6); ver nota de transformaciones
%     'niw_custom'        — NIW informativo con parametros explicitos
%     'natural_conjugate' — Minnesota en forma NIW estricta (Kadiyala & Karlsson 1997)
%
%   Referencias:
%     Koop & Korobilis (2010) Bayesian Multivariate Time Series Methods
%     Kadiyala & Karlsson (1997) Journal of Forecasting
%     Sims & Zha (1998) Review of Economics and Statistics
%     Litterman (1986) Journal of Business & Economic Statistics

%% ── Parametros del modelo ────────────────────────────────────────────────
p   = Cfg.NLAG;
nex = Cfg.NEX;
n   = Dataset.nvar;
m   = n*p + nex;

%% ── Datos escalados ─────────────────────────────────────────────────────
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
num = Dataset.Y_raw(:, endo_mask) * Cfg.SCALE_FACTOR;

%% ── Construir Y y X (notacion RWZ 2010) ─────────────────────────────────
yt = num(p+1:end, :);
T  = size(yt, 1);
xt = zeros(T, n*p + nex);
for i = 1:p
    xt(:, n*(i-1)+1:n*i) = num((p-(i-1)):end-i, :);
end
if nex >= 1
    xt(:, n*p + nex) = ones(T, 1);
end
Y = yt;
X = xt;

%% ── Estimacion OLS ───────────────────────────────────────────────────────
B      = (X'*X) \ (X'*Y);
U      = Y - X*B;
Sigmau = U'*U / T;
ssigma = sqrt(diag(Sigmau));
sig2   = diag(Sigmau);       % varianzas OLS — referencia de escala para priors

%% ── Determinar tipo de prior ─────────────────────────────────────────────
if isfield(Cfg, 'PRIOR') && isfield(Cfg.PRIOR, 'type')
    prior_type = lower(strtrim(Cfg.PRIOR.type));
else
    prior_type = 'diffuse';
end

%% ── Construir matrices del prior segun tipo ──────────────────────────────
switch prior_type

    % ── Prior 0: Difuso ───────────────────────────────────────────────────
    % NIW impropio: Omega_bar^{-1}=0, nu_bar=0, Phi_bar=0, Psi_bar=0.
    % Replica exactamente el original de Arias, Rubio-Ramirez y Waggoner (2018).
    case 'diffuse'
        nnuBar           = 0;
        OomegaBarInverse = zeros(m);
        PpsiBar          = zeros(m, n);
        PphiBar          = zeros(n);
        Y_aug = Y;  X_aug = X;  T_eff = T;

    % ── Prior 1: Minnesota ────────────────────────────────────────────────
    % Shrinkage hacia random walk. Ref: Litterman (1986), Koop & Korobilis (2010).
    %
    % Omega_bar [m x m] diagonal. Elemento para (lag l, variable j):
    %   Omega_bar_{l,j} = (lambda1 / l^lambda3)^2 * sigma_j^2 * w_j
    % donde w_j mezcla la varianza own y cross ponderada por lambda2:
    %   w_j = [1 + (n-1)*lambda2^2] / n
    %   (lambda2=1 => sin distincion; lambda2=0 => solo own)
    %
    % Omega_bar^{-1}_{l,j} = 1 / Omega_bar_{l,j}
    %
    % Psi_bar: prior RW en lag 1 (diagonal = 1), resto = 0.
    % Phi_bar = 0, nu_bar = 0 (prior impropia sobre Sigma).
    case 'minnesota'
        pr = Cfg.PRIOR;
        check_required_fields(pr, {'lambda1','lambda2','lambda3'}, 'minnesota');
        lambda1 = pr.lambda1;
        lambda2 = pr.lambda2;
        lambda3 = pr.lambda3;

        % Factor de mezcla own/cross para Omega_bar [m x m]
        % w_j = (1 + (n-1)*lambda2^2) / n
        %   -> lambda2=1: w=1 (sin distincion propia/cruzada)
        %   -> lambda2=0: w=1/n (maximo shrinkage cruzado)
        %   -> lambda2=0.5, n=5: w = (1+4*0.25)/5 = 0.4
        w = (1 + (n-1)*lambda2^2) / n;

        omega_bar_diag = zeros(m, 1);
        for l = 1:p
            for j = 1:n
                idx = (l-1)*n + j;
                % Varianza prior: sigma_j^2 EN EL NUMERADOR (escala correcta)
                omega_bar_diag(idx) = (lambda1 / l^lambda3)^2 * sig2(j) * w;
            end
        end
        % Constante: prior muy vaga (varianza grande => precision ~ 0)
        if nex >= 1
            omega_bar_diag(m) = 1e6;
        end

        % Omega_bar^{-1} = 1 ./ Omega_bar (diagonal)
        OomegaBarInverse = diag(1 ./ omega_bar_diag);

        % Psi_bar: media prior = random walk en lag 1
        PpsiBar = zeros(m, n);
        for j = 1:n
            PpsiBar(j, j) = 1;   % coef de lag 1 var j en ecuacion j = 1
        end

        nnuBar  = 0;
        PphiBar = zeros(n);
        Y_aug = Y;  X_aug = X;  T_eff = T;

    % ── Prior 2: Sims-Zha ─────────────────────────────────────────────────
    % Dummy observations: suma de coeficientes (mu5) + tendencia comun (mu6).
    % Ref: Sims & Zha (1998), Kadiyala & Karlsson (1997) Sec. 3.2.
    %
    % REQUISITO DE TRANSFORMACION: esta prior asume datos en diferencias o
    % demeaned (y0_bar ~ O(1)). Con datos en log-niveles los dummies pueden
    % dominar la verosimilitud. Transformaciones recomendadas via Cfg.TRANSFORMS
    % (disponible en Chat 13 — Lote 6: Loader extendido):
    %   'dlog'  — log-diferencias: convierte niveles a tasas de crecimiento
    %   'diff'  — primeras diferencias: elimina tendencia lineal
    %   'demean'— resta la media muestral: centra la serie en cero
    % Con cualquiera de estas transformaciones, y0_bar queda ~ O(sigma),
    % y los dummies pesan apropiadamente respecto a los datos.
    %
    % Hiperparametros:
    %   mu5 > 0: fuerza de la prior de co-persistence (suma coefs = I)
    %   mu6 > 0: fuerza de la prior de co-integration (tendencia comun)
    %   Valores pequenos (e.g. 1) => prior fuerte; grandes => prior debil.
    case 'sims_zha'
        pr = Cfg.PRIOR;
        check_required_fields(pr, {'mu5','mu6'}, 'sims_zha');
        mu5 = pr.mu5;
        mu6 = pr.mu6;

        % Advertencia si los datos parecen estar en niveles (y0 grande)
        y0 = mean(num(1:p, :), 1);           % [1 x n] media pre-muestra
        sigma_j = sqrt(sig2)';               % [1 x n] desv. estandar OLS
        y0_normalized = abs(y0) ./ sigma_j; % [1 x n] ratio nivel/escala
        if any(y0_normalized > 10)
            warning('build_posterior:simsZhaScale', ...
                ['Prior sims_zha: y0_bar/sigma > 10 para algunas variables. ' ...
                 'Los datos parecen estar en niveles (no demeaned/diferencias). ' ...
                 'Los dummies pueden dominar la verosimilitud. ' ...
                 'Considere aplicar Cfg.TRANSFORMS = {''dlog''|''diff''|''demean''} ' ...
                 'en load_data antes de usar esta prior.']);
        end

        % Construir dummies usando y0 normalizado por sigma para
        % hacer los dummies comparables entre variables
        y0_s = y0 ./ sigma_j;   % [1 x n], ~ O(1) independientemente de escala

        % Dummy 1: co-persistence (mu5) — n filas
        % Prior: suma de coeficientes propios de cada variable = 1
        if mu5 > 0
            Y_d1 = diag(y0_s) / mu5;
            X_d1 = zeros(n, m);
            for l = 1:p
                X_d1(:, (l-1)*n+1:l*n) = diag(y0_s) / mu5;
            end
        else
            Y_d1 = zeros(0, n);  X_d1 = zeros(0, m);
        end

        % Dummy 2: co-integration (mu6) — 1 fila
        % Prior: las variables comparten una tendencia comun
        if mu6 > 0
            Y_d2 = y0_s / mu6;
            X_d2 = zeros(1, m);
            for l = 1:p
                X_d2(1, (l-1)*n+1:l*n) = y0_s / mu6;
            end
            if nex >= 1
                X_d2(1, m) = 1 / mu6;
            end
        else
            Y_d2 = zeros(0, n);  X_d2 = zeros(0, m);
        end

        Y_aug = [Y; Y_d1; Y_d2];
        X_aug = [X; X_d1; X_d2];
        T_eff = size(Y_aug, 1);

        nnuBar           = 0;
        OomegaBarInverse = zeros(m);
        PpsiBar          = zeros(m, n);
        PphiBar          = zeros(n);

    % ── Prior 3: NIW Custom ───────────────────────────────────────────────
    % NIW informativo con parametros explicitamente especificados.
    % El usuario provee directamente nu_bar, Phi_bar, Psi_bar, Omega_bar.
    % Permite cualquier prior NIW propia.
    case 'niw_custom'
        pr = Cfg.PRIOR;
        check_required_fields(pr, {'nu_bar','Phi_bar','Psi_bar','Omega_bar'}, 'niw_custom');

        nnuBar  = pr.nu_bar;
        PphiBar = pr.Phi_bar;
        PpsiBar = pr.Psi_bar;

        % Invertir Omega_bar con verificacion de condicion numerica
        cond_num = cond(pr.Omega_bar);
        if cond_num > 1e12
            warning('build_posterior:illConditioned', ...
                'Cfg.PRIOR.Omega_bar esta mal condicionada (cond=%.2e). Usando pinv.', cond_num);
            OomegaBarInverse = pinv(pr.Omega_bar);
        else
            OomegaBarInverse = inv(pr.Omega_bar);
        end

        Y_aug = Y;  X_aug = X;  T_eff = T;

    % ── Prior 4: Natural Conjugate (Minnesota en forma NIW estricta) ──────
    % Kadiyala & Karlsson (1997): igual que Minnesota en Omega_bar y Psi_bar,
    % pero agrega una prior informativa sobre Sigma via Phi_bar y nu_bar.
    %
    % Omega_bar_{l,j} = (lambda1 / l^lambda3)^2 * sigma_j^2 * w_j
    %   (igual que Minnesota — misma formula con lambda2)
    %
    % Phi_bar = S * (nu_bar - n - 1),   S = diag(sigma_1^2,...,sigma_n^2)
    %   => prior sobre Sigma centrada en S (las varianzas OLS)
    %   => nu_bar > n+1 para prior propia; recomendado: nu_bar = n+1+T/10
    %
    % nu_bar > n+1 requerido para que E[Sigma|prior] = Phi_bar/(nu_bar-n-1) = S
    %
    % Ref: Kadiyala & Karlsson (1997), Koop & Korobilis (2010) Sec. 2.3
    case 'natural_conjugate'
        pr = Cfg.PRIOR;
        check_required_fields(pr, {'lambda1','lambda2','lambda3'}, 'natural_conjugate');
        lambda1 = pr.lambda1;
        lambda2 = pr.lambda2;
        lambda3 = pr.lambda3;

        % nu_bar: sobrescribible, default = n+1+T/10 (prior moderadamente informativa)
        if isfield(pr, 'nu_bar')
            nnuBar = pr.nu_bar;
        else
            nnuBar = n + 1 + round(T/10);   % e.g. 5+1+22 = 28 con T=220
        end
        if nnuBar <= n + 1
            error('build_posterior:invalidNuBar', ...
                'natural_conjugate requiere nu_bar > n+1 = %d. Valor actual: %d.', n+1, nnuBar);
        end

        % Factor de mezcla own/cross (igual que Minnesota)
        w = (1 + (n-1)*lambda2^2) / n;

        omega_bar_diag = zeros(m, 1);
        for l = 1:p
            for j = 1:n
                idx = (l-1)*n + j;
                omega_bar_diag(idx) = (lambda1 / l^lambda3)^2 * sig2(j) * w;
            end
        end
        if nex >= 1
            omega_bar_diag(m) = 1e6;
        end
        OomegaBarInverse = diag(1 ./ omega_bar_diag);

        % Psi_bar: random walk en lag 1
        PpsiBar = zeros(m, n);
        for j = 1:n
            PpsiBar(j, j) = 1;
        end

        % Phi_bar = S * (nu_bar - n - 1) => E[Sigma] = S (centrada en varianzas OLS)
        PphiBar = diag(sig2) * (nnuBar - n - 1);

        Y_aug = Y;  X_aug = X;  T_eff = T;

    otherwise
        error('build_posterior:unknownPrior', ...
            ['Prior type "%s" no reconocido. ' ...
             'Tipos validos: diffuse, minnesota, sims_zha, niw_custom, natural_conjugate.'], ...
            prior_type);
end

%% ── Posterior NIW ────────────────────────────────────────────────────────
nnuTilde            = T_eff + nnuBar;
OomegaTilde         = (X_aug'*X_aug + OomegaBarInverse) \ eye(m);
OomegaTildeInverse  =  X_aug'*X_aug + OomegaBarInverse;
PpsiTilde           = OomegaTilde * (X_aug'*Y_aug + OomegaBarInverse*PpsiBar);
PphiTilde           = Y_aug'*Y_aug + PphiBar + PpsiBar'*OomegaBarInverse*PpsiBar ...
                      - PpsiTilde' * OomegaTildeInverse * PpsiTilde;
PphiTilde           = (PphiTilde' + PphiTilde) * 0.5;

%% ── Cholesky de OomegaTilde ──────────────────────────────────────────────
cholOomegaTilde = chol(OomegaTilde)';

%% ── Empaquetar struct de salida ─────────────────────────────────────────
PosteriorParams.Y                  = Y;
PosteriorParams.X                  = X;
PosteriorParams.B                  = B;
PosteriorParams.U                  = U;
PosteriorParams.Sigmau             = Sigmau;
PosteriorParams.ssigma             = ssigma;
PosteriorParams.nnuTilde            = nnuTilde;
PosteriorParams.OomegaTilde         = OomegaTilde;
PosteriorParams.OomegaTildeInverse  = OomegaTildeInverse;
PosteriorParams.PpsiTilde           = PpsiTilde;
PosteriorParams.PphiTilde           = PphiTilde;
PosteriorParams.cholOomegaTilde     = cholOomegaTilde;
PosteriorParams.n                  = n;
PosteriorParams.p                  = p;
PosteriorParams.m                  = m;
PosteriorParams.T                  = T;
PosteriorParams.prior_type         = prior_type;

end

%% ── Helper: verificar campos requeridos del prior ────────────────────────
function check_required_fields(pr, fields, prior_name)
    for k = 1:numel(fields)
        if ~isfield(pr, fields{k})
            error('build_posterior:missingHyperparameter', ...
                'Prior "%s" requiere el campo Cfg.PRIOR.%s.', prior_name, fields{k});
        end
    end
end



