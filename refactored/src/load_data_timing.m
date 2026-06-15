function Dataset = load_data_timing(Cfg)
% load_data_timing  Data loader especializado para specs de timing (Tabla 4).
%
% Maneja dos fuentes de datos según Cfg.DATA_SOURCE:
%
%  'bnw_csv'     → Caso 4L1Z: lee data_bnw.xlsx (mismos datos que BNW).
%                  Toma las primeras Cfg.NVAR columnas (5, 6, ó 7 vars).
%                  Los datos ya están en log-pct × 100 (excepto RIR en pct).
%                  Aplica SCALE_FACTOR=100 en build_posterior.
%
%  'timing_xlsx' → Caso 12L3Z: lee data_timing.xlsx (datos mensuales).
%                  Toma las primeras Cfg.NVAR columnas del xlsx.
%                  El scaling (log×100 excepto FFR) se aplica aquí, igual
%                  que en el original. SCALE_FACTOR=1 en este caso.
%
% OUTPUT: Dataset struct con los campos estándar esperados por build_posterior.
%
% REGLA: nunca se usa pwd, cd, ni '..'.

src_root  = fileparts(mfilename('fullpath'));   % .../refactored/src/
proj_root = fileparts(src_root);               % .../refactored/

nvar = Cfg.NVAR;   % 5, 6 ó 7

switch Cfg.DATA_SOURCE

    %======================================================================
    case 'bnw_csv'
    %======================================================================
    % Caso 4L1Z: mismos datos que figure_1 (BNW), hasta 7 vars extendidas.
    % Lee data_bnw.xlsx (Hoja 1: fecha + vars, Hoja 2: metadata).
    % Usa las primeras nvar columnas de Y_raw.

    if isempty(Cfg.DATA_FILE)
        xlsx_path = fullfile(proj_root, 'data', 'data_bnw.xlsx');
    else
        xlsx_path = Cfg.DATA_FILE;
    end
    if ~isfile(xlsx_path)
        error('load_data_timing:fileNotFound', 'No encontrado: %s', xlsx_path);
    end

    % Hoja 1: fecha + variables
    opts1 = detectImportOptions(xlsx_path, 'Sheet', 1);
    opts1 = setvaropts(opts1, opts1.VariableNames{1}, 'Type', 'char');
    T1    = readtable(xlsx_path, opts1, 'Sheet', 1);

    dates_all = table2cell(T1(:, 1));
    Y_all     = table2array(T1(:, 2:end));   % todas las columnas numéricas

    if size(Y_all, 2) < nvar
        error('load_data_timing:notEnoughVars', ...
            'data_bnw.xlsx tiene %d variables pero Cfg.NVAR=%d', ...
            size(Y_all, 2), nvar);
    end

    Dataset.dates       = dates_all;
    Dataset.Y_raw       = Y_all(:, 1:nvar);   % primeras nvar columnas
    Dataset.nvar        = nvar;
    Dataset.nvar_total  = nvar;
    Dataset.source_file = xlsx_path;

    % Metadata sintética (no hay Hoja 2 con nvar>5 necesariamente)
    Dataset.var_names  = cell(1, nvar);
    Dataset.var_labels = cell(1, nvar);
    Dataset.var_roles  = cell(1, nvar);
    base_names  = {'tfp','sp','cons','rir','hours','inv','output'};
    base_labels = {'Adjusted TFP','Stock Prices','Consumption',...
                   'Real Interest Rate','Hours Worked',...
                   'Investment','Output'};
    for k = 1:nvar
        Dataset.var_names{k}  = base_names{k};
        Dataset.var_labels{k} = base_labels{k};
        Dataset.var_roles{k}  = 'endogenous';
    end

    %======================================================================
    case 'timing_xlsx'
    %======================================================================
    % Caso 12L3Z: datos mensuales, transformación log×100 aquí.
    % Variables (columnas 1-7 del xlsx):
    %   1: Real GDP         → 100*log
    %   2: GDP Deflator     → 100*log
    %   3: PCOM             → 100*log
    %   4: M2               → 100*log
    %   5: Federal Funds Rate → 100* (ya en pct anualizado)
    %   6: Unemployment Rate  → 100* (en %)  [sólo para n=6,7]
    %   7: Uncertainty Index  → 100*log       [sólo para n=7]

    if isempty(Cfg.DATA_FILE)
        xlsx_path = fullfile(proj_root, 'data', 'data_timing.xlsx');
    else
        xlsx_path = Cfg.DATA_FILE;
    end
    if ~isfile(xlsx_path)
        error('load_data_timing:fileNotFound', 'No encontrado: %s', xlsx_path);
    end

    % Leer todas las columnas numéricas del xlsx
    raw = xlsread(xlsx_path);   % [T × ncols_raw]
    if size(raw, 2) < nvar
        error('load_data_timing:notEnoughVars', ...
            'data_timing.xlsx tiene %d columnas pero Cfg.NVAR=%d', ...
            size(raw, 2), nvar);
    end

    % Aplicar transformación según el original (idéntica para n=5,6,7)
    % n=5: cols 1-5
    % n=6: cols 1-6 (col 6 = unemployment → 100* directo, sin log)
    % n=7: cols 1-7 (col 7 = uncertainty → 100*log)
    num = zeros(size(raw, 1), nvar);
    for k = 1:min(nvar, 4)
        num(:, k) = 100 * log(raw(:, k));  % GDP, Deflator, PCOM, M2
    end
    if nvar >= 5
        num(:, 5) = 100 * raw(:, 5);       % FFR: ya en pct anualizado
    end
    if nvar >= 6
        num(:, 6) = 100 * raw(:, 6);       % Unemployment Rate (en %)
    end
    if nvar >= 7
        num(:, 7) = 100 * log(raw(:, 7));  % Uncertainty Index
    end

    % Dataset con datos ya transformados (SCALE_FACTOR=1 no cambia nada)
    Dataset.Y_raw       = num;
    Dataset.nvar        = nvar;
    Dataset.nvar_total  = nvar;
    Dataset.source_file = xlsx_path;
    Dataset.dates       = {};   % sin fechas legibles para timing

    base_names  = {'gdp','defl','pcom','m2','ffr','unemp','uncertainty'};
    base_labels = {'Real GDP','GDP Deflator','Commodity Price',...
                   'M2','Federal Funds Rate','Unemployment','Uncertainty'};
    Dataset.var_names  = cell(1, nvar);
    Dataset.var_labels = cell(1, nvar);
    Dataset.var_roles  = cell(1, nvar);
    for k = 1:nvar
        Dataset.var_names{k}  = base_names{k};
        Dataset.var_labels{k} = base_labels{k};
        Dataset.var_roles{k}  = 'endogenous';
    end

    otherwise
        error('load_data_timing:unknownSource', ...
            'Cfg.DATA_SOURCE desconocido: ''%s''', Cfg.DATA_SOURCE);
end

end % function
