%SPEC_AA_DIFFUSE_V0  ERPT baseline oficial — a/a, prior diffuse, Opcion B
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
%   Dummies COVID (2 pulses: caida + rebote mecanico por efecto base —
%   ver .md de cierre de ERPT-Chat 3 para el analisis de la serie 'ea'
%   que sustenta estas fechas):
%     covid_drop_aa    : pulse 2020-03 -> 2021-02 (colapso en terminos a/a;
%                        el mes bajo de 2020 esta en el numerador del yoy)
%     covid_rebound_aa : pulse 2021-03 -> 2022-02 (rebote MECANICO por
%                        efecto base; el mes bajo de 2020 pasa al
%                        denominador del yoy exactamente 12 meses despues)
%   Ventanas EXCLUSIVAS de la variante a/a — la variante m/m usa fechas
%   distintas (mismo choque fisico, otro calendario por la transformacion).
%
%   Este archivo es AUTOCONTENIDO (no hereda de ningun spec_base via
%   eval(fileread(...))) — cada spec_*.m declara su Cfg completo.

% -- Ruta a este proyecto (projects/erpt/), NUNCA pwd/cd/'..' ------------
cfg_dir = fileparts(mfilename('fullpath'));   % .../projects/erpt/config/
ex_dir  = fileparts(cfg_dir);                 % .../projects/erpt/

% -- IDENTIFICADOR DE ESTA SPEC (usado en Cfg.OUTPUT_DIR y en tablas) ----
Cfg.SPEC_NAME = 'spec_aa_diffuse_v0';

% -- DATOS ------------------------------------------------------------------
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_erpt_aa.xlsx');
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
% data_erpt_aa.xlsx (ver .md de cierre ERPT-Chat 3): colapso claro desde
% 2020-03 (cuarentena nacional CO, 25-mar-2020) hasta 2021-02, seguido de
% un rebote mecanico por efecto base de 2021-03 a 2022-02 (mismo mes base
% bajo, ahora en el denominador del a/a).
Cfg.DUMMIES(1).name       = 'covid_drop_aa';
Cfg.DUMMIES(1).type       = 'pulse';
Cfg.DUMMIES(1).date_start = [2020, 3];
Cfg.DUMMIES(1).date_end   = [2021, 2];

Cfg.DUMMIES(2).name       = 'covid_rebound_aa';
Cfg.DUMMIES(2).type       = 'pulse';
Cfg.DUMMIES(2).date_start = [2021, 3];
Cfg.DUMMIES(2).date_end   = [2022, 2];

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
