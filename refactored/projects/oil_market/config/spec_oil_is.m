%SPEC_OIL_IS  Configuración mercado petrolero — modo Importance Sampler (IS).
%
%   Caso de uso: Baumeister & Hamilton (2019, AER) — mercado petróleo global.
%   Algoritmo: Arias, Rubio-Ramírez y Waggoner (2018) — IS (Algoritmo 3).
%   Referencia de identificación: esquema Kilian & Murphy (2012).
%
%   Shock identificado: oferta de petróleo (columna 1 de L₀).
%     - Sign restriction : prod_growth ≥ 0 en h=0
%     - Sign restriction : rpo_growth  ≤ 0 en h=0
%     - Zero restriction : prod_growth no responde a act_growth en h=0
%       (fila 1, columna 2 de L₀ = 0; i.e., la oferta no responde
%        contemporáneamente a la actividad económica)
%
%   Variables (n=4, en este orden):
%     1. prod_growth — 100×Δlog(producción mundial de petróleo)
%     2. act_growth  — 100×Δlog(índice IP OECD+6)
%     3. rpo_growth  — 100×Δlog(precio real WTI)
%     4. dinv        — 100×Δinventarios / producción período anterior
%
%   Muestra efectiva: 1973M2–2016M12 (T=527).
%   El archivo data_bau.xlsx contiene datos desde 1971M2 (necesarios para
%   construir los 24 lags de la primera observación efectiva 1973M2).
%
%   Este script es ejecutado por main.m via run(cfg_path).
%   Popula la struct Cfg en el workspace del caller.

% -- MODELO ------------------------------------------------------------------
Cfg.NLAG           = 24;           % lags (mensual, 2 años — BH 2019)
Cfg.NEX            = 1;            % 1 = incluir constante
Cfg.HORIZON        = 60;           % horizonte máximo para IRFs (60 meses)
Cfg.INDEX_FEVD     = 60;           % horizonte para FEVD
Cfg.SCALE_FACTOR   = 1;            % datos ya en escala correcta

% -- MUESTREO ----------------------------------------------------------------
Cfg.MODE           = 'is';         % Importance Sampler (Algoritmo 3)
Cfg.ND             = 500;          % draws para desarrollo/testing
Cfg.MAX_IS_DRAWS   = 500;          % max draws efectivos IS tras resampling
Cfg.CONJUGATE      = 'structural'; % 'structural' | 'irfs'
Cfg.SEED           = 0;            % semilla rng

% -- DATOS -------------------------------------------------------------------
% Ruta absoluta calculada relativa a la ubicación de este archivo.
% Nunca se usa pwd, cd, ni '..'.
cfg_dir   = fileparts(mfilename('fullpath'));   % .../projects/oil_market/config/
ex_dir    = fileparts(cfg_dir);                 % .../projects/oil_market/
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_bau.xlsx');

% -- RESTRICCIONES -----------------------------------------------------------
% Variables: 1=prod_growth, 2=act_growth, 3=rpo_growth, 4=dinv
% Shock de oferta de petróleo (columna 1 de L₀):
%
%   Zero restriction: la oferta no responde contemporáneamente a actividad.
%     → Elemento (1,2) de L₀ = 0
%     → e1' · L₀ · e2 = 0, donde e2 selecciona la columna 2 (act_growth)
%     En la parametrización ARW: Z{k} actúa sobre la k-ésima columna de L₀.
%     Z{2} = e1' impone que la respuesta de prod_growth al shock 2 = 0.
%     Pero aquí lo que queremos es que en el primer shock (col 1), la restricción
%     sea que prod_growth no responde a act_growth (shock 2) en h=0.
%     Equivalentemente: Ltilde(h=0, var=1, shock=2) = 0
%     En la notación del toolkit IS: Z{2} = e1' (fila 1 de L₀, col 2 = 0).
%
%   Sign restrictions: ídem PFA.
Cfg.HORIZONS_RESTRICT = 0;     % restricciones en horizonte 0
Cfg.NS  = 1;                   % número de objetos F(theta)

n_vars = 4;
e_id   = eye(n_vars);

% Zero restriction: prod_growth no responde a act_growth en h=0
% Z{2}: restringe la columna 2 del shock → fila 1 de esa columna = 0
Cfg.Z         = cell(n_vars, 1);
Cfg.Z{2}      = e_id(1,:);    % Z_2 = e1': prod_growth = 0 ante shock 2 en h=0

% Sign restrictions: prod_growth > 0 y rpo_growth < 0 ante shock de oferta (col 1)
Cfg.S         = cell(n_vars, 1);
Cfg.S{1}      = [e_id(1,:); -e_id(3,:)];  % S_1: [prod_growth>0; rpo_growth<0]

% -- NOMBRE DE LA SPEC -------------------------------------------------------
Cfg.SPEC_NAME = 'spec_oil_is';

% -- TIMING (no aplica en IS) ------------------------------------------------
Cfg.TIMING_VARIANT = [];
Cfg.DERIV_SIDED    = 2;

% -- OUTPUT ------------------------------------------------------------------
% Cfg.OUTPUT_DIR — FIX Chat 19 (ítem de máxima prioridad, ausente hasta
% ahora): sin este campo, plot_irfs.m/plot_fevd.m/export_results.m
% escribían en el folder legado refactored/output/ compartido entre
% TODOS los proyectos, en vez de projects/oil_market/output/
% (autocontenido, como ya hace projects/bnw/).
Cfg.OUTPUT_DIR     = fullfile(ex_dir, 'output');
Cfg.SAVE_RESULTS   = false;
Cfg.PLOT_IRFS      = false;    % false para que validate corra sin figuras
Cfg.ITER_SHOW      = 100;

% -- HORIZONTES PARA PRINT_SUMMARY ------------------------------------------
Cfg.SUMMARY_HORIZONS = [0 3 6 12 24 36 48 60];
Cfg.CRED_BANDS       = [0.16 0.84];
Cfg.SHOCK_IDX        = 1;      % shock de oferta = columna 1

% -- ALERTA DE TASA DE ACEPTACIÓN --------------------------------------------
Cfg.MIN_ACCEPT_RATE = 0.05;    % umbral bajo por restricciones moderadas


