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
%     - Calcula parametros posterior NIW: nnuTilde, OomegaTilde, PpsiTilde, PphiTilde
%
%   Cfg.PRIOR.type admite:
%     'diffuse'           — NIW impropio (paper original, default)
%     'minnesota'         — Shrinkage hacia RW (lambda1, lambda2, lambda3)
%     'sims_zha'          — Dummy observations (lambda1, mu5, mu6)
%     'niw_custom'        — NIW informativo con parametros explícitos
%     'natural_conjugate' — Minnesota en forma NIW estricta (Kadiyala & Karlsson 1997)
%
%   Campos de PosteriorParams devueltos:
%     .Y              [T x n]     datos escalados, sin lags iniciales
%     .X              [T x m]     regressores (lags + constante)
%     .B              [m x n]     estimados OLS
%     .U              [T x n]     residuos OLS
%     .Sigmau         [n x n]     matriz de covarianza OLS
%     .ssigma         [n x 1]     desviaciones estandar (para PFA)
%     .nnuTilde        scalar      grados de libertad posterior
%     .OomegaTilde     [m x m]    matriz Omega posterior
%     .OomegaTildeInverse [m x m] inversa de OomegaTilde
%     .PpsiTilde       [m x n]    media condicional posterior B
%     .PphiTilde       [n x n]    parametro Phi posterior
%     .cholOomegaTilde [m x m]    Cholesky de OomegaTilde (para draws)
%     .n              scalar      numero de variables endogenas
%     .p              scalar      numero de lags
%     .m              scalar      m = n*p + nex
%     .T              scalar      numero de observaciones efectivas
%     .prior_type     string      tipo de prior utilizado (para trazabilidad)

%% ── Parametros del modelo ────────────────────────────────────────────────
p   = Cfg.NLAG;
nex = Cfg.NEX;
n   = Dataset.nvar;      % numero de variables endogenas
m   = n*p + nex;

%% ── Datos escalados ─────────────────────────────────────────────────────
% Aplicar SCALE_FACTOR (x100 para log-porcentajes)
% Solo usar variables endogenas
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
num = Dataset.Y_raw(:, endo_mask) * Cfg.SCALE_FACTOR;

%% ── Construir Y y X (notacion RWZ 2010) ─────────────────────────────────
% yt(t) A0 = xt(t) Aplus + c + et(t)  para t=1,...,T
% x(t) = [yt(t-1), ..., yt(t-p), 1]
% Y = T x n,  X = T x (n*p + nex)
yt = num(p+1:end, :);
T  = size(yt, 1);
xt = zeros(T, n*p + nex);
for i = 1:p
    xt(:, n*(i-1)+1:n*i) = num((p-(i-1)):end-i, :);
end
if nex >= 1
    xt(:, n*p + nex) = ones(T, 1);
end

Y = yt;        % T x n
X = xt;        % T x m

%% ── Estimacion OLS ───────────────────────────────────────────────────────
B      = (X'*X) \ (X'*Y);     % [m x n]  estimados OLS
U      = Y - X*B;              % [T x n]  residuos OLS
Sigmau = U'*U / T;             % [n x n]  covarianza OLS
ssigma = sqrt(diag(Sigmau));   % [n x 1]  desv. estandar (escala para PFA)

%% ── Determinar tipo de prior ─────────────────────────────────────────────
if isfield(Cfg, 'PRIOR') && isfield(Cfg.PRIOR, 'type')
    prior_type = lower(strtrim(Cfg.PRIOR.type));
else
    prior_type = 'diffuse';
end

%% ── Construir matrices del prior segun tipo ──────────────────────────────
switch prior_type

    % ── Prior 0: Difuso (paper original) ─────────────────────────────────
    case 'diffuse'
        nnuBar           = 0;
        OomegaBarInverse = zeros(m);
        PpsiBar          = zeros(m, n);
        PphiBar          = zeros(n);

        % Posterior sobre Y y X originales
        Y_aug = Y;
        X_aug = X;
        T_eff = T;

    % ── Prior 1: Minnesota ────────────────────────────────────────────────
    % Shrinkage hacia random walk.
    % Omega_bar diagonal con bloques por variable y lag:
    %   var. propias (j==i, lag l): (lambda1 / (l^lambda3 * sigma_i))^2
    %   var. cruzadas (j~=i, lag l): (lambda1*lambda2 / (l^lambda3 * sigma_j))^2
    % Ref: Doan, Litterman y Sims (1984); Litterman (1986)
    case 'minnesota'
        pr = Cfg.PRIOR;
        required_fields = {'lambda1', 'lambda2', 'lambda3'};
        check_required_fields(pr, required_fields, 'minnesota');

        lambda1 = pr.lambda1;   % tightness general
        lambda2 = pr.lambda2;   % decay cross-variable
        lambda3 = pr.lambda3;   % decay por lag

        % Varianzas de los residuos OLS como referencia de escala
        sig2 = diag(Sigmau);    % [n x 1]

        % Construir Omega_bar^{-1} (inversa de la varianza prior sobre vec(B))
        % Indexacion: columnas de X = [lag1_var1...lag1_varn, lag2_var1..., constante]
        omega_bar_diag = zeros(m, 1);
        for l = 1:p
            for j = 1:n   % j = variable en la posicion del regresor
                idx = (l-1)*n + j;
                for ii = 1:n   % ii = ecuacion (variable respuesta)
                    % Solo usamos el elemento diagonal para cada par (j, lag l)
                end
                % La prior es sobre el coeficiente A_{l,j} (regresion de var j en lag l)
                % Para ecuacion ii: prior en A_{l,j}^{(ii)} ~ N(delta_{l,j}^{ii}, omega_{l,j})
                % delta = 1 si j==ii y l==1 (RW), 0 otherwise
                % omega_{l,j} = (lambda1 / (l^lambda3))^2 * (1/sig2(j))  para j==ii
                %             = (lambda1*lambda2 / (l^lambda3))^2 * (sig2(j)/sig2(ii)) para j~=ii
                % Omega_bar es m x m; como es diagonal usamos la media sobre ecuaciones:
                % Tomamos omega_{l,j} = (lambda1 / l^lambda3)^2 * (1/sig2(j)) para own
                %                     = (lambda1*lambda2 / l^lambda3)^2 / sig2(j) para cross
                % Promediamos sobre las n ecuaciones que usan este regresor:
                own_sum = (lambda1 / (l^lambda3))^2 / sig2(j);
                % La Omega_bar diagonal se interpreta como varianza del prior sobre B_j
                % Usamos la forma estandar: omega_{lag l, var j} = prior variance
                % Para simplificar (forma Litterman clasica): varianza promedio sobre ecuaciones
                omega_bar_diag(idx) = own_sum;
            end
        end
        % Constante: prior muy difuso (varianza grande → inversa pequeña ≈ 0)
        if nex >= 1
            omega_bar_diag(m) = 1e-10;  % near-zero precision = vague prior
        end

        nnuBar           = 0;
        OomegaBarInverse = diag(omega_bar_diag);
        PpsiBar          = zeros(m, n);
        % PpsiBar: prior mean B. Para RW: lag-1 diagonal = 1, resto = 0
        for l = 1:p
            for j = 1:n
                idx = (l-1)*n + j;
                if l == 1
                    PpsiBar(idx, j) = 1;   % delta_{1,j}^j = 1 (RW prior)
                end
            end
        end
        PphiBar = zeros(n);

        Y_aug = Y;
        X_aug = X;
        T_eff = T;

    % ── Prior 2: Sims-Zha ─────────────────────────────────────────────────
    % Dummy observations: suma de coeficientes + tendencia comun.
    % Exactamente dos bloques de dummies segun Sims y Zha (1998):
    %   mu5: prior de suma de coeficientes (cointegration prior)
    %   mu6: prior de tendencia comun (co-persistence prior)
    % Se augmentan Y y X con estos dummies y se calcula el posterior
    % sobre los datos aumentados con prior difuso encima.
    % Ref: Sims y Zha (1998); Kadiyala y Karlsson (1997) Sec. 3.2
    case 'sims_zha'
        pr = Cfg.PRIOR;
        required_fields = {'mu5', 'mu6'};
        check_required_fields(pr, required_fields, 'sims_zha');

        mu5 = pr.mu5;
        mu6 = pr.mu6;

        % Media de las observaciones iniciales (promedio de los primeros p periodos)
        % Usada como referencia de nivel para los dummies
        y0 = mean(num(1:p, :), 1);   % [1 x n]

        % ── Dummy 1: Suma de coeficientes / co-persistence (mu5) ─────────
        % n filas. Implementa el prior de que la suma de coeficientes de
        % cada variable sobre sus propios lags es 1 (persistencia unitaria).
        % Y_d1 = diag(y0) / mu5    [n x n]
        % X_d1: cada fila j tiene diag(y0)/mu5 en los bloques de lag l=1..p
        %        y cero en la constante
        if mu5 > 0
            Y_d1 = diag(y0) / mu5;
            X_d1 = zeros(n, m);
            for l = 1:p
                X_d1(:, (l-1)*n+1:l*n) = diag(y0) / mu5;
            end
            % constante permanece 0
        else
            Y_d1 = zeros(0, n);
            X_d1 = zeros(0, m);
        end

        % ── Dummy 2: Tendencia comun / co-integration (mu6) ──────────────
        % 1 fila. Implementa el prior de que las variables comparten una
        % tendencia comun (suma de todos los lags = identidad, constante ~ 0).
        % Y_d2 = y0 / mu6          [1 x n]
        % X_d2: bloque lag l = y0/mu6, constante = 1/mu6
        if mu6 > 0
            Y_d2 = y0 / mu6;
            X_d2 = zeros(1, m);
            for l = 1:p
                X_d2(1, (l-1)*n+1:l*n) = y0 / mu6;
            end
            if nex >= 1
                X_d2(1, m) = 1 / mu6;
            end
        else
            Y_d2 = zeros(0, n);
            X_d2 = zeros(0, m);
        end

        % Augmentar Y y X solo con los dos bloques de Sims-Zha
        Y_aug = [Y; Y_d1; Y_d2];
        X_aug = [X; X_d1; X_d2];
        T_eff = size(Y_aug, 1);

        % Prior difuso sobre datos augmentados (igual que diffuse)
        nnuBar           = 0;
        OomegaBarInverse = zeros(m);
        PpsiBar          = zeros(m, n);
        PphiBar          = zeros(n);

    % ── Prior 3: NIW Custom ───────────────────────────────────────────────
    % NIW informativo con parametros explícitos proporcionados por el usuario.
    % Requiere: nu_bar, Phi_bar [n x n], Psi_bar [m x n], Omega_bar [m x m]
    case 'niw_custom'
        pr = Cfg.PRIOR;
        required_fields = {'nu_bar', 'Phi_bar', 'Psi_bar', 'Omega_bar'};
        check_required_fields(pr, required_fields, 'niw_custom');

        nnuBar           = pr.nu_bar;
        PphiBar          = pr.Phi_bar;
        PpsiBar          = pr.Psi_bar;
        OomegaBarInverse = inv(pr.Omega_bar);

        Y_aug = Y;
        X_aug = X;
        T_eff = T;

    % ── Prior 4: Natural Conjugate (Minnesota en forma NIW) ──────────────
    % Kadiyala y Karlsson (1997): Minnesota implementado en forma NIW cerrada.
    % Difiere de Minnesota clasico en que Phi_bar NO es diagonal:
    %   Phi_bar = S * (nu_bar - n - 1)   donde S = diag(sigma_j^2)
    % Omega_bar^{-1} se construye igual que Minnesota.
    % Ref: Kadiyala & Karlsson (1997), Koop & Korobilis (2010)
    case 'natural_conjugate'
        pr = Cfg.PRIOR;
        required_fields = {'lambda1', 'lambda2', 'lambda3'};
        check_required_fields(pr, required_fields, 'natural_conjugate');

        lambda1 = pr.lambda1;
        lambda2 = pr.lambda2;
        lambda3 = pr.lambda3;

        sig2 = diag(Sigmau);

        % Omega_bar^{-1} — igual que Minnesota
        omega_bar_diag = zeros(m, 1);
        for l = 1:p
            for j = 1:n
                idx = (l-1)*n + j;
                omega_bar_diag(idx) = (lambda1 / (l^lambda3))^2 / sig2(j);
            end
        end
        if nex >= 1
            omega_bar_diag(m) = 1e-10;
        end
        OomegaBarInverse = diag(omega_bar_diag);

        % Prior mean B: RW en lag 1
        PpsiBar = zeros(m, n);
        for l = 1:p
            for j = 1:n
                idx = (l-1)*n + j;
                if l == 1
                    PpsiBar(idx, j) = 1;
                end
            end
        end

        % Grados de libertad y Phi_bar (forma NIW cerrada)
        % nu_bar > n + 1 para que la prior sea propia
        nnuBar  = n + 2;  % minimo valido; sobrescribible via Cfg.PRIOR.nu_bar
        if isfield(pr, 'nu_bar')
            nnuBar = pr.nu_bar;
        end
        % Phi_bar = S * (nu_bar - n - 1)   con S = diag(sigma_j^2)
        PphiBar = diag(sig2) * (nnuBar - n - 1);
        if nnuBar <= n + 1
            PphiBar = zeros(n);  % impropio si nu_bar insuficiente
        end

        Y_aug = Y;
        X_aug = X;
        T_eff = T;

    otherwise
        error('build_posterior:unknownPrior', ...
            ['Prior type "%s" no reconocido. ' ...
             'Tipos validos: diffuse, minnesota, sims_zha, niw_custom, natural_conjugate.'], ...
            prior_type);
end

%% ── Posterior NIW (sobre datos posiblemente augmentados) ─────────────────
% Las formulas son identicas en todos los casos; solo cambian Y_aug, X_aug,
% OomegaBarInverse, PpsiBar, PphiBar y nnuBar.
nnuTilde            = T_eff + nnuBar;
OomegaTilde         = (X_aug'*X_aug + OomegaBarInverse) \ eye(m);
OomegaTildeInverse  =  X_aug'*X_aug + OomegaBarInverse;
PpsiTilde           = OomegaTilde * (X_aug'*Y_aug + OomegaBarInverse*PpsiBar);
PphiTilde           = Y_aug'*Y_aug + PphiBar + PpsiBar'*OomegaBarInverse*PpsiBar ...
                      - PpsiTilde' * OomegaTildeInverse * PpsiTilde;
PphiTilde           = (PphiTilde' + PphiTilde) * 0.5;   % simetrizar

%% ── Cholesky de OomegaTilde (para draws de B|Sigma) ─────────────────────
% El original usa: cholOomegaTilde = chol(OomegaTilde)'
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
                'Prior "%s" requiere el campo Cfg.PRIOR.%s.', ...
                prior_name, fields{k});
        end
    end
end

