%VALIDATE_LOTE6  Script de verificacion — Chat 13: Lote 6 Loader extendido.
%
%   Tipo R: incluye condicion de regresion numerica exacta contra Fase 1.
%
%   Cobertura:
%     (a) Regresion: sin transforms ni dummies reproduce exactamente Fase 1
%     (b) Transform diff/dlog: Y_raw pierde primera fila, sin NaN residuales
%     (c) demean: media de columna transformada ≈ 0
%     (d) Loader generico (C2): funciona sin hoja varinfo con VAR_ROLES/LABELS
%     (e) Cfg.DUMMIES pulse: columna dummy correcta en Y_raw
%     (f) Error si transform desconocida
%     (g) Error si Cfg.VAR_ROLES faltante cuando no hay hoja varinfo
%
%   Uso: ejecutar directamente desde MATLAB (cualquier working directory).
%        No genera figuras ni guarda .mat.

fprintf('\n');
fprintf('================================================================\n');
fprintf(' VALIDATE_LOTE6 — Chat 13: Loader extendido (Tipo R)\n');
fprintf('================================================================\n\n');

%% -- Setup de rutas -------------------------------------------------------
val_root  = fileparts(mfilename('fullpath'));   % .../refactored/validate/
proj_root = fileparts(val_root);               % .../refactored/
src_dir   = fullfile(proj_root, 'src');
data_dir  = fullfile(proj_root, 'data');

addpath(src_dir);

% Chequeo de rutas relativas prohibidas
DOTDOT_PATTERN = '\.\.[/\\]';
src_files = dir(fullfile(src_dir, '*.m'));
ruta_ok = true;
for fi = 1:numel(src_files)
    fpath = fullfile(src_dir, src_files(fi).name);
    fid = fopen(fpath, 'r');
    ln_num = 0;
    while ~feof(fid)
        ln = fgetl(fid);
        ln_num = ln_num + 1;
        if ~ischar(ln), continue; end
        ln_trim = strtrim(ln);
        if startsWith(ln_trim, '%'), continue; end
        ln_check = regexprep(ln_trim, '\.\.\..*', '');
        if ~isempty(regexp(ln_check, DOTDOT_PATTERN, 'once'))
            fprintf('  [RUTA PROHIBIDA] %s, linea %d: %s\n', ...
                src_files(fi).name, ln_num, ln_trim);
            ruta_ok = false;
        end
    end
    fclose(fid);
end
if ruta_ok
    fprintf('[OK] Checker de rutas: ninguna ruta relativa prohibida encontrada\n\n');
else
    fprintf('[FALLO] Se encontraron rutas relativas prohibidas\n\n');
end

%% -- Cfg base (replica spec_bnw_pfa sin TRANSFORMS ni DUMMIES) -----------
function Cfg = make_base_cfg()
    Cfg.DATA_FILE    = '';
    Cfg.NLAG         = 4;
    Cfg.NEX          = 1;
    Cfg.HORIZON      = 40;
    Cfg.INDEX_FEVD   = 40;
    Cfg.SCALE_FACTOR = 100;
    Cfg.MODE         = 'pfa';
    Cfg.ND           = 1e4;
    Cfg.MAX_IS_DRAWS = 1e4;
    Cfg.CONJUGATE    = 'irfs';
    Cfg.SEED         = 0;
    Cfg.HORIZONS_RESTRICT = 0;
    Cfg.NS           = 1;
    n_v = 5; e_id = eye(n_v);
    Cfg.Z = cell(n_v,1); Cfg.Z{1} = e_id(1,:);
    Cfg.S = cell(n_v,1); Cfg.S{1} = e_id(2,:);
    Cfg.TIMING_VARIANT = [];
    Cfg.DERIV_SIDED    = 2;
    Cfg.SAVE_RESULTS   = false;
    Cfg.PLOT_IRFS      = false;
    Cfg.ITER_SHOW      = 2000;
end

Cfg_base = make_base_cfg();

%% =========================================================================
%% TEST (a) — Regresion exacta contra Fase 1
%% =========================================================================
fprintf('--- TEST (a): Regresion exacta contra Fase 1 ---\n');

REF_NVAR       = 5;
REF_NVAR_TOTAL = 5;
REF_NROW       = 224;
REF_DATE_1     = '1955.1';
REF_DATE_END   = '2010.4';
REF_Y1 = [0.21720722, -11.28894962, -4.33186596, 0.00802225, -7.59918428];
TOL = 1e-6;

try
    D = load_data(Cfg_base);

    ok = isequal(D.nvar, REF_NVAR) && ...
         isequal(D.nvar_total, REF_NVAR_TOTAL) && ...
         isequal(size(D.Y_raw), [REF_NROW, REF_NVAR_TOTAL]) && ...
         strcmp(D.dates{1}, REF_DATE_1) && ...
         strcmp(D.dates{end}, REF_DATE_END) && ...
         all(abs(D.Y_raw(1,:) - REF_Y1) < TOL) && ...
         isempty(D.transforms_applied.var) && ...
         isempty(D.dummies_applied.name);

    if ok
        fprintf('  [PASA] nvar=%d, nvar_total=%d, size=[%d,%d]\n', ...
            D.nvar, D.nvar_total, size(D.Y_raw,1), size(D.Y_raw,2));
        fprintf('         Y_raw(1,:)=[%.8f, %.8f, %.8f, %.8f, %.8f]\n', ...
            D.Y_raw(1,1), D.Y_raw(1,2), D.Y_raw(1,3), D.Y_raw(1,4), D.Y_raw(1,5));
        fprintf('         dates{1}=''%s'', dates{end}=''%s''\n', ...
            D.dates{1}, D.dates{end});
        fprintf('         transforms_applied.var: vacio [OK]\n');
    else
        fprintf('  [FALLO] nvar=%d(ref=%d), size=[%d,%d](ref=[%d,%d])\n', ...
            D.nvar, REF_NVAR, size(D.Y_raw,1), size(D.Y_raw,2), REF_NROW, REF_NVAR_TOTAL);
        fprintf('         Y_raw(1,1)=%.8f (ref=%.8f)\n', D.Y_raw(1,1), REF_Y1(1));
    end
catch ME
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (b) — diff/dlog: Y_raw pierde primera fila, sin NaN
%% =========================================================================
fprintf('--- TEST (b): Transforms diff y dlog ---\n');

try
    % --- diff sobre columna 3 (Consumption) ---
    Cfg_b = make_base_cfg();
    Cfg_b.TRANSFORMS = struct('var', {3}, 'transform', {{'diff'}});
    D_b = load_data(Cfg_b);

    exp_rows = REF_NROW - 1;  % 223
    ok_diff = isequal(size(D_b.Y_raw), [exp_rows, REF_NVAR]) && ...
              ~any(isnan(D_b.Y_raw(1,:))) && ...
              numel(D_b.transforms_applied.var) == 1;

    if ok_diff
        fprintf('  [PASA] diff: size(Y_raw)=[%d,%d], sin NaN en fila 1\n', ...
            size(D_b.Y_raw,1), size(D_b.Y_raw,2));
        fprintf('         transforms_applied: var=%s, transform=''%s''\n', ...
            num2str(D_b.transforms_applied.var{1}), ...
            D_b.transforms_applied.transform{1});
    else
        fprintf('  [FALLO] diff: size=[%d,%d](esperado[%d,%d]), NaN=%d\n', ...
            size(D_b.Y_raw,1), size(D_b.Y_raw,2), exp_rows, REF_NVAR, ...
            any(isnan(D_b.Y_raw(1,:))));
    end

    % --- dlog sobre columna 1 (TFP, valores positivos ~0.21) ---
    Cfg_b2 = make_base_cfg();
    Cfg_b2.TRANSFORMS = struct('var', {1}, 'transform', {{'dlog'}});
    D_b2 = load_data(Cfg_b2);

    ok_dlog = isequal(size(D_b2.Y_raw), [exp_rows, REF_NVAR]) && ...
              ~any(isnan(D_b2.Y_raw(1,:)));

    if ok_dlog
        fprintf('  [PASA] dlog: size(Y_raw)=[%d,%d], sin NaN en fila 1\n', ...
            size(D_b2.Y_raw,1), size(D_b2.Y_raw,2));
    else
        fprintf('  [FALLO] dlog: size=[%d,%d], NaN=%d\n', ...
            size(D_b2.Y_raw,1), size(D_b2.Y_raw,2), any(isnan(D_b2.Y_raw(1,:))));
    end

    % --- diff + demean combinados (dos transforms) ---
    tf_multi(1).var = 3; tf_multi(1).transform = 'diff';
    tf_multi(2).var = 4; tf_multi(2).transform = 'demean';
    Cfg_b3 = make_base_cfg();
    Cfg_b3.TRANSFORMS = tf_multi;
    D_b3 = load_data(Cfg_b3);
    % Con diff pierde una fila; demean es en linea (sin perdida)
    ok_multi = isequal(size(D_b3.Y_raw), [223, REF_NVAR]) && ...
               abs(mean(D_b3.Y_raw(:,4))) < 1e-10 && ...
               numel(D_b3.transforms_applied.var) == 2;
    if ok_multi
        fprintf('  [PASA] diff+demean combinados: size=[%d,%d], mean(col4)=%.2e\n', ...
            size(D_b3.Y_raw,1), size(D_b3.Y_raw,2), mean(D_b3.Y_raw(:,4)));
    else
        fprintf('  [FALLO] diff+demean: size=[%d,%d], mean(col4)=%.6f\n', ...
            size(D_b3.Y_raw,1), size(D_b3.Y_raw,2), mean(D_b3.Y_raw(:,4)));
    end

catch ME
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (c) — demean: media ≈ 0, otras columnas sin cambio
%% =========================================================================
fprintf('--- TEST (c): Transform demean ---\n');

try
    Cfg_c = make_base_cfg();
    Cfg_c.TRANSFORMS = struct('var', {3}, 'transform', {{'demean'}});
    D_c = load_data(Cfg_c);
    D_orig = load_data(Cfg_base);

    col_mean  = mean(D_c.Y_raw(:, 3));
    col1_same = abs(D_c.Y_raw(1,1) - D_orig.Y_raw(1,1)) < TOL;
    nrow_same = isequal(size(D_c.Y_raw,1), REF_NROW);  % demean no quita filas

    ok_c = abs(col_mean) < 1e-10 && col1_same && nrow_same;

    if ok_c
        fprintf('  [PASA] mean(col3)=%.2e, col1(1) sin cambio, nrow=%d\n', ...
            col_mean, size(D_c.Y_raw,1));
    else
        fprintf('  [FALLO] mean(col3)=%.10f, col1_same=%d, nrow=%d(ref=%d)\n', ...
            col_mean, col1_same, size(D_c.Y_raw,1), REF_NROW);
    end

catch ME
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (d) — Loader generico sin hoja varinfo
%% =========================================================================
fprintf('--- TEST (d): Loader generico (C2) ---\n');

tmp_xlsx_d = fullfile(data_dir, 'tmp_test_lote6_c2.xlsx');
try
    T_d = table({'2000.1';'2000.2';'2000.3';'2000.4'}, ...
                [1.0;1.1;1.2;1.3], [2.0;2.1;2.2;2.3], ...
                'VariableNames', {'date','var1','var2'});
    writetable(T_d, tmp_xlsx_d, 'Sheet', 1);

    Cfg_d.DATA_FILE    = tmp_xlsx_d;
    Cfg_d.NLAG         = 1;
    Cfg_d.NEX          = 1;
    Cfg_d.HORIZON      = 5;
    Cfg_d.INDEX_FEVD   = 5;
    Cfg_d.SCALE_FACTOR = 1;
    Cfg_d.MODE         = 'pfa';
    Cfg_d.ND           = 100;
    Cfg_d.MAX_IS_DRAWS = 100;
    Cfg_d.CONJUGATE    = 'irfs';
    Cfg_d.SEED         = 0;
    Cfg_d.HORIZONS_RESTRICT = 0;
    Cfg_d.NS           = 1;
    Cfg_d.Z = cell(2,1);
    Cfg_d.S = cell(2,1);
    Cfg_d.TIMING_VARIANT = [];
    Cfg_d.DERIV_SIDED    = 2;
    Cfg_d.SAVE_RESULTS   = false;
    Cfg_d.PLOT_IRFS      = false;
    Cfg_d.ITER_SHOW      = 1000;
    Cfg_d.VAR_ROLES  = {'endogenous', 'exogenous'};
    Cfg_d.VAR_LABELS = {'PIB', 'Tasa'};

    D_d = load_data(Cfg_d);

    ok_d = isequal(D_d.nvar, 1) && ...
           isequal(D_d.nvar_total, 2) && ...
           isequal(size(D_d.Y_raw), [4, 2]) && ...
           strcmp(D_d.var_roles{1}, 'endogenous') && ...
           strcmp(D_d.var_roles{2}, 'exogenous') && ...
           strcmp(D_d.var_labels{1}, 'PIB') && ...
           strcmp(D_d.var_labels{2}, 'Tasa');

    if ok_d
        fprintf('  [PASA] nvar=%d (endo), nvar_total=%d, size=[%d,%d]\n', ...
            D_d.nvar, D_d.nvar_total, size(D_d.Y_raw,1), size(D_d.Y_raw,2));
        fprintf('         roles={''%s'',''%s''}, labels={''%s'',''%s''}\n', ...
            D_d.var_roles{1}, D_d.var_roles{2}, ...
            D_d.var_labels{1}, D_d.var_labels{2});
    else
        fprintf('  [FALLO] nvar=%d, nvar_total=%d, size=[%d,%d]\n', ...
            D_d.nvar, D_d.nvar_total, size(D_d.Y_raw,1), size(D_d.Y_raw,2));
    end

    if isfile(tmp_xlsx_d), delete(tmp_xlsx_d); end

catch ME
    if isfile(tmp_xlsx_d), delete(tmp_xlsx_d); end
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (e) — Cfg.DUMMIES pulse
%% =========================================================================
fprintf('--- TEST (e): Cfg.DUMMIES pulse ---\n');

try
    Cfg_e = make_base_cfg();
    Cfg_e.DUMMIES = struct('name','pulse_q10','type','pulse','date_idx',10);

    D_e = load_data(Cfg_e);

    ok_e = isequal(size(D_e.Y_raw), [224, 6]) && ...
           D_e.Y_raw(10, 6) == 1 && ...
           sum(D_e.Y_raw(:, 6)) == 1 && ...
           D_e.nvar_total == 6 && ...
           strcmp(D_e.var_roles{6}, 'exogenous') && ...
           ~isempty(D_e.dummies_applied.name);

    if ok_e
        fprintf('  [PASA] size=[%d,%d], Y_raw(10,6)=%d, sum(col6)=%d\n', ...
            size(D_e.Y_raw,1), size(D_e.Y_raw,2), ...
            D_e.Y_raw(10,6), sum(D_e.Y_raw(:,6)));
        fprintf('         var_roles{6}=''%s'', dummy=''%s''\n', ...
            D_e.var_roles{6}, D_e.dummies_applied.name{1});
    else
        fprintf('  [FALLO] size=[%d,%d], Y_raw(10,6)=%d, sum=%d, nvar_total=%d\n', ...
            size(D_e.Y_raw,1), size(D_e.Y_raw,2), ...
            D_e.Y_raw(10,6), sum(D_e.Y_raw(:,6)), D_e.nvar_total);
    end

    % Test adicional: step dummy
    Cfg_e2 = make_base_cfg();
    Cfg_e2.DUMMIES = struct('name','step_q50','type','step','date_idx',50);
    D_e2 = load_data(Cfg_e2);
    ok_step = D_e2.Y_raw(49,6) == 0 && ...
              D_e2.Y_raw(50,6) == 1 && ...
              D_e2.Y_raw(end,6) == 1 && ...
              sum(D_e2.Y_raw(:,6)) == (224 - 50 + 1);
    if ok_step
        fprintf('  [PASA] step: 0 antes t=50, 1 desde t=50, sum=%d\n', sum(D_e2.Y_raw(:,6)));
    else
        fprintf('  [FALLO] step: Y_raw(49,6)=%d, Y_raw(50,6)=%d\n', ...
            D_e2.Y_raw(49,6), D_e2.Y_raw(50,6));
    end

catch ME
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (f) — Error si transform desconocida
%% =========================================================================
fprintf('--- TEST (f): Error en transform desconocida ---\n');

try
    Cfg_f = make_base_cfg();
    Cfg_f.TRANSFORMS = struct('var', {1}, 'transform', {{'badtransform_xyz'}});
    load_data(Cfg_f);
    fprintf('  [FALLO] No se lanzo error para transform desconocida\n');
catch ME
    if contains(ME.identifier, 'unknownTransform') || ...
       contains(ME.message, 'desconocida') || contains(ME.message, 'Validas')
        fprintf('  [PASA] Error correcto: %s\n', ME.message);
    else
        fprintf('  [FALLO] Error inesperado (id=%s): %s\n', ME.identifier, ME.message);
    end
end
fprintf('\n');

%% =========================================================================
%% TEST (g) — Error si VAR_ROLES faltante sin hoja varinfo
%% =========================================================================
fprintf('--- TEST (g): Error si VAR_ROLES faltante en loader generico ---\n');

tmp_xlsx_g = fullfile(data_dir, 'tmp_test_lote6_g.xlsx');
try
    T_g = table({'2000.1';'2000.2'}, [1.0;1.1], [2.0;2.1], ...
                'VariableNames', {'date','v1','v2'});
    writetable(T_g, tmp_xlsx_g, 'Sheet', 1);

    Cfg_g.DATA_FILE    = tmp_xlsx_g;
    Cfg_g.NLAG         = 1;
    Cfg_g.NEX          = 1;
    Cfg_g.HORIZON      = 5;
    Cfg_g.INDEX_FEVD   = 5;
    Cfg_g.SCALE_FACTOR = 1;
    Cfg_g.MODE         = 'pfa';
    Cfg_g.ND           = 100;
    Cfg_g.MAX_IS_DRAWS = 100;
    Cfg_g.CONJUGATE    = 'irfs';
    Cfg_g.SEED         = 0;
    Cfg_g.HORIZONS_RESTRICT = 0;
    Cfg_g.NS           = 1;
    Cfg_g.Z = cell(2,1);
    Cfg_g.S = cell(2,1);
    Cfg_g.TIMING_VARIANT = [];
    Cfg_g.DERIV_SIDED    = 2;
    Cfg_g.SAVE_RESULTS   = false;
    Cfg_g.PLOT_IRFS      = false;
    Cfg_g.ITER_SHOW      = 1000;
    % Sin Cfg.VAR_ROLES

    load_data(Cfg_g);
    fprintf('  [FALLO] No se lanzo error cuando falta VAR_ROLES\n');
    if isfile(tmp_xlsx_g), delete(tmp_xlsx_g); end

catch ME
    if isfile(tmp_xlsx_g), delete(tmp_xlsx_g); end
    if contains(ME.identifier, 'missingVarRoles') || ...
       contains(ME.message, 'VAR_ROLES')
        fprintf('  [PASA] Error correcto: %s\n', ME.message);
    else
        fprintf('  [FALLO] Error inesperado (id=%s): %s\n', ME.identifier, ME.message);
    end
end
fprintf('\n');

%% =========================================================================
%% Resumen final
%% =========================================================================
fprintf('================================================================\n');
fprintf(' VALIDATE_LOTE6 completado.\n');
fprintf(' Tests cubiertos: (a) regresion Fase1, (b) diff/dlog,\n');
fprintf('   (c) demean, (d) loader generico, (e) dummies pulse+step,\n');
fprintf('   (f) error transform desconocida, (g) error VAR_ROLES faltante\n');
fprintf(' Reportar resultados PASA/FALLO al chat.\n');
fprintf('================================================================\n\n');
