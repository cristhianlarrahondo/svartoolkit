%spec_A_base_mm_diffuse_lag2_v0  ERPT Ejercicio A -- m/m, prior diffuse, lag 2, matriz base
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
%   Matriz de restricciones: BASELINE (base) (D2 de ERPT-Chat 6).
%
%   Prior: DIFFUSE (NIW impropio, default -- Cfg.PRIOR no se define).
%
%   Dummies COVID (m/m): 2 pulses, ventanas de ERPT-Chat 3.
%
%   Este archivo es AUTOCONTENIDO (no hereda de ningun spec_base via
%   eval(fileread(...))) -- declara su Cfg completo.

% -- Ruta a este proyecto (projects/erpt/), NUNCA pwd/cd/'..' ------------
cfg_dir = fileparts(mfilename('fullpath'));   % .../projects/erpt/config/
ex_dir  = fileparts(cfg_dir);                 % .../projects/erpt/

% -- IDENTIFICADOR DE ESTA SPEC (usado en Cfg.OUTPUT_DIR y en tablas) ----
Cfg.SPEC_NAME = 'spec_A_base_mm_diffuse_lag2_v0';

% -- DATOS --------------------------------------------------------------
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_erpt_mm.xlsx');
Cfg.VARS      = {'ner', 'imp_inf', 'pro_inf', 'con_inf', 'ea', 'ir'};
Cfg.VAR_ROLES = {'endogenous','endogenous','endogenous','endogenous','endogenous','endogenous'};

% -- MODELO -------------------------------------------------------------
Cfg.NLAG         = 2;         % numero de lags
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

% -- PRIOR ---------------------------------------------------------------
% DIFFUSE (NIW impropio, default del toolkit). Cfg.PRIOR NO se define --
% es la baseline de referencia contra la variante *_minn correspondiente,
% con la MISMA identificacion y los MISMOS datos.

% -- DUMMIES EXOGENAS (Chat 13 / build_dummies.m) -----------------------
% Ventanas m/m (serie 'ea' en data_erpt_mm.xlsx, ver .md ERPT-Chat 3):
% colapso agudo 2020-03/2020-04, rebote de reapertura 2020-05/2020-06.
Cfg.DUMMIES(1).name       = 'covid_drop_mm';
Cfg.DUMMIES(1).type       = 'pulse';
Cfg.DUMMIES(1).date_start = [2020, 3];
Cfg.DUMMIES(1).date_end   = [2020, 4];

Cfg.DUMMIES(2).name       = 'covid_rebound_mm';
Cfg.DUMMIES(2).type       = 'pulse';
Cfg.DUMMIES(2).date_start = [2020, 5];
Cfg.DUMMIES(2).date_end   = [2020, 6];

% -- RESTRICCIONES (Opcion B, set-identificada -- matriz base) ---
Cfg.HORIZONS_RESTRICT = 0;    % restricciones en horizonte 0

n_vars     = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

Cfg.Z = cell(n_vars, 1);
Cfg.S = cell(n_vars, 1);

% build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
% -- Shock 1: Cam (cambiario / prima de riesgo) : ner(+) | ea=0, ir=0 -----
Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1) ];
Cfg.Z{1} = [ build_restriction_row(5, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1) ];

% -- Shock 2: Dem (demanda) : pro(+), con(+), ea(+) ----------------------
Cfg.S{2} = [ build_restriction_row(3, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(4, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1) ];
Cfg.Z{2} = [];

% -- Shock 3: Ofe (oferta) : pro(-), con(-), ea(+) -----------------------
Cfg.S{3} = [ build_restriction_row(3, 1, n_vars, n_horizons, -1); ...
             build_restriction_row(4, 1, n_vars, n_horizons, -1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1) ];
Cfg.Z{3} = [];

% -- Shock 4: Mon (monetario contractivo) : pro(-), con(-), ea(-), ir(+) -
Cfg.S{4} = [ build_restriction_row(3, 1, n_vars, n_horizons, -1); ...
             build_restriction_row(4, 1, n_vars, n_horizons, -1); ...
             build_restriction_row(5, 1, n_vars, n_horizons, -1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1) ];
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
Cfg.SHOCK_NAMES      = {'Cam', 'Dem', 'Ofe', 'Mon'};
Cfg.IRF_TYPE         = 'both';   % irf, cirf, both
Cfg.IRF_NORM         = 'none';
Cfg.FEVD_HORIZONS    = 1:Cfg.HORIZON;

% -- ERPT (projects/erpt/src/calculate_erpt.m) --------------------------
Cfg.ERPT_PRICE_VARS = {'imp_inf', 'pro_inf', 'con_inf'};
Cfg.ERPT_DENOM_VAR  = 'ner';
Cfg.ERPT_HORIZONS   = [3 6 12 24 36];
