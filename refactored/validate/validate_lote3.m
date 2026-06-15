function validate_lote3()
%VALIDATE_LOTE3  Validación integrada Lote 3 — Outputs tabulares y exportación.
%
%   Verifica dos categorías:
%
%   A) REGRESIÓN NUMÉRICA — que el Lote 3 no rompió el núcleo:
%      A1. PFA reproduce valores de referencia del Chat 7 (con rng(0))
%      A2. IS  reproduce valores de referencia del Chat 7 (con rng(0))
%
%   B) INTEGRACIÓN FUNCIONAL — que cada extensión funciona end-to-end:
%      B1.  print_summary PFA: imprime sin error
%      B2.  print_summary IS: imprime sin error
%      B3.  print_summary con SUMMARY_HORIZONS y CRED_BANDS custom
%      B4.  print_summary error en campo faltante (LtildeStruct vacío)
%      B5.  plot_fevd PFA: genera PNG sin error
%      B6.  plot_fevd IS: genera PNG sin error
%      B7.  plot_fevd con FIG_SUFFIX='_test': nombre de archivo correcto
%      B8.  plot_fevd error con FEVD vacío
%      B9.  export_results PFA: genera .xlsx con las 5 hojas correctas
%      B10. export_results IS: genera .xlsx con las 5 hojas correctas
%      B11. export_results con IRF_TYPE='both': hojas irf y cirf presentes
%      B12. export_results error con LtildeStruct ausente
%      B13. export_results error con FEVD ausente
%      B14. Cadena completa PFA: select_irfs → print_summary → plot_fevd → export_results
%      B15. Cadena completa IS: select_irfs → print_summary → plot_fevd → export_results

fprintf('\n');
fprintf('============================================================\n');
fprintf('  VALIDATE_LOTE3 — Outputs tabulares y exportación\n');
fprintf('  Regresion numerica + Integracion funcional\n');
fprintf('============================================================\n\n');

%% ── Setup paths ──────────────────────────────────────────────────────────
this_dir  = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'config'));
addpath(fullfile(proj_root, 'validate'));
addpath(fullfile(proj_root, 'helpfunctions'));

%% ── Correr PFA e IS una sola vez ─────────────────────────────────────────
fprintf('Preparando resultados PFA e IS (rng(0))...\n');

run(fullfile(proj_root, 'config', 'spec_bnw_pfa.m'));
Cfg_pfa = Cfg;
Dataset_pfa = load_data(Cfg_pfa);
Posterior_pfa = build_posterior(Dataset_pfa, Cfg_pfa);
rng(Cfg_pfa.SEED);
Results_pfa = run_pfa(Posterior_pfa, Cfg_pfa);

run(fullfile(proj_root, 'config', 'spec_bnw_is.m'));
Cfg_is = Cfg;
Dataset_is = load_data(Cfg_is);
Posterior_is = build_posterior(Dataset_is, Cfg_is);
rng(Cfg_is.SEED);
Results_is = run_is(Posterior_is, Cfg_is);

fprintf('Listo.\n\n');

tol          = 1e-6;
all_pass     = true;
failed_tags  = {};

%% ══════════════════════════════════════════════════════════════════════════
%  A — REGRESIÓN NUMÉRICA (referencias del Chat 7)
%% ══════════════════════════════════════════════════════════════════════════
fprintf('════ A. Regresion numerica ════\n\n');

%% A1 — PFA
fprintf('--- A1: spec_bnw_pfa ---\n');
Lp    = Results_pfa.LtildeStruct.data;
FEVDp = Results_pfa.FEVD;
p1 = check_val(Lp(1,1,1),               0.0000000000, tol, 'Ltilde(1,1,1)');
p2 = check_val(Lp(end,end,end),         -0.2326865051, tol, 'Ltilde(end,end,end)');
p3 = check_val(median(Lp(:,2,:),'all'),  5.4910402086, tol, 'median(Ltilde(:,2,:))');
p4 = check_val(median(FEVDp(2,:)),       0.7305634882, tol, 'median(FEVD(2,:))');
pass_A1 = p1&&p2&&p3&&p4;
[all_pass, failed_tags] = emit(pass_A1, 'A1', all_pass, failed_tags);

%% A2 — IS
fprintf('--- A2: spec_bnw_is ---\n');
Li    = Results_is.LtildeStruct.data;
FEVDi = Results_is.FEVD;
p1 = check_val(Li(1,1,1,1),                0.0000000000, tol, 'Ltilde(1,1,1,1)');
p2 = check_val(Li(end,end,end,end),         0.2041864191, tol, 'Ltilde(end,end,end,end)');
p3 = check_val(median(Li(:,2,1,:),'all'),   2.9521795528, tol, 'median(Ltilde(:,2,1,:))');
p4 = check_val(median(FEVDi(2,:)),          0.2580366201, tol, 'median(FEVD(2,:))');
pass_A2 = p1&&p2&&p3&&p4;
[all_pass, failed_tags] = emit(pass_A2, 'A2', all_pass, failed_tags);

%% ══════════════════════════════════════════════════════════════════════════
%  B — INTEGRACIÓN FUNCIONAL
%% ══════════════════════════════════════════════════════════════════════════
fprintf('════ B. Integracion funcional ════\n\n');

%% ── B1-B4: print_summary ─────────────────────────────────────────────────

%% B1 — print_summary PFA sin error
fprintf('--- B1: print_summary PFA ---\n');
try
    print_summary(Results_pfa.LtildeStruct, Dataset_pfa, Cfg_pfa);
    pass_B1 = true;
catch ME
    pass_B1 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B1, 'B1', all_pass, failed_tags);

%% B2 — print_summary IS sin error
fprintf('--- B2: print_summary IS ---\n');
try
    print_summary(Results_is.LtildeStruct, Dataset_is, Cfg_is);
    pass_B2 = true;
catch ME
    pass_B2 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B2, 'B2', all_pass, failed_tags);

%% B3 — print_summary con SUMMARY_HORIZONS y CRED_BANDS custom
fprintf('--- B3: print_summary custom horizons+bands ---\n');
try
    Cfg_b3 = Cfg_pfa;
    Cfg_b3.SUMMARY_HORIZONS = [0 10 20];
    Cfg_b3.CRED_BANDS       = [0.16 0.84; 0.05 0.95];
    print_summary(Results_pfa.LtildeStruct, Dataset_pfa, Cfg_b3);
    pass_B3 = true;
catch ME
    pass_B3 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B3, 'B3', all_pass, failed_tags);

%% B4 — print_summary error con LtildeStruct vacío
fprintf('--- B4: print_summary LtildeStruct vacio (debe error) ---\n');
try
    LS_bad.mode      = 'pfa';
    LS_bad.data      = [];
    LS_bad.shock_idx = 1;
    LS_bad.horizon   = 40;
    LS_bad.nvar      = 5;
    LS_bad.ndraws    = 0;
    % Debe fallar en select_irfs o al acceder al array vacío
    print_summary(LS_bad, Dataset_pfa, Cfg_pfa);
    pass_B4 = false;   % Si no lanzó error, falla
    fprintf('  No lanzó error — FALLA\n');
catch ME
    pass_B4 = true;
    fprintf('  Error capturado correctamente: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B4, 'B4', all_pass, failed_tags);

%% ── B5-B8: plot_fevd ─────────────────────────────────────────────────────

%% B5 — plot_fevd PFA: genera PNG sin error
fprintf('--- B5: plot_fevd PFA ---\n');
try
    Cfg_b5 = Cfg_pfa;
    Cfg_b5.FIG_SUFFIX = '_test';
    plot_fevd(Results_pfa.FEVD, Dataset_pfa, Cfg_b5);
    close all;

    % Verificar que el archivo existe
    src_root  = fileparts(mfilename('fullpath'));
    proj_root_b5 = fileparts(src_root);
    fname_b5 = fullfile(proj_root_b5, 'output', 'figures', 'fevd_pfa_test.png');
    pass_B5 = isfile(fname_b5);
    if pass_B5
        fprintf('  PNG generado: fevd_pfa_test.png\n');
    else
        fprintf('  Archivo PNG no encontrado: %s\n', fname_b5);
    end
catch ME
    pass_B5 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B5, 'B5', all_pass, failed_tags);

%% B6 — plot_fevd IS: genera PNG sin error
fprintf('--- B6: plot_fevd IS ---\n');
try
    Cfg_b6 = Cfg_is;
    Cfg_b6.FIG_SUFFIX = '_test';
    plot_fevd(Results_is.FEVD, Dataset_is, Cfg_b6);
    close all;

    src_root  = fileparts(mfilename('fullpath'));
    proj_root_b6 = fileparts(src_root);
    fname_b6 = fullfile(proj_root_b6, 'output', 'figures', 'fevd_is_test.png');
    pass_B6 = isfile(fname_b6);
    if pass_B6
        fprintf('  PNG generado: fevd_is_test.png\n');
    else
        fprintf('  Archivo PNG no encontrado: %s\n', fname_b6);
    end
catch ME
    pass_B6 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B6, 'B6', all_pass, failed_tags);

%% B7 — plot_fevd con FIG_SUFFIX personalizado y CRED_BANDS=[0.05 0.95]
fprintf('--- B7: plot_fevd suffix+bands ---\n');
try
    Cfg_b7 = Cfg_pfa;
    Cfg_b7.FIG_SUFFIX  = '_validate';
    Cfg_b7.CRED_BANDS  = [0.05 0.95];
    plot_fevd(Results_pfa.FEVD, Dataset_pfa, Cfg_b7);
    close all;

    src_root  = fileparts(mfilename('fullpath'));
    proj_root_b7 = fileparts(src_root);
    fname_b7 = fullfile(proj_root_b7, 'output', 'figures', 'fevd_pfa_validate.png');
    pass_B7 = isfile(fname_b7);
    fprintf('  PNG name OK: %d\n', pass_B7);
catch ME
    pass_B7 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B7, 'B7', all_pass, failed_tags);

%% B8 — plot_fevd error con FEVD vacío
fprintf('--- B8: plot_fevd FEVD vacio (debe error) ---\n');
try
    plot_fevd([], Dataset_pfa, Cfg_pfa);
    pass_B8 = false;
    fprintf('  No lanzó error — FALLA\n');
catch ME
    pass_B8 = true;
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B8, 'B8', all_pass, failed_tags);

%% ── B9-B13: export_results ───────────────────────────────────────────────

% Helper: verificar hojas en xlsx
function sheets_ok = check_xlsx_sheets(xlsx_path, required_sheets)
    try
        [~, sheet_names] = xlsfinfo(xlsx_path);
        sheets_ok = all(ismember(required_sheets, sheet_names));
        if ~sheets_ok
            missing = required_sheets(~ismember(required_sheets, sheet_names));
            fprintf('  Hojas faltantes: %s\n', strjoin(missing, ', '));
        end
    catch
        sheets_ok = false;
    end
end

required_sheets = {'metadata', 'irf_summary', 'cirf_summary', 'fevd_summary', 'run_diagnostics'};
src_root_e   = fileparts(mfilename('fullpath'));
proj_root_e  = fileparts(src_root_e);
tables_dir_e = fullfile(proj_root_e, 'output', 'tables');

%% B9 — export_results PFA: genera xlsx con 5 hojas
fprintf('--- B9: export_results PFA ---\n');
try
    Cfg_b9 = Cfg_pfa;
    Cfg_b9.SPEC_NAME = 'test_pfa';
    Cfg_b9.IRF_TYPE  = 'irf';
    export_results(Results_pfa, Dataset_pfa, Cfg_b9);

    xlsx_b9 = fullfile(tables_dir_e, 'test_pfa_results.xlsx');
    file_exists = isfile(xlsx_b9);
    sheets_ok_b9 = false;
    if file_exists
        sheets_ok_b9 = check_xlsx_sheets(xlsx_b9, required_sheets);
    end
    pass_B9 = file_exists && sheets_ok_b9;
    fprintf('  Archivo existe: %d | Hojas OK: %d\n', file_exists, sheets_ok_b9);
catch ME
    pass_B9 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B9, 'B9', all_pass, failed_tags);

%% B10 — export_results IS: genera xlsx con 5 hojas
fprintf('--- B10: export_results IS ---\n');
try
    Cfg_b10 = Cfg_is;
    Cfg_b10.SPEC_NAME = 'test_is';
    Cfg_b10.IRF_TYPE  = 'irf';
    export_results(Results_is, Dataset_is, Cfg_b10);

    xlsx_b10 = fullfile(tables_dir_e, 'test_is_results.xlsx');
    file_exists = isfile(xlsx_b10);
    sheets_ok_b10 = false;
    if file_exists
        sheets_ok_b10 = check_xlsx_sheets(xlsx_b10, required_sheets);
    end
    pass_B10 = file_exists && sheets_ok_b10;
    fprintf('  Archivo existe: %d | Hojas OK: %d\n', file_exists, sheets_ok_b10);
catch ME
    pass_B10 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B10, 'B10', all_pass, failed_tags);

%% B11 — export_results IRF_TYPE='both': hojas irf + cirf presentes
fprintf('--- B11: export_results IRF_TYPE=both ---\n');
try
    Cfg_b11 = Cfg_pfa;
    Cfg_b11.SPEC_NAME = 'test_pfa_both';
    Cfg_b11.IRF_TYPE  = 'both';
    export_results(Results_pfa, Dataset_pfa, Cfg_b11);

    xlsx_b11 = fullfile(tables_dir_e, 'test_pfa_both_results.xlsx');
    if isfile(xlsx_b11)
        [~, sheet_names_b11] = xlsfinfo(xlsx_b11);
        has_irf  = ismember('irf_summary',  sheet_names_b11);
        has_cirf = ismember('cirf_summary', sheet_names_b11);
        pass_B11 = has_irf && has_cirf;
        fprintf('  irf_summary: %d | cirf_summary: %d\n', has_irf, has_cirf);

        % Verificar que cirf_summary no tiene la nota de "no incluye"
        T_cirf_check = readtable(xlsx_b11, 'Sheet', 'cirf_summary');
        if height(T_cirf_check) > 0 && ismember('shock', T_cirf_check.Properties.VariableNames)
            fprintf('  cirf_summary tiene datos reales: OK\n');
        else
            fprintf('  cirf_summary puede estar vacío o con nota\n');
        end
    else
        pass_B11 = false;
        fprintf('  Archivo no generado\n');
    end
catch ME
    pass_B11 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B11, 'B11', all_pass, failed_tags);

%% B12 — export_results error con LtildeStruct ausente
fprintf('--- B12: export_results LtildeStruct ausente (debe error) ---\n');
try
    Results_bad = Results_pfa;
    Results_bad = rmfield(Results_bad, 'LtildeStruct');
    export_results(Results_bad, Dataset_pfa, Cfg_pfa);
    pass_B12 = false;
    fprintf('  No lanzó error — FALLA\n');
catch ME
    pass_B12 = contains(ME.identifier, 'export_results');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B12, 'B12', all_pass, failed_tags);

%% B13 — export_results error con FEVD ausente
fprintf('--- B13: export_results FEVD ausente (debe error) ---\n');
try
    Results_bad2 = Results_pfa;
    Results_bad2.FEVD = [];
    export_results(Results_bad2, Dataset_pfa, Cfg_pfa);
    pass_B13 = false;
    fprintf('  No lanzó error — FALLA\n');
catch ME
    pass_B13 = contains(ME.identifier, 'export_results');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B13, 'B13', all_pass, failed_tags);

%% ── B14-B15: Cadena completa ─────────────────────────────────────────────

%% B14 — Cadena completa PFA
fprintf('--- B14: cadena completa PFA ---\n');
try
    LS_chain_pfa = Results_pfa.LtildeStruct;
    endo_mask_c  = strcmp(Dataset_pfa.var_roles, 'endogenous');
    LS_chain_pfa.var_labels = Dataset_pfa.var_labels(endo_mask_c);

    % 1. print_summary
    print_summary(LS_chain_pfa, Dataset_pfa, Cfg_pfa);

    % 2. plot_fevd
    Cfg_chain = Cfg_pfa;
    Cfg_chain.FIG_SUFFIX = '_chain_pfa';
    plot_fevd(Results_pfa.FEVD, Dataset_pfa, Cfg_chain);
    close all;

    % 3. export_results
    Cfg_chain.SPEC_NAME = 'chain_pfa';
    Cfg_chain.IRF_TYPE  = 'irf';
    export_results(Results_pfa, Dataset_pfa, Cfg_chain);

    % Verificar outputs
    xlsx_c = fullfile(tables_dir_e, 'chain_pfa_results.xlsx');
    pass_B14 = isfile(xlsx_c);
    fprintf('  Cadena completa: xlsx generado=%d\n', pass_B14);
catch ME
    pass_B14 = false;
    fprintf('  Error en cadena: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B14, 'B14', all_pass, failed_tags);

%% B15 — Cadena completa IS
fprintf('--- B15: cadena completa IS ---\n');
try
    LS_chain_is = Results_is.LtildeStruct;
    endo_mask_ci = strcmp(Dataset_is.var_roles, 'endogenous');
    LS_chain_is.var_labels = Dataset_is.var_labels(endo_mask_ci);

    % 1. print_summary
    print_summary(LS_chain_is, Dataset_is, Cfg_is);

    % 2. plot_fevd
    Cfg_chain_is = Cfg_is;
    Cfg_chain_is.FIG_SUFFIX = '_chain_is';
    plot_fevd(Results_is.FEVD, Dataset_is, Cfg_chain_is);
    close all;

    % 3. export_results
    Cfg_chain_is.SPEC_NAME = 'chain_is';
    Cfg_chain_is.IRF_TYPE  = 'both';
    export_results(Results_is, Dataset_is, Cfg_chain_is);

    xlsx_ci = fullfile(tables_dir_e, 'chain_is_results.xlsx');
    pass_B15 = isfile(xlsx_ci);
    fprintf('  Cadena IS completa: xlsx=%d\n', pass_B15);
catch ME
    pass_B15 = false;
    fprintf('  Error en cadena IS: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B15, 'B15', all_pass, failed_tags);

%% ══════════════════════════════════════════════════════════════════════════
%  VEREDICTO GLOBAL
%% ══════════════════════════════════════════════════════════════════════════
fprintf('\n============================================================\n');
if all_pass
    fprintf('  VEREDICTO GLOBAL: PASA\n');
    fprintf('  Regresion numerica y todas las integraciones OK.\n');
else
    fprintf('  VEREDICTO GLOBAL: NO PASA\n');
    fprintf('  Secciones con falla:\n');
    for kk = 1:numel(failed_tags)
        fprintf('    - %s\n', failed_tags{kk});
    end
end
fprintf('============================================================\n\n');

end

%% ── Helpers ──────────────────────────────────────────────────────────────
function pass = check_val(val, ref, tol, name)
    err = abs(val - ref);
    if err < tol
        fprintf('  %-38s val=%+.10f  err=%.2e  OK\n', name, val, err);
        pass = true;
    else
        fprintf('  %-38s val=%+.10f  ref=%+.10f  err=%.2e  FALLA\n', name, val, ref, err);
        pass = false;
    end
end

function [all_pass_out, failed_out] = emit(pass, tag, all_pass_in, failed_in)
    if pass
        fprintf('  Resultado %s: PASA\n\n', tag);
        all_pass_out = all_pass_in;
        failed_out   = failed_in;
    else
        fprintf('  Resultado %s: NO PASA\n\n', tag);
        all_pass_out = false;
        failed_out   = [failed_in, {tag}];
    end
end
