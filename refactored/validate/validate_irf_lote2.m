function validate_irf_lote2()
%VALIDATE_IRF_LOTE2  Verifica condición de regresión numérica del Lote 2.
%
%   VALIDATE_IRF_LOTE2()
%
%   Verifica que:
%     1. select_irfs devuelve los mismos valores que acceder directamente
%        al array de LtildeStruct (ninguna transformación numérica).
%     2. normalize_irfs con type='none' es identidad exacta (sin error de
%        redondeo: los arrays deben ser bit-a-bit idénticos).
%     3. compute_cirfs es la suma acumulada de IRFs (verificación algebraica).
%     4. main('spec_bnw_pfa') con IRF_NORM ausente o 'none' produce
%        los mismos valores de referencia del Chat 7 (baseline MVP).
%     5. main('spec_bnw_is') ídem.
%
%   Referencias numéricas (Chat 7, rng(0)):
%     PFA: Ltilde(1,1,1)          =  0.0000000000
%          Ltilde(end,end,end)    = -0.2326865051
%          median(Ltilde(:,2,:))  =  5.4910402086
%          median(FEVD(2,:))      =  0.7305634882
%     IS:  Ltilde(1,1,1,1)            =  0.0000000000
%          Ltilde(end,end,end,end)    =  0.2041864191
%          median(Ltilde(:,2,1,:))    =  2.9521795528
%          median(FEVD(2,:))          =  0.2580366201
%
%   Emite veredicto PASA / NO PASA por sección y uno global.

fprintf('\n');
fprintf('============================================================\n');
fprintf('  VALIDATE_IRF_LOTE2 — Lote 2: Outputs IRF\n');
fprintf('  Condicion de regresion numerica A7 (normalize ''none'')\n');
fprintf('============================================================\n\n');

%% ── Localizar raíz del proyecto ─────────────────────────────────────────
this_dir  = fileparts(mfilename('fullpath'));   % .../refactored/validate/
proj_root = fileparts(this_dir);               % .../refactored/
addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'config'));
addpath(fullfile(proj_root, 'validate'));
addpath(fullfile(proj_root, 'helpfunctions'));

all_pass = true;   % acumulador global

%% ══════════════════════════════════════════════════════════════════════════
%  SECCIÓN 1 — Regresión numérica PFA
%% ══════════════════════════════════════════════════════════════════════════
fprintf('--- Seccion 1: spec_bnw_pfa (regresion numerica) ---\n');

% Referencias Chat 7
ref_pfa = struct();
ref_pfa.ltilde_1_1_1   =  0.0000000000;
ref_pfa.ltilde_end     = -0.2326865051;
ref_pfa.median_col2    =  5.4910402086;
ref_pfa.median_fevd2   =  0.7305634882;
tol = 1e-6;

try
    % Cargar config sin tocar IRF_NORM
    run(fullfile(proj_root, 'config', 'spec_bnw_pfa.m'));
    validate_cfg(Cfg);
    Dataset = load_data(Cfg);
    Posterior = build_posterior(Dataset, Cfg);
    rng(Cfg.SEED);
    Results_pfa = run_pfa(Posterior, Cfg);

    Ltilde_pfa = Results_pfa.LtildeStruct.data;   % [horizon+1, nvar, nd]
    FEVD_pfa   = Results_pfa.FEVD;

    v1 = Ltilde_pfa(1,1,1);
    v2 = Ltilde_pfa(end,end,end);
    v3 = median(Ltilde_pfa(:,2,:), 'all');
    v4 = median(FEVD_pfa(2,:));

    chk = @(val, ref, name) check_val(val, ref, tol, name);
    p1 = chk(v1, ref_pfa.ltilde_1_1_1,  'Ltilde(1,1,1)');
    p2 = chk(v2, ref_pfa.ltilde_end,     'Ltilde(end,end,end)');
    p3 = chk(v3, ref_pfa.median_col2,    'median(Ltilde(:,2,:))');
    p4 = chk(v4, ref_pfa.median_fevd2,   'median(FEVD(2,:))');
    pass_pfa = p1 && p2 && p3 && p4;

catch ME
    fprintf('  ERROR al correr spec_bnw_pfa: %s\n', ME.message);
    pass_pfa = false;
    Results_pfa = struct();
end

if pass_pfa
    fprintf('  Resultado Seccion 1: PASA\n\n');
else
    fprintf('  Resultado Seccion 1: NO PASA\n\n');
    all_pass = false;
end

%% ══════════════════════════════════════════════════════════════════════════
%  SECCIÓN 2 — Regresión numérica IS
%% ══════════════════════════════════════════════════════════════════════════
fprintf('--- Seccion 2: spec_bnw_is (regresion numerica) ---\n');

ref_is = struct();
ref_is.ltilde_1_1_1_1  =  0.0000000000;
ref_is.ltilde_end      =  0.2041864191;
ref_is.median_col2     =  2.9521795528;
ref_is.median_fevd2    =  0.2580366201;

try
    run(fullfile(proj_root, 'config', 'spec_bnw_is.m'));
    validate_cfg(Cfg);
    Dataset_is = load_data(Cfg);
    Posterior_is = build_posterior(Dataset_is, Cfg);
    rng(Cfg.SEED);
    Results_is = run_is(Posterior_is, Cfg);

    Ltilde_is = Results_is.LtildeStruct.data;   % [horizon+1, nvar, nvar, ne]
    FEVD_is   = Results_is.FEVD;

    v1 = Ltilde_is(1,1,1,1);
    v2 = Ltilde_is(end,end,end,end);
    v3 = median(Ltilde_is(:,2,1,:), 'all');
    v4 = median(FEVD_is(2,:));

    chk = @(val, ref, name) check_val(val, ref, tol, name);
    p1 = chk(v1, ref_is.ltilde_1_1_1_1, 'Ltilde(1,1,1,1)');
    p2 = chk(v2, ref_is.ltilde_end,      'Ltilde(end,end,end,end)');
    p3 = chk(v3, ref_is.median_col2,     'median(Ltilde(:,2,1,:))');
    p4 = chk(v4, ref_is.median_fevd2,    'median(FEVD(2,:))');
    pass_is = p1 && p2 && p3 && p4;

catch ME
    fprintf('  ERROR al correr spec_bnw_is: %s\n', ME.message);
    pass_is = false;
    Results_is = struct();
end

if pass_is
    fprintf('  Resultado Seccion 2: PASA\n\n');
else
    fprintf('  Resultado Seccion 2: NO PASA\n\n');
    all_pass = false;
end

%% ══════════════════════════════════════════════════════════════════════════
%  SECCIÓN 3 — select_irfs: identidad numérica
%% ══════════════════════════════════════════════════════════════════════════
fprintf('--- Seccion 3: select_irfs (identidad numerica) ---\n');

try
    if isfield(Results_pfa, 'LtildeStruct')
        LS = Results_pfa.LtildeStruct;
        Dataset_tmp = Dataset;
        endo_mask   = strcmp(Dataset_tmp.var_roles, 'endogenous');
        LS.var_labels = Dataset_tmp.var_labels(endo_mask);

        % Todos los índices: debe devolver el array completo
        n_var = LS.nvar;
        [irfs_sel, lbl_s, lbl_r] = select_irfs(LS, 1, 1:n_var);
        raw = LS.data;   % [H+1, nvar, nd]

        % Verificar que son bit-a-bit iguales
        max_diff = max(abs(irfs_sel(:) - raw(:)));
        pass_sel = (max_diff == 0);
        if pass_sel
            fprintf('  select_irfs PFA identidad: max_diff = 0  → PASA\n');
        else
            fprintf('  select_irfs PFA identidad: max_diff = %.2e  → NO PASA\n', max_diff);
        end

        % Verificar labels
        if ~isempty(lbl_s) && ~isempty(lbl_r)
            fprintf('  Labels OK: shock=''%s'', resp{1}=''%s''\n', lbl_s, lbl_r{1});
        end
    else
        fprintf('  No hay Results_pfa disponibles — omitir\n');
        pass_sel = true;   % no contar como falla
    end
catch ME
    fprintf('  ERROR en select_irfs: %s\n', ME.message);
    pass_sel = false;
end

if pass_sel
    fprintf('  Resultado Seccion 3: PASA\n\n');
else
    fprintf('  Resultado Seccion 3: NO PASA\n\n');
    all_pass = false;
end

%% ══════════════════════════════════════════════════════════════════════════
%  SECCIÓN 4 — normalize_irfs 'none': identidad exacta
%% ══════════════════════════════════════════════════════════════════════════
fprintf('--- Seccion 4: normalize_irfs(''none'') identidad ---\n');

try
    if isfield(Results_pfa, 'LtildeStruct')
        LS = Results_pfa.LtildeStruct;
        irfs_raw = LS.data;   % [H+1, nvar, nd]

        [irfs_out, sf] = normalize_irfs(irfs_raw, 'none', struct(), struct());

        max_diff_norm = max(abs(irfs_out(:) - irfs_raw(:)));
        max_sf_dev    = max(abs(sf(:) - 1));

        pass_none = (max_diff_norm == 0) && (max_sf_dev == 0);
        fprintf('  normalize_irfs(''none'') max_diff = %.2e (esperado 0)\n', max_diff_norm);
        fprintf('  scale_factors max_dev_from_1 = %.2e (esperado 0)\n', max_sf_dev);
    else
        fprintf('  No hay Results_pfa — omitir\n');
        pass_none = true;
    end
catch ME
    fprintf('  ERROR en normalize_irfs: %s\n', ME.message);
    pass_none = false;
end

if pass_none
    fprintf('  Resultado Seccion 4: PASA\n\n');
else
    fprintf('  Resultado Seccion 4: NO PASA\n\n');
    all_pass = false;
end

%% ══════════════════════════════════════════════════════════════════════════
%  SECCIÓN 5 — compute_cirfs: suma acumulada algebraica
%% ══════════════════════════════════════════════════════════════════════════
fprintf('--- Seccion 5: compute_cirfs (algebraica) ---\n');

try
    % Test sintético pequeño: array 4 x 2 x 3
    rng(42);
    A = randn(4, 2, 3);
    C = compute_cirfs(A);

    % Verificar manualmente: CIRF(h) = sum_{k=1}^{h+1} A(k)
    max_cirf_err = 0;
    for d_ = 1:3
        for v_ = 1:2
            for h_ = 1:4
                expected = sum(A(1:h_, v_, d_));
                got      = C(h_, v_, d_);
                max_cirf_err = max(max_cirf_err, abs(got - expected));
            end
        end
    end
    pass_cirf = (max_cirf_err < 1e-14);
    fprintf('  compute_cirfs max_err = %.2e (esperado < 1e-14)\n', max_cirf_err);
catch ME
    fprintf('  ERROR en compute_cirfs: %s\n', ME.message);
    pass_cirf = false;
end

if pass_cirf
    fprintf('  Resultado Seccion 5: PASA\n\n');
else
    fprintf('  Resultado Seccion 5: NO PASA\n\n');
    all_pass = false;
end

%% ══════════════════════════════════════════════════════════════════════════
%  VEREDICTO GLOBAL
%% ══════════════════════════════════════════════════════════════════════════
fprintf('============================================================\n');
if all_pass
    fprintf('  VEREDICTO GLOBAL: PASA\n');
    fprintf('  Todas las condiciones de regresion se cumplen.\n');
else
    fprintf('  VEREDICTO GLOBAL: NO PASA\n');
    fprintf('  Revisar secciones marcadas NO PASA arriba.\n');
end
fprintf('============================================================\n\n');

end

%% ── Función auxiliar de comparación ─────────────────────────────────────
function pass = check_val(val, ref, tol, name)
    err = abs(val - ref);
    if err < tol
        fprintf('  %-35s val=%+.10f  ref=%+.10f  err=%.2e  OK\n', ...
                name, val, ref, err);
        pass = true;
    else
        fprintf('  %-35s val=%+.10f  ref=%+.10f  err=%.2e  FALLA\n', ...
                name, val, ref, err);
        pass = false;
    end
end
