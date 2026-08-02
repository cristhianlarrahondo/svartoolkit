% analisis_B.m -- Robustez con Terminos de Intercambio (Ejercicio B, Colombia)
%   Ganadora de A + ToT como 7a variable endogena.
%   Requisito: correr iniciar.m UNA VEZ en la sesion.
%   Referencia: jerarquia imp>pro>con, cercana a la ganadora (Ejercicio A).
%
%   ERPT-Chat 22: banda unica 68% (ERPT-Chat 21 decision 1); choques
%   restringidos a Cam/Dem/Ofe; CIRF generica retirada, sin reemplazo --
%   Figura 2 (nivel L(h)) se implemento y luego se descarto en este mismo
%   chat (patron de "diente de sierra" real, ver nota en analisis_A.m).

%% PASO 0 -- Botones (edita aqui)
spec       = 'spec_B_rob_aa_diffuse_lag4_tot_v0';     % ganadora + ToT (7a variable)
bandas     = [0.16 0.84];                             % 68% -- banda unica de reporte (Chat 21)
usar_cache = true;
shocks     = {'Exchange Rate','Demand','Supply'};                     % choques nombrados
precio     = {'imp_inf','pro_inf','con_inf'};         % las 3 inflaciones del sistema

%% PASO 1 -- Cargar especificacion y datos
Cfg = cargar_spec(spec);
Cfg.SHOCK_IDX = 1:3;                 % restringe wrappers a Cam/Dem/Ofe (Chat 20, loose end)
Cfg.RESP_IDX  = [2 3 4];             % solo las 3 inflaciones (imp_inf,pro_inf,con_inf; ver spec_B: tot es var 7)
Cfg.IRF_TYPE  = 'irf';               % sin CIRF generica (retirada, Chat 21 decision 2)
fprintf('\n=== Ejercicio B (ToT) | spec: %s ===\n', spec);

% -- Limpiar figuras cirf_*.png (retirada) y nivel_*.png (Figura 2,
%    descartada -- ver nota en analisis_A.m) de corridas anteriores --
old_fig_dir = fullfile(Cfg.OUTPUT_DIR, 'figures');
old_stale = [dir(fullfile(old_fig_dir, 'cirf_*.png')); dir(fullfile(old_fig_dir, 'nivel_*.png'))];
for kk = 1:numel(old_stale)
    delete(fullfile(old_stale(kk).folder, old_stale(kk).name));
end
if ~isempty(old_stale)
    fprintf('  [limpieza] %d figura(s) retirada(s) (cirf_*/nivel_*) de %s\n\n', numel(old_stale), old_fig_dir);
end

% -- Limpiar el <SPEC_NAME>_erpt_table.xlsx suelto de la version anterior
%    (round 6): ahora es una hoja de <SPEC_NAME>_results.xlsx --
old_erpt_xlsx = fullfile(Cfg.OUTPUT_DIR, 'tables', [Cfg.SPEC_NAME, '_erpt_table.xlsx']);
if isfile(old_erpt_xlsx)
    delete(old_erpt_xlsx);
    fprintf('  [limpieza] archivo suelto retirado: %s\n\n', old_erpt_xlsx);
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

%% PASO 4 -- Respuestas al impulso (IRF)
mostrar_irf(Results, Dataset, Cfg, bandas);     % tabla IRF
graficar_irf(Results, Dataset, Cfg, bandas);    % figura IRF

%% PASO 5 -- Descomposicion de varianza (FEVD, todas las variables/choques)
%   Cfg.RESP_IDX se restringio arriba SOLO para Figura 1 (IRF); FEVD debe
%   cubrir TODAS las variables endogenas (decision de ERPT-Chat 16).
Cfg_fevd = Cfg;
Cfg_fevd.RESP_IDX = [];
graficar_fevd(Results, Dataset, Cfg_fevd);

%% PASO 6 -- Exportar TODO a un solo Excel (IRF + FEVD + Tabla ERPT)
%   Ver nota completa en analisis_A.m. UN solo archivo <SPEC_NAME>_results.xlsx
%   con hojas metadata/irf_summary/fevd_summary/run_diagnostics (export_results.m,
%   core) + erpt_summary (Tabla ERPT, agregada aparte al mismo archivo).
export_results(Results, Dataset, Cfg_fevd);

ERPT_by_spec_B = struct();
ERPT_by_spec_B.(spec) = ERPT;
T_erpt_B = build_erpt_comparison_long(ERPT_by_spec_B, {spec}, shocks);
results_xlsx_B = fullfile(Cfg.OUTPUT_DIR, 'tables', [Cfg.SPEC_NAME, '_results.xlsx']);
writetable(T_erpt_B, results_xlsx_B, 'Sheet', 'erpt_summary', 'WriteVariableNames', true);
fprintf('  Hoja erpt_summary agregada a: %s\n\n', results_xlsx_B);
