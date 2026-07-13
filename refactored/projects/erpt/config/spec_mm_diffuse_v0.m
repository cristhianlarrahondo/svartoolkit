%SPEC_MM_DIFFUSE_V0  ERPT baseline oficial — m/m, prior diffuse, Opcion B
%
%   Variables (mismo orden posicional que spec_v0.m/spec_v1.m legacy,
%   convencion de NOMBRES nueva confirmada en ERPT-Chat 2/3):
%     1. ner      — Nominal Exchange Rate
%     2. imp_inf  — Imports Inflation
%     3. pro_inf  — Producer Inflation
%     4. con_inf  — Consumer Inflation
%     5. ea       — Economic Activity
%     6. ir       — Interest Rate
%
%   Identificacion (Opcion B, set-identified — igual estructura que
%   spec_v0.m legacy, reindexada por posicion, sin cambios de fondo):
%     Shock 1 (Cam) : signo var1(+)        | cero var6
%     Shock 2 (Dem) : signo var5(+)        | cero var2
%     Shock 3 (Ofe) : signo var4(-)        | cero var2
%   3 choques nombrados + 3 residuales sin restriccion (Cfg.SHOCK_IDX='all').
%   Decision ERPT-Chat 3: NO se agrega 4o choque monetario nombrado.
%
%   Prior: DIFFUSE (NIW impropio, default del toolkit — Cfg.PRIOR no se
%   define). Es la baseline de referencia para comparar contra la variante
%   *_minn_v0 con la MISMA identificacion y los MISMOS datos.
%
%   Dummies COVID (2 pulses: caida + rebote — ver .md de cierre de
%   ERPT-Chat 3 para el analisis de la serie 'ea' que sustenta estas
%   fechas). En m/m el choque es un evento corto y agudo, NO el patron de
%   efecto base de 12 meses que se ve en a/a:
%     covid_drop_mm    : pulse 2020-03 -> 2020-04 (colapso agudo: cuarentena
%                        nacional CO desde 25-mar-2020; abril es el mes
%                        completo de cuarentena estricta, ea=-19.1% m/m)
%     covid_rebound_mm : pulse 2020-05 -> 2020-06 (rebote mecanico de
%                        reapertura; ea=+7.4%/+6.2% m/m, muy por encima
%                        del rango tipico de esos meses en otros anos)
%   Ventanas EXCLUSIVAS de la variante m/m — la variante a/a usa fechas
%   distintas (mismo choque fisico, otro calendario por la transformacion,
%   con ventanas de 12 meses por el efecto base del yoy).
%
%   Este archivo es AUTOCONTENIDO (no hereda de ningun spec_base via
%   eval(fileread(...))) — cada spec_*.m declara su Cfg completo.

% -- Ruta a este proyecto (projects/erpt/), NUNCA pwd/cd/'..' ------------
cfg_dir = fileparts(mfilename('fullpath'));   % .../projects/erpt/config/
ex_dir  = fileparts(cfg_dir);                 % .../projects/erpt/

% -- IDENTIFICADOR DE ESTA SPEC (usado en Cfg.OUTPUT_DIR y en tablas) ----
Cfg.SPEC_NAME = 'spec_mm_diffuse_v0';

% -- DATOS ------------------------------------------------------------------
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_erpt_mm.xlsx');
Cfg.VARS      = {'ner', 'imp_inf', 'pro_inf', 'con_inf', 'ea', 'ir'};
Cfg.VAR_ROLES = {'endogenous','endogenous','endogenous','endogenous','endogenous','endogenous'};

% -- MODELO -------------------------------------------------------------
Cfg.NLAG         = 4;         % numero de lags
Cfg.NEX          = 1;         % 1 = incluir constante
Cfg.HORIZON      = 36;        % horizonte maximo para IRFs
Cfg.INDEX_FEVD   = 36;        % horizonte para FEVD (legado, no usado por FEVD_HORIZONS)
Cfg.SCALE_FACTOR = 1;

% -- MUESTREO -------------------------------------------------------------
Cfg.SEED         = 0;
Cfg.MODE         = 'is';           % unico modo usado en este proyecto (no hay flujo PFA)
Cfg.ND           = 3e5;            % draws ortogonal-reduced-form
Cfg.MAX_IS_DRAWS = 1e5;            % max draws efectivos tras resampling
Cfg.CONJUGATE    = 'structural';   % 'structural' | 'irfs'
Cfg.ITER_SHOW    = 1000;

% -- PRIOR (Chat 12 / build_posterior.m) ---------------------------------
% DIFFUSE: sin Cfg.PRIOR -> NIW impropio (paper original, default del
% toolkit). Deliberadamente NO se define aqui.

% -- DUMMIES EXOGENAS (Chat 13 / build_dummies.m) ------------------------
% Ventanas fijadas a partir de inspeccion directa de la serie 'ea' en
% data_erpt_mm.xlsx (ver .md de cierre ERPT-Chat 3): colapso agudo en
% 2020-03/2020-04 (cuarentena nacional CO), rebote de reapertura en
% 2020-05/2020-06.
Cfg.DUMMIES(1).name       = 'covid_drop_mm';
Cfg.DUMMIES(1).type       = 'pulse';
Cfg.DUMMIES(1).date_start = [2020, 3];
Cfg.DUMMIES(1).date_end   = [2020, 4];

Cfg.DUMMIES(2).name       = 'covid_rebound_mm';
Cfg.DUMMIES(2).type       = 'pulse';
Cfg.DUMMIES(2).date_start = [2020, 5];
Cfg.DUMMIES(2).date_end   = [2020, 6];

% -- RESTRICCIONES (Opcion B, set-identificada) --------------------------
Cfg.HORIZONS_RESTRICT = 0;    % restricciones en horizonte 0

n_vars     = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

Cfg.Z = cell(n_vars, 1);
Cfg.S = cell(n_vars, 1);

% build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
% ── Shock 1: Cam (cambiario / prima de riesgo) ──────────────────────────
Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1) ];
Cfg.Z{1} = [ build_restriction_row(6, 1, n_vars, n_horizons,  1) ];

% ── Shock 2: Dem (demanda domestica) ─────────────────────────────────────
Cfg.S{2} = [ build_restriction_row(5, 1, n_vars, n_horizons,  1) ];
Cfg.Z{2} = [ build_restriction_row(2, 1, n_vars, n_horizons,  1) ];

% ── Shock 3: Ofe (oferta) ─────────────────────────────────────────────────
Cfg.S{3} = [ build_restriction_row(4, 1, n_vars, n_horizons, -1) ];
Cfg.Z{3} = [ build_restriction_row(2, 1, n_vars, n_horizons,  1) ];

% -- OUTPUT: carpeta propia por spec, NUNCA refactored/output/ -----------
Cfg.OUTPUT_DIR = fullfile(ex_dir, 'output', Cfg.SPEC_NAME);

% -- OUTPUT / VISUALIZACION -----------------------------------------------
Cfg.SAVE_RESULTS     = true;
Cfg.PLOT_IRFS        = true;
Cfg.SUMMARY_HORIZONS = [0 4 8 12 18 24];
Cfg.CRED_BANDS       = [0.25 0.75];
Cfg.SHOCK_IDX        = 'all';
Cfg.SHOCK_NAMES      = {'Cam', 'Dem', 'Ofe'};
Cfg.IRF_TYPE         = 'both';   % irf, cirf, both
Cfg.IRF_NORM         = 'none';
Cfg.FEVD_HORIZONS    = 1:Cfg.HORIZON;

% -- ERPT (projects/erpt/src/calculate_erpt.m, ERPT-Chat 2) --------------
Cfg.ERPT_PRICE_VARS = {'imp_inf', 'pro_inf', 'con_inf'};
Cfg.ERPT_DENOM_VAR  = 'ner';
Cfg.ERPT_HORIZONS   = [3 6 12 24 36];
