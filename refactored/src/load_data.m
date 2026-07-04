function Dataset = load_data(Cfg)
%LOAD_DATA  Data loader canonico (generalizado) del SVAR Toolkit.
%
%   Dataset = LOAD_DATA(Cfg) lee el archivo especificado en Cfg.DATA_FILE
%   (o data/data_bnw.xlsx del proyecto si Cfg.DATA_FILE esta vacio) y
%   devuelve la struct Dataset.
%
%   ESTRUCTURA DEL ARCHIVO XLSX
%     Hoja "data"      (OBLIGATORIA) — col 1 = fecha (DD/MM/AAAA), resto =
%                       variables. El nombre de cada columna (excepto la
%                       primera) se usa como Dataset.var_names.
%     Hoja "metadata"  (OPCIONAL)    — columnas var_name | label, leidas
%                       por NOMBRE de columna (no por posicion). Provee
%                       labels legibles para graficos/tablas, emparejados
%                       con var_names por NOMBRE (no por posicion).
%
%   Las hojas se referencian SIEMPRE por nombre ("data", "metadata"),
%   nunca por indice/posicion. Si el archivo tiene una hoja adicional
%   llamada "role" u otras columnas legado dentro de "metadata" (p.ej. una
%   columna 'role' de versiones anteriores del toolkit), se IGNORAN: los
%   roles nunca se leen del Excel (ver bloque ROLES abajo).
%
%   METADATA PARCIAL:
%     Si la hoja "metadata" existe, debe cubrir TODAS las variables de la
%     hoja "data" (todo o nada). Si cubre solo un subconjunto, LOAD_DATA
%     lanza un error explicito en vez de completar labels silenciosamente.
%
%   SIN HOJA "metadata":
%     Dataset.var_labels = {'var1', 'var2', ...} (defaults posicionales).
%
%   ROLES (endogena/exogena):
%     Los roles NUNCA se leen del Excel. Se definen en el spec via
%     Cfg.VAR_ROLES (cell array de strings 'endogenous'/'exogenous', mismo
%     orden y longitud que las columnas de variables en la hoja "data").
%     DEFAULT (documentado aqui): si Cfg.VAR_ROLES no esta definido o esta
%     vacio, LOAD_DATA asume que TODAS las variables son 'endogenous'.
%     Este default reproduce el comportamiento de specs anteriores a esta
%     version del loader que no conocian Cfg.VAR_ROLES.
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
%     .var_names    {1 x nvar_total cell} nombres cortos (de la hoja "data")
%     .var_labels   {1 x nvar_total cell} labels para graficos
%     .var_roles    {1 x nvar_total cell} 'endogenous' | 'exogenous' (desde Cfg)
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

%% -- Hoja "data" (OBLIGATORIA), referenciada por NOMBRE -----------------
% Nota tecnica: el NOMBRE decide QUE hoja se lee (nunca se asume una
% posicion fija en el archivo), pero la llamada de bajo nivel a
% detectImportOptions/readtable se hace con el INDICE ya resuelto. Esto
% evita una diferencia real de deteccion automatica de tipos de columna
% entre pasar 'Sheet' como nombre (string) y como indice (numerico) que
% se observo con datos que no son fechas reales de Excel (p.ej. texto
% "AAAA.T" como en data_bnw.xlsx) y que rompia el parseo de fechas.
idx_data = p_sheet_index(xlsx_path, 'data');
if isempty(idx_data)
    error('load_data:sheetDataMissing', ...
        ['No se encontro una hoja llamada "data" en %s. Las hojas se ' ...
         'referencian siempre por nombre (nunca por posicion).'], xlsx_path);
end
opts1 = detectImportOptions(xlsx_path, 'Sheet', idx_data);

% Forzar primera columna como datetime
opts1 = setvaropts(opts1, opts1.VariableNames{1}, 'Type', 'datetime', ...
    'InputFormat', 'dd/MM/yyyy');
T1 = readtable(xlsx_path, opts1, 'Sheet', idx_data);

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

Dataset.var_names = T1.Properties.VariableNames(2:end);
if ~iscell(Dataset.var_names), Dataset.var_names = cellstr(Dataset.var_names); end

nvar_total          = size(Dataset.Y_raw, 2);
Dataset.nvar_total  = nvar_total;
Dataset.source_file = xlsx_path;

%% -- Detectar frecuencia -------------------------------------------------
Dataset.freq = p_detect_freq(dates_raw);

%% -- Hoja "metadata" (OPCIONAL), referenciada por NOMBRE ----------------
idx_meta     = p_sheet_index(xlsx_path, 'metadata');
has_metadata = ~isempty(idx_meta);

if has_metadata
    T2 = readtable(xlsx_path, 'Sheet', idx_meta, 'ReadVariableNames', true);

    col_names = lower(T2.Properties.VariableNames);
    idx_name  = find(strcmp(col_names, 'var_name'), 1);
    idx_label = find(strcmp(col_names, 'label'),    1);
    % Nota: si existe una columna 'role' (legado), se ignora deliberadamente.
    % Los roles siempre vienen de Cfg.VAR_ROLES (ver bloque ROLES abajo).

    if isempty(idx_name) || isempty(idx_label)
        error('load_data:metadataCols', ...
            ['La hoja "metadata" debe tener (al menos) columnas var_name ' ...
             'y label. Columnas encontradas: %s'], ...
            strjoin(T2.Properties.VariableNames, ', '));
    end

    meta_names  = T2{:, idx_name};
    meta_labels = T2{:, idx_label};
    if ~iscell(meta_names),  meta_names  = cellstr(meta_names);  end
    if ~iscell(meta_labels), meta_labels = cellstr(meta_labels); end

    % Metadata parcial: todo o nada. Primero se verifica el conteo total.
    if numel(meta_names) ~= nvar_total
        error('load_data:partialMetadata', ...
            ['Metadata parcial detectada: la hoja "metadata" define labels ' ...
             'para %d variable(s), pero la hoja "data" tiene %d columna(s) ' ...
             'de variables. La metadata debe cubrir TODAS las variables o ' ...
             'ninguna (no se permiten subconjuntos).'], ...
            numel(meta_names), nvar_total);
    end

    % Emparejar por NOMBRE (var_name), no por posicion.
    var_labels = cell(1, nvar_total);
    for i = 1:nvar_total
        j = find(strcmp(meta_names, Dataset.var_names{i}), 1);
        if isempty(j)
            error('load_data:partialMetadata', ...
                ['Metadata parcial detectada: no se encontro un label para ' ...
                 'la variable "%s" (columna %d de la hoja "data") en la ' ...
                 'hoja "metadata". La metadata debe cubrir TODAS las ' ...
                 'variables o ninguna.'], Dataset.var_names{i}, i);
        end
        var_labels{i} = meta_labels{j};
    end
    Dataset.var_labels = var_labels;
else
    Dataset.var_labels = arrayfun(@(k) sprintf('var%d', k), ...
        1:nvar_total, 'UniformOutput', false);
end

%% -- Roles: SIEMPRE desde Cfg.VAR_ROLES, NUNCA desde el Excel -----------
% DEFAULT DOCUMENTADO: si Cfg.VAR_ROLES no esta definido (o esta vacio),
% TODAS las variables se consideran 'endogenous'. Este es el comportamiento
% que tenian implicitamente los specs anteriores a esta version del loader.
if isfield(Cfg, 'VAR_ROLES') && ~isempty(Cfg.VAR_ROLES)
    var_roles = Cfg.VAR_ROLES;
    if ~iscell(var_roles), var_roles = cellstr(var_roles); end
    var_roles = var_roles(:)';

    if numel(var_roles) ~= nvar_total
        error('load_data:varRolesDim', ...
            ['Cfg.VAR_ROLES tiene %d elemento(s) pero la hoja "data" tiene ' ...
             '%d columna(s) de variables. Deben coincidir en numero y ' ...
             'orden.'], numel(var_roles), nvar_total);
    end

    valid_roles = {'endogenous', 'exogenous'};
    is_valid     = ismember(lower(var_roles), valid_roles);
    if ~all(is_valid)
        bad_idx = find(~is_valid);
        error('load_data:varRolesInvalid', ...
            ['Cfg.VAR_ROLES solo acepta ''endogenous'' o ''exogenous''. ' ...
             'Valor(es) invalido(s) en posicion(es): %s'], mat2str(bad_idx));
    end

    Dataset.var_roles = var_roles;
else
    Dataset.var_roles = repmat({'endogenous'}, 1, nvar_total);   % DEFAULT
end

%% -- Derivados -----------------------------------------------------------
Dataset.nvar = sum(strcmp(Dataset.var_roles, 'endogenous'));

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

%% ======================================================================
%% Funcion auxiliar privada: resolver el INDICE de una hoja via su NOMBRE
%% ======================================================================
function idx = p_sheet_index(xlsx_path, sheet_name)
%P_SHEET_INDEX  Resuelve el INDICE de una hoja a partir de su NOMBRE.
%   Devuelve [] si no existe una hoja con ese nombre.
%
%   Se usa el NOMBRE para decidir que hoja leer (nunca se asume una
%   posicion fija), pero las llamadas a detectImportOptions/readtable se
%   hacen con el INDICE resuelto aqui, no con el nombre directamente (ver
%   nota tecnica en el cuerpo principal de load_data).
%
%   Compatible con MATLAB R2019b+: usa sheetnames (R2020b+) si esta
%   disponible, y cae a xlsfinfo (deprecado pero funcional) si no.
try
    sheets = sheetnames(xlsx_path);
catch
    [~, sheets] = xlsfinfo(xlsx_path);
end
idx = find(strcmp(sheets, sheet_name), 1);
end
