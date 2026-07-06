%SPEC_TEMPLATE_PFA  Plantilla de configuración — modo PFA (Penalty Function Approach).
%
%   CÓMO USAR ESTA PLANTILLA
%   ─────────────────────────────────────────────────────────────────────
%   1. Copia esta carpeta template/ completa a projects/mi_caso/
%   2. Renombra este archivo a spec_<micaso>_pfa.m
%   3. Edita las secciones marcadas con ← EDITAR
%   4. Corre pipeline_template.m sección a sección con Ctrl+Enter
%   ─────────────────────────────────────────────────────────────────────
%
%   Este script es ejecutado por pipeline_template.m via run().
%   Popula la struct Cfg en el workspace del caller.

% =========================================================================
%  SECCIÓN 1 — DATOS                                          ← EDITAR
% =========================================================================
% Ruta al archivo xlsx de datos. Usa fileparts(mfilename('fullpath'))
% para construir la ruta relativa a la ubicación de ESTE archivo.
% Nunca uses pwd, cd, ni '..'.

cfg_dir       = fileparts(mfilename('fullpath'));   % .../mi_caso/config/
ex_dir        = fileparts(cfg_dir);                 % .../mi_caso/
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_micaso.xlsx');  % ← EDITAR nombre

% Cfg.VARS (Chat 19, Hallazgo 7 — OPCIONAL): selecciona/reordena columnas
% de la hoja "data" por NOMBRE (deben coincidir exactamente con los
% encabezados de tu xlsx), sin necesidad de editar el Excel. Si lo dejas
% vacio/comentado, se usan TODAS las columnas en el orden del Excel.
% Cfg.VARS = {'prod_growth', 'act_growth', 'price_growth', 'inv_growth'};  % ← EDITAR (opcional)

% Cfg.VAR_ROLES (← EDITAR): mismo largo y orden que Cfg.VARS (si lo
% definiste) o que las columnas de la hoja "data" (si no). Determina
% cuales entran al VAR como endogenas — nunca se leen del Excel.
Cfg.VAR_ROLES = {'endogenous','endogenous','endogenous','endogenous'};  % ← EDITAR

% Factor de escala aplicado a los datos al cargarlos.
%   1   → datos ya están en la unidad correcta (%, log-dif, etc.)
%   100 → datos en logaritmos sin escalar (como en BNW)
Cfg.SCALE_FACTOR = 1;      % ← EDITAR según tus datos

% =========================================================================
%  SECCIÓN 2 — MODELO VAR                                     ← EDITAR
% =========================================================================
Cfg.NLAG         = 4;      % ← EDITAR número de lags
Cfg.NEX          = 1;      % 1 = incluir constante  |  0 = sin constante
Cfg.HORIZON      = 20;     % ← EDITAR horizonte máximo IRF (en períodos)
Cfg.INDEX_FEVD   = 20;     % ← EDITAR horizonte para FEVD (≤ HORIZON)

% =========================================================================
%  SECCIÓN 3 — MUESTREO                                       ← EDITAR
% =========================================================================
Cfg.MODE           = 'pfa';    % NO cambiar en esta spec
Cfg.ND             = 500;      % draws para testing. Producción: 5000+
Cfg.MAX_IS_DRAWS   = 500;      % no aplica en PFA; incluido por completitud
Cfg.CONJUGATE      = 'irfs';   % 'irfs' recomendado para PFA
Cfg.SEED           = 0;        % semilla rng (0 = reproducible)

% =========================================================================
%  SECCIÓN 4 — RESTRICCIONES DE IDENTIFICACIÓN               ← EDITAR
% =========================================================================
%
%  CONCEPTOS CLAVE
%  ────────────────────────────────────────────────────────────────────────
%  El toolkit identifica shocks estructurales imponiendo restricciones
%  sobre la matriz de impacto L₀ (o sobre las IRFs a horizontes h > 0).
%
%  Cada COLUMNA k de L₀ corresponde al SHOCK k.
%  Cada FILA i de L₀ corresponde a la VARIABLE i.
%  El elemento (i,k) de L₀ es la respuesta de variable i al shock k en h=0.
%
%  Tus variables tienen índices según el orden en la hoja 'varinfo' del xlsx:
%    var_1 = primera variable endógena listada
%    var_2 = segunda variable endógena listada
%    ... y así sucesivamente
%
%  ┌───────────────────────────────────────────────────────────────────┐
%  │ REGLA (Chat 19, Hallazgo 1) — LEE ESTO ANTES DE EDITAR:              │
%  │   Cfg.S y Cfg.Z SIEMPRE se dimensionan a cell(n_vars, 1), sin       │
%  │   importar cuantos shocks tengan restricciones realmente           │
%  │   declaradas. NO uses cell(n_shocks_identificados, 1) — con 6      │
%  │   variables y 4 shocks de interes, sigue siendo cell(6, 1), NO     │
%  │   cell(4, 1). Los shocks sin restriccion simplemente quedan con    │
%  │   Cfg.S{k} = [] (celda vacia). Esto lo exigen internamente         │
%  │   SetupInfo.m, run_pfa.m, run_is.m y                               │
%  │   structural_restrictions_generic.m, todos indexando 1:n_vars.     │
%  └───────────────────────────────────────────────────────────────────┘
%
%  HAY DOS TIPOS DE RESTRICCIONES:
%
%  S{k}  →  restricciones de SIGNO sobre el shock k
%    Cada fila de S{k} selecciona UNA variable, UN horizonte, y dice si
%    responde positiva o negativamente al shock k en ese horizonte.
%
%  Z{k}  →  restricciones de CERO sobre el shock k
%    Cada fila de Z{k} selecciona UNA variable y UN horizonte cuya
%    respuesta al shock k es exactamente 0.
%    (solo aplica en modo IS; en PFA Z debe dejarse vacío — ver LIMITACIÓN
%    DE PFA más abajo)
%
%  CÓMO SE CONSTRUYE CADA FILA — build_restriction_row.m
%  ────────────────────────────────────────────────────────────────────────
%  En vez de armar las filas a mano con eye(n_vars), usa la función
%  compartida build_restriction_row.m (vive en refactored/src/), que ya
%  calcula el offset de columna correcto para cualquier horizonte:
%
%    row = build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
%
%      var_idx       índice ordinal de la variable (1..n_vars)
%      horizon_idx   índice ORDINAL dentro de Cfg.HORIZONS_RESTRICT (NO es
%                    el valor del horizonte). Si HORIZONS_RESTRICT=[0 1 2],
%                    horizon_idx=1→h=0, horizon_idx=2→h=1, horizon_idx=3→h=2.
%      n_vars        número de variables endógenas (Dataset.nvar)
%      n_horizons    numel(Cfg.HORIZONS_RESTRICT)
%      sign_val      +1 (positivo) o -1 (negativo) para S; +1 por
%                    convención para Z (el signo no importa en Z)
%
%  HORIZONTE DE LAS RESTRICCIONES
%  ────────────────────────────────────────────────────────────────────────
%  Cfg.HORIZONS_RESTRICT define en qué horizontes aplican S y Z:
%    0          → solo en h=0 (restricción de impacto — lo más común)
%    [0 1 2]    → en h=0, h=1 y h=2 simultáneamente
%    0:3        → en h=0 hasta h=3
%    0:H        → en todos los horizontes hasta H
%
%  Ejemplos típicos en la literatura:
%    Kilian & Murphy (2012)   → HORIZONS_RESTRICT = 0        (solo impacto)
%    Uhlig (2005)             → HORIZONS_RESTRICT = 0:4      (h=0 a h=4)
%    Mountford & Uhlig (2009) → HORIZONS_RESTRICT = [0 1 2 3]
%
%  LIMITACIÓN REAL DE PFA — un solo choque a la vez
%  ────────────────────────────────────────────────────────────────────────
%  PFA (Mountford & Uhlig, 2009) identifica UN ÚNICO choque por corrida:
%  las restricciones de signo entran como el objetivo a maximizar sobre
%  un solo vector q, no como filtro sobre varios choques simultáneos.
%
%  Si esta spec declara Cfg.S{k} no vacío para MÁS DE UN índice k,
%  run_pfa.m lo detecta automáticamente, emite un warning, y devuelve
%  Results.skipped = true (Results.skip_reason explica por qué) — NO
%  falla con un error críptico más adelante. En ese caso usa Cfg.MODE='is'
%  con la spec IS equivalente, que sí puede resolver múltiples choques
%  restringidos en la misma corrida.
%
%  Cada fila de S{k}/Z{k} debe restringir exactamente UNA variable en UN
%  horizonte (no se soportan combinaciones lineales de variables en una
%  sola fila).
%
%  ── EJEMPLO 1 — solo impacto (h=0), como Kilian & Murphy (2012) ─────────
%  Variables: (1)prod, (2)act, (3)price, (4)inv  →  n_vars=4
%  Shock 1 (oferta): prod responde POSITIVO en h=0, price responde
%  NEGATIVO en h=0.
%
%    n_vars = 4;
%    Cfg.HORIZONS_RESTRICT = 0;
%    n_horizons = numel(Cfg.HORIZONS_RESTRICT);   % = 1
%
%    Cfg.S    = cell(n_vars, 1);
%    Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1);  ...  % prod+ en h=0
%                 build_restriction_row(3, 1, n_vars, n_horizons, -1) ];    % price- en h=0
%
%  ── EJEMPLO 2 — multi-horizonte real, como Uhlig (2005) ─────────────────
%  Mismas 4 variables. Shock 1: prod responde POSITIVO en h=0, h=1 y h=2;
%  price responde NEGATIVO también en h=0, h=1 y h=2.
%
%    n_vars = 4;
%    Cfg.HORIZONS_RESTRICT = [0 1 2];             % 3 horizontes declarados
%    n_horizons = numel(Cfg.HORIZONS_RESTRICT);   % = 3
%
%    Cfg.S    = cell(n_vars, 1);
%    Cfg.S{1} = [ ...
%      build_restriction_row(1, 1, n_vars, n_horizons,  1); ...  % prod+ en h=0 (horizon_idx=1)
%      build_restriction_row(1, 2, n_vars, n_horizons,  1); ...  % prod+ en h=1 (horizon_idx=2)
%      build_restriction_row(1, 3, n_vars, n_horizons,  1); ...  % prod+ en h=2 (horizon_idx=3)
%      build_restriction_row(3, 1, n_vars, n_horizons, -1); ...  % price- en h=0
%      build_restriction_row(3, 2, n_vars, n_horizons, -1); ...  % price- en h=1
%      build_restriction_row(3, 3, n_vars, n_horizons, -1) ];    % price- en h=2
%
%  Para una variable SIN restricción de signo: simplemente no la incluyas.
%  Para el shock k SIN restricciones: deja Cfg.S{k} = [] (celda vacía).
%  Ver también build_restriction_row.m para más ejemplos.
%  ─────────────────────────────────────────────────────────────────────────

% ── Número de variables (Chat 19, Hallazgo 8: auto-derivado de VAR_ROLES,
%    ya no se escribe a mano — evita el desajuste que causaba errores de
%    dimension al cambiar de spec) ─────────────────────────────────────
n_vars = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));

% ── Horizonte de las restricciones ──────────────────────────────────────
Cfg.HORIZONS_RESTRICT = 0;    % ← EDITAR: 0 | [0 1 2] | 0:H
Cfg.NS  = 1;                  % número de shocks identificados
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

% ── Restricciones de CERO — vacías en PFA ───────────────────────────────
Cfg.Z = cell(n_vars, 1);      % todas vacías — no tocar en PFA

% ── Restricciones de SIGNO — EDITAR según tu modelo ─────────────────────
%
%  Tabla de restricciones (reemplaza con las tuyas):
%  ┌─────────────┬────────┬────────────┬───────────┬───────────────────────┐
%  │ Variable    │ Índice │ Shock      │ Horizonte │ Restricción           │
%  ├─────────────┼────────┼────────────┼───────────┼───────────────────────┤
%  │ var_1       │   1    │ Shock 1    │   h=0     │ POSITIVO              │
%  │ var_3       │   3    │ Shock 1    │   h=0     │ NEGATIVO              │
%  └─────────────┴────────┴────────────┴───────────┴───────────────────────┘
%
Cfg.S    = cell(n_vars, 1);
Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1);  ...  % var_1 POSITIVO en h=0  ← EDITAR
             build_restriction_row(3, 1, n_vars, n_horizons, -1) ];    % var_3 NEGATIVO en h=0  ← EDITAR
% Cfg.S{2} = [];    % shock 2 sin restricciones (descomentar si aplica)

% =========================================================================
%  SECCIÓN 5 — OUTPUT Y VISUALIZACIÓN
% =========================================================================
% Cfg.OUTPUT_DIR — FIX Chat 19 (antes ausente en esta plantilla): sin este
% campo, plot_irfs.m/plot_fevd.m/export_results.m escriben en el folder
% legado refactored/output/ compartido entre TODOS los proyectos, en vez
% de projects/mi_caso/output/ (autocontenido). Siempre defínelo así:
cfg_dir_out   = fileparts(mfilename('fullpath'));   % .../mi_caso/config/
proj_root_out = fileparts(cfg_dir_out);             % .../mi_caso/
Cfg.OUTPUT_DIR = fullfile(proj_root_out, 'output'); % ← NO EDITAR (siempre relativo)

Cfg.SPEC_NAME        = 'spec_template_pfa';  % ← EDITAR nombre de tu spec
Cfg.SAVE_RESULTS     = false;   % true → guarda .mat en output/results/
Cfg.PLOT_IRFS        = false;   % controlado desde pipeline_template.m
Cfg.ITER_SHOW        = 100;
Cfg.SUMMARY_HORIZONS = [0 1 4 8 12 20];  % ← EDITAR horizontes para print_summary
Cfg.CRED_BANDS       = [0.16 0.84];      % bandas de credibilidad [16%, 84%]
Cfg.SHOCK_IDX        = 1;               % escalar | vector | 'all' (Chat 19: ya soporta varios shocks)
Cfg.SHOCK_NAMES      = {'shock1'};       % ← EDITAR (Chat 19, Hallazgo 9): nombres de tus shocks para
                                         %   leyendas/titulos/nombres de archivo. Default si no lo
                                         %   defines: 'shock1', 'shock2', ... (resolve_shock_name.m)
Cfg.IRF_TYPE         = 'irf';           % 'irf' | 'cirf' | 'both'
Cfg.IRF_NORM         = 'none';          % 'none' | '1sd' | 'unit' | 'own_unit'

% Cfg.FEVD_HORIZONS (← EDITAR, Chat 19, Hallazgo 6): horizontes en los que
% se calcula la FEVD del shock identificado por PFA (un solo shock por
% corrida — ver limitacion documentada arriba). Default si no lo defines:
% Cfg.INDEX_FEVD (un unico horizonte). Para la curva completa de
% plot_fevd.m, usa algo como 1:Cfg.HORIZON.
Cfg.FEVD_HORIZONS = 1:Cfg.HORIZON;

% Parámetros internos (no modificar)
Cfg.TIMING_VARIANT = [];
Cfg.DERIV_SIDED    = 2;


