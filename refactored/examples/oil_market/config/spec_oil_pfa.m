%SPEC_OIL_PFA  Configuración mercado petrolero — modo Penalty Function Approach.
%
%   Caso de uso: Baumeister & Hamilton (2019, AER) — mercado petróleo global.
%   Algoritmo: Arias, Rubio-Ramírez y Waggoner (2018) — PFA.
%   Referencia de identificación: esquema Kilian & Murphy (2012).
%
%   Shock identificado: oferta de petróleo (columna 1 de L₀).
%     - Sign restriction  : prod_growth ≥ 0 en h=0
%     - Sign restriction  : rpo_growth  ≤ 0 en h=0
%     (Para PFA: solo sign restrictions; sin zero restriction.)
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
%   Con p=24 lags, las primeras 24 filas del xlsx se usan como lags iniciales
%   y no entran en Y directamente.
%
%   Este script es ejecutado por main.m via run(cfg_path).
%   Popula la struct Cfg en el workspace del caller.

% -- MODELO ------------------------------------------------------------------
Cfg.NLAG           = 24;       % lags (mensual, 2 años — BH 2019)
Cfg.NEX            = 1;        % 1 = incluir constante
Cfg.HORIZON        = 60;       % horizonte máximo para IRFs (60 meses)
Cfg.INDEX_FEVD     = 60;       % horizonte para FEVD
Cfg.SCALE_FACTOR   = 1;        % datos ya están en % y en escala correcta

% -- MUESTREO ----------------------------------------------------------------
Cfg.MODE           = 'pfa';    % Penalty Function Approach
Cfg.ND             = 500;      % draws para desarrollo/testing
Cfg.MAX_IS_DRAWS   = 500;      % (no aplica en PFA; incluido por completitud)
Cfg.CONJUGATE      = 'irfs';   % 'irfs' | 'structural'
Cfg.SEED           = 0;        % semilla rng

% -- DATOS -------------------------------------------------------------------
% Ruta absoluta calculada relativa a la ubicación de este archivo.
% Nunca se usa pwd, cd, ni '..'.
cfg_dir   = fileparts(mfilename('fullpath'));   % .../examples/oil_market/config/
ex_dir    = fileparts(cfg_dir);                 % .../examples/oil_market/
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_bau.xlsx');

% -- RESTRICCIONES -----------------------------------------------------------
% Variables: 1=prod_growth, 2=act_growth, 3=rpo_growth, 4=dinv
% Shock de oferta de petróleo (columna 1 de L₀):
%   sign: prod_growth ≥ 0 (producción sube ante shock de oferta positivo)
%   sign: rpo_growth  ≤ 0 (precio baja ante shock de oferta positivo)
% En PFA: solo sign restrictions.
Cfg.HORIZONS_RESTRICT = 0;     % restricciones en horizonte 0
Cfg.NS  = 1;                   % número de objetos F(theta) con restricciones

n_vars = 4;
e_id   = eye(n_vars);

% Zero restriction: ninguna en PFA (cell vacías)
Cfg.Z = cell(n_vars, 1);       % todas vacías para PFA

% Sign restrictions: prod_growth > 0 AND rpo_growth < 0 en h=0
% Se combinan en una sola matriz S{1}: filas = restricciones, cols = variables
% Fila 1: e1'  → prod_growth debe ser > 0 (positivo)
% Fila 2: -e3' → -rpo_growth debe ser > 0, i.e. rpo_growth < 0 (negativo)
Cfg.S          = cell(n_vars, 1);
Cfg.S{1}       = [e_id(1,:); -e_id(3,:)];  % S_1: [prod_growth>0; rpo_growth<0]

% -- NOMBRE DE LA SPEC -------------------------------------------------------
Cfg.SPEC_NAME = 'spec_oil_pfa';

% -- TIMING (no aplica en PFA) -----------------------------------------------
Cfg.TIMING_VARIANT = [];
Cfg.DERIV_SIDED    = 2;

% -- OUTPUT ------------------------------------------------------------------
Cfg.SAVE_RESULTS   = false;
Cfg.PLOT_IRFS      = false;    % false para que validate corra sin figuras
Cfg.ITER_SHOW      = 100;

% -- HORIZONTES PARA PRINT_SUMMARY ------------------------------------------
Cfg.SUMMARY_HORIZONS = [0 3 6 12 24 36 48 60];
Cfg.CRED_BANDS       = [0.16 0.84];
Cfg.SHOCK_IDX        = 1;      % shock de oferta = columna 1
