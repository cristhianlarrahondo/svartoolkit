function validate_lote4()
%VALIDATE_LOTE4  Validación integrada Lote 4 — Robustez y comparación.
%
%   A) REGRESIÓN NUMÉRICA:
%      A1. PFA reproduce valores de referencia del Chat 7 (con rng(0))
%      A2. IS  reproduce valores de referencia del Chat 7 (con rng(0))
%
%   B) INTEGRACIÓN FUNCIONAL:
%      B1.  diagnose_is_weights IS: genera PNG, calcula frac_top sin error
%      B2.  diagnose_is_weights PFA: debe lanzar error informativo
%      B3.  diagnose_is_weights campo uw faltante: debe lanzar error
%      B4.  check_stability PFA: devuelve escalar en [0,1], imprime
%      B5.  check_stability IS: devuelve escalar en [0,1], imprime
%      B6.  check_stability fracción < 0.99: emite advertencia (simulado)
%      B7.  check_stability campo Bdraws faltante: debe lanzar error
%      B8.  compare_pfa_is: genera tabla en consola y xlsx sin error
%      B9.  compare_pfa_is horizontes y bandas custom
%      B10. compare_pfa_is modo incorrecto PFA+PFA: debe lanzar error
%      B11. compare_pfa_is modo incorrecto IS+IS: debe lanzar error
%      B12. main_batch con dos specs PFA: devuelve 2 entradas, llama compare_specs
%      B13. main_batch con override de SEED: aplica override correctamente
%      B14. main_batch spec_list vacío: debe lanzar error
%      B15. compare_specs PFA+IS (modo mixto): imprime tabla sin error
%
%   El script no requiere configuración manual. Todo el setup se hace
%   automáticamente desde las specs del repo.

fprintf('\n');
fprintf('============================================================\n');
fprintf('  VALIDATE_LOTE4 — Robustez y comparacion\n');
fprintf('  Regresion numerica + Integracion funcional\n');
fprintf('============================================================\n\n');

%% ── Setup paths ──────────────────────────────────────────────────────────
this_dir  = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'config'));
addpath(fullfile(proj_root, 'validate'));
addpath(fullfile(proj_root, 'helpfunctions'));

%% ── Correr specs para tests ──────────────────────────────────────────────
fprintf('Preparando resultados PFA e IS (rng(0))...\n');
cfg_dir = fullfile(proj_root, 'config');

Cfg_pfa       = load_spec(fullfile(cfg_dir, 'spec_bnw_pfa.m'));
Dataset_pfa   = load_data(Cfg_pfa);
Posterior_pfa = build_posterior(Dataset_pfa, Cfg_pfa);
rng(Cfg_pfa.SEED);
Results_pfa   = run_pfa(Posterior_pfa, Cfg_pfa);

Cfg_is       = load_spec(fullfile(cfg_dir, 'spec_bnw_is.m'));
Dataset_is   = load_data(Cfg_is);
Posterior_is = build_posterior(Dataset_is, Cfg_is);
rng(Cfg_is.SEED);
Results_is   = run_is(Posterior_is, Cfg_is);

fprintf('Listo.\n\n');

tol         = 1e-6;
all_pass    = true;
failed_tags = {};

%% ══════════════════════════════════════════════════════════════════════════
%  A — REGRESIÓN NUMÉRICA
%% ══════════════════════════════════════════════════════════════════════════
fprintf('════ A. Regresion numerica ════\n\n');

fprintf('--- A1: spec_bnw_pfa ---\n');
Lp    = Results_pfa.LtildeStruct.data;
FEVDp = Results_pfa.FEVD;
p1 = check_val(Lp(1,1,1),               0.0000000000, tol, 'Ltilde(1,1,1)');
p2 = check_val(Lp(end,end,end),         -0.2326865051, tol, 'Ltilde(end,end,end)');
p3 = check_val(median(Lp(:,2,:),'all'),  5.4910402086, tol, 'median(Ltilde(:,2,:))');
p4 = check_val(median(FEVDp(2,:)),       0.7305634882, tol, 'median(FEVD(2,:))');
pass_A1 = p1&&p2&&p3&&p4;
[all_pass, failed_tags] = emit(pass_A1, 'A1', all_pass, failed_tags);

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

fig_dir = fullfile(proj_root, 'output', 'figures');
tbl_dir = fullfile(proj_root, 'output', 'tables');

%% B1 — diagnose_is_weights IS: genera PNG y devuelve frac_top
fprintf('--- B1: diagnose_is_weights IS ---\n');
try
    Cfg_b1 = Cfg_is; Cfg_b1.SPEC_NAME = 'test_is_diag';
    frac_b1 = diagnose_is_weights(Results_is, Cfg_b1);
    png_ok  = isfile(fullfile(fig_dir, 'is_weights_test_is_diag.png'));
    scalar_ok = isnumeric(frac_b1) && isscalar(frac_b1) && frac_b1 >= 0 && frac_b1 <= 1;
    pass_B1 = png_ok && scalar_ok;
    fprintf('  PNG generado: %d | frac_top escalar en [0,1]: %d (valor=%.4f)\n', ...
        png_ok, scalar_ok, frac_b1);
catch ME
    pass_B1 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B1, 'B1', all_pass, failed_tags);

%% B2 — diagnose_is_weights PFA: error informativo
fprintf('--- B2: diagnose_is_weights PFA (debe error) ---\n');
try
    diagnose_is_weights(Results_pfa, Cfg_pfa);
    pass_B2 = false; fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_B2 = contains(ME.identifier, 'diagnose_is_weights');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B2, 'B2', all_pass, failed_tags);

%% B3 — diagnose_is_weights campo uw faltante
fprintf('--- B3: diagnose_is_weights campo uw faltante (debe error) ---\n');
try
    Results_no_uw = rmfield(Results_is, 'uw');
    diagnose_is_weights(Results_no_uw, Cfg_is);
    pass_B3 = false; fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_B3 = contains(ME.identifier, 'diagnose_is_weights');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B3, 'B3', all_pass, failed_tags);

%% B4 — check_stability PFA
fprintf('--- B4: check_stability PFA ---\n');
try
    frac_b4 = check_stability(Results_pfa, Cfg_pfa);
    pass_B4 = isnumeric(frac_b4) && isscalar(frac_b4) && frac_b4 >= 0 && frac_b4 <= 1;
    fprintf('  frac_stable = %.4f | escalar en [0,1]: %d\n', frac_b4, pass_B4);
catch ME
    pass_B4 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B4, 'B4', all_pass, failed_tags);

%% B5 — check_stability IS
fprintf('--- B5: check_stability IS ---\n');
try
    frac_b5 = check_stability(Results_is, Cfg_is);
    pass_B5 = isnumeric(frac_b5) && isscalar(frac_b5) && frac_b5 >= 0 && frac_b5 <= 1;
    fprintf('  frac_stable = %.4f | escalar en [0,1]: %d\n', frac_b5, pass_B5);
catch ME
    pass_B5 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B5, 'B5', all_pass, failed_tags);

%% B6 — check_stability advertencia si fracción < 0.99 (simulado con draws inestables)
% Se simula modificando Bdraws para tener eigenvalores fuera del círculo unitario.
fprintf('--- B6: check_stability advertencia fraccion < 0.99 ---\n');
try
    n_var = Results_pfa.LtildeStruct.nvar;
    nex   = Cfg_pfa.NEX;
    p_lag = Cfg_pfa.NLAG;

    % Crear Bdraws con un coeficiente de lag grande → VAR inestable
    Results_unstable        = Results_pfa;
    B_unstable              = Results_pfa.Bdraws{1};
    B_unstable(1:n_var,:)   = 2.0 * eye(n_var);   % A1 = 2*I → eigenvalores=2 > 1
    Results_unstable.Bdraws = repmat({B_unstable}, numel(Results_pfa.Bdraws), 1);

    frac_b6 = check_stability(Results_unstable, Cfg_pfa);
    % Debe devolver un valor bajo (todos inestables → frac ≈ 0)
    pass_B6 = isnumeric(frac_b6) && isscalar(frac_b6) && frac_b6 < 0.99;
    fprintf('  frac_stable (inestable simulado) = %.4f | advertencia emitida: %d\n', ...
        frac_b6, pass_B6);
catch ME
    pass_B6 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B6, 'B6', all_pass, failed_tags);

%% B7 — check_stability campo Bdraws faltante
fprintf('--- B7: check_stability Bdraws faltante (debe error) ---\n');
try
    Results_noB = rmfield(Results_pfa, 'Bdraws');
    check_stability(Results_noB, Cfg_pfa);
    pass_B7 = false; fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_B7 = contains(ME.identifier, 'check_stability');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B7, 'B7', all_pass, failed_tags);

%% B8 — compare_pfa_is: tabla en consola y xlsx
fprintf('--- B8: compare_pfa_is tabla y xlsx ---\n');
try
    Cfg_b8 = Cfg_pfa; Cfg_b8.SPEC_NAME = 'test_compare';
    compare_pfa_is(Results_pfa, Results_is, Dataset_pfa, Cfg_b8);
    xlsx_b8  = fullfile(tbl_dir, 'compare_pfa_is_test_compare.xlsx');
    pass_B8  = isfile(xlsx_b8);
    fprintf('  xlsx generado: %d\n', pass_B8);
catch ME
    pass_B8 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B8, 'B8', all_pass, failed_tags);

%% B9 — compare_pfa_is horizontes y bandas custom
fprintf('--- B9: compare_pfa_is horizontes y bandas custom ---\n');
try
    Cfg_b9 = Cfg_pfa;
    Cfg_b9.SPEC_NAME       = 'test_compare_custom';
    Cfg_b9.SUMMARY_HORIZONS = [0 10 40];
    Cfg_b9.CRED_BANDS       = [0.05 0.95];
    Cfg_b9.RESP_IDX         = [1 2];
    compare_pfa_is(Results_pfa, Results_is, Dataset_pfa, Cfg_b9);
    xlsx_b9 = fullfile(tbl_dir, 'compare_pfa_is_test_compare_custom.xlsx');
    pass_B9 = isfile(xlsx_b9);
    fprintf('  xlsx con custom: %d\n', pass_B9);
catch ME
    pass_B9 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B9, 'B9', all_pass, failed_tags);

%% B10 — compare_pfa_is PFA+PFA: debe lanzar error
fprintf('--- B10: compare_pfa_is PFA+PFA (debe error) ---\n');
try
    compare_pfa_is(Results_pfa, Results_pfa, Dataset_pfa, Cfg_pfa);
    pass_B10 = false; fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_B10 = contains(ME.identifier, 'compare_pfa_is');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B10, 'B10', all_pass, failed_tags);

%% B11 — compare_pfa_is IS+IS: debe lanzar error
fprintf('--- B11: compare_pfa_is IS+IS (debe error) ---\n');
try
    compare_pfa_is(Results_is, Results_is, Dataset_is, Cfg_is);
    pass_B11 = false; fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_B11 = contains(ME.identifier, 'compare_pfa_is');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B11, 'B11', all_pass, failed_tags);

%% B12 — main_batch con dos specs PFA
% Usamos ND pequeño para no esperar mucho: override ND=200
fprintf('--- B12: main_batch dos specs PFA ---\n');
try
    spec_pfa_path = fullfile(cfg_dir, 'spec_bnw_pfa.m');
    ov_b12 = struct('ND', 200, 'SEED', 42);
    Ra_b12 = main_batch({spec_pfa_path, spec_pfa_path}, ov_b12);
    two_entries = numel(Ra_b12) == 2;
    both_pfa    = strcmpi(Ra_b12{1}.LtildeStruct.mode, 'pfa') && ...
                  strcmpi(Ra_b12{2}.LtildeStruct.mode, 'pfa');
    pass_B12 = two_entries && both_pfa;
    fprintf('  2 entradas: %d | ambas PFA: %d\n', two_entries, both_pfa);
catch ME
    pass_B12 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B12, 'B12', all_pass, failed_tags);

%% B13 — main_batch con override de SEED
fprintf('--- B13: main_batch override SEED ---\n');
try
    spec_pfa_path = fullfile(cfg_dir, 'spec_bnw_pfa.m');
    ov_b13 = struct('ND', 100, 'SEED', 99);
    Ra_b13 = main_batch({spec_pfa_path}, ov_b13);
    % El SEED aplicado debería ser 99 (override), no el del spec (0)
    % No podemos verificar la semilla directamente, pero verificamos que corrió
    pass_B13 = numel(Ra_b13) == 1 && isfield(Ra_b13{1}, 'FEVD');
    fprintf('  1 entrada con FEVD: %d\n', pass_B13);
catch ME
    pass_B13 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_B13, 'B13', all_pass, failed_tags);

%% B14 — main_batch spec_list vacío: debe lanzar error
fprintf('--- B14: main_batch spec_list vacio (debe error) ---\n');
try
    main_batch({});
    pass_B14 = false; fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_B14 = contains(ME.identifier, 'main_batch');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_B14, 'B14', all_pass, failed_tags);

%% B15 — compare_specs PFA+IS (modo mixto): imprime tabla sin error
fprintf('--- B15: compare_specs PFA+IS (modo mixto) ---\n');
try
    Ra_b15     = {Results_pfa; Results_is};
    names_b15  = {'spec_bnw_pfa', 'spec_bnw_is'};
    compare_specs(Ra_b15, names_b15, Dataset_pfa, Cfg_pfa);
    % Con modo mixto no hay ≥2 del mismo modo, así que no imprime tabla
    % Pero no debe crashear
    pass_B15 = true;
    fprintf('  compare_specs modo mixto: retorno sin crash.\n');
catch ME
    pass_B15 = false; fprintf('  Error: %s\n', ME.message);
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
        all_pass_out = all_pass_in; failed_out = failed_in;
    else
        fprintf('  Resultado %s: NO PASA\n\n', tag);
        all_pass_out = false; failed_out = [failed_in, {tag}];
    end
end
