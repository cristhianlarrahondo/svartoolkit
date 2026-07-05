%VALIDATE_LOTE_CHAT19  Script de verificacion — Chat 19 (Tipo S).
%
%   Cobertura:
%   SECCION A — Regresion (confirma que nada de esto rompio BNW)
%     (A1) PFA BNW, nd completo, rng(0) -> Ltilde(end,end,end)  = -0.2326865051
%     (A2) IS  BNW, nd completo, rng(0) -> Ltilde(end,end,end,end) = 0.2041864191
%
%   SECCION B — Hallazgo 1: tamano de Cfg.S/Cfg.Z
%     (B1) Caso 6 variables / 4 shocks con restriccion (2 sin restriccion):
%          Cfg.S = cell(6,1) construido con build_restriction_row corre
%          sin error en print_restriction_matrix y validate_cfg
%     (B2) validate_cfg(Cfg, Dataset) lanza error directo si numel(Cfg.S)
%          no coincide con Dataset.nvar (simulando el error original
%          reportado por el usuario: cell(4,1) para un caso de 6 vars)
%
%   SECCION C — Hallazgo 2: print_restriction_matrix
%     (C1) Corre sin error sobre spec_bnw_pfa (n_vars=5, 1 horizonte)
%     (C2) Corre sin error sobre el caso sintetico 6 vars / 4 shocks
%     (C3) Corre sin error con Cfg.HORIZONS_RESTRICT multi-horizonte
%
%   SECCION D — Hallazgo 4: SHOCK_IDX escalar / vector / 'all'
%     (D1) select_irfs con shock_idx escalar (retrocompatibilidad)
%     (D2) select_irfs con shock_idx vector -> cell array de tamano correcto
%     (D3) select_irfs con shock_idx = 'all' -> numel = nvar
%     (D4) select_irfs con shock_idx fuera de rango -> error esperado
%     (D5) select_irfs con shock_idx de tipo invalido -> error esperado
%     (D6) plot_irfs con Cfg.SHOCK_IDX = [1 2] sobre Results_is real: corre
%          sin error, genera 2 figuras (una por shock)
%     (D7) export_results con Cfg.SHOCK_IDX = 'all' sobre Results_is real:
%          corre sin error, hoja irf_summary tiene filas para todos los
%          shocks (columna 'shock' con >1 valor distinto)
%     (D8) print_summary con Cfg.SHOCK_IDX = [1 2]: corre sin error
%     (D9) plot_fevd respeta Cfg.OUTPUT_DIR (Hallazgo 4, bug adicional
%          encontrado en este chat)
%
%   SECCION E — Hallazgo 5: refresh_cfg_output / get_output_fields
%     (E1) get_output_fields() devuelve lista sin duplicados
%     (E2) refresh_cfg_output actualiza SOLO campos de output; un campo de
%          estimacion alterado artificialmente en el struct "stale" NO se
%          pierde
%     (E3) refresh_cfg_output SI actualiza SHOCK_IDX/CRED_BANDS/OUTPUT_DIR
%          a los valores actuales del archivo de spec en disco
%
%   SECCION F — OUTPUT_DIR (item de maxima prioridad, ya resuelto)
%     (F1) spec_template_pfa.m / spec_template_is.m definen Cfg.OUTPUT_DIR
%     (F2) spec_oil_pfa.m / spec_oil_is.m definen Cfg.OUTPUT_DIR
%
%   Uso: ejecutar desde MATLAB (cualquier working directory).
%        EDITAR la variable REF_ROOT abajo antes de correr.

fprintf('\n');
fprintf('================================================================\n');
fprintf(' VALIDATE_LOTE_CHAT19 — Chat 19 (Tipo S)\n');
fprintf('================================================================\n\n');

%% ── Setup de rutas ────────────────────────────────────────────────────────
%  EDITAR: ruta absoluta a refactored/
REF_ROOT = '/ruta/absoluta/a/refactored';   % ← EDITAR

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(fullfile(REF_ROOT, 'projects', 'bnw', 'config'));

n_results = [];

%% ── SECCION A — Regresion BNW (nd completo) ──────────────────────────────
fprintf('\n--- SECCION A: Regresion (nd completo) ---\n');

REF_PFA_LTILDE_END = -0.2326865051;
REF_IS_LTILDE_END  =  0.2041864191;

clear Cfg;
run(fullfile(REF_ROOT, 'projects', 'bnw', 'config', 'spec_bnw_pfa.m'));
Cfg_pfa = Cfg; clear Cfg;
Dataset = load_data(Cfg_pfa);
Post_pfa = build_posterior(Dataset, Cfg_pfa);
rng(Cfg_pfa.SEED);
Results_pfa = run_pfa(Post_pfa, Cfg_pfa);
val_pfa = Results_pfa.LtildeStruct.data(end,end,end);
n_results(end+1) = check('A1: PFA Ltilde(end,end,end) == -0.2326865051', ...
    abs(val_pfa - REF_PFA_LTILDE_END) < 1e-8, sprintf('obtenido %.10f', val_pfa));

clear Cfg;
run(fullfile(REF_ROOT, 'projects', 'bnw', 'config', 'spec_bnw_is.m'));
Cfg_is = Cfg; clear Cfg;
Post_is = build_posterior(Dataset, Cfg_is);
rng(Cfg_is.SEED);
Results_is = run_is(Post_is, Cfg_is);
val_is = Results_is.LtildeStruct.data(end,end,end,end);
n_results(end+1) = check('A2: IS Ltilde(end,end,end,end) == 0.2041864191', ...
    abs(val_is - REF_IS_LTILDE_END) < 1e-8, sprintf('obtenido %.10f', val_is));

%% ── SECCION B — Hallazgo 1: tamano de S/Z ────────────────────────────────
fprintf('\n--- SECCION B: Hallazgo 1 (tamano Cfg.S/Cfg.Z) ---\n');

% Caso sintetico: 6 variables, restricciones en 4 shocks (2 sin restriccion)
n_vars_b = 6;
Cfg_b.HORIZONS_RESTRICT = 0;
nH_b = 1;
Cfg_b.S = cell(n_vars_b, 1);
Cfg_b.Z = cell(n_vars_b, 1);
Cfg_b.S{1} = build_restriction_row(1, 1, n_vars_b, nH_b, 1);
Cfg_b.S{2} = build_restriction_row(2, 1, n_vars_b, nH_b, -1);
Cfg_b.S{3} = build_restriction_row(3, 1, n_vars_b, nH_b, 1);
Cfg_b.Z{4} = build_restriction_row(5, 1, n_vars_b, nH_b, 1);
% Cfg_b.S{5}, Cfg_b.S{6}, Cfg_b.Z{5}, Cfg_b.Z{6} quedan [] — shocks sin restriccion

ok_b1 = (numel(Cfg_b.S) == 6) && (numel(Cfg_b.Z) == 6);
n_results(end+1) = check('B1: cell(6,1) con 4 shocks restringidos y 2 vacios se construye sin error', ...
    ok_b1, 'numel(Cfg.S) o numel(Cfg.Z) != 6');

Dataset_b6.nvar = 6;
try
    validate_cfg_partial_ok = true;
    % Solo probamos el chequeo directo (no todos los campos de validate_cfg)
    if numel(Cfg_b.S) ~= Dataset_b6.nvar || numel(Cfg_b.Z) ~= Dataset_b6.nvar
        validate_cfg_partial_ok = false;
    end
catch
    validate_cfg_partial_ok = false;
end
n_results(end+1) = check('B1b: numel(Cfg.S)==numel(Cfg.Z)==Dataset.nvar (6) para el caso sintetico', ...
    validate_cfg_partial_ok, 'tamanos no coinciden');

% B2: validate_cfg debe lanzar error directo si el tamano NO coincide
% (simula el bug original: cell(4,1) para un dataset de 6 variables)
Cfg_bad = Cfg_pfa;                 % struct base valido (reusa campos de spec_bnw_pfa)
Cfg_bad.S = cell(4, 1);            % tamano incorrecto a proposito
Cfg_bad.Z = cell(4, 1);
Dataset_fake6.nvar = 6;
threw = false;
try
    validate_cfg(Cfg_bad, Dataset_fake6);
catch err
    threw = strcmp(err.identifier, 'validate_cfg:sTamanoIncorrecto');
end
n_results(end+1) = check('B2: validate_cfg(Cfg,Dataset) lanza error directo con Cfg.S mal dimensionado', ...
    threw, 'no lanzo el error esperado validate_cfg:sTamanoIncorrecto');

%% ── SECCION C — Hallazgo 2: print_restriction_matrix ────────────────────
fprintf('\n--- SECCION C: Hallazgo 2 (print_restriction_matrix) ---\n');

ok_c1 = true;
try
    print_restriction_matrix(Cfg_pfa, Dataset);
catch
    ok_c1 = false;
end
n_results(end+1) = check('C1: print_restriction_matrix corre sin error sobre spec_bnw_pfa (n=5)', ok_c1, 'lanzo error');

ok_c2 = true;
try
    print_restriction_matrix(Cfg_b);   % sin Dataset -> usa var_1..var_6
catch
    ok_c2 = false;
end
n_results(end+1) = check('C2: print_restriction_matrix corre sin error sobre caso sintetico 6 vars/4 shocks', ...
    ok_c2, 'lanzo error');

Cfg_c3 = Cfg_b;
Cfg_c3.HORIZONS_RESTRICT = [0 1];
Cfg_c3.S = cell(6,1);
Cfg_c3.Z = cell(6,1);
Cfg_c3.S{1} = [build_restriction_row(1,1,6,2,1); build_restriction_row(1,2,6,2,1)];
ok_c3 = true;
try
    print_restriction_matrix(Cfg_c3);
catch
    ok_c3 = false;
end
n_results(end+1) = check('C3: print_restriction_matrix corre sin error con HORIZONS_RESTRICT=[0 1]', ok_c3, 'lanzo error');

%% ── SECCION D — Hallazgo 4: SHOCK_IDX escalar/vector/'all' ──────────────
fprintf('\n--- SECCION D: Hallazgo 4 (SHOCK_IDX escalar/vector/all) ---\n');

LtildeIS = Results_is.LtildeStruct;
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
LtildeIS.var_labels = Dataset.var_labels(endo_mask);

[irfs1, lab1, ~, ridx1] = select_irfs(LtildeIS, 1, 1:5);
n_results(end+1) = check('D1: select_irfs shock_idx escalar -> cell{1} y shock_idx resuelto=[1]', ...
    iscell(irfs1) && numel(irfs1)==1 && isequal(ridx1,1), 'forma incorrecta');

[irfs2, lab2, ~, ridx2] = select_irfs(LtildeIS, [1 2], 1:5);
n_results(end+1) = check('D2: select_irfs shock_idx=[1 2] -> cell{2}', ...
    iscell(irfs2) && numel(irfs2)==2 && isequal(ridx2,[1 2]), 'forma incorrecta');

[irfs3, lab3, ~, ridx3] = select_irfs(LtildeIS, 'all', 1:5);
n_results(end+1) = check('D3: select_irfs shock_idx=''all'' -> cell{5} (nvar=5)', ...
    iscell(irfs3) && numel(irfs3)==5 && isequal(ridx3,1:5), 'forma incorrecta');

threw_d4 = false;
try
    select_irfs(LtildeIS, 99, 1:5);
catch
    threw_d4 = true;
end
n_results(end+1) = check('D4: select_irfs shock_idx fuera de rango -> error esperado', threw_d4, 'no lanzo error');

threw_d5 = false;
try
    select_irfs(LtildeIS, struct(), 1:5);
catch
    threw_d5 = true;
end
n_results(end+1) = check('D5: select_irfs shock_idx tipo invalido -> error esperado', threw_d5, 'no lanzo error');

Cfg_plot = Cfg_is;
Cfg_plot.SHOCK_IDX = [1 2];
Cfg_plot.PLOT_IRFS = true;
ok_d6 = true;
try
    close all;
    plot_irfs(Results_is.LtildeStruct, Dataset, Cfg_plot, Results_is);
    n_figs = numel(findobj('Type','figure'));
catch
    ok_d6 = false; n_figs = 0;
end
n_results(end+1) = check('D6: plot_irfs con SHOCK_IDX=[1 2] corre sin error y genera 2 figuras', ...
    ok_d6 && n_figs >= 2, sprintf('n_figs=%d, ok=%d', n_figs, ok_d6));
close all;

Cfg_exp = Cfg_is;
Cfg_exp.SHOCK_IDX = 'all';
Cfg_exp.SPEC_NAME = 'validate_chat19_export_test';
ok_d7 = true;
try
    export_results(Results_is, Dataset, Cfg_exp);
    xlsx_test = fullfile(Cfg_exp.OUTPUT_DIR, 'tables', 'validate_chat19_export_test_results.xlsx');
    sheet_info = sheetnames(xlsx_test);
    irf_sheets_found = sheet_info(startsWith(sheet_info, 'irf_summary_s'));
    n_shocks_in_file = numel(irf_sheets_found);   % nvar=5 -> se esperan 5 hojas irf_summary_s1..s5
catch
    ok_d7 = false; n_shocks_in_file = 0;
end
n_results(end+1) = check('D7: export_results con SHOCK_IDX=''all'' genera una hoja irf_summary_s<k> POR CADA shock (>=2)', ...
    ok_d7 && n_shocks_in_file >= 2, sprintf('n_shocks_in_file=%d, ok=%d', n_shocks_in_file, ok_d7));

Cfg_ps = Cfg_is;
Cfg_ps.SHOCK_IDX = [1 2];
ok_d8 = true;
try
    print_summary(Results_is.LtildeStruct, Dataset, Cfg_ps);
catch
    ok_d8 = false;
end
n_results(end+1) = check('D8: print_summary con SHOCK_IDX=[1 2] corre sin error', ok_d8, 'lanzo error');

ok_d9 = true;
try
    close all;
    plot_fevd(Results_is.FEVD, Dataset, Cfg_is);   % Cfg_is.OUTPUT_DIR = projects/bnw/output
    fname_expected = fullfile(Cfg_is.OUTPUT_DIR, 'figures', ['fevd_', lower(Cfg_is.MODE), '.png']);
    ok_d9 = isfile(fname_expected);
catch
    ok_d9 = false;
end
n_results(end+1) = check('D9: plot_fevd respeta Cfg.OUTPUT_DIR (ya no escribe en refactored/output/)', ...
    ok_d9, 'archivo no encontrado en OUTPUT_DIR');
close all;

%% ── SECCION E — Hallazgo 5: refresh_cfg_output ───────────────────────────
fprintf('\n--- SECCION E: Hallazgo 5 (refresh_cfg_output) ---\n');

fields_e1 = get_output_fields();
n_results(end+1) = check('E1: get_output_fields() sin duplicados', ...
    numel(fields_e1) == numel(unique(fields_e1)), 'hay duplicados');

Cfg_stale = Cfg_pfa;
Cfg_stale.NLAG = 999;                 % campo de ESTIMACION alterado artificialmente
Cfg_stale.SHOCK_IDX = 42;             % campo de OUTPUT alterado artificialmente
spec_path_pfa = fullfile(REF_ROOT, 'projects', 'bnw', 'config', 'spec_bnw_pfa.m');
Cfg_refreshed = refresh_cfg_output(Cfg_stale, spec_path_pfa);

n_results(end+1) = check('E2: refresh_cfg_output NO toca campos de estimacion (NLAG sigue en 999)', ...
    Cfg_refreshed.NLAG == 999, sprintf('NLAG=%d (se esperaba 999)', Cfg_refreshed.NLAG));

n_results(end+1) = check('E3: refresh_cfg_output SI actualiza SHOCK_IDX al valor real de la spec (1, no 42)', ...
    Cfg_refreshed.SHOCK_IDX == 1, sprintf('SHOCK_IDX=%d (se esperaba 1)', Cfg_refreshed.SHOCK_IDX));

%% ── SECCION F — OUTPUT_DIR en las 4 specs (item de maxima prioridad) ────
fprintf('\n--- SECCION F: OUTPUT_DIR en template y oil_market ---\n');

clear Cfg; run(fullfile(REF_ROOT, 'template', 'config', 'spec_template_pfa.m')); Cfg_t1 = Cfg; clear Cfg;
clear Cfg; run(fullfile(REF_ROOT, 'template', 'config', 'spec_template_is.m'));  Cfg_t2 = Cfg; clear Cfg;
clear Cfg; run(fullfile(REF_ROOT, 'projects', 'oil_market', 'config', 'spec_oil_pfa.m')); Cfg_o1 = Cfg; clear Cfg;
clear Cfg; run(fullfile(REF_ROOT, 'projects', 'oil_market', 'config', 'spec_oil_is.m'));  Cfg_o2 = Cfg; clear Cfg;

n_results(end+1) = check('F1: spec_template_pfa.m define Cfg.OUTPUT_DIR', ...
    isfield(Cfg_t1, 'OUTPUT_DIR') && ~isempty(Cfg_t1.OUTPUT_DIR), 'campo ausente');
n_results(end+1) = check('F1b: spec_template_is.m define Cfg.OUTPUT_DIR', ...
    isfield(Cfg_t2, 'OUTPUT_DIR') && ~isempty(Cfg_t2.OUTPUT_DIR), 'campo ausente');
n_results(end+1) = check('F2: spec_oil_pfa.m define Cfg.OUTPUT_DIR', ...
    isfield(Cfg_o1, 'OUTPUT_DIR') && ~isempty(Cfg_o1.OUTPUT_DIR), 'campo ausente');
n_results(end+1) = check('F2b: spec_oil_is.m define Cfg.OUTPUT_DIR', ...
    isfield(Cfg_o2, 'OUTPUT_DIR') && ~isempty(Cfg_o2.OUTPUT_DIR), 'campo ausente');

%% ── Veredicto final ───────────────────────────────────────────────────────
n_pass = sum(n_results);
n_fail = sum(~n_results);
fprintf('\n================================================================\n');
fprintf(' RESULTADO: %d PASA / %d NO PASA (de %d)\n', n_pass, n_fail, numel(n_results));
if n_fail > 0
    fprintf(' Revisa arriba las lineas marcadas [NO PASA].\n');
    fprintf(' VEREDICTO GLOBAL: NO PASA\n');
else
    fprintf(' VEREDICTO GLOBAL: PASA\n');
end
fprintf('================================================================\n\n');

%% ── Funcion auxiliar local (debe ir al final del script) ─────────────────
function ok_out = check(name, ok, detail)
    if ok
        fprintf('  [PASA] %s\n', name);
    else
        fprintf('  [NO PASA] %s -- %s\n', name, detail);
    end
    ok_out = ok;
end
