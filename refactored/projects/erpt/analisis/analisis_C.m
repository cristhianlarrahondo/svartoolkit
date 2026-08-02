% analisis_C.m -- Pass-through por tipo de inflacion (Ejercicio C, Colombia)
%   Sistema de 5 variables {ner, X_inf, ea, ir, tot}, uno por tipo de inflacion.
%   Requisito: correr iniciar.m UNA VEZ en la sesion.
%   Referencia ERPT a h=3 (mediana): importados ~0.58 | productor ~0.29 | consumidor ~0.07
%
%   ERPT-Chat 22: banda unica 68% (ERPT-Chat 21 decision 1); choques
%   restringidos a Cam/Dem/Ofe (u orden correspondiente por sistema);
%   CIRF generica retirada, sin reemplazo -- Figura 2 (nivel L(h)) se
%   implemento y luego se descarto en este mismo chat (ver nota en
%   analisis_A.m).

%% PASO 0 -- Botones (edita aqui)
if ~exist('inflacion', 'var') || isempty(inflacion)
    inflacion  = 'importados';        % 'importados' | 'productor' | 'consumidor'
end
% -- Permite que un llamador externo (p.ej. validate_erpt22.m, para correr
%    los 3 sistemas en un solo loop) preseteé `inflacion` ANTES de correr
%    este script; si no, el default de siempre es 'importados' (uso
%    manual normal: editar el boton de PASO 0 y correr por secciones/F5).
bandas     = [0.16 0.84];             % 68% -- banda unica de reporte (Chat 21)
usar_cache = true;                    % true = reusar estimacion previa si existe

% -- mapa: tipo de inflacion -> spec, choques (en orden) y variable de precio --
switch inflacion
    case 'importados'
        spec = 'spec_C_rob_aa_diffuse_lag4_imp_v0'; precio = {'imp_inf'}; shocks = {'Exchange Rate','Supply','Demand'};
    case 'productor'
        spec = 'spec_C_rob_aa_diffuse_lag4_pro_v0'; precio = {'pro_inf'}; shocks = {'Exchange Rate','Demand','Supply'};
    case 'consumidor'
        spec = 'spec_C_rob_aa_diffuse_lag4_con_v0'; precio = {'con_inf'}; shocks = {'Exchange Rate','Demand','Supply'};
    otherwise
        error('inflacion no valida. Usa: importados | productor | consumidor');
end

%% PASO 1 -- Cargar especificacion y datos
Cfg = cargar_spec(spec);
Cfg.SHOCK_IDX = 1:3;                 % restringe wrappers a los 3 choques nombrados (Chat 20, loose end)
Cfg.RESP_IDX  = 2;                   % solo la variable de precio del sistema (indice 2: ner=1,X_inf=2)
Cfg.IRF_TYPE  = 'irf';               % sin CIRF generica (retirada, Chat 21 decision 2)
fprintf('\n=== Ejercicio C | inflacion: %s | spec: %s ===\n', inflacion, spec);

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

ERPT_by_spec_C = struct();
ERPT_by_spec_C.(spec) = ERPT;
T_erpt_C = build_erpt_comparison_long(ERPT_by_spec_C, {spec}, shocks);
results_xlsx_C = fullfile(Cfg.OUTPUT_DIR, 'tables', [Cfg.SPEC_NAME, '_results.xlsx']);
writetable(T_erpt_C, results_xlsx_C, 'Sheet', 'erpt_summary', 'WriteVariableNames', true);
fprintf('  Hoja erpt_summary agregada a: %s\n\n', results_xlsx_C);
