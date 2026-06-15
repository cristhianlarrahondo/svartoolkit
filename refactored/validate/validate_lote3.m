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
%      B4.  print_summary error con datos vacíos (ndraws=0)
%      B5.  plot_fevd PFA: genera PNG sin error
%      B6.  plot_fevd IS: genera PNG sin error
%      B7.  plot_fevd con FIG_SUFFIX='_validate' y banda custom
%      B8.  plot_fevd error con FEVD vacío
%      B9.  export_results PFA: genera .xlsx con las 5 hojas correctas
%      B10. export_results IS: genera .xlsx con las 5 hojas correctas
%      B11. export_results con IRF_TYPE='both': hojas irf y cirf presentes
%      B12. export_results error con LtildeStruct ausente
%      B13. export_results error con FEVD ausente/vacío
%      B14. Cadena completa PFA: print_summary → plot_fevd → export_results
%      B15. Cadena completa IS: print_summary → plot_fevd → export_results

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

%% ── Cargar specs con load_spec (evita error de workspace estático) ────────
fprintf('Preparando resultados PFA e IS (rng(0))...\n');

cfg_dir = fullfile(proj_root, 'config');

Cfg_pfa = load_spec(fullfile(cfg_dir, 'spec_bnw_pfa.m'));
Dataset_pfa   = load_data(Cfg_pfa);
Posterior_pfa = build_posterior(Dataset_pfa, Cfg_pfa);
rng(Cfg_pfa.SEED);
Results_pfa = run_pfa(Posterior_pfa, Cfg_pfa);

Cfg_is = load_spec(fullfile(cfg_dir, 'spec_bnw_is.m'));
Dataset_is   = load_data(Cfg_is);
Posterior_is = build_posterior(Dataset_is, Cfg_is);
rng(Cfg_is.SEED);
Results_is = run_is(Posterior_is, Cfg_is);

fprintf('Listo.\n\n');

tol         = 1e-6;
all_pass    = true;
failed_tags = {};

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

%% B4 — print_summary con SUMMARY_HORIZONS fuera del rango → aviso, no crash
fprintf('--- B4: print_summary SUMMARY_HORIZONS fuera de rango ---\n');
try
    Cfg_b4 = Cfg_pfa;
    Cfg_b4.SUMMARY_HORIZONS = [100 200];   % fuera de Cfg.HORIZON=40
    print_summary(Results_pfa.LtildeStruct, Dataset_pfa, Cfg_b4);
    % Debe imprimir aviso y retornar sin crash
    pass_B4 = true;
    fprintf('  Retornó sin crash (comportamiento esperado).\n');
catch ME
    pass_B4 = false;
    fprintf('  Error inesperado: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B4, 'B4', all_pass, failed_tags);

%% ── B5-B8: plot_fevd ─────────────────────────────────────────────────────

src_root  = fileparts(mfilename('fullpath'));
proj_root2 = fileparts(src_root);
fig_dir   = fullfile(proj_root2, 'output', 'figures');

%% B5 — plot_fevd PFA: genera PNG sin error
fprintf('--- B5: plot_fevd PFA ---\n');
try
    Cfg_b5 = Cfg_pfa;
    Cfg_b5.FIG_SUFFIX = '_test';
    plot_fevd(Results_pfa.FEVD, Dataset_pfa, Cfg_b5);
    close all;
    fname_b5 = fullfile(fig_dir, 'fevd_pfa_test.png');
    pass_B5 = isfile(fname_b5);
    fprintf('  PNG generado: %d (%s)\n', pass_B5, 'fevd_pfa_test.png');
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
    fname_b6 = fullfile(fig_dir, 'fevd_is_test.png');
    pass_B6 = isfile(fname_b6);
    fprintf('  PNG generado: %d (%s)\n', pass_B6, 'fevd_is_test.png');
catch ME
    pass_B6 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B6, 'B6', all_pass, failed_tags);

%% B7 — plot_fevd con sufijo y CRED_BANDS=[0.05 0.95]
fprintf('--- B7: plot_fevd suffix+bands ---\n');
try
    Cfg_b7 = Cfg_pfa;
    Cfg_b7.FIG_SUFFIX = '_validate';
    Cfg_b7.CRED_BANDS = [0.05 0.95];
    plot_fevd(Results_pfa.FEVD, Dataset_pfa, Cfg_b7);
    close all;
    fname_b7 = fullfile(fig_dir, 'fevd_pfa_validate.png');
    pass_B7 = isfile(fname_b7);
    fprintf('  PNG con sufijo correcto: %d\n', pass_B7);
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
    fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_B8 = contains(ME.identifier, 'plot_fevd');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B8, 'B8', all_pass, failed_tags);

%% ── B9-B13: export_results ───────────────────────────────────────────────

tables_dir = fullfile(proj_root2, 'output', 'tables');
required_sheets = {'metadata', 'irf_summary', 'cirf_summary', 'fevd_summary', 'run_diagnostics'};

%% B9 — export_results PFA: genera xlsx con 5 hojas
fprintf('--- B9: export_results PFA ---\n');
try
    Cfg_b9 = Cfg_pfa;
    Cfg_b9.SPEC_NAME = 'test_pfa';
    Cfg_b9.IRF_TYPE  = 'irf';
    export_results(Results_pfa, Dataset_pfa, Cfg_b9);

    xlsx_b9 = fullfile(tables_dir, 'test_pfa_results.xlsx');
    file_ok  = isfile(xlsx_b9);
    sheets_ok = false;
    if file_ok
        [~, sh] = xlsfinfo(xlsx_b9);
        sheets_ok = all(ismember(required_sheets, sh));
        missing = required_sheets(~ismember(required_sheets, sh));
        if ~isempty(missing)
            fprintf('  Hojas faltantes: %s\n', strjoin(missing, ', '));
        end
    end
    pass_B9 = file_ok && sheets_ok;
    fprintf('  Archivo: %d | Hojas OK: %d\n', file_ok, sheets_ok);
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

    xlsx_b10 = fullfile(tables_dir, 'test_is_results.xlsx');
    file_ok   = isfile(xlsx_b10);
    sheets_ok2 = false;
    if file_ok
        [~, sh2] = xlsfinfo(xlsx_b10);
        sheets_ok2 = all(ismember(required_sheets, sh2));
        missing2 = required_sheets(~ismember(required_sheets, sh2));
        if ~isempty(missing2)
            fprintf('  Hojas faltantes: %s\n', strjoin(missing2, ', '));
        end
    end
    pass_B10 = file_ok && sheets_ok2;
    fprintf('  Archivo: %d | Hojas OK: %d\n', file_ok, sheets_ok2);
catch ME
    pass_B10 = false;
    fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B10, 'B10', all_pass, failed_tags);

%% B11 — export_results IRF_TYPE='both': hojas irf + cirf con datos reales
fprintf('--- B11: export_results IRF_TYPE=both ---\n');
try
    Cfg_b11 = Cfg_pfa;
    Cfg_b11.SPEC_NAME = 'test_pfa_both';
    Cfg_b11.IRF_TYPE  = 'both';
    export_results(Results_pfa, Dataset_pfa, Cfg_b11);

    xlsx_b11 = fullfile(tables_dir, 'test_pfa_both_results.xlsx');
    pass_B11 = false;
    if isfile(xlsx_b11)
        [~, sh3] = xlsfinfo(xlsx_b11);
        has_irf  = ismember('irf_summary',  sh3);
        has_cirf = ismember('cirf_summary', sh3);
        % Verificar que cirf_summary tiene columna 'shock' (datos reales, no nota)
        T_cirf_check = readtable(xlsx_b11, 'Sheet', 'cirf_summary');
        has_data = ismember('shock', T_cirf_check.Properties.VariableNames) && ...
                   height(T_cirf_check) > 0;
        pass_B11 = has_irf && has_cirf && has_data;
        fprintf('  irf_summary: %d | cirf_summary: %d | datos reales: %d\n', ...
            has_irf, has_cirf, has_data);
    else
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
    Results_bad = rmfield(Results_pfa, 'LtildeStruct');
    export_results(Results_bad, Dataset_pfa, Cfg_pfa);
    pass_B12 = false;
    fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_B12 = contains(ME.identifier, 'export_results');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B12, 'B12', all_pass, failed_tags);

%% B13 — export_results error con FEVD vacío
fprintf('--- B13: export_results FEVD vacio (debe error) ---\n');
try
    Results_bad2      = Results_pfa;
    Results_bad2.FEVD = [];
    export_results(Results_bad2, Dataset_pfa, Cfg_pfa);
    pass_B13 = false;
    fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_B13 = contains(ME.identifier, 'export_results');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B13, 'B13', all_pass, failed_tags);

%% ── B14-B15: Cadena completa ─────────────────────────────────────────────

%% B14 — Cadena completa PFA
fprintf('--- B14: cadena completa PFA ---\n');
try
    % print_summary
    Cfg_c = Cfg_pfa;
    print_summary(Results_pfa.LtildeStruct, Dataset_pfa, Cfg_c);

    % plot_fevd
    Cfg_c.FIG_SUFFIX = '_chain_pfa';
    plot_fevd(Results_pfa.FEVD, Dataset_pfa, Cfg_c);
    close all;

    % export_results
    Cfg_c.SPEC_NAME = 'chain_pfa';
    Cfg_c.IRF_TYPE  = 'irf';
    export_results(Results_pfa, Dataset_pfa, Cfg_c);

    xlsx_c = fullfile(tables_dir, 'chain_pfa_results.xlsx');
    pass_B14 = isfile(xlsx_c);
    fprintf('  Cadena PFA completa: xlsx=%d\n', pass_B14);
catch ME
    pass_B14 = false;
    fprintf('  Error en cadena PFA: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B14, 'B14', all_pass, failed_tags);

%% B15 — Cadena completa IS
fprintf('--- B15: cadena completa IS ---\n');
try
    Cfg_ci = Cfg_is;
    print_summary(Results_is.LtildeStruct, Dataset_is, Cfg_ci);

    Cfg_ci.FIG_SUFFIX = '_chain_is';
    plot_fevd(Results_is.FEVD, Dataset_is, Cfg_ci);
    close all;

    Cfg_ci.SPEC_NAME = 'chain_is';
    Cfg_ci.IRF_TYPE  = 'both';
    export_results(Results_is, Dataset_is, Cfg_ci);

    xlsx_ci = fullfile(tables_dir, 'chain_is_results.xlsx');
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

%% ── Helpers locales ──────────────────────────────────────────────────────
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
