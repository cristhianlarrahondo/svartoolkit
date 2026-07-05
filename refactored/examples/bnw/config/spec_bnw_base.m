%SPEC_BNW_BASE  Campos comunes de configuracion — proyecto BNW (examples/bnw).
%
%   NO se ejecuta directamente ni se pasa a main.m/pipeline_bnw.m.
%   Se incluye via eval(fileread(...)) desde spec_bnw_pfa.m y spec_bnw_is.m,
%   que deben haber definido la variable `ex_dir` (ruta absoluta a
%   examples/bnw/) ANTES de incluir este archivo. Esto es necesario porque
%   mfilename('fullpath') dentro de un eval() resuelve al archivo que hace
%   el eval (el spec_bnw_pfa/is.m que llama), no a este archivo.
%
%   Replica Figure 1, Panel (a)/(b) de Arias, Rubio-Ramirez y Waggoner (2018).
%   Identificacion: shock de optimismo identificado con
%       - Zero restriction:  IRF de TFP ajustado a horizonte 0 = 0
%       - Sign restriction:  IRF de precios de acciones a horizonte 0 > 0
%
%   Campos que SI sobreescriben spec_bnw_pfa.m / spec_bnw_is.m tras incluir
%   este archivo: MODE, ND, MAX_IS_DRAWS, CONJUGATE, ITER_SHOW, SPEC_NAME.

if ~exist('ex_dir', 'var')
    error('spec_bnw_base:missingExDir', ...
        ['spec_bnw_base.m debe incluirse via eval(fileread(...)) desde un ' ...
         'spec (spec_bnw_pfa.m o spec_bnw_is.m) que ya haya definido la ' ...
         'variable ex_dir (ruta absoluta a examples/bnw/).']);
end

% -- DATOS ---------------------------------------------------------------
% Variables (n=5, en este orden, igual que refactored/data/data_bnw.xlsx):
%   1. tfp   — Adjusted TFP
%   2. sp    — Stock Prices
%   3. cons  — Consumption
%   4. rir   — Real Interest Rate
%   5. hours — Hours
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_bnw.xlsx');
Cfg.VAR_ROLES = {'endogenous','endogenous','endogenous','endogenous','endogenous'};

% -- OUTPUT: siempre relativo a examples/bnw/, NUNCA a refactored/output/ --
Cfg.OUTPUT_DIR = fullfile(ex_dir, 'output');

% -- MODELO ----------------------------------------------------------------
Cfg.NLAG         = 4;        % numero de lags (BNW usan 4)
Cfg.NEX          = 1;        % 1 = incluir constante
Cfg.HORIZON      = 40;       % horizonte maximo para IRFs
Cfg.INDEX_FEVD   = 40;       % horizonte para FEVD
Cfg.SCALE_FACTOR = 100;      % x100 para pasar a log-porcentajes

% -- MUESTREO (semilla comun; MODE/ND/MAX_IS_DRAWS/CONJUGATE se ---------
%    sobreescriben en spec_bnw_pfa.m / spec_bnw_is.m) ---------------------
Cfg.SEED = 0;

% -- RESTRICCIONES ---------------------------------------------------------
% Variables: 1=tfp, 2=sp, 3=cons, 4=rir, 5=hours
% Shock de optimismo:
%   zero restriction: tfp no responde en h=0
%   sign restriction: sp (stock prices) > 0 en h=0
Cfg.HORIZONS_RESTRICT = 0;     % restricciones en horizonte 0
Cfg.NS = 1;                    % vestigial: solo lo usa run_timing.m, no
                               % run_pfa.m/run_is.m. Se mantiene por
                               % compatibilidad con specs de timing.

n_vars     = 5;
n_horizons = numel(Cfg.HORIZONS_RESTRICT);   % = 1 aqui (solo h=0)

% build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
% horizon_idx=1 siempre en este spec porque solo hay un horizonte (h=0)
% declarado en Cfg.HORIZONS_RESTRICT. Con mas horizontes, horizon_idx
% seria la posicion ORDINAL dentro de ese vector, no el valor del horizonte
% (ver build_restriction_row.m para el ejemplo multi-horizonte).
Cfg.Z    = cell(n_vars, 1);
Cfg.Z{1} = build_restriction_row(1, 1, n_vars, n_horizons, 1);   % tfp = 0 en h=0

Cfg.S    = cell(n_vars, 1);
Cfg.S{1} = build_restriction_row(2, 1, n_vars, n_horizons, 1);   % sp positivo en h=0

% -- TIMING (no aplica en PFA/IS) ------------------------------------------
Cfg.TIMING_VARIANT = [];
Cfg.DERIV_SIDED    = 2;

% -- OUTPUT / VISUALIZACION -------------------------------------------------
Cfg.SAVE_RESULTS     = false;
Cfg.PLOT_IRFS        = true;
Cfg.SUMMARY_HORIZONS = [0 4 8 20 40];
Cfg.CRED_BANDS       = [0.16 0.84];
Cfg.SHOCK_IDX        = 1;
Cfg.IRF_TYPE         = 'irf';
Cfg.IRF_NORM         = 'none';

