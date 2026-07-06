function Results = run_pfa(PosteriorParams, Cfg)
%RUN_PFA  Loop Penalty Function Approach (PFA) — Mountford & Uhlig (2009).
%
%   Results = RUN_PFA(PosteriorParams, Cfg)
%
%   Generaliza la logica de original/figure_1_panel_a/run_mainfile.m para
%   leer genuinamente las restricciones declaradas en Cfg.S / Cfg.Z (antes
%   de este chat, run_pfa.m las ignoraba y usaba e(2,:)/e(1,:) hardcoded a
%   BNW). Con Cfg.S/Cfg.Z de BNW (1 fila de signo, 1 fila de cero, h=0),
%   este archivo reproduce EXACTAMENTE los valores de referencia de BNW.
%
%   ALCANCE Y LIMITES (deliberados, ver .md de cierre para justificacion):
%
%     1) UN SOLO CHOQUE POR CORRIDA. El metodo de Mountford-Uhlig
%        optimiza un unico vector q (una columna ortogonal) por draw de
%        (B,Sigma). Si Cfg.S/Cfg.Z declaran restricciones en mas de un
%        choque, PFA NO PUEDE resolverlos simultaneamente: esta funcion
%        detecta el caso, emite un warning, y retorna un Results "vacio
%        por diseno" (Results.skipped = true) SIN correr el loop. Usa
%        Cfg.MODE='is' para identificacion con multiples choques.
%
%     2) CUALQUIER NUMERO DE HORIZONTES para ESE choque. La respuesta a
%        cualquier horizonte h es lineal en q (dado B,Sigma fijos), asi
%        que Cfg.HORIZONS_RESTRICT puede ser un escalar o un vector — no
%        se requiere ningun cambio al algoritmo de Mountford-Uhlig.
%
%     3) CUALQUIER NUMERO DE FILAS de signo/cero para ESE choque. Las
%        restricciones de cero se apilan como filas adicionales de la
%        restriccion lineal de igualdad (Aeq/beq) de fmincon — esto es
%        exactamente como fmincon maneja restricciones de igualdad
%        multiples, no es una extension del algoritmo. Las restricciones
%        de signo se SUMAN en la funcion de perdida (ver penalty_generic.m)
%        — esta suma SI es una extension de ingenieria sin caso de
%        referencia para N>1 (BNW usa N=1, que sigue reproduciendo
%        exacto).
%
%     4) Cada fila de Cfg.S{k}/Cfg.Z{k} debe restringir EXACTAMENTE una
%        variable en un horizonte (ver parse_restriction_row.m). No se
%        soportan combinaciones lineales de variables en una sola fila.
%
%   Entrada:
%     PosteriorParams  struct de build_posterior.m
%     Cfg              struct de config/spec_*.m
%
%   Salida (caso normal): Results struct con campos:
%     .LtildeStruct     struct canonica (via pack_ltilde.m)
%     .FEVD             [n x 1 x n_fevd_h x nd]  forecast error variance
%                       decomposition del shock identificado, en los
%                       horizontes de Cfg.FEVD_HORIZONS (Chat 19, Hallazgo
%                       6 — antes era [n x nd], un solo horizonte fijo).
%                       La dimension de shock es SIEMPRE 1 en PFA: el
%                       metodo Mountford-Uhlig identifica un unico shock
%                       por corrida, asi que no hay FEVD multi-shock aqui
%                       (ver run_is.m para eso).
%     .FEVD_shock_idx   escalar — el shock identificado (= shock_idx)
%     .FEVD_horizons    [1 x n_fevd_h] — horizontes calculados (resuelto
%                       de Cfg.FEVD_HORIZONS; default = Cfg.INDEX_FEVD)
%     .Bdraws         {nd x 1}  draws de B
%     .Sigmadraws     {nd x 1}  draws de Sigma
%     .Qdraws         {nd x 1}  draws de Q (vector q optimo del PFA)
%     .t_elapsed      tiempo total
%     .skipped        false
%
%   Salida (caso omitido, >1 choque restringido): Results struct con:
%     .skipped        true
%     .skip_reason    string explicando por que
%     .LtildeStruct   struct minima con .skipped=true (para que las
%                     funciones de post-proceso lo detecten via
%                     is_run_skipped.m sin fallar)
%     .FEVD, .FEVD_shock_idx, .FEVD_horizons, .Bdraws, .Sigmadraws, .Qdraws  vacios
%     .t_elapsed      0

%% ── Extraer campos de Cfg ────────────────────────────────────────────────
n  = PosteriorParams.n;
S  = Cfg.S;          % restricciones de signo
Z  = Cfg.Z;          % restricciones de cero
horizons_restrict = Cfg.HORIZONS_RESTRICT;
nH = numel(horizons_restrict);

%% ── Guard 1: detectar cuantos choques tienen restricciones declaradas ──
shocks_con_restriccion = [];
for k = 1:n
    if ~isempty(S{k}) || ~isempty(Z{k})
        shocks_con_restriccion(end+1) = k; %#ok<AGROW>
    end
end
n_shocks_restringidos = numel(shocks_con_restriccion);

if n_shocks_restringidos == 0
    error('run_pfa:noRestrictions', ...
        ['run_pfa: Cfg.S y Cfg.Z estan vacios para todos los choques. ' ...
         'PFA necesita al menos una restriccion de signo en un choque ' ...
         'para construir el objetivo de optimizacion.']);
end

if n_shocks_restringidos > 1
    msg = sprintf(['PFA (Mountford-Uhlig) solo puede identificar UN choque ' ...
        'a la vez. Esta spec declara restricciones en los choques [%s]. ' ...
        'PFA no se ejecutara para esta spec — usa Cfg.MODE=''is'' para ' ...
        'identificacion con multiples choques.'], ...
        strtrim(sprintf('%d ', shocks_con_restriccion)));
    warning('run_pfa:multiShockNotSupported', '%s', msg);

    Results.skipped        = true;
    Results.skip_reason    = msg;
    Results.LtildeStruct   = struct('skipped', true, 'skip_reason', msg);
    Results.FEVD           = [];
    Results.FEVD_shock_idx = [];
    Results.FEVD_horizons  = [];
    Results.Bdraws       = {};
    Results.Sigmadraws   = {};
    Results.Qdraws       = {};
    Results.t_elapsed    = 0;
    return;
end

shock_idx = shocks_con_restriccion(1);

if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX) && Cfg.SHOCK_IDX ~= shock_idx
    error('run_pfa:shockIdxMismatch', ...
        ['Cfg.SHOCK_IDX=%d no coincide con el choque que tiene restricciones ' ...
         'declaradas en Cfg.S/Cfg.Z (choque %d).'], Cfg.SHOCK_IDX, shock_idx);
end

%% ── Guard 2: validar y parsear filas de S{shock_idx} / Z{shock_idx} ─────
S_shock = S{shock_idx};
Z_shock = Z{shock_idx};

if isempty(S_shock)
    error('run_pfa:noSignRestriction', ...
        ['run_pfa: el choque %d no tiene restricciones de signo ' ...
         '(Cfg.S{%d} esta vacio). PFA (Mountford-Uhlig) requiere al menos ' ...
         'una restriccion de signo para construir el objetivo de ' ...
         'optimizacion.'], shock_idx, shock_idx);
end

expected_cols = n * nH;
if size(S_shock, 2) ~= expected_cols
    error('run_pfa:badSDims', ...
        ['Cfg.S{%d} tiene %d columnas; se esperaban %d ' ...
         '(numel(Cfg.HORIZONS_RESTRICT)*nvar = %d*%d).'], ...
        shock_idx, size(S_shock,2), expected_cols, nH, n);
end
if ~isempty(Z_shock) && size(Z_shock, 2) ~= expected_cols
    error('run_pfa:badZDims', ...
        'Cfg.Z{%d} tiene %d columnas; se esperaban %d.', ...
        shock_idx, size(Z_shock,2), expected_cols);
end

nS = size(S_shock, 1);
S_var_idx = zeros(nS,1); S_h_idx = zeros(nS,1); S_sign = zeros(nS,1);
for r = 1:nS
    [vi, hi, sv] = parse_restriction_row(S_shock(r,:), n);
    S_var_idx(r) = vi; S_h_idx(r) = hi; S_sign(r) = sv;
end

nZ = size(Z_shock, 1);
Z_var_idx = zeros(nZ,1); Z_h_idx = zeros(nZ,1);
for r = 1:nZ
    [vi, hi, ~] = parse_restriction_row(Z_shock(r,:), n);
    Z_var_idx(r) = vi; Z_h_idx(r) = hi;
end

horizons_needed = unique([S_h_idx; Z_h_idx]);

%% ── Extraer resto de campos de PosteriorParams ──────────────────────────
p                 = PosteriorParams.p;
m                 = PosteriorParams.m;
nnuTilde          = PosteriorParams.nnuTilde;
OomegaTilde       = PosteriorParams.OomegaTilde;
PpsiTilde         = PosteriorParams.PpsiTilde;
PphiTilde         = PosteriorParams.PphiTilde;
cholOomegaTilde   = PosteriorParams.cholOomegaTilde;
ssigma            = PosteriorParams.ssigma;

%% ── Extraer resto de campos de Cfg ───────────────────────────────────────
nd        = Cfg.ND;
horizon   = Cfg.HORIZON;
index     = Cfg.INDEX_FEVD;
iter_show = Cfg.ITER_SHOW;

%% ── FEVD: horizontes a calcular (Chat 19, Hallazgo 6) ────────────────────
% Cfg.FEVD_HORIZONS (opcional): vector de horizontes para los que se
% calcula la FEVD del shock identificado (PFA solo identifica UN shock por
% corrida — ver limitacion documentada arriba — asi que aqui no hay
% seleccion de shocks, solo de horizontes).
% DEFAULT (retrocompatible): Cfg.INDEX_FEVD (escalar) — reproduce
% EXACTAMENTE el valor unico que se calculaba antes de este campo.
% Misma convencion de "t" que usaba Cfg.INDEX_FEVD (ver variancedecomposition.m,
% helpfunctions/, no modificado): t=0 produce division 0/0, por eso se
% exige t>=1.
if isfield(Cfg, 'FEVD_HORIZONS') && ~isempty(Cfg.FEVD_HORIZONS)
    fevd_horizons = Cfg.FEVD_HORIZONS(:)';
else
    fevd_horizons = index;
end
if any(fevd_horizons < 1)
    error('run_pfa:badFevdHorizons', ...
        ['Cfg.FEVD_HORIZONS debe contener enteros >= 1 (convencion de ' ...
         'variancedecomposition.m: horizonte 0 produce division 0/0). ' ...
         'Recibido: %s'], mat2str(fevd_horizons));
end
n_fevd_h = numel(fevd_horizons);

%% ── Cronómetro ───────────────────────────────────────────────────────────
t_start = tic;

%% ── Funcion de Cholesky (igual que el original: hh = chol(x)') ──────────
hh = @(x) chol(x)';   % lower triangular

%% ── Definiciones de IRFs (pagina 12 de RWZ 2010) ────────────────────────
e      = eye(n);
J      = [e; repmat(zeros(n), p-1, 1)];
A_cell = cell(p, 1);
extraF = repmat(zeros(n), 1, p-1);
F      = zeros(p*n, p*n);
for l = 1:p-1
    F((l-1)*n+1:l*n, n+1:p*n) = [repmat(zeros(n),1,l-1), e, repmat(zeros(n),1,p-(l+1))];
end

%% ── Pre-alocar arrays de salida ─────────────────────────────────────────
Bdraws     = cell(nd, 1);
Sigmadraws = cell(nd, 1);
Qdraws     = cell(nd, 1);
Ltilde     = zeros(horizon+1, n, nd);
FEVD       = zeros(n, 1, n_fevd_h, nd);   % [n x 1 shock x n_fevd_h x nd]

optim_opts = optimset('MaxFunEvals', 40000, 'MaxIter', 20000, ...
    'Display', 'off', 'Algorithm', 'active-set');

%% ── Loop PFA ─────────────────────────────────────────────────────────────
counter = 1;
record  = 1;

while record <= nd

    %% ── Draw Sigma e B|Sigma (exactamente como el original) ─────────────
    Sigmadraw     = iwishrnd(PphiTilde, nnuTilde);
    cholSigmadraw = hh(Sigmadraw);    % lower = chol(S)'
    Bdraw         = kron(cholSigmadraw, cholOomegaTilde) * randn(m*n, 1) ...
                    + reshape(PpsiTilde, n*m, 1);
    Bdraw         = reshape(Bdraw, PosteriorParams.m, n);

    Bdraws{record,1}     = Bdraw;
    Sigmadraws{record,1} = Sigmadraw;

    %% ── Cholesky y matriz F para ESTE draw ───────────────────────────────
    % NOTA DE REFACTOR: en el original, F se calculaba DESPUES de resolver
    % q, porque BNW solo restringe h=0 (no se necesitaba F para construir
    % Aeq/objective). Aqui F se necesita ANTES de llamar fmincon para
    % poder construir restricciones en horizontes >0 (M_h = J'(F')^h J).
    % F depende solo de (B,Sigma), NO de q, asi que este reordenamiento
    % es puramente de ingenieria: no consume numeros aleatorios nuevos ni
    % cambia ningun valor numerico — preserva la reproducibilidad exacta
    % con rng(0).
    L    = hh(Sigmadraw);     % lower triangular, = hh(Sigmadraw) del original
    Umat = L';                % upper triangular, = chol(Sigmadraw)
    A0   = Umat \ e;
    Aplus = Bdraw * A0;
    for l = 1:p-1
        A_cell{l} = Aplus((l-1)*n+1:l*n, 1:end);
        F((l-1)*n+1:l*n, 1:n) = A_cell{l} / A0;
    end
    A_cell{p} = Aplus((p-1)*n+1:p*n, 1:end);
    F((p-1)*n+1:p*n, :) = [A_cell{p}/A0, extraF];

    %% ── Matrices M_h = J'(F')^h J para cada horizonte solicitado ────────
    % response_h = M_h * L * q   (lineal en q; ver .md de cierre)
    Mh = cell(nH, 1);
    for k = horizons_needed(:)'
        hz    = horizons_restrict(k);
        Mh{k} = J' * ((F')^hz) * J;
    end

    %% ── Construir filas de signo (para penalty_generic) y su ssigma ────
    S_rows      = zeros(nS, n);
    ssigma_norm = zeros(nS, 1);
    for r = 1:nS
        coef        = Mh{S_h_idx(r)}(S_var_idx(r), :) * L;   % 1 x n
        S_rows(r,:) = S_sign(r) * coef;
        ssigma_norm(r) = ssigma(S_var_idx(r));
    end

    %% ── Construir Aeq/beq (restricciones de cero, si las hay) ───────────
    if nZ > 0
        Aeq = zeros(nZ, n);
        for r = 1:nZ
            Aeq(r,:) = Mh{Z_h_idx(r)}(Z_var_idx(r), :) * L;
        end
        beq = zeros(nZ, 1);
    else
        Aeq = [];
        beq = [];
    end

    %% ── PFA de Mountford y Uhlig (2009): optimizar q ────────────────────
    q1ga    = rand(n, 1);
    pen_fun = @(q) penalty_generic(q, S_rows, ssigma_norm);
    [q, ~]  = fmincon(pen_fun, q1ga, [], [], Aeq, beq, [], [], @mycon, optim_opts);

    Qdraws{record, 1} = q;

    %% ── IRFs (misma formula que el original; F ya esta calculada) ──────
    for h = 1:horizon+1
        Ltilde(h, :, record) = (J' * ((F')^(h-1)) * J) * L * q;
    end

    %% ── FEVD (formula igual que el original; ahora en varios horizontes) ─
    for hh_i = 1:n_fevd_h
        FEVD(:, 1, hh_i, record) = variancedecomposition(F', J, Sigmadraw, L*q, n, fevd_horizons(hh_i));
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

%% ── Empaquetar LtildeStruct ──────────────────────────────────────────────
LtildeStruct = pack_ltilde(Ltilde, 'pfa', shock_idx, horizon, n, nd);

%% ── Empaquetar Results ───────────────────────────────────────────────────
Results.skipped        = false;
Results.LtildeStruct   = LtildeStruct;
Results.FEVD           = FEVD;             % [n x 1 shock x n_fevd_h x nd]
Results.FEVD_shock_idx = shock_idx;        % escalar: el unico shock identificado
Results.FEVD_horizons  = fevd_horizons;    % vector de horizontes calculados
Results.Bdraws       = Bdraws;
Results.Sigmadraws   = Sigmadraws;
Results.Qdraws       = Qdraws;
Results.t_elapsed    = toc(t_start);

%% ── Resumen de diagnóstico al terminar ───────────────────────────────────
print_run_summary(Cfg, Results, Results.t_elapsed);

end

