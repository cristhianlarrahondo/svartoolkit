%VALIDATE_ERPT17  ERPT-Chat 17 -- Ejercicio B: ToT (Terms of Trade) como
%   robustez sobre la spec ganadora del Ejercicio A. Disenio metodologico
%   cerrado en ERPT-Chat 6 (Discusion, APROBADO, decision D6).
%
%   Tipo S. No toca run_is.m / build_posterior.m / load_data.m -- la
%   spec_B_rob_aa_diffuse_lag4_tot_v0.m es pura construccion de
%   Cfg.VARS/Cfg.S/Cfg.Z (post-procesamiento de config), verificado en el
%   propio archivo de la spec y confirmado por D1 de ERPT-Chat 6.
%
%   CACHE-FIRST (no cache-only): a diferencia de validate_erpt16.m, este
%   script SI corre una estimacion nueva si no existe cache valido a
%   ND_TARGET para la spec de ToT -- es la primera vez que esta spec se
%   estima. Reusa el patron cache-first ya establecido en
%   local_run_spec() de validate_erpt15.m (mismo reset de RNG
%   `rng('default'); rng(Cfg.SEED)` inmediatamente antes de run_is).
%
%   La spec ganadora (WIN_SPEC) se lee EXCLUSIVAMENTE desde su cache ya
%   poblado a ND=1e6 (ERPT-Chat 15/16) -- este script NUNCA la re-estima.
%   Si ese cache no existe o esta por debajo de ND_TARGET, el script
%   detiene con un mensaje explicito senalando a validate_erpt15.m.
%
%   ── Resumen de bloques ──────────────────────────────────────────────────
%     BLOQUE 1 -- (a) Cache-first de la spec de ToT a ND_TARGET
%                 (b) Carga cache-only de la spec ganadora (referencia)
%     BLOQUE 2 -- Set completo de outputs para la spec de ToT (identico al
%                 estandar fijado en ERPT-Chat 14, decision 5, y aplicado
%                 en ERPT-Chat 16 a la ganadora):
%                 (a) diagnosticos (ne, tasa aceptacion, check_stability,
%                     diagnose_is_weights)
%                 (b) IRF + CIRF, bandas 68%/90%, Cam/Dem/Ofe x
%                     imp_inf/pro_inf/con_inf (consola + PNG + Excel)
%                 (c) FEVD, TODAS las variables endogenas (7, incluye tot)
%                 (d) ERPT, 5 horizontes de Cfg.ERPT_HORIZONS, bandas
%                     propias de la spec
%     BLOQUE 3 -- Comparacion informativa ToT vs. ganadora: tabla ERPT
%                 lado a lado (build_erpt_comparison.m) + diagnosticos de
%                 corrida (ne, tasa de aceptacion, fraccion estable). Esto
%                 es evidencia de ROBUSTEZ, no una cascada de seleccion --
%                 no reabre ninguna decision de ERPT-Chat 15.
%     VEREDICTO GLOBAL
%
%   Ejecutar COMPLETO (F5). Pegar el output de consola en el chat.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 17 -- Ejercicio B (ToT robustez)\n');
fprintf('======================================================\n\n');

%% ── Controles de corrida (editar aqui) ------------------------------------
USE_CACHE      = true;      % true = reusar <OUTPUT_DIR>/results_is.mat si ND cacheado >= ND_TARGET
ND_TARGET      = 1e6;       % ND objetivo (comparable al cache de la ganadora, ERPT-Chat 15/16)
WIN_SPEC       = 'spec_A_rob_aa_diffuse_lag4_v0';
TOT_SPEC       = 'spec_B_rob_aa_diffuse_lag4_tot_v0';
NAMED_SHOCKS   = {'Cam', 'Dem', 'Ofe'};
PRICE_VARS     = {'imp_inf', 'pro_inf', 'con_inf'};
NE_MIN         = 200;       % mismo umbral duro usado desde ERPT-Chat 8 (solo informativo aqui)
STABLE_FRAC_MIN = 0.70;     % mismo gate usado en Paso 1 de ERPT-Chat 15 (solo informativo aqui)
BAND_68_90     = [0.16 0.84;   % 68% bilateral
                   0.05 0.95]; % 90% bilateral -- SOLO para IRF/CIRF (objetivo Bloque 2b).
                                % El ERPT (Bloque 2d) se reporta con las
                                % bandas PROPIAS de la spec (Cfg.CRED_BANDS
                                % = [0.25 0.75], identicas a la ganadora).

fprintf('  USE_CACHE     : %d\n', USE_CACHE);
fprintf('  ND_TARGET     : %g\n', ND_TARGET);
fprintf('  WIN_SPEC (ref): %s\n', WIN_SPEC);
fprintf('  TOT_SPEC (new): %s\n\n', TOT_SPEC);

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
REF_VALIDATE  = fullfile(REF_ROOT, 'validate');

addpath(REF_SRC); addpath(REF_CFG_DIR); addpath(REF_HELP);
addpath(REF_VALIDATE); addpath(PROJ_CFG); addpath(PROJ_SRC);

V = {'FAIL', 'OK  '};

% =========================================================================
%  BLOQUE 1 -- (a) Cache-first ToT, (b) cache-only ganadora (referencia)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- Estimacion/carga de las 2 specs\n');
fprintf('======================================================\n\n');

bloque1_ok = true;
Results_tot = []; Dataset_tot = []; Cfg_tot = []; ERPT_tot = [];
Results_win = []; Dataset_win = []; Cfg_win = []; ERPT_win = [];

% -- (a) Spec de ToT: cache-first (corre desde cero si no hay cache valido) --
fprintf('  --- (a) %s (cache-first, ND_TARGET=%g) ---\n', TOT_SPEC, ND_TARGET);
try
    out_tot = local_run_spec(TOT_SPEC, PROJ_CFG, USE_CACHE, ND_TARGET);
    if ~out_tot.ok
        error('validate_erpt17:totSpecFailed', '%s', out_tot.err_msg);
    end
    Results_tot = out_tot.Results;
    Dataset_tot = out_tot.Dataset;
    Cfg_tot     = out_tot.Cfg;
    ERPT_tot    = out_tot.ERPT;

    fprintf('  used_cache      : %d\n', out_tot.used_cache);
    fprintf('  ne              : %d\n', out_tot.ne);
    fprintf('  tasa aceptacion : %.4f\n', out_tot.accept_rate);
    fprintf('  frac. estable   : %.4f  (gate informativo Paso 1 ERPT-Chat 15: >= %.2f)\n', ...
        out_tot.stable_frac, STABLE_FRAC_MIN);
    if out_tot.ne < NE_MIN
        fprintf('  [aviso] ne=%d < NE_MIN=%d.\n', out_tot.ne, NE_MIN);
    end
    if out_tot.stable_frac < STABLE_FRAC_MIN
        fprintf(['  [aviso] frac. estable %.4f < %.2f -- informativo unicamente (este\n' ...
                 '  chat no reabre el gate de seleccion de ERPT-Chat 15, que aplico solo\n' ...
                 '  al universo de 16 specs del Ejercicio A).\n'], out_tot.stable_frac, STABLE_FRAC_MIN);
    end
    fprintf('  >> BLOQUE 1(a): OK.\n\n');
catch ME
    bloque1_ok = false;
    fprintf('  [ERROR] %s\n', ME.message);
    fprintf('  >> BLOQUE 1(a): NO PASA.\n\n');
end

% -- (b) Spec ganadora: cache-only (referencia, NUNCA se re-estima aqui) ----
fprintf('  --- (b) %s (cache-only, referencia) ---\n', WIN_SPEC);
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [WIN_SPEC '.m']));
    cache_path_win = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
    if ~isfile(cache_path_win)
        error('validate_erpt17:winnerCacheMissing', ...
            'No existe %s. Ejecuta primero validate_erpt15.m (Bloque 1) / validate_erpt16.m para poblar el cache de la ganadora.', ...
            cache_path_win);
    end
    peek_win = load(cache_path_win, 'Cfg');
    nd_cached_win = NaN;
    if isfield(peek_win, 'Cfg') && isfield(peek_win.Cfg, 'ND')
        nd_cached_win = peek_win.Cfg.ND;
    end
    if isnan(nd_cached_win) || nd_cached_win < ND_TARGET
        error('validate_erpt17:winnerCacheStale', ...
            'Cache de la ganadora a ND=%g < ND_TARGET=%g. Ejecuta validate_erpt15.m (Bloque 1) para actualizarlo.', ...
            nd_cached_win, ND_TARGET);
    end

    [Results_win, ERPT_win, Dataset_win, Cfg_win] = load_erpt_run(Cfg.OUTPUT_DIR);
    fprintf('  ND cacheado : %g\n', nd_cached_win);
    fprintf('  ne          : %d\n', Results_win.ne);
    fprintf('  >> BLOQUE 1(b): OK.\n\n');
catch ME
    bloque1_ok = false;
    fprintf('  [ERROR] %s\n', ME.message);
    fprintf('  >> BLOQUE 1(b): NO PASA.\n\n');
end

if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA.\n\n');
else
    fprintf('  >> BLOQUE 1: NO PASA -- no se puede continuar de forma confiable.\n\n');
end

% =========================================================================
%  BLOQUE 2 -- Set completo de outputs para la spec de ToT
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Outputs completos: %s\n', TOT_SPEC);
fprintf('======================================================\n\n');

bloque2_ok = true;
try
    if isempty(Results_tot)
        error('validate_erpt17:bloque1aFailed', 'Bloque 1(a) no paso -- no hay resultados de ToT que reportar.');
    end

    endo_mask_tot = strcmp(Dataset_tot.var_roles, 'endogenous');
    var_names_tot = Dataset_tot.var_names(endo_mask_tot);

    price_idx_tot = zeros(1, numel(PRICE_VARS));
    for i = 1:numel(PRICE_VARS)
        price_idx_tot(i) = find(strcmp(var_names_tot, PRICE_VARS{i}), 1);
    end
    shock_idx_tot = zeros(1, numel(NAMED_SHOCKS));
    for i = 1:numel(NAMED_SHOCKS)
        shock_idx_tot(i) = find(strcmp(Cfg_tot.SHOCK_NAMES, NAMED_SHOCKS{i}), 1);
    end

    % ── (a) Diagnosticos ────────────────────────────────────────────────
    % NOTA (hallazgo de la 1a corrida): check_stability/diagnose_is_weights
    % necesitan Results.Bdraws crudo, que local_run_spec() ya aligero
    % (rmfield) antes de devolver Results_tot -- llamarlos de nuevo aqui
    % falla con "Results no contiene campo .Bdraws". Se reportan los
    % valores YA CALCULADOS en Bloque 1(a) (antes de aligerar, dentro de
    % local_run_spec), sin volver a invocar ninguna funcion sobre el
    % struct liviano.
    fprintf('  --- (a) Diagnosticos de corrida ---\n');
    ne_tot          = Results_tot.ne;
    accept_rate_tot = sum(Results_tot.uw > 0) / Cfg_tot.ND;
    fprintf('  ne (draws efectivos)      : %d\n', ne_tot);
    fprintf('  Tasa de aceptacion        : %.4f\n', accept_rate_tot);
    fprintf('  Fraccion draws estables   : %.4f (calculado en Bloque 1a, ver detalle arriba)\n', out_tot.stable_frac);
    fprintf('  Fraccion peso IS en top-5%%: %.4f (calculado en Bloque 1a, ver detalle Pareto-k arriba)\n\n', out_tot.frac_top);

    % ── (b) IRF + CIRF, bandas 68%/90%, 3 choques x 3 price_vars ────────
    fprintf('  --- (b) IRF + CIRF (bandas 68%%/90%%, Cam/Dem/Ofe x imp_inf/pro_inf/con_inf; consola + PNG + Excel) ---\n');
    Cfg_disp             = Cfg_tot;
    Cfg_disp.CRED_BANDS  = BAND_68_90;
    Cfg_disp.SHOCK_IDX   = shock_idx_tot;
    Cfg_disp.RESP_IDX    = price_idx_tot;
    Cfg_disp.SUMMARY_HORIZONS = Cfg_tot.ERPT_HORIZONS;

    print_summary(Results_tot.LtildeStruct, Dataset_tot, Cfg_disp);
    local_print_cirf_digest(Results_tot.LtildeStruct, Dataset_tot, Cfg_disp);

    % Figuras PNG individuales IRF/CIRF (precedente ERPT-Chat 5/16: no
    % olvidar esta llamada).
    plot_irfs(Results_tot.LtildeStruct, Dataset_tot, Cfg_disp, Results_tot);

    % Excel completo (IRF+CIRF+FEVD+diagnosticos), bandas 68/90.
    export_results(Results_tot, Dataset_tot, Cfg_disp);
    fprintf('\n');

    % ── (c) FEVD, TODAS las variables endogenas (7, incluye tot) ────────
    % ERPT-Chat 14 decision 5 / bug de ERPT-Chat 16: el filtro a 3
    % price_vars aplica SOLO a IRF/CIRF, NUNCA a FEVD -- sin RESP_IDX,
    % default = todas las endogenas.
    fprintf('  --- (c) FEVD (las 7 variables endogenas, incluye tot) ---\n');
    plot_fevd(Results_tot, Dataset_tot, Cfg_tot);
    fprintf('\n');

    % ── (d) ERPT, 5 horizontes, bandas propias ──────────────────────────
    fprintf('  --- (d) ERPT -- %s (bandas propias [%.2f, %.2f]) ---\n', ...
        TOT_SPEC, ERPT_tot.cred_bands(1,1), ERPT_tot.cred_bands(1,2));
    local_print_erpt_digest(ERPT_tot, NAMED_SHOCKS, PRICE_VARS);

    fprintf('  >> BLOQUE 2: PASA.\n\n');
catch ME
    bloque2_ok = false;
    fprintf('  [ERROR] %s\n', ME.message);
    fprintf('  >> BLOQUE 2: NO PASA.\n\n');
end

% =========================================================================
%  BLOQUE 3 -- Comparacion informativa ToT vs. ganadora
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- ToT vs. ganadora (evidencia de robustez)\n');
fprintf('======================================================\n\n');

bloque3_ok = true;
try
    if isempty(Results_tot) || isempty(Results_win)
        error('validate_erpt17:bloque1Failed', 'Bloque 1 no paso completo -- no se puede comparar.');
    end

    fprintf('  --- Diagnosticos de corrida, lado a lado ---\n');
    fprintf('  %-38s %8s %10s\n', 'spec', 'ne', 'accept_r');
    fprintf('  %-38s %8d %10.4f\n', WIN_SPEC, Results_win.ne, sum(Results_win.uw > 0) / Cfg_win.ND);
    fprintf('  %-38s %8d %10.4f\n\n', TOT_SPEC, Results_tot.ne, sum(Results_tot.uw > 0) / Cfg_tot.ND);

    ERPT_by_spec    = struct();
    Results_by_spec = struct();
    Cfg_by_spec     = struct();
    ERPT_by_spec.(WIN_SPEC)    = ERPT_win;
    ERPT_by_spec.(TOT_SPEC)    = ERPT_tot;
    Results_by_spec.(WIN_SPEC) = Results_win;
    Results_by_spec.(TOT_SPEC) = Results_tot;
    Cfg_by_spec.(WIN_SPEC)     = Cfg_win;
    Cfg_by_spec.(TOT_SPEC)     = Cfg_tot;

    [T_erpt, T_diag] = build_erpt_comparison(ERPT_by_spec, Results_by_spec, Cfg_by_spec, ...
        {WIN_SPEC, TOT_SPEC}, NAMED_SHOCKS);

    fprintf('  Tabla comparativa ERPT (T_erpt): %d filas (choque x price_var x horizonte)\n\n', height(T_erpt));

    comparison_dir = fullfile(PROJ_ROOT, 'output', 'comparison');
    if ~isfolder(comparison_dir), mkdir(comparison_dir); end
    xlsx_path = fullfile(comparison_dir, 'erpt17_tot_vs_ganadora.xlsx');
    if isfile(xlsx_path), delete(xlsx_path); end
    writetable(T_erpt, xlsx_path, 'Sheet', 'erpt_comparison');
    writetable(T_diag, xlsx_path, 'Sheet', 'run_diagnostics');
    fprintf('  Comparacion exportada (2 hojas) a:\n    %s\n\n', xlsx_path);

    fprintf(['  Nota: esta comparacion es evidencia de ROBUSTEZ (?como cambia el ERPT\n' ...
             '  y la precision de la identificacion al agregar tot?), NO una cascada de\n' ...
             '  seleccion -- no reabre ninguna decision cerrada en ERPT-Chat 15.\n\n']);

    fprintf('  >> BLOQUE 3: PASA.\n\n');
catch ME
    bloque3_ok = false;
    fprintf('  [ERROR] %s\n', ME.message);
    fprintf('  >> BLOQUE 3: NO PASA.\n\n');
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('======================================================\n');
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 17\n');
fprintf('======================================================\n');
fprintf('  Bloque 1 (estimacion/carga ToT + ganadora)   : %s\n', V{int32(bloque1_ok)+1});
fprintf('  Bloque 2 (outputs completos, spec ToT)       : %s\n', V{int32(bloque2_ok)+1});
fprintf('  Bloque 3 (comparacion ToT vs. ganadora)       : %s\n', V{int32(bloque3_ok)+1});
fprintf('------------------------------------------------------\n');
if bloque1_ok && bloque2_ok && bloque3_ok
    fprintf('  GLOBAL : PASA\n');
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% ── Helpers locales ---------------------------------------------------------

function out = local_run_spec(spec_name, PROJ_CFG, USE_CACHE, ND_TARGET)
%LOCAL_RUN_SPEC  Carga (cache-first) o corre una spec a ND_TARGET.
%   Identico al helper de mismo nombre en validate_erpt15.m -- reset
%   determinista de RNG por spec (`rng('default'); rng(Cfg.SEED)`)
%   inmediatamente antes de run_is.

    if contains(spec_name, '_aa_')
        transform_type = 'aa';
    else
        transform_type = 'mm';
    end

    out = struct('spec_name', spec_name, 'ok', true, 'err_msg', '', ...
        'used_cache', false, 'transform', transform_type, ...
        'Results', [], 'Dataset', [], 'Cfg', [], 'ERPT', [], ...
        'stable_frac', NaN, 'accept_rate', NaN, 'ne', NaN, 'frac_top', NaN);

    try
        Cfg = struct();
        run(fullfile(PROJ_CFG, [spec_name '.m']));

        cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
        used_cache = false;
        Results_spec = []; ERPT_spec = []; Dataset_spec = [];

        if USE_CACHE && isfile(cache_path)
            try
                peek = load(cache_path, 'Cfg');
                nd_cached = NaN;
                if isfield(peek, 'Cfg') && isfield(peek.Cfg, 'ND')
                    nd_cached = peek.Cfg.ND;
                end
                if ~isnan(nd_cached) && nd_cached >= ND_TARGET
                    [Results_spec, ERPT_spec, Dataset_spec, Cfg_cached] = load_erpt_run(Cfg.OUTPUT_DIR);
                    used_cache = true;
                    Cfg = Cfg_cached;
                else
                    fprintf('  [%s] cache a ND=%g < objetivo ND=%g -- recalculando desde cero (no se carga el .mat completo).\n', ...
                        spec_name, nd_cached, ND_TARGET);
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

            % -- RESET DETERMINISTA POR SPEC --
            rng('default'); rng(Cfg.SEED);
            tic;
            Results_spec = run_is(Posterior_spec, Cfg);
            Results_spec.t_elapsed = toc;

            ERPT_spec = calculate_erpt(Results_spec, Dataset_spec, Cfg, transform_type);
            save_erpt_run(Results_spec, ERPT_spec, Dataset_spec, Cfg);
        end

        % -- Diagnosticos que requieren los draws crudos (Results.Bdraws) --
        %    DEBEN calcularse ANTES de aligerar Results_spec para el
        %    retorno -- una vez aligerado, ningun bloque posterior de este
        %    script (incluido Bloque 2a) puede volver a llamar
        %    check_stability/diagnose_is_weights sobre el struct devuelto
        %    (hallazgo de la 1a corrida: "Results no contiene campo
        %    .Bdraws" -- ya estan persistidos en <OUTPUT_DIR>/results_is.mat
        %    si se necesitan de nuevo, pero no viajan en el struct liviano).
        stable_frac = check_stability(Results_spec, Cfg);
        frac_top    = diagnose_is_weights(Results_spec, Cfg);
        accept_rate = sum(Results_spec.uw > 0) / Cfg.ND;
        ne_val      = Results_spec.ne;

        % -- Aligerar antes de devolver (Bdraws/Sigmadraws/Qdraws ya estan
        %    persistidos en <OUTPUT_DIR>/results_is.mat) --
        Results_light = rmfield(Results_spec, {'Bdraws', 'Sigmadraws', 'Qdraws'});

        out.used_cache  = used_cache;
        out.Results     = Results_light;
        out.Dataset     = Dataset_spec;
        out.Cfg         = Cfg;
        out.ERPT        = ERPT_spec;
        out.stable_frac = stable_frac;
        out.accept_rate = accept_rate;
        out.ne          = ne_val;
        out.frac_top    = frac_top;

    catch ME
        out.ok      = false;
        out.err_msg = ME.message;
    end
end

function local_print_cirf_digest(LtildeStruct, Dataset, Cfg)
%LOCAL_PRINT_CIRF_DIGEST  Digesto de consola para CIRF (identico al helper
%   de mismo nombre en validate_erpt16.m -- print_summary.m no soporta
%   CIRF directamente).

    cred_bands = [0.16 0.84];
    if isfield(Cfg, 'CRED_BANDS') && ~isempty(Cfg.CRED_BANDS)
        cred_bands = Cfg.CRED_BANDS;
    end
    n_bands = size(cred_bands, 1);

    shock_idx_req = LtildeStruct.shock_idx;
    if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
        shock_idx_req = Cfg.SHOCK_IDX;
    end
    response_idx = 1:LtildeStruct.nvar;
    if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
        response_idx = Cfg.RESP_IDX;
    end
    shock_names = {};
    if isfield(Cfg, 'SHOCK_NAMES') && ~isempty(Cfg.SHOCK_NAMES)
        shock_names = Cfg.SHOCK_NAMES;
    end
    summary_horizons = [0 4 8 20 40];
    if isfield(Cfg, 'SUMMARY_HORIZONS') && ~isempty(Cfg.SUMMARY_HORIZONS)
        summary_horizons = Cfg.SUMMARY_HORIZONS;
    end

    endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
    all_labels = Dataset.var_labels(endo_mask);
    LtildeStruct.var_labels = all_labels;

    [irfs_by_shock, label_shock_arr, label_resp, shock_idx_resolved] = ...
        select_irfs(LtildeStruct, shock_idx_req, response_idx, shock_names);

    horizon_max = LtildeStruct.horizon;
    h_valid = summary_horizons(summary_horizons >= 0 & summary_horizons <= horizon_max);
    h_idx   = h_valid + 1;
    nh      = numel(h_idx);
    n_shocks = numel(shock_idx_resolved);

    sep_wide = repmat('=', 1, 72);
    sep_thin = repmat('-', 1, 72);

    for j = 1:n_shocks
        cirfs_j = compute_cirfs(irfs_by_shock{j});
        nresp   = size(cirfs_j, 2);

        fprintf('\n%s\n', sep_wide);
        fprintf('  CIRF SUMMARY (digesto)   Shock: %s\n', label_shock_arr{j});
        fprintf('%s\n', sep_wide);

        band_hdr = '';
        for bb = 1:n_bands
            band_hdr = [band_hdr, sprintf('  [p%.0f, p%.0f]         ', ...
                cred_bands(bb,1)*100, cred_bands(bb,2)*100)]; %#ok<AGROW>
        end
        fprintf('  %-20s  h   %8s  %s\n', 'Respuesta', 'Mediana', strtrim(band_hdr));
        fprintf('%s\n', sep_thin);

        for jj = 1:nresp
            for ii = 1:nh
                sl = squeeze(cirfs_j(h_idx(ii), jj, :));
                med_val = quantile(sl, 0.50);
                band_str = '';
                for bb = 1:n_bands
                    q = quantile(sl, cred_bands(bb, :));
                    band_str = [band_str, sprintf('  [%8.4f, %8.4f]', q(1), q(2))]; %#ok<AGROW>
                end
                if ii == 1
                    fprintf('  %-20s  %2d  %8.4f%s\n', label_resp{jj}, h_valid(ii), med_val, band_str);
                else
                    fprintf('  %-20s  %2d  %8.4f%s\n', '', h_valid(ii), med_val, band_str);
                end
            end
            fprintf('%s\n', sep_thin);
        end
    end
    fprintf('\n');
end

function local_print_erpt_digest(ERPT, named_shocks, price_vars)
%LOCAL_PRINT_ERPT_DIGEST  Digesto de consola de ERPT.shocks (identico al
%   helper de mismo nombre en validate_erpt16.m).
    names_all = {ERPT.shocks.name};
    horizons  = ERPT.horizons;

    for kk = 1:numel(named_shocks)
        k_idx = find(strcmp(names_all, named_shocks{kk}), 1);
        if isempty(k_idx)
            fprintf('  [aviso] choque %s no encontrado en ERPT.shocks.\n', named_shocks{kk});
            continue;
        end
        prices_arr = ERPT.shocks(k_idx).prices;
        pvar_names = {prices_arr.var};

        fprintf('  Choque: %s\n', named_shocks{kk});
        for pp = 1:numel(price_vars)
            p_idx = find(strcmp(pvar_names, price_vars{pp}), 1);
            if isempty(p_idx)
                fprintf('    [aviso] price_var %s no encontrada.\n', price_vars{pp});
                continue;
            end
            fprintf('    %-10s', price_vars{pp});
            for hh = 1:numel(horizons)
                fprintf('  h=%-2d: %7.3f [%6.3f, %6.3f]', horizons(hh), ...
                    prices_arr(p_idx).median(hh), ...
                    prices_arr(p_idx).band_lo(1, hh), prices_arr(p_idx).band_hi(1, hh));
            end
            fprintf('\n');
        end
        fprintf('\n');
    end
end
