%VALIDATE_ERPT16  ERPT-Chat 16 -- Set completo de outputs para la spec
%   ganadora del Ejercicio A (spec_A_rob_aa_diffuse_lag4_v0, decidida en
%   ERPT-Chat 15, Paso 2 de la cascada de 4 pasos) + anexo de robustez con
%   las 15 specs restantes, en formato largo/tidy.
%
%   Tipo S. No toca run_is.m / build_posterior.m / load_data.m. CACHE-ONLY:
%   este script NO recorre ninguna estimacion -- lee integramente desde
%   <OUTPUT_DIR>/results_is.mat (poblado a ND=1e6 en ERPT-Chat 15). Si el
%   cache de alguna de las 16 specs no existe o quedo por debajo de
%   ND_TARGET, el bloque correspondiente marca NO PASA con un mensaje
%   explicito seniendo al usuario a re-ejecutar el Bloque 1 de
%   validate_erpt15.m para esa spec -- este script no la recalcula.
%
%   ── Resumen de bloques ──────────────────────────────────────────────────
%     BLOQUE 1 -- Carga cache-only de las 16 specs oficiales del Ejercicio A
%     BLOQUE 2 -- Deep-dive de la spec ganadora:
%                 (a) diagnosticos (ne, tasa aceptacion, frac. estable, Pareto-k)
%                 (b) IRF + CIRF, bandas 68%/90%, 3 choques x 3 price_vars
%                     (digesto compacto en consola + figuras PNG + Excel)
%                 (c) FEVD (plot_fevd, TODAS las variables endogenas --
%                     ERPT-Chat 14 decision 5: el filtro a 3 price_vars
%                     aplica solo a IRF/CIRF, no a FEVD -- mismos horizontes
%                     de estimacion)
%                 (d) ERPT, 5 horizontes de Cfg.ERPT_HORIZONS (bandas propias
%                     de la spec, sin cambiar -- ya fijadas al cachear)
%     BLOQUE 3 -- Anexo de robustez: tabla larga/tidy (16 specs, 3 choques,
%                 3 price_vars, 5 horizontes) + notas de exclusion con
%                 evidencia numerica (anchos de banda 68%/90% recalculados
%                 desde ratio_draws cacheados, sin re-estimar nada)
%     VEREDICTO GLOBAL
%
%   Ejecutar COMPLETO (F5). Pegar el output de consola en el chat.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 16 -- outputs ganadora + anexo\n');
fprintf('======================================================\n\n');

%% ── Controles de corrida (editar aqui) ------------------------------------
ND_TARGET      = 1e6;      % ND objetivo cacheado (ERPT-Chat 15)
WIN_SPEC       = 'spec_A_rob_aa_diffuse_lag4_v0';
NAMED_SHOCKS   = {'Cam', 'Dem', 'Ofe'};
PRICE_VARS     = {'imp_inf', 'pro_inf', 'con_inf'};
BAND_68_90     = [0.16 0.84;   % 68% bilateral
                   0.05 0.95]; % 90% bilateral -- usadas SOLO para IRF/CIRF/
                                % anexo de robustez (objetivo 1 y 3 de este
                                % chat). El ERPT de la ganadora (objetivo 2)
                                % se reporta con las bandas PROPIAS de la
                                % spec (Cfg.CRED_BANDS = [0.25 0.75], ya
                                % fijadas al cachear en ERPT-Chat 15) -- no
                                % se recalculan, para mantener consistencia
                                % con la tabla maestra de 16 specs.
% -- Shocks/price_vars usados para el desempate de anchos de banda del
%    anexo (mismo criterio de Paso 2 de ERPT-Chat 14/15) --
BAND_SHOCKS_W    = {'Cam', 'Dem', 'Ofe'};
BAND_PRICEVARS_W = {'imp_inf', 'con_inf'};

fprintf('  ND_TARGET       : %g\n', ND_TARGET);
fprintf('  WIN_SPEC        : %s\n', WIN_SPEC);
fprintf('  Bandas IRF/CIRF : 68%% y 90%% (recalculadas ad-hoc, sin re-estimar)\n');
fprintf('  Bandas ERPT     : propias de cada spec (sin cambiar)\n\n');

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

% -- Los 16 specs OFICIALES del Ejercicio A (identico a validate_erpt15.m) --
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

if ~ismember(WIN_SPEC, spec_names)
    error('validate_erpt16:winnerNotInUniverse', ...
        'WIN_SPEC=''%s'' no esta en el universo de 16 specs oficiales.', WIN_SPEC);
end

% =========================================================================
%  BLOQUE 1 -- Carga cache-only de las 16 specs
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- Carga cache-only (ND>=%g) de 16 specs\n', ND_TARGET);
fprintf('======================================================\n\n');

Results_by_spec = struct();
Dataset_by_spec = struct();
Cfg_by_spec     = struct();
ERPT_by_spec    = struct();
ok_v            = false(1, n_specs);
nd_cached_v     = nan(1, n_specs);
err_msgs        = {};

for ss = 1:n_specs
    sn = spec_names{ss};
    try
        clear Cfg;
        Cfg = struct();
        run(fullfile(PROJ_CFG, [sn '.m']));
        cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');

        if ~isfile(cache_path)
            error('validate_erpt16:noCache', ...
                'No existe %s. Ejecuta primero validate_erpt15.m (Bloque 1) para esta spec.', cache_path);
        end
        peek = load(cache_path, 'Cfg');
        nd_cached = NaN;
        if isfield(peek, 'Cfg') && isfield(peek.Cfg, 'ND')
            nd_cached = peek.Cfg.ND;
        end
        nd_cached_v(ss) = nd_cached;
        if isnan(nd_cached) || nd_cached < ND_TARGET
            error('validate_erpt16:staleCache', ...
                'Cache a ND=%g < objetivo ND=%g. Ejecuta validate_erpt15.m (Bloque 1) para actualizarlo.', ...
                nd_cached, ND_TARGET);
        end

        [Results_ss, ERPT_ss, Dataset_ss, Cfg_ss] = load_erpt_run(Cfg.OUTPUT_DIR);

        % -- Chequeos estructurales minimos (mismo criterio que validate_erpt15) --
        names_out = {ERPT_ss.shocks.name};
        if ~all(ismember(NAMED_SHOCKS, names_out))
            error('validate_erpt16:missingNamedShocks', ...
                'Faltan choques nombrados en ERPT.shocks: se esperaban %s, disponibles %s.', ...
                strjoin(NAMED_SHOCKS, ','), strjoin(names_out, ','));
        end
        if Results_ss.ne <= 0
            error('validate_erpt16:zeroNe', 'ne=%d (sin draws efectivos).', Results_ss.ne);
        end

        Results_by_spec.(sn) = Results_ss;
        Dataset_by_spec.(sn) = Dataset_ss;
        Cfg_by_spec.(sn)     = Cfg_ss;
        ERPT_by_spec.(sn)    = ERPT_ss;
        ok_v(ss) = true;

        fprintf('  [%2d/%d] %-38s ND_cache=%-8g ne=%-6d %s\n', ...
            ss, n_specs, sn, nd_cached, Results_ss.ne, V{2});
    catch ME
        err_msgs{end+1} = sprintf('%s: %s', sn, ME.message); %#ok<AGROW>
        fprintf('  [%2d/%d] %-38s %s -- %s\n', ss, n_specs, sn, V{1}, ME.message);
    end
end
fprintf('\n');

bloque1_ok = all(ok_v);
if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- las 16 specs cargadas desde cache a ND>=%g.\n\n', ND_TARGET);
else
    fprintf('  >> BLOQUE 1: NO PASA. %d/%d specs con cache faltante/desactualizado:\n', ...
        sum(~ok_v), n_specs);
    for i = 1:numel(err_msgs)
        fprintf('     - %s\n', err_msgs{i});
    end
    fprintf('\n');
end

if ~ok_v(strcmp(spec_names, WIN_SPEC))
    error('validate_erpt16:winnerCacheMissing', ...
        'La spec ganadora (%s) no tiene cache valido -- no se puede continuar. Ver Bloque 1 arriba.', WIN_SPEC);
end

% =========================================================================
%  BLOQUE 2 -- Deep-dive de la spec ganadora
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Outputs completos: %s\n', WIN_SPEC);
fprintf('======================================================\n\n');

bloque2_ok = true;
try
    Results_w = Results_by_spec.(WIN_SPEC);
    Dataset_w = Dataset_by_spec.(WIN_SPEC);
    Cfg_w     = Cfg_by_spec.(WIN_SPEC);
    ERPT_w    = ERPT_by_spec.(WIN_SPEC);

    endo_mask_w = strcmp(Dataset_w.var_roles, 'endogenous');
    var_names_w = Dataset_w.var_names(endo_mask_w);

    price_idx_w = zeros(1, numel(PRICE_VARS));
    for i = 1:numel(PRICE_VARS)
        price_idx_w(i) = find(strcmp(var_names_w, PRICE_VARS{i}), 1);
    end
    shock_idx_w = zeros(1, numel(NAMED_SHOCKS));
    for i = 1:numel(NAMED_SHOCKS)
        shock_idx_w(i) = find(strcmp(Cfg_w.SHOCK_NAMES, NAMED_SHOCKS{i}), 1);
    end

    % ── (a) Diagnosticos ────────────────────────────────────────────────
    fprintf('  --- (a) Diagnosticos de corrida ---\n');
    ne_w          = Results_w.ne;
    accept_rate_w = sum(Results_w.uw > 0) / Cfg_w.ND;
    fprintf('  ne (draws efectivos)   : %d\n', ne_w);
    fprintf('  Tasa de aceptacion     : %.4f\n', accept_rate_w);

    stable_frac_w = check_stability(Results_w, Cfg_w);
    frac_top_w    = diagnose_is_weights(Results_w, Cfg_w);
    fprintf('  (ver detalle de check_stability / diagnose_is_weights arriba)\n\n');

    % ── (b) IRF + CIRF, bandas 68%/90%, 3 choques x 3 price_vars ────────
    fprintf('  --- (b) IRF + CIRF (bandas 68%%/90%%, Cam/Dem/Ofe x imp_inf/pro_inf/con_inf; consola + PNG + Excel) ---\n');
    Cfg_disp             = Cfg_w;
    Cfg_disp.CRED_BANDS  = BAND_68_90;
    Cfg_disp.SHOCK_IDX   = shock_idx_w;
    Cfg_disp.RESP_IDX    = price_idx_w;
    Cfg_disp.SUMMARY_HORIZONS = Cfg_w.ERPT_HORIZONS;   % digesto compacto (Chat 10, decision)

    print_summary(Results_w.LtildeStruct, Dataset_w, Cfg_disp);
    local_print_cirf_digest(Results_w.LtildeStruct, Dataset_w, Cfg_disp);

    % Figuras PNG individuales de IRF/CIRF (una por choque) -- bandas 68/90,
    % mismo subconjunto de choques/respuestas que el digesto de consola.
    % (Precedente ERPT-Chat 5: esta llamada se omitio la primera vez y fue
    % el unico fix real de esa iteracion -- no repetir el mismo olvido.)
    plot_irfs(Results_w.LtildeStruct, Dataset_w, Cfg_disp, Results_w);

    % Excel completo (IRF+CIRF+FEVD+diagnosticos), bandas 68/90, mismo
    % subconjunto de choques/respuestas que el digesto de consola.
    export_results(Results_w, Dataset_w, Cfg_disp);
    fprintf('\n');

    % ── (c) FEVD, TODAS las variables endogenas, mismos horizontes de
    %    estimacion (ERPT-Chat 14, decision 5: el calificador "3 price_vars"
    %    aplica SOLO a IRF/CIRF, no a FEVD -- sin RESP_IDX, default = todas) ─
    fprintf('  --- (c) FEVD (todas las variables endogenas, horizontes de estimacion) ---\n');
    plot_fevd(Results_w, Dataset_w, Cfg_w);
    fprintf('\n');

    % ── (d) ERPT, 5 horizontes de Cfg.ERPT_HORIZONS, bandas propias ─────
    fprintf('  --- (d) ERPT -- %s (bandas propias [%.2f, %.2f]) ---\n', ...
        WIN_SPEC, ERPT_w.cred_bands(1,1), ERPT_w.cred_bands(1,2));
    local_print_erpt_digest(ERPT_w, NAMED_SHOCKS, PRICE_VARS);

    % ── Nota economica: jerarquia esperada imp_inf > pro_inf > con_inf ──
    fprintf('  --- Nota economica (jerarquia esperada de magnitud) ---\n');
    fprintf(['  imp_inf tipicamente muestra el ERPT mas alto y mas estable (transmision\n' ...
             '  mas directa vía costos de importacion); pro_inf, intermedio; con_inf, el\n' ...
             '  mas bajo y el de mayor variabilidad/ocasionales cruces de signo entre\n' ...
             '  horizontes -- consistente con la jerarquia esperada imp_inf > pro_inf >\n' ...
             '  con_inf (nota economica del usuario, ERPT-Chat 15): la dilucion del choque\n' ...
             '  cambiario a lo largo de la cadena de precios (importador -> productor ->\n' ...
             '  consumidor) implica mas eslabones de amortiguamiento (margenes, otros\n' ...
             '  costos no transables, rigideces de precios) antes de llegar al consumidor,\n' ...
             '  lo que se traduce en una senal mas debil y mas ruidosa en con_inf. No se\n' ...
             '  trata de una anomalia a resolver, sino del patron esperado.\n\n']);

    fprintf('  >> BLOQUE 2: PASA.\n\n');
catch ME
    bloque2_ok = false;
    fprintf('  [ERROR] %s\n', ME.message);
    fprintf('  >> BLOQUE 2: NO PASA.\n\n');
end

% =========================================================================
%  BLOQUE 3 -- Anexo de robustez (16 specs, formato largo/tidy)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Anexo de robustez (16 specs)\n');
fprintf('======================================================\n\n');

bloque3_ok = true;
T_long = table();
try
    if ~bloque1_ok
        error('validate_erpt16:bloque1Failed', 'Bloque 1 no paso -- no se construye el anexo.');
    end

    T_long = build_erpt_comparison_long(ERPT_by_spec, spec_names, NAMED_SHOCKS);

    n_rows_expected = n_specs * numel(NAMED_SHOCKS) * numel(PRICE_VARS) * ...
        numel(ERPT_by_spec.(WIN_SPEC).horizons);
    fprintf('  Tabla larga (T_long): %d filas (esperadas %d) -- %s\n\n', ...
        height(T_long), n_rows_expected, V{int32(height(T_long) == n_rows_expected)+1});

    % -- T_diag: ne, tasa de aceptacion, ND por spec (manual, sin exigir
    %    horizontes/price_vars identicos entre las 16 -- build_erpt_comparison.m
    %    si lo exige, esto no) --
    diag_rows = cell(n_specs, 4);
    for ss = 1:n_specs
        sn = spec_names{ss};
        R  = Results_by_spec.(sn);
        C  = Cfg_by_spec.(sn);
        diag_rows(ss, :) = {sn, C.ND, R.ne, sum(R.uw > 0) / C.ND};
    end
    T_diag = cell2table(diag_rows, 'VariableNames', {'spec', 'nd', 'ne', 'accept_rate'});

    % -- Anchos de banda 68%/90% recalculados desde ratio_draws cacheados
    %    (sin re-estimar), mismo criterio que Paso 2 de ERPT-Chat 14/15,
    %    usado aqui SOLO para dar evidencia numerica de las notas de
    %    exclusion -- no vuelve a decidir la ganadora (ya cerrada en
    %    ERPT-Chat 15). --
    score_w = nan(1, n_specs);
    for ss = 1:n_specs
        sn = spec_names{ss};
        ERPT_ss  = ERPT_by_spec.(sn);
        names_ss = {ERPT_ss.shocks.name};
        widths = [];
        for kk = 1:numel(BAND_SHOCKS_W)
            k_idx = find(strcmp(names_ss, BAND_SHOCKS_W{kk}), 1);
            if isempty(k_idx), continue; end
            prices_arr = ERPT_ss.shocks(k_idx).prices;
            pvar_names = {prices_arr.var};
            for pp = 1:numel(BAND_PRICEVARS_W)
                p_idx = find(strcmp(pvar_names, BAND_PRICEVARS_W{pp}), 1);
                if isempty(p_idx), continue; end
                ratio_draws = prices_arr(p_idx).ratio_draws;   % [nh x ndraws], crudo
                for hh = 1:size(ratio_draws, 1)
                    sl = ratio_draws(hh, :);
                    for bb = 1:size(BAND_68_90, 1)
                        q = quantile(sl, BAND_68_90(bb, :));
                        widths(end+1) = q(2) - q(1); %#ok<AGROW>
                    end
                end
            end
        end
        score_w(ss) = mean(widths);
    end

    fprintf('  --- Notas de exclusion del universo de seleccion (evidencia numerica) ---\n');
    fprintf('  %-38s %12s\n', 'spec', 'ancho68+90 (Cam/Dem/Ofe x imp/con_inf)');
    for ss = 1:n_specs
        fprintf('  %-38s %12.4f\n', spec_names{ss}, score_w(ss));
    end
    fprintf('\n');

    is_minn      = contains(spec_names, '_minn_');
    is_niwcustom = contains(spec_names, '_niwcustom_');
    is_diffuse   = contains(spec_names, '_diffuse_');

    fprintf('  [aa_minn / mm_minn] Excluidas del universo de seleccion en el mismo\n');
    fprintf('  Paso 1 (gate de estabilidad >= 70%%, ERPT-Chat 15) -- comparten motivo de\n');
    fprintf('  exclusion, no una jerarquia de severidad entre ellas.\n\n');

    niwcustom_note = 'Paso Paso 1; no competitiva en Paso 2 (ver ERPT-Chat 15: ancho ~2.5-3x vs diffuse).';
    if any(is_niwcustom) && any(is_diffuse & ~is_minn & ~is_niwcustom)
        ratio_niw = mean(score_w(is_niwcustom)) / mean(score_w(is_diffuse & ~is_minn & ~is_niwcustom));
        fprintf('  [mm_niwcustom] Paso el Paso 1, pero no fue competitiva en el Paso 2:\n');
        fprintf('  ancho promedio 68%%+90%% %.2fx mayor que el promedio de las specs diffuse\n', ratio_niw);
        fprintf('  (rango esperado documentado en ERPT-Chat 15: 2.5-3x).\n\n');
        niwcustom_note = sprintf('Paso Paso 1; no competitiva en Paso 2 (ancho %.2fx vs diffuse).', ratio_niw);
    end

    comparison_dir = fullfile(PROJ_ROOT, 'output', 'comparison');
    if ~isfolder(comparison_dir), mkdir(comparison_dir); end
    xlsx_path = fullfile(comparison_dir, 'erpt_annex_robustez_ND1e6.xlsx');
    if isfile(xlsx_path), delete(xlsx_path); end
    writetable(T_long, xlsx_path, 'Sheet', 'erpt_long');
    writetable(T_diag, xlsx_path, 'Sheet', 'run_diagnostics');
    T_notes = cell2table({ ...
        'aa_minn/mm_minn', 'Excluidas en Paso 1 (gate de estabilidad >= 70%), mismo motivo.'; ...
        'mm_niwcustom',     niwcustom_note ...
        }, 'VariableNames', {'grupo', 'nota'});
    writetable(T_notes, xlsx_path, 'Sheet', 'exclusion_notes');
    fprintf('  Anexo de robustez exportado (3 hojas) a:\n    %s\n\n', xlsx_path);

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
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 16\n');
fprintf('======================================================\n');
fprintf('  Bloque 1 (carga cache-only, 16 specs @ ND>=%-8g) : %s\n', ND_TARGET, V{int32(bloque1_ok)+1});
fprintf('  Bloque 2 (outputs completos, spec ganadora)      : %s\n', V{int32(bloque2_ok)+1});
fprintf('  Bloque 3 (anexo de robustez, 16 specs)            : %s\n', V{int32(bloque3_ok)+1});
fprintf('------------------------------------------------------\n');
if bloque1_ok && bloque2_ok && bloque3_ok
    fprintf('  GLOBAL : PASA\n');
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% ── Helpers locales ---------------------------------------------------------

function local_print_cirf_digest(LtildeStruct, Dataset, Cfg)
%LOCAL_PRINT_CIRF_DIGEST  Digesto de consola para CIRF, mismo formato que
%   print_summary.m pero aplicando compute_cirfs.m por choque (print_summary
%   no soporta CIRF directamente -- opera sobre LtildeStruct crudo). Usa
%   los mismos campos de Cfg que print_summary.m (SUMMARY_HORIZONS,
%   CRED_BANDS, SHOCK_IDX, RESP_IDX). Solo consola, no persiste nada
%   (el CIRF completo ya se exporta a Excel via export_results.m con
%   IRF_TYPE='both').

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
        cirfs_j = compute_cirfs(irfs_by_shock{j});   % [horizon+1 x nresp x ndraws]
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
%LOCAL_PRINT_ERPT_DIGEST  Digesto de consola de ERPT.shocks para un
%   subconjunto de choques nombrados x variables de precio, en los
%   horizontes de ERPT.horizons (sin recalcular nada -- usa ERPT.shocks(k)
%   .prices(p).median/band_lo/band_hi ya cacheados).
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
