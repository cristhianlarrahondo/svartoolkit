%VALIDATE_ERPT22  ERPT-Chat 22 -- Deuda de ERPT-Chat 20 + tabla de
%   resultados de ERPT-Chat 21 (banda unica 68%, retiro de la CIRF
%   generica, relabel de Figura 1). Figura 2 (nivel L(h)) se implemento y
%   luego se DESCARTO dentro de este chat -- ver nota de cabecera en
%   analisis_A.m.
%
%   Tipo S. No toca run_pfa.m / run_is.m / build_posterior.m / load_data.m
%   -- 100% post-procesamiento sobre projects/erpt/ y draws ya cacheados
%   (ND=1e6 para A -- ver nota en analisis_A_robustez.m sobre lo que hay
%   realmente persistido en cache; cache existente para B/C). Sin
%   regresion BNW, sin cambios en la Bitacora (Seccion C).
%
%   ── Resumen de bloques ──────────────────────────────────────────────────
%     BLOQUE 1 -- Regresion de medianas: la mediana de ERPT es un cuantil
%                 (0.50) sobre draws de ratio, INDEPENDIENTE de
%                 Cfg.CRED_BANDS -- este bloque confirma numericamente esa
%                 invariante para spec_A (ganadora), spec_B (ToT) y los 3
%                 sistemas de spec_C, comparando la mediana cacheada
%                 (bandas 25-75 originales) contra la recalculada a 68%.
%                 "Solo cambia el ancho de banda" (instruccion del chat) se
%                 verifica, no se asume.
%     BLOQUE 2 -- Sanity check de accumulate_level.m/resolve_aa_lag.m: (a)
%                 test sintetico de la recursion aa (L(0)=IRF(0), L(h)=
%                 IRF(h)+L(h-lag) para h>=lag) y de la rama mm (cumsum);
%                 (b) L(0)=IRF(0) sobre datos reales cacheados (spec_A),
%                 via accumulate_level.m directamente (build_level_response.m
%                 fue borrado junto con Figura 2 -- ver nota arriba);
%                 (c) comparacion informativa (NO assert de igualdad, ver
%                 nota) entre razon-de-medianas de L(h) y la mediana-de-
%                 razones de ERPT (ERPT-Chat 1 decision 6: son objetos
%                 estadisticos distintos por la desigualdad de Jensen) --
%                 esta comparacion es tambien el origen del "diente de
%                 sierra" que motivo descartar Figura 2 (ver analisis_A.m).
%     BLOQUE 3 -- Smoke test del wiring erpt_run_spec.m <- local_run_spec
%                 (ERPT-Chat 22, decision del usuario): confirma que las
%                 2 combinaciones de opts usadas (validate_erpt15: quiet_
%                 cfg=true/compute_frac_top=false; validate_erpt17/19:
%                 defaults) cargan cache correctamente y devuelven out.ok.
%     BLOQUE 4 -- Tests funcionales de analisis_A/B/C.m: 3 tareas -- A, B,
%                 C (round 9: analisis_C.m ahora corre los 3 sistemas --
%                 importados/productor/consumidor -- en UN solo loop
%                 interno, ya no expone el boton `inflacion`; A y B siguen
%                 siendo do-files independientes para revisarse uno a la
%                 vez). La verificacion de cada spec (sin cirf_*.png/
%                 nivel_*.png, FEVD con TODAS las variables endogenas,
%                 <SPEC>_results.xlsx con hoja erpt_summary) se hace por
%                 archivo en disco via p_check_spec_outputs -- para C, el
%                 Cfg/Dataset del workspace tras `run()` solo refleja el
%                 ultimo sistema del loop (consumidor), asi que los 3
%                 specs se verifican por separado.
%     VEREDICTO GLOBAL
%
%   Ejecutar COMPLETO (F5). Pegar el output de consola en el chat.

%% -- Diary --------------------------------------------------------------
PROJ_ROOT_early = fileparts(mfilename('fullpath'));
addpath(fullfile(PROJ_ROOT_early, 'src'));
log_path_diary  = start_diary(PROJ_ROOT_early, mfilename);

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 22 -- deuda Chat 20 + tabla Chat 21\n');
fprintf('======================================================\n\n');

%% ── Rutas -------------------------------------------------------------------
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');
ANALISIS_DIR  = fullfile(PROJ_ROOT, 'analisis');
REF_SRC       = fullfile(REF_ROOT, 'src');
REF_CFG_DIR   = fullfile(REF_ROOT, 'config');
REF_HELP      = fullfile(REF_ROOT, 'helpfunctions');
REF_VALIDATE  = fullfile(REF_ROOT, 'validate');

addpath(REF_SRC); addpath(REF_CFG_DIR); addpath(REF_HELP);
addpath(REF_VALIDATE); addpath(PROJ_CFG); addpath(PROJ_SRC); addpath(ANALISIS_DIR);

V = {'FAIL', 'OK  '};
TOL = 1e-9;   % tolerancia para invariantes numericos exactos (misma formula)

BANDS_NEW = [0.16 0.84];
NAMED_SHOCKS = {'Exchange Rate', 'Demand', 'Supply'};

% =========================================================================
%  BLOQUE 1 -- Regresion de medianas (invariante ante cambio de bandas)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- Regresion de medianas @ 68%% (cache-only)\n');
fprintf('======================================================\n\n');

SPECS_CHECK(1) = struct('spec', 'spec_A_rob_aa_diffuse_lag4_v0', ...
    'transform', 'aa', 'shock_names_order', {{'Exchange Rate','Demand','Supply'}});
SPECS_CHECK(2) = struct('spec', 'spec_B_rob_aa_diffuse_lag4_tot_v0', ...
    'transform', 'aa', 'shock_names_order', {{'Exchange Rate','Demand','Supply'}});
SPECS_CHECK(3) = struct('spec', 'spec_C_rob_aa_diffuse_lag4_imp_v0', ...
    'transform', 'aa', 'shock_names_order', {{'Exchange Rate','Supply','Demand'}});
SPECS_CHECK(4) = struct('spec', 'spec_C_rob_aa_diffuse_lag4_pro_v0', ...
    'transform', 'aa', 'shock_names_order', {{'Exchange Rate','Demand','Supply'}});
SPECS_CHECK(5) = struct('spec', 'spec_C_rob_aa_diffuse_lag4_con_v0', ...
    'transform', 'aa', 'shock_names_order', {{'Exchange Rate','Demand','Supply'}});

bloque1_ok = true;
for ii = 1:numel(SPECS_CHECK)
    sn = SPECS_CHECK(ii).spec;
    Cfg0 = cargar_spec(sn);
    cache_path = fullfile(Cfg0.OUTPUT_DIR, 'results_is.mat');
    if ~isfile(cache_path)
        fprintf('  [%-38s] SIN CACHE -- omitido (correr analisis_* o validate_erpt15/16/17/19 primero).\n', sn);
        continue;
    end
    [Results_ss, ERPT_old, Dataset_ss, Cfg_cached] = load_erpt_run(Cfg0.OUTPUT_DIR);

    Cfg_new = Cfg_cached;
    Cfg_new.CRED_BANDS = BANDS_NEW;
    ERPT_new = calculate_erpt(Results_ss, Dataset_ss, Cfg_new, SPECS_CHECK(ii).transform);

    names_old = {ERPT_old.shocks.name};
    names_new = {ERPT_new.shocks.name};
    idx_old   = [ERPT_old.shocks.idx];
    idx_new   = [ERPT_new.shocks.idx];
    max_diff  = 0;
    % -- Emparejar por INDICE de choque (1,2,3 = los 3 nombrados), no por
    %    nombre: Cfg_new hereda Cfg_cached.SHOCK_NAMES (el que estaba
    %    persistido en el .mat cuando se corrio por ultima vez), que puede
    %    diferir del de la spec .m actual (p.ej. tras el relabel a ingles
    %    de ERPT-Chat 22) -- emparejar por nombre contra NAMED_SHOCKS
    %    (ingles) no encontraria nada en un cache viejo con nombres en
    %    espanol, dando un PASA vacio y enganoso.
    for sidx = 1:3
        k_old = find(idx_old == sidx, 1);
        k_new = find(idx_new == sidx, 1);
        if isempty(k_old) || isempty(k_new)
            continue;   % choque no presente en este sistema
        end
        prices_old = ERPT_old.shocks(k_old).prices;
        prices_new = ERPT_new.shocks(k_new).prices;
        names_p_old = {prices_old.var};
        for pp = 1:numel(prices_new)
            p_old = find(strcmp(names_p_old, prices_new(pp).var), 1);
            if isempty(p_old); continue; end
            d = max(abs(prices_new(pp).median - prices_old(p_old).median));
            max_diff = max(max_diff, d);
        end
    end
    ok_ss = max_diff <= TOL;
    bloque1_ok = bloque1_ok && ok_ss;
    fprintf('  [%-38s] max|mediana_68%%-mediana_cache| = %.3e   %s\n', ...
        sn, max_diff, V{int32(ok_ss)+1});
end
fprintf('\n');
if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- la mediana es invariante ante el cambio de banda (solo cambia el ancho).\n\n');
else
    fprintf('  >> BLOQUE 1: NO PASA -- alguna mediana cambio al recalcular bandas (inesperado).\n\n');
end

% =========================================================================
%  BLOQUE 2 -- Sanity check de accumulate_level.m / resolve_aa_lag.m
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Sanity check de la recursion L(h)\n');
fprintf('======================================================\n\n');

bloque2_ok = true;

% -- (a) Test sintetico, rama 'aa' -----------------------------------------
% IRF sintetica de horizonte 0..14 (H=15), 1 draw: valores 1..15.
irf_syn = reshape((1:15)', [15 1 1]);
lag_syn = 12;
L_syn = accumulate_level(irf_syn, 'aa', lag_syn);
% Esperado: L(h)=IRF(h) para h=0..11 (indices 1..12); L(h)=IRF(h)+L(h-12)
% para h=12,13,14 (indices 13,14,15).
expected = zeros(15,1);
expected(1:12) = irf_syn(1:12);
expected(13) = irf_syn(13) + expected(1);   % h=12: IRF(12)+L(0)
expected(14) = irf_syn(14) + expected(2);   % h=13: IRF(13)+L(1)
expected(15) = irf_syn(15) + expected(3);   % h=14: IRF(14)+L(2)
ok_aa_syn = max(abs(squeeze(L_syn) - expected)) <= TOL;
ok_l0_syn = abs(L_syn(1) - irf_syn(1)) <= TOL;   % L(0) = IRF(0)
bloque2_ok = bloque2_ok && ok_aa_syn && ok_l0_syn;
fprintf('  (a) accumulate_level aa, sintetico: L(0)=IRF(0) %s | recursion completa %s\n', ...
    V{int32(ok_l0_syn)+1}, V{int32(ok_aa_syn)+1});

% -- (a2) Test sintetico, rama 'mm' (debe coincidir con cumsum/compute_cirfs)
L_mm = accumulate_level(irf_syn, 'mm', []);
ok_mm_syn = max(abs(squeeze(L_mm) - cumsum(squeeze(irf_syn)))) <= TOL;
bloque2_ok = bloque2_ok && ok_mm_syn;
fprintf('  (a2) accumulate_level mm, sintetico == cumsum: %s\n', V{int32(ok_mm_syn)+1});

% -- (b) L(0)=IRF(0) sobre datos reales cacheados (spec_A, choque Cam, imp_inf)
%    NOTA (ERPT-Chat 22, decision del usuario): Figura 2 (nivel L(h)) y su
%    helper build_level_response.m fueron implementados y luego
%    DESCARTADOS en este chat (patron de "diente de sierra" real, ver nota
%    de cabecera en analisis_A.m) -- este sanity check ya NO pasa por
%    build_level_response.m (borrado); usa accumulate_level.m directamente
%    sobre IRFs extraidas con select_irfs.m, exactamente como lo hace
%    calculate_erpt.m internamente para la Tabla 1 oficial.
Cfg_a = cargar_spec('spec_A_rob_aa_diffuse_lag4_v0');
cache_a = fullfile(Cfg_a.OUTPUT_DIR, 'results_is.mat');
if isfile(cache_a)
    [Results_a, ~, Dataset_a, Cfg_a_cached] = load_erpt_run(Cfg_a.OUTPUT_DIR);
    Cfg_a_cached.SHOCK_IDX = 1:3;

    endo_mask   = strcmp(Dataset_a.var_roles, 'endogenous');
    var_names_a = Dataset_a.var_names(endo_mask);
    resp_idx_a  = [find(strcmp(var_names_a,'ner'),1), find(strcmp(var_names_a,'imp_inf'),1)];
    [irfs_by_shock_a, ~, ~, shock_idx_resolved_a] = ...
        select_irfs(Results_a.LtildeStruct, 1:3, resp_idx_a, Cfg_a_cached.SHOCK_NAMES);
    lag_a = resolve_aa_lag(Dataset_a);

    ok_l0_real = true;
    L_ner_by_shock = cell(1, numel(shock_idx_resolved_a));
    L_imp_by_shock = cell(1, numel(shock_idx_resolved_a));
    for j = 1:numel(shock_idx_resolved_a)
        L_ner_j = accumulate_level(irfs_by_shock_a{j}(:,1,:), 'aa', lag_a);
        L_imp_j = accumulate_level(irfs_by_shock_a{j}(:,2,:), 'aa', lag_a);
        L_ner_by_shock{j} = L_ner_j;
        L_imp_by_shock{j} = L_imp_j;

        irf0_ner = quantile(reshape(irfs_by_shock_a{j}(1,1,:),1,[]), 0.50);
        irf0_imp = quantile(reshape(irfs_by_shock_a{j}(1,2,:),1,[]), 0.50);
        L0_ner = quantile(reshape(L_ner_j(1,1,:),1,[]), 0.50);
        L0_imp = quantile(reshape(L_imp_j(1,1,:),1,[]), 0.50);
        ok_l0_real = ok_l0_real && abs(L0_ner - irf0_ner) <= TOL && abs(L0_imp - irf0_imp) <= TOL;
    end
    bloque2_ok = bloque2_ok && ok_l0_real;
    fprintf('  (b) L(0)=IRF(0) sobre spec_A cacheada (ner, imp_inf, 3 choques): %s\n', V{int32(ok_l0_real)+1});

    % -- (c) Comparacion informativa (NO assert): razon-de-medianas de L(h)
    %    (via accumulate_level, el mismo objeto que Tabla 1) vs mediana-
    %    de-razones de ERPT, en los horizontes de la Tabla 1.
    ERPT_a = calculate_erpt(Results_a, Dataset_a, Cfg_a_cached, 'aa');
    names_a = {ERPT_a.shocks.name};
    idx_a   = [ERPT_a.shocks.idx];
    fprintf('\n  (c) Informativo -- razon-de-medianas(L(h)) vs mediana-de-razones(ERPT):\n');
    fprintf('      (se espera una diferencia pequena pero no-nula: son objetos\n');
    fprintf('       estadisticos distintos, ver ERPT-Chat 1 decision 6 / desigualdad de Jensen)\n');
    for sidx = 1:3
        k_idx = find(idx_a == sidx, 1);
        if isempty(k_idx); continue; end
        label_sidx = resolve_shock_name(Cfg_a.SHOCK_NAMES, sidx);   % label actual (spec fresca), solo para imprimir
        j_lvl = find(shock_idx_resolved_a == sidx, 1);
        prices_arr = ERPT_a.shocks(k_idx).prices;
        p_idx = find(strcmp({prices_arr.var}, 'imp_inf'), 1);
        for hh_target = [3 6 12 24 36]
            h_erpt = find(ERPT_a.horizons == hh_target, 1);
            h_idx_lvl = hh_target + 1;
            med_ner = quantile(reshape(L_ner_by_shock{j_lvl}(h_idx_lvl,1,:),1,[]), 0.50);
            med_imp = quantile(reshape(L_imp_by_shock{j_lvl}(h_idx_lvl,1,:),1,[]), 0.50);
            ratio_of_medians = med_imp / med_ner;
            median_of_ratios = prices_arr(p_idx).median(h_erpt);
            fprintf('      %-14s h=%-2d  razon-de-medianas=%7.4f  mediana-de-razones(ERPT)=%7.4f  diff=%7.4f\n', ...
                label_sidx, hh_target, ratio_of_medians, median_of_ratios, ...
                ratio_of_medians - median_of_ratios);
        end
    end
    fprintf('\n');
else
    fprintf('  (b)/(c) SIN CACHE para spec_A -- omitidos.\n\n');
end

if bloque2_ok
    fprintf('  >> BLOQUE 2: PASA -- recursion sintetica y L(0)=IRF(0) verificados.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA -- revisar accumulate_level.m/resolve_aa_lag.m.\n\n');
end

% =========================================================================
%  BLOQUE 3 -- Smoke test del wiring erpt_run_spec.m <- local_run_spec
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Smoke test wiring erpt_run_spec.m\n');
fprintf('======================================================\n\n');

SMOKE_SPEC = 'spec_A_base_aa_diffuse_lag2_v0';   % spec liviana, cache-only para este smoke test
Cfg_smoke = cargar_spec(SMOKE_SPEC);
cache_smoke = fullfile(Cfg_smoke.OUTPUT_DIR, 'results_is.mat');
bloque3_ok = true;
if isfile(cache_smoke)
    peek = load(cache_smoke, 'Cfg');
    nd_cached_smoke = peek.Cfg.ND;

    % -- Modo validate_erpt17/19 (defaults) --
    out_default = erpt_run_spec(SMOKE_SPEC, PROJ_CFG, true, nd_cached_smoke);
    ok_default = out_default.ok && out_default.used_cache;

    % -- Modo validate_erpt15 (quiet_cfg=true, compute_frac_top=false) --
    out_quiet = erpt_run_spec(SMOKE_SPEC, PROJ_CFG, true, nd_cached_smoke, ...
        struct('compute_frac_top', false, 'quiet_cfg', true));
    ok_quiet = out_quiet.ok && out_quiet.used_cache && isnan(out_quiet.frac_top);

    bloque3_ok = ok_default && ok_quiet;
    fprintf('  erpt_run_spec defaults (modo validate_erpt17/19): %s\n', V{int32(ok_default)+1});
    fprintf('  erpt_run_spec quiet_cfg+no frac_top (modo validate_erpt15):  %s\n', V{int32(ok_quiet)+1});
else
    fprintf('  SIN CACHE para %s -- smoke test omitido (no bloqueante).\n', SMOKE_SPEC);
end
fprintf('\n');
if bloque3_ok
    fprintf('  >> BLOQUE 3: PASA -- erpt_run_spec.m responde igual en ambos modos usados por validate_erpt15/17/19.\n\n');
else
    fprintf('  >> BLOQUE 3: NO PASA -- revisar el wiring en validate_erpt15/17/19.m.\n\n');
end

% =========================================================================
%  BLOQUE 4 -- Tests funcionales de analisis_A/B/C.m (Bloque 1 del chat)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 4 -- Tests funcionales de analisis_A/B/C.m\n');
fprintf('======================================================\n\n');

% -- 3 tareas: A, B, C (round 9: C ahora corre los 3 sistemas -- importados/
%    productor/consumidor -- en UNA sola ejecucion internamente, ya no hay
%    que invocarlo 3 veces con `inflacion` preseteada). Como analisis_C.m
%    deja en el workspace solo el ULTIMO sistema de su loop interno
%    (consumidor), la verificacion de C se hace por archivo en disco para
%    los 3 specs, no leyendo el Cfg/Dataset final del workspace.
TASKS = {'analisis_A.m', 'analisis_B.m', 'analisis_C.m'};
C_SPECS = {'spec_C_rob_aa_diffuse_lag4_imp_v0', ...
           'spec_C_rob_aa_diffuse_lag4_pro_v0', ...
           'spec_C_rob_aa_diffuse_lag4_con_v0'};

bloque4_ok = true;
KEEP_VARS = {'TASKS', 'C_SPECS', 'ANALISIS_DIR', 'bloque1_ok', 'bloque2_ok', ...
    'bloque3_ok', 'bloque4_ok', 'aa', 'BANDS_NEW', 'V', 'TOL', 'PROJ_ROOT', ...
    'PROJECTS_ROOT', 'REF_ROOT', 'PROJ_CFG', 'PROJ_SRC', 'REF_SRC', ...
    'REF_CFG_DIR', 'REF_HELP', 'REF_VALIDATE', 'NAMED_SHOCKS', 'SPECS_CHECK', ...
    'log_path_diary', 'val_file', 'KEEP_VARS', 'fname', 'apath', 'fig_before'};

for aa = 1:numel(TASKS)
    fname = TASKS{aa};
    apath = fullfile(ANALISIS_DIR, fname);
    fprintf('  --- Ejecutando %s (cache-only, usar_cache=true en el archivo) ---\n', fname);

    % -- Limpiar variables de la iteracion anterior ANTES de correr --
    clearvars('-except', KEEP_VARS{:});

    fig_before = findall(0, 'Type', 'figure');
    try
        run(apath);
        run_ok = true;
    catch ME
        run_ok = false;
        fprintf('  [ERROR] %s: %s\n', fname, ME.message);
    end

    if strcmp(fname, 'analisis_C.m')
        % -- C corre 3 sistemas internamente: verificar CADA UNO por
        %    archivo en disco (Cfg/Dataset del workspace solo reflejan el
        %    ultimo, consumidor) --
        ok_all = run_ok;
        for cc = 1:numel(C_SPECS)
            [ok_cc, det_cc] = p_check_spec_outputs(C_SPECS{cc});
            ok_all = ok_all && ok_cc;
            fprintf('    [%-38s] %s\n', C_SPECS{cc}, det_cc);
        end
        fprintf('    >> %s (3 sistemas): %s\n\n', fname, V{int32(ok_all)+1});
    else
        spec_name_check = '';
        if run_ok && exist('Cfg', 'var') == 1 && isfield(Cfg, 'SPEC_NAME')
            spec_name_check = Cfg.SPEC_NAME;
        end
        if ~isempty(spec_name_check)
            [ok_all, det] = p_check_spec_outputs(spec_name_check);
            ok_all = ok_all && run_ok;
            fprintf('    %s\n', det);
        else
            ok_all = false;
        end
        fprintf('    >> %s: %s\n\n', fname, V{int32(ok_all)+1});
    end
    bloque4_ok = bloque4_ok && ok_all;

    % -- Cerrar figuras nuevas de esta iteracion para no acumular ventanas --
    fig_after = findall(0, 'Type', 'figure');
    fig_new   = setdiff(fig_after, fig_before);
    close(fig_new);
end
if bloque4_ok
    fprintf('  >> BLOQUE 4: PASA -- los 3 analisis_*.m corren cache-only y aplican los cambios de ERPT-Chat 22.\n\n');
else
    fprintf('  >> BLOQUE 4: NO PASA -- revisar el detalle de arriba.\n\n');
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('======================================================\n');
fprintf('  VEREDICTO GLOBAL\n');
fprintf('======================================================\n');
fprintf('  BLOQUE 1 (regresion medianas)      : %s\n', V{int32(bloque1_ok)+1});
fprintf('  BLOQUE 2 (sanity L(h))             : %s\n', V{int32(bloque2_ok)+1});
fprintf('  BLOQUE 3 (smoke erpt_run_spec)     : %s\n', V{int32(bloque3_ok)+1});
fprintf('  BLOQUE 4 (funcional analisis_*.m)  : %s\n', V{int32(bloque4_ok)+1});
if bloque1_ok && bloque2_ok && bloque3_ok && bloque4_ok
    fprintf('  GLOBAL : PASA\n');
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');

%% -- Cierre de diary ------------------------------------------------------
diary('off');
fprintf('[diary] Corrida persistida en:\n        %s\n\n', log_path_diary);


%% ── Helpers locales ──────────────────────────────────────────────────────

function [ok_all, detail] = p_check_spec_outputs(spec_name)
%P_CHECK_SPEC_OUTPUTS  Verifica en disco (no en el workspace de la corrida)
%   que un spec tenga: sin cirf_*.png/nivel_*.png, FEVD cubriendo TODAS las
%   variables endogenas, y <SPEC_NAME>_results.xlsx con hoja erpt_summary.
%   Round 9: analisis_C.m ahora corre 3 sistemas en un solo loop interno,
%   asi que el Cfg/Dataset del workspace tras `run()` solo refleja el
%   ULTIMO sistema -- esta funcion revisa cada spec de forma independiente,
%   cargando su propio Cfg/Dataset via cargar_spec/load_erpt_run.
    Cfg = cargar_spec(spec_name);
    cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
    if ~isfile(cache_path)
        ok_all = false;
        detail = 'SIN CACHE -- no se pudo verificar (correr el analisis_*.m correspondiente primero)';
        return;
    end
    [~, ~, Dataset] = load_erpt_run(Cfg.OUTPUT_DIR);

    fig_dir = fullfile(Cfg.OUTPUT_DIR, 'figures');
    cirf_pngs  = dir(fullfile(fig_dir, 'cirf_*.png'));
    nivel_pngs = dir(fullfile(fig_dir, 'nivel_*.png'));
    fevd_pngs  = dir(fullfile(fig_dir, 'fevd_var*.png'));
    ok_no_cirf  = isempty(cirf_pngs);
    ok_no_nivel = isempty(nivel_pngs);
    n_endo_expected = sum(strcmp(Dataset.var_roles, 'endogenous'));
    ok_fevd_all = numel(fevd_pngs) == n_endo_expected;

    results_xlsx = fullfile(Cfg.OUTPUT_DIR, 'tables', [Cfg.SPEC_NAME, '_results.xlsx']);
    ok_results_xlsx = isfile(results_xlsx);
    ok_erpt_sheet = false;
    if ok_results_xlsx
        try
            sheet_names = sheetnames(results_xlsx);
            ok_erpt_sheet = any(strcmpi(sheet_names, 'erpt_summary'));
        catch
            ok_erpt_sheet = false;
        end
    end

    ok_all = ok_no_cirf && ok_no_nivel && ok_fevd_all && ok_results_xlsx && ok_erpt_sheet;

    V = {'FAIL', 'OK  '};
    detail = sprintf(['sin cirf:%s  sin nivel:%s  FEVD %d/%d:%s  ' ...
        'results.xlsx:%s  erpt_summary:%s  >> %s'], ...
        V{int32(ok_no_cirf)+1}, V{int32(ok_no_nivel)+1}, ...
        numel(fevd_pngs), n_endo_expected, V{int32(ok_fevd_all)+1}, ...
        V{int32(ok_results_xlsx)+1}, V{int32(ok_erpt_sheet)+1}, V{int32(ok_all)+1});
end
