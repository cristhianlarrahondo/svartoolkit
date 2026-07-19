%DIAGNOSE_ERPT12_NIWCUSTOM_MINN_NER_RESTRICTION_HORIZONS  ERPT-Chat 12 --
%   Diagnostico dirigido: aplica la restriccion de apreciacion en ner para
%   el choque Dem (evidencia de Rincon-Castro, Rodriguez-Nino & Castro-
%   Pantoja 2017, Banco de la Republica, Borradores de Economia 982 --
%   restriccion acumulada al primer año, no solo al impacto) UNICAMENTE a
%   mm_niwcustom y mm_minn -- las dos familias donde el resultado libre da
%   el signo contrario al esperado. mm_diffuse/aa_diffuse/aa_minn NO se
%   tocan (ya dan el signo correcto sin necesidad de restriccion -- ver
%   discusion del chat).
%
%   Pregunta que responde: al combinar estos priors con la restriccion
%   economicamente correcta, ¿el ne colapsa (evidencia adicional de que el
%   prior favorece una region del conjunto identificado que la teoria
%   descarta) o sobrevive con una mediana corregida (evidencia de que el
%   prior no tenia disciplina, no que fuera incompatible)?
%
%   Cambio respecto al smoke test anterior (diagnose_erpt12_dem_ner_
%   sign_restriction.m): esa version solo restringia h=0 (impacto). Esta
%   version extiende Cfg.HORIZONS_RESTRICT a [0 3 6 12] (aprox. el primer
%   año, replicando el diseño de Rincon-Castro et al.) y repite la
%   restriccion de ner en los 4 horizontes para el choque Dem. Las demas
%   restricciones (Cam, Ofe, ceros de Cam) se mantienen SOLO en h=0, igual
%   que el diseño original -- no se extienden, para aislar el efecto de
%   extender unicamente la restriccion que estamos probando.
%
%   NO toca build_posterior.m/run_is.m ni ningun archivo de spec (Tipo S,
%   exploratorio, no forma parte del protocolo de cierre). Solo construye
%   Cfg en memoria.
%
%   Ejecutar COMPLETO (F5). Pegar el output completo en el chat.

%% -- Log a archivo -----------------------------------------------------
log_dir  = fullfile(fileparts(mfilename('fullpath')), 'output');
if ~isfolder(log_dir), mkdir(log_dir); end
log_path = fullfile(log_dir, 'diagnose_erpt12_niwcustom_minn_ner_restriction_horizons_log.txt');
if exist(log_path, 'file'), delete(log_path); end
diary(log_path);
diary on;
cleanup_diary = onCleanup(@() diary('off'));

fprintf('\n');
fprintf('======================================================\n');
fprintf('   DIAGNOSTICO ERPT-CHAT 12 -- restriccion ner en Dem\n');
fprintf('   multi-horizonte, dirigido a mm_niwcustom / mm_minn\n');
fprintf('======================================================\n\n');
fprintf('  [Output tambien guardado en: %s]\n\n', log_path);

%% -- Controles -------------------------------------------------------------
ND_SMOKE     = 3e4;
SIGN_NER_DEM = -1;              % ner(+)=depreciacion -> apreciacion = -1
DEM_HORIZONS = [0, 3, 6, 12];   % aprox. primer año (Rincon-Castro et al. 2017)

FOCUS_HORIZON   = 36;
FOCUS_PRICE_VAR = 'con_inf';
NAMED_SHOCKS    = {'Cam', 'Dem', 'Ofe'};

fprintf('  ND_SMOKE     : %g\n', ND_SMOKE);
fprintf('  SIGN_NER_DEM : %+d\n', SIGN_NER_DEM);
fprintf('  DEM_HORIZONS : %s\n\n', mat2str(DEM_HORIZONS));

%% -- Rutas -------------------------------------------------------------
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

% Solo specs "base" -- "rob" comparte forma reducida (confirmado en
% diagnosticos previos); la restriccion de identificacion SI puede diferir
% entre base/rob (son matrices de restricciones distintas), pero para este
% diagnostico dirigido (ne colapsa o no, con el prior como variable de
% interes) alcanza con "base" para ambas familias de prior.
test_specs = { ...
    'spec_A_base_mm_niwcustom_lag2_v0', 'spec_A_base_mm_niwcustom_lag4_v0', ...
    'spec_A_base_mm_minn_lag2_v0',      'spec_A_base_mm_minn_lag4_v0'       };

for ss = 1:numel(test_specs)
    spec_name = test_specs{ss};
    fprintf('======================================================\n');
    fprintf('  Spec: %s\n', spec_name);
    fprintf('======================================================\n\n');

    % -- (A) Baseline -- restricciones originales (solo h=0), sin cambios --
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS = false; Cfg.SAVE_RESULTS = false; Cfg.ND = ND_SMOKE;

    fprintf('  --- (A) Restricciones originales (ner libre en Dem, solo h=0) ---\n');
    Dataset_A = load_data(Cfg);
    validate_cfg(Cfg, Dataset_A);
    Posterior_A = build_posterior(Dataset_A, Cfg);
    rng('default'); rng(Cfg.SEED);
    Results_A = run_is(Posterior_A, Cfg);
    fprintf('  ne=%d\n', Results_A.ne);

    ERPT_A = calculate_erpt(Results_A, Dataset_A, Cfg, 'mm');
    med_A = p_get_median(ERPT_A, NAMED_SHOCKS, FOCUS_PRICE_VAR, FOCUS_HORIZON);
    fprintf('  Mediana %s h=%d:  Cam=%.3f  Dem=%.3f  Ofe=%.3f\n\n', ...
        FOCUS_PRICE_VAR, FOCUS_HORIZON, med_A(1), med_A(2), med_A(3));

    % -- (B) Restriccion de apreciacion en Dem, multi-horizonte (0,3,6,12) --
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS = false; Cfg.SAVE_RESULTS = false; Cfg.ND = ND_SMOKE;

    n_vars = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));
    Cfg.HORIZONS_RESTRICT = DEM_HORIZONS;
    n_horizons = numel(Cfg.HORIZONS_RESTRICT);

    % Reconstruccion completa de S/Z con la nueva dimensionalidad
    % (n_vars*n_horizons columnas). Restricciones originales (Cam, Dem
    % pro/con/ea, Ofe) SOLO en horizon_idx=1 (h=0) -- sin cambios de
    % diseño ahi. Unico agregado: ner en Dem, en LOS 4 horizontes.
    %   var 1=ner, 2=imp_inf, 3=pro_inf, 4=con_inf, 5=ea, 6=ir
    Cfg.Z = cell(n_vars, 1);
    Cfg.S = cell(n_vars, 1);

    % Shock 1: Cam -- ner(+) h=0; ea=0, ir=0 h=0 (sin cambios)
    Cfg.S{1} = build_restriction_row(1, 1, n_vars, n_horizons, 1);
    Cfg.Z{1} = [ build_restriction_row(5, 1, n_vars, n_horizons, 1); ...
                 build_restriction_row(6, 1, n_vars, n_horizons, 1) ];

    % Shock 2: Dem -- pro(+),con(+),ea(+) h=0 (sin cambios) + ner(SIGN_NER_DEM)
    % en LOS 4 horizontes de DEM_HORIZONS (agregado de este diagnostico)
    Cfg.S{2} = [ build_restriction_row(3, 1, n_vars, n_horizons,  1); ...
                 build_restriction_row(4, 1, n_vars, n_horizons,  1); ...
                 build_restriction_row(5, 1, n_vars, n_horizons,  1) ];
    for hh = 1:n_horizons
        Cfg.S{2} = [Cfg.S{2}; build_restriction_row(1, hh, n_vars, n_horizons, SIGN_NER_DEM)]; %#ok<AGROW>
    end
    Cfg.Z{2} = [];

    % Shock 3: Ofe -- pro(-),con(-),ea(+) h=0 (sin cambios, ner SIN restringir)
    Cfg.S{3} = [ build_restriction_row(3, 1, n_vars, n_horizons, -1); ...
                 build_restriction_row(4, 1, n_vars, n_horizons, -1); ...
                 build_restriction_row(5, 1, n_vars, n_horizons,  1) ];
    Cfg.Z{3} = [];

    % Shock 4: residual, sin restriccion (igual que el diseño original)
    Cfg.S{4} = [];
    Cfg.Z{4} = [];

    fprintf('  --- (B) ner(%+d) en Dem, horizontes %s (multi-horizonte) ---\n', ...
        SIGN_NER_DEM, mat2str(DEM_HORIZONS));
    try
        Dataset_B = load_data(Cfg);
        validate_cfg(Cfg, Dataset_B);
        Posterior_B = build_posterior(Dataset_B, Cfg);
        rng('default'); rng(Cfg.SEED);
        Results_B = run_is(Posterior_B, Cfg);
        fprintf('  ne=%d  (vs. ne=%d sin la restriccion)\n', Results_B.ne, Results_A.ne);

        if Results_B.ne > 0
            ERPT_B = calculate_erpt(Results_B, Dataset_B, Cfg, 'mm');
            med_B = p_get_median(ERPT_B, NAMED_SHOCKS, FOCUS_PRICE_VAR, FOCUS_HORIZON);
            fprintf('  Mediana %s h=%d:  Cam=%.3f  Dem=%.3f  Ofe=%.3f\n\n', ...
                FOCUS_PRICE_VAR, FOCUS_HORIZON, med_B(1), med_B(2), med_B(3));

            fprintf('  --- Comparacion (A) libre vs (B) con restriccion multi-horizonte ---\n');
            fprintf('  %-8s  %10s  %10s\n', 'choque', 'sin_restr', 'con_restr');
            for kk = 1:numel(NAMED_SHOCKS)
                fprintf('  %-8s  %10.3f  %10.3f\n', NAMED_SHOCKS{kk}, med_A(kk), med_B(kk));
            end
        else
            fprintf('  [ne=0] Ningun draw satisfizo todas las restricciones combinadas --\n');
            fprintf('  el prior de esta spec es incompatible con la region economicamente\n');
            fprintf('  esperada (apreciacion bajo demanda) dado este ND. Evidencia fuerte\n');
            fprintf('  de incompatibilidad prior x restriccion.\n');
        end
    catch ME
        fprintf('  [ERROR] %s\n', ME.message);
        fprintf('  (Un error aqui -- p.ej. run_is:noAcceptedDraws de CU-1 -- es en si\n');
        fprintf('   mismo evidencia de incompatibilidad total entre el prior y la\n');
        fprintf('   restriccion economicamente esperada.)\n');
    end
    fprintf('\n');
end

fprintf('======================================================\n');
fprintf('Pegar este output completo en el chat.\n');
fprintf('(o abrir y pegar: %s)\n\n', log_path);

diary off;


%% -- Helper local --------------------------------------------------------
function med = p_get_median(ERPT, shock_names, price_var, horizon)
    med = nan(1, numel(shock_names));
    hz_idx = find(ERPT.horizons == horizon, 1);
    if isempty(hz_idx)
        error('p_get_median:horizonNotFound', 'Horizonte %d no encontrado en ERPT.horizons.', horizon);
    end
    price_idx = find(strcmp(ERPT.price_vars, price_var), 1);
    if isempty(price_idx)
        error('p_get_median:priceVarNotFound', 'price_var %s no encontrada.', price_var);
    end
    shock_names_out = {ERPT.shocks.name};
    for kk = 1:numel(shock_names)
        s_idx = find(strcmp(shock_names_out, shock_names{kk}), 1);
        if isempty(s_idx), continue; end
        med(kk) = ERPT.shocks(s_idx).prices(price_idx).median(hz_idx);
    end
end
