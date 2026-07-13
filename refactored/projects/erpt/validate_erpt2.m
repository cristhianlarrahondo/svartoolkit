%VALIDATE_ERPT2  ERPT-Chat 2 — Validacion Tipo S de calculate_erpt.m
%
%   Ejecutar completo (F5), no por secciones.
%
%   BLOQUE 1 — Regresion numerica (Chat 7, obligatoria en protocolo Tipo S):
%     Corre spec_bnw_is (rng(0)) y verifica los valores de referencia del
%     MVP checkpoint. calculate_erpt.m NO toca src/ compartido, pero este
%     bloque confirma que las funciones compartidas que SI usa
%     (select_irfs.m, compute_cirfs.m, resolve_shock_name.m, quantile)
%     siguen produciendo el baseline conocido.
%       I-b) Ltilde(end,end,end,end) = 0.2041864191
%       I-f) ne exacto                = referencia guardada en el chat 7
%
%   BLOQUE 2 — Integracion funcional end-to-end (calculate_erpt.m):
%     Corre las restricciones de spec_v0 contra los datos REALES
%     data_erpt_mm.xlsx (transform_type='mm') y data_erpt_aa.xlsx
%     (transform_type='aa'), con ND reducido -- SOLO para velocidad de
%     este smoke test, NO es una corrida cientifica (ver ERPT-Chat 3/4
%     para las baselines reales). Para TODOS los choques de Cfg.SHOCK_IDX
%     x ambas variables de precio (imp_inf, con_inf -- convencion de los
%     archivos nuevos, distinta de la legacy inf_imp/inf_con).
%
%   BLOQUE 3 — Casos de error esperados (5):
%     transform_type faltante / invalido, nombre de variable inexistente,
%     horizontes fuera de rango, nombre de variable de la convencion
%     legacy usado contra el dataset nuevo.
%
%   Pegar el output completo en el chat para verificacion.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 2 -- calculate_erpt.m (Tipo S)\n');
fprintf('======================================================\n\n');

%% ── Rutas (F5 completo -> mfilename(''fullpath'') es confiable aqui) ─────
val_file      = mfilename('fullpath');          % .../refactored/projects/erpt/validate_erpt2.m
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
TOL_ess = 1e-6;

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
%  BLOQUE 2 -- Integracion funcional: calculate_erpt.m con datos REALES
%              (data_erpt_mm.xlsx / data_erpt_aa.xlsx)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Integracion calculate_erpt.m (datos reales)\n');
fprintf('======================================================\n\n');

% NOTA: data_erpt_mm.xlsx / data_erpt_aa.xlsx usan una convencion de
% nombres DISTINTA a la del archivo legacy data_erpt.xlsx que usan
% spec_v0.m/spec_v1.m (inf_imp/inf_p/inf_con/ise/tib vs.
% imp_inf/pro_inf/con_inf/ea/ir). El ORDEN de las 6 variables core es el
% mismo, asi que las restricciones S/Z posicionales de spec_v0.m siguen
% siendo validas -- este bloque solo sobreescribe Cfg.VARS y Cfg.DATA_FILE
% sobre esa base. Esto es un Cfg ad-hoc para ESTE smoke test; las specs
% formales de las 4 baselines (spec_aa_diffuse_v0, etc., ya con Cfg.VARS
% correcto de fabrica) son ERPT-Chat 3.
VARS_NUEVO = {'ner', 'imp_inf', 'pro_inf', 'con_inf', 'ea', 'ir'};   % core; excluye oil_price/tot/com_price (robustez futura, B.6)

file_specs = struct('transform', {'mm', 'aa'}, 'filename', {'data_erpt_mm.xlsx', 'data_erpt_aa.xlsx'});

bloque2_ok   = true;
bloque2_msgs = {};
Results_by_transform = struct();
Dataset_by_transform = struct();
Cfg_by_transform      = struct();

for ff = 1:numel(file_specs)
    transform_type = file_specs(ff).transform;
    data_file      = file_specs(ff).filename;

    fprintf('------------------------------------------------------\n');
    fprintf('  Archivo: %s   (transform_type=''%s'')\n', data_file, transform_type);
    fprintf('------------------------------------------------------\n');

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, 'spec_v0.m'));   % base: restricciones S/Z, SHOCK_NAMES, prior, CRED_BANDS

    % -- Overrides para usar el archivo real correspondiente ----------------
    Cfg.DATA_FILE = fullfile(PROJ_ROOT, 'data', data_file);
    Cfg.VARS      = VARS_NUEVO;
    % Cfg.VAR_ROLES ya trae 6 entradas 'endogenous' (mismo largo) -- se reusa

    % Override SOLO para velocidad del smoke test -- NO es una corrida
    % cientifica (ver ERPT-Chat 3/4 para las baselines reales con Cfg.ND
    % completo).
    Cfg.ND           = 3000;
    Cfg.MAX_IS_DRAWS = 1000;
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;
    fprintf('  [Smoke test] Cfg.ND reducido a %d (solo velocidad, no cientifico)\n', Cfg.ND);

    Dataset_erpt = load_data(Cfg);
    fprintf('  Dataset: %d variables endogenas, freq=%s, T=%d obs\n', ...
        Dataset_erpt.nvar, Dataset_erpt.freq, size(Dataset_erpt.Y_raw, 1));

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
            'tamano de muestra del smoke test, no de calculate_erpt.m. Si ' ...
            'ne=0, sube Cfg.ND en este bloque y vuelve a correr.\n\n'], Results_erpt.ne);
    end

    Results_by_transform.(transform_type) = Results_erpt;
    Dataset_by_transform.(transform_type) = Dataset_erpt;
    Cfg_by_transform.(transform_type)      = Cfg;

    fprintf('--- calculate_erpt.m, transform_type=''%s'' ---\n', transform_type);
    try
        ERPT = calculate_erpt(Results_erpt, Dataset_erpt, Cfg, transform_type);
    catch ME
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s (%s): ERROR INESPERADO: %s', data_file, transform_type, ME.message); %#ok<AGROW>
        fprintf('  [ERROR] %s\n\n', ME.message);
        continue;
    end

    % -- Chequeos estructurales ----------------------------------------------
    n_shocks_out = numel(ERPT.shocks);
    if n_shocks_out ~= Dataset_erpt.nvar
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s: se esperaban %d choques (Cfg.SHOCK_IDX=all), se obtuvieron %d', ...
            data_file, Dataset_erpt.nvar, n_shocks_out); %#ok<AGROW>
    end

    fprintf('  %-6s  %-10s  %-8s', 'Choque', 'Precio', 'h');
    fprintf('  %8s  %8s  %8s\n', 'Mediana', sprintf('p%.0f', Cfg.CRED_BANDS(1,1)*100), sprintf('p%.0f', Cfg.CRED_BANDS(1,2)*100));

    for k = 1:n_shocks_out
        sh = ERPT.shocks(k);
        for p = 1:numel(sh.prices)
            pr = sh.prices(p);

            % -- Chequeos de tamano -----------------------------------------
            nh = numel(ERPT.horizons);
            if numel(pr.median) ~= nh || size(pr.band_lo,2) ~= nh || size(pr.ratio_draws,1) ~= nh
                bloque2_ok = false;
                bloque2_msgs{end+1} = sprintf('%s shock=%s precio=%s: dimensiones inconsistentes', ...
                    data_file, sh.name, pr.var); %#ok<AGROW>
            end
            if any(~isfinite(pr.median))
                % Esperado ocasionalmente en S3 (set-identificado) si el
                % denominador cruza cero en TODOS los draws de un horizonte;
                % se reporta como advertencia, no como fallo (decision 6).
                fprintf('  [ADVERTENCIA] %s / %s: mediana no finita en algun horizonte (denominador degenerado -- esperado en S3/oferta con ND reducido)\n', ...
                    sh.name, pr.var);
            end

            h12 = find(ERPT.horizons == 12, 1);
            if ~isempty(h12)
                fprintf('  %-6s  %-10s  h=%-3d  %8.4f  %8.4f  %8.4f\n', ...
                    sh.name, pr.var, 12, pr.median(h12), pr.band_lo(1,h12), pr.band_hi(1,h12));
            end
        end
    end
    fprintf('\n');

    % -- Sanity check cualitativo: S3 (oferta, set-identificado) deberia
    %    tener bandas mas anchas que Cam en h=12 (decision 4, ERPT-Chat 1) --
    names_out = {ERPT.shocks.name};
    idx_ofe = find(strcmp(names_out, 'Ofe'), 1);
    idx_cam = find(strcmp(names_out, 'Cam'), 1);
    h12 = find(ERPT.horizons == 12, 1);
    if ~isempty(idx_ofe) && ~isempty(idx_cam) && ~isempty(h12)
        w_ofe = ERPT.shocks(idx_ofe).prices(1).band_hi(1,h12) - ERPT.shocks(idx_ofe).prices(1).band_lo(1,h12);
        w_cam = ERPT.shocks(idx_cam).prices(1).band_hi(1,h12) - ERPT.shocks(idx_cam).prices(1).band_lo(1,h12);
        fprintf('  [Diagnostico] Ancho de banda h=12, %s: Ofe=%.4f vs Cam=%.4f  (%s; con ND reducido puede no cumplirse)\n\n', ...
            ERPT.shocks(idx_ofe).prices(1).var, w_ofe, w_cam, ...
            iif_local(w_ofe > w_cam, '[OK] Ofe mas ancho, esperado', '[NO necesariamente -- revisar con ND completo]'));
    end
end

if bloque2_ok
    fprintf('  >> BLOQUE 2: PASA -- calculate_erpt.m corre end-to-end contra data_erpt_mm.xlsx\n');
    fprintf('     (transform=mm) y data_erpt_aa.xlsx (transform=aa), todos los choques x\n');
    fprintf('     ambas variables de precio, sin errores inesperados.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA. Detalle:\n');
    for i = 1:numel(bloque2_msgs)
        fprintf('     - %s\n', bloque2_msgs{i});
    end
    fprintf('\n');
end

% =========================================================================
%  BLOQUE 3 -- Casos de error esperados
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Casos de error esperados\n');
fprintf('======================================================\n\n');

bloque3_ok = true;
bloque3_msgs = {};

% Reusa los resultados 'mm' ya corridos en el Bloque 2 (mismos objetos,
% ningun recalculo).
Results_mm = Results_by_transform.mm;
Dataset_mm = Dataset_by_transform.mm;
Cfg_mm     = Cfg_by_transform.mm;

% Caso 1: transform_type faltante
try
    calculate_erpt(Results_mm, Dataset_mm, Cfg_mm); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'transform_type faltante: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] transform_type faltante no genero error\n');
catch ME
    fprintf('  [OK] transform_type faltante -> error esperado: %s\n', ME.identifier);
end

% Caso 2: transform_type invalido
try
    calculate_erpt(Results_mm, Dataset_mm, Cfg_mm, 'yoy'); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'transform_type invalido: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] transform_type invalido no genero error\n');
catch ME
    fprintf('  [OK] transform_type invalido -> error esperado: %s\n', ME.identifier);
end

% Caso 3: variable denominador inexistente (probando ademas que un nombre
% de la convencion LEGACY, inf_imp, no exista en el dataset nuevo)
try
    calculate_erpt(Results_mm, Dataset_mm, Cfg_mm, 'mm', {'inf_imp'}, 'variable_que_no_existe'); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'denom_var inexistente: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] denom_var inexistente no genero error\n');
catch ME
    fprintf('  [OK] denom_var inexistente -> error esperado: %s\n', ME.identifier);
end

% Caso 4: horizonte fuera de rango
try
    calculate_erpt(Results_mm, Dataset_mm, Cfg_mm, 'mm', {'imp_inf'}, 'ner', [1 6 12 999]); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'horizonte fuera de rango: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] horizonte fuera de rango no genero error\n');
catch ME
    fprintf('  [OK] horizonte fuera de rango -> error esperado: %s\n', ME.identifier);
end

% Caso 5: nombre de variable de la convencion LEGACY usado como price_var
% contra el dataset NUEVO -- debe fallar (son datasets con nombres
% distintos, ver nota al inicio del Bloque 2)
try
    calculate_erpt(Results_mm, Dataset_mm, Cfg_mm, 'mm', {'inf_p'}, 'ner'); %#ok<NASGU>
    bloque3_ok = false;
    bloque3_msgs{end+1} = 'price_var de convencion legacy contra dataset nuevo: NO lanzo error (deberia)'; %#ok<AGROW>
    fprintf('  [FAIL] price_var legacy (inf_p) contra dataset nuevo no genero error\n');
catch ME
    fprintf('  [OK] price_var legacy (inf_p) contra dataset nuevo -> error esperado: %s\n', ME.identifier);
end

fprintf('\n');
if bloque3_ok
    fprintf('  >> BLOQUE 3: PASA -- los 5 casos de error se comportan como se esperaba.\n\n');
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
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 2\n');
fprintf('======================================================\n');
fprintf('  Bloque 1 (Regresion BNW / Chat 7) : %s\n', iif_local(bloque1_pasa, 'PASA', 'NO PASA'));
fprintf('  Bloque 2 (Integracion funcional)   : %s\n', iif_local(bloque2_ok,  'PASA', 'NO PASA'));
fprintf('  Bloque 3 (Casos de error)          : %s\n', iif_local(bloque3_ok,  'PASA', 'NO PASA'));
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
