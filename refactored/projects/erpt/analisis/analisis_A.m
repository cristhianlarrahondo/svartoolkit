% analisis_A.m -- Pass-through, especificacion GANADORA (Ejercicio A, Colombia)
%   Sistema core de 6 variables {ner, imp_inf, pro_inf, con_inf, ea, ir}.
%   El barrido de 16 specs vive en validate_erpt15/16 (maquinaria), no aqui;
%   el do-file de robustez de A vive en analisis_A_robustez.m (ERPT-Chat 22).
%   Requisito: correr iniciar.m UNA VEZ en la sesion.
%   Referencia ERPT a h=3 (mediana): importados ~0.49 | productor ~0.16 | consumidor ~0.03
%
%   ERPT-Chat 22: banda unica 68% en todo el reporte (Tabla ERPT, Figura 1
%   -- ERPT-Chat 21 decision 1); choques mostrados restringidos a los 3
%   nombrados Cam/Dem/Ofe (loose end de ERPT-Chat 20); CIRF generica
%   (cumsum) retirada "sin excepcion, ni siquiera como anexo" (ERPT-Chat 21
%   decision 2). Figura 2 (nivel L(h)) se implemento y luego se DESCARTO
%   dentro de este mismo chat, tras revisar la figura resultante: el
%   objeto exhibe un patron de "diente de sierra" period-12 -- real,
%   matematicamente correcto dado que la recursion reconstruye un nivel
%   mensual a partir de un SVAR estimado directamente sobre a/a (no sobre
%   niveles mensuales), pero el usuario decidio no incluirla en el reporte.
%   No queda reemplazo de la CIRF: el reporte de A queda con Tabla ERPT +
%   Figura 1 + FEVD unicamente.

%% PASO 0 -- Botones (edita aqui)
spec       = 'spec_A_rob_aa_diffuse_lag4_v0';         % ganadora del barrido
bandas     = [0.16 0.84];                             % 68% -- banda unica de reporte (Chat 21)
usar_cache = true;
shocks     = {'Exchange Rate','Demand','Supply'};                     % choques nombrados
precio     = {'imp_inf','pro_inf','con_inf'};         % las 3 inflaciones del sistema

%% PASO 1 -- Cargar especificacion y datos
Cfg = cargar_spec(spec);
Cfg.SHOCK_IDX = 1:3;                 % restringe wrappers a Cam/Dem/Ofe (Chat 20, loose end)
Cfg.RESP_IDX  = [2 3 4];             % Figura 1: solo las 3 inflaciones (imp_inf,pro_inf,con_inf)
Cfg.IRF_TYPE  = 'irf';               % sin CIRF generica (retirada, Chat 21 decision 2)
fprintf('\n=== Ejercicio A (ganadora) | spec: %s ===\n', spec);

% -- Limpiar figuras cirf_*.png (retirada, Chat 21 decision 2) y
%    nivel_*.png (Figura 2, implementada y luego descartada en este mismo
%    chat -- ver nota de cabecera) de corridas anteriores: no deben quedar
%    archivos viejos en disco que puedan colarse por error a la carpeta
%    del paper.
old_fig_dir = fullfile(Cfg.OUTPUT_DIR, 'figures');
old_stale = [dir(fullfile(old_fig_dir, 'cirf_*.png')); dir(fullfile(old_fig_dir, 'nivel_*.png'))];
for kk = 1:numel(old_stale)
    delete(fullfile(old_stale(kk).folder, old_stale(kk).name));
end
if ~isempty(old_stale)
    fprintf('  [limpieza] %d figura(s) retirada(s) (cirf_*/nivel_*) de %s\n\n', numel(old_stale), old_fig_dir);
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
%             cacheados -- Cfg.CRED_BANDS de la spec es [0.25 0.75];
%             ERPT-Chat 21 decision 1 estandariza a [0.16 0.84] en TODO
%             el reporte). No re-estima nada -- calculate_erpt.m es puro
%             post-procesamiento sobre Results.LtildeStruct (ya en memoria
%             o ya cargado de cache).
Cfg.CRED_BANDS = bandas;
ERPT = calculate_erpt(Results, Dataset, Cfg, 'aa');

%% PASO 3 -- Exchange Rate Pass-Through (el resultado principal)
mostrar_erpt(ERPT, shocks, precio);

%% PASO 4 -- Respuestas al impulso (IRF, Figura 1)
mostrar_irf(Results, Dataset, Cfg, bandas);     % tabla IRF (Figura 1)
graficar_irf(Results, Dataset, Cfg, bandas);    % figura IRF (Figura 1: eje "p.p. of annual inflation", sin titulo general)

%% PASO 5 -- Descomposicion de varianza (FEVD, todas las variables/choques)
%   Cfg.RESP_IDX se restringio arriba SOLO para Figura 1 (IRF); FEVD debe
%   cubrir TODAS las variables endogenas (decision de ERPT-Chat 16, bug
%   ya documentado alli) -- se usa una copia de Cfg sin RESP_IDX.
Cfg_fevd = Cfg;
Cfg_fevd.RESP_IDX = [];
graficar_fevd(Results, Dataset, Cfg_fevd);
