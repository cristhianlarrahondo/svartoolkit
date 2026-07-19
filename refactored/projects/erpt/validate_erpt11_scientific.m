%VALIDATE_ERPT11_SCIENTIFIC  ERPT-Chat 11 -- Opcion 4: corrida cientifica
%   (Cfg.ND=3e5, ver nota abajo) de las 8 specs del grupo mm_minn/mm_niwcustom,
%   tratando
%   ambas familias como una COMPARACION EXPLICITA de robustez frente a la
%   especificacion del prior (no se elige una y se descarta la otra):
%
%     - "Minnesota corregida" (4 specs, lambda1=0.2 -- D2-D4, ERPT-Chat 10):
%       shrinkage hacia RW exacto (media=1.0). Estabilidad de draws crudos
%       medida en smoke ~29-31%% -- bandas ERPT tratadas como INDICATIVAS
%       (ne bajo esperado, mismo espiritu del gate suave de ERPT-Chat 8).
%     - "niw_custom" (4 specs, psi_own_lag1=0.97 -- D5 + sensibilidad de
%       Opcion 3 de este chat): misma varianza de prior que Minnesota
%       corregida, media desplazada a 0.97. Estabilidad de draws crudos
%       medida en smoke ~88.7-97.5%% -- bandas ERPT con base mas solida.
%
%   Protocolo Tipo S (config-only; no toca build_posterior.m/run_is.m/
%   load_data.m). Cache ND-aware identico al patron de validate_erpt8.m:
%   una spec se reusa del cache solo si su ND cacheado >= ND objetivo,
%   asi que el cache previo (ND=3e5, con el lambda1=0.1 ROTO para
%   mm_minn, heredado de ERPT-Chat 9) se invalida automaticamente si se
%   sube el objetivo -- no hace falta borrar cache a mano.
%
%   -- Por que ND=3e5 y NO 3e6 -----------------------------------------------
%   El 3e6 aparecio originalmente en ERPT-Chat 8 como ND_OVERRIDES para
%   specs con ne<200 bajo la matriz CON el choque Mon (4 choques, mas
%   restricciones -> menor tasa de aceptacion). Esa pasada nunca se
%   ejecuto: en el mismo chat se removio Mon (ERPT-Chat 9), lo cual
%   mejoro la tasa de aceptacion 8-15x y dejo ne=1605-2828 a ND=3e5 (el
%   ESTANDAR del resto del Ejercicio A) sin necesidad de mas draws. Los 8
%   specs de este chat YA tienen Mon removido (3 choques nombrados) --
%   viven en el regimen post-Chat 9, no en el que motivo el 3e6. Ademas,
%   la tasa de aceptacion medida en el smoke de este chat (~1.1-1.3%)
%   escala linealmente a un ne proyectado de ~1500-2600 a ND=3e5,
%   consistente con el rango real de Chat 9. La inestabilidad de mm_minn
%   (30% vs 88-97% de niw_custom) es un problema del PRIOR, no de ND --
%   subir draws no lo resuelve, solo da mas precision a un ne que ya esta
%   bien a 3e5. Por eso ND_DEFAULT=3e5 aqui, con ND_OVERRIDES disponible
%   para subir puntualmente si alguna spec sale con ne bajo (mismo patron
%   de Chat 8), en vez de forzar 3e6 en las 8 de entrada.
%
%   Ejecutar COMPLETO (F5). Es RESUMIBLE: como en Chat 8, save_erpt_run se
%   llama por spec al terminar cada una.
%
%   -- Bloques ---------------------------------------------------------------
%   BLOQUE 1 -- Las 8 specs, corrida cientifica: load_data -> validate_cfg ->
%     build_posterior -> run_is (ND=3e5) -> calculate_erpt -> save_erpt_run.
%     Por spec, calcula tambien la fraccion de draws CRUDOS estables (misma
%     logica reimplementada localmente que en validate_erpt11.m/diagnose_
%     erpt11_niwcustom_sensitivity.m -- no se modifica check_stability.m).
%   BLOQUE 2 -- Tabla comparativa cruzada (ancha + larga, igual patron que
%     ERPT-Chat 8) + digesto por FAMILIA (Minnesota corregida vs
%     niw_custom) en el horizonte/price_var de foco + Excel de 4 hojas
%     (agrega una hoja "stability_by_family" a las 3 de Chat 8).

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 11 CIENTIFICO -- Opcion 4: 8 specs\n');
fprintf('   (Minnesota corregida vs niw_custom psi=0.97), ND=3e5\n');
fprintf('======================================================\n\n');

%% -- Controles de corrida (editar aqui) ------------------------------------
USE_CACHE       = true;      % true = reusar <OUTPUT_DIR>/results_is.mat si ND cacheado >= objetivo
ND_DEFAULT      = 3e5;       % ND objetivo (estandar del Ejercicio A -- ver nota "Por que
                              % ND=3e5 y NO 3e6" en la cabecera de este archivo)
NE_WARN_THRESHOLD = 200;     % ne por debajo de esto -> advertencia (no reprueba, gate suave
                              % igual que ERPT-Chat 8) -- senal para subir ND_OVERRIDES puntual
FOCUS_HORIZON   = 36;        % horizonte del digesto de consola
FOCUS_PRICE_VAR = 'con_inf'; % price_var del digesto de consola

% ND_OVERRIDES: subir ND objetivo de specs puntuales si su ne resulta bajo.
% Vacio por defecto -- la proyeccion (ne~1500-2600 a ND=3e5, ver cabecera)
% no anticipa necesidad de override, pero queda disponible si el ne real
% de alguna spec sale por debajo de NE_WARN_THRESHOLD.
ND_OVERRIDES = struct();

%% -- Rutas (F5 completo -> mfilename('fullpath') es confiable) -------------
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(PROJ_CFG);
addpath(PROJ_SRC);

fprintf('  REF_ROOT     : %s\n', REF_ROOT);
fprintf('  PROJ_ROOT    : %s\n', PROJ_ROOT);
fprintf('  USE_CACHE    : %d\n', USE_CACHE);
fprintf('  ND_DEFAULT   : %g\n\n', ND_DEFAULT);

V = {'FAIL', 'OK  '};

minn_specs = { ...
    'spec_A_base_mm_minn_lag2_v0', 'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_rob_mm_minn_lag2_v0',  'spec_A_rob_mm_minn_lag4_v0'  };

niwc_specs = { ...
    'spec_A_base_mm_niwcustom_lag2_v0', 'spec_A_base_mm_niwcustom_lag4_v0', ...
    'spec_A_rob_mm_niwcustom_lag2_v0',  'spec_A_rob_mm_niwcustom_lag4_v0'  };

spec_names   = [minn_specs, niwc_specs];
NAMED_SHOCKS = {'Cam', 'Dem', 'Ofe'};

% =========================================================================
%  BLOQUE 1 -- Las 8 specs, corrida cientifica (ND=3e5, cache ND-aware)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- 8 specs, ND=%g (cache ND-aware)\n', ND_DEFAULT);
fprintf('======================================================\n\n');

bloque1_ok      = true;
bloque1_msgs    = {};
warn_low_ne     = {};
Results_by_spec = struct();
Dataset_by_spec = struct();
Cfg_by_spec     = struct();
ERPT_by_spec    = struct();
frac_stable_by_spec = struct();

for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};
    fprintf('------------------------------------------------------\n');
    fprintf('  [%d/%d] Spec: %s\n', ss, numel(spec_names), spec_name);
    fprintf('------------------------------------------------------\n');

    % -- ND objetivo de esta spec (ND_DEFAULT salvo override) --------------
    nd_target = ND_DEFAULT;
    if isfield(ND_OVERRIDES, spec_name) && ~isempty(ND_OVERRIDES.(spec_name))
        nd_target = ND_OVERRIDES.(spec_name);
    end

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;
    Cfg.ND           = nd_target;

    transform_type = 'mm';   % las 8 specs de este chat son todas m/m

    cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
    used_cache = false;

    if USE_CACHE && isfile(cache_path)
        try
            [Results_spec, ERPT_spec, Dataset_spec, Cfg_cached] = load_erpt_run(Cfg.OUTPUT_DIR);
            nd_cached = NaN;
            if isfield(Cfg_cached, 'ND'), nd_cached = Cfg_cached.ND; end
            if ~isnan(nd_cached) && nd_cached >= nd_target
                used_cache = true;
                Cfg = Cfg_cached;
                fprintf('  [cache] ND cacheado (%g) >= objetivo (%g) -> reusando.\n', nd_cached, nd_target);
            else
                fprintf('  [cache] ND cacheado (%g) < objetivo (%g) -> re-estimando.\n', nd_cached, nd_target);
            end
        catch ME
            fprintf('  [ALERTA] No se pudo cargar cache (%s) -- re-estimando desde cero.\n', ME.message);
        end
    end

    if ~used_cache
        fprintf('  Dataset: cargando %s...\n', Cfg.DATA_FILE);
        Dataset_spec = load_data(Cfg);
        fprintf('  Dataset: %d endogenas, freq=%s, T=%d obs\n', ...
            Dataset_spec.nvar, Dataset_spec.freq, size(Dataset_spec.Y_raw, 1));

        validate_cfg(Cfg, Dataset_spec);
        Posterior_spec = build_posterior(Dataset_spec, Cfg);

        if isfield(Posterior_spec, 'ndummies') && Posterior_spec.ndummies ~= 2
            fprintf('  [ALERTA] se esperaban 2 dummies COVID, hay %d.\n', Posterior_spec.ndummies);
        end

        fprintf('  Corriendo IS (nd=%g, CIENTIFICO -- puede tomar bastante tiempo)...\n', Cfg.ND);
        rng('default'); rng(Cfg.SEED);
        tic;
        Results_spec = run_is(Posterior_spec, Cfg);
        Results_spec.t_elapsed = toc;
        fprintf('  Tiempo: %.1f seg | ne=%d | accept=%.4f%%\n', ...
            Results_spec.t_elapsed, Results_spec.ne, 100 * sum(Results_spec.uw > 0) / Cfg.ND);

        try
            ERPT_spec = calculate_erpt(Results_spec, Dataset_spec, Cfg, transform_type);
        catch ME
            bloque1_ok = false;
            bloque1_msgs{end+1} = sprintf('%s: ERROR en calculate_erpt: %s', spec_name, ME.message); %#ok<AGROW>
            fprintf('  [ERROR] %s\n\n', ME.message);
            continue;
        end

        save_erpt_run(Results_spec, ERPT_spec, Dataset_spec, Cfg);
    else
        fprintf('  ne=%d (desde cache, ND=%g)\n', Results_spec.ne, Cfg.ND);
    end

    % -- Checks estructurales (hard-fail) ----------------------------------
    names_out = {ERPT_spec.shocks.name};
    if ~all(ismember(NAMED_SHOCKS, names_out))
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: faltan choques nombrados (esperados %s; presentes %s)', ...
            spec_name, strjoin(NAMED_SHOCKS, '/'), strjoin(names_out, '/')); %#ok<AGROW>
    end
    if Results_spec.ne <= 0
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: ne=%d (sin draws efectivos)', spec_name, Results_spec.ne); %#ok<AGROW>
    end

    % -- Gate SUAVE de ne (advertencia, no fallo -- mismo patron Chat 8) ---
    if Results_spec.ne > 0 && Results_spec.ne < NE_WARN_THRESHOLD
        warn_low_ne{end+1} = sprintf('%s (ne=%d, ND=%g) -- considerar ND_OVERRIDES', ...
            spec_name, Results_spec.ne, Cfg.ND); %#ok<AGROW>
    end

    % -- Estabilidad sobre los ND draws crudos (candidatos, pre-resampling)
    try
        frac_stable_by_spec.(spec_name) = p_local_check_stability(Results_spec, Cfg);
    catch ME
        frac_stable_by_spec.(spec_name) = NaN;
        fprintf('  [ALERTA] no se pudo calcular estabilidad: %s\n', ME.message);
    end

    Results_by_spec.(spec_name) = Results_spec;
    Dataset_by_spec.(spec_name) = Dataset_spec;
    Cfg_by_spec.(spec_name)     = Cfg;
    ERPT_by_spec.(spec_name)    = ERPT_spec;

    fprintf('\n');
end

if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- las 8 specs corrieron (o cargaron del cache)\n');
    fprintf('     con ND objetivo y produjeron los 3 choques Cam/Dem/Ofe.\n\n');
else
    fprintf('  >> BLOQUE 1: NO PASA. Detalle:\n');
    for i = 1:numel(bloque1_msgs)
        fprintf('     - %s\n', bloque1_msgs{i});
    end
    fprintf('\n');
end
if ~isempty(warn_low_ne)
    fprintf('  [ADVERTENCIA] ne < %d en %d spec(s) -- considerar ND_OVERRIDES y re-F5:\n', ...
        NE_WARN_THRESHOLD, numel(warn_low_ne));
    for i = 1:numel(warn_low_ne)
        fprintf('     - %s\n', warn_low_ne{i});
    end
    fprintf('\n');
else
    fprintf('  ne >= %d en las 8 specs -- consistente con la proyeccion de la cabecera,\n', NE_WARN_THRESHOLD);
    fprintf('  ND=3e5 fue suficiente sin necesidad de ND_OVERRIDES.\n\n');
end

% =========================================================================
%  BLOQUE 2 -- Tabla comparativa + digesto por familia + Excel
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Comparacion de robustez: Minnesota corregida\n');
fprintf('  vs. niw_custom (Opcion 4)\n');
fprintf('======================================================\n\n');

bloque2_ok = true;
T_erpt = table(); T_long = table(); T_diag = table();
try
    [T_erpt, T_diag] = build_erpt_comparison(ERPT_by_spec, Results_by_spec, Cfg_by_spec, spec_names, NAMED_SHOCKS);
    T_long           = build_erpt_comparison_long(ERPT_by_spec, spec_names, NAMED_SHOCKS);
catch ME
    bloque2_ok = false;
    fprintf('  [ERROR] construccion de tablas fallo: %s\n\n', ME.message);
end

if bloque2_ok
    fprintf('  --- Diagnosticos de corrida por spec (T_diag) ---\n');
    disp(T_diag);

    % -- Estabilidad (draws crudos) por spec, agrupada por familia --------
    fprintf('  --- Estabilidad de draws crudos (ND=%g) por familia ---\n\n', ND_DEFAULT);
    fprintf('  %-38s %14s\n', 'spec', 'frac_estable');
    for ss = 1:numel(minn_specs)
        sn = minn_specs{ss};
        fprintf('  %-38s %13.2f%%\n', sn, 100*frac_stable_by_spec.(sn));
    end
    minn_mean = mean(cellfun(@(s) frac_stable_by_spec.(s), minn_specs));
    fprintf('  %-38s %13.2f%%   <- promedio "Minnesota corregida"\n\n', '', 100*minn_mean);

    for ss = 1:numel(niwc_specs)
        sn = niwc_specs{ss};
        fprintf('  %-38s %13.2f%%\n', sn, 100*frac_stable_by_spec.(sn));
    end
    niwc_mean = mean(cellfun(@(s) frac_stable_by_spec.(s), niwc_specs));
    fprintf('  %-38s %13.2f%%   <- promedio "niw_custom" (psi=0.97)\n\n', '', 100*niwc_mean);

    % -- Digesto compacto: mediana ERPT por familia, FOCUS_HORIZON/PRICE --
    hz_list = unique(T_long.horizon, 'stable');
    if ~ismember(FOCUS_HORIZON, hz_list)
        FOCUS_HORIZON = hz_list(end);
    end
    fprintf('  --- Digesto: mediana ERPT | price_var=%s | horizonte=%d ---\n', FOCUS_PRICE_VAR, FOCUS_HORIZON);
    fprintf('  (detalle completo -- 3 price_vars x 5 horizontes x bandas -- en el Excel)\n\n');
    fprintf('  %-38s', 'spec');
    for kk = 1:numel(NAMED_SHOCKS)
        fprintf('  %8s', NAMED_SHOCKS{kk});
    end
    fprintf('\n');
    for ss = 1:numel(spec_names)
        sn = spec_names{ss};
        fprintf('  %-38s', sn);
        for kk = 1:numel(NAMED_SHOCKS)
            mask = strcmp(T_long.spec, sn) & strcmp(T_long.shock, NAMED_SHOCKS{kk}) & ...
                   strcmp(T_long.price_var, FOCUS_PRICE_VAR) & (T_long.horizon == FOCUS_HORIZON);
            v = T_long.median(mask);
            if isempty(v)
                fprintf('  %8s', 'n/a');
            else
                fprintf('  %8.3f', v(1));
            end
        end
        fprintf('\n');
    end
    fprintf('\n');
    fprintf('  Lectura: comparar fila a fila cada spec_A_<matriz>_mm_minn_lag<N>_v0\n');
    fprintf('  contra su contraparte spec_A_<matriz>_mm_niwcustom_lag<N>_v0 -- si las\n');
    fprintf('  medianas son parecidas, el ERPT es robusto a la especificacion del\n');
    fprintf('  prior; si difieren mucho, la eleccion Minnesota-vs-niw_custom importa\n');
    fprintf('  para las conclusiones y debe discutirse explicitamente en el paper.\n\n');

    % -- Exportar a Excel (4 hojas: 3 de Chat 8 + estabilidad por familia) -
    comparison_dir = fullfile(PROJ_ROOT, 'output', 'comparison');
    if ~isfolder(comparison_dir), mkdir(comparison_dir); end
    xlsx_path = fullfile(comparison_dir, 'erpt_comparison_mm_minn_vs_niwcustom.xlsx');
    if isfile(xlsx_path), delete(xlsx_path); end

    spec_col      = spec_names(:);
    family_col    = [repmat({'minnesota_corregida'}, numel(minn_specs), 1); ...
                      repmat({'niw_custom_psi097'},   numel(niwc_specs), 1)];
    frac_stable_col = cellfun(@(s) frac_stable_by_spec.(s), spec_names(:));
    T_stability = table(spec_col, family_col, frac_stable_col, ...
        'VariableNames', {'spec', 'family', 'frac_stable_raw_draws'});

    writetable(T_erpt,      xlsx_path, 'Sheet', 'erpt_comparison');
    writetable(T_long,      xlsx_path, 'Sheet', 'erpt_long');
    writetable(T_diag,      xlsx_path, 'Sheet', 'run_diagnostics');
    writetable(T_stability, xlsx_path, 'Sheet', 'stability_by_family');
    fprintf('  Tabla comparativa exportada (4 hojas) a:\n    %s\n\n', xlsx_path);

    fprintf('  >> BLOQUE 2: PASA -- tablas construidas y exportadas.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA.\n\n');
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('======================================================\n');
fprintf('     VEREDICTO GLOBAL ERPT-CHAT 11 CIENTIFICO (Opcion 4)\n');
fprintf('======================================================\n');
fprintf('  Bloque 1 (8 specs, ND=%-6g)  : %s\n', ND_DEFAULT, iif_local(bloque1_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 2 (Comparacion+Excel)  : %s\n', iif_local(bloque2_ok, 'PASA', 'NO PASA'));
fprintf('------------------------------------------------------\n');
if bloque1_ok && bloque2_ok
    fprintf('  GLOBAL : PASA\n');
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% -- Helpers locales --------------------------------------------------------
function out = iif_local(cond, a, b)
    if cond, out = a; else, out = b; end
end

function frac_stable = p_local_check_stability(Results, Cfg)
%P_LOCAL_CHECK_STABILITY  Misma copia local usada en validate_erpt11.m y en
%   diagnose_erpt11_niwcustom_sensitivity.m (logica de check_stability.m
%   del core, con nex_total corregido para incluir dummies COVID).
    Bdraws = Results.Bdraws;
    nd     = numel(Bdraws);
    n      = Results.LtildeStruct.nvar;

    nex_const = 0;
    if isfield(Cfg, 'NEX'), nex_const = Cfg.NEX; end
    ndummies = 0;
    if isfield(Cfg, 'DUMMIES'), ndummies = numel(Cfg.DUMMIES); end
    nex_total = nex_const + ndummies;

    B_example = Bdraws{1};
    m_rows    = size(B_example, 1);
    p = round((m_rows - nex_total) / n);

    np = p * n;
    F_lower = [eye(np - n), zeros(np - n, n)];

    n_stable = 0;
    for s = 1:nd
        B_s = Bdraws{s};
        B_lags = B_s(1:n*p, :);
        F_top = zeros(n, np);
        for l = 1:p
            F_top(:, (l-1)*n+1:l*n) = B_lags((l-1)*n+1:l*n, :)';
        end
        F = [F_top; F_lower];
        if max(abs(eig(F))) < 1
            n_stable = n_stable + 1;
        end
    end
    frac_stable = n_stable / nd;
end
