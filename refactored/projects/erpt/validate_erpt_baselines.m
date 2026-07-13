%VALIDATE_ERPT_BASELINES  ERPT-Chat 4 — Corrida cientifica completa (Cfg.ND=3e5)
%   de las 4 specs baseline + tabla comparativa cruzada. Protocolo Tipo S.
%
%   Ejecutar completo (F5), no por secciones.
%
%   ADVERTENCIA DE TIEMPO: a diferencia de validate_lote_erpt3.m (smoke
%   test, Cfg.ND=3000), este script corre las 4 specs con Cfg.ND=3e5
%   COMPLETO -- la corrida cientifica real. Cada spec puede tomar varios
%   minutos a decenas de minutos. Con cache habilitado (ver USE_CACHE
%   abajo), una vez que una spec fue corrida y persistida, correcciones
%   posteriores a la tabla comparativa NO requieren re-correr esa spec.
%
%   BLOQUE 0 — Regresion BNW (Chat 7), ND completo:
%     spec_bnw_is con rng(0) y Cfg.ND=3e5 (igual que Chat 7 / ERPT-Chat 3
%     Bloque 1, pero sin reducir ND -- esta es la referencia real, no un
%     smoke test). Si esto no pasa, no tiene sentido continuar.
%
%   BLOQUE 1 — Las 4 specs baseline, corrida cientifica completa:
%     spec_aa_diffuse_v0, spec_aa_minn_v0, spec_mm_diffuse_v0,
%     spec_mm_minn_v0 -- cada una: load_data -> validate_cfg ->
%     build_posterior -> run_is (Cfg.ND=3e5) -> calculate_erpt ->
%     save_erpt_run (persistencia .mat completa). Usa cache si ya existe
%     <OUTPUT_DIR>/results_is.mat (ver USE_CACHE).
%
%   BLOQUE 2 — Tabla comparativa cruzada (build_erpt_comparison.m):
%     Filas = choque (solo Cam/Dem/Ofe) x variable de precio x horizonte
%     (los 5 de Cfg.ERPT_HORIZONS). Columnas = bloque de 3 (mediana | p_lo
%     | p_hi) por cada una de las 4 specs. Se imprime en consola por
%     horizonte y se exporta a
%     projects/erpt/output/comparison/erpt_comparison.xlsx (hojas
%     erpt_comparison + run_diagnostics).
%
%   BLOQUE 3 — Casos de error esperados (especificos de build_erpt_comparison.m
%     y save_erpt_run.m):
%     horizontes distintos entre specs comparadas, price_vars distintas,
%     choque inexistente en shock_names_sel, Cfg.OUTPUT_DIR faltante en
%     save_erpt_run.
%
%   Pegar el output completo en el chat para verificacion.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 4 -- 4 baselines (ND=3e5) + tabla\n');
fprintf('======================================================\n\n');

%% ── Control de cache: pon esto en true para forzar re-estimacion --------
USE_CACHE = true;   % true = usar <OUTPUT_DIR>/results_is.mat si existe

%% ── Rutas (F5 completo -> mfilename('fullpath') es confiable aqui) ------
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);            % .../refactored/projects/erpt
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);       % .../refactored
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(PROJ_CFG);
addpath(PROJ_SRC);

fprintf('  REF_ROOT   : %s\n', REF_ROOT);
fprintf('  PROJ_ROOT  : %s\n', PROJ_ROOT);
fprintf('  USE_CACHE  : %d\n\n', USE_CACHE);

V = {'FAIL', 'OK  '};
TOL_irf = 1e-6;

% =========================================================================
%  BLOQUE 0 -- Regresion BNW (Chat 7), ND completo
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 0 -- Regresion BNW (Chat 7), spec_bnw_is, ND completo\n');
fprintf('======================================================\n\n');

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
val_ic = median(squeeze(Ltilde_bnw(:, 2, 1, :)), 'all');
REF_ib = 0.2041864191;
REF_ic = 2.9521795528;

ok_ib = abs(val_ib - REF_ib) <= TOL_irf;
ok_ic = abs(val_ic - REF_ic) <= TOL_irf;

fprintf('  Ltilde(end,end,end,end) = %.10f   (ref %.10f)   %s\n', val_ib, REF_ib, V{int32(ok_ib)+1});
fprintf('  median(Lt(:,2,1,:))     = %.10f   (ref %.10f)   %s\n', val_ic, REF_ic, V{int32(ok_ic)+1});
fprintf('  ne efectivo             = %d\n\n', Results_bnw.ne);

bloque0_pasa = ok_ib && ok_ic;
if bloque0_pasa
    fprintf('  >> BLOQUE 0: PASA -- baseline BNW intacto con ND completo.\n\n');
else
    fprintf('  >> BLOQUE 0: NO PASA -- detener y revisar antes de continuar.\n\n');
end

% =========================================================================
%  BLOQUE 1 -- Las 4 specs baseline, corrida cientifica completa
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- 4 specs baseline, Cfg.ND=3e5 (cientifico)\n');
fprintf('======================================================\n\n');

spec_names = {'spec_aa_diffuse_v0', 'spec_aa_minn_v0', 'spec_mm_diffuse_v0', 'spec_mm_minn_v0'};

bloque1_ok      = true;
bloque1_msgs    = {};
Results_by_spec = struct();
Dataset_by_spec = struct();
Cfg_by_spec     = struct();
ERPT_by_spec    = struct();

for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};
    fprintf('------------------------------------------------------\n');
    fprintf('  Spec: %s\n', spec_name);
    fprintf('------------------------------------------------------\n');

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;

    is_aa = ~isempty(strfind(spec_name, '_aa_')); %#ok<STREMP>
    transform_type = 'mm';
    if is_aa
        transform_type = 'aa';
    end

    cache_path   = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
    used_cache   = false;

    if USE_CACHE && isfile(cache_path)
        try
            [Results_spec, ERPT_spec, Dataset_spec, Cfg_cached] = load_erpt_run(Cfg.OUTPUT_DIR);
            used_cache = true;
            Cfg = Cfg_cached;
        catch ME
            fprintf('  [ALERTA] No se pudo cargar cache (%s) -- re-corriendo desde cero.\n', ME.message);
            used_cache = false;
        end
    end

    if ~used_cache
        fprintf('  Dataset: cargando %s...\n', Cfg.DATA_FILE);
        Dataset_spec = load_data(Cfg);
        fprintf('  Dataset: %d variables endogenas, freq=%s, T=%d obs\n', ...
            Dataset_spec.nvar, Dataset_spec.freq, size(Dataset_spec.Y_raw, 1));

        validate_cfg(Cfg, Dataset_spec);
        Posterior_spec = build_posterior(Dataset_spec, Cfg);

        fprintf('  Corriendo IS (nd=%g, CIENTIFICO -- puede tomar varios minutos)...\n', Cfg.ND);
        rng('default'); rng(Cfg.SEED);
        tic;
        Results_spec = run_is(Posterior_spec, Cfg);
        Results_spec.t_elapsed = toc;
        fprintf('  Tiempo: %.1f seg | ne=%d\n', Results_spec.t_elapsed, Results_spec.ne);

        try
            ERPT_spec = calculate_erpt(Results_spec, Dataset_spec, Cfg, transform_type);
        catch ME
            bloque1_ok = false;
            bloque1_msgs{end+1} = sprintf('%s: ERROR en calculate_erpt: %s', spec_name, ME.message); %#ok<AGROW>
            fprintf('  [ERROR] %s\n\n', ME.message);
            continue;
        end

        save_erpt_run(Results_spec, ERPT_spec, Dataset_spec, Cfg);
    else
        fprintf('  ne=%d (desde cache)\n', Results_spec.ne);
    end

    n_shocks_out = numel(ERPT_spec.shocks);
    if n_shocks_out ~= Dataset_spec.nvar
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: se esperaban %d choques, se obtuvieron %d', ...
            spec_name, Dataset_spec.nvar, n_shocks_out); %#ok<AGROW>
    end
    names_out = {ERPT_spec.shocks.name};
    if ~all(ismember({'Cam','Dem','Ofe'}, names_out))
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: no se encontraron los 3 choques nombrados Cam/Dem/Ofe', spec_name); %#ok<AGROW>
    end
    if Results_spec.ne < 100
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: ne=%d parece bajo para ND=3e5 -- revisar tasa de aceptacion', ...
            spec_name, Results_spec.ne); %#ok<AGROW>
    end

    Results_by_spec.(spec_name) = Results_spec;
    Dataset_by_spec.(spec_name) = Dataset_spec;
    Cfg_by_spec.(spec_name)     = Cfg;
    ERPT_by_spec.(spec_name)    = ERPT_spec;

    fprintf('\n');
end

if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- las 4 specs corrieron (o cargaron desde cache)\n');
    fprintf('     con ND cientifico y produjeron 6 choques x 3 precios cada una.\n\n');
else
    fprintf('  >> BLOQUE 1: NO PASA. Detalle:\n');
    for i = 1:numel(bloque1_msgs)
        fprintf('     - %s\n', bloque1_msgs{i});
    end
    fprintf('\n');
end

% =========================================================================
%  BLOQUE 2 -- Tabla comparativa cruzada
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Tabla comparativa cruzada (4 baselines)\n');
fprintf('======================================================\n\n');

bloque2_ok = true;
try
    [T_erpt, T_diag] = build_erpt_comparison(ERPT_by_spec, Results_by_spec, Cfg_by_spec, spec_names);
catch ME
    bloque2_ok = false;
    fprintf('  [ERROR] build_erpt_comparison fallo: %s\n\n', ME.message);
end

if bloque2_ok
    % -- Impresion en consola, por horizonte --------------------------------
    horizons_all = unique(T_erpt.horizon, 'stable');
    for hh = 1:numel(horizons_all)
        h = horizons_all(hh);
        fprintf('  --- Horizonte h=%d ---\n', h);
        sub = T_erpt(T_erpt.horizon == h, :);
        fprintf('  %-6s %-10s', 'Choque', 'Precio');
        for ss = 1:numel(spec_names)
            fprintf('  %20s', spec_names{ss});
        end
        fprintf('\n');
        for rr = 1:height(sub)
            fprintf('  %-6s %-10s', sub.shock{rr}, sub.price_var{rr});
            for ss = 1:numel(spec_names)
                safe_sn = regexprep(spec_names{ss}, '[^a-zA-Z0-9_]', '_');
                med = sub.(sprintf('%s_median', safe_sn))(rr);
                lo  = sub.(sprintf('%s_p_lo', safe_sn))(rr);
                hi  = sub.(sprintf('%s_p_hi', safe_sn))(rr);
                fprintf('  %6.3f[%6.3f,%6.3f]', med, lo, hi);
            end
            fprintf('\n');
        end
        fprintf('\n');
    end

    fprintf('  --- Diagnosticos de corrida por spec ---\n');
    disp(T_diag);

    % -- Exportar a Excel -----------------------------------------------------
    comparison_dir = fullfile(PROJ_ROOT, 'output', 'comparison');
    if ~isfolder(comparison_dir), mkdir(comparison_dir); end
    xlsx_path = fullfile(comparison_dir, 'erpt_comparison.xlsx');
    if isfile(xlsx_path), delete(xlsx_path); end
    writetable(T_erpt, xlsx_path, 'Sheet', 'erpt_comparison');
    writetable(T_diag, xlsx_path, 'Sheet', 'run_diagnostics');
    fprintf('  Tabla comparativa exportada a:\n    %s\n\n', xlsx_path);

    fprintf('  >> BLOQUE 2: PASA -- tabla comparativa construida y exportada.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA.\n\n');
end

% =========================================================================
%  BLOQUE 3 -- Casos de error esperados (build_erpt_comparison / save_erpt_run)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Casos de error esperados\n');
fprintf('======================================================\n\n');

bloque3_ok   = true;
bloque3_msgs = {};

% Caso 1: horizontes distintos entre specs comparadas
try
    ERPT_bad = ERPT_by_spec;
    fn1 = spec_names{1};
    ERPT_bad.(fn1).horizons = ERPT_bad.(fn1).horizons(1:end-1);   % le quita un horizonte
    build_erpt_comparison(ERPT_bad, Results_by_spec, Cfg_by_spec, spec_names);
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'horizontes distintos: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] horizontes distintos no genero error\n');
catch ME
    fprintf('  [OK] horizontes distintos -> error esperado: %s\n', ME.identifier);
end

% Caso 2: price_vars distintas entre specs comparadas
try
    ERPT_bad2 = ERPT_by_spec;
    fn2 = spec_names{2};
    ERPT_bad2.(fn2).price_vars = {'imp_inf', 'con_inf'};   % le quita pro_inf
    build_erpt_comparison(ERPT_bad2, Results_by_spec, Cfg_by_spec, spec_names);
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'price_vars distintas: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] price_vars distintas no genero error\n');
catch ME
    fprintf('  [OK] price_vars distintas -> error esperado: %s\n', ME.identifier);
end

% Caso 3: choque inexistente en shock_names_sel
try
    build_erpt_comparison(ERPT_by_spec, Results_by_spec, Cfg_by_spec, spec_names, {'Cam', 'Mon'});
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'choque inexistente (Mon): NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] choque inexistente no genero error\n');
catch ME
    fprintf('  [OK] choque inexistente (Mon) -> error esperado: %s\n', ME.identifier);
end

% Caso 4: save_erpt_run sin Cfg.OUTPUT_DIR
try
    Cfg_bad = Cfg_by_spec.(spec_names{1});
    Cfg_bad = rmfield(Cfg_bad, 'OUTPUT_DIR');
    save_erpt_run(Results_by_spec.(spec_names{1}), ERPT_by_spec.(spec_names{1}), ...
        Dataset_by_spec.(spec_names{1}), Cfg_bad);
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'save_erpt_run sin OUTPUT_DIR: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] save_erpt_run sin OUTPUT_DIR no genero error\n');
catch ME
    fprintf('  [OK] save_erpt_run sin OUTPUT_DIR -> error esperado: %s\n', ME.identifier);
end

fprintf('\n');
if bloque3_ok
    fprintf('  >> BLOQUE 3: PASA -- los 4 casos de error se comportan como se esperaba.\n\n');
else
    fprintf('  >> BLOQUE 3: NO PASA. Detalle:\n');
    for i = 1:numel(bloque3_msgs)
        fprintf('     - %s\n', bloque3_msgs{i});
    end
    fprintf('\n');
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('======================================================\n');
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 4\n');
fprintf('======================================================\n');
fprintf('  Bloque 0 (Regresion BNW, ND completo)   : %s\n', iif_local(bloque0_pasa, 'PASA', 'NO PASA'));
fprintf('  Bloque 1 (4 baselines, ND cientifico)   : %s\n', iif_local(bloque1_ok,   'PASA', 'NO PASA'));
fprintf('  Bloque 2 (Tabla comparativa)             : %s\n', iif_local(bloque2_ok,   'PASA', 'NO PASA'));
fprintf('  Bloque 3 (Casos de error)                : %s\n', iif_local(bloque3_ok,   'PASA', 'NO PASA'));
fprintf('------------------------------------------------------\n');
if bloque0_pasa && bloque1_ok && bloque2_ok && bloque3_ok
    fprintf('  GLOBAL : PASA\n');
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% ── Helper local ──────────────────────────────────────────────────────────
function out = iif_local(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
