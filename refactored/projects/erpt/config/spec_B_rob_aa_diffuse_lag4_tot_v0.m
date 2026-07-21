%spec_B_rob_aa_diffuse_lag4_tot_v0  ERPT Ejercicio B -- ToT (Terms of Trade)
%   como robustez sobre la spec ganadora del Ejercicio A.
%
%   ERPT-Chat 17 (Tipo S). Extiende spec_A_rob_aa_diffuse_lag4_v0.m
%   (ganadora, ERPT-Chat 15) agregando `tot` como 7a variable ENDOGENA,
%   con restriccion de impacto-cero (h=0), siguiendo el diseno
%   metodologico cerrado en ERPT-Chat 6 (Discusion, APROBADO, decision D6).
%
%   Variables endogenas (Cfg.VARS), orden posicional:
%     1. ner      -- Nominal Exchange Rate
%     2. imp_inf  -- Imports Inflation   (LIBRE en todos los choques)
%     3. pro_inf  -- Producer Inflation
%     4. con_inf  -- Consumer Inflation
%     5. ea       -- Economic Activity
%     6. ir       -- Interest Rate
%     7. tot      -- Terms of Trade      (NUEVA -- Ejercicio B)
%
%   ── Reconciliacion D6 vs. estado actual de la ganadora (protocolo
%   obligatorio de ERPT-Chat 17, punto 1, verificado via lectura API de
%   spec_A_rob_aa_diffuse_lag4_v0.m) ───────────────────────────────────────
%   D6 (ERPT-Chat 6) diseno tot=0 para los "4 choques" {Cam, Dem, Ofe, Mon}.
%   Pero ERPT-Chat 9 elimino Mon como choque NOMBRADO de la matriz 'rob'
%   (paso a residual sin restriccion -- en la ganadora vigente:
%   S{4}=[]/Z{4}=[]). La ganadora SOLO tiene 3 choques identificados: Cam,
%   Dem, Ofe. Consecuencia para este spec: la fila tot=0 se agrega
%   UNICAMENTE a los 3 choques identificados -- NO a ningun residual
%   (4..7), porque hacerlo introduciria una restriccion de cero en un
%   choque que hoy no tiene ninguna, cambiando su estatus de
%   identificacion sin ninguna decision economica que lo respalde. Esto es
%   fiel al espiritu de D6 (restringir tot=0 en los choques CON NOMBRE
%   economico), ajustado al estado real post-Chat 9.
%
%   Conteo de ceros resultante (n=7 ahora, antes n=6):
%     Cam : 3 ceros (ea, ir, tot)   -- antes 2 (ea, ir)
%     Dem : 1 cero  (tot)           -- antes 0
%     Ofe : 1 cero  (tot)           -- antes 0
%     residuales 4,5,6,7: 0 ceros (ahora 4 residuales en vez de 3, porque
%     n crecio de 6 a 7 -- ningun choque adicional se nombra)
%   Orden por conteo de ceros descendente se mantiene (Cam=1, Dem=2,
%   Ofe=3): 3,1,1,0,0,0,0 -- condicion de regularidad ARW satisfecha con
%   holgura amplia (zeros_j <= n-j para cada j: 3<=6, 1<=5, 1<=4).
%
%   Matriz de restricciones para Cam/Dem/Ofe: IDENTICA en signos a
%   spec_A_rob_aa_diffuse_lag4_v0.m (matriz 'rob'); unico cambio es la
%   fila adicional tot=0 en Z{1}/Z{2}/Z{3}.
%
%   Prior: DIFFUSE (identico a la ganadora -- Cfg.PRIOR no se define).
%   Transform: a/a. Lags: 4 (identico a la ganadora). Dummies COVID:
%   identicas (a/a, ERPT-Chat 3).
%
%   Dato: `tot` ya existe en data_erpt_aa.xlsx (hoja "data" y "metadata",
%   confirmado via API en ERPT-Chat 17) -- no se construye dataset nuevo
%   (hallazgo de datos ya documentado en D6/ERPT-Chat 4-5).
%
%   ND = 1e6 (no 3e5): se corre directamente al ND cientifico final, para
%   comparabilidad directa con el cache de la ganadora (tambien a ND=1e6,
%   ERPT-Chat 15/16) -- este spec no pasa por una cascada de seleccion
%   propia, es una unica corrida de robustez.
%
%   Este archivo es AUTOCONTENIDO (no hereda de ningun spec_base via
%   eval(fileread(...))) -- declara su Cfg completo.

% -- Ruta a este proyecto (projects/erpt/), NUNCA pwd/cd/'..' ------------
cfg_dir = fileparts(mfilename('fullpath'));   % .../projects/erpt/config/
ex_dir  = fileparts(cfg_dir);                 % .../projects/erpt/

% -- IDENTIFICADOR DE ESTA SPEC (usado en Cfg.OUTPUT_DIR y en tablas) ----
Cfg.SPEC_NAME = 'spec_B_rob_aa_diffuse_lag4_tot_v0';

% -- DATOS ----------------------------------------------------------------
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_erpt_aa.xlsx');
Cfg.VARS      = {'ner', 'imp_inf', 'pro_inf', 'con_inf', 'ea', 'ir', 'tot'};
Cfg.VAR_ROLES = {'endogenous','endogenous','endogenous','endogenous', ...
                  'endogenous','endogenous','endogenous'};

% -- MODELO -----------------------------------------------------------------
Cfg.NLAG         = 4;         % numero de lags (identico a la ganadora)
Cfg.NEX          = 1;         % 1 = incluir constante
Cfg.HORIZON      = 36;        % horizonte maximo para IRFs
Cfg.INDEX_FEVD   = 36;        % horizonte para FEVD (legado)
Cfg.SCALE_FACTOR = 1;

% -- MUESTREO -----------------------------------------------------------
Cfg.SEED         = 0;
Cfg.MODE         = 'is';           % unico modo del proyecto (no hay flujo PFA)
Cfg.ND           = 1e6;            % ND cientifico final (comparable al cache de la ganadora)
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

% -- RESTRICCIONES (Opcion B, set-identificada -- matriz rob + tot=0) ----
Cfg.HORIZONS_RESTRICT = 0;    % restricciones en horizonte 0

n_vars     = sum(strcmp(Cfg.VAR_ROLES, 'endogenous'));   % = 7
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

Cfg.Z = cell(n_vars, 1);
Cfg.S = cell(n_vars, 1);

% build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
% -- Shock 1: Cam (identico a la ganadora + tot=0 NUEVO) -----------------
%    ner(+) | ea=0, ir=0, tot=0
Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1) ];
Cfg.Z{1} = [ build_restriction_row(5, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(7, 1, n_vars, n_horizons,  1) ];

% -- Shock 2: Dem (identico a la ganadora + tot=0 NUEVO) -----------------
%    pro(+), con(+), ea(+), ir(+) | tot=0
Cfg.S{2} = [ build_restriction_row(3, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(4, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1) ];
Cfg.Z{2} = [ build_restriction_row(7, 1, n_vars, n_horizons,  1) ];

% -- Shock 3: Ofe (identico a la ganadora + tot=0 NUEVO) -----------------
%    con(-), ea(+) | tot=0
Cfg.S{3} = [ build_restriction_row(4, 1, n_vars, n_horizons, -1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1) ];
Cfg.Z{3} = [ build_restriction_row(7, 1, n_vars, n_horizons,  1) ];

% -- Shocks 4..7: residuales sin restriccion (ver nota de reconciliacion
%    arriba -- Mon ya no es choque nombrado desde ERPT-Chat 9; tot no
%    agrega ningun choque nombrado adicional, solo una variable observada
%    mas) --
Cfg.S{4} = []; Cfg.Z{4} = [];
Cfg.S{5} = []; Cfg.Z{5} = [];
Cfg.S{6} = []; Cfg.Z{6} = [];
Cfg.S{7} = []; Cfg.Z{7} = [];

% -- OUTPUT: carpeta propia por spec, NUNCA refactored/output/ ----------
Cfg.OUTPUT_DIR = fullfile(ex_dir, 'output', Cfg.SPEC_NAME);

% -- OUTPUT / VISUALIZACION ---------------------------------------------
Cfg.SAVE_RESULTS     = true;
Cfg.PLOT_IRFS        = true;
Cfg.SUMMARY_HORIZONS = [0 4 8 12 18 24];
Cfg.CRED_BANDS       = [0.25 0.75];    % identico a la ganadora
Cfg.SHOCK_IDX        = 'all';
Cfg.SHOCK_NAMES      = {'Cam', 'Dem', 'Ofe'};
Cfg.IRF_TYPE         = 'both';   % irf, cirf, both
Cfg.IRF_NORM         = 'none';
Cfg.FEVD_HORIZONS    = 1:Cfg.HORIZON;

% -- ERPT (projects/erpt/src/calculate_erpt.m) --------------------------
Cfg.ERPT_PRICE_VARS = {'imp_inf', 'pro_inf', 'con_inf'};
Cfg.ERPT_DENOM_VAR  = 'ner';
Cfg.ERPT_HORIZONS   = [3 6 12 24 36];
