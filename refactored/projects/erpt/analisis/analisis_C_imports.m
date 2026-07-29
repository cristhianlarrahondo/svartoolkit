% analisis_C_imports.m -- Pass-through a inflacion de IMPORTADOS (Colombia)
%   Ejercicio C: sistema de 5 variables {ner, imp_inf, ea, ir, tot}.
%   Requisito: haber corrido iniciar.m UNA VEZ en esta sesion.
%   Correr por secciones (Ctrl+Enter) o completo (F5).

%% PASO 0 -- Botones (edita aqui)
spec       = 'spec_C_rob_aa_diffuse_lag4_imp_v0';   % especificacion a estimar
bandas     = [0.16 0.84; 0.05 0.95];                % bandas 68% y 90% para IRF/CIRF
usar_cache = true;                                   % true = reusar estimacion previa si existe

%% PASO 1 -- Cargar especificacion y datos
Cfg = cargar_spec(spec);          % trae variables, rezagos, restricciones y semilla
fprintf('Spec cargada: %s\n', spec);

%% PASO 2 -- Estimar el SVAR bayesiano (o cargar si ya se estimo)
cache = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
if usar_cache && exist(cache, 'file')
    [Results, ERPT, Dataset] = load_erpt_run(Cfg.OUTPUT_DIR);   % carga rapida
else
    Dataset   = load_data(Cfg);
    Posterior = build_posterior(Dataset, Cfg);
    rng('default'); rng(Cfg.SEED);                 % reproducible
    Results   = run_is(Posterior, Cfg);            % importance sampling (ARW 2018)
    ERPT      = calculate_erpt(Results, Dataset, Cfg, 'aa');
    save_erpt_run(Results, ERPT, Dataset, Cfg);    % guarda para la proxima
end

%% PASO 3 -- Respuestas al impulso (IRF y IRF acumulada)
Cfg_show            = Cfg;
Cfg_show.CRED_BANDS = bandas;
print_summary(Results.LtildeStruct, Dataset, Cfg_show);            % tabla IRF en consola
erpt_print_cirf_digest(Results.LtildeStruct, Dataset, Cfg_show);   % tabla IRF acumulada (CIRF)
plot_irfs(Results.LtildeStruct, Dataset, Cfg_show, Results);       % figuras IRF/CIRF

%% PASO 4 -- Exchange Rate Pass-Through (ERPT)
erpt_print_erpt_digest(ERPT, {'Cam','Ofe','Dem'}, {'imp_inf'});    % ERPT por horizonte y shock

%% PASO 5 -- Descomposicion de varianza (FEVD)
plot_fevd(Results, Dataset, Cfg);
