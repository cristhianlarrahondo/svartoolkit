%VALIDATE_LOTE6  Script de verificacion — Chat 13: Lote 6 Loader extendido.
%
%   Tipo R. Cubre:
%     (a) Regresion exacta Fase 1: fechas datetime, Y_raw identico
%     (b) Regresion exacta Fases 2/3: build_posterior sin dummies = original
%     (c) build_dummies oneoff: columna correcta en xt de PosteriorParams
%     (d) build_dummies pulse: rango correcto
%     (e) build_dummies step: desde fecha
%     (f) Orden en xt: constante en col n*p+1, dummies al final
%     (g) Error si tipo de dummy desconocido
%     (h) Error si fecha no encontrada en Dataset.dates
%     (i) Error si Dataset.dates no es datetime al usar dummies
%
%   Uso: ejecutar desde MATLAB (cualquier working directory).
%        No genera figuras ni guarda .mat.

fprintf('\n');
fprintf('================================================================\n');
fprintf(' VALIDATE_LOTE6 — Chat 13: Lote 6 (Tipo R)\n');
fprintf('================================================================\n\n');

%% -- Setup de rutas -----------------------------------------------------
val_root  = fileparts(mfilename('fullpath'));
proj_root = fileparts(val_root);
src_dir   = fullfile(proj_root, 'src');
addpath(src_dir);
addpath(fullfile(proj_root, 'helpfunctions'));

%% -- Checker de rutas prohibidas ----------------------------------------
DOTDOT = '\.\.[/\\]';
src_files = dir(fullfile(src_dir, '*.m'));
ruta_ok = true;
for fi = 1:numel(src_files)
    fid = fopen(fullfile(src_dir, src_files(fi).name), 'r');
    lnum = 0;
    while ~feof(fid)
        ln = fgetl(fid); lnum = lnum+1;
        if ~ischar(ln), continue; end
        lt = strtrim(ln);
        if startsWith(lt,'%'), continue; end
        lc = regexprep(lt,'\.\.\..*','');
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

%% -- Cfg base (replica spec_bnw_pfa) ------------------------------------
function Cfg = make_cfg()
    Cfg.DATA_FILE    = '';
    Cfg.NLAG         = 4;   Cfg.NEX          = 1;
    Cfg.HORIZON      = 40;  Cfg.INDEX_FEVD   = 40;
    Cfg.SCALE_FACTOR = 100; Cfg.MODE         = 'pfa';
    Cfg.ND           = 1e4; Cfg.MAX_IS_DRAWS = 1e4;
    Cfg.CONJUGATE    = 'irfs'; Cfg.SEED       = 0;
    Cfg.HORIZONS_RESTRICT = 0; Cfg.NS         = 1;
    n_v = 5; e_id = eye(n_v);
    Cfg.Z = cell(n_v,1); Cfg.Z{1} = e_id(1,:);
    Cfg.S = cell(n_v,1); Cfg.S{1} = e_id(2,:);
    Cfg.TIMING_VARIANT = []; Cfg.DERIV_SIDED = 2;
    Cfg.SAVE_RESULTS = false; Cfg.PLOT_IRFS = false;
    Cfg.ITER_SHOW = 2000;
end

TOL = 1e-6;

%% =========================================================================
%% TEST (a) — Regresion Fase 1: Dataset con datetime correcto
%% =========================================================================
fprintf('--- TEST (a): Regresion Fase 1 con fechas datetime ---\n');

REF_NVAR  = 5;  REF_NROW = 224;
REF_Y1    = [0.21720722, -11.28894962, -4.33186596, 0.00802225, -7.59918428];
% Fechas en nuevo formato datetime (Q1 1955 = 31/03/1955)
REF_DATE1_YM = [1955, 3];    % year=1955, month=3
REF_DATE_END_YM = [2010, 12]; % year=2010, month=12

try
    D = load_data(make_cfg());

    ok_dt   = isdatetime(D.dates);
    ok_yr1  = year(D.dates(1))  == REF_DATE1_YM(1) && ...
              month(D.dates(1)) == REF_DATE1_YM(2);
    ok_yrE  = year(D.dates(end))  == REF_DATE_END_YM(1) && ...
              month(D.dates(end)) == REF_DATE_END_YM(2);
    ok_size = isequal(size(D.Y_raw), [REF_NROW, REF_NVAR]);
    ok_vals = all(abs(D.Y_raw(1,:) - REF_Y1) < TOL);
    ok_freq = ~isempty(D.freq);

    if ok_dt && ok_yr1 && ok_yrE && ok_size && ok_vals
        fprintf('  [PASA] datetime OK, size=[%d,%d], freq=''%s''\n', ...
            size(D.Y_raw,1), size(D.Y_raw,2), D.freq);
        fprintf('         dates(1): %s | dates(end): %s\n', ...
            datestr(D.dates(1),'dd/mm/yyyy'), datestr(D.dates(end),'dd/mm/yyyy'));
        fprintf('         Y_raw(1,:)=[%.6f, %.6f, ...]\n', D.Y_raw(1,1), D.Y_raw(1,2));
    else
        fprintf('  [FALLO] isdatetime=%d, yr1=%d, yrE=%d, size=%d, vals=%d\n', ...
            ok_dt, ok_yr1, ok_yrE, ok_size, ok_vals);
    end
catch ME
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (b) — Regresion Fases 2/3: build_posterior sin dummies = original
%% =========================================================================
fprintf('--- TEST (b): Regresion Fases 2/3 — build_posterior sin dummies ---\n');

REF_BPOST.n = 5;  REF_BPOST.p = 4;
REF_BPOST.m = 21;  % 5*4 + 1 constante
REF_BPOST.ndummies = 0;

try
    D   = load_data(make_cfg());
    PP  = build_posterior(D, make_cfg());

    ok = PP.n == REF_BPOST.n && ...
         PP.p == REF_BPOST.p && ...
         PP.m == REF_BPOST.m && ...
         PP.ndummies == REF_BPOST.ndummies && ...
         isequal(size(PP.Y), [D.nvar, 1]') && ... % T x n  (chequeo indirecto)
         isequal(size(PP.X), [size(PP.Y,1), PP.m]);

    % Verificar que constante esta en col n*p+1 = col 21
    const_col = PP.X(:, PP.n*PP.p + 1);
    ok_const  = all(const_col == 1);

    if ok && ok_const
        fprintf('  [PASA] n=%d, p=%d, m=%d, ndummies=%d\n', PP.n, PP.p, PP.m, PP.ndummies);
        fprintf('         size(Y)=[%d,%d], size(X)=[%d,%d]\n', ...
            size(PP.Y,1), size(PP.Y,2), size(PP.X,1), size(PP.X,2));
        fprintf('         Constante en col %d: todos 1 [OK]\n', PP.n*PP.p+1);
    else
        fprintf('  [FALLO] m=%d(ref=%d), ndummies=%d(ref=%d), const_ok=%d\n', ...
            PP.m, REF_BPOST.m, PP.ndummies, REF_BPOST.ndummies, ok_const);
    end
catch ME
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (c) — build_dummies oneoff: una sola celda en xt
%% =========================================================================
fprintf('--- TEST (c): Dummy oneoff ---\n');

try
    Cfg_c = make_cfg();
    % Q1 1970 = 31/03/1970 -> [1970, 3]
    Cfg_c.DUMMIES(1).name = 'test_oneoff';
    Cfg_c.DUMMIES(1).type = 'oneoff';
    Cfg_c.DUMMIES(1).date = [1970, 3];

    D_c  = load_data(Cfg_c);
    PP_c = build_posterior(D_c, Cfg_c);

    % m debe ser 22 (21 + 1 dummy)
    ok_m = PP_c.m == 22 && PP_c.ndummies == 1;

    % La columna de la dummy en X es la ultima (col 22)
    dummy_col = PP_c.X(:, end);
    ok_sum    = sum(dummy_col) == 1;
    % La constante sigue en col 21
    ok_const  = all(PP_c.X(:, PP_c.n*PP_c.p+1) == 1);

    if ok_m && ok_sum && ok_const
        % Encontrar en qué fila está el 1
        t_dummy = find(dummy_col == 1);
        fprintf('  [PASA] m=22, ndummies=1, sum(dummy_col)=1\n');
        fprintf('         Dummy activa en fila %d\n', t_dummy);
        fprintf('         Constante en col %d: todos 1 [OK]\n', PP_c.n*PP_c.p+1);
    else
        fprintf('  [FALLO] m=%d(ref=22), ndummies=%d, sum=%d, const_ok=%d\n', ...
            PP_c.m, PP_c.ndummies, sum(dummy_col), ok_const);
    end
catch ME
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (d) — build_dummies pulse: rango correcto
%% =========================================================================
fprintf('--- TEST (d): Dummy pulse ---\n');

try
    Cfg_d = make_cfg();
    % COVID: Q1 2007 - Q4 2007 (dentro del rango de datos)
    Cfg_d.DUMMIES(1).name       = 'test_pulse';
    Cfg_d.DUMMIES(1).type       = 'pulse';
    Cfg_d.DUMMIES(1).date_start = [2007, 3];
    Cfg_d.DUMMIES(1).date_end   = [2007, 12];

    D_d  = load_data(Cfg_d);
    PP_d = build_posterior(D_d, Cfg_d);

    dummy_col = PP_d.X(:, end);
    n_ones    = sum(dummy_col);     % debe ser 4 trimestres
    ok = PP_d.ndummies == 1 && n_ones == 4;

    if ok
        fprintf('  [PASA] ndummies=1, sum(dummy_col)=%d (4 trimestres)\n', n_ones);
        t_start = find(dummy_col==1, 1, 'first');
        t_end   = find(dummy_col==1, 1, 'last');
        fprintf('         Filas activas: %d a %d (consecutivas=%d)\n', ...
            t_start, t_end, (t_end-t_start+1)==4);
    else
        fprintf('  [FALLO] ndummies=%d, n_ones=%d (esperado 4)\n', PP_d.ndummies, n_ones);
    end
catch ME
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (e) — build_dummies step: desde fecha hasta el final
%% =========================================================================
fprintf('--- TEST (e): Dummy step ---\n');

try
    Cfg_e = make_cfg();
    % Step desde Q1 2000 = [2000, 3]
    Cfg_e.DUMMIES(1).name = 'test_step';
    Cfg_e.DUMMIES(1).type = 'step';
    Cfg_e.DUMMIES(1).date = [2000, 3];

    D_e  = load_data(Cfg_e);
    PP_e = build_posterior(D_e, Cfg_e);

    dummy_col = PP_e.X(:, end);
    t_start   = find(dummy_col==1, 1, 'first');
    t_end_0   = find(dummy_col==0, 1, 'last');
    all_after = all(dummy_col(t_start:end) == 1);

    ok = PP_e.ndummies == 1 && all_after && ...
         (isempty(t_end_0) || t_end_0 < t_start);

    if ok
        fprintf('  [PASA] ndummies=1, step desde fila %d, all_after=true\n', t_start);
        fprintf('         sum(dummy)=%d, T=%d\n', sum(dummy_col), size(PP_e.X,1));
    else
        fprintf('  [FALLO] ndummies=%d, all_after=%d\n', PP_e.ndummies, all_after);
    end
catch ME
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (f) — Orden xt: constante col n*p+1, dos dummies al final
%% =========================================================================
fprintf('--- TEST (f): Orden en xt con dos dummies ---\n');

try
    Cfg_f = make_cfg();
    Cfg_f.DUMMIES(1).name = 'd1'; Cfg_f.DUMMIES(1).type = 'oneoff';
    Cfg_f.DUMMIES(1).date = [1970, 3];
    Cfg_f.DUMMIES(2).name = 'd2'; Cfg_f.DUMMIES(2).type = 'oneoff';
    Cfg_f.DUMMIES(2).date = [1980, 3];

    D_f  = load_data(Cfg_f);
    PP_f = build_posterior(D_f, Cfg_f);

    n=PP_f.n; p=PP_f.p;
    % m debe ser 23 (21 + 2 dummies)
    ok_m     = PP_f.m == 23 && PP_f.ndummies == 2;
    ok_const = all(PP_f.X(:, n*p+1) == 1);         % col 21 = constante
    ok_d1    = sum(PP_f.X(:, n*p+2)) == 1;          % col 22 = dummy 1
    ok_d2    = sum(PP_f.X(:, n*p+3)) == 1;          % col 23 = dummy 2
    % Las dos dummies deben ser distintas (1 en filas diferentes)
    ok_diff  = sum(PP_f.X(:,n*p+2) & PP_f.X(:,n*p+3)) == 0;

    if ok_m && ok_const && ok_d1 && ok_d2 && ok_diff
        fprintf('  [PASA] m=23, ndummies=2\n');
        fprintf('         Col %d=constante, col %d=d1, col %d=d2\n', n*p+1, n*p+2, n*p+3);
        fprintf('         Filas activas: d1=%d, d2=%d (distintas)\n', ...
            find(PP_f.X(:,n*p+2)==1), find(PP_f.X(:,n*p+3)==1));
    else
        fprintf('  [FALLO] m=%d, const=%d, d1=%d, d2=%d, diff=%d\n', ...
            PP_f.m, ok_const, ok_d1, ok_d2, ok_diff);
    end
catch ME
    fprintf('  [ERROR] %s\n', ME.message);
end
fprintf('\n');

%% =========================================================================
%% TEST (g) — Error si tipo de dummy desconocido
%% =========================================================================
fprintf('--- TEST (g): Error en tipo de dummy desconocido ---\n');

try
    D_g = load_data(make_cfg());
    Cfg_g = make_cfg();
    Cfg_g.DUMMIES(1).name = 'bad'; Cfg_g.DUMMIES(1).type = 'invalid_type';
    Cfg_g.DUMMIES(1).date = [1970,3];
    build_dummies(Cfg_g, D_g.dates);
    fprintf('  [FALLO] No se lanzo error para tipo desconocido\n');
catch ME
    if contains(ME.identifier,'unknownType') || contains(ME.message,'no reconocido')
        fprintf('  [PASA] Error correcto: %s\n', ME.message);
    else
        fprintf('  [FALLO] Error inesperado: %s\n', ME.message);
    end
end
fprintf('\n');

%% =========================================================================
%% TEST (h) — Error si fecha no encontrada en Dataset.dates
%% =========================================================================
fprintf('--- TEST (h): Error si fecha fuera de rango ---\n');

try
    D_h = load_data(make_cfg());
    Cfg_h = make_cfg();
    Cfg_h.DUMMIES(1).name = 'future'; Cfg_h.DUMMIES(1).type = 'oneoff';
    Cfg_h.DUMMIES(1).date = [2030, 3];  % fuera del rango de datos
    build_dummies(Cfg_h, D_h.dates);
    fprintf('  [FALLO] No se lanzo error para fecha fuera de rango\n');
catch ME
    if contains(ME.identifier,'dateNotFound') || contains(ME.message,'no encontrado')
        fprintf('  [PASA] Error correcto: %s\n', ME.message);
    else
        fprintf('  [FALLO] Error inesperado: %s\n', ME.message);
    end
end
fprintf('\n');

%% =========================================================================
%% TEST (i) — Error si Dataset.dates no es datetime
%% =========================================================================
fprintf('--- TEST (i): Error si dates no es datetime ---\n');

try
    Cfg_i = make_cfg();
    Cfg_i.DUMMIES(1).name='d'; Cfg_i.DUMMIES(1).type='oneoff';
    Cfg_i.DUMMIES(1).date=[1970,3];
    % Pasar cell array de strings en lugar de datetime
    fake_dates = {'31/03/1955'; '30/06/1955'};
    build_dummies(Cfg_i, fake_dates);
    fprintf('  [FALLO] No se lanzo error cuando dates no es datetime\n');
catch ME
    if contains(ME.identifier,'datesNotDatetime') || contains(ME.message,'datetime')
        fprintf('  [PASA] Error correcto: %s\n', ME.message);
    else
        fprintf('  [FALLO] Error inesperado: %s\n', ME.message);
    end
end
fprintf('\n');

%% =========================================================================
%% Resumen
%% =========================================================================
fprintf('================================================================\n');
fprintf(' VALIDATE_LOTE6 completado.\n');
fprintf(' Tests: (a) datetime Fase1, (b) build_posterior Fases2/3,\n');
fprintf('   (c) oneoff, (d) pulse, (e) step, (f) orden xt,\n');
fprintf('   (g) tipo invalido, (h) fecha fuera rango, (i) dates no datetime\n');
fprintf(' IMPORTANTE: el test (a) requiere que data_bnw.xlsx tenga\n');
fprintf(' la columna de fecha en formato DD/MM/AAAA (fecha real Excel).\n');
fprintf('================================================================\n\n');
