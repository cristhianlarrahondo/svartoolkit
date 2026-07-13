%VALIDATE_LOTE_ERPT3  ERPT-Chat 3 — Validacion Tipo S de las 4 specs baseline
%
%   Ejecutar completo (F5), no por secciones.
%
%   BLOQUE 1 — Regresion numerica (Chat 7, obligatoria en protocolo Tipo S):
%     Corre spec_bnw_is (rng(0)) y verifica los valores de referencia del
%     MVP checkpoint. Este chat no toca src/ compartido (solo agrega
%     config files), pero build_dummies.m (Chat 13) y build_posterior.m
%     (prior minnesota, Chat 12) se ejercitan por primera vez en un
%     proyecto ERPT real -- este bloque confirma que el baseline BNW
%     conocido sigue intacto.
%
%   BLOQUE 2 — Integracion funcional end-to-end (4 specs baseline):
%     spec_aa_diffuse_v0, spec_aa_minn_v0, spec_mm_diffuse_v0,
%     spec_mm_minn_v0 -- cada una corre load_data -> build_dummies (spot
%     check de ventanas) -> validate_cfg -> build_posterior -> run_is ->
%     calculate_erpt, con Cfg.ND reducido SOLO por velocidad (smoke test,
%     NO es la corrida cientifica -- esa es ERPT-Chat 4).
%
%   BLOQUE 3 — Casos de error esperados (4), especificos de este lote:
%     prior minnesota con hiperparametro faltante, dummy con rango de
%     fechas invertido, dummy con fecha fuera de muestra, convencion de
%     variables LEGACY contra los datasets nuevos.
%
%   Pegar el output completo en el chat para verificacion.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 3 -- 4 specs baseline (Tipo S)\n');
fprintf('======================================================\n\n');

%% ── Rutas (F5 completo -> mfilename(''fullpath'') es confiable aqui) ─────
val_file      = mfilename('fullpath');          % .../refactored/projects/erpt/validate_lote_erpt3.m
PROJ_ROOT     = fileparts(val_file);            % .../refactored/projects/erpt
PROJECTS_ROOT = fileparts(PROJ_ROOT);           % .../refactored/projects
REF_ROOT      = fileparts(PROJECTS_ROOT);       % .../refactored
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');     % calculate_erpt.m vive aqui

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(PROJ_CFG);
addpath(PROJ_SRC);

fprintf('  REF_ROOT  : %s\n', REF_ROOT);
fprintf('  PROJ_ROOT : %s\n\n', PROJ_ROOT);

V = {'FAIL', 'OK  '};
TOL_irf = 1e-6;

% =========================================================================
%  BLOQUE 1 -- Regresion BNW (Chat 7)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- Regresion BNW (Chat 7), spec_bnw_is\n');
fprintf('======================================================\n\n');

Cfg = struct();
run(fullfile(REF_ROOT, 'config', 'spec_bnw_is.m'));
Cfg.PLOT_IRFS    = false;
Cfg.SAVE_RESULTS = false;
fprintf('  Cfg.MODE = %s | Cfg.ND = %g | Cfg.SEED = %d\n', Cfg.MODE, Cfg.ND, Cfg.SEED);

Dataset_bnw   = load_data(Cfg);
Posterior_bnw = build_posterior(Dataset_bnw, Cfg);

fprintf('  Corriendo IS BNW (nd=%g, esperar varios minutos)...\n', Cfg.ND);
rng('default'); rng(0);
tic;
Results_bnw = run_is(Posterior_bnw, Cfg);
t_bnw = toc;
fprintf('  Tiempo: %.1f seg\n\n', t_bnw);

Ltilde_bnw = Results_bnw.LtildeStruct.data;
ne_bnw     = Results_bnw.ne;

val_ib = Ltilde_bnw(end, end, end, end);
val_ic = median(squeeze(Ltilde_bnw(:, 2, 1, :)), 'all');
REF_ib = 0.2041864191;
REF_ic = 2.9521795528;

ok_ib = abs(val_ib - REF_ib) <= TOL_irf;
ok_ic = abs(val_ic - REF_ic) <= TOL_irf;

fprintf('  I-b) Ltilde(end,end,end,end) = %.10f   (ref %.10f)   %s\n', val_ib, REF_ib, V{int32(ok_ib)+1});
fprintf('  I-c) median(Lt(:,2,1,:))     = %.10f   (ref %.10f)   %s\n', val_ic, REF_ic, V{int32(ok_ic)+1});
fprintf('  ne efectivo                  = %d\n\n', ne_bnw);

bloque1_pasa = ok_ib && ok_ic;
if bloque1_pasa
    fprintf('  >> BLOQUE 1: PASA -- baseline BNW (Chat 7) intacto.\n\n');
else
    fprintf('  >> BLOQUE 1: NO PASA -- revisar antes de continuar.\n\n');
end

% =========================================================================
%  BLOQUE 2 -- Integracion funcional: 4 specs baseline end-to-end
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Integracion 4 specs baseline\n');
fprintf('======================================================\n\n');

spec_names = {'spec_aa_diffuse_v0', 'spec_aa_minn_v0', 'spec_mm_diffuse_v0', 'spec_mm_minn_v0'};

% Fechas de spot-check de las dummies COVID por spec (year, month, valor
% esperado 1/0 en cada columna de DummyMatrix). Confirma que las ventanas
% documentadas en cada spec_*.m realmente caen donde se espera dentro de
% Dataset.dates real (no solo en el papel).
spotcheck_aa = struct( ...
    'inside_drop',     [2020, 6], ...   % dentro de covid_drop_aa (2020-03->2021-02)
    'inside_rebound',  [2021, 6], ...   % dentro de covid_rebound_aa (2021-03->2022-02)
    'outside_both',    [2019, 6]);      % fuera de ambas ventanas
spotcheck_mm = struct( ...
    'inside_drop',     [2020, 4], ...   % dentro de covid_drop_mm (2020-03->2020-04)
    'inside_rebound',  [2020, 6], ...   % dentro de covid_rebound_mm (2020-05->2020-06)
    'outside_both',    [2020, 8]);      % fuera de ambas ventanas

bloque2_ok   = true;
bloque2_msgs = {};
Results_by_spec = struct();
Dataset_by_spec = struct();
Cfg_by_spec     = struct();
ERPT_by_spec    = struct();

for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};
    fprintf('------------------------------------------------------\n');
    fprintf('  Spec: %s\n', spec_name);
    fprintf('------------------------------------------------------\n');

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));

    % Override SOLO para velocidad del smoke test -- NO es la corrida
    % cientifica (ver ERPT-Chat 4 para las baselines reales con Cfg.ND
    % completo, 3e5).
    Cfg.ND           = 3000;
    Cfg.MAX_IS_DRAWS = 1000;
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;
    fprintf('  [Smoke test] Cfg.ND reducido a %d (solo velocidad, no cientifico)\n', Cfg.ND);

    Dataset_erpt = load_data(Cfg);
    fprintf('  Dataset: %d variables endogenas, freq=%s, T=%d obs\n', ...
        Dataset_erpt.nvar, Dataset_erpt.freq, size(Dataset_erpt.Y_raw, 1));

    % -- Spot-check de las ventanas de Cfg.DUMMIES contra Dataset.dates real -
    is_aa = ~isempty(strfind(spec_name, '_aa_')); %#ok<STREMP>
    if is_aa
        sc = spotcheck_aa;
    else
        sc = spotcheck_mm;
    end
    DummyMatrix = build_dummies(Cfg, Dataset_erpt.dates);
    if size(DummyMatrix, 2) ~= 2
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s: se esperaban 2 columnas de dummies, se obtuvieron %d', ...
            spec_name, size(DummyMatrix, 2)); %#ok<AGROW>
    end

    fn = fieldnames(sc);
    for i = 1:numel(fn)
        yr_mo = sc.(fn{i});
        t_idx = find(year(Dataset_erpt.dates) == yr_mo(1) & month(Dataset_erpt.dates) == yr_mo(2), 1);
        if isempty(t_idx)
            bloque2_ok = false;
            bloque2_msgs{end+1} = sprintf('%s: fecha de spot-check %d-%02d no encontrada en Dataset.dates', ...
                spec_name, yr_mo(1), yr_mo(2)); %#ok<AGROW>
            continue;
        end
        row = DummyMatrix(t_idx, :);
        switch fn{i}
            case 'inside_drop'
                exp_row = [1 0];
            case 'inside_rebound'
                exp_row = [0 1];
            case 'outside_both'
                exp_row = [0 0];
        end
        ok_row = isequal(row, exp_row);
        if ~ok_row
            bloque2_ok = false;
            bloque2_msgs{end+1} = sprintf('%s: dummy en %d-%02d = [%d %d], esperado [%d %d]', ...
                spec_name, yr_mo(1), yr_mo(2), row(1), row(2), exp_row(1), exp_row(2)); %#ok<AGROW>
        end
        fprintf('    [%s] %d-%02d -> DummyMatrix = [%d %d]   %s\n', ...
            fn{i}, yr_mo(1), yr_mo(2), row(1), row(2), V{int32(ok_row)+1});
    end

    validate_cfg(Cfg, Dataset_erpt);
    Posterior_erpt = build_posterior(Dataset_erpt, Cfg);

    fprintf('  Corriendo IS (nd=%d)...\n', Cfg.ND);
    rng('default'); rng(Cfg.SEED);
    tic;
    Results_erpt = run_is(Posterior_erpt, Cfg);
    t_erpt = toc;
    fprintf('  Tiempo: %.1f seg | ne=%d\n\n', t_erpt, Results_erpt.ne);

    if Results_erpt.ne < 20
        fprintf(['  [ALERTA] ne=%d es muy bajo para este smoke test (ND reducido). ' ...
            'Las tablas de abajo pueden verse degeneradas -- problema de ' ...
            'tamano de muestra del smoke test, no de la spec. Si ne=0, sube ' ...
            'Cfg.ND en este bloque y vuelve a correr.\n\n'], Results_erpt.ne);
    end

    Results_by_spec.(spec_name) = Results_erpt;
    Dataset_by_spec.(spec_name) = Dataset_erpt;
    Cfg_by_spec.(spec_name)     = Cfg;

    fprintf('  --- calculate_erpt.m, %s ---\n', spec_name);
    transform_type = 'mm';
    if is_aa
        transform_type = 'aa';
    end
    try
        ERPT = calculate_erpt(Results_erpt, Dataset_erpt, Cfg, transform_type);
    catch ME
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s: ERROR INESPERADO en calculate_erpt: %s', spec_name, ME.message); %#ok<AGROW>
        fprintf('  [ERROR] %s\n\n', ME.message);
        continue;
    end
    ERPT_by_spec.(spec_name) = ERPT;

    n_shocks_out = numel(ERPT.shocks);
    if n_shocks_out ~= Dataset_erpt.nvar
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s: se esperaban %d choques (Cfg.SHOCK_IDX=all), se obtuvieron %d', ...
            spec_name, Dataset_erpt.nvar, n_shocks_out); %#ok<AGROW>
    end

    names_out = {ERPT.shocks.name};
    if ~all(ismember({'Cam','Dem','Ofe'}, names_out))
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s: no se encontraron los 3 choques nombrados Cam/Dem/Ofe', spec_name); %#ok<AGROW>
    end

    fprintf('  %-6s  %-10s  %-8s', 'Choque', 'Precio', 'h');
    fprintf('  %8s  %8s  %8s\n', sprintf('p%.0f', Cfg.CRED_BANDS(1,1)*100), 'Mediana', sprintf('p%.0f', Cfg.CRED_BANDS(1,2)*100));

    h12 = find(ERPT.horizons == 12, 1);
    for k = 1:n_shocks_out
        sh = ERPT.shocks(k);
        for p = 1:numel(sh.prices)
            pr = sh.prices(p);
            if ~isempty(h12)
                fprintf('  %-6s  %-10s  h=%-3d  %8.4f  %8.4f  %8.4f\n', ...
                    sh.name, pr.var, 12, pr.band_lo(1,h12), pr.median(h12), pr.band_hi(1,h12));
            end
        end
    end
    fprintf('\n');
end

if bloque2_ok
    fprintf('  >> BLOQUE 2: PASA -- las 4 specs corren end-to-end sin errores,\n');
    fprintf('     las ventanas de dummies COVID caen donde se esperaba en\n');
    fprintf('     Dataset.dates real, y calculate_erpt produce 6 choques x 3\n');
    fprintf('     precios en cada una.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA. Detalle:\n');
    for i = 1:numel(bloque2_msgs)
        fprintf('     - %s\n', bloque2_msgs{i});
    end
    fprintf('\n');
end

% =========================================================================
%  BLOQUE 3 -- Casos de error esperados (especificos de este lote)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Casos de error esperados\n');
fprintf('======================================================\n\n');

bloque3_ok   = true;
bloque3_msgs = {};

% Caso 1: prior minnesota con hiperparametro faltante (lambda1) --
% ejercita build_posterior.m (Chat 12) por primera vez en un Cfg real de
% ERPT con datos m/m.
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, 'spec_mm_minn_v0.m'));
    Cfg.PRIOR = rmfield(Cfg.PRIOR, 'lambda1');
    Cfg.ND = 100; Cfg.SAVE_RESULTS = false; Cfg.PLOT_IRFS = false;
    Dataset_bad = load_data(Cfg);
    build_posterior(Dataset_bad, Cfg); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'minnesota sin lambda1: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] minnesota sin lambda1 no genero error\n');
catch ME
    fprintf('  [OK] minnesota sin lambda1 -> error esperado: %s\n', ME.identifier);
end

% Caso 2: dummy con rango de fechas invertido (date_end antes de date_start)
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, 'spec_aa_diffuse_v0.m'));
    Cfg.DUMMIES(1).date_start = [2021, 2];
    Cfg.DUMMIES(1).date_end   = [2020, 3];   % invertido a proposito
    Dataset_bad = load_data(Cfg);
    build_dummies(Cfg, Dataset_bad.dates); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'dummy con rango invertido: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] dummy con rango invertido no genero error\n');
catch ME
    fprintf('  [OK] dummy con rango invertido -> error esperado: %s\n', ME.identifier);
end

% Caso 3: dummy con fecha fuera de la muestra (antes del inicio de datos)
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, 'spec_mm_diffuse_v0.m'));
    Cfg.DUMMIES(1).date_start = [1999, 1];   % fuera de muestra (datos empiezan 2005-02)
    Cfg.DUMMIES(1).date_end   = [1999, 2];
    Dataset_bad = load_data(Cfg);
    build_dummies(Cfg, Dataset_bad.dates); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'dummy con fecha fuera de muestra: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] dummy con fecha fuera de muestra no genero error\n');
catch ME
    fprintf('  [OK] dummy con fecha fuera de muestra -> error esperado: %s\n', ME.identifier);
end

% Caso 4: convencion de variables LEGACY (inf_imp/inf_p/inf_con/ise/tib)
% usada como Cfg.VARS contra el dataset NUEVO (data_erpt_mm.xlsx) -- debe
% fallar porque esos nombres de columna no existen en el archivo.
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, 'spec_mm_diffuse_v0.m'));
    Cfg.VARS = {'ner', 'inf_imp', 'inf_p', 'inf_con', 'ise', 'tib'};   % convencion legacy
    load_data(Cfg); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'VARS legacy contra dataset nuevo: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] VARS legacy contra data_erpt_mm.xlsx no genero error\n');
catch ME
    fprintf('  [OK] VARS legacy contra data_erpt_mm.xlsx -> error esperado: %s\n', ME.identifier);
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
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 3\n');
fprintf('======================================================\n');
fprintf('  Bloque 1 (Regresion BNW / Chat 7)      : %s\n', iif_local(bloque1_pasa, 'PASA', 'NO PASA'));
fprintf('  Bloque 2 (Integracion 4 specs)          : %s\n', iif_local(bloque2_ok,  'PASA', 'NO PASA'));
fprintf('  Bloque 3 (Casos de error)               : %s\n', iif_local(bloque3_ok,  'PASA', 'NO PASA'));
fprintf('------------------------------------------------------\n');
if bloque1_pasa && bloque2_ok && bloque3_ok
    fprintf('  GLOBAL : PASA\n');
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% ── Helper local ─────────────────────────────────────────────────────────
function out = iif_local(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
