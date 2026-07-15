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
%     .LtildeStruct     struct canonica 4D (via pack_ltilde.m)
%                       Ltilde: [horizon+1, nvar, nvar, ne]
%     .FEVD             [n x n_fevd_shocks x n_fevd_h x ne]  forecast error
%                       variance decomposition, para los shocks de
%                       Cfg.SHOCK_IDX (default 'all') y los horizontes de
%                       Cfg.FEVD_HORIZONS (default Cfg.INDEX_FEVD). Chat 19,
%                       Hallazgo 6 — antes era [n x ne], siempre shock 1,
%                       siempre un unico horizonte fijo.
%     .FEVD_shock_idx   [1 x n_fevd_shocks] — shocks realmente calculados
%     .FEVD_horizons    [1 x n_fevd_h] — horizontes realmente calculados
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

%% ── FEVD: shocks y horizontes a calcular (Chat 19, Hallazgo 6) ───────────
% Shocks: reutiliza Cfg.SHOCK_IDX (mismo campo que ya usan plot_irfs.m /
% export_results.m para seleccionar shocks a graficar/exportar) — evita un
% campo duplicado. DEFAULT (IS): 'all' (todos los n shocks), a diferencia
% del comportamiento anterior a este chat (siempre Qdraw(:,1) fijo), para
% que el grafico de barras apiladas de plot_fevd.m tenga sentido por
% defecto. Con PFA no aplica (un solo shock por corrida, ver run_pfa.m).
if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
    fevd_shock_req = Cfg.SHOCK_IDX;
else
    fevd_shock_req = 'all';
end
if (ischar(fevd_shock_req) || isstring(fevd_shock_req)) && strcmpi(fevd_shock_req, 'all')
    fevd_shock_idx = 1:n;
else
    fevd_shock_idx = fevd_shock_req(:)';
end
if any(fevd_shock_idx < 1) || any(fevd_shock_idx > n)
    error('run_is:badFevdShockIdx', ...
        'Cfg.SHOCK_IDX (para FEVD) fuera de rango [1,%d]: %s', n, mat2str(fevd_shock_idx));
end
n_fevd_shocks = numel(fevd_shock_idx);

% Horizontes: Cfg.FEVD_HORIZONS (vector). DEFAULT (retrocompatible):
% Cfg.INDEX_FEVD (escalar) — reproduce el unico horizonte que se
% calculaba antes de este campo. Misma convencion de "t" que usaba
% Cfg.INDEX_FEVD (ver variancedecomposition.m, helpfunctions/, no
% modificado): t=0 produce division 0/0, por eso se exige t>=1.
if isfield(Cfg, 'FEVD_HORIZONS') && ~isempty(Cfg.FEVD_HORIZONS)
    fevd_horizons = Cfg.FEVD_HORIZONS(:)';
else
    fevd_horizons = index;
end
if any(fevd_horizons < 1)
    error('run_is:badFevdHorizons', ...
        ['Cfg.FEVD_HORIZONS debe contener enteros >= 1 (convencion de ' ...
         'variancedecomposition.m: horizonte 0 produce division 0/0). ' ...
         'Recibido: %s'], mat2str(fevd_horizons));
end
n_fevd_h = numel(fevd_horizons);

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
% NOTA (fix de este chat): helpfunctions/StructuralRestrictions.m evalua
% las restricciones de signo unicamente en h=0 (usa inv(A0)' fijo), sin
% importar cuantos horizontes declare Cfg.HORIZONS_RESTRICT. Con
% horizons=0 (caso BNW) esto coincidia por construccion, pero con
% numel(horizons)>1 producia un error de dimensiones. Se usa en su lugar
% structural_restrictions_generic.m (src/, generalizado via
% IRF_horizons.m), que reproduce EXACTAMENTE el original cuando
% horizons=0 y ademas soporta cualquier Cfg.HORIZONS_RESTRICT.
fh_S_restrictions = @(y) structural_restrictions_generic(y, S, n, p, m, horizons);

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
    Bdraw         = reshape(Bdraw, PosteriorParams.m, n);  % usa m de PosteriorParams (incluye dummies)

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

%% ── Guardia: ningun draw satisface las restricciones de signo ───────────
% (CU-1, generico) Sin esta guardia, sum(uw)==0 produce imp_w = 0/0 = NaN
% en toda la columna, ne = floor(1/NaN) = NaN, y el resampling de mas abajo
% falla varios pasos despues dentro de randsample con un mensaje generico
% de MATLAB ("W must contain non-negative values..."), sin indicar la
% causa real. Se detiene aqui, en el punto exacto de la falla, con un
% mensaje que apunta a Cfg.ND y Cfg.S.
if sum(uw) == 0
    error('run_is:noAcceptedDraws', ...
        ['Ningun draw satisfizo las restricciones de signo declaradas en ' ...
         'Cfg.S (0 de %d draws, Cfg.ND=%d). El importance sampler no puede ' ...
         'calcular pesos normalizados ni continuar con el resampling. ' ...
         'Aumente Cfg.ND, o revise que las restricciones de signo en Cfg.S ' ...
         '(y las de cero en Cfg.Z) sean jointly compatibles entre los ' ...
         'choques restringidos.'], nd, nd);
end

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
FEVD       = zeros(n, n_fevd_shocks, n_fevd_h, n_irf_draws);

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

    % FIX (Chat 19, Hallazgo 6): antes solo se calculaba para Qdraw(:,1)
    % (siempre el primer shock) y un unico horizonte (index). Misma
    % formula, ahora en un loop sobre los shocks/horizontes resueltos
    % arriba (fevd_shock_idx, fevd_horizons).
    for jj = 1:n_fevd_shocks
        sh = fevd_shock_idx(jj);
        for hh_i = 1:n_fevd_h
            FEVD(:, jj, hh_i, s) = variancedecomposition(F', J, Sigmadraw, ...
                hSigmadraw' * Qdraw(:, sh), n, fevd_horizons(hh_i));
        end
    end

    % Guardar parametros estructurales resampleados
    A0tilde(:, :, s)    = reshape(structpara(1:n*n), n, n);
    Aplustilde(:, :, s) = reshape(structpara(n*n+1:end), m, n);

end

% Recortar al tamano efectivo real (igual que el original)
A0tilde    = A0tilde(:, :, 1:s);
Aplustilde = Aplustilde(:, :, 1:s);
Ltilde     = Ltilde(:, :, :, 1:s);
FEVD       = FEVD(:, :, :, 1:s);

%% ── Empaquetar LtildeStruct ──────────────────────────────────────────────
% IS: Ltilde es 4D [horizon+1, nvar, nvar, ne]
% shock_idx = 1 (primer shock = optimismo)
LtildeStruct = pack_ltilde(Ltilde, 'is', 1, horizon, n, size(Ltilde, 4));

%% ── Empaquetar Results ───────────────────────────────────────────────────
Results.LtildeStruct   = LtildeStruct;
Results.FEVD           = FEVD;             % [n x n_fevd_shocks x n_fevd_h x ne]
Results.FEVD_shock_idx = fevd_shock_idx;
Results.FEVD_horizons  = fevd_horizons;
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





