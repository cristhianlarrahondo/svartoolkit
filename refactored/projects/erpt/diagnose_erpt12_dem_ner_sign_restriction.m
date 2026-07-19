%DIAGNOSE_ERPT12_DEM_NER_SIGN_RESTRICTION  ERPT-Chat 12 -- smoke test de
%   agregar una restriccion de signo en `ner` para el choque Dem, siguiendo
%   Forbes, Hjortsoe & Nenova (2018): "positive demand shocks ... [an]
%   exchange rate appreciation".
%
%   *** CONFIRMAR ANTES DE CORRER ***
%   SIGN_NER_DEM abajo asume ner(+) = depreciacion (mas pesos por dolar),
%   inferido de que Cam (choque cambiario/prima de riesgo) ya usa ner(+)
%   como su propia restriccion -- un choque de aversion al riesgo
%   depreciaria la moneda, consistente con esa convencion. Bajo esa
%   convencion, "demanda -> apreciacion" (Forbes) = ner NEGATIVO.
%   Si la convencion real es la inversa (ner+ = apreciacion), cambiar
%   SIGN_NER_DEM a +1 antes de correr.
%
%   Alcance: SOLO agrega una fila a Cfg.S{2} (Dem) sobre var 1 (ner) EN
%   MEMORIA -- no modifica ningun archivo de spec ni el repo. Corre en
%   smoke (ND=3000) sobre mm_diffuse (base, lag2 y lag4) -- el mas limpio
%   de referencia, para aislar el efecto de la restriccion sin mezclarlo
%   con los problemas de prior ya diagnosticados en mm_minn/mm_niwcustom.
%   No toca build_posterior.m/run_is.m/run_pfa.m (Tipo S, exploratorio,
%   no forma parte del protocolo de cierre).
%
%   Ejecutar COMPLETO (F5). Pegar el output completo en el chat.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   DIAGNOSTICO ERPT-CHAT 12 -- restriccion ner en Dem\n');
fprintf('   (apreciacion bajo demanda, a la Forbes 2018)\n');
fprintf('======================================================\n\n');

%% -- Controles -- CONFIRMAR SIGN_NER_DEM antes de correr ------------------
ND_SMOKE     = 3000;
SIGN_NER_DEM = -1;   % ner(+)=depreciacion asumido -> apreciacion = -1
                     % CAMBIAR A +1 si en tu dataset ner(+) = apreciacion

FOCUS_HORIZON   = 36;
FOCUS_PRICE_VAR = 'con_inf';

fprintf('  ND_SMOKE     : %g\n', ND_SMOKE);
fprintf('  SIGN_NER_DEM : %+d  (%s)\n\n', SIGN_NER_DEM, ...
    iif_local(SIGN_NER_DEM < 0, 'asume ner(+)=depreciacion -> se impone apreciacion', ...
                                  'asume ner(+)=apreciacion -> se impone apreciacion directamente'));

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

% Solo mm_diffuse (base) -- referencia mas limpia, lag2 y lag4. rob
% comparte forma reducida con base (confirmado en diagnosticos previos),
% asi que no aporta informacion nueva sobre el EFECTO DE LA RESTRICCION
% en si (que es sobre la identificacion, no sobre la dinamica reducida).
test_specs  = {'spec_A_base_mm_diffuse_lag2_v0', 'spec_A_base_mm_diffuse_lag4_v0'};
test_labels = {'lag2', 'lag4'};

NAMED_SHOCKS = {'Cam', 'Dem', 'Ofe'};

for ss = 1:numel(test_specs)
    spec_name = test_specs{ss};
    fprintf('======================================================\n');
    fprintf('  Spec base: %s (%s)\n', spec_name, test_labels{ss});
    fprintf('======================================================\n\n');

    % -- (A) Corrida SIN la restriccion nueva (baseline de comparacion) --
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS = false; Cfg.SAVE_RESULTS = false; Cfg.ND = ND_SMOKE;

    fprintf('  --- (A) SIN restriccion nueva (baseline, smoke ND=%g) ---\n', ND_SMOKE);
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

    % -- (B) Corrida CON la restriccion nueva en Cfg.S{2} (Dem) ----------
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS = false; Cfg.SAVE_RESULTS = false; Cfg.ND = ND_SMOKE;

    n_vars     = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));
    n_horizons = numel(Cfg.HORIZONS_RESTRICT);
    ner_row    = build_restriction_row(1, 1, n_vars, n_horizons, SIGN_NER_DEM);   % var 1 = ner
    Cfg.S{2}   = [Cfg.S{2}; ner_row];   % se agrega a las 3 filas existentes (pro+,con+,ea+)

    fprintf('  --- (B) CON ner(%+d) agregado a Cfg.S{2} (Dem), smoke ND=%g ---\n', SIGN_NER_DEM, ND_SMOKE);
    Dataset_B = load_data(Cfg);
    validate_cfg(Cfg, Dataset_B);
    Posterior_B = build_posterior(Dataset_B, Cfg);
    rng('default'); rng(Cfg.SEED);
    Results_B = run_is(Posterior_B, Cfg);
    fprintf('  ne=%d  (vs. ne=%d sin la restriccion -- ne mas bajo es esperado: el conjunto\n', Results_B.ne, Results_A.ne);
    fprintf('  admisible se redujo al agregar una restriccion mas sobre el mismo choque)\n');

    ERPT_B = calculate_erpt(Results_B, Dataset_B, Cfg, 'mm');
    med_B = p_get_median(ERPT_B, NAMED_SHOCKS, FOCUS_PRICE_VAR, FOCUS_HORIZON);
    fprintf('  Mediana %s h=%d:  Cam=%.3f  Dem=%.3f  Ofe=%.3f\n\n', ...
        FOCUS_PRICE_VAR, FOCUS_HORIZON, med_B(1), med_B(2), med_B(3));

    fprintf('  --- Comparacion (A) sin restriccion vs (B) con restriccion ---\n');
    fprintf('  %-8s  %10s  %10s\n', 'choque', 'sin_restr', 'con_restr');
    for kk = 1:numel(NAMED_SHOCKS)
        fprintf('  %-8s  %10.3f  %10.3f\n', NAMED_SHOCKS{kk}, med_A(kk), med_B(kk));
    end
    fprintf('\n  Lectura esperada: Cam y Ofe NO deberian cambiar (la restriccion solo\n');
    fprintf('  toca Cfg.S{2}=Dem). Dem deberia cambiar de signo/magnitud -- eso es\n');
    fprintf('  lo que estamos probando.\n\n');
end

fprintf('======================================================\n');
fprintf('Pegar este output completo en el chat.\n\n');


%% -- Helpers locales -------------------------------------------------------
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

function out = iif_local(cond, a, b)
    if cond, out = a; else, out = b; end
end
