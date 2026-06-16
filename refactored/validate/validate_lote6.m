%VALIDATE_LOTE6  Script de verificacion — Chat 13: Lote 6 (Tipo R).
%
%   Cobertura:
%   SECCION A — Tests de loader y dummies (rapidos)
%     (a) Regresion Fase 1: fechas datetime, Y_raw identico
%     (b) build_posterior sin dummies: m=21, ndummies=0, constante fija
%     (c) Dummy oneoff: columna correcta en xt
%     (d) Dummy pulse: rango correcto
%     (e) Dummy step: desde fecha hasta el final
%     (f) Orden en xt con dos dummies
%     (g) Error tipo de dummy desconocido
%     (h) Error fecha fuera de rango
%     (i) Error si dates no es datetime al usar dummies
%
%   SECCION B — Regresion numerica exacta (lentos, nd completo)
%     (B1) PFA sin dummies, prior diffuse, rng(0) → valores Chat 7
%     (B2) IS  sin dummies, prior diffuse, rng(0) → valores Chat 7
%
%   SECCION C — Integracion end-to-end (nd=500, ~2 min total)
%     (C1) PFA + dummy oneoff: corre sin error, size(Ltilde) correcto
%     (C2) IS  + dummy oneoff: corre sin error, ne>0, pesos suman 1
%     (C3) PFA + prior minnesota, sin dummies: corre sin error
%     (C4) PFA + prior minnesota + dos dummies: corre sin error
%     (C5) IS  + prior minnesota + dummy pulse: corre sin error
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
addpath(fullfile(proj_root, 'validate'));

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
    Cfg.NLAG         = 4;    Cfg.NEX          = 1;
    Cfg.HORIZON      = 40;   Cfg.INDEX_FEVD   = 40;
    Cfg.SCALE_FACTOR = 100;  Cfg.MODE         = 'pfa';
    Cfg.ND           = 1e4;  Cfg.MAX_IS_DRAWS = 1e4;
    Cfg.CONJUGATE    = 'irfs'; Cfg.SEED        = 0;
    Cfg.HORIZONS_RESTRICT = 0; Cfg.NS          = 1;
    n_v = 5; e_id = eye(n_v);
    Cfg.Z = cell(n_v,1); Cfg.Z{1} = e_id(1,:);
    Cfg.S = cell(n_v,1); Cfg.S{1} = e_id(2,:);
    Cfg.TIMING_VARIANT = []; Cfg.DERIV_SIDED = 2;
    Cfg.SAVE_RESULTS = false; Cfg.PLOT_IRFS = false;
    Cfg.ITER_SHOW = 2000;
end

TOL = 1e-6;

%% ========================================================================
%% SECCION A — Tests de loader y dummies
%% ========================================================================
fprintf('════════════════════════════════════════════════════════════════\n');
fprintf(' SECCION A — Loader y dummies\n');
fprintf('════════════════════════════════════════════════════════════════\n\n');

%% TEST (a) — Regresion Fase 1 con datetime ------------------------------
fprintf('--- TEST (a): Regresion Fase 1 con fechas datetime ---\n');
REF_Y1 = [0.21720722, -11.28894962, -4.33186596, 0.00802225, -7.59918428];
try
    D = load_data(make_cfg());
    ok = isdatetime(D.dates) && ...
         year(D.dates(1))==1955 && month(D.dates(1))==3 && ...
         year(D.dates(end))==2010 && month(D.dates(end))==12 && ...
         isequal(size(D.Y_raw),[224,5]) && ...
         all(abs(D.Y_raw(1,:)-REF_Y1)<TOL) && ...
         strcmp(D.freq,'Q');
    if ok
        fprintf('  [PASA] datetime, size=[224,5], freq=Q\n');
        fprintf('         dates(1)=%s, dates(end)=%s\n', ...
            datestr(D.dates(1),'dd/mm/yyyy'), datestr(D.dates(end),'dd/mm/yyyy'));
    else
        fprintf('  [FALLO]\n');
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (b) — build_posterior sin dummies --------------------------------
fprintf('--- TEST (b): build_posterior sin dummies ---\n');
try
    D  = load_data(make_cfg());
    PP = build_posterior(D, make_cfg());
    ok_m      = PP.m == 21 && PP.ndummies == 0;
    ok_const  = all(PP.X(:, PP.n*PP.p+1) == 1);
    ok_size_Y = isequal(size(PP.Y,2), D.nvar);
    ok_size_X = isequal(size(PP.X), [size(PP.Y,1), PP.m]);
    if ok_m && ok_const && ok_size_Y && ok_size_X
        fprintf('  [PASA] m=21, ndummies=0, size(X)=[%d,%d], constante en col 21\n', ...
            size(PP.X,1), size(PP.X,2));
    else
        fprintf('  [FALLO] m=%d, ndummies=%d, const_ok=%d, sizeY=%d, sizeX=%d\n', ...
            PP.m, PP.ndummies, ok_const, ok_size_Y, ok_size_X);
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (c) — Dummy oneoff -----------------------------------------------
fprintf('--- TEST (c): Dummy oneoff ---\n');
try
    Cfg_c = make_cfg();
    Cfg_c.DUMMIES(1).name='d1'; Cfg_c.DUMMIES(1).type='oneoff';
    Cfg_c.DUMMIES(1).date=[1970,3];
    D_c  = load_data(Cfg_c);
    PP_c = build_posterior(D_c, Cfg_c);
    ok = PP_c.m==22 && PP_c.ndummies==1 && ...
         sum(PP_c.X(:,end))==1 && all(PP_c.X(:,PP_c.n*PP_c.p+1)==1);
    if ok
        fprintf('  [PASA] m=22, ndummies=1, 1 fila activa, constante fija\n');
    else
        fprintf('  [FALLO] m=%d, ndummies=%d\n', PP_c.m, PP_c.ndummies);
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (d) — Dummy pulse ------------------------------------------------
fprintf('--- TEST (d): Dummy pulse ---\n');
try
    Cfg_d = make_cfg();
    Cfg_d.DUMMIES(1).name='d1'; Cfg_d.DUMMIES(1).type='pulse';
    Cfg_d.DUMMIES(1).date_start=[2007,3];
    Cfg_d.DUMMIES(1).date_end=[2007,12];
    D_d  = load_data(Cfg_d);
    PP_d = build_posterior(D_d, Cfg_d);
    ok = PP_d.ndummies==1 && sum(PP_d.X(:,end))==4;
    if ok
        fprintf('  [PASA] ndummies=1, 4 filas activas (4 trimestres)\n');
    else
        fprintf('  [FALLO] ndummies=%d, sum=%d\n', PP_d.ndummies, sum(PP_d.X(:,end)));
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (e) — Dummy step -------------------------------------------------
fprintf('--- TEST (e): Dummy step ---\n');
try
    Cfg_e = make_cfg();
    Cfg_e.DUMMIES(1).name='d1'; Cfg_e.DUMMIES(1).type='step';
    Cfg_e.DUMMIES(1).date=[2000,3];
    D_e  = load_data(Cfg_e);
    PP_e = build_posterior(D_e, Cfg_e);
    col  = PP_e.X(:,end);
    t1   = find(col==1, 1, 'first');
    ok   = PP_e.ndummies==1 && all(col(t1:end)==1) && all(col(1:t1-1)==0);
    if ok
        fprintf('  [PASA] step desde fila %d, sum=%d\n', t1, sum(col));
    else
        fprintf('  [FALLO] ndummies=%d\n', PP_e.ndummies);
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (f) — Orden xt con dos dummies -----------------------------------
fprintf('--- TEST (f): Orden en xt con dos dummies ---\n');
try
    Cfg_f = make_cfg();
    Cfg_f.DUMMIES(1).name='d1'; Cfg_f.DUMMIES(1).type='oneoff';
    Cfg_f.DUMMIES(1).date=[1970,3];
    Cfg_f.DUMMIES(2).name='d2'; Cfg_f.DUMMIES(2).type='oneoff';
    Cfg_f.DUMMIES(2).date=[1980,3];
    D_f  = load_data(Cfg_f);
    PP_f = build_posterior(D_f, Cfg_f);
    n=PP_f.n; p=PP_f.p;
    ok = PP_f.m==23 && PP_f.ndummies==2 && ...
         all(PP_f.X(:,n*p+1)==1) && ...
         sum(PP_f.X(:,n*p+2))==1 && sum(PP_f.X(:,n*p+3))==1 && ...
         sum(PP_f.X(:,n*p+2) & PP_f.X(:,n*p+3))==0;
    if ok
        fprintf('  [PASA] m=23, ndummies=2, constante col %d, d1 col %d, d2 col %d\n', ...
            n*p+1, n*p+2, n*p+3);
    else
        fprintf('  [FALLO] m=%d, ndummies=%d\n', PP_f.m, PP_f.ndummies);
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (g) — Error tipo desconocido -------------------------------------
fprintf('--- TEST (g): Error tipo dummy desconocido ---\n');
try
    D_g = load_data(make_cfg());
    Cfg_g = make_cfg();
    Cfg_g.DUMMIES(1).name='bad'; Cfg_g.DUMMIES(1).type='invalid';
    Cfg_g.DUMMIES(1).date=[1970,3];
    build_dummies(Cfg_g, D_g.dates);
    fprintf('  [FALLO] No se lanzo error\n');
catch ME
    if contains(ME.identifier,'unknownType') || contains(ME.message,'no reconocido')
        fprintf('  [PASA] Error correcto: %s\n', ME.message);
    else
        fprintf('  [FALLO] Error inesperado: %s\n', ME.message);
    end
end
fprintf('\n');

%% TEST (h) — Error fecha fuera de rango ---------------------------------
fprintf('--- TEST (h): Error fecha fuera de rango ---\n');
try
    D_h = load_data(make_cfg());
    Cfg_h = make_cfg();
    Cfg_h.DUMMIES(1).name='fut'; Cfg_h.DUMMIES(1).type='oneoff';
    Cfg_h.DUMMIES(1).date=[2030,3];
    build_dummies(Cfg_h, D_h.dates);
    fprintf('  [FALLO] No se lanzo error\n');
catch ME
    if contains(ME.identifier,'dateNotFound') || contains(ME.message,'no encontrado')
        fprintf('  [PASA] Error correcto: %s\n', ME.message);
    else
        fprintf('  [FALLO] Error inesperado: %s\n', ME.message);
    end
end
fprintf('\n');

%% TEST (i) — Error dates no datetime ------------------------------------
fprintf('--- TEST (i): Error si dates no es datetime ---\n');
try
    Cfg_i = make_cfg();
    Cfg_i.DUMMIES(1).name='d'; Cfg_i.DUMMIES(1).type='oneoff';
    Cfg_i.DUMMIES(1).date=[1970,3];
    build_dummies(Cfg_i, {'31/03/1955';'30/06/1955'});
    fprintf('  [FALLO] No se lanzo error\n');
catch ME
    if contains(ME.identifier,'datesNotDatetime') || contains(ME.message,'datetime')
        fprintf('  [PASA] Error correcto: %s\n', ME.message);
    else
        fprintf('  [FALLO] Error inesperado: %s\n', ME.message);
    end
end
fprintf('\n');

%% ========================================================================
%% SECCION B — Regresion numerica exacta (nd completo)
%% ========================================================================
fprintf('════════════════════════════════════════════════════════════════\n');
fprintf(' SECCION B — Regresion numerica exacta (nd completo, lento)\n');
fprintf('════════════════════════════════════════════════════════════════\n\n');

TOL_NUM = 1e-8;

%% TEST (B1) — PFA sin dummies, rng(0) -----------------------------------
fprintf('--- TEST (B1): PFA sin dummies, prior diffuse, rng(0) ---\n');
fprintf('    (nd=10000, ~15 seg)\n');
REF_PFA_L1   = 0.0000000000;
REF_PFA_Lend = -0.2326865051;
REF_PFA_med2 = 5.4910402086;
REF_PFA_FEVD = 0.7305634882;
try
    Cfg_b1 = make_cfg();
    Cfg_b1.ND = 1e4;
    D_b1  = load_data(Cfg_b1);
    PP_b1 = build_posterior(D_b1, Cfg_b1);
    rng(0);
    R_b1  = run_pfa(PP_b1, Cfg_b1);
    L = R_b1.LtildeStruct.data;
    v1 = abs(L(1,1,1)             - REF_PFA_L1)   < TOL_NUM;
    v2 = abs(L(end,end,end)       - REF_PFA_Lend)  < TOL_NUM;
    v3 = abs(median(L(:,2,:),'all') - REF_PFA_med2) < TOL_NUM;
    v4 = abs(median(R_b1.FEVD(2,:)) - REF_PFA_FEVD) < TOL_NUM;
    if v1&&v2&&v3&&v4
        fprintf('  [PASA] Ltilde(1,1,1)=%.10f\n', L(1,1,1));
        fprintf('         Ltilde(end,end,end)=%.10f\n', L(end,end,end));
        fprintf('         median(L(:,2,:))=%.10f\n', median(L(:,2,:),'all'));
        fprintf('         median(FEVD(2,:))=%.10f\n', median(R_b1.FEVD(2,:)));
    else
        fprintf('  [FALLO]\n');
        fprintf('         Ltilde(1,1,1)=%.10f (ref=%.10f) dif=%.2e\n', ...
            L(1,1,1), REF_PFA_L1, abs(L(1,1,1)-REF_PFA_L1));
        fprintf('         Ltilde(end)  =%.10f (ref=%.10f) dif=%.2e\n', ...
            L(end,end,end), REF_PFA_Lend, abs(L(end,end,end)-REF_PFA_Lend));
        fprintf('         med(L(:,2,:))=%.10f (ref=%.10f) dif=%.2e\n', ...
            median(L(:,2,:),'all'), REF_PFA_med2, abs(median(L(:,2,:),'all')-REF_PFA_med2));
        fprintf('         med(FEVD(2)) =%.10f (ref=%.10f) dif=%.2e\n', ...
            median(R_b1.FEVD(2,:)), REF_PFA_FEVD, abs(median(R_b1.FEVD(2,:))-REF_PFA_FEVD));
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (B2) — IS sin dummies, rng(0) ------------------------------------
fprintf('--- TEST (B2): IS sin dummies, prior diffuse, rng(0) ---\n');
fprintf('    (nd=30000, ~15 min)\n');
REF_IS_L1   = 0.0000000000;
REF_IS_Lend = 0.2041864191;
REF_IS_med2 = 2.9521795528;
REF_IS_FEVD = 0.2580366201;
REF_IS_ne   = 11674;
try
    Cfg_b2 = make_cfg();
    Cfg_b2.MODE         = 'is';
    Cfg_b2.ND           = 3e4;
    Cfg_b2.MAX_IS_DRAWS = 1e4;
    Cfg_b2.CONJUGATE    = 'structural';
    D_b2  = load_data(Cfg_b2);
    PP_b2 = build_posterior(D_b2, Cfg_b2);
    rng(0);
    R_b2  = run_is(PP_b2, Cfg_b2);
    L = R_b2.LtildeStruct.data;
    v1 = abs(L(1,1,1,1)               - REF_IS_L1)   < TOL_NUM;
    v2 = abs(L(end,end,end,end)        - REF_IS_Lend)  < TOL_NUM;
    v3 = abs(median(L(:,2,1,:),'all')  - REF_IS_med2)  < TOL_NUM;
    v4 = abs(median(R_b2.FEVD(2,:))    - REF_IS_FEVD)  < TOL_NUM;
    v5 = R_b2.ne == REF_IS_ne;
    if v1&&v2&&v3&&v4&&v5
        fprintf('  [PASA] Ltilde(1,1,1,1)=%.10f\n', L(1,1,1,1));
        fprintf('         Ltilde(end)    =%.10f\n', L(end,end,end,end));
        fprintf('         med(L(:,2,1,:))=%.10f\n', median(L(:,2,1,:),'all'));
        fprintf('         med(FEVD(2,:)) =%.10f\n', median(R_b2.FEVD(2,:)));
        fprintf('         ne             =%d\n', R_b2.ne);
    else
        fprintf('  [FALLO]\n');
        if ~v1, fprintf('         L(1,1,1,1)   =%.10f (ref=%.10f)\n',L(1,1,1,1),REF_IS_L1); end
        if ~v2, fprintf('         L(end)       =%.10f (ref=%.10f)\n',L(end,end,end,end),REF_IS_Lend); end
        if ~v3, fprintf('         med(L(:,2,1))=%.10f (ref=%.10f)\n',median(L(:,2,1,:),'all'),REF_IS_med2); end
        if ~v4, fprintf('         med(FEVD(2)) =%.10f (ref=%.10f)\n',median(R_b2.FEVD(2,:)),REF_IS_FEVD); end
        if ~v5, fprintf('         ne=%d (ref=%d)\n',R_b2.ne,REF_IS_ne); end
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% ========================================================================
%% SECCION C — Integracion end-to-end (nd=500, rapido)
%% ========================================================================
fprintf('════════════════════════════════════════════════════════════════\n');
fprintf(' SECCION C — Integracion end-to-end (nd=500)\n');
fprintf('════════════════════════════════════════════════════════════════\n\n');

ND_FAST = 500;

function Cfg = make_cfg_fast(mode, nd)
    Cfg = make_cfg();
    Cfg.MODE = mode;
    Cfg.ND   = nd;
    if strcmp(mode,'is')
        Cfg.MAX_IS_DRAWS = nd;
        Cfg.CONJUGATE    = 'structural';
    end
    Cfg.ITER_SHOW = nd + 1;   % silenciar progress
end

%% TEST (C1) — PFA + dummy oneoff ----------------------------------------
fprintf('--- TEST (C1): PFA + dummy oneoff (nd=%d) ---\n', ND_FAST);
try
    Cfg_c1 = make_cfg_fast('pfa', ND_FAST);
    Cfg_c1.DUMMIES(1).name='covid_q1'; Cfg_c1.DUMMIES(1).type='oneoff';
    Cfg_c1.DUMMIES(1).date=[1970,3];
    D_c1  = load_data(Cfg_c1);
    PP_c1 = build_posterior(D_c1, Cfg_c1);
    rng(0);
    R_c1  = run_pfa(PP_c1, Cfg_c1);
    L = R_c1.LtildeStruct.data;
    ok_m    = PP_c1.m == 22 && PP_c1.ndummies == 1;
    ok_size = isequal(size(L), [41, 5, ND_FAST]);
    ok_z    = L(1,1,1) == 0;   % restriccion de cero en h=0
    if ok_m && ok_size && ok_z
        fprintf('  [PASA] m=22, ndummies=1, size(Ltilde)=[41,5,%d], L(1,1,1)=0\n', ND_FAST);
    else
        fprintf('  [FALLO] m=%d, size(L)=[%s], L(1,1,1)=%.4f\n', ...
            PP_c1.m, num2str(size(L)), L(1,1,1));
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (C2) — IS + dummy oneoff -----------------------------------------
fprintf('--- TEST (C2): IS + dummy oneoff (nd=%d) ---\n', ND_FAST);
try
    Cfg_c2 = make_cfg_fast('is', ND_FAST);
    Cfg_c2.DUMMIES(1).name='gfc'; Cfg_c2.DUMMIES(1).type='oneoff';
    Cfg_c2.DUMMIES(1).date=[2009,3];
    D_c2  = load_data(Cfg_c2);
    PP_c2 = build_posterior(D_c2, Cfg_c2);
    rng(0);
    R_c2  = run_is(PP_c2, Cfg_c2);
    ok_m    = PP_c2.m == 22 && PP_c2.ndummies == 1;
    ok_ne   = R_c2.ne > 0;
    ok_w    = abs(sum(R_c2.imp_w) - 1) < 1e-10;
    L = R_c2.LtildeStruct.data;
    ok_size = size(L,1)==41 && size(L,2)==5 && size(L,3)==5 && size(L,4)>0;
    if ok_m && ok_ne && ok_w && ok_size
        fprintf('  [PASA] m=22, ndummies=1, ne=%d, sum(imp_w)=1, size(Ltilde)=[41,5,5,%d]\n', ...
            R_c2.ne, size(L,4));
    else
        fprintf('  [FALLO] m=%d, ne=%d, sum(w)=%.6f\n', PP_c2.m, R_c2.ne, sum(R_c2.imp_w));
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (C3) — PFA + prior minnesota, sin dummies ------------------------
fprintf('--- TEST (C3): PFA + prior minnesota, sin dummies (nd=%d) ---\n', ND_FAST);
try
    Cfg_c3 = make_cfg_fast('pfa', ND_FAST);
    Cfg_c3.PRIOR.type    = 'minnesota';
    Cfg_c3.PRIOR.lambda1 = 0.2;
    Cfg_c3.PRIOR.lambda2 = 0.5;
    Cfg_c3.PRIOR.lambda3 = 1.0;
    D_c3  = load_data(Cfg_c3);
    PP_c3 = build_posterior(D_c3, Cfg_c3);
    rng(0);
    R_c3  = run_pfa(PP_c3, Cfg_c3);
    L = R_c3.LtildeStruct.data;
    ok = PP_c3.m==21 && PP_c3.ndummies==0 && ...
         isequal(size(L),[41,5,ND_FAST]) && ...
         strcmp(PP_c3.prior_type,'minnesota');
    if ok
        fprintf('  [PASA] m=21, ndummies=0, prior=minnesota, size(Ltilde)=[41,5,%d]\n', ND_FAST);
    else
        fprintf('  [FALLO] m=%d, prior=%s\n', PP_c3.m, PP_c3.prior_type);
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (C4) — PFA + prior minnesota + dos dummies -----------------------
fprintf('--- TEST (C4): PFA + prior minnesota + 2 dummies (nd=%d) ---\n', ND_FAST);
try
    Cfg_c4 = make_cfg_fast('pfa', ND_FAST);
    Cfg_c4.PRIOR.type    = 'minnesota';
    Cfg_c4.PRIOR.lambda1 = 0.2;
    Cfg_c4.PRIOR.lambda2 = 0.5;
    Cfg_c4.PRIOR.lambda3 = 1.0;
    Cfg_c4.DUMMIES(1).name='d1'; Cfg_c4.DUMMIES(1).type='oneoff';
    Cfg_c4.DUMMIES(1).date=[1970,3];
    Cfg_c4.DUMMIES(2).name='d2'; Cfg_c4.DUMMIES(2).type='step';
    Cfg_c4.DUMMIES(2).date=[2000,3];
    D_c4  = load_data(Cfg_c4);
    PP_c4 = build_posterior(D_c4, Cfg_c4);
    rng(0);
    R_c4  = run_pfa(PP_c4, Cfg_c4);
    L = R_c4.LtildeStruct.data;
    ok = PP_c4.m==23 && PP_c4.ndummies==2 && ...
         isequal(size(L),[41,5,ND_FAST]) && ...
         strcmp(PP_c4.prior_type,'minnesota');
    if ok
        fprintf('  [PASA] m=23, ndummies=2, prior=minnesota, size(Ltilde)=[41,5,%d]\n', ND_FAST);
    else
        fprintf('  [FALLO] m=%d, ndummies=%d\n', PP_c4.m, PP_c4.ndummies);
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% TEST (C5) — IS + prior minnesota + dummy pulse ------------------------
fprintf('--- TEST (C5): IS + prior minnesota + dummy pulse (nd=%d) ---\n', ND_FAST);
try
    Cfg_c5 = make_cfg_fast('is', ND_FAST);
    Cfg_c5.PRIOR.type    = 'minnesota';
    Cfg_c5.PRIOR.lambda1 = 0.2;
    Cfg_c5.PRIOR.lambda2 = 0.5;
    Cfg_c5.PRIOR.lambda3 = 1.0;
    Cfg_c5.DUMMIES(1).name='blk'; Cfg_c5.DUMMIES(1).type='pulse';
    Cfg_c5.DUMMIES(1).date_start=[1970,3];
    Cfg_c5.DUMMIES(1).date_end=[1971,12];
    D_c5  = load_data(Cfg_c5);
    PP_c5 = build_posterior(D_c5, Cfg_c5);
    rng(0);
    R_c5  = run_is(PP_c5, Cfg_c5);
    L = R_c5.LtildeStruct.data;
    ok = PP_c5.m==22 && PP_c5.ndummies==1 && ...
         R_c5.ne > 0 && abs(sum(R_c5.imp_w)-1)<1e-10 && ...
         size(L,4)>0 && strcmp(PP_c5.prior_type,'minnesota');
    if ok
        fprintf('  [PASA] m=22, ndummies=1, prior=minnesota, ne=%d, sum(w)=1\n', R_c5.ne);
    else
        fprintf('  [FALLO] m=%d, ndummies=%d, ne=%d\n', PP_c5.m, PP_c5.ndummies, R_c5.ne);
    end
catch ME; fprintf('  [ERROR] %s\n', ME.message); end
fprintf('\n');

%% ========================================================================
%% Resumen
%% ========================================================================
fprintf('════════════════════════════════════════════════════════════════\n');
fprintf(' VALIDATE_LOTE6 completado.\n');
fprintf(' Seccion A (loader/dummies): tests a-i\n');
fprintf(' Seccion B (regresion numerica): B1=PFA exacto, B2=IS exacto\n');
fprintf(' Seccion C (integracion, nd=%d): C1-C5\n', ND_FAST);
fprintf(' Reportar PASA/FALLO al chat.\n');
fprintf('════════════════════════════════════════════════════════════════\n\n');
