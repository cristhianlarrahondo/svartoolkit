function validate_cfg(Cfg, Dataset)
%VALIDATE_CFG  Valida los campos obligatorios de la struct Cfg.
%
%   VALIDATE_CFG(Cfg)
%   VALIDATE_CFG(Cfg, Dataset)
%
%   CAMBIO (Chat 19, Hallazgo 1): Dataset es un argumento OPCIONAL nuevo.
%   Si se provee, se agrega una validacion DIRECTA de que
%   numel(Cfg.S) == numel(Cfg.Z) == Dataset.nvar — es decir, que Cfg.S y
%   Cfg.Z esten dimensionados a cell(n_vars,1), sin importar cuantos
%   shocks tengan restricciones realmente declaradas. Antes de este chat,
%   esta funcion solo detectaba el error INDIRECTAMENTE (via el numero de
%   columnas esperado, inferido de numel(Cfg.S) en lugar del nvar real
%   del dataset) — lo cual SI atrapaba specs mal construidas, pero con un
%   mensaje de error menos directo. Sin Dataset, el comportamiento es
%   identico al de antes (retrocompatible).
%
%   Verifica que todos los campos requeridos estén presentes y tengan el
%   tipo y valor correcto antes de correr cualquier estimación.
%   Lanza un error descriptivo con el nombre del campo problemático.
%
%   Uso: llamada automáticamente por main.m después de cargar Cfg.
%
%   Campos obligatorios para todos los modos:
%     MODE, ND, SEED, NLAG, NEX, HORIZON, INDEX_FEVD,
%     SCALE_FACTOR, DATA_FILE, S, Z, HORIZONS_RESTRICT
%
%   Campos adicionales obligatorios para MODE='is':
%     MAX_IS_DRAWS, CONJUGATE
%
%   Validacion adicional (todos los modos): cada S{k}/Z{k} no vacio debe
%   tener numel(Cfg.HORIZONS_RESTRICT)*nvar columnas, donde nvar se infiere
%   de numel(Cfg.S). Esto detecta specs mal construidas ANTES de correr
%   run_pfa.m/run_is.m, en vez de fallar mas adelante con un error
%   criptico de algebra matricial.

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
    'Z',            'cell',    false; ...
    'HORIZONS_RESTRICT', 'double', false ...
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

%% ── Validar dimensiones de S/Z contra HORIZONS_RESTRICT ─────────────────
%  Cada S{k}/Z{k} debe tener numel(Cfg.HORIZONS_RESTRICT)*nvar columnas.
%  nvar se infiere de numel(Cfg.S) (S siempre es cell(nvar,1)).
%  Este chequeo previene el error críptico de álgebra matricial que
%  aparecía más adelante (en ZIRF/StructuralRestrictions) cuando una spec
%  construía S/Z con el número de columnas equivocado para el número de
%  horizontes declarado.
if isfield(Cfg, 'HORIZONS_RESTRICT') && ~isempty(Cfg.S)
    nvar_inferred = numel(Cfg.S);
    nH            = numel(Cfg.HORIZONS_RESTRICT);
    expected_cols = nvar_inferred * nH;

    for k = 1:nvar_inferred
        if ~isempty(Cfg.S{k}) && size(Cfg.S{k}, 2) ~= expected_cols
            error('validate_cfg:badSDims', ...
                ['[validate_cfg] Cfg.S{%d} tiene %d columnas; se esperaban %d ' ...
                 '(numel(Cfg.HORIZONS_RESTRICT)*nvar = %d*%d). Revisa que la ' ...
                 'fila se haya construido con build_restriction_row.m usando ' ...
                 'el mismo numel(HORIZONS_RESTRICT) que declara la spec.'], ...
                k, size(Cfg.S{k},2), expected_cols, nH, nvar_inferred);
        end
        if numel(Cfg.Z) >= k && ~isempty(Cfg.Z{k}) && size(Cfg.Z{k}, 2) ~= expected_cols
            error('validate_cfg:badZDims', ...
                ['[validate_cfg] Cfg.Z{%d} tiene %d columnas; se esperaban %d ' ...
                 '(numel(Cfg.HORIZONS_RESTRICT)*nvar = %d*%d).'], ...
                k, size(Cfg.Z{k},2), expected_cols, nH, nvar_inferred);
        end
    end
end

%% ── Validación DIRECTA contra Dataset.nvar (Chat 19, Hallazgo 1) ────────
%  Solo corre si el llamador provee Dataset. Es la version directa del
%  chequeo de arriba: en vez de inferir nvar de numel(Cfg.S), lo compara
%  contra el nvar REAL del dataset cargado.
if nargin >= 2 && ~isempty(Dataset) && isfield(Dataset, 'nvar')
    if numel(Cfg.S) ~= Dataset.nvar
        error('validate_cfg:sTamanoIncorrecto', ...
            ['[validate_cfg] Cfg.S tiene %d celdas, pero el dataset tiene ' ...
             '%d variables endogenas. REGLA: Cfg.S siempre debe ser ' ...
             'cell(n_vars, 1) — es decir, cell(%d, 1) — sin importar ' ...
             'cuantos shocks tengan restricciones realmente declaradas ' ...
             '(los shocks sin restriccion simplemente quedan con ' ...
             'Cfg.S{k} = []). Ver README_cfg_reference.md.'], ...
            numel(Cfg.S), Dataset.nvar, Dataset.nvar);
    end
    if numel(Cfg.Z) ~= Dataset.nvar
        error('validate_cfg:zTamanoIncorrecto', ...
            ['[validate_cfg] Cfg.Z tiene %d celdas, pero el dataset tiene ' ...
             '%d variables endogenas. REGLA: Cfg.Z siempre debe ser ' ...
             'cell(n_vars, 1) — es decir, cell(%d, 1). Ver ' ...
             'README_cfg_reference.md.'], ...
            numel(Cfg.Z), Dataset.nvar, Dataset.nvar);
    end
end

%% ── Validación opcional: Cfg.VARS vs Cfg.VAR_ROLES (Chat 19, Hallazgo 7) ─
%  Si ambos estan definidos, deben tener el mismo largo (mismo orden,
%  ver load_data.m). Es un chequeo temprano y directo — sin el, el error
%  real solo aparece dentro de load_data.m con un mensaje menos util.
if isfield(Cfg, 'VARS') && ~isempty(Cfg.VARS) && isfield(Cfg, 'VAR_ROLES') && ~isempty(Cfg.VAR_ROLES)
    if numel(Cfg.VARS) ~= numel(Cfg.VAR_ROLES)
        error('validate_cfg:varsRolesMismatch', ...
            ['[validate_cfg] Cfg.VARS tiene %d elemento(s) pero Cfg.VAR_ROLES ' ...
             'tiene %d. Deben coincidir en numero y orden (ver ' ...
             'README_cfg_reference.md, campo VARS).'], ...
            numel(Cfg.VARS), numel(Cfg.VAR_ROLES));
    end
end

%% ── Campos adicionales para MODE='is' ───────────────────────────────────
if strcmpi(Cfg.MODE, 'is')
    is_extra = {'MAX_IS_DRAWS', 'CONJUGATE'};
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



