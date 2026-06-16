%VALIDATE_OIL  Script de verificación funcional — Chat 15: Ejemplo Oil Market.
%
%   Tipo S (validación funcional + regresión numérica BNW).
%
%   SECCIÓN A — Carga de datos
%     A1: load_data lee data_bau.xlsx (n=4, T>0)
%     A2: Dataset.freq == 'M' (mensual)
%     A3: Variables en orden correcto
%     A4: Sin NaN en la muestra
%
%   SECCIÓN B — Config
%     B1: spec_oil_pfa carga con campos obligatorios
%     B2: spec_oil_is carga con restricciones declaradas
%     B3a/B3b: validate_cfg no lanza error
%
%   SECCIÓN C — Ejecución end-to-end (nd=500)
%     C1: spec_oil_pfa termina sin error
%     C2: spec_oil_is termina sin error
%     C3a/C3b: Results contiene LtildeStruct y FEVD
%     C4: IS tiene draws aceptados
%     C5: print_summary imprime sin error (PFA)
%
%   SECCIÓN D — Regresión numérica BNW (los valores de referencia no cambian)
%     D1: BNW PFA Ltilde(1,1,1) == 0
%     D2: BNW IS  Ltilde(1,1,1,1) == 0
%
%   Uso: ejecutar desde MATLAB (cualquier working directory).

fprintf('\n');
fprintf('================================================================\n');
fprintf(' VALIDATE_OIL — Chat 15: Ejemplo Mercado Petrolero\n');
fprintf('================================================================\n\n');

%% ── Rutas ────────────────────────────────────────────────────────────────
% validate_oil.m vive en: refactored/examples/oil_market/
% Calculamos ref_root subiendo dos niveles desde este archivo.
val_root  = fileparts(mfilename('fullpath'));    % .../examples/oil_market/
ref_root  = fileparts(fileparts(val_root));      % .../refactored/
ex_cfg    = fullfile(val_root, 'config');
ex_data   = fullfile(val_root, 'data', 'data_bau.xlsx');

addpath(fullfile(ref_root, 'src'));
addpath(fullfile(ref_root, 'config'));
addpath(fullfile(ref_root, 'helpfunctions'));
addpath(fullfile(ref_root, 'validate'));
addpath(ex_cfg);

%% ── Checker de rutas prohibidas ─────────────────────────────────────────
src_dir   = fullfile(ref_root, 'src');
DOTDOT    = '\.\.[/\\]';
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
if ruta_ok, fprintf('[OK] Checker de rutas: sin rutas relativas prohibidas\n\n'); end

%% ── Contadores (variables del script, no función nested) ─────────────────
n_pass = 0;
n_fail = 0;

%% ── Macro de reporte (expresión inline, sin función nested) ──────────────
%  Uso: [n_pass, n_fail] = rpt(n_pass, n_fail, label, ok, detail)
%  Se llama explícitamente para evitar el problema de scope de MATLAB.

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN A — Carga de datos
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN A — Carga de datos\n');
fprintf('---------------------------\n');

Cfg_a                 = struct();
Cfg_a.DATA_FILE       = ex_data;
Cfg_a.SCALE_FACTOR    = 1;
Cfg_a.NLAG            = 24;
Cfg_a.NEX             = 1;

loaded_ok = false;
Dataset_a = struct();
try
    Dataset_a = load_data(Cfg_a);
    loaded_ok = true;
catch ME_a
    fprintf('  ERROR load_data: %s\n', ME_a.message);
end

% A1
label = 'A1: n=4 variables endogenas';
if loaded_ok
    ok = (Dataset_a.nvar == 4);
    detail = sprintf('n=%d', Dataset_a.nvar);
else
    ok = false; detail = 'load_data falló';
end
[n_pass, n_fail] = rpt(n_pass, n_fail, label, ok, detail);

% A2
label = 'A2: frecuencia mensual (M)';
if loaded_ok
    ok = strcmp(Dataset_a.freq, 'M');
    detail = sprintf('freq=''%s''', Dataset_a.freq);
else
    ok = false; detail = 'load_data falló';
end
[n_pass, n_fail] = rpt(n_pass, n_fail, label, ok, detail);

% A3
label = 'A3: orden de variables correcto';
if loaded_ok
    expected = {'prod_growth','act_growth','rpo_growth','dinv'};
    endo_mask  = strcmp(Dataset_a.var_roles, 'endogenous');
    endo_names = Dataset_a.var_names(endo_mask);
    ok = isequal(endo_names(:)', expected);
    detail = sprintf('encontrado: %s', strjoin(endo_names, ', '));
else
    ok = false; detail = 'load_data falló';
end
[n_pass, n_fail] = rpt(n_pass, n_fail, label, ok, detail);

% A4
label = 'A4: sin NaN en la muestra';
if loaded_ok
    n_nan = sum(isnan(Dataset_a.Y_raw(:)));
    ok = (n_nan == 0);
    detail = sprintf('%d NaN encontrados', n_nan);
else
    ok = false; detail = 'load_data falló';
end
[n_pass, n_fail] = rpt(n_pass, n_fail, label, ok, detail);

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN B — Config
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN B — Config\n');
fprintf('-------------------\n');

mandatory_base = {'MODE','ND','SEED','NLAG','NEX','HORIZON','INDEX_FEVD',...
                  'SCALE_FACTOR','DATA_FILE','S','Z'};

% B1: spec_oil_pfa
Cfg_pfa   = struct();
pfa_ok    = false;
try
    clear Cfg;
    run(fullfile(ex_cfg, 'spec_oil_pfa.m'));
    Cfg_pfa = Cfg; clear Cfg;
    pfa_ok  = true;
    missing = {};
    for k = 1:numel(mandatory_base)
        if ~isfield(Cfg_pfa, mandatory_base{k}), missing{end+1} = mandatory_base{k}; end %#ok<AGROW>
    end
    ok = isempty(missing);
    detail = '';
    if ~ok, detail = ['Faltantes: ' strjoin(missing,', ')]; end
catch ME_b1
    ok = false; detail = ME_b1.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'B1: spec_oil_pfa carga con campos obligatorios', ok, detail);

% B2: spec_oil_is
Cfg_is = struct();
is_ok  = false;
try
    clear Cfg;
    run(fullfile(ex_cfg, 'spec_oil_is.m'));
    Cfg_is = Cfg; clear Cfg;
    is_ok  = true;
    mandatory_is = [mandatory_base, {'MAX_IS_DRAWS','CONJUGATE','HORIZONS_RESTRICT'}];
    missing_is = {};
    for k = 1:numel(mandatory_is)
        if ~isfield(Cfg_is, mandatory_is{k}), missing_is{end+1} = mandatory_is{k}; end %#ok<AGROW>
    end
    has_z2 = ~isempty(Cfg_is.Z{2});
    has_s1 = ~isempty(Cfg_is.S{1});
    ok = isempty(missing_is) && has_z2 && has_s1;
    detail = sprintf('faltantes=%d, Z{2}=%d filas, S{1}=%d filas', ...
        numel(missing_is), size(Cfg_is.Z{2},1), size(Cfg_is.S{1},1));
catch ME_b2
    ok = false; detail = ME_b2.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'B2: spec_oil_is carga con restricciones declaradas', ok, detail);

% B3a
try
    validate_cfg(Cfg_pfa);
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'B3a: validate_cfg OK para spec_oil_pfa', true, '');
catch ME_b3a
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'B3a: validate_cfg OK para spec_oil_pfa', false, ME_b3a.message);
end

% B3b
try
    validate_cfg(Cfg_is);
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'B3b: validate_cfg OK para spec_oil_is', true, '');
catch ME_b3b
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'B3b: validate_cfg OK para spec_oil_is', false, ME_b3b.message);
end

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN C — Ejecución end-to-end (nd=500)
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN C — Ejecución end-to-end (nd=500)\n');
fprintf('------------------------------------------\n');
fprintf('  Nota: esta sección tarda varios minutos.\n\n');

% ── C1 + C3a: PFA ────────────────────────────────────────────────────────
Results_pfa  = [];
Dataset_pfa  = [];
Cfg_run_pfa  = [];
try
    Cfg_run_pfa               = Cfg_pfa;
    Cfg_run_pfa.ND            = 500;
    Cfg_run_pfa.PLOT_IRFS     = false;

    rng(Cfg_run_pfa.SEED);
    Dataset_pfa  = load_data(Cfg_run_pfa);
    Post_pfa     = build_posterior(Dataset_pfa, Cfg_run_pfa);
    rng(Cfg_run_pfa.SEED);
    Results_pfa  = run_pfa(Post_pfa, Cfg_run_pfa);
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C1: spec_oil_pfa termina sin error (nd=500)', true, '');
    ok_c3a = isfield(Results_pfa,'LtildeStruct') && isfield(Results_pfa,'FEVD');
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C3a: Results_pfa contiene LtildeStruct y FEVD', ok_c3a, '');
catch ME_c1
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C1: spec_oil_pfa termina sin error (nd=500)', false, ME_c1.message);
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C3a: Results_pfa contiene LtildeStruct y FEVD', false, 'run falló');
end

% ── C2 + C3b: IS ─────────────────────────────────────────────────────────
Results_is   = [];
Dataset_is   = [];
Cfg_run_is   = [];
try
    Cfg_run_is                 = Cfg_is;
    Cfg_run_is.ND              = 500;
    Cfg_run_is.MAX_IS_DRAWS    = 500;
    Cfg_run_is.PLOT_IRFS       = false;

    rng(Cfg_run_is.SEED);
    Dataset_is   = load_data(Cfg_run_is);
    Post_is      = build_posterior(Dataset_is, Cfg_run_is);
    rng(Cfg_run_is.SEED);
    Results_is   = run_is(Post_is, Cfg_run_is);
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C2: spec_oil_is termina sin error (nd=500)', true, '');
    ok_c3b = isfield(Results_is,'LtildeStruct') && isfield(Results_is,'FEVD');
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C3b: Results_is contiene LtildeStruct y FEVD', ok_c3b, '');
catch ME_c2
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C2: spec_oil_is termina sin error (nd=500)', false, ME_c2.message);
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C3b: Results_is contiene LtildeStruct y FEVD', false, 'run falló');
end

% C4: draws IS aceptados
if ~isempty(Results_is) && isfield(Results_is,'uw')
    n_acc = sum(Results_is.uw > 0);
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C4: IS tiene draws aceptados (uw>0)', n_acc > 0, ...
        sprintf('%d draws aceptados de %d', n_acc, Cfg_run_is.ND));
else
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C4: IS tiene draws aceptados (uw>0)', false, 'run_is falló');
end

% C5: print_summary PFA
if ~isempty(Results_pfa)
    try
        fprintf('\n  -- print_summary (spec_oil_pfa) --\n');
        print_summary(Results_pfa.LtildeStruct, Dataset_pfa, Cfg_run_pfa);
        [n_pass, n_fail] = rpt(n_pass, n_fail, 'C5: print_summary imprime sin error (PFA)', true, '');
    catch ME_c5
        [n_pass, n_fail] = rpt(n_pass, n_fail, 'C5: print_summary imprime sin error (PFA)', false, ME_c5.message);
    end
else
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C5: print_summary imprime sin error (PFA)', false, 'run_pfa falló');
end

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN D — Regresión numérica BNW
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN D — Regresión numérica BNW (nd=500, rng(0))\n');
fprintf('-----------------------------------------------------\n\n');

% Cfg BNW PFA (replica spec_bnw_pfa, nd=500 para test rápido)
n5 = 5; e5 = eye(n5);
Cfg_bnw_p              = struct();
Cfg_bnw_p.NLAG         = 4;
Cfg_bnw_p.NEX          = 1;
Cfg_bnw_p.HORIZON      = 40;
Cfg_bnw_p.INDEX_FEVD   = 40;
Cfg_bnw_p.SCALE_FACTOR = 100;
Cfg_bnw_p.MODE         = 'pfa';
Cfg_bnw_p.ND           = 500;
Cfg_bnw_p.MAX_IS_DRAWS = 500;
Cfg_bnw_p.CONJUGATE    = 'irfs';
Cfg_bnw_p.SEED         = 0;
Cfg_bnw_p.HORIZONS_RESTRICT = 0;
Cfg_bnw_p.NS           = 1;
Cfg_bnw_p.DATA_FILE    = '';       % usa data_bnw.xlsx del proyecto
Cfg_bnw_p.TIMING_VARIANT = [];
Cfg_bnw_p.DERIV_SIDED  = 2;
Cfg_bnw_p.SAVE_RESULTS = false;
Cfg_bnw_p.PLOT_IRFS    = false;
Cfg_bnw_p.ITER_SHOW    = 200;
Cfg_bnw_p.Z            = cell(n5,1);  Cfg_bnw_p.Z{1} = e5(1,:);
Cfg_bnw_p.S            = cell(n5,1);  Cfg_bnw_p.S{1} = e5(2,:);

% D1: BNW PFA — Ltilde(1,1,1) == 0
try
    rng(0);
    DS_bnw_p  = load_data(Cfg_bnw_p);
    Post_bnw_p = build_posterior(DS_bnw_p, Cfg_bnw_p);
    rng(0);
    R_bnw_p   = run_pfa(Post_bnw_p, Cfg_bnw_p);
    v_d1      = R_bnw_p.LtildeStruct.data(1,1,1);
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'D1: BNW PFA Ltilde(1,1,1)==0 (zero restriction)', ...
        abs(v_d1) < 1e-8, sprintf('valor=%.10f', v_d1));
catch ME_d1
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'D1: BNW PFA Ltilde(1,1,1)==0', false, ME_d1.message);
end

% D2: BNW IS — Ltilde(1,1,1,1) == 0
Cfg_bnw_i              = Cfg_bnw_p;
Cfg_bnw_i.MODE         = 'is';
Cfg_bnw_i.CONJUGATE    = 'structural';
Cfg_bnw_i.HORIZONS_RESTRICT = 0;

try
    rng(0);
    DS_bnw_i   = load_data(Cfg_bnw_i);
    Post_bnw_i = build_posterior(DS_bnw_i, Cfg_bnw_i);
    rng(0);
    R_bnw_i    = run_is(Post_bnw_i, Cfg_bnw_i);
    v_d2       = R_bnw_i.LtildeStruct.data(1,1,1,1);
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'D2: BNW IS Ltilde(1,1,1,1)==0 (zero restriction)', ...
        abs(v_d2) < 1e-8, sprintf('valor=%.10f', v_d2));
catch ME_d2
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'D2: BNW IS Ltilde(1,1,1,1)==0', false, ME_d2.message);
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

%% ── Función auxiliar de reporte ──────────────────────────────────────────
function [np, nf] = rpt(np, nf, label, ok, detail)
    if ok
        fprintf('  [PASA]  %s\n', label);
        np = np + 1;
    else
        fprintf('  [FALLA] %s\n', label);
        if nargin >= 5 && ~isempty(detail)
            fprintf('          %s\n', detail);
        end
        nf = nf + 1;
    end
end
