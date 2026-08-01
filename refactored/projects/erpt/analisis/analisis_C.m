% analisis_C.m -- Pass-through por tipo de inflacion (Ejercicio C, Colombia)
%   Sistema de 5 variables {ner, X_inf, ea, ir, tot}, uno por tipo de inflacion.
%   Requisito: correr iniciar.m UNA VEZ en la sesion.
%   Referencia ERPT a h=3 (mediana): importados ~0.58 | productor ~0.29 | consumidor ~0.07

%% PASO 0 -- Botones (edita aqui)
inflacion  = 'importados';            % 'importados' | 'productor' | 'consumidor'
bandas     = [0.16 0.84; 0.05 0.95];  % 68% y 90% para IRF/CIRF
usar_cache = true;                    % true = reusar estimacion previa si existe

% -- mapa: tipo de inflacion -> spec, choques (en orden) y variable de precio --
switch inflacion
    case 'importados'
        spec = 'spec_C_rob_aa_diffuse_lag4_imp_v0'; precio = {'imp_inf'}; shocks = {'Cam','Ofe','Dem'};
    case 'productor'
        spec = 'spec_C_rob_aa_diffuse_lag4_pro_v0'; precio = {'pro_inf'}; shocks = {'Cam','Dem','Ofe'};
    case 'consumidor'
        spec = 'spec_C_rob_aa_diffuse_lag4_con_v0'; precio = {'con_inf'}; shocks = {'Cam','Dem','Ofe'};
    otherwise
        error('inflacion no valida. Usa: importados | productor | consumidor');
end

%% PASO 1 -- Cargar especificacion y datos
Cfg = cargar_spec(spec);
fprintf('\n=== Ejercicio C | inflacion: %s | spec: %s ===\n', inflacion, spec);

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
