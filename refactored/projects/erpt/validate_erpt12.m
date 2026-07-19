%VALIDATE_ERPT12  ERPT-Chat 12 -- Reconstruccion de la tabla maestra del
%   Ejercicio A (16 specs oficiales) tras la decision de este chat:
%
%   1. El pendiente de "12 specs con ND_OVERRIDES=3e6" (arrastrado desde
%      ERPT-Chat 8/10/11) queda CONFIRMADO COMO RESUELTO: ERPT-Chat 9 ya
%      habia borrado y re-corrido el cache completo de las 16 specs (sin
%      Mon) a ND=3e5, con ne en 1605-2828 -- muy por encima de
%      NE_WARN_THRESHOLD=200. No hace falta ninguna segunda pasada de
%      draws. Este script NO vuelve a tocar eso; solo lo deja documentado.
%
%   2. `mm_minn` REEMPLAZA -- no se agrega en paralelo -- por
%      `mm_niwcustom` en los 16 specs "oficiales" del Ejercicio A. Motivo
%      (discutido y aprobado en el chat, ver diagnose_erpt12_lambda1_
%      sensitivity.m): la grilla completa lambda1=[0.2,0.3,0.4,0.5,0.7,1.0]
%      en los 4 `mm_minn` NUNCA cruza el umbral de 70% estable (max
%      observado 57.5% promedio en lambda1=1.0, valor que ya anula el
%      proposito economico del prior Minnesota). Esto agota la via de
%      recalibracion -- no es una preferencia por "el numero que dio
%      bonito", es evidencia de que mm_minn tal como esta especificado no
%      es viable bajo mm. `aa_minn` NO se toca (nunca file diagnosticado
%      con el mismo problema; 58% estable, sin anomalia de medianas;
%      decision D2 de ERPT-Chat 10 de dejarlo intacto se mantiene sin
%      reabrir).
%
%   Como consecuencia, `build_erpt_comparison.m`/`_long.m` NO requieren
%   ningun cambio estructural: la tabla maestra sigue siendo de 16 specs,
%   solo cambia CUAL archivo de spec entra en la lista `spec_names` (los 4
%   `mm_niwcustom` en vez de los 4 `mm_minn`). Tipo S (no toca src/
%   compartido).
%
%   Los 4 archivos `spec_A_*_mm_minn_lag*_v0.m` NO se borran del repo --
%   quedan como evidencia del diagnostico agotado, fuera de la tabla
%   oficial, documentados en el .md de cierre.
%
%   Ejecutar COMPLETO (F5). Pegar el output de consola en el chat.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 12 -- tabla maestra 16 specs\n');
fprintf('   (mm_niwcustom reemplaza a mm_minn)\n');
fprintf('======================================================\n\n');

%% -- Controles de corrida (editar aqui) -----------------------------------
USE_CACHE         = true;      % true = reusar <OUTPUT_DIR>/results_is.mat si ND cacheado >= objetivo
RUN_BNW_CHECK     = true;      % true = correr Bloque 0 (obligatorio para APRUEBO)
ND_DEFAULT        = 3e5;       % ND objetivo (ya alcanzado en cache por Chat 9/11 para las 16 specs)
NE_WARN_THRESHOLD = 200;       % ne por debajo de esto -> advertencia "bandas indicativas"
FOCUS_HORIZON     = 36;
FOCUS_PRICE_VAR   = 'con_inf';

%% -- Rutas -----------------------------------------------------------------
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(PROJ_CFG);
addpath(PROJ_SRC);

fprintf('  USE_CACHE           : %d\n', USE_CACHE);
fprintf('  RUN_BNW_CHECK       : %d\n', RUN_BNW_CHECK);
fprintf('  ND_DEFAULT          : %g\n', ND_DEFAULT);
fprintf('  NE_WARN_THRESHOLD   : %d\n\n', NE_WARN_THRESHOLD);

V       = {'FAIL', 'OK  '};
TOL_irf = 1e-6;

% -- Los 16 specs OFICIALES del Ejercicio A tras ERPT-Chat 12 --------------
% (mm_niwcustom en el lugar de mm_minn; aa_minn intacto; aa_diffuse y
% mm_diffuse intactos)
spec_names = { ...
    'spec_A_base_aa_diffuse_lag2_v0',   'spec_A_base_aa_diffuse_lag4_v0', ...
    'spec_A_base_aa_minn_lag2_v0',      'spec_A_base_aa_minn_lag4_v0', ...
    'spec_A_base_mm_diffuse_lag2_v0',   'spec_A_base_mm_diffuse_lag4_v0', ...
    'spec_A_base_mm_niwcustom_lag2_v0', 'spec_A_base_mm_niwcustom_lag4_v0', ...
    'spec_A_rob_aa_diffuse_lag2_v0',    'spec_A_rob_aa_diffuse_lag4_v0', ...
    'spec_A_rob_aa_minn_lag2_v0',       'spec_A_rob_aa_minn_lag4_v0', ...
    'spec_A_rob_mm_diffuse_lag2_v0',    'spec_A_rob_mm_diffuse_lag4_v0', ...
    'spec_A_rob_mm_niwcustom_lag2_v0',  'spec_A_rob_mm_niwcustom_lag4_v0' };

% -- Specs EXCLUIDAS de la tabla oficial (evidencia del diagnostico, no se
%    borran del repo, se documentan en el .md de cierre) -------------------
spec_names_excluded = { ...
    'spec_A_base_mm_minn_lag2_v0', 'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_rob_mm_minn_lag2_v0',  'spec_A_rob_mm_minn_lag4_v0' };

NAMED_SHOCKS = {'Cam', 'Dem', 'Ofe'};

% Specs cuyo cache NO es confiable (Cfg.PRIOR cambio in-place tras el
fprintf('  Specs oficiales (16): %d aa_diffuse + %d aa_minn + %d mm_diffuse + %d mm_niwcustom\n\n', 4,4,4,4);
fprintf('  Specs EXCLUIDAS (evidencia, no en tabla): %s\n\n', strjoin(spec_names_excluded, ', '));

% Specs cuyo cache NO es confiable (Cfg.PRIOR cambio in-place tras el
% commit de este chat: psi 0.97->0.90) -- se fuerza recalculo ignorando
% el cache existente, sin importar su ND. El chequeo cache-first normal
% (solo compara ND) no detecta este tipo de cambio -- ver hallazgo de
% diagnose_erpt12_niwcustom_cache_integrity.m con mm_minn/lambda1.
FORCE_RECOMPUTE = { ...
    'spec_A_base_mm_niwcustom_lag2_v0', 'spec_A_base_mm_niwcustom_lag4_v0', ...
    'spec_A_rob_mm_niwcustom_lag2_v0',  'spec_A_rob_mm_niwcustom_lag4_v0'  };

fprintf('  Specs con recalculo FORZADO (cache invalidado por cambio de psi): %s\n\n', ...
    strjoin(FORCE_RECOMPUTE, ', '));

% =========================================================================
%  BLOQUE 0 -- Regresion BNW IS (sanity -- este chat no toca el core)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 0 -- Regresion BNW IS (spec_bnw_is), ND completo\n');
fprintf('======================================================\n\n');

if RUN_BNW_CHECK
    clear Cfg;
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
    val_ib = Ltilde_bnw(end, end, end, end);
    REF_ib = 0.2041864191;
    ok_ib  = abs(val_ib - REF_ib) <= TOL_irf;

    fprintf('  Ltilde(end,end,end,end) = %.10f   (ref %.10f)   %s\n', val_ib, REF_ib, V{int32(ok_ib)+1});
    fprintf('  ne efectivo             = %d\n\n', Results_bnw.ne);

    bloque0_pasa = ok_ib;
    if bloque0_pasa
        fprintf('  >> BLOQUE 0: PASA -- baseline BNW intacto.\n\n');
    else
        fprintf('  >> BLOQUE 0: NO PASA -- detener y revisar antes de continuar.\n\n');
    end
else
    bloque0_pasa = true;
    fprintf('  [OMITIDO] RUN_BNW_CHECK=false.\n\n');
end

% =========================================================================
%  BLOQUE 1 -- Cargar (o correr si falta) las 16 specs oficiales
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- 16 specs oficiales (cache-first)\n');
fprintf('======================================================\n\n');

bloque1_ok      = true;
bloque1_msgs    = {};
warn_low_ne     = {};
cache_status    = {};   % 'cache' | 'recalculado'
Results_by_spec = struct();
Dataset_by_spec = struct();
Cfg_by_spec     = struct();
ERPT_by_spec    = struct();

for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};
    fprintf('------------------------------------------------------\n');
    fprintf('  [%2d/16] Spec: %s\n', ss, spec_name);
    fprintf('------------------------------------------------------\n');

    if contains(spec_name, '_aa_')
        transform_type = 'aa';
    else
        transform_type = 'mm';
    end

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;

    cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
    used_cache = false;
    force_recompute_this = ismember(spec_name, FORCE_RECOMPUTE);

    if force_recompute_this
        fprintf('  [FORCE_RECOMPUTE] cache invalidado por cambio de Cfg.PRIOR -- recalculando desde cero.\n');
    end

    if USE_CACHE && ~force_recompute_this && isfile(cache_path)
        try
            [Results_spec, ERPT_spec, Dataset_spec, Cfg_cached] = load_erpt_run(Cfg.OUTPUT_DIR);
            nd_cached = NaN;
            if isfield(Cfg_cached, 'ND'), nd_cached = Cfg_cached.ND; end
            if ~isnan(nd_cached) && nd_cached >= ND_DEFAULT
                used_cache = true;
                Cfg = Cfg_cached;
                fprintf('  [cache] ND=%g, ne=%d\n', nd_cached, Results_spec.ne);
            else
                fprintf('  [cache] ND cacheado (%g) < objetivo (%g) -> re-estimando.\n', nd_cached, ND_DEFAULT);
            end
        catch ME
            fprintf('  [ALERTA] No se pudo cargar cache (%s) -- re-estimando desde cero.\n', ME.message);
        end
    end

    if ~used_cache
        Cfg.ND = ND_DEFAULT;
        fprintf('  Dataset: cargando %s (transform=%s)...\n', Cfg.DATA_FILE, transform_type);
        Dataset_spec = load_data(Cfg);
        validate_cfg(Cfg, Dataset_spec);
        Posterior_spec = build_posterior(Dataset_spec, Cfg);

        fprintf('  Corriendo IS (nd=%g, CIENTIFICO -- varios minutos)...\n', Cfg.ND);
        rng('default'); rng(Cfg.SEED);
        tic;
        Results_spec = run_is(Posterior_spec, Cfg);
        Results_spec.t_elapsed = toc;
        fprintf('  Tiempo: %.1f seg | ne=%d\n', Results_spec.t_elapsed, Results_spec.ne);

        try
            ERPT_spec = calculate_erpt(Results_spec, Dataset_spec, Cfg, transform_type);
        catch ME
            bloque1_ok = false;
            bloque1_msgs{end+1} = sprintf('%s: ERROR en calculate_erpt: %s', spec_name, ME.message); %#ok<AGROW>
            fprintf('  [ERROR] %s\n\n', ME.message);
            continue;
        end

        save_erpt_run(Results_spec, ERPT_spec, Dataset_spec, Cfg);
        cache_status{end+1} = sprintf('%s: recalculado', spec_name); %#ok<AGROW>
    else
        cache_status{end+1} = sprintf('%s: cache', spec_name); %#ok<AGROW>
    end

    % -- Checks estructurales --------------------------------------------
    n_shocks_out = numel(ERPT_spec.shocks);
    if n_shocks_out ~= Dataset_spec.nvar
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: se esperaban %d choques, se obtuvieron %d', ...
            spec_name, Dataset_spec.nvar, n_shocks_out); %#ok<AGROW>
    end
    names_out = {ERPT_spec.shocks.name};
    if ~all(ismember(NAMED_SHOCKS, names_out))
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: faltan choques nombrados', spec_name); %#ok<AGROW>
    end
    if Results_spec.ne <= 0
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: ne=%d (sin draws efectivos)', spec_name, Results_spec.ne); %#ok<AGROW>
    end
    if Results_spec.ne > 0 && Results_spec.ne < NE_WARN_THRESHOLD
        warn_low_ne{end+1} = sprintf('%s (ne=%d)', spec_name, Results_spec.ne); %#ok<AGROW>
    end

    Results_by_spec.(spec_name) = Results_spec;
    Dataset_by_spec.(spec_name) = Dataset_spec;
    Cfg_by_spec.(spec_name)     = Cfg;
    ERPT_by_spec.(spec_name)    = ERPT_spec;

    fprintf('\n');
end

if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- las 16 specs oficiales cargadas/corridas.\n');
else
    fprintf('  >> BLOQUE 1: NO PASA. Detalle:\n');
    for i = 1:numel(bloque1_msgs)
        fprintf('     - %s\n', bloque1_msgs{i});
    end
end
if ~isempty(warn_low_ne)
    fprintf('\n  [ADVERTENCIA] ne < %d en %d spec(s) -- BANDAS INDICATIVAS:\n', NE_WARN_THRESHOLD, numel(warn_low_ne));
    for i = 1:numel(warn_low_ne)
        fprintf('     - %s\n', warn_low_ne{i});
    end
end
fprintf('\n');

% =========================================================================
%  BLOQUE 2 -- Tabla comparativa maestra (ancha + larga) + Excel
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Tabla maestra (16 specs, mm_niwcustom x mm_minn)\n');
fprintf('======================================================\n\n');

bloque2_ok = true;
T_erpt = table(); T_long = table(); T_diag = table();
try
    [T_erpt, T_diag] = build_erpt_comparison(ERPT_by_spec, Results_by_spec, Cfg_by_spec, spec_names, NAMED_SHOCKS);
    T_long           = build_erpt_comparison_long(ERPT_by_spec, spec_names, NAMED_SHOCKS);
catch ME
    bloque2_ok = false;
    fprintf('  [ERROR] construccion de tablas fallo: %s\n\n', ME.message);
end

if bloque2_ok
    fprintf('  --- Diagnosticos de corrida por spec (T_diag) ---\n');
    disp(T_diag);

    hz_list = unique(T_long.horizon, 'stable');
    if ~ismember(FOCUS_HORIZON, hz_list)
        FOCUS_HORIZON = hz_list(end);
    end
    fprintf('  --- Digesto: mediana ERPT | price_var=%s | horizonte=%d ---\n', FOCUS_PRICE_VAR, FOCUS_HORIZON);
    fprintf('  %-32s', 'spec');
    for kk = 1:numel(NAMED_SHOCKS)
        fprintf('  %8s', NAMED_SHOCKS{kk});
    end
    fprintf('\n');
    for ss = 1:numel(spec_names)
        sn = spec_names{ss};
        fprintf('  %-32s', sn);
        for kk = 1:numel(NAMED_SHOCKS)
            mask = strcmp(T_long.spec, sn) & strcmp(T_long.shock, NAMED_SHOCKS{kk}) & ...
                   strcmp(T_long.price_var, FOCUS_PRICE_VAR) & (T_long.horizon == FOCUS_HORIZON);
            v = T_long.median(mask);
            if isempty(v)
                fprintf('  %8s', 'n/a');
            else
                fprintf('  %8.3f', v(1));
            end
        end
        fprintf('\n');
    end
    fprintf('\n');

    % -- Exportar a Excel (3 hojas). Nombre distinto del A16_noMon de Chat 9
    %    para no sobreescribir esa referencia -- este es el estado final
    %    tras el reemplazo mm_minn -> mm_niwcustom.
    comparison_dir = fullfile(PROJ_ROOT, 'output', 'comparison');
    if ~isfolder(comparison_dir), mkdir(comparison_dir); end
    xlsx_path = fullfile(comparison_dir, 'erpt_comparison_A16_final.xlsx');
    if isfile(xlsx_path), delete(xlsx_path); end
    writetable(T_erpt, xlsx_path, 'Sheet', 'erpt_comparison');
    writetable(T_long, xlsx_path, 'Sheet', 'erpt_long');
    writetable(T_diag, xlsx_path, 'Sheet', 'run_diagnostics');
    fprintf('  Tabla comparativa exportada (3 hojas) a:\n    %s\n\n', xlsx_path);

    fprintf('  >> BLOQUE 2: PASA.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA.\n\n');
end

% =========================================================================
%  BLOQUE 3 -- Casos de error esperados
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Casos de error esperados\n');
fprintf('======================================================\n\n');

bloque3_ok   = true;
bloque3_msgs = {};

% Caso 1: spec_names con un nombre inexistente (control de que la lista
% oficial de 16 se valida contra ERPT_by_spec real, no solo se asume).
try
    bad_names = spec_names;
    bad_names{1} = 'spec_A_base_mm_minn_lag2_v0';   % excluido, no deberia estar en ERPT_by_spec
    build_erpt_comparison(ERPT_by_spec, Results_by_spec, Cfg_by_spec, bad_names, NAMED_SHOCKS);
    bloque3_ok = false; bloque3_msgs{end+1} = 'spec excluida (mm_minn) en la lista: NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] spec excluida no genero error\n');
catch ME
    fprintf('  [OK] spec excluida (mm_minn) en spec_names -> error esperado: %s\n', ME.identifier);
end

% Caso 2: choque inexistente
try
    build_erpt_comparison(ERPT_by_spec, Results_by_spec, Cfg_by_spec, spec_names, {'Cam', 'Mon'});
    bloque3_ok = false; bloque3_msgs{end+1} = 'choque inexistente: NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] choque inexistente no genero error\n');
catch ME
    fprintf('  [OK] choque inexistente (Mon) -> error esperado: %s\n', ME.identifier);
end

% Caso 3: horizontes distintos entre specs
try
    ERPT_bad = ERPT_by_spec;
    fn1 = spec_names{1};
    ERPT_bad.(fn1).horizons = ERPT_bad.(fn1).horizons(1:end-1);
    build_erpt_comparison(ERPT_bad, Results_by_spec, Cfg_by_spec, spec_names, NAMED_SHOCKS);
    bloque3_ok = false; bloque3_msgs{end+1} = 'horizontes distintos: NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] horizontes distintos no genero error\n');
catch ME
    fprintf('  [OK] horizontes distintos -> error esperado: %s\n', ME.identifier);
end

fprintf('\n');
if bloque3_ok
    fprintf('  >> BLOQUE 3: PASA.\n\n');
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
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 12\n');
fprintf('======================================================\n');
fprintf('  Bloque 0 (Regresion BNW IS)                 : %s\n', iif_local(bloque0_pasa, 'PASA', 'NO PASA'));
fprintf('  Bloque 1 (16 specs oficiales, cache-first)  : %s\n', iif_local(bloque1_ok,   'PASA', 'NO PASA'));
fprintf('  Bloque 2 (Tabla maestra + Excel)             : %s\n', iif_local(bloque2_ok,   'PASA', 'NO PASA'));
fprintf('  Bloque 3 (Casos de error)                    : %s\n', iif_local(bloque3_ok,   'PASA', 'NO PASA'));
fprintf('------------------------------------------------------\n');
if bloque0_pasa && bloque1_ok && bloque2_ok && bloque3_ok
    fprintf('  GLOBAL : PASA\n');
    if ~isempty(warn_low_ne)
        fprintf('  (con %d spec(s) en BANDAS INDICATIVAS por ne bajo -- ver arriba)\n', numel(warn_low_ne));
    end
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% -- Helper local ------------------------------------------------------
function out = iif_local(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
