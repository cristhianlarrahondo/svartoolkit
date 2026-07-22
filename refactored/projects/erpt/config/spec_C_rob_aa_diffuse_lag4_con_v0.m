%spec_C_rob_aa_diffuse_lag4_con_v0  ERPT Ejercicio C -- sistema CONSUMER
%   (5 variables), a/a, prior diffuse, lag 4, matriz rob.
%
%   ERPT-Chat 19 (Tipo S). Uno de los 3 sistemas de 5 variables del
%   Ejercicio C, disenados en ERPT-Chat 18 (Discusion, APROBADO). Aisla
%   con_inf (inflacion al consumidor) como unica variable de precio.
%
%   Variables endogenas (Cfg.VARS), orden posicional:
%     1. ner      -- Nominal Exchange Rate
%     2. con_inf  -- Consumer Inflation
%     3. ea       -- Economic Activity
%     4. ir       -- Interest Rate
%     5. tot      -- Terms of Trade
%
%   Identificacion: Opcion B (set-identificada), Cfg.MODE='is'. 3 choques
%   nombrados {Cam, Dem, Ofe} + 2 residuales sin restriccion
%   (Cfg.SHOCK_IDX='all'). Orden por conteo de ceros DESCENDENTE (condicion
%   de regularidad ARW): Cam=1 (3 ceros), Dem=2 (1 cero), Ofe=3 (1 cero).
%
%   ── Diseno de signos (ERPT-Chat 18) ────────────────────────────────────
%   Como en el sistema producer, aqui NO se aplica ner⊥Ofe=0. con_inf
%   recibe signo positivo bajo Dem (con+) y signo NEGATIVO bajo Ofe (con-),
%   heredando el contenido economico de la ganadora del Ejercicio A (el
%   choque de Oferta empuja la inflacion al consumidor a la baja). El
%   choque de Oferta se identifica por con(-) y ea(+), con tot=0.
%
%   Conteo de ceros resultante (n=5):
%     Cam : 3 ceros (ea, ir, tot)
%     Dem : 1 cero  (tot)
%     Ofe : 1 cero  (tot)
%     residuales 4,5: 0 ceros
%   Orden por conteo descendente 3,1,1,0,0 -- zeros_j <= n-j: 3<=4, 1<=3,
%   1<=2, 0<=1, 0<=0. Regularidad ARW satisfecha.
%
%   Prior: DIFFUSE (Cfg.PRIOR no se define). Transform: a/a. Lags: 4.
%   Dummies COVID: 2 pulses a/a (ventanas ERPT-Chat 3). ND=1e6 (corrida
%   unica de robustez). Archivo AUTOCONTENIDO.

% -- Ruta a este proyecto (projects/erpt/), NUNCA pwd/cd/'..' ------------
cfg_dir = fileparts(mfilename('fullpath'));   % .../projects/erpt/config/
ex_dir  = fileparts(cfg_dir);                 % .../projects/erpt/

% -- IDENTIFICADOR DE ESTA SPEC (usado en Cfg.OUTPUT_DIR y en tablas) ----
Cfg.SPEC_NAME = 'spec_C_rob_aa_diffuse_lag4_con_v0';

% -- DATOS --------------------------------------------------------------
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_erpt_aa.xlsx');
Cfg.VARS      = {'ner', 'con_inf', 'ea', 'ir', 'tot'};
Cfg.VAR_ROLES = {'endogenous','endogenous','endogenous','endogenous','endogenous'};

% -- MODELO -------------------------------------------------------------
Cfg.NLAG         = 4;
Cfg.NEX          = 1;
Cfg.HORIZON      = 36;
Cfg.INDEX_FEVD   = 36;
Cfg.SCALE_FACTOR = 1;

% -- MUESTREO -----------------------------------------------------------
Cfg.SEED         = 0;
Cfg.MODE         = 'is';
Cfg.ND           = 1e6;
Cfg.MAX_IS_DRAWS = 1e5;
Cfg.CONJUGATE    = 'structural';
Cfg.ITER_SHOW    = 1000;

% -- PRIOR ---------------------------------------------------------------
% DIFFUSE (NIW impropio, default). Cfg.PRIOR NO se define.

% -- DUMMIES EXOGENAS (Chat 13 / build_dummies.m) -----------------------
Cfg.DUMMIES(1).name       = 'covid_drop_aa';
Cfg.DUMMIES(1).type       = 'pulse';
Cfg.DUMMIES(1).date_start = [2020, 3];
Cfg.DUMMIES(1).date_end   = [2021, 2];

Cfg.DUMMIES(2).name       = 'covid_rebound_aa';
Cfg.DUMMIES(2).type       = 'pulse';
Cfg.DUMMIES(2).date_start = [2021, 3];
Cfg.DUMMIES(2).date_end   = [2022, 2];

% -- RESTRICCIONES (Opcion B, set-identificada -- matriz rob) ------------
Cfg.HORIZONS_RESTRICT = 0;

n_vars     = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));   % = 5
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

Cfg.Z = cell(n_vars, 1);
Cfg.S = cell(n_vars, 1);

% build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
% Indices: 1=ner, 2=con_inf, 3=ea, 4=ir, 5=tot.
% -- Shock 1: Cam : ner(+) | ea=0, ir=0, tot=0  (3 ceros) ---------------
Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1) ];
Cfg.Z{1} = [ build_restriction_row(3, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(4, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1) ];

% -- Shock 2: Dem : con(+), ea(+), ir(+) | tot=0  (1 cero) --------------
Cfg.S{2} = [ build_restriction_row(2, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(3, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(4, 1, n_vars, n_horizons,  1) ];
Cfg.Z{2} = [ build_restriction_row(5, 1, n_vars, n_horizons,  1) ];

% -- Shock 3: Ofe : con(-), ea(+) | tot=0  (1 cero) ---------------------
Cfg.S{3} = [ build_restriction_row(2, 1, n_vars, n_horizons, -1); ...
             build_restriction_row(3, 1, n_vars, n_horizons,  1) ];
Cfg.Z{3} = [ build_restriction_row(5, 1, n_vars, n_horizons,  1) ];

% -- Shocks 4, 5: residuales sin restriccion ----------------------------
Cfg.S{4} = []; Cfg.Z{4} = [];
Cfg.S{5} = []; Cfg.Z{5} = [];

% -- OUTPUT: carpeta propia por spec, NUNCA refactored/output/ ----------
Cfg.OUTPUT_DIR = fullfile(ex_dir, 'output', Cfg.SPEC_NAME);

% -- OUTPUT / VISUALIZACION ---------------------------------------------
Cfg.SAVE_RESULTS     = true;
Cfg.PLOT_IRFS        = true;
Cfg.SUMMARY_HORIZONS = [0 4 8 12 18 24];
Cfg.CRED_BANDS       = [0.25 0.75];
Cfg.SHOCK_IDX        = 'all';
Cfg.SHOCK_NAMES      = {'Cam', 'Dem', 'Ofe'};   % orden por conteo de ceros desc.
Cfg.IRF_TYPE         = 'both';
Cfg.IRF_NORM         = 'none';
Cfg.FEVD_HORIZONS    = 1:Cfg.HORIZON;

% -- ERPT (projects/erpt/src/calculate_erpt.m) --------------------------
Cfg.ERPT_PRICE_VARS = {'con_inf'};
Cfg.ERPT_DENOM_VAR  = 'ner';
Cfg.ERPT_HORIZONS   = [3 6 12 24 36];
