%spec_A_rob_aa_minn_lag4_v0  ERPT Ejercicio A -- a/a, prior minnesota, lag 4, matriz rob
%
%   ERPT-Chat 7 (Tipo S). Uno de los 16 specs del Ejercicio A, disenados en
%   ERPT-Chat 6 (Discusion, APROBADO). Reemplaza las 4 baselines legacy
%   (spec_aa/mm_diffuse/minn_v0) como antecedente metodologico.
%
%   Variables endogenas (Cfg.VARS), orden posicional:
%     1. ner      -- Nominal Exchange Rate
%     2. imp_inf  -- Imports Inflation   (LIBRE en todos los choques -- D2)
%     3. pro_inf  -- Producer Inflation
%     4. con_inf  -- Consumer Inflation
%     5. ea       -- Economic Activity
%     6. ir       -- Interest Rate
%
%   Identificacion: Opcion B (set-identificada), Cfg.MODE='is'. 4 choques
%   nombrados {Cam, Dem, Ofe, Mon} + 2 residuales sin restriccion
%   (Cfg.SHOCK_IDX='all'). Orden por conteo de ceros descendente (condicion
%   de regularidad ARW): Cam=1 (2 ceros), Dem=2, Ofe=3, Mon=4 (0 ceros).
%   Reversion deliberada de ERPT-Chat 3 (D5): se agrega el 4o choque Mon.
%   imp_inf (var 2) queda libre en todos -- elimina los imp_inf=0 legacy.
%
%   Matriz de restricciones: ROBUSTEZ (rob) (D2 de ERPT-Chat 6).
%
%   Prior: MINNESOTA con lambda1=0.1, lambda2=0.5, lambda3=2 (D3).
%
%   Dummies COVID (a/a): 2 pulses, ventanas de ERPT-Chat 3.
%
%   Este archivo es AUTOCONTENIDO (no hereda de ningun spec_base via
%   eval(fileread(...))) -- declara su Cfg completo.

% -- Ruta a este proyecto (projects/erpt/), NUNCA pwd/cd/'..' ------------
cfg_dir = fileparts(mfilename('fullpath'));   % .../projects/erpt/config/
ex_dir  = fileparts(cfg_dir);                 % .../projects/erpt/

% -- IDENTIFICADOR DE ESTA SPEC (usado en Cfg.OUTPUT_DIR y en tablas) ----
Cfg.SPEC_NAME = 'spec_A_rob_aa_minn_lag4_v0';

% -- DATOS --------------------------------------------------------------
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_erpt_aa.xlsx');
Cfg.VARS      = {'ner', 'imp_inf', 'pro_inf', 'con_inf', 'ea', 'ir'};
Cfg.VAR_ROLES = {'endogenous','endogenous','endogenous','endogenous','endogenous','endogenous'};

% -- MODELO -------------------------------------------------------------
Cfg.NLAG         = 4;         % numero de lags
Cfg.NEX          = 1;         % 1 = incluir constante
Cfg.HORIZON      = 36;        % horizonte maximo para IRFs
Cfg.INDEX_FEVD   = 36;        % horizonte para FEVD (legado)
Cfg.SCALE_FACTOR = 1;

% -- MUESTREO -----------------------------------------------------------
Cfg.SEED         = 0;
Cfg.MODE         = 'is';           % unico modo del proyecto (no hay flujo PFA)
Cfg.ND           = 3e5;            % draws ortogonal-reduced-form (cientifico)
Cfg.MAX_IS_DRAWS = 1e5;            % max draws efectivos tras resampling
Cfg.CONJUGATE    = 'structural';   % 'structural' | 'irfs'
Cfg.ITER_SHOW    = 1000;

% -- PRIOR (Chat 12 / build_posterior.m) --------------------------------
% Minnesota con hiperparametros de D3 (ERPT-Chat 6), uniformes en los 8
% specs minnesota: lambda3 1->2 (amortigua dinamica de lags altos),
% lambda1 0.2->0.1 (menor tightness, dato mensual volatil), lambda2 sin
% cambio. Ajuste a priori (no dirigido al resultado) -- ver .md ERPT-Chat 6.
Cfg.PRIOR.type    = 'minnesota';
Cfg.PRIOR.lambda1 = 0.1;   % tightness
Cfg.PRIOR.lambda2 = 0.5;   % mezcla own/cross-variable
Cfg.PRIOR.lambda3 = 2;     % lag decay

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

% -- RESTRICCIONES (Opcion B, set-identificada -- matriz rob) ---
Cfg.HORIZONS_RESTRICT = 0;    % restricciones en horizonte 0

n_vars     = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

Cfg.Z = cell(n_vars, 1);
Cfg.S = cell(n_vars, 1);

% build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
% -- Shock 1: Cam (identico a base) : ner(+) | ea=0, ir=0 ----------------
Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1) ];
Cfg.Z{1} = [ build_restriction_row(5, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1) ];

% -- Shock 2: Dem (agrega ir+ vs base) : pro(+), con(+), ea(+), ir(+) ----
Cfg.S{2} = [ build_restriction_row(3, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(4, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1) ];
Cfg.Z{2} = [];

% -- Shock 3: Ofe (libera pro_inf vs base) : con(-), ea(+) ---------------
Cfg.S{3} = [ build_restriction_row(4, 1, n_vars, n_horizons, -1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1) ];
Cfg.Z{3} = [];

% -- Shock 4: Mon -- ELIMINADO de la identificacion (ERPT-Chat 9). Pasa a
%   residual sin restriccion (S{4}/Z{4} vacios); ya no es un choque nombrado.
Cfg.S{4} = [];
Cfg.Z{4} = [];

% -- Shocks 5, 6: residuales sin restriccion (quedan [] por cell init) ---

% -- OUTPUT: carpeta propia por spec, NUNCA refactored/output/ ----------
Cfg.OUTPUT_DIR = fullfile(ex_dir, 'output', Cfg.SPEC_NAME);

% -- OUTPUT / VISUALIZACION ---------------------------------------------
Cfg.SAVE_RESULTS     = true;
Cfg.PLOT_IRFS        = true;
Cfg.SUMMARY_HORIZONS = [0 4 8 12 18 24];
Cfg.CRED_BANDS       = [0.25 0.75];
Cfg.SHOCK_IDX        = 'all';
Cfg.SHOCK_NAMES      = {'Cam', 'Dem', 'Ofe'};
Cfg.IRF_TYPE         = 'both';   % irf, cirf, both
Cfg.IRF_NORM         = 'none';
Cfg.FEVD_HORIZONS    = 1:Cfg.HORIZON;

% -- ERPT (projects/erpt/src/calculate_erpt.m) --------------------------
Cfg.ERPT_PRICE_VARS = {'imp_inf', 'pro_inf', 'con_inf'};
Cfg.ERPT_DENOM_VAR  = 'ner';
Cfg.ERPT_HORIZONS   = [3 6 12 24 36];

