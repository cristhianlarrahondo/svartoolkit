function Results = run_is(PosteriorParams, Cfg)
%RUN_IS  Loop Importance Sampler (IS) + resampling.
%
%   Results = RUN_IS(PosteriorParams, Cfg)
%
%   Replica exactamente el loop de:
%     original/figure_1_panel_b/run_mainfile1.m
%   implementando el Algorithm 3 de Arias, Rubio-Ramirez y Waggoner (2018).
%
%   Las helpfunctions de ARW deben estar en el path antes de llamar esta
%   funcion (main.m se encarga via addpath).
%
%   Entrada:
%     PosteriorParams  struct de build_posterior.m
%     Cfg              struct de config/spec_*.m
%
%   Salida: Results struct con campos:
%     .LtildeStruct   struct canonica 4D (via pack_ltilde.m)
%                     Ltilde: [horizon+1, nvar, nvar, ne]
%     .FEVD           [n x ne]   forecast error variance decomposition
%     .imp_w          [nd x 1]   pesos normalizados del IS
%     .ne             scalar     effective sample size
%     .Bdraws         {nd x 1}   draws de B (todos, antes de resampling)
%     .Sigmadraws     {nd x 1}   draws de Sigma (todos)
%     .Qdraws         {nd x 1}   draws de Q (todos)
%     .uw             [nd x 1]   pesos sin normalizar

%% ── Extraer campos de PosteriorParams ────────────────────────────────────
n                = PosteriorParams.n;
p                = PosteriorParams.p;
m                = PosteriorParams.m;
nnuTilde         = PosteriorParams.nnuTilde;
PpsiTilde        = PosteriorParams.PpsiTilde;
PphiTilde        = PosteriorParams.PphiTilde;
cholOomegaTilde  = PosteriorParams.cholOomegaTilde;

%% ── Extraer campos de Cfg ────────────────────────────────────────────────
nd        = Cfg.ND;
horizon   = Cfg.HORIZON;
index     = Cfg.INDEX_FEVD;
iter_show = Cfg.ITER_SHOW;
maxdraws  = Cfg.MAX_IS_DRAWS;
conjugate = Cfg.CONJUGATE;
S         = Cfg.S;
Z         = Cfg.Z;
horizons  = Cfg.HORIZONS_RESTRICT;   % horizonte(s) sobre los que se restringen

%% ── Cronómetro ───────────────────────────────────────────────────────────
t_start = tic;

%% ── Normalizar Z: cada Z{i} debe ser zeros(zi, numel(horizons)*n) ────────
% El original inicializa explicitamente:
%   for i=1:nvar, Z{i}=zeros(0,numel(horizons)*nvar); end
% Si Cfg.Z{i} es [] (vacio, 0x0), ZIRF falla con error de dimensiones.
% Convertir [] a zeros(0, numel(horizons)*n) para que la multiplicacion
% Z{i}*IRF sea [0x(H*n)] * [(H*n)xn] = [0xn] (valida).
nH = numel(horizons);   % numero de horizontes restringidos
for i = 1:n
    if isempty(Z{i})
        Z{i} = zeros(0, nH * n);
    end
end

%% ── Normalizar S de la misma manera ──────────────────────────────────────
for i = 1:n
    if isempty(S{i})
        S{i} = zeros(0, nH * n);
    end
end

%% ── Setup info para helpfunctions IS ────────────────────────────────────
% SetupInfo construye la estructura que necesitan DrawW, ff_h, ff_h_inv,
% SpheresToQ, ZeroRestrictions, LogVolumeElement, etc.
info = SetupInfo(n, m, Z, @(x) chol(x));

%% ── Funcion de Cholesky: usar info.h del SetupInfo (igual que el original) ─
% El original: hh = info.h = @(x)chol(x)  (devuelve upper triangular)
% cholSigmadraw = hh(Sigma)' = chol(Sigma)' (lower triangular)
% CRITICO: NO redefinir hh como @(x)chol(x)' - eso invierte upper/lower
% y produce Bdraws diferentes aunque los pesos sean iguales.
hh = info.h;

info.nlag     = p;
info.horizons = horizons;
info.ZF       = @(x, y) ZIRF(x, y);

%% ── Funciones para pesos IS ──────────────────────────────────────────────
fs = @(x) ff_h(x, info);             % mapping (A0,A+) -> (B,Sigma,W)
r  = @(x) ZeroRestrictions(x, info); % restricciones de cero

%% ── Funcion para restricciones de signo ──────────────────────────────────
fh_S_restrictions = @(y) StructuralRestrictions(y, S);

%% ── Definiciones de IRFs (pagina 12 de RWZ 2010) ─────────────────────────
e      = eye(n);
J      = [e; repmat(zeros(n), p-1, 1)];
A_cell = cell(p, 1);
extraF = repmat(zeros(n), 1, p-1);
F      = zeros(p*n, p*n);
for l = 1:p-1
    F((l-1)*n+1:l*n, n+1:p*n) = [repmat(zeros(n),1,l-1), e, repmat(zeros(n),1,p-(l+1))];
end

%% ── Pre-alocar arrays ────────────────────────────────────────────────────
Bdraws      = cell(nd, 1);
Sigmadraws  = cell(nd, 1);
Qdraws      = cell(nd, 1);
storevefh   = zeros(nd, 1);   % log volume element f_h
storevegfhZ = zeros(nd, 1);   % log volume element g o f_h | Z
uw          = zeros(nd, 1);   % pesos sin normalizar

%% ── Loop IS: Algoritmo 2 + calculo de pesos (Algoritmo 3) ───────────────
counter = 1;
record  = 1;

while record <= nd

    %% ── Paso 1: Draw (B, Sigma) del posterior NIW ────────────────────────
    Sigmadraw     = iwishrnd(PphiTilde, nnuTilde);
    cholSigmadraw = hh(Sigmadraw)';
    Bdraw         = kron(cholSigmadraw, cholOomegaTilde) * randn(m*n, 1) ...
                    + reshape(PpsiTilde, n*m, 1);
    Bdraw         = reshape(Bdraw, n*p + Cfg.NEX, n);

    % Guardar draws de forma reducida
    Bdraws{record, 1}     = Bdraw;
    Sigmadraws{record, 1} = Sigmadraw;

    %% ── Pasos 2-4: Draw Q con restricciones de cero (Algoritmo 2) ───────
    w          = DrawW(info);
    x          = [vec(Bdraw); vec(Sigmadraw); w];
    structpara = ff_h_inv(x, info);

    % Guardar Q asociado al draw
    Qdraw             = SpheresToQ(w, info, Bdraw, Sigmadraw);
    Qdraws{record, 1} = reshape(Qdraw, n, n);

    %% ── Verificar restricciones de signo ─────────────────────────────────
    signs = fh_S_restrictions(structpara);

    if (sum(signs > 0)) == size(signs, 1)

        %% ── Calcular pesos IS (caso 'structural') ─────────────────────────
        switch conjugate

            case 'structural'
                % log volume element de f_h en (A0,A+):
                % = (n(n+1)/2)*log(2) - (2n+m+1)*log|det(A0)|
                storevefh(record, 1)   = (n*(n+1)/2)*log(2) ...
                    - (2*n + m + 1) * LogAbsDet(reshape(structpara(1:n*n), n, n));
                % log volume element de g o f_h restringido a Z
                storevegfhZ(record, 1) = LogVolumeElement(fs, structpara, r);
                % peso sin normalizar
                uw(record, 1) = exp(storevefh(record, 1) - storevegfhZ(record, 1));

            otherwise
                % Para otros conjugate (no implementado en Fase 3)
                uw(record, 1) = 1;

        end

    else
        % No satisface restricciones de signo: peso = 0
        uw(record, 1) = 0;
    end

    %% ── Progress display ─────────────────────────────────────────────────
    if counter == iter_show
        fprintf('Number of draws = %d\n', record);
        fprintf('Remaining draws = %d\n', nd - record);
        counter = 0;
    end
    counter = counter + 1;
    record  = record + 1;

end  % while

%% ── Normalizar pesos y calcular ESS ─────────────────────────────────────
imp_w = uw / sum(uw);
ne    = floor(1 / sum(imp_w.^2));   % effective sample size

fprintf('Effective sample size (ne) = %d\n', ne);
fprintf('Draws satisfying sign restrictions = %d\n', sum(uw > 0));

%% ── Pre-alocar arrays para IRFs e IS draws ───────────────────────────────
n_irf_draws = min(ne, maxdraws);

A0tilde    = zeros(n, n, n_irf_draws);
Aplustilde = zeros(m, n, n_irf_draws);
Ltilde     = zeros(horizon+1, n, n, n_irf_draws);
FEVD       = zeros(n, n_irf_draws);

%% ── Resampling IS (Paso 4 del Algoritmo 3) ───────────────────────────────
for s = 1:n_irf_draws

    %% ── Draw: B, Sigma, Q con pesos IS ───────────────────────────────────
    is_draw   = randsample(1:size(imp_w, 1), 1, true, imp_w);
    Bdraw     = Bdraws{is_draw, 1};
    Sigmadraw = Sigmadraws{is_draw, 1};
    Qdraw     = Qdraws{is_draw, 1};

    % Obtener parametros estructurales del draw resampleado
    x          = [reshape(Bdraw, m*n, 1); reshape(Sigmadraw, n*n, 1); Qdraw(:)];
    structpara = f_h_inv(x, info);

    %% ── IRFs en todos los horizontes (igual que el original) ─────────────
    LIRF = IRF_horizons(structpara, n, p, m, 0:horizon);

    for h = 0:horizon
        Ltilde(h+1, :, :, s) = LIRF(1 + h*n:(h+1)*n, :);
    end

    %% ── FEVD (igual que el original) ─────────────────────────────────────
    hSigmadraw = hh(Sigmadraw);
    A0_s       = hSigmadraw \ e;
    Aplus_s    = Bdraw * A0_s;

    for l = 1:p-1
        A_cell{l} = Aplus_s((l-1)*n+1:l*n, 1:end);
        F((l-1)*n+1:l*n, 1:n) = A_cell{l} / A0_s;
    end
    A_cell{p} = Aplus_s((p-1)*n+1:p*n, 1:end);
    F((p-1)*n+1:p*n, :) = [A_cell{p}/A0_s, extraF];

    FEVD(:, s) = variancedecomposition(F', J, Sigmadraw, ...
                     hSigmadraw' * Qdraw(:, 1), n, index);

    % Guardar parametros estructurales resampleados
    A0tilde(:, :, s)    = reshape(structpara(1:n*n), n, n);
    Aplustilde(:, :, s) = reshape(structpara(n*n+1:end), m, n);

end

% Recortar al tamano efectivo real (igual que el original)
A0tilde    = A0tilde(:, :, 1:s);
Aplustilde = Aplustilde(:, :, 1:s);
Ltilde     = Ltilde(:, :, :, 1:s);
FEVD       = FEVD(:, 1:s);

%% ── Empaquetar LtildeStruct ──────────────────────────────────────────────
% IS: Ltilde es 4D [horizon+1, nvar, nvar, ne]
% shock_idx = 1 (primer shock = optimismo)
LtildeStruct = pack_ltilde(Ltilde, 'is', 1, horizon, n, size(Ltilde, 4));

%% ── Empaquetar Results ───────────────────────────────────────────────────
Results.LtildeStruct = LtildeStruct;
Results.FEVD         = FEVD;
Results.imp_w        = imp_w;
Results.ne           = ne;
Results.Bdraws       = Bdraws;
Results.Sigmadraws   = Sigmadraws;
Results.Qdraws       = Qdraws;
Results.uw           = uw;
Results.t_elapsed    = toc(t_start);

%% ── Resumen de diagnóstico al terminar ───────────────────────────────────
print_run_summary(Cfg, Results, Results.t_elapsed);

%% ── E3: Alerta de tasa de aceptación baja ────────────────────────────────
% Leer umbral desde Cfg.MIN_ACCEPT_RATE (default 0.30 si no existe)
if isfield(Cfg, 'MIN_ACCEPT_RATE')
    min_accept = Cfg.MIN_ACCEPT_RATE;
else
    min_accept = 0.30;
end
accept_rate_final = sum(Results.uw > 0) / Cfg.ND;
if accept_rate_final < min_accept
    fprintf('[ADVERTENCIA] Tasa de aceptación baja: %.4f (umbral: %.2f)\n', ...
            accept_rate_final, min_accept);
    fprintf('             Considera aumentar ND o relajar las restricciones.\n');
end

end

