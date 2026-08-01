% analisis_B.m -- Robustez con Terminos de Intercambio (Ejercicio B, Colombia)
%   Ganadora de A + ToT como 7a variable endogena.
%   Requisito: correr iniciar.m UNA VEZ en la sesion.
%   Referencia: jerarquia imp>pro>con, cercana a la ganadora (Ejercicio A).
%
%   ERPT-Chat 22: banda unica 68% (ERPT-Chat 21 decision 1); choques
%   restringidos a Cam/Dem/Ofe; CIRF generica retirada, reemplazada por
%   Figura 2 (nivel L(h), ERPT-Chat 21 decision 2).

%% PASO 0 -- Botones (edita aqui)
spec       = 'spec_B_rob_aa_diffuse_lag4_tot_v0';     % ganadora + ToT (7a variable)
bandas     = [0.16 0.84];                             % 68% -- banda unica de reporte (Chat 21)
usar_cache = true;
shocks     = {'Cam','Dem','Ofe'};                     % choques nombrados
precio     = {'imp_inf','pro_inf','con_inf'};         % las 3 inflaciones del sistema

%% PASO 1 -- Cargar especificacion y datos
Cfg = cargar_spec(spec);
Cfg.SHOCK_IDX = 1:3;                 % restringe wrappers a Cam/Dem/Ofe (Chat 20, loose end)
Cfg.RESP_IDX  = [2 3 4];             % solo las 3 inflaciones (imp_inf,pro_inf,con_inf; ver spec_B: tot es var 7)
Cfg.IRF_TYPE  = 'irf';               % sin CIRF generica (retirada, Chat 21 decision 2)
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

%% PASO 2.5 -- Recalcular ERPT a bandas 68% (post-proceso sobre draws ya
%             cacheados; ver nota en analisis_A.m).
Cfg.CRED_BANDS = bandas;
ERPT = calculate_erpt(Results, Dataset, Cfg, 'aa');

%% PASO 3 -- Exchange Rate Pass-Through (el resultado principal)
mostrar_erpt(ERPT, shocks, precio);

%% PASO 4 -- Respuestas al impulso (IRF) y nivel acumulado (Figura 2)
mostrar_irf(Results, Dataset, Cfg, bandas);     % tabla IRF
graficar_irf(Results, Dataset, Cfg, bandas);    % figura IRF
mostrar_nivel(Results, Dataset, Cfg, bandas);   % tabla nivel L(h)
graficar_nivel(Results, Dataset, Cfg, bandas);  % figura nivel L(h) (incluye panel ner)

%% PASO 5 -- Descomposicion de varianza (FEVD, todas las variables/choques)
graficar_fevd(Results, Dataset, Cfg);
