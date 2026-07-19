%spec_A_rob_mm_niwcustom_lag2_v0  ERPT Ejercicio A -- m/m, prior niw_custom (D5), lag 2, matriz rob
%
%   ERPT-Chat 11 (Tipo S). Spec NUEVO (no parte de los 16 originales de
%   ERPT-Chat 6/7): variante niw_custom (D5, ERPT-Chat-10-discusion-cierre.md)
%   agregada como alternativa exploratoria a "Minnesota corregida" para el
%   grupo mm_minn, que mostraba inestabilidad dinamica (ERPT-Chat 9/10).
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
%   Prior: NIW_CUSTOM (D5 de ERPT-Chat 10, implementado en ERPT-Chat 11).
%   Variante ADICIONAL a "Minnesota corregida" (spec_A_rob_mm_minn_lag2_v0),
%   no un reemplazo. Omega_bar construida con la MISMA formula e
%   hiperparametros que Minnesota (lambda1=0.2, lambda2=0.5, lambda3=2)
%   via build_niw_custom_prior.m (projects/erpt/src/, Tipo S -- no toca
%   build_posterior.m). Unica diferencia real: Psi_bar tiene coeficiente
%   propio de rezago-1 = 0.97 (en vez de 1.0), dejando margen de
%   estabilidad en la MEDIA del prior, no solo en su varianza.
%   VALOR AJUSTADO tras el diagnostico de sensibilidad de ERPT-Chat 11
%   (Opcion 3, diagnose_erpt11_niwcustom_sensitivity.m): el valor D5
%   original (0.90) daba 100%% estable pero era mas agresivo de lo
%   necesario. La grilla [1.00 0.99 0.97 0.95 0.93 0.90] mostro que
%   0.97 es el desplazamiento MENOS agresivo (mas cercano a la caminata
%   aleatoria original) que ya cruza el umbral de 70%% en las 4 specs
%   mm_niwcustom simultaneamente (minimo observado: 88.73%%, margen
%   amplio sobre el umbral). Sanity check: psi=1.00 reprodujo
%   exactamente el ~30%% ya medido para Minnesota corregida, confirmando
%   que build_niw_custom_prior.m replica el Omega_bar correctamente.
%   nu_bar=0, Phi_bar=zeros(n): vagos por defecto.
%
%   Dummies COVID (m/m): 2 pulses, ventanas de ERPT-Chat 3.
%
%   Este archivo es AUTOCONTENIDO (no hereda de ningun spec_base via
%   eval(fileread(...))) -- declara su Cfg completo.

% -- Ruta a este proyecto (projects/erpt/), NUNCA pwd/cd/'..' ------------
cfg_dir = fileparts(mfilename('fullpath'));   % .../projects/erpt/config/
ex_dir  = fileparts(cfg_dir);                 % .../projects/erpt/

% -- IDENTIFICADOR DE ESTA SPEC (usado en Cfg.OUTPUT_DIR y en tablas) ----
Cfg.SPEC_NAME = 'spec_A_rob_mm_niwcustom_lag2_v0';

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

% -- PRIOR (build_niw_custom_prior.m / projects/erpt/src/, ERPT-Chat 11) -
% Variante niw_custom de D5 (ERPT-Chat-10-discusion-cierre.md): misma
% varianza de prior que Minnesota corregida (lambda1=0.2, lambda2=0.5,
% lambda3=2), coeficiente propio de rezago-1 en la MEDIA = 0.97 en vez de
% 1.0 (Psi_bar) -- ajustado en ERPT-Chat 11 tras diagnostico de
% sensibilidad, ver arriba. La funcion helper replica la construccion OLS de
% build_posterior.m (sin modificarlo) para calcular Omega_bar con el
% mismo sig2(j) que usaria la variante minnesota. Se llama al final de
% este archivo (seccion ERPT), una vez que Cfg.NLAG/NEX/DUMMIES ya
% estan definidos.

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

% -- PRIOR: construir Cfg.PRIOR via helper (requiere NLAG/NEX/DUMMIES ya
%   definidos arriba) -----------------------------------------------------
Cfg.PRIOR = build_niw_custom_prior(Cfg, 0.97);   % psi_own_lag1=0.97 (ERPT-Chat 11, sensibilidad)

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

