%VALIDATE_CHAT18  Verificacion — Chat 18: template/ alineado a Chat 17 +
%rename examples/ -> projects/ (Tipo S, post-procesamiento y estructura).
%
%   Corre este script COMPLETO (F5 o Run), no por secciones — a diferencia
%   de los pipeline_*.m, este script SI puede usar
%   fileparts(mfilename('fullpath')) de forma confiable porque se ejecuta
%   entero, nunca por Ctrl+Enter seccion a seccion.
%
%   Cubre:
%     SECCION A — Estructura de carpetas: examples/ ya no existe,
%                 projects/bnw/ y projects/oil_market/ si existen
%     SECCION B — Regresion numerica: pipeline_bnw equivalente
%                 (projects/bnw/config/spec_bnw_pfa.m y spec_bnw_is.m)
%                 reproduce los valores de referencia del Chat 7 con
%                 rng(0), corriendo desde su NUEVA ruta projects/bnw/
%     SECCION C — Integracion funcional: spec_template_pfa.m y
%                 spec_template_is.m cargan sin error y construyen S/Z
%                 con las dimensiones correctas via build_restriction_row
%     SECCION D — Casos de error esperados: build_restriction_row sigue
%                 lanzando errores informativos ante indices invalidos
%     SECCION E — Verificacion estatica de pipeline_template.m: usa
%                 PROJ_* (no EX_*), 'projects' (no 'examples'), y OUT_FIG/
%                 OUT_TAB relativos a PROJ_ROOT (no a REF_ROOT)

clear; clc;
fprintf('════════════════════════════════════════════════════\n');
fprintf(' VALIDATE_CHAT18 — template/ + rename examples/->projects/\n');
fprintf('════════════════════════════════════════════════════\n\n');

% validate_chat18.m vive en: refactored/validate/
val_root = fileparts(mfilename('fullpath'));      % .../refactored/validate/
REF_ROOT = fileparts(val_root);                    % .../refactored/

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));

n_pass = 0; n_fail = 0;

%% ── SECCION A — Estructura de carpetas ──────────────────────────────────
fprintf('SECCION A — Estructura de carpetas (rename examples/ -> projects/)\n');

examples_gone = ~isfolder(fullfile(REF_ROOT, 'examples'));
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'A1: refactored/examples/ ya NO existe', examples_gone);

bnw_present = isfolder(fullfile(REF_ROOT, 'projects', 'bnw')) && ...
              isfile(fullfile(REF_ROOT, 'projects', 'bnw', 'pipeline_bnw.m'));
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'A2: refactored/projects/bnw/ existe con pipeline_bnw.m', bnw_present);

oil_present = isfolder(fullfile(REF_ROOT, 'projects', 'oil_market')) && ...
              isfile(fullfile(REF_ROOT, 'projects', 'oil_market', 'pipeline_oil.m'));
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'A3: refactored/projects/oil_market/ existe con pipeline_oil.m', oil_present);

legacy_intact = isfolder(fullfile(REF_ROOT, 'config')) && ...
                isfolder(fullfile(REF_ROOT, 'data')) && ...
                isfile(fullfile(REF_ROOT, 'main.m'));
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'A4: refactored/config, refactored/data, refactored/main.m intactos', legacy_intact);

template_not_renamed = isfolder(fullfile(REF_ROOT, 'template')) && ...
                       ~isfolder(fullfile(REF_ROOT, 'projects', 'template'));
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'A5: refactored/template/ sigue llamandose template (no se renombro)', template_not_renamed);

fprintf('\n');

%% ── SECCION B — Regresion numerica (projects/bnw/) ──────────────────────
fprintf('SECCION B — Regresion numerica desde la nueva ruta projects/bnw/\n');

PROJ_BNW_CFG = fullfile(REF_ROOT, 'projects', 'bnw', 'config');
addpath(PROJ_BNW_CFG);

try
    clear Cfg;
    run(fullfile(PROJ_BNW_CFG, 'spec_bnw_pfa.m'));
    Cfg_pfa = Cfg; clear Cfg;

    Dataset_bnw = load_data(Cfg_pfa);
    Post_pfa    = build_posterior(Dataset_bnw, Cfg_pfa);
    rng(0);
    Results_pfa = run_pfa(Post_pfa, Cfg_pfa);

    Lt = Results_pfa.LtildeStruct.data;
    val_pfa = Lt(end, end, end);
    ok_pfa  = abs(val_pfa - (-0.2326865051)) < 1e-6;
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'B1: BNW PFA desde projects/bnw/ reproduce Ltilde(end,end,end) = -0.2326865051', ...
        ok_pfa, sprintf('obtenido = %.10f', val_pfa));
catch ME
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'B1: BNW PFA desde projects/bnw/', false, ME.message);
end

try
    clear Cfg;
    run(fullfile(PROJ_BNW_CFG, 'spec_bnw_is.m'));
    Cfg_is = Cfg; clear Cfg;

    if ~exist('Dataset_bnw', 'var')
        Dataset_bnw = load_data(Cfg_is);
    end
    Post_is    = build_posterior(Dataset_bnw, Cfg_is);
    rng(0);
    Results_is = run_is(Post_is, Cfg_is);

    Lt_is  = Results_is.LtildeStruct.data;
    val_is = Lt_is(end, end, end, end);
    ok_is  = abs(val_is - 0.2041864191) < 1e-6;
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'B2: BNW IS desde projects/bnw/ reproduce Ltilde(end,end,end,end) = 0.2041864191', ...
        ok_is, sprintf('obtenido = %.10f', val_is));
catch ME
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'B2: BNW IS desde projects/bnw/', false, ME.message);
end

fprintf('\n');

%% ── SECCION C — Integracion funcional del template actualizado ─────────
fprintf('SECCION C — spec_template_pfa.m / spec_template_is.m actualizados\n');

TEMPLATE_CFG = fullfile(REF_ROOT, 'template', 'config');
addpath(TEMPLATE_CFG);

try
    clear Cfg;
    run(fullfile(TEMPLATE_CFG, 'spec_template_pfa.m'));
    Cfg_t_pfa = Cfg; clear Cfg;

    ok_mode = strcmp(Cfg_t_pfa.MODE, 'pfa');
    ok_dims = isequal(size(Cfg_t_pfa.S{1}), [2 4]);   % 2 filas (var1+, var3-), 4 cols (n_vars=4, 1 horizonte)
    ok_z    = all(cellfun(@isempty, Cfg_t_pfa.Z));
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'C1: spec_template_pfa.m carga sin error, MODE=pfa', ok_mode);
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'C2: Cfg.S{1} construido via build_restriction_row tiene dimension [2x4]', ...
        ok_dims, sprintf('size = [%s]', num2str(size(Cfg_t_pfa.S{1}))));
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'C3: Cfg.Z vacio en template PFA (correcto para PFA)', ok_z);
catch ME
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C1-C3: spec_template_pfa.m', false, ME.message);
end

try
    clear Cfg;
    run(fullfile(TEMPLATE_CFG, 'spec_template_is.m'));
    Cfg_t_is = Cfg; clear Cfg;

    ok_mode_is = strcmp(Cfg_t_is.MODE, 'is');
    ok_dims_is = isequal(size(Cfg_t_is.S{1}), [2 4]);
    ok_z_is    = isequal(size(Cfg_t_is.Z{2}), [1 4]);   % var_1 = 0 ante shock 2
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'C4: spec_template_is.m carga sin error, MODE=is', ok_mode_is);
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'C5: Cfg.S{1} en template IS tiene dimension [2x4]', ok_dims_is);
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'C6: Cfg.Z{2} (zero restriction) tiene dimension [1x4]', ok_z_is);
catch ME
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C4-C6: spec_template_is.m', false, ME.message);
end

fprintf('\n');

%% ── SECCION D — Casos de error esperados (build_restriction_row) ───────
fprintf('SECCION D — build_restriction_row sigue validando indices invalidos\n');

try
    build_restriction_row(1, 5, 4, 1, 1);   % horizon_idx=5 > n_horizons=1 -> debe fallar
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'D1: horizon_idx fuera de rango lanza error', false, 'No lanzo error (inesperado)');
catch ME
    ok_id = strcmp(ME.identifier, 'build_restriction_row:badHorizonIdx');
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'D1: horizon_idx fuera de rango lanza error informativo', ok_id, ME.identifier);
end

try
    build_restriction_row(9, 1, 4, 1, 1);   % var_idx=9 > n_vars=4 -> debe fallar
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'D2: var_idx fuera de rango lanza error', false, 'No lanzo error (inesperado)');
catch ME
    ok_id2 = strcmp(ME.identifier, 'build_restriction_row:badVarIdx');
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'D2: var_idx fuera de rango lanza error informativo', ok_id2, ME.identifier);
end

fprintf('\n');

%% ── SECCION E — Verificacion estatica de pipeline_template.m ───────────
fprintf('SECCION E — pipeline_template.m usa PROJ_* y projects/, no EX_*/examples/\n');

pt_path = fullfile(REF_ROOT, 'template', 'pipeline_template.m');
pt_text = fileread(pt_path);

has_proj_root   = contains(pt_text, 'PROJ_ROOT');
no_ex_root      = ~contains(pt_text, 'EX_ROOT');
uses_projects   = contains(pt_text, "'projects'");
no_examples_str = ~contains(pt_text, "'examples'");
out_relative_to_proj = contains(pt_text, "fullfile(PROJ_ROOT, 'output'");
has_skipped_notice   = contains(pt_text, 'Results_pfa.skipped');

[n_pass, n_fail] = rpt(n_pass, n_fail, 'E1: usa PROJ_ROOT', has_proj_root);
[n_pass, n_fail] = rpt(n_pass, n_fail, 'E2: ya no usa EX_ROOT', no_ex_root);
[n_pass, n_fail] = rpt(n_pass, n_fail, 'E3: referencia carpeta ''projects''', uses_projects);
[n_pass, n_fail] = rpt(n_pass, n_fail, 'E4: ya no referencia ''examples''', no_examples_str);
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'E5: OUT_FIG/OUT_TAB relativos a PROJ_ROOT (no a REF_ROOT/output)', out_relative_to_proj);
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'E6: aviso inmediato de Results.skipped en Seccion 3 (igual que pipeline_bnw.m)', has_skipped_notice);

fprintf('\n');

%% ── RESUMEN GLOBAL ───────────────────────────────────────────────────────
fprintf('════════════════════════════════════════════════════\n');
fprintf('RESUMEN: %d PASA | %d FALLA\n', n_pass, n_fail);
if n_fail == 0
    fprintf('VEREDICTO: PASA\n');
else
    fprintf('VEREDICTO: NO PASA\n');
end
fprintf('════════════════════════════════════════════════════\n');

%% ── Funcion auxiliar interna (debe ir al final del script en MATLAB) ────

function [n_pass, n_fail] = rpt(n_pass, n_fail, label, ok, detail)
    if ok
        n_pass = n_pass + 1;
        fprintf('  [PASA]  %s\n', label);
    else
        n_fail = n_fail + 1;
        fprintf('  [FALLA] %s\n', label);
    end
    if nargin >= 5 && ~isempty(detail)
        fprintf('          %s\n', detail);
    end
end
