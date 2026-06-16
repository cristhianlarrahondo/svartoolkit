function DummyMatrix = build_dummies(Cfg, dates)
%BUILD_DUMMIES  Construye matriz de variables dummy exogenas.
%
%   DummyMatrix = BUILD_DUMMIES(Cfg, dates)
%
%   Lee Cfg.DUMMIES (struct array) y genera una matriz [T x ndummies]
%   lista para concatenar al final de xt en build_posterior.m.
%
%   Cada elemento de Cfg.DUMMIES debe tener:
%     .name        string — nombre descriptivo (usado en etiquetas)
%     .type        string — tipo de dummy:
%                    'oneoff'   : 1 en una fecha puntual, 0 el resto
%                    'pulse'    : 1 en un rango de fechas, 0 el resto
%                    'step'     : 0 antes de la fecha, 1 desde la fecha
%                    'seasonal' : patron periodico (requiere .period, .phase)
%
%   Localizacion por fecha (cualquiera de las dos formas):
%     .date        [year, month] — fecha puntual (para oneoff y step)
%     .date_start  [year, month] — inicio del rango (para pulse)
%     .date_end    [year, month] — fin del rango (para pulse)
%     .period      entero        — periodo de repeticion (para seasonal)
%     .phase       entero        — fase dentro del periodo (default=1)
%
%   El argumento dates es Dataset.dates: datetime array [T x 1].
%   Si dates no es datetime, se lanza un error descriptivo.
%
%   Salida:
%     DummyMatrix  [T x ndummies double]  columnas en el orden de Cfg.DUMMIES
%
%   Ejemplo:
%     % Dummy puntual: COVID Q1 2020
%     Cfg.DUMMIES(1).name = 'covid_q1_2020';
%     Cfg.DUMMIES(1).type = 'oneoff';
%     Cfg.DUMMIES(1).date = [2020, 3];   % marzo = fin de Q1
%
%     % Dummy de bloque: COVID 2020Q1-2021Q4
%     Cfg.DUMMIES(2).name = 'covid_block';
%     Cfg.DUMMIES(2).type = 'pulse';
%     Cfg.DUMMIES(2).date_start = [2020, 3];
%     Cfg.DUMMIES(2).date_end   = [2021, 12];
%
%     % Step: post-GFC desde 2009Q1
%     Cfg.DUMMIES(3).name = 'post_gfc';
%     Cfg.DUMMIES(3).type = 'step';
%     Cfg.DUMMIES(3).date = [2009, 3];
%
%     DummyMatrix = build_dummies(Cfg, Dataset.dates);

%% -- Validaciones basicas -----------------------------------------------
if ~isfield(Cfg, 'DUMMIES') || isempty(Cfg.DUMMIES)
    DummyMatrix = zeros(numel(dates), 0);   % [T x 0] — sin dummies
    return;
end

if ~isdatetime(dates)
    error('build_dummies:datesNotDatetime', ...
        ['Dataset.dates debe ser un array datetime para usar Cfg.DUMMIES. ' ...
         'Revise que data_bnw.xlsx tenga la columna de fecha en formato ' ...
         'DD/MM/AAAA (fecha real de Excel, no texto).']);
end

T          = numel(dates);
specs      = Cfg.DUMMIES;
ndummies   = numel(specs);
DummyMatrix = zeros(T, ndummies);

%% -- Construir cada dummy -----------------------------------------------
for k = 1:ndummies
    d = specs(k);

    if ~isfield(d, 'type') || isempty(d.type)
        error('build_dummies:missingType', ...
            'Cfg.DUMMIES(%d) no tiene campo ''type''.', k);
    end

    switch lower(d.type)

        %% -- oneoff: 1 en una fecha puntual, 0 el resto -----------------
        case 'oneoff'
            t = p_find_date(d, 'date', dates, k);
            DummyMatrix(t, k) = 1;

        %% -- pulse: 1 en rango [date_start, date_end], 0 el resto -------
        case 'pulse'
            t1 = p_find_date(d, 'date_start', dates, k);
            t2 = p_find_date(d, 'date_end',   dates, k);
            if t2 < t1
                error('build_dummies:rangeInverted', ...
                    'Cfg.DUMMIES(%d): date_end (%d/%d) es anterior a date_start (%d/%d).', ...
                    k, d.date_end(1), d.date_end(2), ...
                       d.date_start(1), d.date_start(2));
            end
            DummyMatrix(t1:t2, k) = 1;

        %% -- step: 0 antes de date, 1 desde date ------------------------
        case 'step'
            t = p_find_date(d, 'date', dates, k);
            DummyMatrix(t:end, k) = 1;

        %% -- seasonal: patron periodico ----------------------------------
        case 'seasonal'
            if ~isfield(d, 'period') || isempty(d.period)
                error('build_dummies:missingPeriod', ...
                    'Cfg.DUMMIES(%d) tipo ''seasonal'' requiere campo ''period''.', k);
            end
            period = d.period;
            phase  = 1;
            if isfield(d, 'phase') && ~isempty(d.phase)
                phase = d.phase;
            end
            for t = 1:T
                if mod(t - phase, period) == 0
                    DummyMatrix(t, k) = 1;
                end
            end

        otherwise
            error('build_dummies:unknownType', ...
                ['Cfg.DUMMIES(%d): tipo ''%s'' no reconocido. ' ...
                 'Tipos validos: oneoff, pulse, step, seasonal.'], k, d.type);
    end
end

end

%% ======================================================================
%% Funcion auxiliar privada: resolver fecha -> indice de fila
%% ======================================================================
function t_idx = p_find_date(d, field_name, dates, k)
%P_FIND_DATE  Busca [year, month] en el array datetime y devuelve el indice.

if ~isfield(d, field_name) || isempty(d.(field_name))
    error('build_dummies:missingDateField', ...
        'Cfg.DUMMIES(%d): falta el campo ''%s''.', k, field_name);
end

date_spec = d.(field_name);   % [year, month]

if numel(date_spec) ~= 2
    error('build_dummies:badDateSpec', ...
        ['Cfg.DUMMIES(%d).%s debe ser [year, month]. ' ...
         'Ejemplo: [2020, 3] para marzo 2020 (= Q1 2020).'], k, field_name);
end

yr = date_spec(1);
mo = date_spec(2);

% Buscar coincidencia en dates (datetime array)
hits = find(year(dates) == yr & month(dates) == mo);

if isempty(hits)
    error('build_dummies:dateNotFound', ...
        ['Cfg.DUMMIES(%d).%s = [%d, %d] no encontrado en Dataset.dates. ' ...
         'Rango de datos: %s a %s. ' ...
         'Recuerde usar convencion ultimo mes del periodo: Q1->3, Q2->6, Q3->9, Q4->12.'], ...
        k, field_name, yr, mo, ...
        datestr(dates(1), 'mm/yyyy'), datestr(dates(end), 'mm/yyyy'));
end

t_idx = hits(1);
end
