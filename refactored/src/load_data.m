function Dataset = load_data(Cfg)
%LOAD_DATA  Data loader canonico del SVAR Toolkit.
%
%   Dataset = LOAD_DATA(Cfg) lee data_bnw.xlsx (o el archivo especificado
%   en Cfg.DATA_FILE) y devuelve la struct Dataset.
%
%   El archivo xlsx puede tener una o dos hojas:
%     Hoja 1: datos tabulares  — col 1 = fecha (texto), resto = variables
%     Hoja 2: metadata         — columnas: var_name | role | label
%             (opcional; si no existe, usar Cfg.VAR_ROLES y Cfg.VAR_LABELS)
%
%   REGLA DE RUTAS: nunca se usa pwd, cd, ni '..'.
%   La ruta al proyecto se calcula con fileparts(mfilename('fullpath')).
%
%   Campos de Dataset devueltos:
%     .dates               [T x 1 cell]           etiquetas de fecha
%     .Y_raw               [T x nvar_total double] datos crudos SIN escalar
%     .var_names           {1 x nvar_total cell}   nombres cortos
%     .var_labels          {1 x nvar_total cell}   labels para graficos
%     .var_roles           {1 x nvar_total cell}   'endogenous'|'exogenous'
%     .nvar                scalar                  n. variables endogenas
%     .nvar_total          scalar                  total columnas Hoja 1
%     .source_file         string                  ruta absoluta al .xlsx
%     .transforms_applied  struct                  doc. de transformaciones
%     .dummies_applied     struct                  doc. de dummies (si B6)
%
%   Extensiones de Cfg soportadas:
%     Cfg.TRANSFORMS  — struct/cell con transformaciones por variable
%     Cfg.VAR_ROLES   — cell array (si no hay hoja varinfo)
%     Cfg.VAR_LABELS  — cell array (si no hay hoja varinfo)
%     Cfg.DUMMIES     — struct array con dummies exogenas

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

%% -- Hoja 2: metadata o modo generico ----------------------------------
% Detectar si existe hoja varinfo
has_varinfo = p_has_sheet(xlsx_path, 'varinfo') || ...
              p_has_sheet_by_index(xlsx_path, 2);

if has_varinfo
    %-- Modo normal: leer hoja 2 ----------------------------------------
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

    Dataset.var_names  = T2{:, idx_name}';    % {1 x nvar_total}
    Dataset.var_labels = T2{:, idx_label}';   % {1 x nvar_total}
    Dataset.var_roles  = T2{:, idx_role}';    % {1 x nvar_total}

    % Asegurar que sean cell arrays de strings
    if ~iscell(Dataset.var_names),  Dataset.var_names  = cellstr(Dataset.var_names);  end
    if ~iscell(Dataset.var_labels), Dataset.var_labels = cellstr(Dataset.var_labels); end
    if ~iscell(Dataset.var_roles),  Dataset.var_roles  = cellstr(Dataset.var_roles);  end

else
    %-- Modo generico (C2): roles y labels via Cfg ----------------------
    if ~isfield(Cfg, 'VAR_ROLES') || isempty(Cfg.VAR_ROLES)
        error('load_data:missingVarRoles', ...
            ['El archivo no tiene hoja de metadata (varinfo) y ' ...
             'Cfg.VAR_ROLES no esta definido. ' ...
             'Defina Cfg.VAR_ROLES como cell array de strings ' ...
             '(''endogenous'' | ''exogenous'').']);
    end

    nv = size(Dataset.Y_raw, 2);

    % VAR_ROLES es obligatorio
    roles = Cfg.VAR_ROLES;
    if ~iscell(roles), roles = cellstr(roles); end
    if numel(roles) ~= nv
        error('load_data:dimMismatch', ...
            'Cfg.VAR_ROLES tiene %d elementos pero el archivo tiene %d variables.', ...
            numel(roles), nv);
    end
    Dataset.var_roles = roles(:)';

    % VAR_LABELS es opcional (default = indices)
    if isfield(Cfg, 'VAR_LABELS') && ~isempty(Cfg.VAR_LABELS)
        labs = Cfg.VAR_LABELS;
        if ~iscell(labs), labs = cellstr(labs); end
        if numel(labs) ~= nv
            error('load_data:dimMismatch', ...
                'Cfg.VAR_LABELS tiene %d elementos pero el archivo tiene %d variables.', ...
                numel(labs), nv);
        end
        Dataset.var_labels = labs(:)';
    else
        Dataset.var_labels = arrayfun(@(k) sprintf('Var%d', k), 1:nv, 'UniformOutput', false);
    end

    % Intentar leer nombres de columna del xlsx; fallback a etiquetas
    try
        col_hdrs = T1.Properties.VariableNames(2:end);
        Dataset.var_names = col_hdrs;
    catch
        Dataset.var_names = Dataset.var_labels;
    end
end

%% -- C1: aplicar transformaciones Cfg.TRANSFORMS -----------------------
Dataset.transforms_applied = struct('var', {{}}, 'transform', {{}});

if isfield(Cfg, 'TRANSFORMS') && ~isempty(Cfg.TRANSFORMS)
    transforms = Cfg.TRANSFORMS;

    % Aceptar struct array o containers.Map o cell {name, transform}
    % Formato canónico: struct array con campos .var y .transform
    %   o cell array Nx2  { 'varname', 'transform'; ... }
    if isstruct(transforms)
        % Struct array: cada elemento tiene .var (nombre o índice) y .transform
        tf_list = transforms;
    elseif iscell(transforms)
        % Cell Nx2: { 'varname', 'transform'; 'varname2', 'transform2'; ... }
        if size(transforms, 2) ~= 2
            error('load_data:badTransforms', ...
                'Cfg.TRANSFORMS como cell debe ser Nx2: {varname, transform}.');
        end
        tf_list = struct('var', transforms(:,1), 'transform', transforms(:,2));
    else
        error('load_data:badTransforms', ...
            'Cfg.TRANSFORMS debe ser struct array o cell Nx2.');
    end

    applied_vars = {};
    applied_tfs  = {};

    for k = 1:numel(tf_list)
        tf_entry = tf_list(k);
        tf_name  = tf_entry.transform;

        % Resolver índice de columna
        if isnumeric(tf_entry.var)
            col_idx = tf_entry.var;
        else
            col_idx = find(strcmp(Dataset.var_names, tf_entry.var), 1);
            if isempty(col_idx)
                error('load_data:unknownVar', ...
                    'Variable ''%s'' no encontrada en var_names.', tf_entry.var);
            end
        end

        % Aplicar transformación
        y = Dataset.Y_raw(:, col_idx);
        switch lower(tf_name)
            case 'none'
                % Sin transformacion
            case 'log'
                if any(y <= 0)
                    error('load_data:transformLog', ...
                        'Transform ''log'' requiere valores positivos (var idx %d).', col_idx);
                end
                Dataset.Y_raw(:, col_idx) = log(y);
            case 'dlog'
                if any(y <= 0)
                    error('load_data:transformDlog', ...
                        'Transform ''dlog'' requiere valores positivos (var idx %d).', col_idx);
                end
                ly = log(y);
                % Primera diferencia de log: pierde primera observacion
                % Se rellena con NaN en la primera fila y se recorta al final
                dly = [NaN; diff(ly)];
                Dataset.Y_raw(:, col_idx) = dly;
            case 'diff'
                dy = [NaN; diff(y)];
                Dataset.Y_raw(:, col_idx) = dy;
            case 'demean'
                Dataset.Y_raw(:, col_idx) = y - mean(y);
            otherwise
                error('load_data:unknownTransform', ...
                    'Transformacion desconocida: ''%s''. Validas: none, log, dlog, diff, demean.', ...
                    tf_name);
        end

        if ~strcmpi(tf_name, 'none')
            applied_vars{end+1} = tf_entry.var; %#ok<AGROW>
            applied_tfs{end+1}  = tf_name;       %#ok<AGROW>
        end
    end

    % Recortar filas NaN del inicio si hubo dlog o diff
    if ~isempty(Dataset.Y_raw) && any(any(isnan(Dataset.Y_raw(1, :))))
        Dataset.Y_raw   = Dataset.Y_raw(2:end, :);
        Dataset.dates   = Dataset.dates(2:end);
    end

    Dataset.transforms_applied.var       = applied_vars;
    Dataset.transforms_applied.transform = applied_tfs;
end

%% -- B6: construir dummies Cfg.DUMMIES ---------------------------------
Dataset.dummies_applied = struct('name', {{}}, 'type', {{}}, 'date', {{}});

if isfield(Cfg, 'DUMMIES') && ~isempty(Cfg.DUMMIES)
    dummy_specs = Cfg.DUMMIES;
    if ~isstruct(dummy_specs)
        error('load_data:badDummies', ...
            'Cfg.DUMMIES debe ser un struct array con campos: name, type, date (y period para seasonal).');
    end

    T = size(Dataset.Y_raw, 1);
    dummy_matrix = [];
    dummy_names  = {};
    dummy_roles  = {};
    dummy_labels = {};

    for k = 1:numel(dummy_specs)
        d = dummy_specs(k);

        % Validar campos obligatorios
        if ~isfield(d, 'type')
            error('load_data:dummyMissingField', ...
                'Dummy %d no tiene campo ''type''.', k);
        end
        if ~isfield(d, 'name')
            d.name = sprintf('dummy_%s_%d', d.type, k);
        end

        col = zeros(T, 1);

        switch lower(d.type)
            case 'pulse'
                % date_idx: indice de fila donde ocurre el pulso
                t_idx = p_resolve_date(d, Dataset.dates, T);
                col(t_idx) = 1;

            case 'step'
                % 0 antes de date_idx, 1 desde date_idx
                t_idx = p_resolve_date(d, Dataset.dates, T);
                col(t_idx:end) = 1;

            case 'seasonal'
                % period: periodo de la estacionalidad (e.g. 4 para trimestral)
                % phase: fase dentro del periodo donde dummy=1 (1-based, default 1)
                if ~isfield(d, 'period') || isempty(d.period)
                    error('load_data:dummyMissingPeriod', ...
                        'Dummy seasonal ''%s'' requiere campo ''period''.', d.name);
                end
                period = d.period;
                phase  = 1;
                if isfield(d, 'phase') && ~isempty(d.phase)
                    phase = d.phase;
                end
                for t = 1:T
                    if mod(t - phase, period) == 0
                        col(t) = 1;
                    end
                end

            otherwise
                error('load_data:unknownDummyType', ...
                    'Tipo de dummy desconocido: ''%s''. Validos: pulse, step, seasonal.', ...
                    d.type);
        end

        dummy_matrix(:, end+1) = col; %#ok<AGROW>
        dummy_names{end+1}     = d.name; %#ok<AGROW>
        dummy_roles{end+1}     = 'exogenous'; %#ok<AGROW>
        dummy_labels{end+1}    = d.name; %#ok<AGROW>
    end

    % Agregar dummies a Y_raw como columnas adicionales
    Dataset.Y_raw      = [Dataset.Y_raw, dummy_matrix];
    Dataset.var_names  = [Dataset.var_names,  dummy_names];
    Dataset.var_labels = [Dataset.var_labels, dummy_labels];
    Dataset.var_roles  = [Dataset.var_roles,  dummy_roles];

    % Documentar
    for k = 1:numel(dummy_names)
        Dataset.dummies_applied.name{end+1} = dummy_names{k};
        Dataset.dummies_applied.type{end+1} = dummy_specs(k).type;
        if isfield(dummy_specs(k), 'date_idx')
            Dataset.dummies_applied.date{end+1} = dummy_specs(k).date_idx;
        elseif isfield(dummy_specs(k), 'date_str')
            Dataset.dummies_applied.date{end+1} = dummy_specs(k).date_str;
        else
            Dataset.dummies_applied.date{end+1} = [];
        end
    end
end

%% -- Derivados ---------------------------------------------------------
endo_mask          = strcmp(Dataset.var_roles, 'endogenous');
Dataset.nvar       = sum(endo_mask);
Dataset.nvar_total = size(Dataset.Y_raw, 2);
Dataset.source_file = xlsx_path;

%% -- Verificacion basica -----------------------------------------------
% nvar_total incluye dummies; comparar solo variables originales con metadata
n_meta = numel(Dataset.var_names);
if size(Dataset.Y_raw, 2) ~= n_meta
    error('load_data:dimMismatch', ...
        ['Numero de columnas en Y_raw (%d) no coincide con ' ...
         'numero de entradas en var_names (%d).'], ...
        size(Dataset.Y_raw, 2), n_meta);
end

end

%% ======================================================================
%% Funciones auxiliares privadas
%% ======================================================================

function tf = p_has_sheet(xlsx_path, sheet_name)
%P_HAS_SHEET  Devuelve true si el xlsx tiene una hoja con ese nombre.
try
    [~, sheets] = xlsfinfo(xlsx_path);
    tf = any(strcmpi(sheets, sheet_name));
catch
    tf = false;
end
end

function tf = p_has_sheet_by_index(xlsx_path, idx)
%P_HAS_SHEET_BY_INDEX  Devuelve true si el xlsx tiene al menos idx hojas.
try
    [~, sheets] = xlsfinfo(xlsx_path);
    tf = numel(sheets) >= idx;
catch
    tf = false;
end
end

function t_idx = p_resolve_date(d, dates, T)
%P_RESOLVE_DATE  Resuelve el indice de fila para una dummy de fecha.
%   Acepta campo date_idx (entero) o date_str (string a buscar en dates).
if isfield(d, 'date_idx') && ~isempty(d.date_idx)
    t_idx = d.date_idx;
    if t_idx < 1 || t_idx > T
        error('load_data:dummyDateOutOfRange', ...
            'date_idx=%d fuera de rango [1, %d].', t_idx, T);
    end
elseif isfield(d, 'date_str') && ~isempty(d.date_str)
    hit = find(strcmp(dates, d.date_str), 1);
    if isempty(hit)
        error('load_data:dummyDateNotFound', ...
            'date_str=''%s'' no encontrado en Dataset.dates.', d.date_str);
    end
    t_idx = hit;
else
    error('load_data:dummyMissingDate', ...
        'Dummy debe tener campo date_idx o date_str.');
end
end
