%VALIDATE_ERPT5  ERPT-Chat 5 -- Outputs completos: IRFs, CIRFs, FEVD y ERPT.
%   Protocolo Tipo S (Seccion A, SVARToolkit).
%
%   Ejecutar completo (F5), no por secciones.
%
%   PRE-REQUISITO: las 4 specs baseline deben estar previamente persistidas
%   por ERPT-Chat 4 (validate_erpt_baselines.m) en
%   <OUTPUT_DIR>/results_is.mat. Este script NO vuelve a correr build_posterior/
%   run_is -- solo carga via load_erpt_run.m y genera outputs. Si falta el
%   cache de alguna spec, el script se detiene con un mensaje explicito
%   (correr validate_erpt_baselines.m primero).
%
%   BLOQUE 1 -- Outputs individuales por spec (4 baselines):
%     export_results.m (Chat 10) -- IRF/CIRF/FEVD/metadata/run_diagnostics
%     a Excel. Cfg.EXPORT_HORIZONS = Cfg.ERPT_HORIZONS (decision ERPT-Chat 5:
%     restringir horizontes de export a los 5 de la tabla ERPT, por
%     consistencia -- ver addendum CU-1 en Seccion A).
%     plot_fevd.m (Chat 19/20) -- figuras FEVD por variable, todos los
%     horizontes nativos de Cfg.FEVD_HORIZONS (sin restriccion).
%
%   BLOQUE 2 -- Comparacion cruzada entre las 4 specs:
%     build_irf_comparison.m  (IRF)  -- todos los choques x todas las vars
%     build_irf_comparison.m  (CIRF) -- idem
%     build_fevd_comparison.m (FEVD) -- por choque, variable x horizonte
%     Todas restringidas a los 5 horizontes de Cfg.ERPT_HORIZONS.
%     Export a projects/erpt/output/comparison/outputs_comparison.xlsx.
%
%   BLOQUE 3 -- Casos de error esperados:
%     kind invalido en build_irf_comparison, variables desalineadas,
%     horizonte fuera de Results.FEVD_horizons en build_fevd_comparison.
%
%   Pegar el output completo en el chat para verificacion.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 5 -- Outputs completos (IRF/CIRF/FEVD/ERPT)\n');
fprintf('======================================================\n\n');

%% ── Rutas ──────────────────────────────────────────────────────────────
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(PROJ_CFG);
addpath(PROJ_SRC);

fprintf('  REF_ROOT   : %s\n', REF_ROOT);
fprintf('  PROJ_ROOT  : %s\n\n', PROJ_ROOT);

spec_names = {'spec_aa_diffuse_v0', 'spec_aa_minn_v0', 'spec_mm_diffuse_v0', 'spec_mm_minn_v0'};
n_specs    = numel(spec_names);

% =========================================================================
%  BLOQUE 1 -- Cargar cache + outputs individuales por spec
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- Cargar cache + outputs individuales (4 specs)\n');
fprintf('======================================================\n\n');

Results_by_spec = struct();
Dataset_by_spec = struct();
Cfg_by_spec     = struct();
ERPT_by_spec    = struct();

bloque1_ok   = true;
bloque1_msgs = {};

for ss = 1:n_specs
    spec_name = spec_names{ss};
    fprintf('------------------------------------------------------\n');
    fprintf('  Spec: %s\n', spec_name);
    fprintf('------------------------------------------------------\n');

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));

    cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
    if ~isfile(cache_path)
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf(['%s: no existe %s -- correr ' ...
            'validate_erpt_baselines.m primero (ERPT-Chat 4).'], spec_name, cache_path); %#ok<AGROW>
        fprintf('  [ERROR] cache no encontrado: %s\n\n', cache_path);
        continue;
    end

    [Results_spec, ERPT_spec, Dataset_spec, Cfg_spec] = load_erpt_run(Cfg.OUTPUT_DIR);
    fprintf('  Cargado desde cache. ne=%d\n', Results_spec.ne);

    % -- Outputs individuales: export_results.m con horizontes restringidos --
    Cfg_spec.EXPORT_HORIZONS = Cfg_spec.ERPT_HORIZONS;
    export_results(Results_spec, Dataset_spec, Cfg_spec);

    % -- Figuras FEVD por variable (todos los horizontes nativos) -----------
    plot_fevd(Results_spec, Dataset_spec, Cfg_spec);

    Results_by_spec.(spec_name) = Results_spec;
    Dataset_by_spec.(spec_name) = Dataset_spec;
    Cfg_by_spec.(spec_name)     = Cfg_spec;
    ERPT_by_spec.(spec_name)    = ERPT_spec;

    fprintf('\n');
end

if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- 4 specs cargadas desde cache, outputs individuales generados.\n\n');
else
    fprintf('  >> BLOQUE 1: NO PASA. Detalle:\n');
    for i = 1:numel(bloque1_msgs)
        fprintf('     - %s\n', bloque1_msgs{i});
    end
    fprintf('\n  Deteniendo -- no tiene sentido continuar sin las 4 specs cargadas.\n\n');
    return;
end

% =========================================================================
%  BLOQUE 2 -- Comparacion cruzada entre las 4 specs
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Comparacion cruzada IRF/CIRF/FEVD (4 baselines)\n');
fprintf('======================================================\n\n');

bloque2_ok = true;
horizons_sel = Cfg_by_spec.(spec_names{1}).ERPT_HORIZONS;

try
    T_irf = build_irf_comparison(Results_by_spec, Dataset_by_spec, Cfg_by_spec, spec_names, 'irf', horizons_sel);
    fprintf('  build_irf_comparison (irf) : %d filas x %d columnas\n', height(T_irf), width(T_irf));
catch ME
    bloque2_ok = false;
    fprintf('  [ERROR] build_irf_comparison (irf) fallo: %s\n', ME.message);
end

try
    T_cirf = build_irf_comparison(Results_by_spec, Dataset_by_spec, Cfg_by_spec, spec_names, 'cirf', horizons_sel);
    fprintf('  build_irf_comparison (cirf): %d filas x %d columnas\n', height(T_cirf), width(T_cirf));
catch ME
    bloque2_ok = false;
    fprintf('  [ERROR] build_irf_comparison (cirf) fallo: %s\n', ME.message);
end

try
    T_fevd_by_shock = build_fevd_comparison(Results_by_spec, Dataset_by_spec, Cfg_by_spec, spec_names, horizons_sel);
    shock_fields = fieldnames(T_fevd_by_shock);
    fprintf('  build_fevd_comparison      : %d choques (%s)\n', numel(shock_fields), strjoin(shock_fields, ', '));
catch ME
    bloque2_ok = false;
    fprintf('  [ERROR] build_fevd_comparison fallo: %s\n', ME.message);
end

if bloque2_ok
    comparison_dir = fullfile(PROJ_ROOT, 'output', 'comparison');
    if ~isfolder(comparison_dir), mkdir(comparison_dir); end
    xlsx_path = fullfile(comparison_dir, 'outputs_comparison.xlsx');
    if isfile(xlsx_path), delete(xlsx_path); end

    writetable(T_irf,  xlsx_path, 'Sheet', 'irf_comparison');
    writetable(T_cirf, xlsx_path, 'Sheet', 'cirf_comparison');
    for k = 1:numel(shock_fields)
        sheet_name = sprintf('fevd_%s', shock_fields{k});
        if numel(sheet_name) > 31, sheet_name = sheet_name(1:31); end   % limite Excel
        writetable(T_fevd_by_shock.(shock_fields{k}), xlsx_path, 'Sheet', sheet_name);
    end

    fprintf('\n  Tabla comparativa exportada a:\n    %s\n\n', xlsx_path);
    fprintf('  >> BLOQUE 2: PASA -- comparacion cruzada construida y exportada.\n\n');
else
    fprintf('\n  >> BLOQUE 2: NO PASA.\n\n');
end

% =========================================================================
%  BLOQUE 3 -- Casos de error esperados
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Casos de error esperados\n');
fprintf('======================================================\n\n');

bloque3_ok   = true;
bloque3_msgs = {};

% Caso 1: kind invalido en build_irf_comparison
try
    build_irf_comparison(Results_by_spec, Dataset_by_spec, Cfg_by_spec, spec_names, 'bad_kind');
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'kind invalido: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] kind invalido no genero error\n');
catch ME
    fprintf('  [OK] kind invalido -> error esperado: %s\n', ME.identifier);
end

% Caso 2: variables endogenas desalineadas entre specs (build_irf_comparison)
try
    Dataset_bad = Dataset_by_spec;
    fn1 = spec_names{1};
    Dataset_bad.(fn1).var_names = circshift(Dataset_bad.(fn1).var_names, 1);
    build_irf_comparison(Results_by_spec, Dataset_bad, Cfg_by_spec, spec_names, 'irf', horizons_sel);
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'var_names desalineadas: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] var_names desalineadas no genero error\n');
catch ME
    fprintf('  [OK] var_names desalineadas -> error esperado: %s\n', ME.identifier);
end

% Caso 3: horizonte fuera de Results.FEVD_horizons (build_fevd_comparison)
try
    build_fevd_comparison(Results_by_spec, Dataset_by_spec, Cfg_by_spec, spec_names, [3 6 12 24 999]);
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'horizonte fuera de FEVD_horizons: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] horizonte invalido no genero error\n');
catch ME
    fprintf('  [OK] horizonte fuera de FEVD_horizons -> error esperado: %s\n', ME.identifier);
end

% Caso 4: Cfg.EXPORT_HORIZONS fuera de rango en export_results.m
try
    Cfg_bad = Cfg_by_spec.(spec_names{1});
    Cfg_bad.EXPORT_HORIZONS = [3 6 999];
    export_results(Results_by_spec.(spec_names{1}), Dataset_by_spec.(spec_names{1}), Cfg_bad);
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'EXPORT_HORIZONS fuera de rango: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] EXPORT_HORIZONS fuera de rango no genero error\n');
catch ME
    fprintf('  [OK] EXPORT_HORIZONS fuera de rango -> error esperado: %s\n', ME.identifier);
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
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 5\n');
fprintf('======================================================\n');
fprintf('  Bloque 1 (cache + outputs individuales) : %s\n', iif_local(bloque1_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 2 (comparacion cruzada)           : %s\n', iif_local(bloque2_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 3 (casos de error)                : %s\n', iif_local(bloque3_ok, 'PASA', 'NO PASA'));
fprintf('------------------------------------------------------\n');
if bloque1_ok && bloque2_ok && bloque3_ok
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
