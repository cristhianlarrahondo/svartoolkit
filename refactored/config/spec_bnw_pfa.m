%SPEC_BNW_PFA  Configuracion BNW - modo Penalty Function Approach.
%
%   Replica Figure 1, Panel (a) de Arias, Rubio-Ramirez y Waggoner (2018).
%   Identificacion: shock de optimismo identificado con
%       - Zero restriction:  IRF de TFP ajustado a horizonte 0 = 0
%       - Sign restriction:  IRF de precios de acciones a horizonte 0 > 0
%
%   Este script es ejecutado por main.m via run(cfg_path).
%   Popula la struct Cfg en el workspace del caller.

% -- MODELO ------------------------------------------------------------------
Cfg.NLAG           = 4;        % numero de lags (BNW usan 4)
Cfg.NEX            = 1;        % 1 = incluir constante
Cfg.HORIZON        = 40;       % horizonte maximo para IRFs
Cfg.INDEX_FEVD     = 40;       % horizonte para FEVD
Cfg.SCALE_FACTOR   = 100;      % x100 para pasar a log-porcentajes

% -- MUESTREO ----------------------------------------------------------------
Cfg.MODE           = 'pfa';    % Penalty Function Approach
Cfg.ND             = 1e4;      % draws ortogonal-reduced-form
Cfg.MAX_IS_DRAWS   = 1e4;      % (no aplica en PFA; incluido por completitud)
Cfg.CONJUGATE      = 'irfs';   % 'irfs' | 'structural'  (BNW usan 'irfs')
Cfg.SEED           = 0;        % semilla rng

% -- RESTRICCIONES -----------------------------------------------------------
% Variables: 1=TFP, 2=StockPrices, 3=Consumption, 4=RealRate, 5=Hours
% Shock de optimismo:
%   zero restriction: TFP no responde en h=0
%   sign restriction: StockPrices > 0 en h=0
Cfg.HORIZONS_RESTRICT = 0;     % restricciones en horizonte 0
Cfg.NS  = 1;                   % numero de objetos F(theta) con restricciones

n_vars  = 5;
e_id    = eye(n_vars);

% Zero restriction: fila 1 de L_0 = 0  (TFP a h=0)
Cfg.Z   = cell(n_vars, 1);
Cfg.Z{1} = e_id(1,:);         % Z_1 = e_1': TFP igual a cero en h=0

% Sign restriction: fila 2 de L_0 > 0  (StockPrices > 0 en h=0)
Cfg.S   = cell(n_vars, 1);
Cfg.S{1} = e_id(2,:);         % S_1 = e_2': StockPrices positivo en h=0

% -- DATOS -------------------------------------------------------------------
Cfg.DATA_FILE = '';            % vacio -> usa data/data_bnw.xlsx del proyecto

% -- TIMING (no aplica en PFA) -----------------------------------------------
Cfg.TIMING_VARIANT = [];
Cfg.DERIV_SIDED    = 2;

% -- OUTPUT ------------------------------------------------------------------
Cfg.SAVE_RESULTS   = false;
Cfg.PLOT_IRFS      = true;
Cfg.ITER_SHOW      = 2000;
