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
%   ORDEN DE COLUMNAS EN xt (convension RWZ):
%     xt = [ lags (n*p cols) | constante (1 col) | dummies (ndummies cols) ]
%   La constante siempre en posicion n*p+1; dummies al final.
%   Con ndummies=0 esto replica exactamente el codigo original.
%
%   Cfg.PRIOR.type admite:
%     'diffuse'           — NIW impropio (paper original, default)
%     'minnesota'         — Shrinkage hacia RW
%     'sims_zha'          — Dummy observations
%     'niw_custom'        — NIW informativo
%     'natural_conjugate' — Minnesota en forma NIW estricta
%
%   Dummies exogenas via Cfg.DUMMIES (struct array, ver build_dummies.m):
%     Las dummies se construyen con build_dummies(Cfg, Dataset.dates) y se
%     agregan al final de xt. El campo PosteriorParams.ndummies documenta
%     cuantas dummies se incluyeron.

%% -- Parametros del modelo ----------------------------------------------
p   = Cfg.NLAG;
n   = Dataset.nvar;

%% -- Datos escalados (solo variables endogenas) -------------------------
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
num = Dataset.Y_raw(:, endo_mask) * Cfg.SCALE_FACTOR;

%% -- Construir dummies --------------------------------------------------
% build_dummies devuelve [T x ndummies]; [T x 0] si no hay dummies.
src_root  = fileparts(mfilename('fullpath'));
addpath(src_root);
DummyMatrix = build_dummies(Cfg, Dataset.dates);
ndummies    = size(DummyMatrix, 2);

%% -- nex total: constante + dummies ------------------------------------
% Cfg.NEX sigue siendo 1 (constante) o 0 (sin constante).
% nex_total = Cfg.NEX + ndummies es el total de exogenas en xt.
nex_const = Cfg.NEX;
nex_total = nex_const + ndummies;
m         = n*p + nex_total;

%% -- Construir Y y X (notacion RWZ 2010) --------------------------------
% x(t) = [y(t-1), ..., y(t-p), constante, dummy_1, ..., dummy_k]
yt = num(p+1:end, :);
T  = size(yt, 1);
xt = zeros(T, m);

% Bloque 1: lags
for i = 1:p
    xt(:, n*(i-1)+1 : n*i) = num((p-(i-1)) : end-i, :);
end

% Bloque 2: constante (posicion n*p+1, siempre fija)
if nex_const >= 1
    xt(:, n*p + 1) = ones(T, 1);
end

% Bloque 3: dummies al final (posiciones n*p+2 hasta m)
if ndummies > 0
    % Las dummies se construyeron sobre la muestra completa [T_full x ndummies].
    % Recortar los primeros p filas igual que yt.
    xt(:, n*p + nex_const + 1 : end) = DummyMatrix(p+1:end, :);
end

Y = yt;
X = xt;

%% -- Estimacion OLS -----------------------------------------------------
B      = (X'*X) \ (X'*Y);
U      = Y - X*B;
Sigmau = U'*U / T;
ssigma = sqrt(diag(Sigmau));
sig2   = diag(Sigmau);

%% -- Determinar tipo de prior -------------------------------------------
if isfield(Cfg, 'PRIOR') && isfield(Cfg.PRIOR, 'type')
    prior_type = lower(strtrim(Cfg.PRIOR.type));
else
    prior_type = 'diffuse';
end

%% -- Construir matrices del prior segun tipo ----------------------------
switch prior_type

    % -- Prior 0: Difuso -------------------------------------------------
    case 'diffuse'
        nnuBar           = 0;
        OomegaBarInverse = zeros(m);
        PpsiBar          = zeros(m, n);
        PphiBar          = zeros(n);
        Y_aug = Y;  X_aug = X;  T_eff = T;

    % -- Prior 1: Minnesota ----------------------------------------------
    case 'minnesota'
        pr = Cfg.PRIOR;
        check_required_fields(pr, {'lambda1','lambda2','lambda3'}, 'minnesota');
        lambda1 = pr.lambda1;
        lambda2 = pr.lambda2;
        lambda3 = pr.lambda3;

        w = (1 + (n-1)*lambda2^2) / n;

        omega_bar_diag = zeros(m, 1);
        for l = 1:p
            for j = 1:n
                idx = (l-1)*n + j;
                omega_bar_diag(idx) = (lambda1 / l^lambda3)^2 * sig2(j) * w;
            end
        end
        % Constante y dummies: prior muy vaga
        omega_bar_diag(n*p+1 : end) = 1e6;

        OomegaBarInverse = diag(1 ./ omega_bar_diag);

        PpsiBar = zeros(m, n);
        for j = 1:n
            PpsiBar(j, j) = 1;
        end

        nnuBar  = 0;
        PphiBar = zeros(n);
        Y_aug = Y;  X_aug = X;  T_eff = T;

    % -- Prior 2: Sims-Zha -----------------------------------------------
    case 'sims_zha'
        pr = Cfg.PRIOR;
        check_required_fields(pr, {'mu5','mu6'}, 'sims_zha');
        mu5 = pr.mu5;
        mu6 = pr.mu6;

        y0 = mean(num(1:p, :), 1);
        sigma_j = sqrt(sig2)';
        y0_normalized = abs(y0) ./ sigma_j;
        if any(y0_normalized > 10)
            warning('build_posterior:simsZhaScale', ...
                ['Prior sims_zha: y0_bar/sigma > 10 para algunas variables. ' ...
                 'Los datos parecen estar en niveles. ' ...
                 'Los dummies pueden dominar la verosimilitud.']);
        end

        y0_s = y0 ./ sigma_j;

        if mu5 > 0
            Y_d1 = diag(y0_s) / mu5;
            X_d1 = zeros(n, m);
            for l = 1:p
                X_d1(:, (l-1)*n+1:l*n) = diag(y0_s) / mu5;
            end
        else
            Y_d1 = zeros(0, n);  X_d1 = zeros(0, m);
        end

        if mu6 > 0
            Y_d2 = y0_s / mu6;
            X_d2 = zeros(1, m);
            for l = 1:p
                X_d2(1, (l-1)*n+1:l*n) = y0_s / mu6;
            end
            if nex_const >= 1
                X_d2(1, n*p+1) = 1 / mu6;   % constante en posicion fija
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

    % -- Prior 3: NIW Custom ---------------------------------------------
    case 'niw_custom'
        pr = Cfg.PRIOR;
        check_required_fields(pr, {'nu_bar','Phi_bar','Psi_bar','Omega_bar'}, 'niw_custom');

        nnuBar  = pr.nu_bar;
        PphiBar = pr.Phi_bar;
        PpsiBar = pr.Psi_bar;

        cond_num = cond(pr.Omega_bar);
        if cond_num > 1e12
            warning('build_posterior:illConditioned', ...
                'Cfg.PRIOR.Omega_bar mal condicionada (cond=%.2e). Usando pinv.', cond_num);
            OomegaBarInverse = pinv(pr.Omega_bar);
        else
            OomegaBarInverse = inv(pr.Omega_bar);
        end

        Y_aug = Y;  X_aug = X;  T_eff = T;

    % -- Prior 4: Natural Conjugate --------------------------------------
    case 'natural_conjugate'
        pr = Cfg.PRIOR;
        check_required_fields(pr, {'lambda1','lambda2','lambda3'}, 'natural_conjugate');
        lambda1 = pr.lambda1;
        lambda2 = pr.lambda2;
        lambda3 = pr.lambda3;

        if isfield(pr, 'nu_bar')
            nnuBar = pr.nu_bar;
        else
            nnuBar = n + 1 + round(T/10);
        end
        if nnuBar <= n + 1
            error('build_posterior:invalidNuBar', ...
                'natural_conjugate requiere nu_bar > n+1 = %d. Valor actual: %d.', n+1, nnuBar);
        end

        w = (1 + (n-1)*lambda2^2) / n;

        omega_bar_diag = zeros(m, 1);
        for l = 1:p
            for j = 1:n
                idx = (l-1)*n + j;
                omega_bar_diag(idx) = (lambda1 / l^lambda3)^2 * sig2(j) * w;
            end
        end
        omega_bar_diag(n*p+1 : end) = 1e6;
        OomegaBarInverse = diag(1 ./ omega_bar_diag);

        PpsiBar = zeros(m, n);
        for j = 1:n
            PpsiBar(j, j) = 1;
        end

        PphiBar = diag(sig2) * (nnuBar - n - 1);
        Y_aug = Y;  X_aug = X;  T_eff = T;

    otherwise
        error('build_posterior:unknownPrior', ...
            'Prior type "%s" no reconocido.', prior_type);
end

%% -- Posterior NIW ------------------------------------------------------
nnuTilde           = T_eff + nnuBar;
OomegaTilde        = (X_aug'*X_aug + OomegaBarInverse) \ eye(m);
OomegaTildeInverse =  X_aug'*X_aug + OomegaBarInverse;
PpsiTilde          = OomegaTilde * (X_aug'*Y_aug + OomegaBarInverse*PpsiBar);
PphiTilde          = Y_aug'*Y_aug + PphiBar + PpsiBar'*OomegaBarInverse*PpsiBar ...
                     - PpsiTilde' * OomegaTildeInverse * PpsiTilde;
PphiTilde          = (PphiTilde' + PphiTilde) * 0.5;

%% -- Cholesky de OomegaTilde --------------------------------------------
cholOomegaTilde = chol(OomegaTilde)';

%% -- Empaquetar struct de salida ----------------------------------------
PosteriorParams.Y                  = Y;
PosteriorParams.X                  = X;
PosteriorParams.B                  = B;
PosteriorParams.U                  = U;
PosteriorParams.Sigmau             = Sigmau;
PosteriorParams.ssigma             = ssigma;
PosteriorParams.nnuTilde           = nnuTilde;
PosteriorParams.OomegaTilde        = OomegaTilde;
PosteriorParams.OomegaTildeInverse = OomegaTildeInverse;
PosteriorParams.PpsiTilde          = PpsiTilde;
PosteriorParams.PphiTilde          = PphiTilde;
PosteriorParams.cholOomegaTilde    = cholOomegaTilde;
PosteriorParams.n                  = n;
PosteriorParams.p                  = p;
PosteriorParams.m                  = m;
PosteriorParams.T                  = T;
PosteriorParams.ndummies           = ndummies;
PosteriorParams.prior_type         = prior_type;

end

%% -- Helper: verificar campos requeridos del prior ----------------------
function check_required_fields(pr, fields, prior_name)
    for k = 1:numel(fields)
        if ~isfield(pr, fields{k})
            error('build_posterior:missingHyperparameter', ...
                'Prior "%s" requiere el campo Cfg.PRIOR.%s.', prior_name, fields{k});
        end
    end
end
