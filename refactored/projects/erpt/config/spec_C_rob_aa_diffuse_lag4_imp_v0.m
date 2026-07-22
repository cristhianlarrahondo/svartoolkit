%spec_C_rob_aa_diffuse_lag4_imp_v0  ERPT Ejercicio C -- sistema IMPORTS
%   (5 variables), a/a, prior diffuse, lag 4, matriz rob.
%
%   ERPT-Chat 19 (Tipo S). Uno de los 3 sistemas de 5 variables del
%   Ejercicio C, disenados en ERPT-Chat 18 (Discusion, APROBADO). Cada
%   sistema aisla UNA variable de inflacion (aqui imp_inf) en lugar de
%   estimar las tres conjuntamente como en la ganadora del Ejercicio A.
%
%   Variables endogenas (Cfg.VARS), orden posicional:
%     1. ner      -- Nominal Exchange Rate
%     2. imp_inf  -- Imports Inflation   (LIBRE en todos los choques)
%     3. ea       -- Economic Activity
%     4. ir       -- Interest Rate
%     5. tot      -- Terms of Trade
%
%   Identificacion: Opcion B (set-identificada), Cfg.MODE='is'. 3 choques
%   nombrados {Cam, Ofe, Dem} + 2 residuales sin restriccion
%   (Cfg.SHOCK_IDX='all'). Orden por conteo de ceros DESCENDENTE (condicion
%   de regularidad ARW): Cam=1 (3 ceros), Ofe=2 (2 ceros), Dem=3 (1 cero).
%
%   ── Asimetria NER-Oferta (decision DC-4 de ERPT-Chat 18, Opcion 1) ──────
%   imp_inf es la variable de pass-through: se deja LIBRE bajo todos los
%   choques (no se le impone signo). Esto deja al choque de Oferta sin
%   contenido de signo sobre el precio en este sistema; para preservar su
%   identificacion se impone ner(+)=0 en h=0 bajo Ofe -- la restriccion de
%   impacto-cero ner⊥Ofe. Esta restriccion se aplica UNICAMENTE en el
%   sistema de imports (no en pro ni con), donde el precio SI recibe signo
%   bajo Ofe (con-) o queda libre por diseno (pro). De ahi la asimetria.
%
%   Conteo de ceros resultante (n=5):
%     Cam : 3 ceros (ea, ir, tot)
%     Ofe : 2 ceros (ner, tot)      <- incluye la asimetria ner⊥Ofe
%     Dem : 1 cero  (tot)
%     residuales 4,5: 0 ceros
%   Orden por conteo descendente 3,2,1,0,0 -- zeros_j <= n-j: 3<=4, 2<=3,
%   1<=2, 0<=1, 0<=0. Regularidad ARW satisfecha.
%
%   Prior: DIFFUSE (NIW impropio, default -- Cfg.PRIOR no se define).
%   Transform: a/a. Lags: 4. Dummies COVID: 2 pulses a/a (ventanas
%   ERPT-Chat 3, identicas a la ganadora). ND=1e6 (corrida unica de
%   robustez, mismo criterio que spec_B/ERPT-Chat 17; la ganadora del
%   Ejercicio A esta a ND=3e5 por su cascada de seleccion -- este spec no
%   pasa por cascada, va directo al ND cientifico).
%
%   Este archivo es AUTOCONTENIDO (no hereda de ningun spec_base via
%   eval(fileread(...))) -- declara su Cfg completo.

% -- Ruta a este proyecto (projects/erpt/), NUNCA pwd/cd/'..' ------------
cfg_dir = fileparts(mfilename('fullpath'));   % .../projects/erpt/config/
ex_dir  = fileparts(cfg_dir);                 % .../projects/erpt/

% -- IDENTIFICADOR DE ESTA SPEC (usado en Cfg.OUTPUT_DIR y en tablas) ----
Cfg.SPEC_NAME = 'spec_C_rob_aa_diffuse_lag4_imp_v0';

% -- DATOS --------------------------------------------------------------
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_erpt_aa.xlsx');
Cfg.VARS      = {'ner', 'imp_inf', 'ea', 'ir', 'tot'};
Cfg.VAR_ROLES = {'endogenous','endogenous','endogenous','endogenous','endogenous'};

% -- MODELO -------------------------------------------------------------
Cfg.NLAG         = 4;         % numero de lags (identico a la ganadora)
Cfg.NEX          = 1;         % 1 = incluir constante
Cfg.HORIZON      = 36;        % horizonte maximo para IRFs
Cfg.INDEX_FEVD   = 36;        % horizonte para FEVD (legado)
Cfg.SCALE_FACTOR = 1;

% -- MUESTREO -----------------------------------------------------------
Cfg.SEED         = 0;
Cfg.MODE         = 'is';           % unico modo del proyecto (no hay flujo PFA)
Cfg.ND           = 1e6;            % ND cientifico final (corrida unica de robustez)
Cfg.MAX_IS_DRAWS = 1e5;            % max draws efectivos tras resampling
Cfg.CONJUGATE    = 'structural';   % 'structural' | 'irfs'
Cfg.ITER_SHOW    = 1000;

% -- PRIOR ---------------------------------------------------------------
% DIFFUSE (NIW impropio, default del toolkit). Cfg.PRIOR NO se define --
% identico a la spec ganadora del Ejercicio A.

% -- DUMMIES EXOGENAS (Chat 13 / build_dummies.m) -----------------------
% Ventanas a/a (serie 'ea' en data_erpt_aa.xlsx, ver .md ERPT-Chat 3):
% colapso 2020-03->2021-02 y rebote mecanico por efecto base 2021-03->2022-02.
Cfg.DUMMIES(1).name       = 'covid_drop_aa';
Cfg.DUMMIES(1).type       = 'pulse';
Cfg.DUMMIES(1).date_start = [2020, 3];
Cfg.DUMMIES(1).date_end   = [2021, 2];

Cfg.DUMMIES(2).name       = 'covid_rebound_aa';
Cfg.DUMMIES(2).type       = 'pulse';
Cfg.DUMMIES(2).date_start = [2021, 3];
Cfg.DUMMIES(2).date_end   = [2022, 2];

% -- RESTRICCIONES (Opcion B, set-identificada -- matriz rob) ------------
Cfg.HORIZONS_RESTRICT = 0;    % restricciones en horizonte 0

n_vars     = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));   % = 5
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

Cfg.Z = cell(n_vars, 1);
Cfg.S = cell(n_vars, 1);

% build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
% Indices: 1=ner, 2=imp_inf, 3=ea, 4=ir, 5=tot.
% -- Shock 1: Cam : ner(+) | ea=0, ir=0, tot=0  (3 ceros) ---------------
Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1) ];
Cfg.Z{1} = [ build_restriction_row(3, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(4, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1) ];

% -- Shock 2: Ofe : ea(+) | ner=0, tot=0  (2 ceros; ner=0 = asimetria) --
Cfg.S{2} = [ build_restriction_row(3, 1, n_vars, n_horizons,  1) ];
Cfg.Z{2} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1) ];

% -- Shock 3: Dem : ea(+), ir(+) | tot=0  (1 cero) ----------------------
Cfg.S{3} = [ build_restriction_row(3, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(4, 1, n_vars, n_horizons,  1) ];
Cfg.Z{3} = [ build_restriction_row(5, 1, n_vars, n_horizons,  1) ];

% -- Shocks 4, 5: residuales sin restriccion (quedan [] por cell init) --
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
Cfg.SHOCK_NAMES      = {'Cam', 'Ofe', 'Dem'};   % orden por conteo de ceros desc.
Cfg.IRF_TYPE         = 'both';   % irf, cirf, both
Cfg.IRF_NORM         = 'none';
Cfg.FEVD_HORIZONS    = 1:Cfg.HORIZON;

% -- ERPT (projects/erpt/src/calculate_erpt.m) --------------------------
Cfg.ERPT_PRICE_VARS = {'imp_inf'};   % una sola variable de precio por sistema
Cfg.ERPT_DENOM_VAR  = 'ner';
Cfg.ERPT_HORIZONS   = [3 6 12 24 36];
