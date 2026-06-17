%SPEC_TEMPLATE_PFA  Plantilla de configuración — modo PFA (Penalty Function Approach).
%
%   CÓMO USAR ESTA PLANTILLA
%   ─────────────────────────────────────────────────────────────────────
%   1. Copia esta carpeta template/ completa a examples/mi_caso/
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
%  HAY DOS TIPOS DE RESTRICCIONES:
%
%  S{k}  →  restricciones de SIGNO sobre el shock k
%    Cada fila de S{k} selecciona UNA variable y dice si responde
%    positiva o negativamente al shock k.
%    Fila  [0 ... 1 ... 0]  →  variable i responde POSITIVAMENTE
%    Fila  [0 ... -1 ... 0] →  variable i responde NEGATIVAMENTE
%    (el 1 o -1 está en la posición i; el resto son ceros)
%
%  Z{k}  →  restricciones de CERO sobre el shock k
%    Cada fila de Z{k} selecciona UNA variable cuya respuesta al shock k
%    es exactamente 0.
%    Fila  [0 ... 1 ... 0]  →  variable i tiene respuesta CERO al shock k
%    (solo aplica en modo IS; en PFA Z debe dejarse vacío)
%
%  HORIZONTE DE LAS RESTRICCIONES
%  ────────────────────────────────────────────────────────────────────────
%  Cfg.HORIZONS_RESTRICT define en qué horizontes aplican S y Z:
%    0          → solo en h=0 (restricción de impacto — lo más común)
%    [0 1 2]    → en h=0, h=1 y h=2 simultáneamente
%    0:3        → en h=0 hasta h=3
%    0:H        → en todos los horizontes hasta H
%
%  IMPORTANTE: S{k} y Z{k} aplican en TODOS los horizontes listados.
%  Si necesitas distintas restricciones por horizonte (p.ej. signo en h=0
%  pero no en h=3), debes crear specs separadas.
%
%  Ejemplos típicos en la literatura:
%    Kilian & Murphy (2012)   → HORIZONS_RESTRICT = 0        (solo impacto)
%    Uhlig (2005)             → HORIZONS_RESTRICT = 0:4      (h=0 a h=4)
%    Mountford & Uhlig (2009) → HORIZONS_RESTRICT = [0 1 2 3]
%
%  CÓMO CONSTRUIR S{k} Y Z{k} PASO A PASO
%  ────────────────────────────────────────────────────────────────────────
%  Supón que tienes n=3 variables: (1) prod, (2) act, (3) price
%  y quieres identificar el shock de oferta (shock 1, columna 1 de L₀).
%
%  Restricciones económicas:
%    "prod responde positivamente al shock de oferta en h=0"
%    "price responde negativamente al shock de oferta en h=0"
%
%  Traducción a código:
%    n_vars = 3;
%    e = eye(n_vars);
%    S{1} = [ e(1,:)  ];   % prod positivo  → fila con 1 en posición 1
%    S{1} = [ S{1}; -e(3,:) ];  % price negativo → fila con -1 en posición 3
%    % Resultado: S{1} = [1 0 0; 0 0 -1]
%
%  Para una variable SIN restricción de signo: simplemente no la incluyas.
%  Para el shock k SIN restricciones: deja S{k} = [] (celda vacía).
%
%  ── EJEMPLO COMPLETO: 2 shocks con restricciones distintas ───────────────
%  Variables: (1)prod, (2)act, (3)price, (4)inv  →  n=4
%  Shock 1 (oferta):   prod≥0 en h=0, price≤0 en h=0
%  Shock 2 (demanda):  act≥0 en h=[0,1,2], price≥0 en h=[0,1,2]
%
%  n_vars = 4; e = eye(n_vars);
%  Cfg.HORIZONS_RESTRICT = 0;    % para shock 1
%  % (nota: HORIZONS_RESTRICT es global; si los shocks tienen horizontes
%  %  distintos, crea specs separadas)
%  S{1} = [e(1,:); -e(3,:)];    % prod+, price-
%  S{2} = [e(2,:);  e(3,:)];    % act+,  price+
%  Z{1} = [];  Z{2} = [];       % sin zeros en PFA
%  ─────────────────────────────────────────────────────────────────────────

% ── Número de variables (ajustar según tu dataset) ──────────────────────
n_vars = 4;          % ← EDITAR: número de variables endógenas
e      = eye(n_vars);

% ── Horizonte de las restricciones ──────────────────────────────────────
Cfg.HORIZONS_RESTRICT = 0;    % ← EDITAR: 0 | [0 1 2] | 0:H
Cfg.NS  = 1;                  % número de shocks identificados

% ── Restricciones de CERO — vacías en PFA ───────────────────────────────
Cfg.Z = cell(n_vars, 1);      % todas vacías — no tocar en PFA

% ── Restricciones de SIGNO — EDITAR según tu modelo ─────────────────────
%
%  Tabla de restricciones (reemplaza con las tuyas):
%  ┌─────────────┬────────┬────────────┬──────────────────────────────────┐
%  │ Variable    │ Índice │ Shock      │ Restricción                      │
%  ├─────────────┼────────┼────────────┼──────────────────────────────────┤
%  │ var_1       │   1    │ Shock 1    │ POSITIVO en h=0                  │
%  │ var_3       │   3    │ Shock 1    │ NEGATIVO en h=0                  │
%  └─────────────┴────────┴────────────┴──────────────────────────────────┘
%
Cfg.S         = cell(n_vars, 1);
Cfg.S{1}      = [ e(1,:);    % var_1 responde POSITIVAMENTE al shock 1  ← EDITAR
                 -e(3,:) ];  % var_3 responde NEGATIVAMENTE al shock 1  ← EDITAR
% Cfg.S{2}   = [];           % shock 2 sin restricciones (descomentar si aplica)

% =========================================================================
%  SECCIÓN 5 — OUTPUT Y VISUALIZACIÓN
% =========================================================================
Cfg.SPEC_NAME        = 'spec_template_pfa';  % ← EDITAR nombre de tu spec
Cfg.SAVE_RESULTS     = false;   % true → guarda .mat en output/results/
Cfg.PLOT_IRFS        = false;   % controlado desde pipeline_template.m
Cfg.ITER_SHOW        = 100;
Cfg.SUMMARY_HORIZONS = [0 1 4 8 12 20];  % ← EDITAR horizontes para print_summary
Cfg.CRED_BANDS       = [0.16 0.84];      % bandas de credibilidad [16%, 84%]
Cfg.SHOCK_IDX        = 1;               % índice del shock identificado
Cfg.IRF_TYPE         = 'irf';           % 'irf' | 'cirf' | 'both'
Cfg.IRF_NORM         = 'none';          % 'none' | '1sd' | 'unit' | 'own_unit'

% Parámetros internos (no modificar)
Cfg.TIMING_VARIANT = [];
Cfg.DERIV_SIDED    = 2;
