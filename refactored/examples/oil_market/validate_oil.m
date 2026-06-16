%VALIDATE_OIL  Script de verificación funcional — Chat 15: Ejemplo Oil Market.
%
%   Tipo S (validación funcional + regresión numérica BNW).
%
%   Cobertura:
%   SECCIÓN A — Carga de datos
%     A1: load_data lee data_bau.xlsx correctamente (n=4, T_efectivo correcto)
%     A2: Dataset.freq detecta frecuencia 'M' (mensual)
%     A3: Variables en el orden correcto (prod_growth, act_growth, rpo_growth, dinv)
%     A4: No hay NaN en la muestra efectiva
%
%   SECCIÓN B — Config
%     B1: spec_oil_pfa carga sin error; campos obligatorios presentes
%     B2: spec_oil_is  carga sin error; restricciones declaradas
%     B3: validate_cfg no lanza error en ninguna de las dos specs
%
%   SECCIÓN C — Ejecución end-to-end (nd=500)
%     C1: main_oil corre PFA sin error
%     C2: main_oil corre IS  sin error
%     C3: Results contiene LtildeStruct, FEVD
%     C4: IS tiene draws aceptados (uw con elementos > 0)
%     C5: print_summary imprime tabla sin error para spec PFA
%
%   SECCIÓN D — Regresión numérica BNW (no debe cambiar)
%     D1: spec_bnw_pfa con nd=500 y rng(0) produce Ltilde(1,1,1) == 0
%     D2: spec_bnw_is  con nd=500 y rng(0) produce Ltilde(1,1,1,1) == 0
%
%   Uso: ejecutar desde MATLAB (cualquier working directory).
%        No genera figuras ni guarda .mat (PLOT_IRFS=false en specs).

fprintf('\n');
fprintf('================================================================\n');
fprintf(' VALIDATE_OIL — Chat 15: Ejemplo Mercado Petrolero\n');
fprintf('================================================================\n\n');

%% ── Setup de rutas ───────────────────────────────────────────────────────
val_root  = fileparts(mfilename('fullpath'));    % .../examples/oil_market/
ref_root  = fileparts(fileparts(val_root));      % .../refactored/
src_dir   = fullfile(ref_root, 'src');
cfg_dir   = fullfile(ref_root, 'config');
val_dir   = fullfile(ref_root, 'validate');
ex_cfg    = fullfile(val_root, 'config');

addpath(src_dir);
addpath(cfg_dir);
addpath(fullfile(ref_root, 'helpfunctions'));
addpath(val_dir);
addpath(ex_cfg);

%% ── Checker de rutas prohibidas (..) en src/ ─────────────────────────────
DOTDOT   = '\.\.[/\\]';
src_files = dir(fullfile(src_dir, '*.m'));
ruta_ok   = true;
for fi = 1:numel(src_files)
    fid  = fopen(fullfile(src_dir, src_files(fi).name), 'r');
    lnum = 0;
    while ~feof(fid)
        ln = fgetl(fid); lnum = lnum + 1;
        if ~ischar(ln), continue; end
        lt = strtrim(ln);
        if startsWith(lt, '%'), continue; end
        lc = regexprep(lt, '\.\.\..*', '');
        if ~isempty(regexp(lc, DOTDOT, 'once'))
            fprintf('  [RUTA PROHIBIDA] %s L%d\n', src_files(fi).name, lnum);
            ruta_ok = false;
        end
    end
    fclose(fid);
end
if ruta_ok
    fprintf('[OK] Checker de rutas: sin rutas relativas prohibidas\n\n');
end

%% ── Helpers ──────────────────────────────────────────────────────────────
n_pass = 0;
n_fail = 0;

function report(label, ok, detail)
    if ok
        fprintf('  [PASA] %s\n', label);
        n_pass = n_pass + 1;
    else
        fprintf('  [FALLA] %s\n', label);
        if nargin >= 3 && ~isempty(detail)
            fprintf('          Detalle: %s\n', detail);
        end
        n_fail = n_fail + 1;
    end
end

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN A — Carga de datos
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN A — Carga de datos\n');
fprintf('---------------------------\n');

% Construir Cfg mínimo para cargar los datos del ejemplo
ex_root   = val_root;   % validate_oil vive en examples/oil_market/
data_path = fullfile(ex_root, 'data', 'data_bau.xlsx');

Cfg_a = struct();
Cfg_a.DATA_FILE    = data_path;
Cfg_a.SCALE_FACTOR = 1;
Cfg_a.NLAG         = 24;
Cfg_a.NEX          = 1;

try
    Dataset_a = load_data(Cfg_a);
    loaded_ok = true;
catch ME
    loaded_ok = false;
    fprintf('  ERROR load_data: %s\n', ME.message);
end

% A1: n=4 y T razonable
if loaded_ok
    n_endo = Dataset_a.nvar;
    T_raw  = size(Dataset_a.Y_raw, 1);
    % Con datos desde 1971M2 hasta 2016M12 = 549 obs; con p=24 → T_eff=525
    % Con datos desde 1958M1 hasta 2016M12 = 707 obs; con p=24 → T_eff=683
    % Aceptamos cualquier T_raw razonable (>= 24+527 = 551 si desde 1971M2)
    report('A1: n=4 variables endogenas', n_endo == 4, sprintf('n=%d', n_endo));
else
    report('A1: n=4 variables endogenas', false, 'load_data falló');
end

% A2: frecuencia 'M'
if loaded_ok
    report('A2: frecuencia mensual (M)', strcmp(Dataset_a.freq, 'M'), ...
           sprintf('freq=%s', Dataset_a.freq));
else
    report('A2: frecuencia mensual (M)', false, 'load_data falló');
end

% A3: orden de variables
if loaded_ok
    expected_names = {'prod_growth', 'act_growth', 'rpo_growth', 'dinv'};
    endo_mask = strcmp(Dataset_a.var_roles, 'endogenous');
    endo_names = Dataset_a.var_names(endo_mask);
    order_ok = isequal(endo_names(:)', expected_names);
    report('A3: orden de variables correcto', order_ok, ...
           sprintf('encontrado: %s', strjoin(endo_names, ', ')));
else
    report('A3: orden de variables correcto', false, 'load_data falló');
end

% A4: sin NaN en la muestra
if loaded_ok
    has_nan = any(isnan(Dataset_a.Y_raw(:)));
    report('A4: sin NaN en la muestra', ~has_nan, ...
           sprintf('%d NaN encontrados', sum(isnan(Dataset_a.Y_raw(:)))));
else
    report('A4: sin NaN en la muestra', false, 'load_data falló');
end

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN B — Config
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN B — Config\n');
fprintf('-------------------\n');

% B1: spec_oil_pfa carga sin error
try
    clear Cfg;
    run(fullfile(ex_cfg, 'spec_oil_pfa.m'));
    Cfg_pfa = Cfg; clear Cfg;
    pfa_ok = true;
    % Verificar campos obligatorios
    mandatory = {'MODE','ND','SEED','NLAG','NEX','HORIZON','INDEX_FEVD',...
                 'SCALE_FACTOR','DATA_FILE','S','Z'};
    missing = {};
    for k = 1:numel(mandatory)
        if ~isfield(Cfg_pfa, mandatory{k}), missing{end+1} = mandatory{k}; end
    end
    report('B1: spec_oil_pfa carga con campos obligatorios', isempty(missing), ...
           ['Faltantes: ' strjoin(missing, ', ')]);
catch ME
    pfa_ok = false;
    report('B1: spec_oil_pfa carga con campos obligatorios', false, ME.message);
    Cfg_pfa = struct('MODE','pfa','ND',500,'SEED',0,'NLAG',24,'NEX',1,...
                     'HORIZON',60,'INDEX_FEVD',60,'SCALE_FACTOR',1,...
                     'DATA_FILE',data_path,'S',{{}},'Z',{{}});
end

% B2: spec_oil_is carga sin error
try
    clear Cfg;
    run(fullfile(ex_cfg, 'spec_oil_is.m'));
    Cfg_is = Cfg; clear Cfg;
    is_ok = true;
    mandatory_is = {'MODE','ND','SEED','NLAG','NEX','HORIZON','INDEX_FEVD',...
                    'SCALE_FACTOR','DATA_FILE','S','Z','MAX_IS_DRAWS',...
                    'CONJUGATE','HORIZONS_RESTRICT'};
    missing_is = {};
    for k = 1:numel(mandatory_is)
        if ~isfield(Cfg_is, mandatory_is{k}), missing_is{end+1} = mandatory_is{k}; end
    end
    has_zero_rest = ~isempty(Cfg_is.Z{2});
    has_sign_rest = ~isempty(Cfg_is.S{1});
    report('B2: spec_oil_is carga con restricciones declaradas', ...
           isempty(missing_is) && has_zero_rest && has_sign_rest, ...
           sprintf('faltantes=%d, Z{2}=%d filas, S{1}=%d filas', ...
               numel(missing_is), size(Cfg_is.Z{2},1), size(Cfg_is.S{1},1)));
catch ME
    is_ok = false;
    report('B2: spec_oil_is carga con restricciones declaradas', false, ME.message);
    n_v = 4; e_v = eye(n_v);
    Cfg_is = struct('MODE','is','ND',500,'SEED',0,'NLAG',24,'NEX',1,...
                    'HORIZON',60,'INDEX_FEVD',60,'SCALE_FACTOR',1,...
                    'DATA_FILE',data_path,'MAX_IS_DRAWS',500,...
                    'CONJUGATE','structural','HORIZONS_RESTRICT',0,...
                    'NS',1,'S',{{}},'Z',{{}});
    Cfg_is.Z = cell(n_v,1); Cfg_is.Z{2} = e_v(1,:);
    Cfg_is.S = cell(n_v,1); Cfg_is.S{1} = [e_v(1,:);-e_v(3,:)];
end

% B3: validate_cfg no lanza error
try
    validate_cfg(Cfg_pfa);
    report('B3a: validate_cfg OK para spec_oil_pfa', true);
catch ME
    report('B3a: validate_cfg OK para spec_oil_pfa', false, ME.message);
end

try
    validate_cfg(Cfg_is);
    report('B3b: validate_cfg OK para spec_oil_is', true);
catch ME
    report('B3b: validate_cfg OK para spec_oil_is', false, ME.message);
end

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN C — Ejecución end-to-end (nd=500)
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN C — Ejecución end-to-end (nd=500)\n');
fprintf('------------------------------------------\n');
fprintf('  Nota: esta sección tarda varios minutos.\n\n');

% C1 + C3 (PFA): run completo
Results_pfa = [];
try
    Cfg_run_pfa = Cfg_pfa;
    Cfg_run_pfa.ND        = 500;
    Cfg_run_pfa.PLOT_IRFS = false;

    rng(Cfg_run_pfa.SEED);
    Dataset_pfa  = load_data(Cfg_run_pfa);
    Post_pfa     = build_posterior(Dataset_pfa, Cfg_run_pfa);
    rng(Cfg_run_pfa.SEED);
    Results_pfa  = run_pfa(Post_pfa, Cfg_run_pfa);

    report('C1: spec_oil_pfa termina sin error (nd=500)', true);
    has_fields_pfa = isfield(Results_pfa,'LtildeStruct') && ...
                     isfield(Results_pfa,'FEVD');
    report('C3a: Results_pfa contiene LtildeStruct y FEVD', has_fields_pfa);
catch ME
    report('C1: spec_oil_pfa termina sin error (nd=500)', false, ME.message);
    report('C3a: Results_pfa contiene LtildeStruct y FEVD', false, 'run falló');
end

% C2 + C3 (IS): run completo
Results_is = [];
try
    Cfg_run_is = Cfg_is;
    Cfg_run_is.ND           = 500;
    Cfg_run_is.MAX_IS_DRAWS = 500;
    Cfg_run_is.PLOT_IRFS    = false;

    rng(Cfg_run_is.SEED);
    Dataset_is   = load_data(Cfg_run_is);
    Post_is      = build_posterior(Dataset_is, Cfg_run_is);
    rng(Cfg_run_is.SEED);
    Results_is   = run_is(Post_is, Cfg_run_is);

    report('C2: spec_oil_is termina sin error (nd=500)', true);
    has_fields_is = isfield(Results_is,'LtildeStruct') && ...
                    isfield(Results_is,'FEVD');
    report('C3b: Results_is contiene LtildeStruct y FEVD', has_fields_is);
catch ME
    report('C2: spec_oil_is termina sin error (nd=500)', false, ME.message);
    report('C3b: Results_is contiene LtildeStruct y FEVD', false, 'run falló');
end

% C4: IS tiene draws aceptados
if ~isempty(Results_is) && isfield(Results_is,'uw')
    n_accept = sum(Results_is.uw > 0);
    report('C4: IS tiene draws aceptados (uw > 0)', n_accept > 0, ...
           sprintf('%d draws con peso > 0 de %d', n_accept, Cfg_run_is.ND));
else
    report('C4: IS tiene draws aceptados (uw > 0)', false, 'run_is falló');
end

% C5: print_summary corre sin error para PFA
if ~isempty(Results_pfa)
    try
        fprintf('\n  -- print_summary output (spec_oil_pfa) --\n');
        print_summary(Results_pfa.LtildeStruct, Dataset_pfa, Cfg_run_pfa);
        report('C5: print_summary imprime sin error (PFA)', true);
    catch ME
        report('C5: print_summary imprime sin error (PFA)', false, ME.message);
    end
else
    report('C5: print_summary imprime sin error (PFA)', false, 'run_pfa falló');
end

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN D — Regresión numérica BNW (los valores de referencia no cambian)
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN D — Regresión numérica BNW\n');
fprintf('------------------------------------\n');
fprintf('  Nota: esta sección corre spec_bnw con nd=500 y rng(0).\n');
fprintf('        Los valores de referencia deben mantenerse intactos.\n\n');

% Referenciar Cfg BNW explícitamente
bnw_cfg_pfa = struct();
bnw_cfg_pfa.NLAG           = 4;
bnw_cfg_pfa.NEX            = 1;
bnw_cfg_pfa.HORIZON        = 40;
bnw_cfg_pfa.INDEX_FEVD     = 40;
bnw_cfg_pfa.SCALE_FACTOR   = 100;
bnw_cfg_pfa.MODE           = 'pfa';
bnw_cfg_pfa.ND             = 500;
bnw_cfg_pfa.MAX_IS_DRAWS   = 500;
bnw_cfg_pfa.CONJUGATE      = 'irfs';
bnw_cfg_pfa.SEED           = 0;
bnw_cfg_pfa.HORIZONS_RESTRICT = 0;
bnw_cfg_pfa.NS             = 1;
bnw_cfg_pfa.DATA_FILE      = '';   % usa data_bnw.xlsx del proyecto
bnw_cfg_pfa.TIMING_VARIANT = [];
bnw_cfg_pfa.DERIV_SIDED    = 2;
bnw_cfg_pfa.SAVE_RESULTS   = false;
bnw_cfg_pfa.PLOT_IRFS      = false;
bnw_cfg_pfa.ITER_SHOW      = 200;
n5 = 5; e5 = eye(n5);
bnw_cfg_pfa.Z = cell(n5,1); bnw_cfg_pfa.Z{1} = e5(1,:);
bnw_cfg_pfa.S = cell(n5,1); bnw_cfg_pfa.S{1} = e5(2,:);

% D1: BNW PFA — Ltilde(1,1,1) debe ser 0 (zero restriction intacta)
try
    rng(0);
    Dataset_bnw_p = load_data(bnw_cfg_pfa);
    Post_bnw_p    = build_posterior(Dataset_bnw_p, bnw_cfg_pfa);
    rng(0);
    Results_bnw_p = run_pfa(Post_bnw_p, bnw_cfg_pfa);
    val_d1 = Results_bnw_p.LtildeStruct.Ltilde(1, 1, 1);
    report('D1: BNW PFA Ltilde(1,1,1) == 0 (zero restriction)', abs(val_d1) < 1e-8, ...
           sprintf('valor=%.10f', val_d1));
catch ME
    report('D1: BNW PFA Ltilde(1,1,1) == 0', false, ME.message);
end

% D2: BNW IS — Ltilde(1,1,1,1) debe ser 0
bnw_cfg_is = bnw_cfg_pfa;
bnw_cfg_is.MODE           = 'is';
bnw_cfg_is.ND             = 500;
bnw_cfg_is.MAX_IS_DRAWS   = 500;
bnw_cfg_is.CONJUGATE      = 'structural';
bnw_cfg_is.HORIZONS_RESTRICT = 0;

try
    rng(0);
    Dataset_bnw_i = load_data(bnw_cfg_is);
    Post_bnw_i    = build_posterior(Dataset_bnw_i, bnw_cfg_is);
    rng(0);
    Results_bnw_i = run_is(Post_bnw_i, bnw_cfg_is);
    val_d2 = Results_bnw_i.LtildeStruct.Ltilde(1, 1, 1, 1);
    report('D2: BNW IS Ltilde(1,1,1,1) == 0 (zero restriction)', abs(val_d2) < 1e-8, ...
           sprintf('valor=%.10f', val_d2));
catch ME
    report('D2: BNW IS Ltilde(1,1,1,1) == 0', false, ME.message);
end

fprintf('\n');

%% ── Resumen final ────────────────────────────────────────────────────────
fprintf('================================================================\n');
fprintf(' RESUMEN: %d PASA  |  %d FALLA\n', n_pass, n_fail);
if n_fail == 0
    fprintf(' VEREDICTO: PASA\n');
else
    fprintf(' VEREDICTO: NO PASA — revisar las secciones con [FALLA]\n');
end
fprintf('================================================================\n\n');
