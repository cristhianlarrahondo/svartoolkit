%VALIDATE_ERPT9  ERPT-Chat 9 — Ejecuta la decision de ERPT-Chat 8: elimina el
%   choque Mon de los 16 specs del Ejercicio A y vuelve a correr la corrida
%   cientifica completa (Cfg.ND=3e5) con 3 choques nombrados {Cam, Dem, Ofe}
%   + 3 residuales. Protocolo Tipo S.
%
%   Ejecutar COMPLETO (F5), nunca por secciones. Pegar el output de consola
%   en el chat para verificacion.
%
%   ── Que cambio respecto a validate_erpt8.m ───────────────────────────────
%   Los 16 archivos de spec (config/spec_A_*_v0.m) fueron editados IN-PLACE
%   en ERPT-Chat 9: Cfg.S{4}=[] y Cfg.Z{4}=[] (el choque 4 pasa de "Mon"
%   restringido a residual sin restriccion) y Cfg.SHOCK_NAMES pierde 'Mon'
%   ({'Cam','Dem','Ofe'}). Todo lo demas (transform, prior, lags, dummies,
%   matriz base/rob para Cam/Dem/Ofe, Cfg.ND) es IDENTICO a ERPT-Chat 8.
%   calculate_erpt.m es agnostico al numero de choques nombrados (Nota 3 de
%   su encabezado) -- no requiere cambios. build_erpt_comparison.m ya tenia
%   {'Cam','Dem','Ofe'} como default; build_erpt_comparison_long.m se ajusto
%   (su default pasa de 4 a 3 choques).
%
%   ── Por que este script BORRA el cache antes de correr ───────────────────
%   Los 16 SPEC_NAME no cambiaron de nombre (edicion in-place), pero SI
%   cambio la identificacion (Mon deja de ser un choque restringido). El
%   cache ND-aware de validate_erpt8.m solo compara Cfg.ND cacheado vs
%   objetivo -- NO sabe que la identificacion cambio -- asi que reusar el
%   cache de ERPT-Chat 8 bajo los mismos nombres de spec cargaria
%   silenciosamente resultados de la version CON Mon. Por eso este script
%   borra <OUTPUT_DIR> completo de los 16 specs antes del Bloque 1, de forma
%   incondicional en la corrida oficial (CLEAR_LEGACY_CACHE=true).
%
%   IMPORTANTE: si mas adelante en esta MISMA sesion se necesita una
%   SEGUNDA pasada (subir ND_OVERRIDES en specs con ne bajo, analogo a lo
%   hecho en ERPT-Chat 8), poner CLEAR_LEGACY_CACHE=false para esa
%   reiteracion -- de lo contrario se borra el resultado recien calculado a
%   3e5 y se pierde el aprovechamiento del cache ND-aware.
%
%   ── Decision de computo (ERPT-Chat 9, decision 3 del prompt) ─────────────
%   Se corre DIRECTO a ND_DEFAULT=3e5 en los 16, SIN smoke previo (riesgo
%   aceptado: no hay antecedente numerico exacto para esta combinacion sin
%   Mon). Gate suave de ne (igual que ERPT-Chat 8): ne < NE_WARN_THRESHOLD
%   -> "bandas indicativas" (advierte, NO reprueba). Solo se reprueba por
%   error real (0 draws, choque nombrado faltante, numero de choques
%   incorrecto, fallo de calculate_erpt). ND_OVERRIDES arranca VACIO en
%   esta corrida oficial; la decision de una segunda pasada se toma DESPUES
%   de ver el ne resultante (pendiente de este chat, ver .md de cierre).
%
%   ── Bloques ───────────────────────────────────────────────────────────────
%   BLOQUE 0 — Regresion BNW IS a ND completo (core intacto, sin cambios).
%   BLOQUE 1 — Cache-clear de los 16 specs + corrida cientifica: load_data ->
%     validate_cfg -> build_posterior -> run_is (ND objetivo) ->
%     calculate_erpt -> save_erpt_run. Gate suave de ne.
%   BLOQUE 2 — Tabla comparativa cruzada (ancha + larga), NAMED_SHOCKS de 3.
%   BLOQUE 3 — Casos de error esperados (sin cambios de fondo).

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 9 -- 16 specs sin Mon (3 choques) + tabla\n');
fprintf('======================================================\n\n');

%% ── Controles de corrida (editar aqui) ────────────────────────────────────
CLEAR_LEGACY_CACHE = true;    % true = borrar <OUTPUT_DIR> de los 16 specs ANTES de correr
                               % (obligatorio en la corrida oficial de ERPT-Chat 9 -- ver
                               % nota de cabecera. Poner false SOLO en una segunda pasada
                               % dentro de esta misma sesion, tras un primer F5 exitoso).
USE_CACHE         = true;      % true = reusar <OUTPUT_DIR>/results_is.mat si ND cacheado >= objetivo
RUN_BNW_CHECK     = true;      % true = correr Bloque 0 (obligatorio para APRUEBO)
ND_DEFAULT        = 3e5;       % ND objetivo por defecto (corrida cientifica, directo, sin smoke)
NE_WARN_THRESHOLD = 200;       % ne por debajo de esto -> advertencia "bandas indicativas" (no reprueba)
FOCUS_HORIZON     = 36;        % horizonte del digesto de consola (pass-through de largo plazo)
FOCUS_PRICE_VAR   = 'con_inf'; % price_var del digesto de consola (pass-through a inflacion al consumidor)

% ND_OVERRIDES: subir ND objetivo de specs puntuales. VACIO en esta corrida
% oficial (decision 3 del prompt de ERPT-Chat 9: directo a ND_DEFAULT en
% los 16, sin antecedente numerico para la version sin Mon). Si el ne
% resultante de esta corrida lo justifica, se decide una segunda pasada en
% este mismo chat (ver seccion "DECISION A REVISAR" del prompt) y este
% struct se llena entonces -- con CLEAR_LEGACY_CACHE=false para esa 2a
% pasada, de forma analoga a como se hizo en ERPT-Chat 8.
ND_OVERRIDES = struct();

%% ── Rutas (F5 completo -> mfilename('fullpath') es confiable) ──────────────
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);            % .../refactored/projects/erpt
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);       % .../refactored
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(PROJ_CFG);
addpath(PROJ_SRC);

fprintf('  REF_ROOT            : %s\n', REF_ROOT);
fprintf('  PROJ_ROOT           : %s\n', PROJ_ROOT);
fprintf('  CLEAR_LEGACY_CACHE  : %d\n', CLEAR_LEGACY_CACHE);
fprintf('  USE_CACHE           : %d\n', USE_CACHE);
fprintf('  RUN_BNW_CHECK       : %d\n', RUN_BNW_CHECK);
fprintf('  ND_DEFAULT          : %g\n', ND_DEFAULT);
fprintf('  NE_WARN_THRESHOLD   : %d\n', NE_WARN_THRESHOLD);
if ~isempty(fieldnames(ND_OVERRIDES))
    fprintf('  ND_OVERRIDES        : %s\n', strjoin(fieldnames(ND_OVERRIDES), ', '));
else
    fprintf('  ND_OVERRIDES        : (vacio -- corrida directa a ND_DEFAULT en las 16)\n');
end
fprintf('\n');

V       = {'FAIL', 'OK  '};
TOL_irf = 1e-6;

% Los 16 specs del Ejercicio A (mismos nombres de ERPT-Chat 7/8; edicion
% in-place en ERPT-Chat 9 -- ver cabecera).
spec_names = { ...
    'spec_A_base_aa_diffuse_lag2_v0', 'spec_A_base_aa_diffuse_lag4_v0', ...
    'spec_A_base_aa_minn_lag2_v0',    'spec_A_base_aa_minn_lag4_v0', ...
    'spec_A_base_mm_diffuse_lag2_v0', 'spec_A_base_mm_diffuse_lag4_v0', ...
    'spec_A_base_mm_minn_lag2_v0',    'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_rob_aa_diffuse_lag2_v0',  'spec_A_rob_aa_diffuse_lag4_v0', ...
    'spec_A_rob_aa_minn_lag2_v0',     'spec_A_rob_aa_minn_lag4_v0', ...
    'spec_A_rob_mm_diffuse_lag2_v0',  'spec_A_rob_mm_diffuse_lag4_v0', ...
    'spec_A_rob_mm_minn_lag2_v0',     'spec_A_rob_mm_minn_lag4_v0' };

NAMED_SHOCKS = {'Cam', 'Dem', 'Ofe'};   % 3 choques nombrados (ERPT-Chat 9 -- Mon eliminado)

% =========================================================================
%  BLOQUE -1 (previo al 0) -- Cache-clear obligatorio de los 16 specs
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE PREVIO -- limpieza de cache legado (con Mon)\n');
fprintf('======================================================\n\n');

if CLEAR_LEGACY_CACHE
    for ss = 1:numel(spec_names)
        spec_name = spec_names{ss};
        clear Cfg;
        Cfg = struct();
        run(fullfile(PROJ_CFG, [spec_name '.m']));
        out_dir = Cfg.OUTPUT_DIR;
        if isfolder(out_dir)
            rmdir(out_dir, 's');
            fprintf('  [borrado] %s\n', out_dir);
        else
            fprintf('  [sin cache previo] %s\n', out_dir);
        end
    end
    fprintf('\n  >> Cache legado (con Mon) eliminado para los 16 specs.\n\n');
else
    fprintf('  [OMITIDO] CLEAR_LEGACY_CACHE=false -- se conserva el cache existente.\n');
    fprintf('  NOTA: usar esto SOLO en una segunda pasada dentro de esta misma\n');
    fprintf('  sesion, tras un primer F5 exitoso ya sin Mon.\n\n');
end

% =========================================================================
%  BLOQUE 0 -- Regresion BNW IS a ND completo
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 0 -- Regresion BNW IS (spec_bnw_is), ND completo\n');
fprintf('======================================================\n\n');

if RUN_BNW_CHECK
    clear Cfg;
    Cfg = struct();
    run(fullfile(REF_ROOT, 'config', 'spec_bnw_is.m'));
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;
    fprintf('  Cfg.MODE = %s | Cfg.ND = %g | Cfg.SEED = %d\n', Cfg.MODE, Cfg.ND, Cfg.SEED);

    Dataset_bnw   = load_data(Cfg);
    Posterior_bnw = build_posterior(Dataset_bnw, Cfg);

    fprintf('  Corriendo IS BNW (nd=%g, esperar varios minutos)...\n', Cfg.ND);
    rng('default'); rng(0);
    tic;
    Results_bnw = run_is(Posterior_bnw, Cfg);
    t_bnw = toc;
    fprintf('  Tiempo: %.1f seg\n\n', t_bnw);

    Ltilde_bnw = Results_bnw.LtildeStruct.data;
    val_ib = Ltilde_bnw(end, end, end, end);
    val_ic = median(squeeze(Ltilde_bnw(:, 2, 1, :)), 'all');
    REF_ib = 0.2041864191;
    REF_ic = 2.9521795528;

    ok_ib = abs(val_ib - REF_ib) <= TOL_irf;
    ok_ic = abs(val_ic - REF_ic) <= TOL_irf;

    fprintf('  Ltilde(end,end,end,end) = %.10f   (ref %.10f)   %s\n', val_ib, REF_ib, V{int32(ok_ib)+1});
    fprintf('  median(Lt(:,2,1,:))     = %.10f   (ref %.10f)   %s\n', val_ic, REF_ic, V{int32(ok_ic)+1});
    fprintf('  ne efectivo             = %d\n\n', Results_bnw.ne);

    bloque0_pasa = ok_ib && ok_ic;
    if bloque0_pasa
        fprintf('  >> BLOQUE 0: PASA -- baseline BNW intacto (nada del core fue tocado).\n\n');
    else
        fprintf('  >> BLOQUE 0: NO PASA -- detener y revisar antes de continuar.\n\n');
    end
else
    bloque0_pasa = true;   % omitido a proposito (solo para re-iteraciones de tabla)
    fprintf('  [OMITIDO] RUN_BNW_CHECK=false. Bloque 0 saltado.\n');
    fprintf('  NOTA: la corrida oficial para APRUEBO debe correr con RUN_BNW_CHECK=true.\n\n');
end

% =========================================================================
%  BLOQUE 1 -- Los 16 specs, corrida cientifica (sin Mon)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- 16 specs, ND cientifico (cache ND-aware, sin Mon)\n');
fprintf('======================================================\n\n');

bloque1_ok      = true;
bloque1_msgs    = {};
warn_low_ne     = {};   % specs con ne < NE_WARN_THRESHOLD (advertencia, no fallo)
Results_by_spec = struct();
Dataset_by_spec = struct();
Cfg_by_spec     = struct();
ERPT_by_spec    = struct();

for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};
    fprintf('------------------------------------------------------\n');
    fprintf('  [%2d/16] Spec: %s\n', ss, spec_name);
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
    Cfg.ND           = nd_target;   % override editable (segunda pasada, si aplica)

    % transform_type EXPLICITO (calculate_erpt lo exige; no se infiere) ----
    if contains(spec_name, '_aa_')
        transform_type = 'aa';
    else
        transform_type = 'mm';
    end

    cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
    used_cache = false;

    % -- Cache ND-aware: reusar solo si ND cacheado >= objetivo ------------
    if USE_CACHE && isfile(cache_path)
        try
            [Results_spec, ERPT_spec, Dataset_spec, Cfg_cached] = load_erpt_run(Cfg.OUTPUT_DIR);
            nd_cached = NaN;
            if isfield(Cfg_cached, 'ND'), nd_cached = Cfg_cached.ND; end
            if ~isnan(nd_cached) && nd_cached >= nd_target
                used_cache = true;
                Cfg = Cfg_cached;   % conserva el ND real con que corrio
            else
                fprintf('  [cache] ND cacheado (%g) < objetivo (%g) -> re-estimando.\n', nd_cached, nd_target);
                used_cache = false;
            end
        catch ME
            fprintf('  [ALERTA] No se pudo cargar cache (%s) -- re-estimando desde cero.\n', ME.message);
            used_cache = false;
        end
    end

    if ~used_cache
        fprintf('  Dataset: cargando %s (transform=%s)...\n', Cfg.DATA_FILE, transform_type);
        Dataset_spec = load_data(Cfg);
        fprintf('  Dataset: %d endogenas, freq=%s, T=%d obs\n', ...
            Dataset_spec.nvar, Dataset_spec.freq, size(Dataset_spec.Y_raw, 1));

        validate_cfg(Cfg, Dataset_spec);
        Posterior_spec = build_posterior(Dataset_spec, Cfg);   % construye dummies COVID adentro

        % Sanity ligero de dummies (Chat 7 valido las ventanas a fondo).
        if isfield(Posterior_spec, 'ndummies')
            fprintf('  Dummies exogenas incluidas: %d\n', Posterior_spec.ndummies);
            if Posterior_spec.ndummies ~= 2
                fprintf('  [ALERTA] se esperaban 2 dummies COVID, hay %d.\n', Posterior_spec.ndummies);
            end
        end

        fprintf('  Corriendo IS (nd=%g, CIENTIFICO -- varios minutos)...\n', Cfg.ND);
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

    % -- Checks estructurales (hard-fail) ---------------------------------
    n_shocks_out = numel(ERPT_spec.shocks);
    if n_shocks_out ~= Dataset_spec.nvar
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: se esperaban %d choques, se obtuvieron %d', ...
            spec_name, Dataset_spec.nvar, n_shocks_out); %#ok<AGROW>
    end
    names_out = {ERPT_spec.shocks.name};
    if ~all(ismember(NAMED_SHOCKS, names_out))
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: faltan choques nombrados (esperados %s; presentes %s)', ...
            spec_name, strjoin(NAMED_SHOCKS, '/'), strjoin(names_out, '/')); %#ok<AGROW>
    end
    if any(strcmpi(names_out, 'Mon'))
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: el choque ''Mon'' sigue presente -- se esperaba eliminado (ERPT-Chat 9)', ...
            spec_name); %#ok<AGROW>
    end
    if Results_spec.ne <= 0
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: ne=%d (sin draws efectivos)', spec_name, Results_spec.ne); %#ok<AGROW>
    end

    % -- Gate SUAVE de ne (advertencia, no fallo) -------------------------
    if Results_spec.ne > 0 && Results_spec.ne < NE_WARN_THRESHOLD
        warn_low_ne{end+1} = sprintf('%s (ne=%d, ND=%g)', spec_name, Results_spec.ne, Cfg.ND); %#ok<AGROW>
    end

    Results_by_spec.(spec_name) = Results_spec;
    Dataset_by_spec.(spec_name) = Dataset_spec;
    Cfg_by_spec.(spec_name)     = Cfg;
    ERPT_by_spec.(spec_name)    = ERPT_spec;

    fprintf('\n');
end

if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- las 16 specs corrieron (o cargaron del cache)\n');
    fprintf('     con ND objetivo y produjeron %d choques nombrados Cam/Dem/Ofe (sin Mon).\n', numel(NAMED_SHOCKS));
else
    fprintf('  >> BLOQUE 1: NO PASA. Detalle:\n');
    for i = 1:numel(bloque1_msgs)
        fprintf('     - %s\n', bloque1_msgs{i});
    end
end
if ~isempty(warn_low_ne)
    fprintf('\n  [ADVERTENCIA] ne < %d en %d spec(s) -- BANDAS INDICATIVAS\n', ...
        NE_WARN_THRESHOLD, numel(warn_low_ne));
    fprintf('   (no reprueba; es informacion sobre la identificacion debil de D2, ahora\n');
    fprintf('    con 3 choques restringidos en vez de 4. Para bandas mas ajustadas, subir\n');
    fprintf('    ND_OVERRIDES de estas specs y re-F5 con CLEAR_LEGACY_CACHE=false):\n');
    for i = 1:numel(warn_low_ne)
        fprintf('     - %s\n', warn_low_ne{i});
    end
end
fprintf('\n');

% =========================================================================
%  BLOQUE 2 -- Tabla comparativa cruzada (ancha + larga)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Tabla comparativa cruzada (16 specs, 3 choques)\n');
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
    % -- Diagnosticos por spec (el titular: ne / aceptacion) ----------------
    fprintf('  --- Diagnosticos de corrida por spec (T_diag) ---\n');
    disp(T_diag);

    % -- Digesto compacto de consola: FOCUS_HORIZON, FOCUS_PRICE_VAR --------
    hz_list = unique(T_long.horizon, 'stable');
    if ~ismember(FOCUS_HORIZON, hz_list)
        FOCUS_HORIZON = hz_list(end);   % fallback: horizonte mas largo disponible
    end
    fprintf('  --- Digesto: mediana ERPT | price_var=%s | horizonte=%d ---\n', FOCUS_PRICE_VAR, FOCUS_HORIZON);
    fprintf('  (detalle completo -- 3 price_vars x 5 horizontes x bandas -- en el Excel)\n\n');
    fprintf('  %-32s', 'spec');
    for kk = 1:numel(NAMED_SHOCKS)
        fprintf('  %8s', NAMED_SHOCKS{kk});
    end
    fprintf('\n');
    for ss = 1:numel(spec_names)
        sn = spec_names{ss};
        fprintf('  %-32s', sn);
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

    % -- Exportar a Excel (3 hojas) ---------------------------------------
    comparison_dir = fullfile(PROJ_ROOT, 'output', 'comparison');
    if ~isfolder(comparison_dir), mkdir(comparison_dir); end
    xlsx_path = fullfile(comparison_dir, 'erpt_comparison_A16_noMon.xlsx');
    if isfile(xlsx_path), delete(xlsx_path); end
    writetable(T_erpt, xlsx_path, 'Sheet', 'erpt_comparison');   % ancha (16 specs lado a lado)
    writetable(T_long, xlsx_path, 'Sheet', 'erpt_long');         % tidy (pivotable)
    writetable(T_diag, xlsx_path, 'Sheet', 'run_diagnostics');   % ne/aceptacion/tiempo
    fprintf('  Tabla comparativa exportada (3 hojas) a:\n    %s\n\n', xlsx_path);

    fprintf('  >> BLOQUE 2: PASA -- tablas ancha+larga construidas y exportadas.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA.\n\n');
end

% =========================================================================
%  BLOQUE 3 -- Casos de error esperados
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Casos de error esperados\n');
fprintf('======================================================\n\n');

bloque3_ok   = true;
bloque3_msgs = {};

% Caso 1: horizontes distintos entre specs (build_erpt_comparison ancha)
try
    ERPT_bad = ERPT_by_spec;
    fn1 = spec_names{1};
    ERPT_bad.(fn1).horizons = ERPT_bad.(fn1).horizons(1:end-1);
    build_erpt_comparison(ERPT_bad, Results_by_spec, Cfg_by_spec, spec_names, NAMED_SHOCKS);
    bloque3_ok = false; bloque3_msgs{end+1} = 'horizontes distintos: NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] horizontes distintos no genero error\n');
catch ME
    fprintf('  [OK] horizontes distintos -> error esperado: %s\n', ME.identifier);
end

% Caso 2: price_vars distintas entre specs (build_erpt_comparison ancha)
try
    ERPT_bad2 = ERPT_by_spec;
    fn2 = spec_names{2};
    ERPT_bad2.(fn2).price_vars = {'imp_inf', 'con_inf'};   % quita pro_inf
    build_erpt_comparison(ERPT_bad2, Results_by_spec, Cfg_by_spec, spec_names, NAMED_SHOCKS);
    bloque3_ok = false; bloque3_msgs{end+1} = 'price_vars distintas: NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] price_vars distintas no genero error\n');
catch ME
    fprintf('  [OK] price_vars distintas -> error esperado: %s\n', ME.identifier);
end

% Caso 3: choque inexistente en shock_names_sel (ancha).
% NOTA: en ERPT-Chat 9, 'Mon' YA NO existe en ninguno de los 16 specs (fue
% eliminado) -- se usa directamente 'Mon' como choque inexistente, en vez
% de 'Fiscal' (ERPT-Chat 8), como verificacion cruzada de la eliminacion.
try
    build_erpt_comparison(ERPT_by_spec, Results_by_spec, Cfg_by_spec, spec_names, {'Cam', 'Mon'});
    bloque3_ok = false; bloque3_msgs{end+1} = 'choque inexistente (Mon): NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] choque inexistente (ancha) no genero error\n');
catch ME
    fprintf('  [OK] choque inexistente (Mon, ancha) -> error esperado: %s\n', ME.identifier);
end

% Caso 4: choque inexistente en build_erpt_comparison_long (helper)
try
    build_erpt_comparison_long(ERPT_by_spec, spec_names, {'Cam', 'Mon'});
    bloque3_ok = false; bloque3_msgs{end+1} = 'long/choque inexistente: NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] choque inexistente (larga) no genero error\n');
catch ME
    fprintf('  [OK] choque inexistente (Mon, larga) -> error esperado: %s\n', ME.identifier);
end

% Caso 5: save_erpt_run sin Cfg.OUTPUT_DIR
try
    Cfg_bad = Cfg_by_spec.(spec_names{1});
    Cfg_bad = rmfield(Cfg_bad, 'OUTPUT_DIR');
    save_erpt_run(Results_by_spec.(spec_names{1}), ERPT_by_spec.(spec_names{1}), ...
        Dataset_by_spec.(spec_names{1}), Cfg_bad);
    bloque3_ok = false; bloque3_msgs{end+1} = 'save_erpt_run sin OUTPUT_DIR: NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] save_erpt_run sin OUTPUT_DIR no genero error\n');
catch ME
    fprintf('  [OK] save_erpt_run sin OUTPUT_DIR -> error esperado: %s\n', ME.identifier);
end

fprintf('\n');
if bloque3_ok
    fprintf('  >> BLOQUE 3: PASA -- los 5 casos de error se comportan como se esperaba.\n\n');
else
    fprintf('  >> BLOQUE 3: NO PASA. Detalle:\n');
    for i = 1:numel(bloque3_msgs)
        fprintf('     - %s\n', bloque3_msgs{i});
    end
    fprintf('\n');
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('======================================================\n');
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 9\n');
fprintf('======================================================\n');
fprintf('  Bloque 0 (Regresion BNW IS, ND completo) : %s\n', iif_local(bloque0_pasa, 'PASA', 'NO PASA'));
fprintf('  Bloque 1 (16 specs, ND cientifico, sin Mon): %s\n', iif_local(bloque1_ok,   'PASA', 'NO PASA'));
fprintf('  Bloque 2 (Tabla comparativa ancha+larga)  : %s\n', iif_local(bloque2_ok,   'PASA', 'NO PASA'));
fprintf('  Bloque 3 (Casos de error)                 : %s\n', iif_local(bloque3_ok,   'PASA', 'NO PASA'));
fprintf('------------------------------------------------------\n');
if bloque0_pasa && bloque1_ok && bloque2_ok && bloque3_ok
    fprintf('  GLOBAL : PASA\n');
    if ~isempty(warn_low_ne)
        fprintf('  (con %d spec(s) marcada(s) como BANDAS INDICATIVAS por ne bajo --\n', numel(warn_low_ne));
        fprintf('   hallazgo economico, no fallo. Ver seccion de advertencia arriba. Pendiente\n');
        fprintf('   decidir en este chat si se acepta o se lanza una 2a pasada con ND_OVERRIDES.)\n');
    end
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% ── Helper local ──────────────────────────────────────────────────────────
function out = iif_local(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end
