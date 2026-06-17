%SPEC_TEMPLATE_IS  Plantilla de configuración — modo IS (Importance Sampler).
%
%   CUÁNDO USAR IS vs PFA
%   ─────────────────────────────────────────────────────────────────────
%   PFA  → solo restricciones de SIGNO (S). Más rápido, más draws.
%   IS   → restricciones de SIGNO (S) + CERO (Z). Necesitas IS cuando
%           quieres imponer que cierta variable NO responda a cierto shock.
%
%   Este script es ejecutado por pipeline_template.m via run().
%   Popula la struct Cfg en el workspace del caller.

% =========================================================================
%  SECCIÓN 1 — DATOS                                          ← EDITAR
% =========================================================================
cfg_dir       = fileparts(mfilename('fullpath'));
ex_dir        = fileparts(cfg_dir);
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_micaso.xlsx');  % ← EDITAR

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
%    Fila  e(i,:)   →  variable i responde POSITIVAMENTE al shock k
%    Fila -e(i,:)   →  variable i responde NEGATIVAMENTE al shock k
%
%  Z{k}  →  restricciones de CERO sobre el shock k   ← novedad respecto a PFA
%    Fila  e(i,:)   →  variable i tiene respuesta EXACTAMENTE CERO al shock k
%    Impone estructura en la matriz L₀ vía el algoritmo IS de ARW (2018).
%    Útil para supuestos de no-contemporaneidad (p.ej.: "la oferta no
%    responde contemporáneamente a la demanda").
%
%  HORIZONTE DE LAS RESTRICCIONES
%  ────────────────────────────────────────────────────────────────────────
%  Cfg.HORIZONS_RESTRICT define en qué horizontes aplican S y Z:
%    0          → solo en h=0 (restricción de impacto — lo más común)
%    [0 1 2]    → en h=0, h=1 y h=2 simultáneamente
%    0:H        → en todos los horizontes hasta H
%
%  S y Z aplican en TODOS los horizontes listados simultáneamente.
%  Para restricciones distintas por horizonte: crea specs separadas.
%
%  EJEMPLOS TÍPICOS EN LA LITERATURA
%  ────────────────────────────────────────────────────────────────────────
%    Kilian & Murphy (2012)   → HORIZONS_RESTRICT = 0        (solo impacto)
%    Uhlig (2005)             → HORIZONS_RESTRICT = 0:4      (h=0 a h=4)
%    Mountford & Uhlig (2009) → HORIZONS_RESTRICT = [0 1 2 3]
%
%  CÓMO CONSTRUIR S{k} Y Z{k} PASO A PASO
%  ────────────────────────────────────────────────────────────────────────
%  Variables (n=4): (1)prod, (2)act, (3)price, (4)inv
%  Modelo: identificar shock de oferta (shock 1) con:
%    - prod responde positivamente en h=0        → S{1} incluye  e(1,:)
%    - price responde negativamente en h=0       → S{1} incluye -e(3,:)
%    - prod NO responde al shock de actividad    → Z{2} incluye  e(1,:)
%      (i.e., elemento (1,2) de L₀ = 0)
%
%  n_vars = 4; e = eye(n_vars);
%  S{1} = [e(1,:); -e(3,:)];   % prod+, price-  ante shock 1
%  S{2} = [];                  % sin sign restrictions sobre shock 2
%  Z{1} = [];                  % sin zero restrictions en columna 1
%  Z{2} = e(1,:);              % prod tiene respuesta CERO ante shock 2
%
%  NOTA SOBRE IDENTIFICACIÓN PARCIAL
%  ────────────────────────────────────────────────────────────────────────
%  No es necesario identificar TODOS los shocks. Si solo te interesa el
%  shock 1, deja S{2}, S{3}, ... y Z{2}, Z{3}, ... vacíos. El toolkit
%  identifica parcialmente y marginaliza sobre los shocks no restringidos.
%
%  ── TABLA DE RESTRICCIONES DE ESTE TEMPLATE (reemplaza con las tuyas) ───
%  ┌─────────────┬────────┬──────────┬───────────┬─────────────────────────┐
%  │ Variable    │ Índice │ Shock    │ Horizonte │ Restricción             │
%  ├─────────────┼────────┼──────────┼───────────┼─────────────────────────┤
%  │ var_1       │   1    │ Shock 1  │   h=0     │ SIGNO POSITIVO          │
%  │ var_3       │   3    │ Shock 1  │   h=0     │ SIGNO NEGATIVO          │
%  │ var_1       │   1    │ Shock 2  │   h=0     │ CERO (no responde)      │
%  └─────────────┴────────┴──────────┴───────────┴─────────────────────────┘

n_vars = 4;          % ← EDITAR
e      = eye(n_vars);

Cfg.HORIZONS_RESTRICT = 0;    % ← EDITAR: 0 | [0 1 2] | 0:H
Cfg.NS  = 1;                  % número de shocks identificados

% ── Restricciones de CERO — solo IS ─────────────────────────────────────
Cfg.Z         = cell(n_vars, 1);   % inicializar todas vacías
Cfg.Z{2}      = e(1,:);   % var_1 tiene respuesta CERO ante shock 2  ← EDITAR
% Cfg.Z{3}   = e(2,:);   % ejemplo: var_2 tiene respuesta CERO ante shock 3

% ── Restricciones de SIGNO ──────────────────────────────────────────────
Cfg.S         = cell(n_vars, 1);   % inicializar todas vacías
Cfg.S{1}      = [ e(1,:);    % var_1 POSITIVA ante shock 1  ← EDITAR
                 -e(3,:) ];  % var_3 NEGATIVA ante shock 1  ← EDITAR
% Cfg.S{2}   = e(2,:);      % ejemplo: var_2 POSITIVA ante shock 2

% =========================================================================
%  SECCIÓN 5 — OUTPUT Y VISUALIZACIÓN
% =========================================================================
Cfg.SPEC_NAME        = 'spec_template_is';  % ← EDITAR
Cfg.SAVE_RESULTS     = false;
Cfg.PLOT_IRFS        = false;
Cfg.ITER_SHOW        = 100;
Cfg.SUMMARY_HORIZONS = [0 1 4 8 12 20];    % ← EDITAR
Cfg.CRED_BANDS       = [0.16 0.84];
Cfg.SHOCK_IDX        = 1;
Cfg.IRF_TYPE         = 'irf';
Cfg.IRF_NORM         = 'none';
Cfg.MIN_ACCEPT_RATE  = 0.05;  % alerta si tasa de aceptación IS < este umbral

Cfg.TIMING_VARIANT   = [];
Cfg.DERIV_SIDED      = 2;
