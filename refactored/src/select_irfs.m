function [irfs, labels_shock, labels_response] = select_irfs(LtildeStruct, shock_idx, response_idx)
%SELECT_IRFS  Extrae un subconjunto shock-response de LtildeStruct.
%
%   [irfs, labels_shock, labels_response] = ...
%       SELECT_IRFS(LtildeStruct, shock_idx, response_idx)
%
%   Devuelve el array de IRFs filtrado por shocks y variables de respuesta,
%   junto con los labels correspondientes extraídos de Dataset (que el
%   llamador debe haber adjuntado a LtildeStruct.var_labels, o se usan
%   índices si no están disponibles).
%
%   Entradas:
%     LtildeStruct  struct canónica de pack_ltilde.m, enriquecida con:
%                     .var_labels  {1 x nvar} cell de strings (opcional)
%     shock_idx     escalar — índice del shock de interés (columna j en Q)
%     response_idx  vector — índices de las variables de respuesta
%
%   Salidas:
%     irfs             [horizon+1  x  numel(response_idx)  x  ndraws]
%     labels_shock     string — label del shock seleccionado
%     labels_response  {1 x numel(response_idx)} — labels de respuestas
%
%   Notas:
%     - PFA:  LtildeStruct.data es [horizon+1, nvar, nd]
%             shock_idx selecciona LtildeStruct.shock_idx (fijo por run)
%             El array resultante contiene las columnas response_idx.
%     - IS:   LtildeStruct.data es [horizon+1, nvar, nvar, ne]
%             shock_idx selecciona la 3ra dimensión (columna de B).
%     - Para PFA, shock_idx debe coincidir con LtildeStruct.shock_idx;
%       se lanza advertencia si difieren.

%% ── Validación de entradas ───────────────────────────────────────────────
if nargin < 3 || isempty(response_idx)
    response_idx = 1:LtildeStruct.nvar;
end
if nargin < 2 || isempty(shock_idx)
    shock_idx = LtildeStruct.shock_idx;
end

nvar    = LtildeStruct.nvar;
horizon = LtildeStruct.horizon;

% Verificar límites
if any(response_idx < 1) || any(response_idx > nvar)
    error('select_irfs:outOfRange', ...
        'response_idx contiene índices fuera de rango [1, %d].', nvar);
end
if shock_idx < 1 || shock_idx > nvar
    error('select_irfs:outOfRange', ...
        'shock_idx = %d está fuera de rango [1, %d].', shock_idx, nvar);
end

%% ── Extraer draws según modo ─────────────────────────────────────────────
switch LtildeStruct.mode
    case 'pfa'
        % data: [horizon+1, nvar, nd]
        if shock_idx ~= LtildeStruct.shock_idx
            warning('select_irfs:shockMismatch', ...
                ['PFA: el shock_idx solicitado (%d) difiere del shock ', ...
                 'estimado (%d). Se devuelven IRFs del shock estimado.'], ...
                shock_idx, LtildeStruct.shock_idx);
        end
        % Seleccionar variables de respuesta: dim 2
        irfs = LtildeStruct.data(:, response_idx, :);
        % Resultado: [horizon+1, numel(response_idx), nd]

    case 'is'
        % data: [horizon+1, nvar, nvar, ne]  (dim3 = shock)
        shock_slice = squeeze(LtildeStruct.data(:, :, shock_idx, :));
        % shock_slice: [horizon+1, nvar, ne]
        irfs = shock_slice(:, response_idx, :);
        % Resultado: [horizon+1, numel(response_idx), ne]

    otherwise
        error('select_irfs:unknownMode', ...
            'Modo desconocido en LtildeStruct.mode: ''%s''.', LtildeStruct.mode);
end

%% ── Labels ───────────────────────────────────────────────────────────────
if isfield(LtildeStruct, 'var_labels') && ~isempty(LtildeStruct.var_labels)
    all_labels      = LtildeStruct.var_labels;
    labels_shock    = all_labels{min(shock_idx, numel(all_labels))};
    labels_response = all_labels(response_idx(response_idx <= numel(all_labels)));
    % Si response_idx tiene más elementos de los que hay en var_labels, rellenar
    if numel(labels_response) < numel(response_idx)
        for k = numel(labels_response)+1:numel(response_idx)
            labels_response{k} = sprintf('Var %d', response_idx(k));
        end
    end
else
    % Fallback: labels numéricos
    labels_shock    = sprintf('Shock %d', shock_idx);
    labels_response = arrayfun(@(i) sprintf('Var %d', i), response_idx, ...
                               'UniformOutput', false);
end

end
