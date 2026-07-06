%VALIDATE_LOTE_CHAT19  Script de verificacion — Chat 19 (Tipo MIXTO: S + R).
%
%   ACTUALIZACION: este chat paso de ser puramente Tipo S a MIXTO porque
%   los Hallazgos 6 (FEVD multi-shock/horizonte) y 7/8 (Cfg.VARS + n_vars
%   auto) tocan run_pfa.m/run_is.m/load_data.m — Tipo R por definicion.
%   Por eso la Seccion A (regresion BNW completa, Ltilde) se corre
%   DESPUES de todos los cambios de este chat, no antes.
%
%   Cobertura (Secciones A-F: hallazgos ya resueltos antes de esta sesion;
%   Secciones G-L: hallazgos nuevos de esta sesion):
%
%   SECCION A — Regresion (confirma que NADA de este chat, incluyendo los
%     cambios Tipo R a load_data.m/run_pfa.m/run_is.m, rompio BNW)
%     (A1) PFA BNW, nd completo, rng(0) -> Ltilde(end,end,end)  = -0.2326865051
%     (A2) IS  BNW, nd completo, rng(0) -> Ltilde(end,end,end,end) = 0.2041864191
%
%   SECCION B — Hallazgo 1: tamano de Cfg.S/Cfg.Z (ya resuelto)
%   SECCION C — Hallazgo 2: print_restriction_matrix (ya resuelto)
%   SECCION D — Hallazgo 4: SHOCK_IDX escalar/vector/'all' (ya resuelto)
%   SECCION E — Hallazgo 5: refresh_cfg_output / get_output_fields (ya resuelto)
%   SECCION F — OUTPUT_DIR en las 4 specs (ya resuelto)
%
%   SECCION G — Hallazgo 12: plot_irfs grafica TODAS las variables
%     (G1) Caso sintetico de 6 variables: plot_irfs genera 6 paneles, no 5
%     (G2) Grid dinamico: 7 variables -> 3 columnas x 3 filas
%
%   SECCION H — Hallazgo 6: FEVD multi-shock x multi-horizonte
%     (H1) run_is.m: Results.FEVD tiene forma [n x n_fevd_shocks x n_fevd_h x ne]
%     (H2) Default IS (Cfg.SHOCK_IDX no definido): FEVD_shock_idx = 1:n ('all')
%     (H3) Cfg.SHOCK_IDX=[1 2] (IS): FEVD_shock_idx == [1 2]
%     (H4) Cfg.FEVD_HORIZONS=[1 5 10]: FEVD_horizons == [1 5 10], n_fevd_h=3
%     (H5) run_pfa.m: Results.FEVD tiene forma [n x 1 x n_fevd_h x nd]
%     (H6) Cfg.FEVD_HORIZONS=0 (invalido, <1) -> error esperado (run_is/run_pfa)
%     (H7) plot_fevd corre sin error sobre Results_is real y genera 1
%          archivo POR VARIABLE (nvar archivos fevd_var<K>_*.png)
%     (H8) plot_fevd con PFA skipped (>1 shock restringido): retorna sin
%          error y sin generar archivos (is_run_skipped)
%
%   SECCION I — Hallazgo 7/8: Cfg.VARS + n_vars auto-derivado
%     (I1) Cfg.VARS no definido (BNW): Dataset.nvar_total y var_names
%          identicos a cargar sin Cfg.VARS — regresion exacta
%     (I2) Cfg.VARS = subconjunto/reordenado de 3 de las 5 variables BNW:
%          Dataset.nvar_total=3, orden y contenido correctos
%     (I3) Cfg.VARS con un nombre inexistente -> error esperado
%     (I4) validate_cfg detecta numel(Cfg.VARS) != numel(Cfg.VAR_ROLES)
%
%   SECCION J — Hallazgo 9: Cfg.SHOCK_NAMES (naming, ya no reusa var_labels)
%     (J1) select_irfs sin SHOCK_NAMES -> labels_shock = 'shock1','shock2',...
%     (J2) select_irfs con SHOCK_NAMES = {'supply','demand'} -> labels
%          correctos, y NO coinciden con los labels de variables
%     (J3) plot_irfs con SHOCK_NAMES genera archivo 'irf_shock1_supply*.png'
%
%   SECCION K — Hallazgo 10: titulos IRF vs CIRF diferenciados
%     (K1) Figura IRF: Name contiene 'IRF - ', no 'CIRF -'
%     (K2) Figura CIRF: Name contiene 'CIRF - '
%
%   SECCION L — Hallazgo 11: export_results formato ancho
%     (L1) Hoja irf_summary tiene columnas '<resp>_median'/'<resp>_p16'/
%          '<resp>_p84' (formato ancho), no columnas 'response'/'median' (largo)
%     (L2) Filas ordenadas por horizonte ascendente desde 0
%     (L3) fevd_summary_v<k> (o fevd_summary si nresp=1) existe con
%          columnas por shock
%
%   Uso: ejecutar desde MATLAB (cualquier working directory).
%        EDITAR la variable REF_ROOT abajo antes de correr.

fprintf('\n');
fprintf('================================================================\n');
fprintf(' VALIDATE_LOTE_CHAT19 — Chat 19 (Tipo MIXTO: S + R)\n');
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
    plot_fevd(Results_is, Dataset, Cfg_is);   % Chat 19: firma nueva (Results, Dataset, Cfg)
    % Nombre esperado con la convencion nueva (Hallazgo 9, adaptada a FEVD
    % por variable): fevd_var<K>_<VARNAME>.png para la primera variable
    % endogena de BNW (tfp, var 1).
    endo_mask_d9 = strcmp(Dataset.var_roles, 'endogenous');
    v1_label     = Dataset.var_labels(endo_mask_d9); v1_label = v1_label{1};
    v1_safe      = regexprep(v1_label, '[^a-zA-Z0-9_]', '_');
    fname_expected = fullfile(Cfg_is.OUTPUT_DIR, 'figures', sprintf('fevd_var1_%s.png', v1_safe));
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

%% ── SECCION G — Hallazgo 12: plot_irfs grafica TODAS las variables ──────
fprintf('\n--- SECCION G: Hallazgo 12 (grid dinamico, sin truncar variables) ---\n');

tmp_out_g = fullfile(tempdir, 'validate_chat19_tmp_g');
if ~isfolder(tmp_out_g), mkdir(tmp_out_g); end

for nvar_g = [6 7]
    horizon_g = 10; nd_g = 30;
    clear LtildeG Dataset_g Cfg_g
    LtildeG.mode      = 'pfa';
    LtildeG.data      = randn(horizon_g+1, nvar_g, nd_g);
    LtildeG.shock_idx = 1;
    LtildeG.horizon   = horizon_g;
    LtildeG.nvar      = nvar_g;
    LtildeG.ndraws    = nd_g;

    Dataset_g.var_roles  = repmat({'endogenous'}, 1, nvar_g);
    Dataset_g.var_labels = arrayfun(@(k) sprintf('var%d', k), 1:nvar_g, 'UniformOutput', false);

    Cfg_g.IRF_TYPE   = 'irf';
    Cfg_g.SHOCK_IDX  = 1;
    Cfg_g.CRED_BANDS = [0.16 0.84];
    Cfg_g.OUTPUT_DIR = tmp_out_g;

    ok_gk = true; n_axes = 0;
    try
        close all;
        plot_irfs(LtildeG, Dataset_g, Cfg_g);
        n_axes = numel(findobj(gcf, 'Type', 'axes'));
    catch
        ok_gk = false;
    end
    n_results(end+1) = check(sprintf('G: plot_irfs grafica las %d variables (no trunca)', nvar_g), ...
        ok_gk && n_axes == nvar_g, sprintf('n_axes=%d (esperado %d)', n_axes, nvar_g));
    close all;
end

%% ── SECCION H — Hallazgo 6: FEVD multi-shock x multi-horizonte ──────────
fprintf('\n--- SECCION H: Hallazgo 6 (FEVD multi-shock/horizonte) ---\n');

n_h_test = numel(Cfg_is.FEVD_HORIZONS);   % = 40, via spec_bnw_base.m (1:HORIZON)

n_results(end+1) = check('H1: run_is.m Results.FEVD tiene forma [n x n_fevd_shocks x n_fevd_h x ne]', ...
    ndims(Results_is.FEVD) == 4 && size(Results_is.FEVD,1) == 5, ...
    sprintf('size=%s', mat2str(size(Results_is.FEVD))));

% H2: default IS (sin Cfg.SHOCK_IDX) -> FEVD_shock_idx = 1:n ('all')
Cfg_h2 = Cfg_is; Cfg_h2.ND = 200; Cfg_h2 = rmfield(Cfg_h2, 'SHOCK_IDX');
rng(Cfg_h2.SEED);
Results_h2 = run_is(Post_is, Cfg_h2);
n_results(end+1) = check('H2: IS sin Cfg.SHOCK_IDX -> FEVD_shock_idx == 1:5 (default all)', ...
    isequal(Results_h2.FEVD_shock_idx, 1:5), sprintf('obtenido %s', mat2str(Results_h2.FEVD_shock_idx)));

% H3: Cfg.SHOCK_IDX=[1 2] -> FEVD_shock_idx == [1 2]
Cfg_h3 = Cfg_is; Cfg_h3.ND = 200; Cfg_h3.SHOCK_IDX = [1 2];
rng(Cfg_h3.SEED);
Results_h3 = run_is(Post_is, Cfg_h3);
n_results(end+1) = check('H3: IS con Cfg.SHOCK_IDX=[1 2] -> FEVD_shock_idx == [1 2]', ...
    isequal(Results_h3.FEVD_shock_idx, [1 2]), sprintf('obtenido %s', mat2str(Results_h3.FEVD_shock_idx)));

% H4: Cfg.FEVD_HORIZONS=[1 5 10] -> FEVD_horizons == [1 5 10]
Cfg_h4 = Cfg_is; Cfg_h4.ND = 200; Cfg_h4.FEVD_HORIZONS = [1 5 10];
rng(Cfg_h4.SEED);
Results_h4 = run_is(Post_is, Cfg_h4);
n_results(end+1) = check('H4: Cfg.FEVD_HORIZONS=[1 5 10] -> FEVD_horizons coincide y n_fevd_h=3', ...
    isequal(Results_h4.FEVD_horizons, [1 5 10]) && size(Results_h4.FEVD,3) == 3, ...
    sprintf('FEVD_horizons=%s, size dim3=%d', mat2str(Results_h4.FEVD_horizons), size(Results_h4.FEVD,3)));

% H5: run_pfa.m -> FEVD tiene forma [n x 1 x n_fevd_h x nd]
n_results(end+1) = check('H5: run_pfa.m Results.FEVD tiene dimension de shock == 1', ...
    ndims(Results_pfa.FEVD) == 4 && size(Results_pfa.FEVD,2) == 1, ...
    sprintf('size=%s', mat2str(size(Results_pfa.FEVD))));

% H6: Cfg.FEVD_HORIZONS=0 (invalido) -> error esperado, en IS y en PFA
Cfg_h6is = Cfg_is; Cfg_h6is.ND = 20; Cfg_h6is.FEVD_HORIZONS = 0;
threw_h6is = false;
try
    run_is(Post_is, Cfg_h6is);
catch
    threw_h6is = true;
end
n_results(end+1) = check('H6a: run_is con Cfg.FEVD_HORIZONS=0 -> error esperado', threw_h6is, 'no lanzo error');

Cfg_h6pfa = Cfg_pfa; Cfg_h6pfa.ND = 20; Cfg_h6pfa.FEVD_HORIZONS = 0;
threw_h6pfa = false;
try
    rng(Cfg_h6pfa.SEED);
    run_pfa(Post_pfa, Cfg_h6pfa);
catch
    threw_h6pfa = true;
end
n_results(end+1) = check('H6b: run_pfa con Cfg.FEVD_HORIZONS=0 -> error esperado', threw_h6pfa, 'no lanzo error');

% H7: plot_fevd corre sin error y genera 1 archivo POR VARIABLE (5 en BNW)
tmp_out_h = fullfile(tempdir, 'validate_chat19_tmp_h');
if ~isfolder(tmp_out_h), mkdir(tmp_out_h); end
Cfg_h7 = Cfg_is; Cfg_h7.OUTPUT_DIR = tmp_out_h;
ok_h7 = true; n_fevd_files = 0;
try
    close all;
    plot_fevd(Results_is, Dataset, Cfg_h7);
    d = dir(fullfile(tmp_out_h, 'figures', 'fevd_var*.png'));
    n_fevd_files = numel(d);
catch
    ok_h7 = false;
end
n_results(end+1) = check('H7: plot_fevd genera 1 archivo POR VARIABLE (5 en BNW)', ...
    ok_h7 && n_fevd_files == 5, sprintf('n_fevd_files=%d', n_fevd_files));
close all;

% H8: plot_fevd con corrida "skipped" -> retorna sin error, sin archivos
Results_h8.skipped     = true;
Results_h8.skip_reason = 'prueba sintetica H8';
n_before_h8 = numel(dir(fullfile(tmp_out_h, 'figures', 'fevd_var*.png')));
ok_h8 = true;
try
    plot_fevd(Results_h8, Dataset, Cfg_h7);
catch
    ok_h8 = false;
end
n_after_h8 = numel(dir(fullfile(tmp_out_h, 'figures', 'fevd_var*.png')));
n_results(end+1) = check('H8: plot_fevd con Results.skipped=true no falla y no genera archivos nuevos', ...
    ok_h8 && n_after_h8 == n_before_h8, sprintf('antes=%d, despues=%d, ok=%d', n_before_h8, n_after_h8, ok_h8));

%% ── SECCION I — Hallazgo 7/8: Cfg.VARS + n_vars auto-derivado ───────────
fprintf('\n--- SECCION I: Hallazgo 7/8 (Cfg.VARS + n_vars auto) ---\n');

n_results(end+1) = check('I1: sin Cfg.VARS (BNW), Dataset.nvar_total == 5 (regresion)', ...
    Dataset.nvar_total == 5, sprintf('nvar_total=%d', Dataset.nvar_total));

Cfg_i2 = Cfg_pfa;
Cfg_i2.VARS = {Dataset.var_names{3}, Dataset.var_names{1}};   % 2 de 5, reordenadas
Dataset_i2 = load_data(Cfg_i2);
n_results(end+1) = check('I2: Cfg.VARS selecciona y reordena 2 de 5 columnas correctamente', ...
    Dataset_i2.nvar_total == 2 && ...
    strcmp(Dataset_i2.var_names{1}, Dataset.var_names{3}) && ...
    strcmp(Dataset_i2.var_names{2}, Dataset.var_names{1}), ...
    sprintf('nvar_total=%d, var_names=%s', Dataset_i2.nvar_total, strjoin(Dataset_i2.var_names, ',')));

Cfg_i3 = Cfg_pfa;
Cfg_i3.VARS = {'variable_que_no_existe_xyz'};
threw_i3 = false;
try
    load_data(Cfg_i3);
catch
    threw_i3 = true;
end
n_results(end+1) = check('I3: Cfg.VARS con nombre inexistente -> error esperado', threw_i3, 'no lanzo error');

Cfg_i4 = Cfg_pfa;
Cfg_i4.VARS      = {Dataset.var_names{1}, Dataset.var_names{2}};   % 2 elementos
Cfg_i4.VAR_ROLES = {'endogenous'};                                  % 1 elemento (mismatch)
threw_i4 = false;
try
    validate_cfg(Cfg_i4);
catch err
    threw_i4 = strcmp(err.identifier, 'validate_cfg:varsRolesMismatch');
end
n_results(end+1) = check('I4: validate_cfg detecta numel(Cfg.VARS) != numel(Cfg.VAR_ROLES)', threw_i4, 'no lanzo el error esperado');

%% ── SECCION J — Hallazgo 9: Cfg.SHOCK_NAMES ──────────────────────────────
fprintf('\n--- SECCION J: Hallazgo 9 (SHOCK_NAMES, ya no reusa var_labels) ---\n');

[~, labels_j1] = select_irfs(LtildeIS, [1 2], 1:5);
n_results(end+1) = check('J1: select_irfs sin SHOCK_NAMES -> labels shock1/shock2', ...
    isequal(labels_j1, {'shock1','shock2'}), sprintf('obtenido %s', strjoin(labels_j1, ',')));

[~, labels_j2] = select_irfs(LtildeIS, [1 2], 1:5, {'supply','demand'});
var_labels_15 = Dataset.var_labels(endo_mask);
n_results(end+1) = check('J2: select_irfs con SHOCK_NAMES usa esos nombres (no var_labels)', ...
    isequal(labels_j2, {'supply','demand'}) && ~isequal(labels_j2, var_labels_15(1:2)), ...
    sprintf('obtenido %s', strjoin(labels_j2, ',')));

tmp_out_j = fullfile(tempdir, 'validate_chat19_tmp_j');
if ~isfolder(tmp_out_j), mkdir(tmp_out_j); end
Cfg_j3 = Cfg_is; Cfg_j3.OUTPUT_DIR = tmp_out_j; Cfg_j3.SHOCK_IDX = 1; Cfg_j3.SHOCK_NAMES = {'supply'};
ok_j3 = true;
try
    close all;
    plot_irfs(Results_is.LtildeStruct, Dataset, Cfg_j3, Results_is);
catch
    ok_j3 = false;
end
d_j3 = dir(fullfile(tmp_out_j, 'figures', 'irf_shock1_supply*.png'));
n_results(end+1) = check('J3: plot_irfs con SHOCK_NAMES genera irf_shock1_supply*.png', ...
    ok_j3 && numel(d_j3) >= 1, sprintf('archivos encontrados=%d', numel(d_j3)));
close all;

%% ── SECCION K — Hallazgo 10: titulos IRF vs CIRF diferenciados ──────────
fprintf('\n--- SECCION K: Hallazgo 10 (titulos IRF/CIRF diferenciados) ---\n');

Cfg_k = Cfg_is; Cfg_k.OUTPUT_DIR = tmp_out_j; Cfg_k.SHOCK_IDX = 1; Cfg_k.IRF_TYPE = 'both';
ok_k = true;
try
    close all;
    plot_irfs(Results_is.LtildeStruct, Dataset, Cfg_k, Results_is);
    figs_k = findobj('Type', 'figure');
    names_k = get(figs_k, 'Name');
    if ~iscell(names_k), names_k = {names_k}; end
    has_irf  = any(contains(names_k, 'IRF - ') & ~contains(names_k, 'CIRF'));
    has_cirf = any(contains(names_k, 'CIRF - '));
catch
    ok_k = false; has_irf = false; has_cirf = false;
end
n_results(end+1) = check('K: figuras IRF y CIRF tienen nombres diferenciados (''IRF - '' vs ''CIRF - '')', ...
    ok_k && has_irf && has_cirf, sprintf('has_irf=%d, has_cirf=%d', has_irf, has_cirf));
close all;

%% ── SECCION L — Hallazgo 11: export_results formato ancho ───────────────
fprintf('\n--- SECCION L: Hallazgo 11 (export_results formato ancho) ---\n');

Cfg_l = Cfg_is; Cfg_l.OUTPUT_DIR = tmp_out_j; Cfg_l.SPEC_NAME = 'validate_chat19_export_wide';
ok_l = true;
try
    export_results(Results_is, Dataset, Cfg_l);
    xlsx_l = fullfile(Cfg_l.OUTPUT_DIR, 'tables', 'validate_chat19_export_wide_results.xlsx');
    sheets_l = sheetnames(xlsx_l);
    irf_sheet_l = sheets_l(startsWith(sheets_l, 'irf_summary'));
    T_l = readtable(xlsx_l, 'Sheet', irf_sheet_l{1});
    has_wide_cols = any(endsWith(T_l.Properties.VariableNames, '_median'));
    horizons_l = T_l.horizon;
    is_ascending = issorted(horizons_l) && horizons_l(1) == 0;
    fevd_sheets_l = sheets_l(startsWith(sheets_l, 'fevd_summary'));
    has_fevd_sheet = numel(fevd_sheets_l) >= 1;
catch
    ok_l = false; has_wide_cols = false; is_ascending = false; has_fevd_sheet = false;
end
n_results(end+1) = check('L1: irf_summary tiene columnas anchas (''<resp>_median'')', ...
    ok_l && has_wide_cols, 'columnas no encontradas');
n_results(end+1) = check('L2: filas de irf_summary ordenadas por horizonte ascendente desde 0', ...
    ok_l && is_ascending, 'orden incorrecto');
n_results(end+1) = check('L3: existe al menos una hoja fevd_summary[_v<k>]', ...
    ok_l && has_fevd_sheet, 'hoja fevd_summary ausente');

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

