function validate_cfg(Cfg)
%VALIDATE_CFG  Valida los campos obligatorios de la struct Cfg.
%
%   VALIDATE_CFG(Cfg)
%
%   Verifica que todos los campos requeridos estén presentes y tengan el
%   tipo correcto antes de correr cualquier estimación.
%   Lanza un error descriptivo con el nombre del campo problemático.
%
%   Uso recomendado: llamar al principio de main.m, después de cargar Cfg
%   y antes de cargar datos.
%
%   Campos obligatorios para todos los modos:
%     MODE, ND, SEED, NLAGS, NEX, HORIZON, INDEX_FEVD,
%     DATA_PATH, DATA_FILE, SHEET_DATA, SHEET_INFO, SCALE,
%     ENDOG_VARS, SIGN_RESTRICTIONS, ZERO_RESTRICTIONS
%
%   Campos adicionales obligatorios para MODE='is':
%     MAX_IS_DRAWS

%% ── Campos universales ───────────────────────────────────────────────────
required_fields = { ...
    'MODE',               'char',   []; ...
    'ND',                 'double', [1 1]; ...
    'SEED',               'double', [1 1]; ...
    'NLAGS',              'double', [1 1]; ...
    'NEX',                'double', [1 1]; ...
    'HORIZON',            'double', [1 1]; ...
    'INDEX_FEVD',         'double', []; ...
    'DATA_PATH',          'char',   []; ...
    'DATA_FILE',          'char',   []; ...
    'SHEET_DATA',         'char',   []; ...
    'SHEET_INFO',         'char',   []; ...
    'SCALE',              'double', []; ...
    'ENDOG_VARS',         'cell',   []; ...
    'SIGN_RESTRICTIONS',  'cell',   []; ...
    'ZERO_RESTRICTIONS',  'cell',   [] ...
};

for k = 1:size(required_fields, 1)
    fname = required_fields{k, 1};
    ftype = required_fields{k, 2};
    fsize = required_fields{k, 3};

    % Verificar presencia
    if ~isfield(Cfg, fname)
        error('validate_cfg:missingField', ...
            '[validate_cfg] Campo obligatorio ausente: Cfg.%s', fname);
    end

    val = Cfg.(fname);

    % Verificar que no sea vacío (salvo casos permitidos)
    campos_vacios_ok = {'ZERO_RESTRICTIONS', 'SIGN_RESTRICTIONS', ...
                        'DATA_FILE', 'DATA_PATH'};
    if isempty(val) && ~ismember(fname, campos_vacios_ok)
        error('validate_cfg:emptyField', ...
            '[validate_cfg] Campo vacío: Cfg.%s (se esperaba un valor)', fname);
    end

    % Verificar tipo
    switch ftype
        case 'char'
            if ~ischar(val) && ~isstring(val)
                error('validate_cfg:wrongType', ...
                    '[validate_cfg] Cfg.%s debe ser de tipo char/string (recibido: %s)', ...
                    fname, class(val));
            end
        case 'double'
            if ~isnumeric(val)
                error('validate_cfg:wrongType', ...
                    '[validate_cfg] Cfg.%s debe ser numérico (recibido: %s)', ...
                    fname, class(val));
            end
            % Verificar tamaño si se especificó
            if ~isempty(fsize) && ~isequal(size(val), fsize)
                error('validate_cfg:wrongSize', ...
                    '[validate_cfg] Cfg.%s debe ser escalar [%s] (recibido: [%s])', ...
                    fname, num2str(fsize), num2str(size(val)));
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
        '[validate_cfg] Cfg.MODE = ''%s'' no es válido. Usar: ''pfa'', ''is'' o ''timing''.', ...
        Cfg.MODE);
end

%% ── Campos adicionales para MODE='is' ───────────────────────────────────
if strcmpi(Cfg.MODE, 'is')
    if ~isfield(Cfg, 'MAX_IS_DRAWS')
        error('validate_cfg:missingField', ...
            '[validate_cfg] Campo obligatorio para MODE=''is'' ausente: Cfg.MAX_IS_DRAWS');
    end
    if ~isnumeric(Cfg.MAX_IS_DRAWS) || ~isscalar(Cfg.MAX_IS_DRAWS)
        error('validate_cfg:wrongType', ...
            '[validate_cfg] Cfg.MAX_IS_DRAWS debe ser un escalar numérico');
    end
    if Cfg.MAX_IS_DRAWS <= 0
        error('validate_cfg:invalidValue', ...
            '[validate_cfg] Cfg.MAX_IS_DRAWS debe ser positivo (recibido: %g)', ...
            Cfg.MAX_IS_DRAWS);
    end
end

%% ── Validar valores coherentes ───────────────────────────────────────────
if Cfg.ND <= 0
    error('validate_cfg:invalidValue', ...
        '[validate_cfg] Cfg.ND debe ser positivo (recibido: %g)', Cfg.ND);
end
if Cfg.NLAGS <= 0
    error('validate_cfg:invalidValue', ...
        '[validate_cfg] Cfg.NLAGS debe ser positivo (recibido: %g)', Cfg.NLAGS);
end
if Cfg.NEX < 0
    error('validate_cfg:invalidValue', ...
        '[validate_cfg] Cfg.NEX debe ser >= 0 (recibido: %g)', Cfg.NEX);
end
if Cfg.HORIZON <= 0
    error('validate_cfg:invalidValue', ...
        '[validate_cfg] Cfg.HORIZON debe ser positivo (recibido: %g)', Cfg.HORIZON);
end

%% ── Resultado ────────────────────────────────────────────────────────────
fprintf('[validate_cfg] OK — Cfg válida para MODE=''%s'', ND=%g, NLAGS=%d, HORIZON=%d\n', ...
    Cfg.MODE, Cfg.ND, Cfg.NLAGS, Cfg.HORIZON);

end
