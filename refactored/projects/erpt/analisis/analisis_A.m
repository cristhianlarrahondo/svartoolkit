% analisis_A.m -- Pass-through, especificacion GANADORA (Ejercicio A, Colombia)
%   Sistema core de 6 variables {ner, imp_inf, pro_inf, con_inf, ea, ir}.
%   El barrido de 16 specs vive en validate_erpt15/16 (maquinaria), no aqui;
%   el do-file de robustez de A vive en analisis_A_robustez.m (ERPT-Chat 22).
%   Requisito: correr iniciar.m UNA VEZ en la sesion.
%   Referencia ERPT a h=3 (mediana): importados ~0.49 | productor ~0.16 | consumidor ~0.03
%
%   ERPT-Chat 22: banda unica 68% en todo el reporte (Tabla ERPT, Figura 1,
%   Figura 2 -- ERPT-Chat 21 decision 1); choques mostrados restringidos a
%   los 3 nombrados Cam/Dem/Ofe (loose end de ERPT-Chat 20); CIRF generica
%   (cumsum) retirada sin reemplazo directo -- Figura 2 (nivel L(h)) la
%   sustituye para variables a/a (ERPT-Chat 21 decision 2).

%% PASO 0 -- Botones (edita aqui)
spec       = 'spec_A_rob_aa_diffuse_lag4_v0';         % ganadora del barrido
bandas     = [0.16 0.84];                             % 68% -- banda unica de reporte (Chat 21)
usar_cache = true;
shocks     = {'Cam','Dem','Ofe'};                     % choques nombrados
precio     = {'imp_inf','pro_inf','con_inf'};         % las 3 inflaciones del sistema

%% PASO 1 -- Cargar especificacion y datos
Cfg = cargar_spec(spec);
Cfg.SHOCK_IDX = 1:3;                 % restringe wrappers a Cam/Dem/Ofe (Chat 20, loose end)
Cfg.RESP_IDX  = [2 3 4];             % Figura 1: solo las 3 inflaciones (imp_inf,pro_inf,con_inf)
Cfg.IRF_TYPE  = 'irf';               % sin CIRF generica (retirada, Chat 21 decision 2)
fprintf('\n=== Ejercicio A (ganadora) | spec: %s ===\n', spec);

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
%             cacheados -- Cfg.CRED_BANDS de la spec es [0.25 0.75];
%             ERPT-Chat 21 decision 1 estandariza a [0.16 0.84] en TODO
%             el reporte). No re-estima nada -- calculate_erpt.m es puro
%             post-procesamiento sobre Results.LtildeStruct (ya en memoria
%             o ya cargado de cache).
Cfg.CRED_BANDS = bandas;
ERPT = calculate_erpt(Results, Dataset, Cfg, 'aa');

%% PASO 3 -- Exchange Rate Pass-Through (el resultado principal)
mostrar_erpt(ERPT, shocks, precio);

%% PASO 4 -- Respuestas al impulso (IRF, Figura 1) y nivel acumulado (Figura 2)
mostrar_irf(Results, Dataset, Cfg, bandas);     % tabla IRF (Figura 1)
graficar_irf(Results, Dataset, Cfg, bandas);    % figura IRF (Figura 1: eje "pp de inflacion anual")
mostrar_nivel(Results, Dataset, Cfg, bandas);   % tabla nivel L(h) (Figura 2)
graficar_nivel(Results, Dataset, Cfg, bandas);  % figura nivel L(h) (Figura 2, incluye panel ner)

%% PASO 5 -- Descomposicion de varianza (FEVD, todas las variables/choques)
graficar_fevd(Results, Dataset, Cfg);
