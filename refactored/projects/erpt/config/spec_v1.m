%SPEC_V1  ERPT — Identificacion Opcion A (restricciones ampliadas, exactamente identificada)
%
%   Variables (mismo orden que VAR_ROLES):
%     1. ner     — Nominal Exchange Rate
%     2. inf_imp — Imports Inflation
%     3. inf_p   — Producer Inflation
%     4. inf_con — Consumer Inflation
%     5. ise      — Economic Activity
%     6. tib      — Interest Rate
%
%   Identificacion (3 shocks):
%     Shock 1 (Cam) : signos var1(+), var2(+)          | ceros var5, var6
%     Shock 2 (Dem) : signos var4(+), var5(+)          | ceros var2, var6
%     Shock 3 (Ofe) : signo  var4(-)                   | ceros var2, var3, var6
%
%   Condicion de orden ARW: 2, 2, 3 ceros (ordenando de mayor a menor;
%   se necesitan 0,1,2) -> CUMPLE. Exactamente identificada.
%
%   Nota de correccion (respecto a una version previa de esta spec en el
%   repo): Cfg.Z{3} tenia la fila de var2 duplicada en vez de var2+var3.
%   Esta version ya incluye la restriccion correcta sobre var3 (inf_p).
%
%   Este archivo es AUTOCONTENIDO (no hereda de ningun spec_base via
%   eval(fileread(...))) para evitar la circularidad detectada al variar
%   specs. Cada spec_v*.m declara su propio Cfg completo.

% -- Ruta a este proyecto (projects/erpt/), NUNCA pwd/cd/'..' ------------
cfg_dir = fileparts(mfilename('fullpath'));   % .../projects/erpt/config/
ex_dir  = fileparts(cfg_dir);                 % .../projects/erpt/

% -- IDENTIFICADOR DE ESTA SPEC (usado en Cfg.OUTPUT_DIR y en tablas) ----
Cfg.SPEC_NAME = 'spec_v1';

% -- DATOS ------------------------------------------------------------------
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_erpt.xlsx');
Cfg.VARS      = {'ner', 'inf_imp', 'inf_p', 'inf_con', 'ise', 'tib'};
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
Cfg.ND           = 3e4;            % draws ortogonal-reduced-form
Cfg.MAX_IS_DRAWS = 1e4;            % max draws efectivos tras resampling
Cfg.CONJUGATE    = 'structural';   % 'structural' | 'irfs'
Cfg.ITER_SHOW    = 1000;

% -- PRIOR (Chat 12 / build_posterior.m) ---------------------------------
% Default si no se define Cfg.PRIOR: 'diffuse' (NIW impropio, paper original).
% Para probar otro prior en esta variante, descomentar UNA de las opciones
% siguientes (no combinar mas de una):
%
 %Cfg.PRIOR.type    = 'minnesota';
 %Cfg.PRIOR.lambda1 = 0.2;   % tightness
 %Cfg.PRIOR.lambda2 = 0.5;   % mezcla own/cross-variable
 %Cfg.PRIOR.lambda3 = 1;     % lag decay
%
% Cfg.PRIOR.type = 'sims_zha';
% Cfg.PRIOR.mu5  = 1;
% Cfg.PRIOR.mu6  = 1;
% % Nota: con datos en niveles, build_posterior emite warning
% % 'build_posterior:simsZhaScale' si y0/sigma > 10 (normal en niveles).
%
% Cfg.PRIOR.type    = 'niw_custom';
% Cfg.PRIOR.nu_bar  = 30;
% Cfg.PRIOR.Phi_bar = eye(numel(Cfg.VARS));   % ajustar dimensiones reales
% Cfg.PRIOR.Psi_bar = zeros(Cfg.NLAG*numel(Cfg.VARS)+Cfg.NEX, numel(Cfg.VARS));
% Cfg.PRIOR.Omega_bar = eye(Cfg.NLAG*numel(Cfg.VARS)+Cfg.NEX);
%
% Cfg.PRIOR.type    = 'natural_conjugate';
% Cfg.PRIOR.lambda1 = 0.2;
% Cfg.PRIOR.lambda2 = 0.5;
% Cfg.PRIOR.lambda3 = 1;
% % Cfg.PRIOR.nu_bar opcional; default n+1+T/10

% -- DUMMIES EXOGENAS (Chat 13 / build_dummies.m) — OPCIONAL --------------
% Sin Cfg.DUMMIES, ndummies=0 (comportamiento actual, sin cambios).
% Para agregar una dummy, descomentar y ajustar. Requiere Dataset.dates
% (datetime), que el loader ya provee automaticamente.
%
%Cfg.DUMMIES(1).type  = 'step';     % 'oneoff' | 'pulse' | 'step' | 'seasonal'
%Cfg.DUMMIES(1).year  = 2020;
% Cfg.DUMMIES(1).month = 3;          % ej. quiebre cambiario/pandemia marzo 2020
% Cfg.DUMMIES(1).name  = 'covid_step';

% -- DUMMIES EXOGENAS (Chat 13 / build_dummies.m) -------------------------
Cfg.DUMMIES(1).name       = 'covid1';
Cfg.DUMMIES(1).type       = 'pulse';
Cfg.DUMMIES(1).date_start = [2020, 3];   % marzo 2020
Cfg.DUMMIES(1).date_end   = [2020, 6];   % junio 2020

Cfg.DUMMIES(2).name       = 'covid2';
Cfg.DUMMIES(2).type       = 'pulse';
Cfg.DUMMIES(2).date_start = [2021, 3];   % marzo 2021
Cfg.DUMMIES(2).date_end   = [2021, 6];   % junio 2021

% -- RESTRICCIONES --------------------------------------------------------
Cfg.HORIZONS_RESTRICT = 0;    % restricciones en horizonte 0

n_vars     = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

Cfg.Z = cell(n_vars, 1);
Cfg.S = cell(n_vars, 1);

% build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
% ── Shock 1: Cam (cambiario / prima de riesgo) ──────────────────────────
Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(2, 1, n_vars, n_horizons,  1) ];
Cfg.Z{1} = [ build_restriction_row(5, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1) ];

% ── Shock 2: Dem (demanda domestica) ─────────────────────────────────────
Cfg.S{2} = [ build_restriction_row(4, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1) ];
Cfg.Z{2} = [ build_restriction_row(2, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1) ];

% ── Shock 3: Ofe (oferta) ─────────────────────────────────────────────────
Cfg.S{3} = [ build_restriction_row(4, 1, n_vars, n_horizons, -1) ];
Cfg.Z{3} = [ build_restriction_row(2, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(3, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1) ];

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
