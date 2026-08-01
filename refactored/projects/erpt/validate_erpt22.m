%VALIDATE_ERPT22  ERPT-Chat 22 -- Deuda de ERPT-Chat 20 + tabla de
%   resultados de ERPT-Chat 21 (banda unica 68%, Figura 2 = nivel L(h),
%   retiro de la CIRF generica, relabel de Figura 1).
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
%                 (b) L(0)=IRF(0) sobre datos reales cacheados (spec_A);
%                 (c) comparacion informativa (NO assert de igualdad, ver
%                 nota) entre razon-de-medianas de Level y la mediana-de-
%                 razones de ERPT (ERPT-Chat 1 decision 6: son objetos
%                 estadisticos distintos por la desigualdad de Jensen).
%     BLOQUE 3 -- Smoke test del wiring erpt_run_spec.m <- local_run_spec
%                 (ERPT-Chat 22, decision del usuario): confirma que las
%                 2 combinaciones de opts usadas (validate_erpt15: quiet_
%                 cfg=true/compute_frac_top=false; validate_erpt17/19:
%                 defaults) cargan cache correctamente y devuelven out.ok.
%     BLOQUE 4 -- Tests funcionales de analisis_A/B/C.m (Bloque 1 de este
%                 chat): cada uno se ejecuta completo (cache-only) y se
%                 verifica: SHOCK_IDX/RESP_IDX/IRF_TYPE aplicados, ausencia
%                 de nuevas figuras cirf_*.png, presencia de nivel_*.png
%                 (Figura 2) y de irf_*.png con eje Y reetiquetado.
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
NAMED_SHOCKS = {'Cam', 'Dem', 'Ofe'};

% =========================================================================
%  BLOQUE 1 -- Regresion de medianas (invariante ante cambio de bandas)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- Regresion de medianas @ 68%% (cache-only)\n');
fprintf('======================================================\n\n');

SPECS_CHECK(1) = struct('spec', 'spec_A_rob_aa_diffuse_lag4_v0', ...
    'transform', 'aa', 'shock_names_order', {{'Cam','Dem','Ofe'}});
SPECS_CHECK(2) = struct('spec', 'spec_B_rob_aa_diffuse_lag4_tot_v0', ...
    'transform', 'aa', 'shock_names_order', {{'Cam','Dem','Ofe'}});
SPECS_CHECK(3) = struct('spec', 'spec_C_rob_aa_diffuse_lag4_imp_v0', ...
    'transform', 'aa', 'shock_names_order', {{'Cam','Ofe','Dem'}});
SPECS_CHECK(4) = struct('spec', 'spec_C_rob_aa_diffuse_lag4_pro_v0', ...
    'transform', 'aa', 'shock_names_order', {{'Cam','Dem','Ofe'}});
SPECS_CHECK(5) = struct('spec', 'spec_C_rob_aa_diffuse_lag4_con_v0', ...
    'transform', 'aa', 'shock_names_order', {{'Cam','Dem','Ofe'}});

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
    max_diff  = 0;
    for kk = 1:numel(NAMED_SHOCKS)
        k_old = find(strcmp(names_old, NAMED_SHOCKS{kk}), 1);
        k_new = find(strcmp(names_new, NAMED_SHOCKS{kk}), 1);
        if isempty(k_old) || isempty(k_new)
            continue;   % choque no nombrado en este sistema (p.ej. Mon ya eliminado)
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
Cfg_a = cargar_spec('spec_A_rob_aa_diffuse_lag4_v0');
cache_a = fullfile(Cfg_a.OUTPUT_DIR, 'results_is.mat');
if isfile(cache_a)
    [Results_a, ~, Dataset_a, Cfg_a_cached] = load_erpt_run(Cfg_a.OUTPUT_DIR);
    Cfg_a_cached.SHOCK_IDX = 1:3;
    Level_a = build_level_response(Results_a, Dataset_a, Cfg_a_cached, 'aa', {'ner','imp_inf'});

    endo_mask = strcmp(Dataset_a.var_roles, 'endogenous');
    var_names_a = Dataset_a.var_names(endo_mask);
    resp_idx_a  = [find(strcmp(var_names_a,'ner'),1), find(strcmp(var_names_a,'imp_inf'),1)];
    [irfs_by_shock_a, ~, ~, shock_idx_resolved_a] = ...
        select_irfs(Results_a.LtildeStruct, 1:3, resp_idx_a, Cfg_a_cached.SHOCK_NAMES);

    ok_l0_real = true;
    for j = 1:numel(shock_idx_resolved_a)
        irf0_ner = quantile(reshape(irfs_by_shock_a{j}(1,1,:),1,[]), 0.50);
        irf0_imp = quantile(reshape(irfs_by_shock_a{j}(1,2,:),1,[]), 0.50);
        L0_ner = Level_a.shocks(j).vars(1).median(1);
        L0_imp = Level_a.shocks(j).vars(2).median(1);
        ok_l0_real = ok_l0_real && abs(L0_ner - irf0_ner) <= TOL && abs(L0_imp - irf0_imp) <= TOL;
    end
    bloque2_ok = bloque2_ok && ok_l0_real;
    fprintf('  (b) L(0)=IRF(0) sobre spec_A cacheada (ner, imp_inf, 3 choques): %s\n', V{int32(ok_l0_real)+1});

    % -- (c) Comparacion informativa (NO assert): razon-de-medianas de Level
    %    vs mediana-de-razones de ERPT, en los horizontes de la Tabla 1.
    ERPT_a = calculate_erpt(Results_a, Dataset_a, Cfg_a_cached, 'aa');
    names_a = {ERPT_a.shocks.name};
    fprintf('\n  (c) Informativo -- razon-de-medianas(Level) vs mediana-de-razones(ERPT):\n');
    fprintf('      (se espera una diferencia pequena pero no-nula: son objetos\n');
    fprintf('       estadisticos distintos, ver ERPT-Chat 1 decision 6 / desigualdad de Jensen)\n');
    for kk = 1:numel(NAMED_SHOCKS)
        k_idx = find(strcmp(names_a, NAMED_SHOCKS{kk}), 1);
        if isempty(k_idx); continue; end
        j_lvl = find([Level_a.shocks.idx] == ERPT_a.shocks(k_idx).idx, 1);
        prices_arr = ERPT_a.shocks(k_idx).prices;
        p_idx = find(strcmp({prices_arr.var}, 'imp_inf'), 1);
        for hh_target = [3 6 12 24 36]
            h_erpt = find(ERPT_a.horizons == hh_target, 1);
            h_lvl  = find(Level_a.horizons == hh_target, 1);
            ratio_of_medians = Level_a.shocks(j_lvl).vars(2).median(h_lvl) / ...
                                Level_a.shocks(j_lvl).vars(1).median(h_lvl);
            median_of_ratios = prices_arr(p_idx).median(h_erpt);
            fprintf('      %-4s h=%-2d  razon-de-medianas=%7.4f  mediana-de-razones(ERPT)=%7.4f  diff=%7.4f\n', ...
                NAMED_SHOCKS{kk}, hh_target, ratio_of_medians, median_of_ratios, ...
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
    fprintf('  >> BLOQUE 2: NO PASA -- revisar accumulate_level.m/build_level_response.m.\n\n');
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

ANALISIS_FILES = {'analisis_A.m', 'analisis_B.m', 'analisis_C.m'};
bloque4_ok = true;
KEEP_VARS = {'ANALISIS_FILES', 'ANALISIS_DIR', 'bloque1_ok', 'bloque2_ok', ...
    'bloque3_ok', 'bloque4_ok', 'aa', 'BANDS_NEW', 'V', 'TOL', 'PROJ_ROOT', ...
    'PROJECTS_ROOT', 'REF_ROOT', 'PROJ_CFG', 'PROJ_SRC', 'REF_SRC', ...
    'REF_CFG_DIR', 'REF_HELP', 'REF_VALIDATE', 'NAMED_SHOCKS', 'SPECS_CHECK', ...
    'log_path_diary', 'val_file', 'KEEP_VARS', 'fname', 'apath', 'fig_before'};

for aa = 1:numel(ANALISIS_FILES)
    fname = ANALISIS_FILES{aa};
    fprintf('  --- Ejecutando %s (cache-only, usar_cache=true en el archivo) ---\n', fname);
    apath = fullfile(ANALISIS_DIR, fname);

    % -- Limpiar variables de la iteracion anterior ANTES de correr, para
    %    que un fallo temprano de `run(apath)` no deje pasar por error un
    %    Cfg/Results de la corrida previa --
    clearvars('-except', KEEP_VARS{:});

    fig_before = findall(0, 'Type', 'figure');
    try
        run(apath);
        run_ok = true;
    catch ME
        run_ok = false;
        fprintf('  [ERROR] %s: %s\n', fname, ME.message);
    end

    if run_ok && exist('Cfg', 'var') == 1
        ok_shock_idx = isfield(Cfg, 'SHOCK_IDX') && isequal(Cfg.SHOCK_IDX, 1:3);
        ok_irf_type  = isfield(Cfg, 'IRF_TYPE') && strcmpi(Cfg.IRF_TYPE, 'irf');
        ok_bands     = isfield(Cfg, 'CRED_BANDS') && isequal(Cfg.CRED_BANDS, BANDS_NEW);
        ok_has_outdir = isfield(Cfg, 'OUTPUT_DIR') && isfolder(fullfile(Cfg.OUTPUT_DIR, 'figures'));
    else
        ok_shock_idx = false; ok_irf_type = false; ok_bands = false; ok_has_outdir = false;
    end

    if ok_has_outdir
        fig_dir_check = fullfile(Cfg.OUTPUT_DIR, 'figures');
        cirf_pngs  = dir(fullfile(fig_dir_check, 'cirf_*.png'));
        nivel_pngs = dir(fullfile(fig_dir_check, 'nivel_*.png'));
        ok_no_cirf   = isempty(cirf_pngs);
        ok_has_nivel = ~isempty(nivel_pngs);
    else
        cirf_pngs = []; nivel_pngs = [];
        ok_no_cirf = false; ok_has_nivel = false;
    end

    ok_all = run_ok && ok_shock_idx && ok_irf_type && ok_bands && ok_no_cirf && ok_has_nivel;
    bloque4_ok = bloque4_ok && ok_all;

    fprintf('    corrida sin error          : %s\n', V{int32(run_ok)+1});
    fprintf('    Cfg.SHOCK_IDX == 1:3       : %s\n', V{int32(ok_shock_idx)+1});
    fprintf('    Cfg.IRF_TYPE == ''irf''      : %s\n', V{int32(ok_irf_type)+1});
    fprintf('    Cfg.CRED_BANDS == [.16 .84]: %s\n', V{int32(ok_bands)+1});
    fprintf('    sin cirf_*.png nuevas      : %s  (%d encontradas)\n', V{int32(ok_no_cirf)+1}, numel(cirf_pngs));
    fprintf('    con nivel_*.png (Figura 2) : %s  (%d encontradas)\n', V{int32(ok_has_nivel)+1}, numel(nivel_pngs));
    fprintf('    >> %s: %s\n\n', fname, V{int32(ok_all)+1});

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
