%SPEC_TEMPLATE_IS  Plantilla de configuración — modo IS (Importance Sampler).
%
%   CUÁNDO USAR IS vs PFA
%   ─────────────────────────────────────────────────────────────────────
%   PFA  → solo restricciones de SIGNO (S), y UN SOLO choque restringido
%           por corrida (limitación estructural de Mountford-Uhlig).
%           Más rápido, más draws.
%   IS   → restricciones de SIGNO (S) + CERO (Z), y puede resolver
%           MÚLTIPLES choques restringidos en la misma corrida. Necesitas
%           IS cuando quieres imponer que cierta variable NO responda a
%           cierto shock, o cuando restringes más de un choque a la vez.
%
%   Este script es ejecutado por pipeline_template.m via run().
%   Popula la struct Cfg en el workspace del caller.

% =========================================================================
%  SECCIÓN 1 — DATOS                                          ← EDITAR
% =========================================================================
cfg_dir       = fileparts(mfilename('fullpath'));
ex_dir        = fileparts(cfg_dir);
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_micaso.xlsx');  % ← EDITAR

% Cfg.VARS (Chat 19, Hallazgo 7 — OPCIONAL): selecciona/reordena columnas
% de la hoja "data" por NOMBRE, sin editar el Excel. Vacio/comentado =
% todas las columnas en el orden del Excel.
% Cfg.VARS = {'prod_growth', 'act_growth', 'price_growth', 'inv_growth'};  % ← EDITAR (opcional)

% Cfg.VAR_ROLES (← EDITAR): mismo largo y orden que Cfg.VARS (si lo
% definiste) o que las columnas de la hoja "data" (si no).
Cfg.VAR_ROLES = {'endogenous','endogenous','endogenous','endogenous'};  % ← EDITAR

Cfg.SCALE_FACTOR = 1;      % ← EDITAR: 1 (ya en %) | 100 (en logaritmos)

% =========================================================================
%  SECCIÓN 2 — MODELO VAR                                     ← EDITAR
% =========================================================================
Cfg.NLAG         = 4;      % ← EDITAR
Cfg.NEX          = 1;
Cfg.HORIZON      = 20;     % ← EDITAR
Cfg.INDEX_FEVD   = 20;     % ← EDITAR

% =========================================================================
%  SECCIÓN 3 — MUESTREO                                       ← EDITAR
% =========================================================================
Cfg.MODE           = 'is';
Cfg.ND             = 500;          % draws candidatos. Producción: 5000+
Cfg.MAX_IS_DRAWS   = 500;          % draws efectivos tras resampling IS
Cfg.CONJUGATE      = 'structural'; % 'structural' recomendado para IS con zeros
Cfg.SEED           = 0;

% =========================================================================
%  SECCIÓN 4 — RESTRICCIONES DE IDENTIFICACIÓN               ← EDITAR
% =========================================================================
%
%  CONCEPTOS CLAVE (igual que en spec_template_pfa — resumen rápido)
%  ────────────────────────────────────────────────────────────────────────
%  Columna k de L₀ = Shock k.  Fila i de L₀ = Variable i.
%  Variables indexadas según orden en hoja 'varinfo' del xlsx.
%
%  S{k}  →  restricciones de SIGNO sobre el shock k
%  Z{k}  →  restricciones de CERO sobre el shock k   ← novedad respecto a PFA
%    Impone estructura en la matriz L₀ vía el algoritmo IS de ARW (2018).
%    Útil para supuestos de no-contemporaneidad (p.ej.: "la oferta no
%    responde contemporáneamente a la demanda").
%
%  A DIFERENCIA DE PFA, IS SÍ PUEDE RESOLVER VARIOS CHOQUES RESTRINGIDOS
%  EN LA MISMA CORRIDA (S{1}, S{2}, ... y/o Z{1}, Z{2}, ... simultáneos).
%  No hay guard de "un solo choque" en run_is.m — esa limitación es
%  exclusiva de PFA.
%
%  ┌───────────────────────────────────────────────────────────────────┐
%  │ REGLA (Chat 19, Hallazgo 1) — LEE ESTO ANTES DE EDITAR:              │
%  │   Cfg.S y Cfg.Z SIEMPRE se dimensionan a cell(n_vars, 1), sin       │
%  │   importar cuantos shocks tengan restricciones realmente           │
%  │   declaradas. NO uses cell(n_shocks_identificados, 1) — con 6      │
%  │   variables y 4 shocks de interes, sigue siendo cell(6, 1), NO     │
%  │   cell(4, 1). Los shocks sin restriccion simplemente quedan con    │
%  │   Cfg.S{k}/Cfg.Z{k} = [] (celda vacia). Lo exigen internamente     │
%  │   SetupInfo.m, run_pfa.m, run_is.m y                               │
%  │   structural_restrictions_generic.m, todos indexando 1:n_vars.     │
%  └───────────────────────────────────────────────────────────────────┘
%
%  CÓMO SE CONSTRUYE CADA FILA — build_restriction_row.m
%  ────────────────────────────────────────────────────────────────────────
%  Usa la función compartida build_restriction_row.m (vive en
%  refactored/src/) en vez de armar las filas a mano con eye(n_vars):
%
%    row = build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
%
%      var_idx       índice ordinal de la variable (1..n_vars)
%      horizon_idx   índice ORDINAL dentro de Cfg.HORIZONS_RESTRICT (NO es
%                    el valor del horizonte). Ver ejemplo multi-horizonte
%                    más abajo.
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
%    0:H        → en todos los horizontes hasta H
%
%  EJEMPLOS TÍPICOS EN LA LITERATURA
%  ────────────────────────────────────────────────────────────────────────
%    Kilian & Murphy (2012)   → HORIZONS_RESTRICT = 0        (solo impacto)
%    Uhlig (2005)             → HORIZONS_RESTRICT = 0:4      (h=0 a h=4)
%    Mountford & Uhlig (2009) → HORIZONS_RESTRICT = [0 1 2 3]
%
%  ── EJEMPLO 1 — solo impacto (h=0) con signo + cero ──────────────────────
%  Variables (n=4): (1)prod, (2)act, (3)price, (4)inv
%  Shock 1 (oferta):  prod+ en h=0, price- en h=0
%  Shock 2 (demanda): prod NO responde (cero) en h=0
%
%    n_vars = 4;
%    Cfg.HORIZONS_RESTRICT = 0;
%    n_horizons = numel(Cfg.HORIZONS_RESTRICT);   % = 1
%
%    Cfg.S    = cell(n_vars, 1);
%    Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1); ...  % prod+ en h=0
%                 build_restriction_row(3, 1, n_vars, n_horizons, -1) ];   % price- en h=0
%
%    Cfg.Z    = cell(n_vars, 1);
%    Cfg.Z{2} = build_restriction_row(1, 1, n_vars, n_horizons, 1);   % prod=0 en h=0, shock 2
%
%  ── EJEMPLO 2 — multi-horizonte, dos choques restringidos a la vez ───────
%  (esto es exactamente lo que PFA NO puede resolver en una sola corrida —
%  ver LIMITACIÓN DE PFA en spec_template_pfa.m — pero IS sí lo resuelve)
%
%  Mismas 4 variables. HORIZONS_RESTRICT = [0 1]:
%    Shock 1 (oferta):  prod+ en h=0 y h=1
%    Shock 2 (demanda): act+  en h=0 y h=1;  prod=0 en h=0 (cero, shock 2)
%
%    n_vars = 4;
%    Cfg.HORIZONS_RESTRICT = [0 1];               % 2 horizontes declarados
%    n_horizons = numel(Cfg.HORIZONS_RESTRICT);   % = 2
%
%    Cfg.S    = cell(n_vars, 1);
%    Cfg.S{1} = [ ...
%      build_restriction_row(1, 1, n_vars, n_horizons, 1); ...  % prod+ en h=0 (horizon_idx=1)
%      build_restriction_row(1, 2, n_vars, n_horizons, 1) ];    % prod+ en h=1 (horizon_idx=2)
%    Cfg.S{2} = [ ...
%      build_restriction_row(2, 1, n_vars, n_horizons, 1); ...  % act+ en h=0
%      build_restriction_row(2, 2, n_vars, n_horizons, 1) ];    % act+ en h=1
%
%    Cfg.Z    = cell(n_vars, 1);
%    Cfg.Z{2} = build_restriction_row(1, 1, n_vars, n_horizons, 1);  % prod=0 en h=0, shock 2
%
%  NOTA SOBRE IDENTIFICACIÓN PARCIAL
%  ────────────────────────────────────────────────────────────────────────
%  No es necesario identificar TODOS los shocks. Si solo te interesa el
%  shock 1, deja S{2}, S{3}, ... y Z{2}, Z{3}, ... vacíos. El toolkit
%  identifica parcialmente y marginaliza sobre los shocks no restringidos.
%
%  Cada fila de S{k}/Z{k} debe restringir exactamente UNA variable en UN
%  horizonte (no se soportan combinaciones lineales de variables en una
%  sola fila). Ver también build_restriction_row.m para más ejemplos.
%  ── TABLA DE RESTRICCIONES DE ESTE TEMPLATE (reemplaza con las tuyas) ───
%  ┌─────────────┬────────┬──────────┬───────────┬─────────────────────────┐
%  │ Variable    │ Índice │ Shock    │ Horizonte │ Restricción             │
%  ├─────────────┼────────┼──────────┼───────────┼─────────────────────────┤
%  │ var_1       │   1    │ Shock 1  │   h=0     │ SIGNO POSITIVO          │
%  │ var_3       │   3    │ Shock 1  │   h=0     │ SIGNO NEGATIVO          │
%  │ var_1       │   1    │ Shock 2  │   h=0     │ CERO (no responde)      │
%  └─────────────┴────────┴──────────┴───────────┴─────────────────────────┘

% ── Número de variables (Chat 19, Hallazgo 8: auto-derivado de VAR_ROLES) ─
n_vars = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));

Cfg.HORIZONS_RESTRICT = 0;    % ← EDITAR: 0 | [0 1 2] | 0:H
Cfg.NS  = 1;                  % número de shocks identificados
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

% ── Restricciones de CERO — solo IS ─────────────────────────────────────
Cfg.Z    = cell(n_vars, 1);   % inicializar todas vacías
Cfg.Z{2} = build_restriction_row(1, 1, n_vars, n_horizons, 1);   % var_1 CERO ante shock 2, h=0  ← EDITAR
% Cfg.Z{3} = build_restriction_row(2, 1, n_vars, n_horizons, 1); % ejemplo: var_2 CERO ante shock 3

% ── Restricciones de SIGNO ──────────────────────────────────────────────
Cfg.S    = cell(n_vars, 1);   % inicializar todas vacías
Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1); ...  % var_1 POSITIVO en h=0  ← EDITAR
             build_restriction_row(3, 1, n_vars, n_horizons, -1) ];   % var_3 NEGATIVO en h=0  ← EDITAR
% Cfg.S{2} = build_restriction_row(2, 1, n_vars, n_horizons, 1); % ejemplo: var_2 POSITIVO en shock 2

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

Cfg.SPEC_NAME        = 'spec_template_is';  % ← EDITAR
Cfg.SAVE_RESULTS     = false;
Cfg.PLOT_IRFS        = false;
Cfg.ITER_SHOW        = 100;
Cfg.SUMMARY_HORIZONS = [0 1 4 8 12 20];    % ← EDITAR
Cfg.CRED_BANDS       = [0.16 0.84];
Cfg.SHOCK_IDX        = 1;               % escalar | vector | 'all' (Chat 19: ya soporta varios shocks;
                                         %   IS ademas usa este mismo campo para elegir shocks en FEVD)
Cfg.SHOCK_NAMES      = {'shock1', 'shock2'};  % ← EDITAR (Chat 19, Hallazgo 9): uno por shock declarado
Cfg.IRF_TYPE         = 'irf';
Cfg.IRF_NORM         = 'none';
Cfg.MIN_ACCEPT_RATE  = 0.05;  % alerta si tasa de aceptación IS < este umbral

% Cfg.FEVD_HORIZONS (← EDITAR, Chat 19, Hallazgo 6): horizontes en los que
% se calcula la FEVD. Default si no lo defines: Cfg.INDEX_FEVD (un unico
% horizonte). IS puede calcular varios shocks a la vez (ver Cfg.SHOCK_IDX
% arriba, default 'all' si no lo defines) — util para el grafico de barras
% apiladas de plot_fevd.m.
Cfg.FEVD_HORIZONS = 1:Cfg.HORIZON;

Cfg.TIMING_VARIANT   = [];
Cfg.DERIV_SIDED      = 2;


