function PosteriorParams = build_posterior(Dataset, Cfg)
%BUILD_POSTERIOR  Construye Y, X, B, U y parametros posterior NIW.
%
%   PosteriorParams = BUILD_POSTERIOR(Dataset, Cfg)
%
%   Replica exactamente la logica de calculo de run_mainfile.m del original:
%     - Aplica Cfg.SCALE_FACTOR a los datos crudos
%     - Arma Y y X en notacion Rubio-Waggoner-Zha (RES 2010)
%     - Calcula OLS: B, U
%     - Prior difuso: nnuBar=0, OomegaBarInverse=0, PpsiBar=0, PphiBar=0
%     - Calcula parametros posterior NIW: nnuTilde, OomegaTilde, PpsiTilde, PphiTilde
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

%% ── Prior difuso (igual al original) ────────────────────────────────────
nnuBar           = 0;
OomegaBarInverse = zeros(m);
PpsiBar          = zeros(m, n);
PphiBar          = zeros(n);

%% ── Posterior NIW ────────────────────────────────────────────────────────
nnuTilde            = T + nnuBar;
OomegaTilde         = (X'*X + OomegaBarInverse) \ eye(m);
OomegaTildeInverse  =  X'*X + OomegaBarInverse;
PpsiTilde           = OomegaTilde * (X'*Y + OomegaBarInverse*PpsiBar);
PphiTilde           = Y'*Y + PphiBar + PpsiBar'*OomegaBarInverse*PpsiBar ...
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

end
