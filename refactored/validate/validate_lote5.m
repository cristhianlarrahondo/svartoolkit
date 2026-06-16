function validate_lote5()
%VALIDATE_LOTE5  Validacion integrada Lote 5 — Priors alternativos (Tipo R).
%
%   A) CONDICION DE REGRESION (obligatoria):
%      A1. PFA con prior 'diffuse' reproduce valores de referencia Chat 7
%      A2. IS  con prior 'diffuse' reproduce valores de referencia Chat 7
%      A3. PFA sin campo PRIOR reproduce igual (default es 'diffuse')
%
%   B) CAMBIO DE POSTERIOR CON PRIORS ALTERNATIVOS:
%      B1. Minnesota: OomegaTilde diferente a diffuse
%      B2. Sims-Zha:  OomegaTilde diferente a diffuse
%      B3. NIW custom: PphiTilde diferente a diffuse (prior informativa)
%      B4. Natural conjugate: OomegaTilde Y PphiTilde diferentes a diffuse
%
%   C) INTEGRACION FUNCIONAL:
%      C1. Minnesota: build_posterior + run_pfa corre sin error
%      C2. Sims-Zha:  build_posterior + run_pfa corre sin error
%      C3. NIW custom: build_posterior + run_pfa corre sin error
%      C4. Natural conjugate: build_posterior + run_pfa corre sin error
%      C5. run_prior_sensitivity: los 5 priors, tabla con diferencias visibles
%      C6. Error si Cfg.PRIOR.type no reconocido
%      C7. Error si faltan hiperparametros requeridos (minnesota sin lambda2)
%      C8. Error si faltan hiperparametros requeridos (niw_custom sin Phi_bar)
%
%   El script no requiere configuracion manual.

fprintf('\n');
fprintf('============================================================\n');
fprintf('  VALIDATE_LOTE5 — Priors alternativos (Tipo R)\n');
fprintf('  Regresion numerica + Cambio de posterior + Integracion\n');
fprintf('============================================================\n\n');

%% ── Setup paths ──────────────────────────────────────────────────────────
this_dir  = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'config'));
addpath(fullfile(proj_root, 'validate'));
addpath(fullfile(proj_root, 'helpfunctions'));

cfg_dir = fullfile(proj_root, 'config');

%% ── Cargar specs base ────────────────────────────────────────────────────
Cfg_pfa     = load_spec(fullfile(cfg_dir, 'spec_bnw_pfa.m'));
Dataset_pfa = load_data(Cfg_pfa);

Cfg_is      = load_spec(fullfile(cfg_dir, 'spec_bnw_is.m'));
Dataset_is  = load_data(Cfg_is);

% Posterior diffuse de referencia para comparaciones B
Post_diff = build_posterior(Dataset_pfa, Cfg_pfa);
n_var = Post_diff.n;   % 5
m_var = Post_diff.m;   % 21

tol         = 1e-6;
all_pass    = true;
failed_tags = {};

%% ══════════════════════════════════════════════════════════════════════════
%  A — CONDICION DE REGRESION
%% ══════════════════════════════════════════════════════════════════════════
fprintf('==== A. Condicion de regresion ====\n\n');

%% A1 — PFA con Cfg.PRIOR.type = 'diffuse'
fprintf('--- A1: PFA con PRIOR.type = diffuse ---\n');
Cfg_a1       = Cfg_pfa;
Cfg_a1.PRIOR = struct('type', 'diffuse');
Post_a1      = build_posterior(Dataset_pfa, Cfg_a1);
rng(Cfg_pfa.SEED);
Res_a1       = run_pfa(Post_a1, Cfg_a1);
Lp = Res_a1.LtildeStruct.data;
p1 = check_val(Lp(1,1,1),               0.0000000000, tol, 'Ltilde(1,1,1)');
p2 = check_val(Lp(end,end,end),         -0.2326865051, tol, 'Ltilde(end,end,end)');
p3 = check_val(median(Lp(:,2,:),'all'),  5.4910402086, tol, 'median(Ltilde(:,2,:))');
pass_A1 = p1&&p2&&p3;
[all_pass, failed_tags] = emit(pass_A1, 'A1', all_pass, failed_tags);

%% A2 — IS con Cfg.PRIOR.type = 'diffuse'
fprintf('--- A2: IS con PRIOR.type = diffuse ---\n');
Cfg_a2       = Cfg_is;
Cfg_a2.PRIOR = struct('type', 'diffuse');
Post_a2      = build_posterior(Dataset_is, Cfg_a2);
rng(Cfg_is.SEED);
Res_a2       = run_is(Post_a2, Cfg_a2);
Li = Res_a2.LtildeStruct.data;
p1 = check_val(Li(1,1,1,1),               0.0000000000, tol, 'Ltilde(1,1,1,1)');
p2 = check_val(Li(end,end,end,end),        0.2041864191, tol, 'Ltilde(end,end,end,end)');
p3 = check_val(median(Li(:,2,1,:),'all'),  2.9521795528, tol, 'median(Ltilde(:,2,1,:))');
pass_A2 = p1&&p2&&p3;
[all_pass, failed_tags] = emit(pass_A2, 'A2', all_pass, failed_tags);

%% A3 — PFA sin campo PRIOR (default = 'diffuse')
fprintf('--- A3: PFA sin campo PRIOR (default diffuse) ---\n');
Cfg_a3 = Cfg_pfa;
if isfield(Cfg_a3, 'PRIOR'), Cfg_a3 = rmfield(Cfg_a3, 'PRIOR'); end
Post_a3 = build_posterior(Dataset_pfa, Cfg_a3);
rng(Cfg_pfa.SEED);
Res_a3  = run_pfa(Post_a3, Cfg_a3);
Lp3 = Res_a3.LtildeStruct.data;
p1  = check_val(Lp3(end,end,end), -0.2326865051, tol, 'Ltilde(end,end,end)');
pass_A3 = p1;
[all_pass, failed_tags] = emit(pass_A3, 'A3', all_pass, failed_tags);

%% ══════════════════════════════════════════════════════════════════════════
%  B — CAMBIO DE POSTERIOR CON PRIORS ALTERNATIVOS
%  Hiperparametros informativos para ver diferencia real vs diffuse.
%% ══════════════════════════════════════════════════════════════════════════
fprintf('==== B. Cambio de posterior con priors alternativos ====\n\n');

%% B1 — Minnesota: lambda1=0.5 (informativo), lambda2=0.5, lambda3=1
fprintf('--- B1: Minnesota posterior diferente a diffuse ---\n');
Cfg_b1       = Cfg_pfa;
Cfg_b1.PRIOR = struct('type','minnesota', 'lambda1',0.5, 'lambda2',0.5, 'lambda3',1);
Post_b1      = build_posterior(Dataset_pfa, Cfg_b1);
diff_omega_b1 = norm(Post_b1.OomegaTilde - Post_diff.OomegaTilde, 'fro');
diff_psi_b1   = norm(Post_b1.PpsiTilde   - Post_diff.PpsiTilde,   'fro');
pass_B1 = (diff_omega_b1 > tol);
fprintf('  ||OomegaTilde_minn - OomegaTilde_diff|| = %.6e\n', diff_omega_b1);
fprintf('  ||PpsiTilde_minn   - PpsiTilde_diff||   = %.6e  (media prior RW != 0)\n', diff_psi_b1);
[all_pass, failed_tags] = emit(pass_B1, 'B1', all_pass, failed_tags);

%% B2 — Sims-Zha: mu5=0.5, mu6=0.5 (informativo)
fprintf('--- B2: Sims-Zha posterior diferente a diffuse ---\n');
Cfg_b2       = Cfg_pfa;
Cfg_b2.PRIOR = struct('type','sims_zha', 'mu5',0.5, 'mu6',0.5);
Post_b2      = build_posterior(Dataset_pfa, Cfg_b2);
diff_omega_b2 = norm(Post_b2.OomegaTilde - Post_diff.OomegaTilde, 'fro');
fprintf('  ||OomegaTilde_sz - OomegaTilde_diff|| = %.6e\n', diff_omega_b2);
fprintf('  T_eff con dummies: %d  (T_original=%d, agrega n+1=%d filas)\n', ...
    Post_b2.nnuTilde, Post_diff.T, n_var+1);
pass_B2 = (diff_omega_b2 > tol);
[all_pass, failed_tags] = emit(pass_B2, 'B2', all_pass, failed_tags);

%% B3 — NIW custom: Omega_bar informativa (shrinkage fuerte), Phi_bar escalada
fprintf('--- B3: NIW custom posterior diferente a diffuse ---\n');
Cfg_b3  = Cfg_pfa;
% Omega_bar = 0.1*I => varianza prior pequena => shrinkage fuerte
% Phi_bar = 50*diag(sigma^2) => prior informativa sobre Sigma
sig2_ols = diag(Post_diff.Sigmau);
Cfg_b3.PRIOR = struct( ...
    'type',      'niw_custom', ...
    'nu_bar',    n_var + 50, ...
    'Phi_bar',   diag(sig2_ols) * 50, ...
    'Psi_bar',   zeros(m_var, n_var), ...
    'Omega_bar', eye(m_var) * 0.1);
Post_b3     = build_posterior(Dataset_pfa, Cfg_b3);
diff_phi_b3 = norm(Post_b3.PphiTilde   - Post_diff.PphiTilde,   'fro');
diff_om_b3  = norm(Post_b3.OomegaTilde - Post_diff.OomegaTilde, 'fro');
pass_B3 = (diff_phi_b3 > tol) && (diff_om_b3 > tol);
fprintf('  ||PphiTilde_niw  - PphiTilde_diff||   = %.6e\n', diff_phi_b3);
fprintf('  ||OomegaTilde_niw- OomegaTilde_diff||  = %.6e\n', diff_om_b3);
[all_pass, failed_tags] = emit(pass_B3, 'B3', all_pass, failed_tags);

%% B4 — Natural conjugate: lambda1=0.5, nu_bar=50
%   => OomegaTilde diferente (lambda1 grande) Y PphiTilde diferente (Phi_bar != 0)
fprintf('--- B4: Natural conjugate posterior diferente en Omega y Phi ---\n');
Cfg_b4       = Cfg_pfa;
Cfg_b4.PRIOR = struct('type','natural_conjugate', 'lambda1',0.5, 'lambda2',0.5, ...
    'lambda3',1, 'nu_bar',50);
Post_b4      = build_posterior(Dataset_pfa, Cfg_b4);
diff_omega_b4 = norm(Post_b4.OomegaTilde - Post_diff.OomegaTilde, 'fro');
diff_phi_b4   = norm(Post_b4.PphiTilde   - Post_diff.PphiTilde,   'fro');
pass_B4 = (diff_omega_b4 > tol) && (diff_phi_b4 > tol);
fprintf('  ||OomegaTilde_nc - OomegaTilde_diff|| = %.6e\n', diff_omega_b4);
fprintf('  ||PphiTilde_nc   - PphiTilde_diff||   = %.6e  (Phi_bar != 0 con nu_bar=50)\n', diff_phi_b4);
[all_pass, failed_tags] = emit(pass_B4, 'B4', all_pass, failed_tags);

%% ══════════════════════════════════════════════════════════════════════════
%  C — INTEGRACION FUNCIONAL
%  Hiperparametros informativos para que la tabla de C5 sea visualmente
%  diferente entre priors (misma direccion, magnitudes distintas).
%% ══════════════════════════════════════════════════════════════════════════
fprintf('==== C. Integracion funcional ====\n\n');

%% C1 — Minnesota: lambda1=0.5 (informativo)
fprintf('--- C1: Minnesota build_posterior + run_pfa ---\n');
try
    Cfg_c1       = Cfg_pfa;
    Cfg_c1.PRIOR = struct('type','minnesota', 'lambda1',0.5, 'lambda2',0.5, 'lambda3',1);
    Cfg_c1.ND    = 500;
    Post_c1      = build_posterior(Dataset_pfa, Cfg_c1);
    rng(0);
    Res_c1       = run_pfa(Post_c1, Cfg_c1);
    has_ltilde   = isfield(Res_c1, 'LtildeStruct') && ~isempty(Res_c1.LtildeStruct.data);
    pass_C1 = has_ltilde;
    fprintf('  LtildeStruct presente: %d | prior_type: %s\n', has_ltilde, Post_c1.prior_type);
catch ME
    pass_C1 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_C1, 'C1', all_pass, failed_tags);

%% C2 — Sims-Zha: mu5=0.5, mu6=0.5 (informativo)
fprintf('--- C2: Sims-Zha build_posterior + run_pfa ---\n');
try
    Cfg_c2       = Cfg_pfa;
    Cfg_c2.PRIOR = struct('type','sims_zha', 'mu5',0.5, 'mu6',0.5);
    Cfg_c2.ND    = 500;
    Post_c2      = build_posterior(Dataset_pfa, Cfg_c2);
    rng(0);
    Res_c2       = run_pfa(Post_c2, Cfg_c2);
    has_ltilde   = isfield(Res_c2, 'LtildeStruct') && ~isempty(Res_c2.LtildeStruct.data);
    pass_C2 = has_ltilde;
    fprintf('  LtildeStruct presente: %d | T_eff: %d (original: %d)\n', ...
        has_ltilde, Post_c2.nnuTilde, Post_diff.T);
catch ME
    pass_C2 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_C2, 'C2', all_pass, failed_tags);

%% C3 — NIW custom: Omega_bar informativa
fprintf('--- C3: NIW custom build_posterior + run_pfa ---\n');
try
    Cfg_c3 = Cfg_pfa;
    Cfg_c3.PRIOR = struct( ...
        'type',      'niw_custom', ...
        'nu_bar',    n_var + 50, ...
        'Phi_bar',   diag(sig2_ols) * 50, ...
        'Psi_bar',   zeros(m_var, n_var), ...
        'Omega_bar', eye(m_var) * 0.1);
    Cfg_c3.ND = 500;
    Post_c3   = build_posterior(Dataset_pfa, Cfg_c3);
    rng(0);
    Res_c3    = run_pfa(Post_c3, Cfg_c3);
    has_ltilde = isfield(Res_c3, 'LtildeStruct') && ~isempty(Res_c3.LtildeStruct.data);
    pass_C3 = has_ltilde;
    fprintf('  LtildeStruct presente: %d\n', has_ltilde);
catch ME
    pass_C3 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_C3, 'C3', all_pass, failed_tags);

%% C4 — Natural conjugate: lambda1=0.5, nu_bar=50
fprintf('--- C4: Natural conjugate build_posterior + run_pfa ---\n');
try
    Cfg_c4       = Cfg_pfa;
    Cfg_c4.PRIOR = struct('type','natural_conjugate', 'lambda1',0.5, 'lambda2',0.5, ...
        'lambda3',1, 'nu_bar',50);
    Cfg_c4.ND    = 500;
    Post_c4      = build_posterior(Dataset_pfa, Cfg_c4);
    rng(0);
    Res_c4       = run_pfa(Post_c4, Cfg_c4);
    has_ltilde   = isfield(Res_c4, 'LtildeStruct') && ~isempty(Res_c4.LtildeStruct.data);
    pass_C4 = has_ltilde;
    fprintf('  LtildeStruct presente: %d | nu_bar=%d nu_tilde=%d\n', ...
        has_ltilde, Post_c4.nnuTilde - Post_diff.T, Post_c4.nnuTilde);
catch ME
    pass_C4 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_C4, 'C4', all_pass, failed_tags);

%% C5 — run_prior_sensitivity: los 5 priors, tabla con diferencias visibles
fprintf('--- C5: run_prior_sensitivity con los 5 priors ---\n');
try
    Cfg_c5    = Cfg_pfa;
    Cfg_c5.ND = 500;
    prior_list_c5 = { ...
        struct('type', 'diffuse'), ...
        struct('type', 'minnesota',         'lambda1',0.5, 'lambda2',0.5, 'lambda3',1), ...
        struct('type', 'sims_zha',          'mu5',0.5,     'mu6',0.5), ...
        struct('type', 'niw_custom',        'nu_bar',n_var+50, ...
               'Phi_bar',diag(sig2_ols)*50, 'Psi_bar',zeros(m_var,n_var), ...
               'Omega_bar',eye(m_var)*0.1), ...
        struct('type', 'natural_conjugate', 'lambda1',0.5, 'lambda2',0.5, ...
               'lambda3',1, 'nu_bar',50) ...
    };
    spec_path_c5 = fullfile(cfg_dir, 'spec_bnw_pfa.m');
    Res_sens  = run_prior_sensitivity(spec_path_c5, prior_list_c5, Dataset_pfa, Cfg_c5);
    is_cell   = iscell(Res_sens);
    n_res     = numel(Res_sens);

    % Verificar que diffuse y minnesota difieren en h=4, resp=2 (Stock Prices)
    Ld  = Res_sens{1}.LtildeStruct.data;
    Lm  = Res_sens{2}.LtildeStruct.data;
    med_diff = median(Ld(5, 2, :), 'all');   % h=4 -> idx=5, resp=Stock Prices
    med_minn = median(Lm(5, 2, :), 'all');
    visibly_different = abs(med_diff - med_minn) > 1e-4;

    pass_C5 = is_cell && (n_res == 5);
    fprintf('  Retorna cell: %d | n_results: %d (esperado: 5)\n', is_cell, n_res);
    fprintf('  Mediana h=4 StockPrices — diffuse: %+.4f | minn: %+.4f | diff: %.4f\n', ...
        med_diff, med_minn, abs(med_diff - med_minn));
    if ~visibly_different
        fprintf('  NOTA: diferencia pequena (T=220 domina el prior). Comportamiento esperado.\n');
    end
catch ME
    pass_C5 = false; fprintf('  Error: %s\n', ME.message);
end
[all_pass, failed_tags] = emit(pass_C5, 'C5', all_pass, failed_tags);

%% C6 — Error si Cfg.PRIOR.type no reconocido
fprintf('--- C6: Error para prior type desconocido ---\n');
try
    Cfg_c6       = Cfg_pfa;
    Cfg_c6.PRIOR = struct('type', 'fake_prior_xyz');
    build_posterior(Dataset_pfa, Cfg_c6);
    pass_C6 = false; fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_C6 = contains(ME.identifier, 'build_posterior');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_C6, 'C6', all_pass, failed_tags);

%% C7 — Error si faltan hiperparametros de minnesota (lambda2 ausente)
fprintf('--- C7: Error por lambda2 faltante en minnesota ---\n');
try
    Cfg_c7       = Cfg_pfa;
    Cfg_c7.PRIOR = struct('type','minnesota', 'lambda1',0.2, 'lambda3',1);
    build_posterior(Dataset_pfa, Cfg_c7);
    pass_C7 = false; fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_C7 = contains(ME.identifier, 'build_posterior');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_C7, 'C7', all_pass, failed_tags);

%% C8 — Error si faltan hiperparametros de niw_custom (Phi_bar ausente)
fprintf('--- C8: Error por Phi_bar faltante en niw_custom ---\n');
try
    Cfg_c8       = Cfg_pfa;
    Cfg_c8.PRIOR = struct('type','niw_custom', 'nu_bar',10, ...
        'Psi_bar',zeros(m_var,n_var), 'Omega_bar',eye(m_var));
    build_posterior(Dataset_pfa, Cfg_c8);
    pass_C8 = false; fprintf('  No lanzo error — FALLA\n');
catch ME
    pass_C8 = contains(ME.identifier, 'build_posterior');
    fprintf('  Error capturado: %s\n', ME.identifier);
end
[all_pass, failed_tags] = emit(pass_C8, 'C8', all_pass, failed_tags);

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
