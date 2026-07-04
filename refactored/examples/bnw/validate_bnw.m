%VALIDATE_BNW  Script de verificación — Chat 16: Loader extendido + examples/bnw.
%
%   Tipo R (modifica load_data.m — requiere regresión numérica exacta).
%
%   SECCIÓN A — Composición de specs (base + overrides), examples/bnw/
%     A1: spec_bnw_pfa.m compone Cfg completo (base + overrides PFA)
%     A2: spec_bnw_is.m compone Cfg completo (base + overrides IS)
%     A3: Campos compartidos (NLAG, HORIZON, SCALE_FACTOR, SEED, Z, S,
%         VAR_ROLES) son idénticos entre PFA e IS (vienen del mismo base)
%     A4: Cfg.OUTPUT_DIR de ambos apunta a examples/bnw/output (nunca a
%         refactored/output)
%
%   SECCIÓN B — Loader generalizado (load_data.m, Tipo R)
%     B1: hojas leídas por NOMBRE, aunque el orden físico esté invertido
%     B2: sin hoja "metadata" → var_labels default var1..varN, sin error
%     B3: columna "role" legado en "metadata" se ignora sin romper
%     B4: metadata parcial (subconjunto de variables) → error explícito
%     B5: Cfg.VAR_ROLES no definido → default todas 'endogenous'
%     B6: Cfg.VAR_ROLES definido con roles mixtos → Dataset refleja Cfg
%     B7: Cfg.VAR_ROLES con longitud incorrecta → error explícito
%     B8: falta hoja "data" → error explícito
%
%   SECCIÓN C — Regresión funcional: BNW legacy (refactored/config) intacto
%     C1: load_data sobre refactored/data/data_bnw.xlsx → nvar=5, labels
%         y roles iguales a antes de este chat
%     C2: refactored/config/spec_bnw_pfa.m y spec_bnw_is.m (con VAR_ROLES
%         explícito, Parte 2) cargan sin error
%
%   SECCIÓN D — Regresión numérica exacta (Chat 7 baseline, rng(0), nd completo)
%     D1: PFA (refactored/config/spec_bnw_pfa, nd=1e4) →
%         Ltilde(end,end,end) == -0.2326865051
%     D2: IS  (refactored/config/spec_bnw_is,  nd=3e4) →
%         Ltilde(end,end,end,end) == 0.2041864191
%     NOTA: esta sección corre con nd completo (no nd=500) y puede tardar
%     varios minutos, igual que validate_mvp.m.
%
%   SECCIÓN E — Proyecto examples/bnw/ (requiere data_bnw.xlsx copiado a
%   examples/bnw/data/; si no está presente, E2–E5 reportan FALLA con
%   instrucciones claras, sin abortar el resto del script)
%     E1: archivo de datos presente en examples/bnw/data/data_bnw.xlsx
%     E2: labels vienen de Excel (metadata), roles vienen de Cfg.VAR_ROLES
%         (verificación explícita de Dataset.var_labels y Dataset.var_roles)
%     E3: PFA en examples/bnw (nd=1e4, rng(0)) reproduce
%         Ltilde(end,end,end) == -0.2326865051
%     E4: IS en examples/bnw (nd=3e4, rng(0)) reproduce
%         Ltilde(end,end,end,end) == 0.2041864191
%     E5: plot_irfs/export_results escriben en examples/bnw/output/, y NO
%         se crea/actualiza nada en refactored/output/
%
%   Uso: ejecutar desde MATLAB (cualquier working directory).

fprintf('\n');
fprintf('================================================================\n');
fprintf(' VALIDATE_BNW — Chat 16: Loader extendido + examples/bnw\n');
fprintf('================================================================\n\n');

%% ── Rutas ────────────────────────────────────────────────────────────────
% validate_bnw.m vive en: refactored/examples/bnw/
val_root = fileparts(mfilename('fullpath'));      % .../examples/bnw/
ref_root = fileparts(fileparts(val_root));         % .../refactored/
ex_cfg   = fullfile(val_root, 'config');
ex_data  = fullfile(val_root, 'data', 'data_bnw.xlsx');
legacy_cfg  = fullfile(ref_root, 'config');
legacy_data = fullfile(ref_root, 'data', 'data_bnw.xlsx');

addpath(fullfile(ref_root, 'src'));
addpath(legacy_cfg);
addpath(fullfile(ref_root, 'helpfunctions'));
addpath(fullfile(ref_root, 'validate'));
addpath(ex_cfg);

%% ── Checker de rutas prohibidas (aplica a src/ y examples/bnw/) ─────────
DOTDOT  = '\.\.[/\\]';
ruta_ok = true;
check_dirs = {fullfile(ref_root, 'src'), val_root};
for di = 1:numel(check_dirs)
    files_i = dir(fullfile(check_dirs{di}, '*.m'));
    for fi = 1:numel(files_i)
        fid  = fopen(fullfile(files_i(fi).folder, files_i(fi).name), 'r');
        lnum = 0;
        while ~feof(fid)
            ln = fgetl(fid); lnum = lnum + 1;
            if ~ischar(ln), continue; end
            lt = strtrim(ln);
            if startsWith(lt, '%'), continue; end
            lc = regexprep(lt, '\.\.\..*', '');
            if ~isempty(regexp(lc, DOTDOT, 'once'))
                fprintf('  [RUTA PROHIBIDA] %s L%d\n', files_i(fi).name, lnum);
                ruta_ok = false;
            end
        end
        fclose(fid);
    end
end
if ruta_ok, fprintf('[OK] Checker de rutas: sin rutas relativas prohibidas\n\n'); end

%% ── Contadores ──────────────────────────────────────────────────────────
n_pass = 0;
n_fail = 0;

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN A — Composición de specs (base + overrides), examples/bnw/
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN A — Composición de specs (examples/bnw)\n');
fprintf('-------------------------------------------------\n');

mandatory_base = {'MODE','ND','SEED','NLAG','NEX','HORIZON','INDEX_FEVD', ...
    'SCALE_FACTOR','DATA_FILE','VAR_ROLES','OUTPUT_DIR','S','Z'};

Cfg_pfa = struct(); pfa_ok = false;
try
    clear Cfg;
    run(fullfile(ex_cfg, 'spec_bnw_pfa.m'));
    Cfg_pfa = Cfg; clear Cfg;
    pfa_ok  = true;
    missing = {};
    for k = 1:numel(mandatory_base)
        if ~isfield(Cfg_pfa, mandatory_base{k}), missing{end+1} = mandatory_base{k}; end %#ok<AGROW>
    end
    ok = isempty(missing) && strcmp(Cfg_pfa.MODE,'pfa') && Cfg_pfa.ND == 1e4 ...
        && strcmp(Cfg_pfa.CONJUGATE,'irfs') && strcmp(Cfg_pfa.SPEC_NAME,'spec_bnw_pfa');
    detail = '';
    if ~ok, detail = ['Campos/valores no esperados. Faltantes: ' strjoin(missing,', ')]; end
catch ME_a1
    ok = false; detail = ME_a1.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'A1: spec_bnw_pfa compone Cfg completo (base+overrides)', ok, detail);

Cfg_is = struct(); is_ok = false;
try
    clear Cfg;
    run(fullfile(ex_cfg, 'spec_bnw_is.m'));
    Cfg_is = Cfg; clear Cfg;
    is_ok   = true;
    missing = {};
    for k = 1:numel(mandatory_base)
        if ~isfield(Cfg_is, mandatory_base{k}), missing{end+1} = mandatory_base{k}; end %#ok<AGROW>
    end
    ok = isempty(missing) && strcmp(Cfg_is.MODE,'is') && Cfg_is.ND == 3e4 ...
        && strcmp(Cfg_is.CONJUGATE,'structural') && strcmp(Cfg_is.SPEC_NAME,'spec_bnw_is');
    detail = '';
    if ~ok, detail = ['Campos/valores no esperados. Faltantes: ' strjoin(missing,', ')]; end
catch ME_a2
    ok = false; detail = ME_a2.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'A2: spec_bnw_is compone Cfg completo (base+overrides)', ok, detail);

if pfa_ok && is_ok
    shared_fields = {'NLAG','HORIZON','SCALE_FACTOR','SEED','VAR_ROLES'};
    same = true;
    for k = 1:numel(shared_fields)
        f = shared_fields{k};
        if ~isequal(Cfg_pfa.(f), Cfg_is.(f)), same = false; end
    end
    same = same && isequal(Cfg_pfa.Z, Cfg_is.Z) && isequal(Cfg_pfa.S, Cfg_is.S);
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'A3: campos compartidos identicos entre PFA e IS (vienen del base)', same, '');
else
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'A3: campos compartidos identicos entre PFA e IS (vienen del base)', false, 'A1/A2 fallaron');
end

if pfa_ok && is_ok
    exp_out = fullfile(val_root, 'output');
    ok = strcmp(Cfg_pfa.OUTPUT_DIR, exp_out) && strcmp(Cfg_is.OUTPUT_DIR, exp_out);
    detail = sprintf('PFA=%s | IS=%s | esperado=%s', Cfg_pfa.OUTPUT_DIR, Cfg_is.OUTPUT_DIR, exp_out);
else
    ok = false; detail = 'A1/A2 fallaron';
end
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'A4: Cfg.OUTPUT_DIR apunta a examples/bnw/output (no a refactored/output)', ok, detail);

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN B — Loader generalizado (load_data.m, Tipo R)
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN B — Loader generalizado (load_data.m)\n');
fprintf('-------------------------------------------------\n');

tmp_dir = fullfile(tempdir, 'validate_bnw_tmp');
if ~isfolder(tmp_dir), mkdir(tmp_dir); end
cleanupObj = onCleanup(@() rmdir(tmp_dir, 's')); %#ok<NASGU>

dates3 = datetime(2000,1,1) + calmonths(0:2)';
Y3     = [1.0 2.0; 1.1 2.1; 1.2 2.2];

% B1: hojas por NOMBRE, orden fisico invertido (metadata antes que data)
p_b1 = fullfile(tmp_dir, 'b1_reversed_order.xlsx');
try
    Tmeta = table({'x';'y'}, {'X label';'Y label'}, 'VariableNames', {'var_name','label'});
    writetable(Tmeta, p_b1, 'Sheet', 'metadata');   % se crea PRIMERO -> sheet fisica 1
    Tdata = table(dates3, Y3(:,1), Y3(:,2), 'VariableNames', {'date','x','y'});
    writetable(Tdata, p_b1, 'Sheet', 'data');        % se crea SEGUNDO -> sheet fisica 2
    Cfg_b1 = struct('DATA_FILE', p_b1);
    DS_b1  = load_data(Cfg_b1);
    ok = isequal(DS_b1.var_names, {'x','y'}) && isequal(DS_b1.var_labels, {'X label','Y label'});
    detail = sprintf('var_names=%s | var_labels=%s', strjoin(DS_b1.var_names,','), strjoin(DS_b1.var_labels,','));
catch ME_b1
    ok = false; detail = ME_b1.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'B1: hojas leidas por NOMBRE (orden fisico invertido)', ok, detail);

% B2: sin hoja "metadata" -> defaults var1..varN, sin error
p_b2 = fullfile(tmp_dir, 'b2_no_metadata.xlsx');
try
    Tdata = table(dates3, Y3(:,1), Y3(:,2), 'VariableNames', {'date','x','y'});
    writetable(Tdata, p_b2, 'Sheet', 'data');
    Cfg_b2 = struct('DATA_FILE', p_b2);
    DS_b2  = load_data(Cfg_b2);
    ok = isequal(DS_b2.var_labels, {'var1','var2'});
    detail = sprintf('var_labels=%s', strjoin(DS_b2.var_labels, ','));
catch ME_b2
    ok = false; detail = ME_b2.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'B2: sin hoja "metadata" -> defaults var1..varN', ok, detail);

% B3: columna "role" legado en metadata no rompe (se ignora)
p_b3 = fullfile(tmp_dir, 'b3_legacy_role.xlsx');
try
    Tdata = table(dates3, Y3(:,1), Y3(:,2), 'VariableNames', {'date','x','y'});
    writetable(Tdata, p_b3, 'Sheet', 'data');
    Tmeta = table({'x';'y'}, {'endogenous';'exogenous'}, {'X label';'Y label'}, ...
        'VariableNames', {'var_name','role','label'});
    writetable(Tmeta, p_b3, 'Sheet', 'metadata');
    Cfg_b3 = struct('DATA_FILE', p_b3);   % sin VAR_ROLES -> debe usar default, NO la columna role
    DS_b3  = load_data(Cfg_b3);
    ok = isequal(DS_b3.var_labels, {'X label','Y label'}) && ...
         isequal(DS_b3.var_roles, {'endogenous','endogenous'});   % default, ignora 'role' de Excel
    detail = sprintf('var_roles=%s (debe ser default, no la columna role del Excel)', strjoin(DS_b3.var_roles,','));
catch ME_b3
    ok = false; detail = ME_b3.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'B3: columna "role" legado en metadata se ignora', ok, detail);

% B4: metadata parcial (subconjunto) -> error explicito
p_b4 = fullfile(tmp_dir, 'b4_partial_metadata.xlsx');
try
    Tdata = table(dates3, Y3(:,1), Y3(:,2), 'VariableNames', {'date','x','y'});
    writetable(Tdata, p_b4, 'Sheet', 'data');
    Tmeta = table({'x'}, {'X label'}, 'VariableNames', {'var_name','label'});   % solo 'x', falta 'y'
    writetable(Tmeta, p_b4, 'Sheet', 'metadata');
    Cfg_b4 = struct('DATA_FILE', p_b4);
    threw = false;
    try
        load_data(Cfg_b4);
    catch ME_inner
        threw = strcmp(ME_inner.identifier, 'load_data:partialMetadata');
    end
    ok = threw;
    detail = 'error load_data:partialMetadata esperado';
catch ME_b4
    ok = false; detail = ME_b4.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'B4: metadata parcial -> error explicito (todo o nada)', ok, detail);

% B5: Cfg.VAR_ROLES no definido -> default todas 'endogenous'
p_b5 = fullfile(tmp_dir, 'b5_default_roles.xlsx');
try
    Tdata = table(dates3, Y3(:,1), Y3(:,2), 'VariableNames', {'date','x','y'});
    writetable(Tdata, p_b5, 'Sheet', 'data');
    Cfg_b5 = struct('DATA_FILE', p_b5);   % sin VAR_ROLES
    DS_b5  = load_data(Cfg_b5);
    ok = isequal(DS_b5.var_roles, {'endogenous','endogenous'}) && DS_b5.nvar == 2;
    detail = sprintf('var_roles=%s, nvar=%d', strjoin(DS_b5.var_roles,','), DS_b5.nvar);
catch ME_b5
    ok = false; detail = ME_b5.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'B5: Cfg.VAR_ROLES no definido -> default todas endogenous', ok, detail);

% B6: Cfg.VAR_ROLES definido con roles mixtos -> Dataset refleja Cfg
p_b6 = p_b5;   % reutiliza el mismo archivo de datos
try
    Cfg_b6 = struct('DATA_FILE', p_b6, 'VAR_ROLES', {{'endogenous','exogenous'}});
    DS_b6  = load_data(Cfg_b6);
    ok = isequal(DS_b6.var_roles, {'endogenous','exogenous'}) && DS_b6.nvar == 1;
    detail = sprintf('var_roles=%s, nvar=%d', strjoin(DS_b6.var_roles,','), DS_b6.nvar);
catch ME_b6
    ok = false; detail = ME_b6.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'B6: Cfg.VAR_ROLES mixto -> Dataset.var_roles/nvar reflejan Cfg', ok, detail);

% B7: Cfg.VAR_ROLES con longitud incorrecta -> error explicito
try
    Cfg_b7 = struct('DATA_FILE', p_b5, 'VAR_ROLES', {{'endogenous','exogenous','endogenous'}});
    threw = false;
    try
        load_data(Cfg_b7);
    catch ME_inner7
        threw = strcmp(ME_inner7.identifier, 'load_data:varRolesDim');
    end
    ok = threw;
    detail = 'error load_data:varRolesDim esperado';
catch ME_b7
    ok = false; detail = ME_b7.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'B7: Cfg.VAR_ROLES longitud incorrecta -> error explicito', ok, detail);

% B8: falta hoja "data" -> error explicito
p_b8 = fullfile(tmp_dir, 'b8_no_data_sheet.xlsx');
try
    Tother = table({'x'}, 'VariableNames', {'foo'});
    writetable(Tother, p_b8, 'Sheet', 'otra_hoja');
    Cfg_b8 = struct('DATA_FILE', p_b8);
    threw = false;
    try
        load_data(Cfg_b8);
    catch ME_inner8
        threw = strcmp(ME_inner8.identifier, 'load_data:sheetDataMissing');
    end
    ok = threw;
    detail = 'error load_data:sheetDataMissing esperado';
catch ME_b8
    ok = false; detail = ME_b8.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'B8: falta hoja "data" -> error explicito', ok, detail);

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN C — Regresión funcional: BNW legacy (refactored/config) intacto
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN C — BNW legacy (refactored/config) sigue intacto\n');
fprintf('-----------------------------------------------------------\n');

try
    Cfg_c1 = struct('DATA_FILE', legacy_data);
    DS_c1  = load_data(Cfg_c1);
    ok = (DS_c1.nvar == 5) && (DS_c1.nvar_total == 5) && ...
         isequal(DS_c1.var_roles, repmat({'endogenous'},1,5));
    detail = sprintf('nvar=%d, nvar_total=%d', DS_c1.nvar, DS_c1.nvar_total);
catch ME_c1
    ok = false; detail = ME_c1.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'C1: load_data(refactored/data/data_bnw.xlsx) -> nvar=5, roles OK', ok, detail);

Cfg_legacy_pfa = struct(); Cfg_legacy_is = struct();
try
    clear Cfg;
    run(fullfile(legacy_cfg, 'spec_bnw_pfa.m'));
    Cfg_legacy_pfa = Cfg; clear Cfg;
    run(fullfile(legacy_cfg, 'spec_bnw_is.m'));
    Cfg_legacy_is = Cfg; clear Cfg;
    ok = isfield(Cfg_legacy_pfa,'VAR_ROLES') && isfield(Cfg_legacy_is,'VAR_ROLES');
    detail = '';
catch ME_c2
    ok = false; detail = ME_c2.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'C2: refactored/config/spec_bnw_pfa.m y spec_bnw_is.m cargan con VAR_ROLES explicito', ok, detail);

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN D — Regresión numérica exacta (Chat 7 baseline, nd completo)
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN D — Regresión numérica exacta (refactored/config, nd completo)\n');
fprintf('  Nota: nd=1e4 (PFA) y nd=3e4 (IS). Puede tardar varios minutos.\n');
fprintf('--------------------------------------------------------------------\n');

REF_PFA = -0.2326865051;
REF_IS  =  0.2041864191;

try
    Cfg_d_pfa = Cfg_legacy_pfa;
    Dataset_d_pfa = load_data(Cfg_d_pfa);
    Post_d_pfa    = build_posterior(Dataset_d_pfa, Cfg_d_pfa);
    rng(Cfg_d_pfa.SEED);
    Results_d_pfa = run_pfa(Post_d_pfa, Cfg_d_pfa);
    v_d1 = Results_d_pfa.LtildeStruct.data(end,end,end);
    ok = abs(v_d1 - REF_PFA) < 1e-8;
    detail = sprintf('valor=%.10f, esperado=%.10f', v_d1, REF_PFA);
catch ME_d1
    ok = false; detail = ME_d1.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'D1: PFA Ltilde(end,end,end) == -0.2326865051 (rng(0))', ok, detail);

try
    Cfg_d_is = Cfg_legacy_is;
    Dataset_d_is = load_data(Cfg_d_is);
    Post_d_is    = build_posterior(Dataset_d_is, Cfg_d_is);
    rng(Cfg_d_is.SEED);
    Results_d_is = run_is(Post_d_is, Cfg_d_is);
    v_d2 = Results_d_is.LtildeStruct.data(end,end,end,end);
    ok = abs(v_d2 - REF_IS) < 1e-8;
    detail = sprintf('valor=%.10f, esperado=%.10f', v_d2, REF_IS);
catch ME_d2
    ok = false; detail = ME_d2.message;
end
[n_pass, n_fail] = rpt(n_pass, n_fail, 'D2: IS Ltilde(end,end,end,end) == 0.2041864191 (rng(0))', ok, detail);

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN E — Proyecto examples/bnw/
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN E — Proyecto examples/bnw/\n');
fprintf('-------------------------------------\n');

n_fail_before_E = n_fail;   % para distinguir fallas de A-D de las de E (archivo faltante)
data_present = isfile(ex_data);
[n_pass, n_fail] = rpt(n_pass, n_fail, 'E1: data_bnw.xlsx presente en examples/bnw/data/', data_present, ...
    iif(data_present, '', sprintf('Copiar el archivo a: %s', ex_data)));

if data_present && pfa_ok && is_ok
    try
        DS_e = load_data(Cfg_pfa);
        endo_mask_e = strcmp(DS_e.var_roles, 'endogenous');
        ok = isequal(DS_e.var_labels, {'Adjusted TFP','Stock Prices','Consumption','Real Interest Rate','Hours Worked'}) ...
             && all(endo_mask_e);   % roles: los 5 vienen de Cfg.VAR_ROLES (todas endogenous)
        detail = sprintf('var_labels=%s | var_roles=%s', ...
            strjoin(DS_e.var_labels, ' | '), strjoin(DS_e.var_roles, ','));
    catch ME_e2
        ok = false; detail = ME_e2.message;
    end
else
    ok = false; detail = 'requiere E1 y Sección A OK';
end
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'E2: labels vienen de Excel (metadata), roles vienen de Cfg.VAR_ROLES', ok, detail);

Results_e_pfa = []; Results_e_is = [];
if data_present && pfa_ok
    try
        Cfg_e_pfa = Cfg_pfa;
        Cfg_e_pfa.PLOT_IRFS = false;
        Dataset_e_pfa = load_data(Cfg_e_pfa);
        Post_e_pfa    = build_posterior(Dataset_e_pfa, Cfg_e_pfa);
        rng(Cfg_e_pfa.SEED);
        Results_e_pfa = run_pfa(Post_e_pfa, Cfg_e_pfa);
        v_e3 = Results_e_pfa.LtildeStruct.data(end,end,end);
        ok = abs(v_e3 - REF_PFA) < 1e-8;
        detail = sprintf('valor=%.10f, esperado=%.10f', v_e3, REF_PFA);
    catch ME_e3
        ok = false; detail = ME_e3.message;
    end
else
    ok = false; detail = 'requiere E1';
end
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'E3: PFA examples/bnw (nd=1e4, rng(0)) reproduce Ltilde(end,end,end)', ok, detail);

if data_present && is_ok
    try
        Cfg_e_is = Cfg_is;
        Cfg_e_is.PLOT_IRFS = false;
        Dataset_e_is = load_data(Cfg_e_is);
        Post_e_is    = build_posterior(Dataset_e_is, Cfg_e_is);
        rng(Cfg_e_is.SEED);
        Results_e_is = run_is(Post_e_is, Cfg_e_is);
        v_e4 = Results_e_is.LtildeStruct.data(end,end,end,end);
        ok = abs(v_e4 - REF_IS) < 1e-8;
        detail = sprintf('valor=%.10f, esperado=%.10f', v_e4, REF_IS);
    catch ME_e4
        ok = false; detail = ME_e4.message;
    end
else
    ok = false; detail = 'requiere E1';
end
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'E4: IS examples/bnw (nd=3e4, rng(0)) reproduce Ltilde(end,end,end,end)', ok, detail);

if data_present && ~isempty(Results_e_pfa) && ~isempty(Results_e_is)
    try
        legacy_fig_dir = fullfile(ref_root, 'output', 'figures');
        legacy_tab_dir = fullfile(ref_root, 'output', 'tables');
        proj_fig_dir   = fullfile(val_root, 'output', 'figures');
        proj_tab_dir   = fullfile(val_root, 'output', 'tables');

        before_legacy = [list_files(legacy_fig_dir), list_files(legacy_tab_dir)];

        export_results(Results_e_pfa, Dataset_e_pfa, Cfg_e_pfa);
        Cfg_e_pfa_plot = Cfg_e_pfa; Cfg_e_pfa_plot.FIG_SUFFIX = '_validate_bnw';
        plot_irfs(Results_e_pfa.LtildeStruct, Dataset_e_pfa, Cfg_e_pfa_plot);

        after_legacy = [list_files(legacy_fig_dir), list_files(legacy_tab_dir)];

        new_in_proj_fig = isfile(fullfile(proj_fig_dir, ...
            ['irfs_', Results_e_pfa.LtildeStruct.mode, '_validate_bnw.png']));
        new_in_proj_tab = ~isempty(list_files(proj_tab_dir));
        no_new_in_legacy = isequal(sort(before_legacy), sort(after_legacy));

        ok = new_in_proj_fig && new_in_proj_tab && no_new_in_legacy;
        detail = sprintf('fig en proyecto=%d, tabla en proyecto=%d, sin cambios en refactored/output=%d', ...
            new_in_proj_fig, new_in_proj_tab, no_new_in_legacy);
    catch ME_e5
        ok = false; detail = ME_e5.message;
    end
else
    ok = false; detail = 'requiere E1, E3 y E4';
end
[n_pass, n_fail] = rpt(n_pass, n_fail, ...
    'E5: outputs en examples/bnw/output/, nada nuevo en refactored/output/', ok, detail);

fprintf('\n');

%% ── Resumen final ────────────────────────────────────────────────────────
fprintf('================================================================\n');
fprintf(' RESUMEN: %d PASA  |  %d FALLA\n', n_pass, n_fail);
if n_fail == 0
    fprintf(' VEREDICTO: PASA\n');
elseif ~data_present && n_fail_before_E == 0
    fprintf(' VEREDICTO: PASA CON ADVERTENCIA — Secciones A-D OK; Sección E pendiente\n');
    fprintf('            (falta copiar data_bnw.xlsx a examples/bnw/data/)\n');
else
    fprintf(' VEREDICTO: NO PASA — revisar las secciones con [FALLA]\n');
end
fprintf('================================================================\n\n');

%% ── Funciones auxiliares ──────────────────────────────────────────────────
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

function s = iif(cond, a, b)
    if cond, s = a; else, s = b; end
end

function names = list_files(d)
    if ~isfolder(d)
        names = {};
        return;
    end
    L = dir(fullfile(d, '*'));
    L = L(~[L.isdir]);
    names = {L.name};
end
