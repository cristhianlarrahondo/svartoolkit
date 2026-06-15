function validate_cfg(Cfg)
%VALIDATE_CFG  Valida los campos obligatorios de la struct Cfg.
%
%   VALIDATE_CFG(Cfg)
%
%   Verifica que todos los campos requeridos estén presentes y tengan el
%   tipo y valor correcto antes de correr cualquier estimación.
%   Lanza un error descriptivo con el nombre del campo problemático.
%
%   Uso: llamada automáticamente por main.m después de cargar Cfg.
%
%   Campos obligatorios para todos los modos:
%     MODE, ND, SEED, NLAG, NEX, HORIZON, INDEX_FEVD,
%     SCALE_FACTOR, DATA_FILE, S, Z
%
%   Campos adicionales obligatorios para MODE='is':
%     MAX_IS_DRAWS, CONJUGATE, HORIZONS_RESTRICT

%% ── Campos universales (nombre, tipo, escalar?) ──────────────────────────
%  Columnas: { nombre_campo, tipo, debe_ser_escalar }
required_fields = { ...
    'MODE',         'char',    false; ...
    'ND',           'double',  true;  ...
    'SEED',         'double',  true;  ...
    'NLAG',         'double',  true;  ...
    'NEX',          'double',  true;  ...
    'HORIZON',      'double',  true;  ...
    'INDEX_FEVD',   'double',  true;  ...
    'SCALE_FACTOR', 'double',  true;  ...
    'DATA_FILE',    'char',    false; ...
    'S',            'cell',    false; ...
    'Z',            'cell',    false  ...
};

for k = 1:size(required_fields, 1)
    fname     = required_fields{k, 1};
    ftype     = required_fields{k, 2};
    is_scalar = required_fields{k, 3};

    %% Verificar presencia
    if ~isfield(Cfg, fname)
        error('validate_cfg:missingField', ...
            '[validate_cfg] Campo obligatorio ausente: Cfg.%s', fname);
    end

    val = Cfg.(fname);

    %% Verificar tipo
    switch ftype
        case 'char'
            if ~ischar(val) && ~isstring(val)
                error('validate_cfg:wrongType', ...
                    '[validate_cfg] Cfg.%s debe ser char/string (recibido: %s)', ...
                    fname, class(val));
            end
        case 'double'
            if ~isnumeric(val)
                error('validate_cfg:wrongType', ...
                    '[validate_cfg] Cfg.%s debe ser numérico (recibido: %s)', ...
                    fname, class(val));
            end
            if is_scalar && ~isscalar(val)
                error('validate_cfg:wrongSize', ...
                    '[validate_cfg] Cfg.%s debe ser escalar (recibido tamaño [%s])', ...
                    fname, num2str(size(val)));
            end
        case 'cell'
            if ~iscell(val)
                error('validate_cfg:wrongType', ...
                    '[validate_cfg] Cfg.%s debe ser cell array (recibido: %s)', ...
                    fname, class(val));
            end
    end
end

%% ── Validar MODE ─────────────────────────────────────────────────────────
valid_modes = {'pfa', 'is', 'timing'};
if ~ismember(lower(Cfg.MODE), valid_modes)
    error('validate_cfg:invalidMode', ...
        '[validate_cfg] Cfg.MODE = ''%s'' no es válido. Opciones: ''pfa'', ''is'', ''timing''.', ...
        Cfg.MODE);
end

%% ── Validar valores numéricos coherentes ─────────────────────────────────
if Cfg.ND <= 0
    error('validate_cfg:invalidValue', ...
        '[validate_cfg] Cfg.ND debe ser positivo (recibido: %g)', Cfg.ND);
end
if Cfg.NLAG <= 0
    error('validate_cfg:invalidValue', ...
        '[validate_cfg] Cfg.NLAG debe ser positivo (recibido: %g)', Cfg.NLAG);
end
if Cfg.NEX < 0
    error('validate_cfg:invalidValue', ...
        '[validate_cfg] Cfg.NEX debe ser >= 0 (recibido: %g)', Cfg.NEX);
end
if Cfg.HORIZON <= 0
    error('validate_cfg:invalidValue', ...
        '[validate_cfg] Cfg.HORIZON debe ser positivo (recibido: %g)', Cfg.HORIZON);
end
if Cfg.SCALE_FACTOR <= 0
    error('validate_cfg:invalidValue', ...
        '[validate_cfg] Cfg.SCALE_FACTOR debe ser positivo (recibido: %g)', Cfg.SCALE_FACTOR);
end

%% ── Campos adicionales para MODE='is' ───────────────────────────────────
if strcmpi(Cfg.MODE, 'is')
    is_extra = {'MAX_IS_DRAWS', 'CONJUGATE', 'HORIZONS_RESTRICT'};
    for k = 1:numel(is_extra)
        fname = is_extra{k};
        if ~isfield(Cfg, fname)
            error('validate_cfg:missingField', ...
                '[validate_cfg] Campo obligatorio para MODE=''is'' ausente: Cfg.%s', fname);
        end
    end
    if ~isnumeric(Cfg.MAX_IS_DRAWS) || ~isscalar(Cfg.MAX_IS_DRAWS) || Cfg.MAX_IS_DRAWS <= 0
        error('validate_cfg:invalidValue', ...
            '[validate_cfg] Cfg.MAX_IS_DRAWS debe ser un escalar positivo');
    end
    valid_conj = {'structural', 'irfs'};
    if ~ismember(lower(Cfg.CONJUGATE), valid_conj)
        error('validate_cfg:invalidValue', ...
            '[validate_cfg] Cfg.CONJUGATE = ''%s'' no es válido. Opciones: ''structural'', ''irfs''.', ...
            Cfg.CONJUGATE);
    end
end

%% ── Resultado ────────────────────────────────────────────────────────────
fprintf('[validate_cfg] OK — Cfg válida: MODE=''%s'', ND=%g, NLAG=%d, HORIZON=%d\n', ...
    Cfg.MODE, Cfg.ND, Cfg.NLAG, Cfg.HORIZON);

end
