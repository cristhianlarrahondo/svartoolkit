%SPEC_BASE  Campos comunes de configuracion

%%
% -- DATOS ---------------------------------------------------------------
% Variables
%   1. ner     — Nominal Exchange Rate
%   2. inf_imp — Imports Inflation
%   3. inf_p   — Producer Inflation
%   4. inf_c   — Consumer Inflation
%   5. ise     — Economic Activity
%   6. tib     - Interest Rate
Cfg.DATA_FILE = fullfile(ex_dir, 'data', 'data_erpt.xlsx');

% Cfg.VARS 
% mismo orden que VAR_ROLES
Cfg.VARS = {'ner', 'inf_imp', 'inf_p', 'inf_con', 'ise', 'tib'};   
Cfg.VAR_ROLES = {'endogenous','endogenous','endogenous','endogenous','endogenous', 'endogenous'};

% -- OUTPUT: siempre relativo a projects/bnw/, NUNCA a refactored/output/ --
Cfg.OUTPUT_DIR = fullfile(ex_dir, 'output');

% -- MODELO ----------------------------------------------------------------
Cfg.NLAG         = 4;        % numero de lags
Cfg.NEX          = 1;        % 1 = incluir constante
Cfg.HORIZON      = 36;       % horizonte maximo para IRFs
Cfg.INDEX_FEVD   = 36;       % horizonte para FEVD
Cfg.SCALE_FACTOR = 1;       

% -- MUESTREO - SEMILLA
Cfg.SEED = 0;

% -- RESTRICCIONES ---------------------------------------------------------
Cfg.HORIZONS_RESTRICT = 0;     % restricciones en horizonte 0

% Número de variables
n_vars     = sum(strcmp(Cfg.VAR_ROLES, 'endogenous')); % Automático según definido arriba
% Número de horizontes con restricciones
n_horizons = numel(Cfg.HORIZONS_RESTRICT);   % Sobre cuántos horizontes hay restricciones (automático)

% Matrices de restricciones
Cfg.Z    = cell(n_vars, 1); % Ceros (automático, no tocar)
Cfg.S    = cell(n_vars, 1); % Signos (automático, no tocar)

% build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
% ── Shock 1: Cam (cambiario/prima de riesgo) ────────────────────────────
Cfg.S{1} = [ build_restriction_row(1, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(2, 1, n_vars, n_horizons,  1); ];        
Cfg.Z{1} = [ build_restriction_row(5, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1); ];

% ── Shock 2: Dem (demanda doméstica) ─────────────────────────────────────
Cfg.S{2} = [ build_restriction_row(4, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(5, 1, n_vars, n_horizons,  1);];        
Cfg.Z{2} = [ build_restriction_row(2, 1, n_vars, n_horizons,  1); ...
             build_restriction_row(6, 1, n_vars, n_horizons,  1);];        

% ── Shock 3: Ofe (oferta) ────────────────────────────────────────────────
Cfg.S{3} = [ build_restriction_row(4, 1, n_vars, n_horizons, -1)];         
Cfg.Z{3} = [ build_restriction_row(2, 1, n_vars, n_horizons, 1); ...
             build_restriction_row(3, 1, n_vars, n_horizons, 1); ...
             build_restriction_row(6, 1, n_vars, n_horizons, 1);];

% -- OUTPUT / VISUALIZACION ───────────────────────────────────────────────
Cfg.SAVE_RESULTS     = true;
Cfg.PLOT_IRFS        = true;
Cfg.SUMMARY_HORIZONS = [0 4 8 12 18 24];
Cfg.CRED_BANDS       = [0.25 0.75];
Cfg.SHOCK_IDX        = 'all';
Cfg.SHOCK_NAMES      = {'ER', 'Demand', 'Supply'}; % Nombre de los shocks
Cfg.IRF_TYPE         = 'both'; % irf, cirf, both
Cfg.IRF_NORM         = 'none';

% Cfg.FEVD_HORIZONS
Cfg.FEVD_HORIZONS = 1:Cfg.HORIZON;



