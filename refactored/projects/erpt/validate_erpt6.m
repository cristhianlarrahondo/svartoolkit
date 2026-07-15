%VALIDATE_ERPT6  ERPT-Chat 7 -- Validacion Tipo S de los 16 specs del
%   Ejercicio A (disenados en ERPT-Chat 6, Discusion APROBADO).
%
%   Ejecutar completo (F5), no por secciones. No requiere configurar nada
%   a mano. Pegar el output completo de consola en el chat.
%
%   BLOQUE 0 -- Regresion BNW (Chat 7), smoke check obligatorio Tipo S:
%     PFA (spec_bnw_pfa, rng(0), ND nativo 1e4)   : Ltilde(end,end,end)
%       = -0.2326865051
%     IS  (spec_bnw_is,  rng('default');rng(0), ND nativo 3e5) :
%       Ltilde(end,end,end,end) = 0.2041864191
%     El ND de BNW NO se reduce -- los valores de referencia solo se
%     reproducen a ND nativo (igual que ERPT-Chat 3/4). Si BNW no pasa, NO
%     PASA global aunque los 16 specs funcionen.
%
%   BLOQUE 1 -- Verificacion de construccion (los 16, ambas matrices):
%     Corre cada spec_A_*.m y compara Cfg.S{k}/Cfg.Z{k} fila a fila contra
%     la traduccion D2 de ERPT-Chat 6 (matrices base y rob), reconstruidas
%     independientemente con build_restriction_row. Verifica tamanos y
%     contenido exacto (isequal).
%
%   BLOQUE 2 -- Smoke run end-to-end de los 16 (ND=20000, SOLO velocidad):
%     load_data -> build_dummies (spot-check de ventanas aa/mm) ->
%     validate_cfg -> build_posterior -> run_is -> calculate_erpt, sin
%     error. Verifica 6 choques y 3 price_vars por spec, y que los 4
%     choques nombrados Cam/Dem/Ofe/Mon esten presentes. NO es la corrida
%     cientifica (esa es ND=3e5, el siguiente chat). ND subido de 3000
%     (ERPT-Chat 3) a 20000: con 4 choques restringidos la probabilidad
%     conjunta de aceptacion es menor y 3000 produjo ne=0 en la primera
%     corrida de este smoke.
%
%   BLOQUE 3 -- Casos de error esperados (5), con identificador explicito:
%     minnesota sin lambda3, dummy con rango invertido, dummy fuera de
%     muestra, build_restriction_row con var_idx fuera de rango, y (CU-1,
%     nuevo) restricciones de signo contradictorias -> run_is.m debe fallar
%     con 'run_is:noAcceptedDraws' en vez de crashear en randsample.
%
%   NOTA Tipo R-core: este chat corrige un defecto real encontrado en
%   run_is.m (crash con mensaje generico de MATLAB cuando 0 draws
%   satisfacen las restricciones de signo). El BLOQUE 0 (regresion BNW
%   completa, PFA+IS, ND nativo) es condicion de aprobacion obligatoria:
%   si el fix rompe BNW, NO PASA sin excepcion aunque ERPT funcione.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 7 -- 16 specs Ejercicio A (Tipo S)\n');
fprintf('======================================================\n\n');

%% -- Rutas (F5 completo -> mfilename('fullpath') confiable) --------------
val_file      = mfilename('fullpath');          % .../refactored/projects/erpt/validate_erpt6.m
PROJ_ROOT     = fileparts(val_file);            % .../refactored/projects/erpt
PROJECTS_ROOT = fileparts(PROJ_ROOT);           % .../refactored/projects
REF_ROOT      = fileparts(PROJECTS_ROOT);       % .../refactored
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(PROJ_CFG);
addpath(PROJ_SRC);

fprintf('  REF_ROOT  : %s\n', REF_ROOT);
fprintf('  PROJ_ROOT : %s\n\n', PROJ_ROOT);

V       = {'FAIL', 'OK  '};
TOL_irf = 1e-6;

% Los 16 specs del Ejercicio A (D4). El nombre codifica matriz/transform/
% prior/lag; de ahi se derivan los checks (no hay tabla hardcodeada aparte).
spec_names = { ...
    'spec_A_base_aa_diffuse_lag2_v0', 'spec_A_base_aa_diffuse_lag4_v0', ...
    'spec_A_base_aa_minn_lag2_v0',    'spec_A_base_aa_minn_lag4_v0', ...
    'spec_A_base_mm_diffuse_lag2_v0', 'spec_A_base_mm_diffuse_lag4_v0', ...
    'spec_A_base_mm_minn_lag2_v0',    'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_rob_aa_diffuse_lag2_v0',  'spec_A_rob_aa_diffuse_lag4_v0', ...
    'spec_A_rob_aa_minn_lag2_v0',     'spec_A_rob_aa_minn_lag4_v0', ...
    'spec_A_rob_mm_diffuse_lag2_v0',  'spec_A_rob_mm_diffuse_lag4_v0', ...
    'spec_A_rob_mm_minn_lag2_v0',     'spec_A_rob_mm_minn_lag4_v0'};
n_specs = numel(spec_names);

% =========================================================================
%  BLOQUE 0 -- Regresion BNW (Chat 7): PFA + IS, ND nativo
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 0 -- Regresion BNW (Chat 7): PFA + IS\n');
fprintf('======================================================\n\n');

% -- PFA (spec_bnw_pfa, rng(0), ND nativo 1e4) ---------------------------
fprintf('  --- BNW PFA (spec_bnw_pfa) ---\n');
clear Cfg;
Cfg = struct();
run(fullfile(REF_ROOT, 'config', 'spec_bnw_pfa.m'));
Cfg.PLOT_IRFS    = false;
Cfg.SAVE_RESULTS = false;
fprintf('  Cfg.MODE = %s | Cfg.ND = %g | Cfg.SEED = %d\n', Cfg.MODE, Cfg.ND, Cfg.SEED);

Dataset_pfa   = load_data(Cfg);
Posterior_pfa = build_posterior(Dataset_pfa, Cfg);
fprintf('  Corriendo PFA (nd=%g, esperar ~1-3 min)...\n', Cfg.ND);
rng(0);
tic;
Results_pfa = run_pfa(Posterior_pfa, Cfg);
t_pfa = toc;

Ltilde_pfa = Results_pfa.LtildeStruct.data;
val_pb = Ltilde_pfa(end, end, end);
REF_pb = -0.2326865051;
ok_pb  = abs(val_pb - REF_pb) <= TOL_irf;
fprintf('  Tiempo: %.1f seg\n', t_pfa);
fprintf('  P-b) Ltilde(end,end,end)     = %.10f   (ref %.10f)   %s\n\n', val_pb, REF_pb, V{int32(ok_pb)+1});

% -- IS (spec_bnw_is, rng('default');rng(0), ND nativo 3e5) --------------
fprintf('  --- BNW IS (spec_bnw_is) ---\n');
clear Cfg;
Cfg = struct();
run(fullfile(REF_ROOT, 'config', 'spec_bnw_is.m'));
Cfg.PLOT_IRFS    = false;
Cfg.SAVE_RESULTS = false;
fprintf('  Cfg.MODE = %s | Cfg.ND = %g | Cfg.SEED = %d\n', Cfg.MODE, Cfg.ND, Cfg.SEED);

Dataset_is   = load_data(Cfg);
Posterior_is = build_posterior(Dataset_is, Cfg);
fprintf('  Corriendo IS (nd=%g, esperar ~10-15 min)...\n', Cfg.ND);
rng('default'); rng(0);
tic;
Results_is = run_is(Posterior_is, Cfg);
t_is = toc;

Ltilde_is = Results_is.LtildeStruct.data;
val_ib = Ltilde_is(end, end, end, end);
REF_ib = 0.2041864191;
ok_ib  = abs(val_ib - REF_ib) <= TOL_irf;
fprintf('  Tiempo: %.1f seg | ne=%d\n', t_is, Results_is.ne);
fprintf('  I-b) Ltilde(end,end,end,end) = %.10f   (ref %.10f)   %s\n\n', val_ib, REF_ib, V{int32(ok_ib)+1});

bloque0_pasa = ok_pb && ok_ib;
if bloque0_pasa
    fprintf('  >> BLOQUE 0: PASA -- baseline BNW (PFA e IS) intacto.\n\n');
else
    fprintf('  >> BLOQUE 0: NO PASA -- el core esta alterado. Detener; los\n');
    fprintf('     16 specs no pueden aprobarse si BNW no reproduce (protocolo).\n\n');
end

% =========================================================================
%  BLOQUE 1 -- Verificacion de construccion S/Z de los 16 (contra D2)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- Construccion S/Z de los 16 (fila a fila vs D2)\n');
fprintf('======================================================\n\n');

bloque1_ok   = true;
bloque1_msgs = {};

for ss = 1:n_specs
    spec_name = spec_names{ss};
    meta      = parse_spec_name(spec_name);   % helper local

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));

    nv = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));
    nh = numel(Cfg.HORIZONS_RESTRICT);

    % -- Esperado segun D2, reconstruido independientemente --------------
    [S_exp, Z_exp] = expected_matrix(meta.matrix, nv, nh);

    % -- Comparacion celda a celda (S y Z, los 6 choques) ----------------
    ok_spec = true;
    for k = 1:nv
        if ~isequal(Cfg.S{k}, S_exp{k})
            ok_spec = false;
            bloque1_msgs{end+1} = sprintf('%s: S{%d} no coincide con D2 (%s)', spec_name, k, meta.matrix); %#ok<AGROW>
        end
        if ~isequal(Cfg.Z{k}, Z_exp{k})
            ok_spec = false;
            bloque1_msgs{end+1} = sprintf('%s: Z{%d} no coincide con D2 (%s)', spec_name, k, meta.matrix); %#ok<AGROW>
        end
    end

    % -- Checks de metadatos del spec ------------------------------------
    if ~isequal(Cfg.SHOCK_NAMES, {'Cam','Dem','Ofe','Mon'})
        ok_spec = false;
        bloque1_msgs{end+1} = sprintf('%s: SHOCK_NAMES != {Cam,Dem,Ofe,Mon}', spec_name); %#ok<AGROW>
    end
    if ~strcmp(Cfg.SHOCK_IDX, 'all')
        ok_spec = false;
        bloque1_msgs{end+1} = sprintf('%s: SHOCK_IDX != all', spec_name); %#ok<AGROW>
    end
    if Cfg.NLAG ~= meta.lag
        ok_spec = false;
        bloque1_msgs{end+1} = sprintf('%s: NLAG=%d != %d (nombre)', spec_name, Cfg.NLAG, meta.lag); %#ok<AGROW>
    end
    % Prior: diffuse -> Cfg.PRIOR ausente ; minn -> minnesota con D3
    has_prior = isfield(Cfg, 'PRIOR');
    if strcmp(meta.prior, 'diffuse')
        if has_prior
            ok_spec = false;
            bloque1_msgs{end+1} = sprintf('%s: diffuse pero Cfg.PRIOR definido', spec_name); %#ok<AGROW>
        end
    else  % minn
        if ~has_prior || ~strcmp(Cfg.PRIOR.type, 'minnesota') ...
                || Cfg.PRIOR.lambda1 ~= 0.1 || Cfg.PRIOR.lambda2 ~= 0.5 || Cfg.PRIOR.lambda3 ~= 2
            ok_spec = false;
            bloque1_msgs{end+1} = sprintf('%s: minnesota con hiperparametros != D3 (0.1/0.5/2)', spec_name); %#ok<AGROW>
        end
    end
    % Data file segun transform
    exp_data = 'data_erpt_mm.xlsx';
    if strcmp(meta.transform, 'aa'), exp_data = 'data_erpt_aa.xlsx'; end
    [~, df_name, df_ext] = fileparts(Cfg.DATA_FILE);
    if ~strcmp([df_name df_ext], exp_data)
        ok_spec = false;
        bloque1_msgs{end+1} = sprintf('%s: DATA_FILE=%s != %s', spec_name, [df_name df_ext], exp_data); %#ok<AGROW>
    end

    if ~ok_spec, bloque1_ok = false; end
    n_sz = sum(cellfun(@(x) size(x,1), Cfg.S)) + sum(cellfun(@(x) size(x,1), Cfg.Z));
    fprintf('  %-32s  filas S+Z=%2d  %s\n', spec_name, n_sz, V{int32(ok_spec)+1});
end

fprintf('\n');
if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- los 16 specs construyen S/Z exactamente\n');
    fprintf('     segun D2 (base y rob), con SHOCK_NAMES/NLAG/prior/datos correctos.\n\n');
else
    fprintf('  >> BLOQUE 1: NO PASA. Detalle:\n');
    for i = 1:numel(bloque1_msgs)
        fprintf('     - %s\n', bloque1_msgs{i});
    end
    fprintf('\n');
end

% =========================================================================
%  BLOQUE 2 -- Smoke run end-to-end de los 16 (ND=3000)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Smoke run end-to-end de los 16 (ND=3000)\n');
fprintf('======================================================\n\n');

% Spot-check de ventanas de dummies por transform (year, month -> [drop rebound])
spotcheck_aa = struct( ...
    'inside_drop',    [2020, 6], ...   % dentro covid_drop_aa (2020-03->2021-02)
    'inside_rebound', [2021, 6], ...   % dentro covid_rebound_aa (2021-03->2022-02)
    'outside_both',   [2019, 6]);
spotcheck_mm = struct( ...
    'inside_drop',    [2020, 4], ...   % dentro covid_drop_mm (2020-03->2020-04)
    'inside_rebound', [2020, 6], ...   % dentro covid_rebound_mm (2020-05->2020-06)
    'outside_both',   [2020, 8]);

bloque2_ok   = true;
bloque2_msgs = {};

for ss = 1:n_specs
    spec_name = spec_names{ss};
    meta      = parse_spec_name(spec_name);
    fprintf('------------------------------------------------------\n');
    fprintf('  Spec: %s\n', spec_name);
    fprintf('------------------------------------------------------\n');

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));

    % Override SOLO para velocidad del smoke -- NO es la corrida cientifica.
    % ND subido de 3000 (ERPT-Chat 3) a 20000: con 4 choques restringidos
    % (vs 3 antes -- D5 de ERPT-Chat 6) la probabilidad conjunta de que un
    % draw satisfaga TODAS las restricciones de signo simultaneamente es
    % menor, y ND=3000 produjo ne=0 en al menos un spec durante la primera
    % corrida de este smoke (spec_A_base_mm_minn_lag2_v0). Ver guardia
    % nueva en run_is.m (CU-1) para el caso ne=0 con mensaje explicito.
    Cfg.ND           = 20000;
    Cfg.MAX_IS_DRAWS = 2000;
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;
    fprintf('  [Smoke] Cfg.ND=%d (solo velocidad, no cientifico)\n', Cfg.ND);

    Dataset = load_data(Cfg);
    fprintf('  Dataset: %d endogenas, freq=%s, T=%d obs\n', ...
        Dataset.nvar, Dataset.freq, size(Dataset.Y_raw, 1));

    % -- Spot-check ventanas de dummies contra Dataset.dates real --------
    if strcmp(meta.transform, 'aa'), sc = spotcheck_aa; else, sc = spotcheck_mm; end
    DummyMatrix = build_dummies(Cfg, Dataset.dates);
    if size(DummyMatrix, 2) ~= 2
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s: se esperaban 2 dummies, hay %d', spec_name, size(DummyMatrix,2)); %#ok<AGROW>
    end
    fn = fieldnames(sc);
    for i = 1:numel(fn)
        ym = sc.(fn{i});
        t_idx = find(year(Dataset.dates) == ym(1) & month(Dataset.dates) == ym(2), 1);
        if isempty(t_idx)
            bloque2_ok = false;
            bloque2_msgs{end+1} = sprintf('%s: fecha %d-%02d no esta en Dataset.dates', spec_name, ym(1), ym(2)); %#ok<AGROW>
            continue;
        end
        row = DummyMatrix(t_idx, :);
        switch fn{i}
            case 'inside_drop',    exp_row = [1 0];
            case 'inside_rebound', exp_row = [0 1];
            case 'outside_both',   exp_row = [0 0];
        end
        ok_row = isequal(row, exp_row);
        if ~ok_row
            bloque2_ok = false;
            bloque2_msgs{end+1} = sprintf('%s: dummy %d-%02d=[%d %d], esperado [%d %d]', ...
                spec_name, ym(1), ym(2), row(1), row(2), exp_row(1), exp_row(2)); %#ok<AGROW>
        end
        fprintf('    [%s] %d-%02d -> [%d %d]  %s\n', fn{i}, ym(1), ym(2), row(1), row(2), V{int32(ok_row)+1});
    end

    validate_cfg(Cfg, Dataset);
    Posterior = build_posterior(Dataset, Cfg);

    fprintf('  Corriendo IS (nd=%d)...\n', Cfg.ND);
    rng('default'); rng(Cfg.SEED);
    tic;
    Results = run_is(Posterior, Cfg);
    t_e = toc;
    fprintf('  Tiempo: %.1f seg | ne=%d\n', t_e, Results.ne);
    if Results.ne < 20
        fprintf(['  [ALERTA] ne=%d muy bajo para smoke (ND reducido). Tablas\n' ...
            '  pueden verse degeneradas -- es tamano de muestra del smoke, no\n' ...
            '  la spec. Si ne=0, sube Cfg.ND en este bloque.\n'], Results.ne);
    end

    transform_type = meta.transform;   % 'aa' | 'mm'
    try
        ERPT = calculate_erpt(Results, Dataset, Cfg, transform_type);
    catch ME
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s: ERROR en calculate_erpt: %s', spec_name, ME.message); %#ok<AGROW>
        fprintf('  [ERROR] %s\n\n', ME.message);
        continue;
    end

    n_shocks_out = numel(ERPT.shocks);
    if n_shocks_out ~= Dataset.nvar
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s: se esperaban %d choques, se obtuvieron %d', ...
            spec_name, Dataset.nvar, n_shocks_out); %#ok<AGROW>
    end
    names_out = {ERPT.shocks.name};
    if ~all(ismember({'Cam','Dem','Ofe','Mon'}, names_out))
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s: faltan choques nombrados Cam/Dem/Ofe/Mon', spec_name); %#ok<AGROW>
    end
    % 3 price_vars por choque
    for k = 1:n_shocks_out
        if numel(ERPT.shocks(k).prices) ~= 3
            bloque2_ok = false;
            bloque2_msgs{end+1} = sprintf('%s: choque %s tiene %d price_vars (esperado 3)', ...
                spec_name, ERPT.shocks(k).name, numel(ERPT.shocks(k).prices)); %#ok<AGROW>
            break;
        end
    end
    fprintf('  calculate_erpt: %d choques x %d price_vars\n\n', n_shocks_out, numel(ERPT.shocks(1).prices));
end

if bloque2_ok
    fprintf('  >> BLOQUE 2: PASA -- los 16 corren end-to-end sin error,\n');
    fprintf('     ventanas de dummies caen donde se espera, y calculate_erpt\n');
    fprintf('     produce 6 choques x 3 price_vars en cada uno.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA. Detalle:\n');
    for i = 1:numel(bloque2_msgs)
        fprintf('     - %s\n', bloque2_msgs{i});
    end
    fprintf('\n');
end

% =========================================================================
%  BLOQUE 3 -- Casos de error esperados (identificador explicito)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Casos de error esperados\n');
fprintf('======================================================\n\n');

bloque3_ok   = true;
bloque3_msgs = {};

% Caso 1: minnesota sin lambda3 (nuevo hiperparam D3) -> build_posterior error
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, 'spec_A_base_mm_minn_lag4_v0.m'));
    Cfg.PRIOR = rmfield(Cfg.PRIOR, 'lambda3');
    Cfg.ND = 100; Cfg.SAVE_RESULTS = false; Cfg.PLOT_IRFS = false;
    Dataset_bad = load_data(Cfg);
    build_posterior(Dataset_bad, Cfg); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'minnesota sin lambda3: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] minnesota sin lambda3 no genero error\n');
catch ME
    fprintf('  [OK] minnesota sin lambda3 -> error esperado: %s\n', ME.identifier);
end

% Caso 2: dummy con rango invertido -> build_dummies:rangeInverted
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, 'spec_A_base_aa_diffuse_lag2_v0.m'));
    Cfg.DUMMIES(1).date_start = [2021, 2];
    Cfg.DUMMIES(1).date_end   = [2020, 3];   % invertido a proposito
    Dataset_bad = load_data(Cfg);
    build_dummies(Cfg, Dataset_bad.dates); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'dummy rango invertido: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] dummy rango invertido no genero error\n');
catch ME
    fprintf('  [OK] dummy rango invertido -> error esperado: %s\n', ME.identifier);
end

% Caso 3: dummy fuera de muestra -> build_dummies:dateNotFound
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, 'spec_A_base_mm_diffuse_lag2_v0.m'));
    Cfg.DUMMIES(1).date_start = [1999, 1];   % fuera de muestra
    Cfg.DUMMIES(1).date_end   = [1999, 2];
    Dataset_bad = load_data(Cfg);
    build_dummies(Cfg, Dataset_bad.dates); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'dummy fuera de muestra: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] dummy fuera de muestra no genero error\n');
catch ME
    fprintf('  [OK] dummy fuera de muestra -> error esperado: %s\n', ME.identifier);
end

% Caso 4: build_restriction_row con var_idx fuera de rango -> badVarIdx
try
    build_restriction_row(7, 1, 6, 1, 1);   % var_idx=7 > n_vars=6
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'build_restriction_row var_idx=7: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] build_restriction_row var_idx fuera de rango no genero error\n');
catch ME
    fprintf('  [OK] build_restriction_row var_idx fuera de rango -> error esperado: %s\n', ME.identifier);
end

% Caso 5 (CU-1, regresion del bug encontrado en la primera corrida de este
% smoke): restricciones de signo contradictorias -> 0 draws satisfacen ->
% run_is.m debe fallar con error explicito (noAcceptedDraws), NO con el
% crash generico de randsample ("W must contain non-negative values...").
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, 'spec_A_base_aa_diffuse_lag2_v0.m'));
    Cfg.ND = 50; Cfg.MAX_IS_DRAWS = 20; Cfg.SAVE_RESULTS = false; Cfg.PLOT_IRFS = false;
    nv = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));
    nh = numel(Cfg.HORIZONS_RESTRICT);
    % Forzar contradiccion: ner(+) Y ner(-) simultaneo en el mismo choque.
    Cfg.S{1} = [ build_restriction_row(1, 1, nv, nh,  1); ...
                 build_restriction_row(1, 1, nv, nh, -1) ];
    Dataset_bad = load_data(Cfg);
    Posterior_bad = build_posterior(Dataset_bad, Cfg);
    rng('default'); rng(Cfg.SEED);
    run_is(Posterior_bad, Cfg); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'restricciones de signo contradictorias: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] restricciones contradictorias no genero error\n');
catch ME
    if strcmp(ME.identifier, 'run_is:noAcceptedDraws')
        fprintf('  [OK] 0 draws aceptados -> error esperado y explicito: %s\n', ME.identifier);
    else
        bloque3_ok = false;
        bloque3_msgs{end+1} = sprintf('restricciones contradictorias: error inesperado (%s), se esperaba run_is:noAcceptedDraws', ME.identifier); %#ok<AGROW>
        fprintf('  [FAIL] error distinto al esperado: %s (%s)\n', ME.identifier, ME.message);
    end
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
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 7\n');
fprintf('======================================================\n');
fprintf('  Bloque 0 (Regresion BNW PFA+IS)      : %s\n', iif_local(bloque0_pasa, 'PASA', 'NO PASA'));
fprintf('  Bloque 1 (Construccion S/Z de los 16): %s\n', iif_local(bloque1_ok,   'PASA', 'NO PASA'));
fprintf('  Bloque 2 (Smoke end-to-end de los 16): %s\n', iif_local(bloque2_ok,   'PASA', 'NO PASA'));
fprintf('  Bloque 3 (Casos de error)            : %s\n', iif_local(bloque3_ok,   'PASA', 'NO PASA'));
fprintf('------------------------------------------------------\n');
if bloque0_pasa && bloque1_ok && bloque2_ok && bloque3_ok
    fprintf('  GLOBAL : PASA\n');
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% ======================================================================
%  Helpers locales
%% ======================================================================
function meta = parse_spec_name(name)
%PARSE_SPEC_NAME  Extrae matrix/transform/prior/lag del nombre del spec
%   Formato: spec_A_<base|rob>_<aa|mm>_<diffuse|minn>_lag<2|4>_v0
    parts = strsplit(name, '_');
    % parts = {spec, A, <matrix>, <transform>, <prior>, lag<n>, v0}
    meta.matrix    = parts{3};
    meta.transform = parts{4};
    meta.prior     = parts{5};
    meta.lag       = str2double(erase(parts{6}, 'lag'));
end

function [S_exp, Z_exp] = expected_matrix(matrix, nv, nh)
%EXPECTED_MATRIX  Reconstruye S/Z esperados segun D2 (ERPT-Chat 6),
%   independiente del spec, con build_restriction_row. nv=6, nh=1.
    S_exp = cell(nv, 1);
    Z_exp = cell(nv, 1);
    r = @(v, s) build_restriction_row(v, 1, nv, nh, s);

    % Cam (k=1): identico en base y rob
    S_exp{1} = [ r(1, 1) ];
    Z_exp{1} = [ r(5, 1); r(6, 1) ];

    switch matrix
        case 'base'
            S_exp{2} = [ r(3, 1); r(4, 1); r(5, 1) ];              % Dem
            S_exp{3} = [ r(3,-1); r(4,-1); r(5, 1) ];              % Ofe
            S_exp{4} = [ r(3,-1); r(4,-1); r(5,-1); r(6, 1) ];     % Mon
        case 'rob'
            S_exp{2} = [ r(3, 1); r(4, 1); r(5, 1); r(6, 1) ];     % Dem (agrega ir+)
            S_exp{3} = [ r(4,-1); r(5, 1) ];                       % Ofe (libera pro)
            S_exp{4} = [ r(4,-1); r(5,-1); r(6, 1) ];              % Mon (libera pro)
        otherwise
            error('validate_erpt6:badMatrix', 'Matriz desconocida: %s', matrix);
    end
    Z_exp{2} = []; Z_exp{3} = []; Z_exp{4} = [];
    % k=5,6 quedan [] (residuales)
end

function out = iif_local(cond, a, b)
    if cond, out = a; else, out = b; end
end
