function Dataset = load_data(Cfg)
%LOAD_DATA  Data loader canonico del SVAR Toolkit.
%
%   Dataset = LOAD_DATA(Cfg) lee data_bnw.xlsx (o el archivo especificado
%   en Cfg.DATA_FILE) y devuelve la struct Dataset.
%
%   El archivo xlsx debe tener DOS hojas:
%     Hoja 1: datos tabulares  — col 1 = fecha (texto), resto = variables
%     Hoja 2: metadata         — columnas: var_name | role | label
%
%   REGLA DE RUTAS: nunca se usa pwd, cd, ni '..'.
%   La ruta al proyecto se calcula con fileparts(mfilename('fullpath')).
%
%   Campos de Dataset devueltos:
%     .dates        [T x 1 cell]    etiquetas de fecha (strings del xlsx)
%     .Y_raw        [T x nvar_total double]   datos crudos SIN escalar
%     .var_names    {1 x nvar_total cell}     nombres cortos
%     .var_labels   {1 x nvar_total cell}     labels para graficos
%     .var_roles    {1 x nvar_total cell}     'endogenous' | 'exogenous'
%     .nvar         scalar          numero de variables endogenas
%     .nvar_total   scalar          total columnas Hoja 1 (sin fecha)
%     .source_file  string          ruta absoluta al .xlsx leido

%% -- Calcular ruta absoluta al archivo de datos -------------------------
src_root  = fileparts(mfilename('fullpath'));   % .../refactored/src/
proj_root = fileparts(src_root);               % .../refactored/

if isempty(Cfg.DATA_FILE)
    xlsx_path = fullfile(proj_root, 'data', 'data_bnw.xlsx');
else
    xlsx_path = Cfg.DATA_FILE;
end

if ~isfile(xlsx_path)
    error('load_data:fileNotFound', ...
        'Archivo de datos no encontrado: %s', xlsx_path);
end

%% -- Hoja 1: datos tabulares -------------------------------------------
% Forzar lectura de texto para la primera columna (fechas)
opts1 = detectImportOptions(xlsx_path, 'Sheet', 1);
opts1 = setvaropts(opts1, opts1.VariableNames{1}, 'Type', 'char');
T1    = readtable(xlsx_path, opts1, 'Sheet', 1);

% Primera columna = fechas; resto = variables numericas
Dataset.dates   = table2cell(T1(:, 1));          % {T x 1 cell} de strings
Dataset.Y_raw   = table2array(T1(:, 2:end));     % [T x nvar_total double]

%% -- Hoja 2: metadata --------------------------------------------------
T2 = readtable(xlsx_path, 'Sheet', 2, 'ReadVariableNames', true);

% Se esperan columnas: var_name | role | label
% Ser tolerante con nombres de columna en distintos casos
col_names = lower(T2.Properties.VariableNames);

idx_name  = find(strcmp(col_names, 'var_name'), 1);
idx_role  = find(strcmp(col_names, 'role'),     1);
idx_label = find(strcmp(col_names, 'label'),    1);

if isempty(idx_name) || isempty(idx_role) || isempty(idx_label)
    error('load_data:metadataCols', ...
        ['Hoja 2 debe tener columnas var_name, role y label. ' ...
         'Columnas encontradas: %s'], strjoin(T2.Properties.VariableNames, ', '));
end

Dataset.var_names  = T2{:, idx_name}';    % {1 x nvar_total}
Dataset.var_labels = T2{:, idx_label}';   % {1 x nvar_total}
Dataset.var_roles  = T2{:, idx_role}';    % {1 x nvar_total}

% Asegurar que sean cell arrays de strings
if ~iscell(Dataset.var_names)
    Dataset.var_names = cellstr(Dataset.var_names);
end
if ~iscell(Dataset.var_labels)
    Dataset.var_labels = cellstr(Dataset.var_labels);
end
if ~iscell(Dataset.var_roles)
    Dataset.var_roles = cellstr(Dataset.var_roles);
end

%% -- Derivados ---------------------------------------------------------
endo_mask         = strcmp(Dataset.var_roles, 'endogenous');
Dataset.nvar      = sum(endo_mask);
Dataset.nvar_total = size(Dataset.Y_raw, 2);
Dataset.source_file = xlsx_path;

%% -- Verificacion basica -----------------------------------------------
if Dataset.nvar_total ~= numel(Dataset.var_names)
    error('load_data:dimMismatch', ...
        ['Numero de columnas en Hoja 1 (%d) no coincide con filas de ' ...
         'metadata en Hoja 2 (%d).'], ...
        Dataset.nvar_total, numel(Dataset.var_names));
end

end
