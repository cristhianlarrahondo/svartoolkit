function Dataset = load_data(Cfg)
%LOAD_DATA  Data loader canonico del SVAR Toolkit.
%
%   Dataset = LOAD_DATA(Cfg) lee data_bnw.xlsx (o el archivo especificado
%   en Cfg.DATA_FILE) y devuelve la struct Dataset.
%
%   El archivo xlsx debe tener DOS hojas:
%     Hoja 1: datos tabulares  — col 1 = fecha (DD/MM/AAAA), resto = variables
%     Hoja 2: metadata         — columnas: var_name | role | label
%
%   FORMATO FECHA OBLIGATORIO:
%     La columna de fecha debe ser una fecha real de Excel en formato
%     DD/MM/AAAA. El loader la convierte a datetime de MATLAB.
%     Convencion de periodo: ultimo mes del periodo.
%       Trimestral : Q1->31/03, Q2->30/06, Q3->30/09, Q4->31/12
%       Semestral  : S1->30/06, S2->31/12
%       Anual      : 31/12/AAAA
%
%   REGLA DE RUTAS: nunca se usa pwd, cd, ni '..'.
%   La ruta al proyecto se calcula con fileparts(mfilename('fullpath')).
%
%   Campos de Dataset devueltos:
%     .dates        [T x 1 datetime]      fechas como datetime de MATLAB
%     .dates_str    {T x 1 cell}          fechas como strings 'MM/YYYY'
%     .Y_raw        [T x nvar_total]      datos crudos SIN escalar
%     .var_names    {1 x nvar_total cell} nombres cortos
%     .var_labels   {1 x nvar_total cell} labels para graficos
%     .var_roles    {1 x nvar_total cell} 'endogenous' | 'exogenous'
%     .nvar         scalar                numero de variables endogenas
%     .nvar_total   scalar                total columnas (sin dummies)
%     .source_file  string                ruta absoluta al .xlsx leido
%     .freq         string                frecuencia detectada: 'Q','M','A','S','?'

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
opts1 = detectImportOptions(xlsx_path, 'Sheet', 1);
% Forzar primera columna como datetime
opts1 = setvaropts(opts1, opts1.VariableNames{1}, 'Type', 'datetime', ...
    'InputFormat', 'dd/MM/yyyy');
T1 = readtable(xlsx_path, opts1, 'Sheet', 1);

% Primera columna = fechas datetime; resto = variables numericas
dates_raw = T1{:, 1};   % datetime array

if ~isdatetime(dates_raw)
    error('load_data:badDateFormat', ...
        ['La columna de fecha no se pudo leer como datetime. ' ...
         'Asegurese de que el archivo tenga fechas reales de Excel ' ...
         'en formato DD/MM/AAAA (no texto).']);
end

Dataset.dates     = dates_raw;
Dataset.dates_str = cellstr(datestr(dates_raw, 'mm/yyyy'));
Dataset.Y_raw     = table2array(T1(:, 2:end));   % [T x nvar_total]

%% -- Detectar frecuencia -----------------------------------------------
Dataset.freq = p_detect_freq(dates_raw);

%% -- Hoja 2: metadata --------------------------------------------------
T2 = readtable(xlsx_path, 'Sheet', 2, 'ReadVariableNames', true);

col_names = lower(T2.Properties.VariableNames);
idx_name  = find(strcmp(col_names, 'var_name'), 1);
idx_role  = find(strcmp(col_names, 'role'),     1);
idx_label = find(strcmp(col_names, 'label'),    1);

if isempty(idx_name) || isempty(idx_role) || isempty(idx_label)
    error('load_data:metadataCols', ...
        ['Hoja 2 debe tener columnas var_name, role y label. ' ...
         'Columnas encontradas: %s'], strjoin(T2.Properties.VariableNames, ', '));
end

Dataset.var_names  = T2{:, idx_name}';
Dataset.var_labels = T2{:, idx_label}';
Dataset.var_roles  = T2{:, idx_role}';

if ~iscell(Dataset.var_names),  Dataset.var_names  = cellstr(Dataset.var_names);  end
if ~iscell(Dataset.var_labels), Dataset.var_labels = cellstr(Dataset.var_labels); end
if ~iscell(Dataset.var_roles),  Dataset.var_roles  = cellstr(Dataset.var_roles);  end

%% -- Derivados ---------------------------------------------------------
endo_mask          = strcmp(Dataset.var_roles, 'endogenous');
Dataset.nvar       = sum(endo_mask);
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

%% ======================================================================
%% Funcion auxiliar privada: detectar frecuencia
%% ======================================================================
function freq = p_detect_freq(dates)
%P_DETECT_FREQ  Detecta la frecuencia de la serie a partir de las fechas.
if numel(dates) < 2
    freq = '?';
    return;
end
% Diferencia en dias entre las dos primeras observaciones
delta_days = days(dates(2) - dates(1));
if     delta_days >= 360 && delta_days <= 370
    freq = 'A';   % anual
elseif delta_days >= 175 && delta_days <= 185
    freq = 'S';   % semestral
elseif delta_days >= 85  && delta_days <= 95
    freq = 'Q';   % trimestral
elseif delta_days >= 28  && delta_days <= 32
    freq = 'M';   % mensual
else
    freq = '?';   % desconocida
end
end
