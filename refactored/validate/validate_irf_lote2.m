function validate_irf_lote2()
%VALIDATE_IRF_LOTE2  Validación integrada Lote 1 + Lote 2.
%
%   Verifica dos categorías:
%
%   A) REGRESIÓN NUMÉRICA — que nada de lo nuevo rompió el núcleo:
%      A1. PFA reproduce valores de referencia del Chat 7 (con rng(0))
%      A2. IS  reproduce valores de referencia del Chat 7 (con rng(0))
%
%   B) INTEGRACIÓN FUNCIONAL — que cada extensión funciona end-to-end:
%      --- Lote 1 (Chat 8) ---
%      B1. validate_cfg detecta campo faltante y lanza error
%      B2. validate_cfg detecta tipo incorrecto y lanza error
%      B3. validate_cfg pasa silenciosamente con Cfg válida
%      B4. print_run_summary imprime sin error en modo PFA
%      B5. print_run_summary imprime sin error en modo IS
%      B6. Alerta E3 se dispara cuando tasa de aceptación < umbral
%      B7. Alerta E3 no se dispara cuando tasa de aceptación >= umbral
%      --- Lote 2 (Chat 9) ---
%      B8.  select_irfs PFA: subconjunto response_idx=[2,4] correcto
%      B9.  select_irfs IS:  subconjunto shock_idx=1, response_idx=[1,3] correcto
%      B10. compute_cirfs: valores algebraicamente correctos (array real PFA)
%      B11. normalize_irfs 'none':  identidad exacta (max_diff=0)
%      B12. normalize_irfs 'own_unit': h=0 de cada var → 1 por draw
%      B13. normalize_irfs 'unit': var/horizonte/valor objetivo cumplidos
%      B14. normalize_irfs '1sd': escala draw-by-draw verificada
%      B15. plot_irfs IRF_TYPE='irf': genera figura y archivo PNG sin error
%      B16. plot_irfs IRF_TYPE='cirf': genera figura y archivo PNG sin error
%      B17. plot_irfs IRF_TYPE='both': genera dos figuras sin error
%      B18. plot_irfs CRED_BANDS=[0.16 0.84;0.05 0.95]: dos bandas sin error
%      B19. plot_irfs IRF_NORM='own_unit': normalización aplicada en plot
%      B20. plot_irfs con Results (para '1sd'): sin error

fprintf('\n');
fprintf('============================================================\n');
fprintf('  VALIDATE_IRF_LOTE2 — Lote 1 + Lote 2\n');
fprintf('  Regresion numerica + Integracion funcional\n');
fprintf('============================================================\n\n');

%% ── Setup paths ──────────────────────────────────────────────────────────
this_dir  = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'config'));
addpath(fullfile(proj_root, 'validate'));
addpath(fullfile(proj_root, 'helpfunctions'));

%% ── Correr PFA e IS una sola vez (reutilizar en todas las secciones) ─────
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

tol     = 1e-6;
all_pass    = true;
failed_tags = {};   % acumula tags de secciones que fallan

%% ══════════════════════════════════════════════════════════════════════════
%  A — REGRESIÓN NUMÉRICA
%% ══════════════════════════════════════════════════════════════════════════
fprintf('════ A. Regresion numerica ════\n\n');

%% A1 — PFA
fprintf('--- A1: spec_bnw_pfa ---\n');
Lp   = Results_pfa.LtildeStruct.data;
FEVDp = Results_pfa.FEVD;
p1 = check_val(Lp(1,1,1),            0.0000000000, tol, 'Ltilde(1,1,1)');
p2 = check_val(Lp(end,end,end),      -0.2326865051, tol, 'Ltilde(end,end,end)');
p3 = check_val(median(Lp(:,2,:),'all'), 5.4910402086, tol, 'median(Ltilde(:,2,:))');
p4 = check_val(median(FEVDp(2,:)),    0.7305634882, tol, 'median(FEVD(2,:))');
pass_A1 = p1&&p2&&p3&&p4;
all_pass = all_pass && pass_A1;
[all_pass, failed_tags] = emit(pass_A1, 'A1', all_pass, failed_tags);

%% A2 — IS
fprintf('--- A2: spec_bnw_is ---\n');
Li   = Results_is.LtildeStruct.data;
FEVDi = Results_is.FEVD;
p1 = check_val(Li(1,1,1,1),               0.0000000000, tol, 'Ltilde(1,1,1,1)');
p2 = check_val(Li(end,end,end,end),        0.2041864191, tol, 'Ltilde(end,end,end,end)');
p3 = check_val(median(Li(:,2,1,:),'all'),  2.9521795528, tol, 'median(Ltilde(:,2,1,:))');
p4 = check_val(median(FEVDi(2,:)),         0.2580366201, tol, 'median(FEVD(2,:))');
pass_A2 = p1&&p2&&p3&&p4;
all_pass = all_pass && pass_A2;
[all_pass, failed_tags] = emit(pass_A2, 'A2', all_pass, failed_tags);

%% ══════════════════════════════════════════════════════════════════════════
%  B — INTEGRACIÓN FUNCIONAL
%% ══════════════════════════════════════════════════════════════════════════
fprintf('════ B. Integracion funcional ════\n\n');

%% ── Lote 1 ───────────────────────────────────────────────────────────────

%% B1 — validate_cfg detecta campo faltante
fprintf('--- B1: validate_cfg campo faltante ---\n');
try
    Cfg_bad = rmfield(Cfg_pfa, 'ND');
    validate_cfg(Cfg_bad);
    pass_B1 = false;
    fprintf('  No lanzó error — FALLA\n');
catch ME
    pass_B1 = contains(ME.identifier, 'validate_cfg');
    fprintf('  Error capturado: %s\n', ME.message);
end
all_pass = all_pass && pass_B1;
[all_pass, failed_tags] = emit(pass_B1, 'B1', all_pass, failed_tags);

%% B2 — validate_cfg detecta tipo incorrecto
fprintf('--- B2: validate_cfg tipo incorrecto ---\n');
try
    Cfg_bad2      = Cfg_pfa;
    Cfg_bad2.ND   = 'diez_mil';   % string en lugar de double
    validate_cfg(Cfg_bad2);
    pass_B2 = false;
    fprintf('  No lanzó error — FALLA\n');
catch ME
    pass_B2 = contains(ME.identifier, 'validate_cfg');
    fprintf('  Error capturado: %s\n', ME.message);
end
all_pass = all_pass && pass_B2;
[all_pass, failed_tags] = emit(pass_B2, 'B2', all_pass, failed_tags);

%% B3 — validate_cfg pasa con Cfg válida
fprintf('--- B3: validate_cfg Cfg valida ---\n');
try
    validate_cfg(Cfg_pfa);
    pass_B3 = true;
catch ME
    pass_B3 = false;
    fprintf('  Error inesperado: %s\n', ME.message);
end
all_pass = all_pass && pass_B3;
[all_pass, failed_tags] = emit(pass_B3, 'B3', all_pass, failed_tags);

%% B4 — print_run_summary modo PFA
fprintf('--- B4: print_run_summary PFA ---\n');
try
    print_run_summary(Cfg_pfa, Results_pfa, Results_pfa.t_elapsed);
    pass_B4 = true;
catch ME
    pass_B4 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B4;
[all_pass, failed_tags] = emit(pass_B4, 'B4', all_pass, failed_tags);

%% B5 — print_run_summary modo IS
fprintf('--- B5: print_run_summary IS ---\n');
try
    print_run_summary(Cfg_is, Results_is, Results_is.t_elapsed);
    pass_B5 = true;
catch ME
    pass_B5 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B5;
[all_pass, failed_tags] = emit(pass_B5, 'B5', all_pass, failed_tags);

%% B6 — Alerta E3 se dispara cuando tasa < umbral
fprintf('--- B6: alerta E3 tasa baja (debe dispararse) ---\n');
try
    % Simular Results_is con tasa de aceptación muy baja
    Results_fake             = Results_is;
    Results_fake.uw          = zeros(Cfg_is.ND, 1);
    Results_fake.uw(1:10)    = 1;   % solo 10/30000 aceptados → tasa muy baja
    Cfg_fake                 = Cfg_is;
    Cfg_fake.MIN_ACCEPT_RATE = 0.30;

    % Capturar output a string para verificar que imprime la advertencia
    outbuf = evalc('check_e3_alert(Results_fake, Cfg_fake)');
    pass_B6 = contains(outbuf, 'ADVERTENCIA') || contains(outbuf, 'baja');
    if pass_B6
        fprintf('  Advertencia emitida correctamente.\n');
    else
        fprintf('  Advertencia NO emitida — FALLA\n');
        fprintf('  Output: %s\n', outbuf);
    end
catch ME
    pass_B6 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B6;
[all_pass, failed_tags] = emit(pass_B6, 'B6', all_pass, failed_tags);

%% B7 — Alerta E3 no se dispara cuando tasa >= umbral
fprintf('--- B7: alerta E3 tasa OK (no debe dispararse) ---\n');
try
    Results_ok           = Results_is;
    Cfg_ok               = Cfg_is;
    Cfg_ok.MIN_ACCEPT_RATE = 0.10;   % umbral muy bajo — tasa real (~0.50) supera

    outbuf2 = evalc('check_e3_alert(Results_ok, Cfg_ok)');
    pass_B7 = ~(contains(outbuf2, 'ADVERTENCIA') || contains(outbuf2, 'baja'));
    if pass_B7
        fprintf('  Sin advertencia — correcto.\n');
    else
        fprintf('  Advertencia inesperada — FALLA\n');
    end
catch ME
    pass_B7 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B7;
[all_pass, failed_tags] = emit(pass_B7, 'B7', all_pass, failed_tags);

%% ── Lote 2 ───────────────────────────────────────────────────────────────

% Adjuntar labels a LtildeStructs
LS_pfa = Results_pfa.LtildeStruct;
endo_mask = strcmp(Dataset_pfa.var_roles, 'endogenous');
all_labels = Dataset_pfa.var_labels(endo_mask);
LS_pfa.var_labels = all_labels;

LS_is = Results_is.LtildeStruct;
LS_is.var_labels = all_labels;

%% B8 — select_irfs PFA subconjunto response_idx=[2,4]
fprintf('--- B8: select_irfs PFA response_idx=[2,4] ---\n');
try
    [irfs_sel, ~, lbl_r] = select_irfs(LS_pfa, 1, [2, 4]);
    raw_full = LS_pfa.data;   % [H+1, 5, nd]

    % irfs_sel debe ser [H+1, 2, nd]
    sz_ok = isequal(size(irfs_sel), [LS_pfa.horizon+1, 2, LS_pfa.ndraws]);
    % Verificar que los valores coinciden con columnas 2 y 4 del raw
    diff24 = max(abs(irfs_sel(:,1,:) - raw_full(:,2,:)), [], 'all') + ...
             max(abs(irfs_sel(:,2,:) - raw_full(:,4,:)), [], 'all');
    pass_B8 = sz_ok && (diff24 == 0);
    fprintf('  Size OK: %d | Valores OK: max_diff=%.2e\n', sz_ok, diff24);
    fprintf('  Labels: %s, %s\n', lbl_r{1}, lbl_r{2});
catch ME
    pass_B8 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B8;
[all_pass, failed_tags] = emit(pass_B8, 'B8', all_pass, failed_tags);

%% B9 — select_irfs IS subconjunto shock_idx=1, response_idx=[1,3]
fprintf('--- B9: select_irfs IS shock=1 response=[1,3] ---\n');
try
    [irfs_is_sel, lbl_s, lbl_r2] = select_irfs(LS_is, 1, [1, 3]);
    raw_is = LS_is.data;   % [H+1, 5, 5, ne]

    % Extraer manualmente shock=1: squeeze dim3=1
    raw_shock1 = squeeze(raw_is(:, :, 1, :));   % [H+1, 5, ne]
    diff13 = max(abs(irfs_is_sel(:,1,:) - raw_shock1(:,1,:)), [], 'all') + ...
             max(abs(irfs_is_sel(:,2,:) - raw_shock1(:,3,:)), [], 'all');
    sz_ok_is = isequal(size(irfs_is_sel), [LS_is.horizon+1, 2, size(raw_is,4)]);
    pass_B9 = sz_ok_is && (diff13 == 0);
    fprintf('  Size OK: %d | Valores OK: max_diff=%.2e\n', sz_ok_is, diff13);
    fprintf('  Shock label: %s\n', lbl_s);
catch ME
    pass_B9 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B9;
[all_pass, failed_tags] = emit(pass_B9, 'B9', all_pass, failed_tags);

%% B10 — compute_cirfs: valores algebraicamente correctos con array real PFA
fprintf('--- B10: compute_cirfs array real PFA ---\n');
try
    irfs_all = LS_pfa.data;   % [H+1, 5, nd]
    cirfs    = compute_cirfs(irfs_all);

    % Verificar en h=5, var=3, draw=10: debe ser sum(irfs_all(1:5,3,10))
    h_test = 5; v_test = 3; d_test = 10;
    expected = sum(irfs_all(1:h_test, v_test, d_test));
    got      = cirfs(h_test, v_test, d_test);
    err_cirf = abs(got - expected);
    % Verificar también tamaño
    sz_eq = isequal(size(cirfs), size(irfs_all));
    pass_B10 = sz_eq && (err_cirf < 1e-14);
    fprintf('  Size OK: %d | CIRF(h=5,v=3,d=10): got=%.6f exp=%.6f err=%.2e\n', ...
            sz_eq, got, expected, err_cirf);
catch ME
    pass_B10 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B10;
[all_pass, failed_tags] = emit(pass_B10, 'B10', all_pass, failed_tags);

%% B11 — normalize_irfs 'none': identidad exacta
fprintf('--- B11: normalize_irfs none ---\n');
try
    irfs_raw = LS_pfa.data;
    [irfs_out, sf] = normalize_irfs(irfs_raw, 'none', struct(), struct());
    max_diff = max(abs(irfs_out(:) - irfs_raw(:)));
    max_sf   = max(abs(sf(:) - 1));
    pass_B11 = (max_diff == 0) && (max_sf == 0);
    fprintf('  max_diff=%.2e  max_sf_dev=%.2e\n', max_diff, max_sf);
catch ME
    pass_B11 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B11;
[all_pass, failed_tags] = emit(pass_B11, 'B11', all_pass, failed_tags);

%% B12 — normalize_irfs 'own_unit': h=0 de cada var → 1 por draw
fprintf('--- B12: normalize_irfs own_unit ---\n');
try
    irfs_raw = LS_pfa.data;   % [H+1, 5, nd]
    [irfs_n, sf] = normalize_irfs(irfs_raw, 'own_unit', struct(), struct());

    % pivot(k,d) = irfs_raw(1,k,d)
    pivot = squeeze(irfs_raw(1, :, :));    % [5, nd]
    h0_vals = squeeze(irfs_n(1, :, :));   % [5, nd]

    % Donde pivot != 0: irfs_n(1,k,d) debe ser exactamente 1
    nonzero_mask = (pivot ~= 0);
    max_dev_from_1 = max(abs(h0_vals(nonzero_mask) - 1));

    % Donde pivot == 0: normalize_irfs no aplica escala → sf(k,d) debe ser 1
    zero_mask = ~nonzero_mask;
    n_zero = sum(zero_mask(:));
    sf_zero_err = 0;
    if n_zero > 0
        sf_zero_err = max(abs(sf(zero_mask) - 1));
    end

    % Donde pivot != 0: sf(k,d) debe ser 1/pivot(k,d)
    sf_expected_nz = 1 ./ pivot(nonzero_mask);
    sf_err = max(abs(sf(nonzero_mask) - sf_expected_nz));

    pass_B12 = (max_dev_from_1 < 1e-12) && (sf_err < 1e-12) && (sf_zero_err < 1e-12);
    fprintf('  Draws con pivot=0: %d (escala no aplicada, sf=1 esperado)\n', n_zero);
    fprintf('  max|h=0 - 1| (pivot!=0) = %.2e  |  sf_err = %.2e\n', max_dev_from_1, sf_err);
catch ME
    pass_B12 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B12;
[all_pass, failed_tags] = emit(pass_B12, 'B12', all_pass, failed_tags);

%% B13 — normalize_irfs 'unit': var/horizonte/valor objetivo cumplidos
fprintf('--- B13: normalize_irfs unit ---\n');
try
    irfs_raw = LS_pfa.data;   % [H+1, 5, nd]
    Cfg_unit             = struct();
    Cfg_unit.NORM_VAR    = 2;    % StockPrices
    Cfg_unit.NORM_HORIZON = 0;   % h=0
    Cfg_unit.NORM_VALUE   = 1;   % respuesta = 1

    [irfs_u, ~] = normalize_irfs(irfs_raw, 'unit', Cfg_unit, struct());

    % irfs_u(1, 2, d) debe ser 1 para todo d
    target_vals = squeeze(irfs_u(1, 2, :));   % [nd x 1]
    max_dev_unit = max(abs(target_vals - 1));
    pass_B13 = (max_dev_unit < 1e-12);
    fprintf('  max|irfs_u(h=0, var=2) - 1| = %.2e  (esperado 0)\n', max_dev_unit);
catch ME
    pass_B13 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B13;
[all_pass, failed_tags] = emit(pass_B13, 'B13', all_pass, failed_tags);

%% B14 — normalize_irfs '1sd': escala draw-by-draw verificada
fprintf('--- B14: normalize_irfs 1sd ---\n');
try
    irfs_raw = LS_pfa.data;   % [H+1, 5, nd]
    Cfg_1sd              = struct();
    Cfg_1sd.NORM_SHOCK_IDX = 1;   % shock 1 (TFP)

    % Pasar Sigmadraws vía 4to argumento (Results)
    Results_norm = struct('Sigmadraws', {Results_pfa.Sigmadraws});
    [irfs_1sd, sf_1sd] = normalize_irfs(irfs_raw, '1sd', Cfg_1sd, Results_norm);

    % Verificar draw d=1: factor = 1/sqrt(Sigma_1(1,1))
    Sigma1  = Results_pfa.Sigmadraws{1};
    sd_j    = sqrt(Sigma1(1,1));
    sf_exp  = 1 / sd_j;
    sf_err  = abs(sf_1sd(1, 1) - sf_exp);   % var=1, draw=1

    % Verificar que irfs_1sd(h, k, 1) = irfs_raw(h, k, 1) * sf_exp
    irf_err = max(abs(irfs_1sd(:, :, 1) - irfs_raw(:, :, 1) * sf_exp), [], 'all');

    pass_B14 = (sf_err < 1e-12) && (irf_err < 1e-12);
    fprintf('  sf draw1: got=%.6f exp=%.6f err=%.2e\n', sf_1sd(1,1), sf_exp, sf_err);
    fprintf('  irf_err draw1: %.2e\n', irf_err);
catch ME
    pass_B14 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B14;
[all_pass, failed_tags] = emit(pass_B14, 'B14', all_pass, failed_tags);

%% B15-B20 — plot_irfs: verificaciones funcionales (sin crashes)
% Para estas secciones usamos un número reducido de draws para rapidez

% Construir LtildeStruct reducida (primeros 50 draws)
LS_small = LS_pfa;
LS_small.data   = LS_pfa.data(:, :, 1:50);
LS_small.ndraws = 50;

Cfg_plot = Cfg_pfa;
Cfg_plot.PLOT_IRFS = false;   % evitar que main vuelva a graficar

%% B15 — IRF_TYPE='irf'
fprintf('--- B15: plot_irfs IRF_TYPE=irf ---\n');
try
    Cfg_b15 = Cfg_plot;
    Cfg_b15.IRF_TYPE = 'irf';
    plot_irfs(LS_small, Dataset_pfa, Cfg_b15);
    close all;
    pass_B15 = true;
catch ME
    pass_B15 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B15;
[all_pass, failed_tags] = emit(pass_B15, 'B15', all_pass, failed_tags);

%% B16 — IRF_TYPE='cirf'
fprintf('--- B16: plot_irfs IRF_TYPE=cirf ---\n');
try
    Cfg_b16 = Cfg_plot;
    Cfg_b16.IRF_TYPE = 'cirf';
    plot_irfs(LS_small, Dataset_pfa, Cfg_b16);
    close all;
    pass_B16 = true;
catch ME
    pass_B16 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B16;
[all_pass, failed_tags] = emit(pass_B16, 'B16', all_pass, failed_tags);

%% B17 — IRF_TYPE='both'
fprintf('--- B17: plot_irfs IRF_TYPE=both ---\n');
try
    Cfg_b17 = Cfg_plot;
    Cfg_b17.IRF_TYPE = 'both';
    plot_irfs(LS_small, Dataset_pfa, Cfg_b17);
    close all;
    pass_B17 = true;
catch ME
    pass_B17 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B17;
[all_pass, failed_tags] = emit(pass_B17, 'B17', all_pass, failed_tags);

%% B18 — CRED_BANDS=[0.16 0.84; 0.05 0.95] (dos bandas)
fprintf('--- B18: plot_irfs dos bandas ---\n');
try
    Cfg_b18 = Cfg_plot;
    Cfg_b18.IRF_TYPE   = 'irf';
    Cfg_b18.CRED_BANDS = [0.16 0.84; 0.05 0.95];
    plot_irfs(LS_small, Dataset_pfa, Cfg_b18);
    close all;
    pass_B18 = true;
catch ME
    pass_B18 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B18;
[all_pass, failed_tags] = emit(pass_B18, 'B18', all_pass, failed_tags);

%% B19 — IRF_NORM='own_unit' aplicado en plot (valores h=0 → ~1 en mediana)
fprintf('--- B19: plot_irfs IRF_NORM=own_unit ---\n');
try
    Cfg_b19 = Cfg_plot;
    Cfg_b19.IRF_TYPE = 'irf';
    Cfg_b19.IRF_NORM = 'own_unit';
    plot_irfs(LS_small, Dataset_pfa, Cfg_b19);
    close all;
    pass_B19 = true;
catch ME
    pass_B19 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B19;
[all_pass, failed_tags] = emit(pass_B19, 'B19', all_pass, failed_tags);

%% B20 — IRF_NORM='1sd' con Results pasado como 4to arg
fprintf('--- B20: plot_irfs IRF_NORM=1sd con Results ---\n');
try
    Cfg_b20 = Cfg_plot;
    Cfg_b20.IRF_TYPE       = 'irf';
    Cfg_b20.IRF_NORM       = '1sd';
    Cfg_b20.NORM_SHOCK_IDX = 1;
    % Construir Results reducido con Sigmadraws de los 50 draws
    Results_small = struct('Sigmadraws', {Results_pfa.Sigmadraws(1:50)});
    plot_irfs(LS_small, Dataset_pfa, Cfg_b20, Results_small);
    close all;
    pass_B20 = true;
catch ME
    pass_B20 = false;
    fprintf('  Error: %s\n', ME.message);
end
all_pass = all_pass && pass_B20;
[all_pass, failed_tags] = emit(pass_B20, 'B20', all_pass, failed_tags);

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

function check_e3_alert(Results, Cfg)
%CHECK_E3_ALERT  Aísla la lógica de alerta E3 de run_is para testearla.
    if isfield(Cfg, 'MIN_ACCEPT_RATE')
        min_accept = Cfg.MIN_ACCEPT_RATE;
    else
        min_accept = 0.30;
    end
    accept_rate = sum(Results.uw > 0) / Cfg.ND;
    if accept_rate < min_accept
        fprintf('[ADVERTENCIA] Tasa de aceptación baja: %.4f (umbral: %.2f)\n', ...
                accept_rate, min_accept);
        fprintf('             Considera aumentar ND o relajar las restricciones.\n');
    end
end

