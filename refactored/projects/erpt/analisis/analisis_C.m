% analisis_C.m -- Pass-through por tipo de inflacion (Ejercicio C, Colombia)
%   Sistema de 5 variables {ner, X_inf, ea, ir, tot}, uno por tipo de inflacion.
%   Requisito: correr iniciar.m UNA VEZ en la sesion.
%   Referencia ERPT a h=3 (mediana): importados ~0.58 | productor ~0.29 | consumidor ~0.07
%
%   ERPT-Chat 22: banda unica 68% (ERPT-Chat 21 decision 1); choques
%   restringidos a Cam/Dem/Ofe (u orden correspondiente por sistema);
%   CIRF generica retirada, reemplazada por Figura 2 (nivel L(h)).

%% PASO 0 -- Botones (edita aqui)
inflacion  = 'importados';            % 'importados' | 'productor' | 'consumidor'
bandas     = [0.16 0.84];             % 68% -- banda unica de reporte (Chat 21)
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
Cfg.SHOCK_IDX = 1:3;                 % restringe wrappers a los 3 choques nombrados (Chat 20, loose end)
Cfg.RESP_IDX  = 2;                   % solo la variable de precio del sistema (indice 2: ner=1,X_inf=2)
Cfg.IRF_TYPE  = 'irf';               % sin CIRF generica (retirada, Chat 21 decision 2)
fprintf('\n=== Ejercicio C | inflacion: %s | spec: %s ===\n', inflacion, spec);

% -- Limpiar figuras cirf_*.png de corridas anteriores (pre-Chat 22) --
old_cirf_dir = fullfile(Cfg.OUTPUT_DIR, 'figures');
old_cirf = dir(fullfile(old_cirf_dir, 'cirf_*.png'));
for kk = 1:numel(old_cirf)
    delete(fullfile(old_cirf(kk).folder, old_cirf(kk).name));
end
if ~isempty(old_cirf)
    fprintf('  [limpieza] %d figura(s) cirf_*.png retirada(s) de %s\n\n', numel(old_cirf), old_cirf_dir);
end

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
mostrar_nivel(Results, Dataset, Cfg, bandas, [{'ner'}, precio]);   % tabla nivel L(h)
graficar_nivel(Results, Dataset, Cfg, bandas, [{'ner'}, precio]);  % figura nivel L(h) (incluye panel ner)

%% PASO 5 -- Descomposicion de varianza (FEVD, todas las variables/choques)
%   Cfg.RESP_IDX se restringio arriba SOLO para Figura 1 (IRF); FEVD debe
%   cubrir TODAS las variables endogenas (decision de ERPT-Chat 16).
Cfg_fevd = Cfg;
Cfg_fevd.RESP_IDX = [];
graficar_fevd(Results, Dataset, Cfg_fevd);
