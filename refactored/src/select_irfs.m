function [irfs_by_shock, labels_shock, labels_response, shock_idx] = select_irfs(LtildeStruct, shock_idx, response_idx)
%SELECT_IRFS  Extrae uno o varios subconjuntos shock-response de LtildeStruct.
%
%   [irfs_by_shock, labels_shock, labels_response, shock_idx] = ...
%       SELECT_IRFS(LtildeStruct, shock_idx, response_idx)
%
%   CAMBIO (Chat 19, Hallazgo 4): shock_idx ahora acepta escalar, vector,
%   o el string 'all' (todos los shocks identificados: 1:nvar). Antes
%   solo aceptaba escalar, lo que causaba un error de MATLAB
%   ("Operands to the || and && operators must be convertible to logical
%   scalar values") si se pasaba un vector — el sintoma reportado era que
%   plot_irfs.m/export_results.m/print_summary.m fallaban (o no producian
%   ningun archivo) al intentar graficar/exportar mas de un shock.
%
%   CAMBIO DE CONTRATO: la salida ya NO es un unico array 3D — es un cell
%   array con un elemento POR CADA shock solicitado (aunque solo se pida
%   uno). Esto generaliza limpiamente a 1..N shocks sin casos especiales.
%   Los llamadores (plot_irfs.m, export_results.m, print_summary.m) ya
%   fueron actualizados para iterar sobre este cell array.
%
%   Entradas:
%     LtildeStruct  struct canonica de pack_ltilde.m, enriquecida con:
%                     .var_labels  {1 x nvar} cell de strings (opcional)
%     shock_idx     escalar | vector | 'all' (default: LtildeStruct.shock_idx)
%     response_idx  vector — indices de las variables de respuesta
%                   (default: todas)
%
%   Salidas:
%     irfs_by_shock     {1 x numel(shock_idx)} cell array. Cada celda:
%                       [horizon+1  x  numel(response_idx)  x  ndraws]
%     labels_shock      {1 x numel(shock_idx)} cell array de strings
%     labels_response   {1 x numel(response_idx)} — labels de respuestas
%                       (las mismas para todos los shocks)
%     shock_idx         vector resuelto realmente usado (util cuando la
%                       entrada fue 'all' o quedo vacia)
%
%   Notas:
%     - PFA:  LtildeStruct.data es [horizon+1, nvar, nd]. PFA solo estima
%             UN shock por corrida (LtildeStruct.shock_idx); si se pide
%             un shock_idx distinto, se emite advertencia y se devuelven
%             las IRFs del shock realmente estimado (comportamiento igual
%             al de antes, ahora aplicado elemento por elemento).
%     - IS:   LtildeStruct.data es [horizon+1, nvar, nvar, ne].
%             shock_idx selecciona la 3ra dimension (columna de B) — con
%             IS SI se puede pedir varios shocks reales en una lista.

%% ── Validación de entradas ───────────────────────────────────────────────
nvar    = LtildeStruct.nvar;
horizon = LtildeStruct.horizon;

if nargin < 3 || isempty(response_idx)
    response_idx = 1:nvar;
end
if any(response_idx < 1) || any(response_idx > nvar)
    error('select_irfs:outOfRange', ...
        'response_idx contiene índices fuera de rango [1, %d].', nvar);
end

if nargin < 2 || isempty(shock_idx)
    shock_idx = LtildeStruct.shock_idx;
end

% Resolver 'all' -> 1:nvar
if (ischar(shock_idx) || isstring(shock_idx)) && strcmpi(shock_idx, 'all')
    shock_idx = 1:nvar;
end

if ~isnumeric(shock_idx) || isempty(shock_idx)
    error('select_irfs:badShockIdx', ...
        ['shock_idx debe ser un escalar, un vector numerico, o el string ' ...
         '''all''. Recibido: %s.'], class(shock_idx));
end
shock_idx = shock_idx(:)';   % forzar fila

if any(shock_idx < 1) || any(shock_idx > nvar)
    error('select_irfs:outOfRange', ...
        'shock_idx contiene indices fuera de rango [1, %d].', nvar);
end

%% ── Labels de respuesta (no dependen del shock) ──────────────────────────
if isfield(LtildeStruct, 'var_labels') && ~isempty(LtildeStruct.var_labels)
    all_labels      = LtildeStruct.var_labels;
    labels_response = all_labels(response_idx(response_idx <= numel(all_labels)));
    if numel(labels_response) < numel(response_idx)
        for k = numel(labels_response)+1:numel(response_idx)
            labels_response{k} = sprintf('Var %d', response_idx(k));
        end
    end
    has_labels = true;
else
    all_labels      = {};
    labels_response = arrayfun(@(i) sprintf('Var %d', i), response_idx, ...
                               'UniformOutput', false);
    has_labels = false;
end

%% ── Extraer draws por shock, segun modo ──────────────────────────────────
n_shocks       = numel(shock_idx);
irfs_by_shock  = cell(1, n_shocks);
labels_shock   = cell(1, n_shocks);

for j = 1:n_shocks
    sidx = shock_idx(j);

    switch LtildeStruct.mode
        case 'pfa'
            % data: [horizon+1, nvar, nd] — un unico shock estimado
            if sidx ~= LtildeStruct.shock_idx
                warning('select_irfs:shockMismatch', ...
                    ['PFA: el shock_idx solicitado (%d) difiere del shock ', ...
                     'estimado (%d). Se devuelven IRFs del shock estimado.'], ...
                    sidx, LtildeStruct.shock_idx);
            end
            irfs_by_shock{j} = LtildeStruct.data(:, response_idx, :);

        case 'is'
            % data: [horizon+1, nvar, nvar, ne]  (dim3 = shock)
            shock_slice = squeeze(LtildeStruct.data(:, :, sidx, :));
            irfs_by_shock{j} = shock_slice(:, response_idx, :);

        otherwise
            error('select_irfs:unknownMode', ...
                'Modo desconocido en LtildeStruct.mode: ''%s''.', LtildeStruct.mode);
    end

    if has_labels
        labels_shock{j} = all_labels{min(sidx, numel(all_labels))};
    else
        labels_shock{j} = sprintf('Shock %d', sidx);
    end
end

end
