%VALIDATE_FASE1  Script de validacion para Fase 1 — Esqueleto y data loader.
%
%   Verifica:
%     (a) main.m existe y es localizable desde cualquier working directory
%     (b) load_data.m lee data_bnw.xlsx y retorna Dataset con campos correctos
%     (c) Dataset.nvar == 5, Dataset.nvar_total == 5
%     (d) Las rutas internas NO contienen '..' ni dependen de pwd
%
%   EJECUTAR desde CUALQUIER directorio:
%       run('/ruta/absoluta/refactored/validate/validate_fase1.m')
%   O desde validate/:
%       validate_fase1
%
%   Salida: solo texto en consola. Ningun .mat ni figura se genera.

fprintf('\n');
fprintf('=================================================================\n');
fprintf('  VALIDATE FASE 1 - Esqueleto, rutas y data loader\n');
fprintf('=================================================================\n\n');

PASS = true;

%% -- Localizar proj_root de forma robusta ---------------------------------
% mfilename('fullpath') devuelve '' cuando el script se ejecuta via 'run'
% desde un directorio distinto en versiones antiguas de MATLAB.
% Solucion robusta: buscar el archivo validate_fase1.m en el path de MATLAB.
this_file = which('validate_fase1');
if isempty(this_file)
    % Fallback: asumir que estamos en validate/ o en proj_root
    candidate = fullfile(pwd, 'validate', 'validate_fase1.m');
    if isfile(candidate)
        this_file = candidate;
    else
        candidate2 = fullfile(pwd, 'validate_fase1.m');
        if isfile(candidate2)
            this_file = candidate2;
        else
            error(['No se puede localizar validate_fase1.m. ' ...
                   'Ejecuta desde refactored/ o desde refactored/validate/.']);
        end
    end
end

val_dir   = fileparts(this_file);   % .../refactored/validate/
proj_root = fileparts(val_dir);     % .../refactored/

% Añadir src/ y config/ al path
addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'config'));

fprintf('Raiz del proyecto detectada:\n  %s\n\n', proj_root);

%% -- CHECK A: main.m existe y no usa rutas prohibidas --------------------
fprintf('--- CHECK A: Existencia de main.m ---\n');
main_path = fullfile(proj_root, 'main.m');

if isfile(main_path)
    fprintf('  [OK] main.m encontrado en: %s\n', main_path);

    fid = fopen(main_path, 'r');
    raw = fread(fid, '*char')';
    fclose(fid);

    % Eliminar comentarios antes de buscar patrones prohibidos
    % Un comentario en MATLAB empieza con % hasta fin de linea
    code_only = regexprep(raw, '%[^\n]*', '');

    has_pwd    = ~isempty(regexp(code_only, '\bpwd\b',   'once'));
    has_cd     = ~isempty(regexp(code_only, '\bcd\s*\(', 'once'));
    has_dotdot = ~isempty(regexp(code_only, '\.\.',       'once'));

    if has_pwd
        fprintf('  [WARN] main.m contiene ''pwd'' en codigo (no en comentarios)\n');
        PASS = false;
    end
    if has_cd
        fprintf('  [WARN] main.m contiene ''cd('' en codigo (no en comentarios)\n');
        PASS = false;
    end
    if has_dotdot
        fprintf('  [WARN] main.m contiene ''..'' en codigo (no en comentarios)\n');
        PASS = false;
    end
    if ~has_pwd && ~has_cd && ~has_dotdot
        fprintf('  [OK] main.m no usa pwd, cd ni .. (en codigo ejecutable)\n');
    end
else
    fprintf('  [FAIL] main.m NO encontrado en: %s\n', main_path);
    PASS = false;
end
fprintf('\n');

%% -- CHECK B: load_data.m existe y no usa rutas prohibidas ---------------
fprintf('--- CHECK B: Existencia y rutas en load_data.m ---\n');
ld_path = fullfile(proj_root, 'src', 'load_data.m');

if isfile(ld_path)
    fprintf('  [OK] load_data.m encontrado en: %s\n', ld_path);

    fid = fopen(ld_path, 'r');
    raw = fread(fid, '*char')';
    fclose(fid);

    code_only = regexprep(raw, '%[^\n]*', '');

    has_pwd      = ~isempty(regexp(code_only, '\bpwd\b',    'once'));
    has_cd       = ~isempty(regexp(code_only, '\bcd\s*\(',  'once'));
    has_dotdot   = ~isempty(regexp(code_only, '\.\.',        'once'));
    has_mfile    = ~isempty(regexp(raw,       'mfilename',   'once'));

    if has_pwd
        fprintf('  [WARN] load_data.m contiene ''pwd'' en codigo\n');
        PASS = false;
    end
    if has_cd
        fprintf('  [WARN] load_data.m contiene ''cd('' en codigo\n');
        PASS = false;
    end
    if has_dotdot
        fprintf('  [WARN] load_data.m contiene ''..'' en codigo\n');
        PASS = false;
    end
    if ~has_pwd && ~has_cd && ~has_dotdot
        fprintf('  [OK] load_data.m no usa pwd, cd ni .. (en codigo ejecutable)\n');
    end
    if has_mfile
        fprintf('  [OK] load_data.m usa mfilename para calcular rutas\n');
    else
        fprintf('  [WARN] load_data.m no parece usar mfilename\n');
    end
else
    fprintf('  [FAIL] load_data.m NO encontrado en: %s\n', ld_path);
    PASS = false;
end
fprintf('\n');

%% -- CHECK C: data_bnw.xlsx existe ----------------------------------------
fprintf('--- CHECK C: Existencia de data_bnw.xlsx ---\n');
xlsx_path = fullfile(proj_root, 'data', 'data_bnw.xlsx');
if isfile(xlsx_path)
    fprintf('  [OK] data_bnw.xlsx encontrado en: %s\n', xlsx_path);
else
    fprintf('  [FAIL] data_bnw.xlsx NO encontrado en: %s\n', xlsx_path);
    PASS = false;
end
fprintf('\n');

%% -- CHECK D: Ejecutar load_data y verificar Dataset ---------------------
fprintf('--- CHECK D: Lectura de datos con load_data ---\n');

Cfg_test.DATA_FILE    = '';
Cfg_test.SCALE_FACTOR = 100;

try
    Dataset = load_data(Cfg_test);
    fprintf('  [OK] load_data ejecutado sin errores\n');

    required_fields = {'dates','Y_raw','var_names','var_labels','var_roles', ...
                       'nvar','nvar_total','source_file'};
    for k = 1:numel(required_fields)
        f = required_fields{k};
        if isfield(Dataset, f)
            fprintf('  [OK] Dataset.%s existe\n', f);
        else
            fprintf('  [FAIL] Dataset.%s NO existe\n', f);
            PASS = false;
        end
    end
catch ME
    fprintf('  [FAIL] load_data lanzo error: %s\n', ME.message);
    PASS = false;
    Dataset = struct();
end
fprintf('\n');

%% -- CHECK E: Dimensiones y valores numericos ----------------------------
fprintf('--- CHECK E: Dimensiones de Dataset ---\n');
if isfield(Dataset, 'nvar') && isfield(Dataset, 'nvar_total')

    fprintf('  Dataset.nvar        = %d\n', Dataset.nvar);
    fprintf('  Dataset.nvar_total  = %d\n', Dataset.nvar_total);

    if isfield(Dataset, 'Y_raw')
        [T_obs, ncols] = size(Dataset.Y_raw);
        fprintf('  Dataset.Y_raw size  = [%d x %d]\n', T_obs, ncols);
    end
    if isfield(Dataset, 'dates') && ~isempty(Dataset.dates)
        fprintf('  Dataset.dates(1)    = %s\n', Dataset.dates{1});
        fprintf('  Dataset.dates(end)  = %s\n', Dataset.dates{end});
    end

    if Dataset.nvar == 5
        fprintf('  [OK] nvar == 5  (5 variables endogenas)\n');
    else
        fprintf('  [FAIL] nvar == %d  (esperado: 5)\n', Dataset.nvar);
        PASS = false;
    end
    if Dataset.nvar_total == 5
        fprintf('  [OK] nvar_total == 5\n');
    else
        fprintf('  [FAIL] nvar_total == %d  (esperado: 5)\n', Dataset.nvar_total);
        PASS = false;
    end

    if isfield(Dataset, 'var_roles')
        n_endo = sum(strcmp(Dataset.var_roles, 'endogenous'));
        fprintf('  Variables endogenas : %d\n', n_endo);
        fprintf('  var_names           : %s\n', strjoin(Dataset.var_names, ', '));
        fprintf('  var_labels          : %s\n', strjoin(Dataset.var_labels, ', '));
    end

    if isfield(Dataset, 'Y_raw') && ~isempty(Dataset.Y_raw)
        fprintf('\n  Primer registro de Y_raw (crudo, sin x%d):\n', Cfg_test.SCALE_FACTOR);
        for j = 1:Dataset.nvar_total
            fprintf('    %s: %.8f\n', Dataset.var_names{j}, Dataset.Y_raw(1,j));
        end
    end
else
    fprintf('  [FAIL] Dataset no tiene campos nvar/nvar_total\n');
    PASS = false;
end
fprintf('\n');

%% -- CHECK F: spec_bnw_pfa.m existe --------------------------------------
fprintf('--- CHECK F: Existencia de spec_bnw_pfa.m ---\n');
spec_path = fullfile(proj_root, 'config', 'spec_bnw_pfa.m');
if isfile(spec_path)
    fprintf('  [OK] spec_bnw_pfa.m encontrado\n');
else
    fprintf('  [FAIL] spec_bnw_pfa.m NO encontrado en: %s\n', spec_path);
    PASS = false;
end
fprintf('\n');

%% -- RESUMEN FINAL --------------------------------------------------------
fprintf('=================================================================\n');
if PASS
    fprintf('  RESULTADO GLOBAL: ** PASA **\n');
else
    fprintf('  RESULTADO GLOBAL: ** NO PASA ** (ver detalles arriba)\n');
end
fprintf('=================================================================\n\n');
