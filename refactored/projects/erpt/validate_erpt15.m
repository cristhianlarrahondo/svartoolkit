%VALIDATE_ERPT15  ERPT-Chat 15 -- Verificacion RNG/PCT, corrida paralela de
%   las 16 specs oficiales del Ejercicio A a ND=1e6, y aplicacion del
%   criterio de seleccion de 4 pasos (fijado en ERPT-Chat 14) para elegir
%   la spec ganadora.
%
%   Tipo S. No toca run_is.m / build_posterior.m / load_data.m. Reusa la
%   infraestructura de cache ND-aware ya usada en ERPT-Chat 8/9/11/12.
%
%   ── 1. Verificacion de RNG por spec (protocolo obligatorio, ver .md de
%   cierre de ERPT-Chat 14, "Verificaciones pendientes", punto 1) ─────────
%   Confirmado via lectura de API de los 16 archivos spec_A_*.m y de
%   validate_erpt8.m/validate_erpt12.m ANTES de escribir este script:
%     - Cada spec define Cfg.SEED = 0 en su propio archivo de config (no
%       hay un rng(0) global unico consumido secuencialmente por las 16
%       corridas del loop).
%     - El patron ya establecido en validate_erpt8.m/12.m es
%       `rng('default'); rng(Cfg.SEED);` inmediatamente antes de cada
%       llamada a run_is, DENTRO del cuerpo del loop por spec.
%     - validate_erpt8.m documenta explicitamente (comentario junto a
%       ND_OVERRIDES) que este patron hace que subir ND para la MISMA
%       semilla produzca un superset determinista de los draws crudos
%       (ND=3e6 superset de ND=3e5) -- confirma que el reset ocurre por
%       spec, no una vez al inicio del script.
%   Conclusion: la paralelizacion a nivel de specs (parfor) es DIRECTA y
%   REPRODUCIBLE sin ajuste adicional, siempre que cada iteracion seguir
%   ejecutando su propio `rng('default'); rng(Cfg.SEED)` justo antes de su
%   propia llamada a run_is -- exactamente lo que hace local_run_spec()
%   (helper al final de este archivo), sin importar en que worker corra ni
%   en que orden se complete respecto a las demas 15 specs. run_is.m no
%   contiene ninguna llamada a rng/RandStream propia (verificado via API)
%   -- consume el stream global del proceso que lo invoca, que en un
%   worker de parfor es su propio stream independiente, reseteado por
%   nuestro codigo antes de cada llamada.
%
%   ── 2. Verificacion operativa de memoria (hallazgo de este chat, no
%   anticipado en ERPT-Chat 14) ────────────────────────────────────────────
%   run_is.m devuelve Results.Bdraws/.Sigmadraws/.Qdraws con el POOL CRUDO
%   de tamano Cfg.ND (no el resampleado a ne) -- confirmado via lectura de
%   run_is.m. A ND=1e6 eso son ~1.5-2 GB por spec solo en esos 3 campos.
%   Si las 16 corridas viven simultaneamente en el workspace del cliente
%   (patron normal de parfor, que devuelve el struct completo por
%   iteracion), el pico de memoria ronda 25-30 GB. Los 3 campos crudos ya
%   quedan persistidos en <OUTPUT_DIR>/results_is.mat via save_erpt_run
%   ANTES de aligerarse -- no se pierde informacion, simplemente no viajan
%   de vuelta al workspace del cliente en cada iteracion del parfor.
%   check_stability.m se llama ANTES de aligerar (usa Bdraws crudo).
%
%   Ejecutar COMPLETO (F5). Pegar el output de consola en el chat.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 15 -- corrida ND=1e6 + seleccion\n');
fprintf('======================================================\n\n');

%% ── Controles de corrida (editar aqui) ------------------------------------
USE_CACHE         = true;     % true = reusar <OUTPUT_DIR>/results_is.mat si ND cacheado >= ND_TARGET
RUN_BNW_CHECK     = true;     % true = correr Bloque 0 (obligatorio para APRUEBO)
USE_PARALLEL      = true;     % true = parfor a nivel de specs; fallback automatico a for si PCT no esta operativo
ND_TARGET         = 1e6;      % ND objetivo (decision 3, ERPT-Chat 14)
NE_MIN            = 200;      % Paso 1: umbral duro de ne (ya usado desde ERPT-Chat 8)
STABLE_FRAC_MIN   = 0.70;     % Paso 1: umbral duro de fraccion de draws estables (ERPT-Chat 11/12)
FOCUS_HORIZON     = 36;
FOCUS_PRICE_VAR   = 'con_inf';

% Paso 2 -- shocks/variables de precio y niveles de banda a evaluar
BAND_SHOCKS      = {'Cam', 'Dem', 'Ofe'};
BAND_PRICE_VARS  = {'imp_inf', 'con_inf'};
BAND_LEVELS      = [0.16 0.84;   % 68% bilateral
                     0.05 0.95]; % 90% bilateral
% Regla de decisividad del Paso 2 (definida en ESTE chat -- ERPT-Chat 14
% dejo el criterio "menor ancho promedio gana" sin fijar que tan separado
% debe estar el 1o del 2o para considerarse decisivo sin pasar al Paso 3).
% Se define: si el ancho promedio combinado (68%+90%) del 1er lugar esta
% > SEP_MARGIN por debajo del 2o lugar (en terminos relativos), el Paso 2
% decide solo. Si no, se pasa al Paso 3 como desempate cualitativo.
SEP_MARGIN = 0.05;   % 5% relativo

%% ── Rutas -------------------------------------------------------------------
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');
REF_SRC       = fullfile(REF_ROOT, 'src');
REF_CFG_DIR   = fullfile(REF_ROOT, 'config');
REF_HELP      = fullfile(REF_ROOT, 'helpfunctions');

addpath(REF_SRC); addpath(REF_CFG_DIR); addpath(REF_HELP);
addpath(PROJ_CFG); addpath(PROJ_SRC);

fprintf('  USE_CACHE         : %d\n', USE_CACHE);
fprintf('  RUN_BNW_CHECK     : %d\n', RUN_BNW_CHECK);
fprintf('  USE_PARALLEL (req): %d\n', USE_PARALLEL);
fprintf('  ND_TARGET         : %g\n', ND_TARGET);
fprintf('  NE_MIN            : %d\n', NE_MIN);
fprintf('  STABLE_FRAC_MIN   : %.2f\n\n', STABLE_FRAC_MIN);

V       = {'FAIL', 'OK  '};
TOL_irf = 1e-6;

% -- Los 16 specs OFICIALES del Ejercicio A (ERPT-Chat 14, decision 1):
%    mm_niwcustom REEMPLAZA a mm_minn. mm_minn queda fuera, sin borrarse
%    del repo (evidencia documentada, ver ERPT-Chat 9-13).
spec_names = { ...
    'spec_A_base_aa_diffuse_lag2_v0',   'spec_A_base_aa_diffuse_lag4_v0', ...
    'spec_A_base_aa_minn_lag2_v0',      'spec_A_base_aa_minn_lag4_v0', ...
    'spec_A_base_mm_diffuse_lag2_v0',   'spec_A_base_mm_diffuse_lag4_v0', ...
    'spec_A_base_mm_niwcustom_lag2_v0', 'spec_A_base_mm_niwcustom_lag4_v0', ...
    'spec_A_rob_aa_diffuse_lag2_v0',    'spec_A_rob_aa_diffuse_lag4_v0', ...
    'spec_A_rob_aa_minn_lag2_v0',       'spec_A_rob_aa_minn_lag4_v0', ...
    'spec_A_rob_mm_diffuse_lag2_v0',    'spec_A_rob_mm_diffuse_lag4_v0', ...
    'spec_A_rob_mm_niwcustom_lag2_v0',  'spec_A_rob_mm_niwcustom_lag4_v0' };
n_specs = numel(spec_names);

NAMED_SHOCKS = {'Cam', 'Dem', 'Ofe'};

fprintf('  Specs oficiales (16): 4 aa_diffuse + 4 aa_minn + 4 mm_diffuse + 4 mm_niwcustom\n\n');

% =========================================================================
%  BLOQUE A -- Verificacion operativa del Parallel Computing Toolbox
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE A -- Verificacion operativa PCT (smoke test)\n');
fprintf('======================================================\n\n');

pct_ok = false;
n_workers = 0;
if USE_PARALLEL
    try
        v = ver('parallel');
        if isempty(v)
            error('validate_erpt15:noPCT', 'Parallel Computing Toolbox no esta instalado.');
        end
        pool = gcp('nocreate');
        if isempty(pool)
            pool = parpool;
        end
        n_workers = pool.NumWorkers;

        % -- Propagar path a todos los workers (funciones de projects/erpt
        %    y del core compartido deben resolverse tambien alla) ---------
        pctRunOnAll(sprintf('addpath(''%s'');', REF_SRC));
        pctRunOnAll(sprintf('addpath(''%s'');', REF_CFG_DIR));
        pctRunOnAll(sprintf('addpath(''%s'');', REF_HELP));
        pctRunOnAll(sprintf('addpath(''%s'');', PROJ_CFG));
        pctRunOnAll(sprintf('addpath(''%s'');', PROJ_SRC));

        % -- Smoke test: confirmar que rng('default');rng(0) dentro de cada
        %    iteracion produce el MISMO numero sin importar el worker
        %    (verificacion operativa de la conclusion RNG del encabezado) --
        smoke = zeros(1, 4);
        parfor kk = 1:4
            rng('default'); rng(0); %#ok<PFEEDBACK>
            smoke(kk) = rand();
        end
        rng_ok = all(abs(smoke - smoke(1)) < 1e-15);

        fprintf('  Pool activo         : %d workers\n', n_workers);
        fprintf('  Smoke rng(0) x4     : %s (valores: %s)\n', V{int32(rng_ok)+1}, mat2str(smoke, 6));

        if ~rng_ok
            error('validate_erpt15:rngMismatch', ...
                'rng(0) dentro de parfor no fue determinista entre workers -- no se puede paralelizar de forma reproducible.');
        end

        pct_ok = true;
        fprintf('\n  >> BLOQUE A: PASA -- PCT operativo, %d workers, RNG determinista confirmado.\n\n', n_workers);
    catch ME
        pct_ok = false;
        fprintf('\n  [ADVERTENCIA] PCT no disponible/operativo: %s\n', ME.message);
        fprintf('  >> Fallback automatico a ejecucion SECUENCIAL (for) para el Bloque 1.\n\n');
    end
else
    fprintf('  [OMITIDO] USE_PARALLEL=false por configuracion -- ejecucion secuencial.\n\n');
end

USE_PARALLEL_EFFECTIVE = USE_PARALLEL && pct_ok;

% =========================================================================
%  BLOQUE 0 -- Regresion BNW IS (sanity -- este chat no toca el core)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 0 -- Regresion BNW IS (spec_bnw_is), ND completo\n');
fprintf('======================================================\n\n');

if RUN_BNW_CHECK
    clear Cfg;
    Cfg = struct();
    run(fullfile(REF_ROOT, 'config', 'spec_bnw_is.m'));
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;
    fprintf('  Cfg.MODE = %s | Cfg.ND = %g | Cfg.SEED = %d\n', Cfg.MODE, Cfg.ND, Cfg.SEED);

    Dataset_bnw   = load_data(Cfg);
    Posterior_bnw = build_posterior(Dataset_bnw, Cfg);

    fprintf('  Corriendo IS BNW (nd=%g, esperar varios minutos)...\n', Cfg.ND);
    rng('default'); rng(0);
    tic;
    Results_bnw = run_is(Posterior_bnw, Cfg);
    t_bnw = toc;
    fprintf('  Tiempo: %.1f seg\n\n', t_bnw);

    Ltilde_bnw = Results_bnw.LtildeStruct.data;
    val_ib = Ltilde_bnw(end, end, end, end);
    REF_ib = 0.2041864191;
    ok_ib  = abs(val_ib - REF_ib) <= TOL_irf;

    fprintf('  Ltilde(end,end,end,end) = %.10f   (ref %.10f)   %s\n', val_ib, REF_ib, V{int32(ok_ib)+1});
    fprintf('  ne efectivo             = %d\n\n', Results_bnw.ne);

    bloque0_pasa = ok_ib;
    if bloque0_pasa
        fprintf('  >> BLOQUE 0: PASA -- baseline BNW intacto.\n\n');
    else
        fprintf('  >> BLOQUE 0: NO PASA -- detener y revisar antes de continuar.\n\n');
    end
else
    bloque0_pasa = true;
    fprintf('  [OMITIDO] RUN_BNW_CHECK=false.\n\n');
end

% =========================================================================
%  BLOQUE 1 -- Corrida (paralela o secuencial) de las 16 specs a ND=1e6
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- 16 specs oficiales @ ND=%g (%s)\n', ND_TARGET, ...
    iif_local(USE_PARALLEL_EFFECTIVE, 'PARALELO', 'SECUENCIAL'));
fprintf('======================================================\n\n');

spec_out = cell(1, n_specs);
t_bloque1 = tic;

if USE_PARALLEL_EFFECTIVE
    parfor ss = 1:n_specs
        spec_out{ss} = local_run_spec(spec_names{ss}, PROJ_CFG, USE_CACHE, ND_TARGET); %#ok<PFOUS>
    end
else
    for ss = 1:n_specs
        fprintf('------------------------------------------------------\n');
        fprintf('  [%2d/%d] Spec: %s\n', ss, n_specs, spec_names{ss});
        fprintf('------------------------------------------------------\n');
        spec_out{ss} = local_run_spec(spec_names{ss}, PROJ_CFG, USE_CACHE, ND_TARGET);
    end
end
t_bloque1_elapsed = toc(t_bloque1);
fprintf('  Tiempo total Bloque 1: %.1f seg (%.1f min)\n\n', t_bloque1_elapsed, t_bloque1_elapsed/60);

bloque1_ok      = true;
bloque1_msgs    = {};
warn_low_ne     = {};
Results_by_spec = struct();
Dataset_by_spec = struct();
Cfg_by_spec     = struct();
ERPT_by_spec    = struct();
ne_v            = nan(1, n_specs);
accept_rate_v   = nan(1, n_specs);
stable_frac_v   = nan(1, n_specs);
cache_used_v    = false(1, n_specs);
ok_v            = false(1, n_specs);

for ss = 1:n_specs
    r  = spec_out{ss};
    sn = spec_names{ss};
    if ~r.ok
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: ERROR: %s', sn, r.err_msg); %#ok<AGROW>
        fprintf('  [%2d/%d] %-38s [ERROR] %s\n', ss, n_specs, sn, r.err_msg);
        continue;
    end

    n_shocks_out = numel(r.ERPT.shocks);
    if n_shocks_out ~= r.Dataset.nvar
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: se esperaban %d choques, se obtuvieron %d', ...
            sn, r.Dataset.nvar, n_shocks_out); %#ok<AGROW>
    end
    names_out = {r.ERPT.shocks.name};
    if ~all(ismember(NAMED_SHOCKS, names_out))
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: faltan choques nombrados', sn); %#ok<AGROW>
    end
    if r.ne <= 0
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: ne=%d (sin draws efectivos)', sn, r.ne); %#ok<AGROW>
    end
    if r.ne > 0 && r.ne < NE_MIN
        warn_low_ne{end+1} = sprintf('%s (ne=%d)', sn, r.ne); %#ok<AGROW>
    end

    Results_by_spec.(sn) = r.Results;
    Dataset_by_spec.(sn) = r.Dataset;
    Cfg_by_spec.(sn)     = r.Cfg;
    ERPT_by_spec.(sn)    = r.ERPT;
    ne_v(ss)             = r.ne;
    accept_rate_v(ss)    = r.accept_rate;
    stable_frac_v(ss)    = r.stable_frac;
    cache_used_v(ss)     = r.used_cache;
    ok_v(ss)             = true;

    fprintf('  [%2d/%d] %-38s %-11s ne=%-6d accept=%.4f estable=%.2f%%\n', ...
        ss, n_specs, sn, iif_local(r.used_cache, '[cache]', '[recalc]'), ...
        r.ne, r.accept_rate, 100*r.stable_frac);
end
fprintf('\n');

if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- las 16 specs oficiales cargadas/corridas a ND=%g.\n', ND_TARGET);
else
    fprintf('  >> BLOQUE 1: NO PASA. Detalle:\n');
    for i = 1:numel(bloque1_msgs)
        fprintf('     - %s\n', bloque1_msgs{i});
    end
end
if ~isempty(warn_low_ne)
    fprintf('\n  [ADVERTENCIA] ne < %d en %d spec(s) -- BANDAS INDICATIVAS:\n', NE_MIN, numel(warn_low_ne));
    for i = 1:numel(warn_low_ne)
        fprintf('     - %s\n', warn_low_ne{i});
    end
end
fprintf('\n');

% =========================================================================
%  BLOQUE 2 -- Tabla comparativa (ancha + larga) + Excel
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Tabla maestra (16 specs, ND=%g)\n', ND_TARGET);
fprintf('======================================================\n\n');

bloque2_ok = true;
T_erpt = table(); T_long = table(); T_diag = table();
if bloque1_ok
    try
        [T_erpt, T_diag] = build_erpt_comparison(ERPT_by_spec, Results_by_spec, Cfg_by_spec, spec_names, NAMED_SHOCKS);
        T_long           = build_erpt_comparison_long(ERPT_by_spec, spec_names, NAMED_SHOCKS);
    catch ME
        bloque2_ok = false;
        fprintf('  [ERROR] construccion de tablas fallo: %s\n\n', ME.message);
    end
else
    bloque2_ok = false;
    fprintf('  [OMITIDO] Bloque 1 no paso -- no se construyen tablas.\n\n');
end

if bloque2_ok
    fprintf('  --- Diagnosticos de corrida por spec (T_diag) ---\n');
    disp(T_diag);

    hz_list = unique(T_long.horizon, 'stable');
    if ~ismember(FOCUS_HORIZON, hz_list)
        FOCUS_HORIZON = hz_list(end);
    end
    fprintf('  --- Digesto: mediana ERPT | price_var=%s | horizonte=%d ---\n', FOCUS_PRICE_VAR, FOCUS_HORIZON);
    fprintf('  %-32s', 'spec');
    for kk = 1:numel(NAMED_SHOCKS)
        fprintf('  %8s', NAMED_SHOCKS{kk});
    end
    fprintf('\n');
    for ss = 1:n_specs
        sn = spec_names{ss};
        fprintf('  %-32s', sn);
        for kk = 1:numel(NAMED_SHOCKS)
            mask = strcmp(T_long.spec, sn) & strcmp(T_long.shock, NAMED_SHOCKS{kk}) & ...
                   strcmp(T_long.price_var, FOCUS_PRICE_VAR) & (T_long.horizon == FOCUS_HORIZON);
            v = T_long.median(mask);
            if isempty(v)
                fprintf('  %8s', 'n/a');
            else
                fprintf('  %8.3f', v(1));
            end
        end
        fprintf('\n');
    end
    fprintf('\n');

    comparison_dir = fullfile(PROJ_ROOT, 'output', 'comparison');
    if ~isfolder(comparison_dir), mkdir(comparison_dir); end
    xlsx_path = fullfile(comparison_dir, 'erpt_comparison_A16_ND1e6.xlsx');
    if isfile(xlsx_path), delete(xlsx_path); end
    writetable(T_erpt, xlsx_path, 'Sheet', 'erpt_comparison');
    writetable(T_long, xlsx_path, 'Sheet', 'erpt_long');
    writetable(T_diag, xlsx_path, 'Sheet', 'run_diagnostics');
    fprintf('  Tabla comparativa exportada (3 hojas) a:\n    %s\n\n', xlsx_path);

    fprintf('  >> BLOQUE 2: PASA.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA.\n\n');
end

% =========================================================================
%  BLOQUE 3 -- Criterio de seleccion de 4 pasos (ERPT-Chat 14, decision 2)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Seleccion de spec ganadora (cascada de 4 pasos)\n');
fprintf('======================================================\n\n');

winner            = '';
winner_step       = 0;
winner_reason     = '';
bloque3_ok        = bloque1_ok && bloque2_ok;
paso2_tbl_names   = {};
paso2_scores      = [];

if bloque3_ok
    % -- Paso 1: filtro duro de estabilidad numerica -----------------------
    fprintf('  --- Paso 1: estabilidad numerica (ne>=%d Y frac.estable>=%.0f%%) ---\n', NE_MIN, 100*STABLE_FRAC_MIN);
    pass1 = false(1, n_specs);
    fprintf('  %-38s %8s %10s %10s\n', 'spec', 'ne', 'estable%', 'PASA?');
    for ss = 1:n_specs
        if ~ok_v(ss), continue; end
        p1 = (ne_v(ss) >= NE_MIN) && (stable_frac_v(ss) >= STABLE_FRAC_MIN);
        pass1(ss) = p1;
        fprintf('  %-38s %8d %9.2f%% %10s\n', spec_names{ss}, ne_v(ss), 100*stable_frac_v(ss), V{int32(p1)+1});
    end
    survivors = spec_names(pass1);
    fprintf('\n  Sobreviven Paso 1: %d/%d -> %s\n\n', numel(survivors), n_specs, strjoin(survivors, ', '));

    if isempty(survivors)
        bloque3_ok = false;
        fprintf('  [ERROR] Ninguna spec paso el Paso 1 -- no se puede seleccionar ganadora.\n\n');
    else
        % -- Paso 2: ancho promedio de bandas 68%/90% ------------------------
        fprintf('  --- Paso 2: ancho promedio de bandas (68%%+90%%), Cam/Dem/Ofe x imp_inf/con_inf, 5 horizontes ---\n');
        fprintf('  Regla de agregacion (fijada en este chat): ancho_68 y ancho_90 se\n');
        fprintf('  promedian cada uno sobre todas las combinaciones shock x price_var x\n');
        fprintf('  horizonte; el score final es el promedio simple de ambos anchos.\n\n');

        n_surv = numel(survivors);
        score68 = nan(1, n_surv);
        score90 = nan(1, n_surv);
        score_combined = nan(1, n_surv);

        for ss = 1:n_surv
            sn = survivors{ss};
            ERPT_ss = ERPT_by_spec.(sn);
            names_ss = {ERPT_ss.shocks.name};
            widths68 = [];
            widths90 = [];
            for kk = 1:numel(BAND_SHOCKS)
                k_idx = find(strcmp(names_ss, BAND_SHOCKS{kk}), 1);
                if isempty(k_idx), continue; end
                prices_arr = ERPT_ss.shocks(k_idx).prices;
                pvar_names = {prices_arr.var};
                for pp = 1:numel(BAND_PRICE_VARS)
                    p_idx = find(strcmp(pvar_names, BAND_PRICE_VARS{pp}), 1);
                    if isempty(p_idx), continue; end
                    ratio_draws = prices_arr(p_idx).ratio_draws;   % [nh x ndraws]
                    nh_local = size(ratio_draws, 1);
                    for hh = 1:nh_local
                        sl = ratio_draws(hh, :);
                        q68 = quantile(sl, BAND_LEVELS(1, :));
                        q90 = quantile(sl, BAND_LEVELS(2, :));
                        widths68(end+1) = q68(2) - q68(1); %#ok<AGROW>
                        widths90(end+1) = q90(2) - q90(1); %#ok<AGROW>
                    end
                end
            end
            score68(ss) = mean(widths68);
            score90(ss) = mean(widths90);
            score_combined(ss) = mean([score68(ss), score90(ss)]);
        end

        [sorted_scores, order] = sort(score_combined, 'ascend');
        sorted_names = survivors(order);

        fprintf('  %-38s %10s %10s %10s\n', 'spec', 'ancho68', 'ancho90', 'combinado');
        for ss = 1:n_surv
            fprintf('  %-38s %10.4f %10.4f %10.4f\n', sorted_names{ss}, ...
                score68(order(ss)), score90(order(ss)), sorted_scores(ss));
        end
        fprintf('\n');

        paso2_tbl_names = sorted_names;
        paso2_scores    = sorted_scores;

        if n_surv == 1
            winner        = sorted_names{1};
            winner_step   = 1;
            winner_reason = 'unica spec que sobrevivio el Paso 1 (filtro duro de estabilidad).';
        else
            rel_gap = (sorted_scores(2) - sorted_scores(1)) / sorted_scores(1);
            fprintf('  Brecha relativa 1o vs 2o lugar: %.2f%% (umbral de decisividad: %.0f%%)\n\n', ...
                100*rel_gap, 100*SEP_MARGIN);

            if rel_gap >= SEP_MARGIN
                winner        = sorted_names{1};
                winner_step   = 2;
                winner_reason = sprintf(['menor ancho promedio de bandas (68%%+90%%) entre las specs que ' ...
                    'pasaron el Paso 1, con brecha decisiva (%.2f%%%% >= %.0f%%%%) sobre el 2o lugar (%s).'], ...
                    100*rel_gap, 100*SEP_MARGIN, sorted_names{2});
            else
                % -- Paso 3: plausibilidad economica del signo bajo Demanda --
                fprintf('  --- Paso 3 (desempate cualitativo): signo de ner bajo Demanda ---\n');
                fprintf('  Convencion: ner(+) = depreciacion (ERPT-Chat 12). Literatura (Forbes et\n');
                fprintf('  al. 2018; Manopimoke et al. 2024; Rincon-Castro et al. 2017) espera\n');
                fprintf('  apreciacion (ner<0, mediana) bajo Demanda via canal de tasa de interes.\n\n');

                cand = sorted_names(1:min(3, n_surv));   % top candidatos por Paso 2 como universo de desempate
                sign_ok = false(1, numel(cand));
                fprintf('  %-38s %14s %10s\n', 'spec', 'L_ner(Dem,h=12)', 'signo_ok?');
                for cc = 1:numel(cand)
                    sn = cand{cc};
                    L_dem = local_denom_level(Results_by_spec.(sn), Dataset_by_spec.(sn), Cfg_by_spec.(sn), 12);
                    med_L = median(L_dem);
                    sign_ok(cc) = med_L < 0;
                    fprintf('  %-38s %14.4f %10s\n', sn, med_L, V{int32(sign_ok(cc))+1});
                end
                fprintf('\n');

                idx_ok = find(sign_ok, 1);
                if ~isempty(idx_ok)
                    winner        = cand{idx_ok};
                    winner_step   = 3;
                    winner_reason = sprintf(['desempate del Paso 2 (brecha no decisiva, %.2f%% < %.0f%%) resuelto ' ...
                        'en el Paso 3: primera spec (por orden del Paso 2) con signo economicamente ' ...
                        'plausible de ner bajo Demanda (apreciacion).'], 100*rel_gap, 100*SEP_MARGIN);
                else
                    winner        = sorted_names{1};
                    winner_step   = 2;
                    winner_reason = sprintf(['Paso 3 no logro separar (ninguna de las %d candidatas mostro el ' ...
                        'signo esperado bajo Demanda) -- se retiene el orden del Paso 2, ganadora = menor ' ...
                        'ancho promedio combinado.'], numel(cand));
                end
            end
        end

        fprintf('  --- Paso 4 (chequeo de sanidad, no de ranking): consistencia entre horizontes de la ganadora ---\n');
        ERPT_w = ERPT_by_spec.(winner);
        names_w = {ERPT_w.shocks.name};
        flips_total = 0;
        for kk = 1:numel(NAMED_SHOCKS)
            k_idx = find(strcmp(names_w, NAMED_SHOCKS{kk}), 1);
            if isempty(k_idx), continue; end
            prices_arr = ERPT_w.shocks(k_idx).prices;
            for pp = 1:numel(prices_arr)
                med = prices_arr(pp).median;
                s = sign(med);
                s(s == 0) = 1;
                nflips = sum(diff(s) ~= 0);
                flips_total = flips_total + nflips;
                if nflips > 0
                    fprintf('  [nota] %s, choque %s, precio %s: %d cruce(s) de signo entre horizontes (mediana): %s\n', ...
                        winner, NAMED_SHOCKS{kk}, prices_arr(pp).var, nflips, mat2str(med, 3));
                end
            end
        end
        if flips_total == 0
            fprintf('  Sin cruces de signo erraticos en la mediana entre h=3 y h=36, en ningun choque/price_var.\n');
        end
        fprintf('\n');

        fprintf('  >> GANADORA: %s\n', winner);
        fprintf('  >> Decidida en: Paso %d\n', winner_step);
        fprintf('  >> Justificacion: %s\n\n', winner_reason);
    end
else
    fprintf('  [OMITIDO] Bloque 1 o 2 no pasaron -- no se aplica el criterio de seleccion.\n\n');
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('======================================================\n');
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 15\n');
fprintf('======================================================\n');
fprintf('  Bloque A (PCT operativo)                    : %s\n', iif_local(pct_ok || ~USE_PARALLEL, 'PASA', 'ADVERTENCIA (fallback secuencial)'));
fprintf('  Bloque 0 (Regresion BNW IS)                 : %s\n', iif_local(bloque0_pasa, 'PASA', 'NO PASA'));
fprintf('  Bloque 1 (16 specs @ ND=%-8g)             : %s\n', ND_TARGET, iif_local(bloque1_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 2 (Tabla maestra + Excel)             : %s\n', iif_local(bloque2_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 3 (Seleccion spec ganadora)           : %s\n', iif_local(bloque3_ok && ~isempty(winner), 'PASA', 'NO PASA'));
fprintf('------------------------------------------------------\n');
if bloque0_pasa && bloque1_ok && bloque2_ok && bloque3_ok && ~isempty(winner)
    fprintf('  GLOBAL : PASA\n');
    fprintf('  SPEC GANADORA : %s (Paso %d)\n', winner, winner_step);
    if ~isempty(warn_low_ne)
        fprintf('  (con %d spec(s) en BANDAS INDICATIVAS por ne bajo -- ver Bloque 1)\n', numel(warn_low_ne));
    end
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% ── Helpers locales ---------------------------------------------------------

function out = iif_local(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

function out = local_run_spec(spec_name, PROJ_CFG, USE_CACHE, ND_TARGET)
%LOCAL_RUN_SPEC  Carga (cache-first) o corre una spec a ND_TARGET.
%   Disenado para ejecutarse identico dentro de un cuerpo `for` o `parfor`
%   -- cada llamada resetea su propio stream de RNG antes de invocar
%   run_is (ver nota RNG en el encabezado de este archivo), por lo que el
%   resultado es identico sin importar el orden de ejecucion o el worker
%   que la procese.

    if contains(spec_name, '_aa_')
        transform_type = 'aa';
    else
        transform_type = 'mm';
    end

    out = struct('spec_name', spec_name, 'ok', true, 'err_msg', '', ...
        'used_cache', false, 'transform', transform_type, ...
        'Results', [], 'Dataset', [], 'Cfg', [], 'ERPT', [], ...
        'stable_frac', NaN, 'accept_rate', NaN, 'ne', NaN);

    try
        Cfg = struct();
        run(fullfile(PROJ_CFG, [spec_name '.m']));
        Cfg.PLOT_IRFS    = false;
        Cfg.SAVE_RESULTS = false;

        cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
        used_cache = false;
        Results_spec = []; ERPT_spec = []; Dataset_spec = [];

        if USE_CACHE && isfile(cache_path)
            try
                [Results_spec, ERPT_spec, Dataset_spec, Cfg_cached] = load_erpt_run(Cfg.OUTPUT_DIR);
                nd_cached = NaN;
                if isfield(Cfg_cached, 'ND'), nd_cached = Cfg_cached.ND; end
                if ~isnan(nd_cached) && nd_cached >= ND_TARGET
                    used_cache = true;
                    Cfg = Cfg_cached;
                end
            catch
                used_cache = false;
            end
        end

        if ~used_cache
            Cfg.ND = ND_TARGET;
            Dataset_spec = load_data(Cfg);
            validate_cfg(Cfg, Dataset_spec);
            Posterior_spec = build_posterior(Dataset_spec, Cfg);

            % -- RESET DETERMINISTA POR SPEC (ver nota RNG del encabezado) --
            rng('default'); rng(Cfg.SEED);
            tic;
            Results_spec = run_is(Posterior_spec, Cfg);
            Results_spec.t_elapsed = toc;

            ERPT_spec = calculate_erpt(Results_spec, Dataset_spec, Cfg, transform_type);
            save_erpt_run(Results_spec, ERPT_spec, Dataset_spec, Cfg);
        end

        % -- Diagnosticos que requieren los draws crudos (Results.Bdraws) --
        %    Deben calcularse ANTES de aligerar Results_spec para el
        %    retorno -- ya quedaron persistidos en disco via save_erpt_run
        %    (o ya estaban persistidos, si vino de cache).
        stable_frac = check_stability(Results_spec, Cfg);
        accept_rate = sum(Results_spec.uw > 0) / Cfg.ND;
        ne_val      = Results_spec.ne;

        % -- Aligerar antes de devolver del worker/iteracion (ver nota de
        %    memoria del encabezado) -- Bdraws/Sigmadraws/Qdraws de tamano
        %    ND ya estan en <OUTPUT_DIR>/results_is.mat, no se pierden.
        Results_light = rmfield(Results_spec, {'Bdraws', 'Sigmadraws', 'Qdraws'});

        out.used_cache  = used_cache;
        out.Results     = Results_light;
        out.Dataset     = Dataset_spec;
        out.Cfg         = Cfg;
        out.ERPT        = ERPT_spec;
        out.stable_frac = stable_frac;
        out.accept_rate = accept_rate;
        out.ne          = ne_val;

    catch ME
        out.ok      = false;
        out.err_msg = ME.message;
    end
end

function L = local_denom_level(Results, Dataset, Cfg, h_target)
%LOCAL_DENOM_LEVEL  Nivel acumulado L_ner(h_target) por draw, para el
%   choque 'Dem', replicando la logica de p_accumulate de calculate_erpt.m
%   (no exportada por ese archivo). Usado solo para el desempate del Paso
%   3 (signo de ner bajo Demanda) -- no reemplaza ni recalcula el ERPT
%   oficial, que sigue viniendo integramente de calculate_erpt.m.

    endo_mask = strcmp(Dataset.var_roles, 'endogenous');
    var_names = Dataset.var_names(endo_mask);
    denom_var = 'ner';
    if isfield(Cfg, 'ERPT_DENOM_VAR') && ~isempty(Cfg.ERPT_DENOM_VAR)
        denom_var = Cfg.ERPT_DENOM_VAR;
    end
    denom_idx = find(strcmp(var_names, denom_var), 1);

    shock_names = {};
    if isfield(Cfg, 'SHOCK_NAMES') && ~isempty(Cfg.SHOCK_NAMES)
        shock_names = Cfg.SHOCK_NAMES;
    end
    [irfs_by_shock, ~, ~, shock_idx_resolved] = ...
        select_irfs(Results.LtildeStruct, 'all', denom_idx, shock_names);

    names_resolved = cell(1, numel(shock_idx_resolved));
    for i = 1:numel(shock_idx_resolved)
        names_resolved{i} = resolve_shock_name(shock_names, shock_idx_resolved(i));
    end
    j = find(strcmp(names_resolved, 'Dem'), 1);
    if isempty(j)
        error('local_denom_level:demNotFound', 'Choque Dem no encontrado.');
    end
    irf_slice = irfs_by_shock{j};   % [horizon+1 x 1 x ndraws]

    transform_type = 'mm';
    % NLAG-agnostic: usamos Dataset.freq para decidir el rezago si aa
    if isfield(Cfg, 'DATA_FILE') && contains(Cfg.DATA_FILE, 'aa')
        transform_type = 'aa';
    end

    if strcmp(transform_type, 'mm')
        Lfull = compute_cirfs(irf_slice);
    else
        lag = 12;
        H = size(irf_slice, 1);
        Lfull = zeros(size(irf_slice));
        for h = 1:H
            if h <= lag
                Lfull(h, 1, :) = irf_slice(h, 1, :);
            else
                Lfull(h, 1, :) = irf_slice(h, 1, :) + Lfull(h - lag, 1, :);
            end
        end
    end

    h_idx = h_target + 1;
    L = reshape(Lfull(h_idx, 1, :), 1, []);
end
