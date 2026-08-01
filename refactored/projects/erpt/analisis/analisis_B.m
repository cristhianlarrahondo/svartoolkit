% analisis_B.m -- Robustez con Terminos de Intercambio (Ejercicio B, Colombia)
%   Ganadora de A + ToT como 7a variable endogena.
%   Requisito: correr iniciar.m UNA VEZ en la sesion.
%   Referencia: jerarquia imp>pro>con, cercana a la ganadora (Ejercicio A).

%% PASO 0 -- Botones (edita aqui)
spec       = 'spec_B_rob_aa_diffuse_lag4_tot_v0';     % ganadora + ToT (7a variable)
bandas     = [0.16 0.84; 0.05 0.95];                  % 68% y 90% para IRF/CIRF
usar_cache = true;
shocks     = {'Cam','Dem','Ofe'};                     % choques nombrados
precio     = {'imp_inf','pro_inf','con_inf'};         % las 3 inflaciones del sistema

%% PASO 1 -- Cargar especificacion y datos
Cfg = cargar_spec(spec);
fprintf('\n=== Ejercicio B (ToT) | spec: %s ===\n', spec);

%% PASO 2 -- Estimar el SVAR bayesiano (o cargar si ya se estimo)
cache = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
if usar_cache && exist(cache, 'file')
    [Results, ERPT, Dataset] = load_erpt_run(Cfg.OUTPUT_DIR);
    origen = 'cargado de cache';
else
    Dataset   = load_data(Cfg);
    Posterior = build_posterior(Dataset, Cfg);
    rng('default'); rng(Cfg.SEED);            % reproducible
    Results   = run_is(Posterior, Cfg);       % importance sampling (ARW 2018)
    ERPT      = calculate_erpt(Results, Dataset, Cfg, 'aa');
    save_erpt_run(Results, ERPT, Dataset, Cfg);
    origen = 'estimado desde cero';
end
fprintf('   >> %s | ne (draws efectivos) = %d\n\n', origen, Results.ne);

%% PASO 3 -- Exchange Rate Pass-Through (el resultado principal)
mostrar_erpt(ERPT, shocks, precio);

%% PASO 4 -- Respuestas al impulso (IRF y IRF acumulada)
mostrar_irf(Results, Dataset, Cfg, bandas);     % tabla IRF
mostrar_cirf(Results, Dataset, Cfg, bandas);    % tabla IRF acumulada (CIRF)
graficar_irf(Results, Dataset, Cfg, bandas);    % figuras

%% PASO 5 -- Descomposicion de varianza (FEVD)
graficar_fevd(Results, Dataset, Cfg);
