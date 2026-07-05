function print_restriction_matrix(Cfg, Dataset)
%PRINT_RESTRICTION_MATRIX  Imprime la matriz de restricciones declarada
%en Cfg.S/Cfg.Z como una tabla variables (filas) x shocks (columnas).
%
%   PRINT_RESTRICTION_MATRIX(Cfg, Dataset)
%   PRINT_RESTRICTION_MATRIX(Cfg)   % sin Dataset: usa var_1, var_2, ...
%
%   Contexto (Chat 19, Hallazgo 2): pipeline_template.m Seccion 2 ya
%   traduce Cfg.S/Cfg.Z a lenguaje natural fila por fila, pero no hay una
%   vista de conjunto que permita verificar de un vistazo que la matriz
%   de restricciones coincide con lo que el usuario CREE haber declarado.
%   Esta funcion llena ese vacio con una tabla compacta.
%
%   IMPORTANTE (recordatorio del Hallazgo 1): el numero de COLUMNAS de
%   esta tabla es SIEMPRE numel(Cfg.S) = n_vars, sin importar cuantos
%   shocks tengan restricciones realmente declaradas (los demas se ven
%   con todas sus celdas en '.' — es lo esperado, no un error).
%
%   Si Cfg.HORIZONS_RESTRICT tiene mas de un elemento, se imprime una
%   tabla POR CADA horizonte declarado (una restriccion puede tener signo
%   distinto en distintos horizontes).
%
%   Simbologia:
%     '+'  restriccion de signo POSITIVO (Cfg.S)
%     '-'  restriccion de signo NEGATIVO (Cfg.S)
%     '0'  restriccion de CERO (Cfg.Z)
%     '.'  sin restriccion declarada
%     '!'  CONFLICTO: hay restriccion de signo Y de cero en la misma
%          celda (var, shock, horizonte) — esto no deberia ocurrir; revisa
%          la spec.
%
%   Entradas:
%     Cfg       struct de config/spec_*.m. Requiere Cfg.S, Cfg.Z,
%               Cfg.HORIZONS_RESTRICT.
%     Dataset   (opcional) struct de load_data.m. Si se provee, usa
%               Dataset.var_names(endo_mask) para las etiquetas de fila.
%               Si no se provee, usa 'var_1', 'var_2', ...
%
%   Ver tambien: parse_restriction_row.m, build_restriction_row.m

%% ── Validar entradas minimas ─────────────────────────────────────────────
if ~isfield(Cfg, 'S') || ~isfield(Cfg, 'Z') || ~isfield(Cfg, 'HORIZONS_RESTRICT')
    error('print_restriction_matrix:missingFields', ...
        'print_restriction_matrix: Cfg debe tener los campos S, Z y HORIZONS_RESTRICT.');
end

n_vars     = numel(Cfg.S);
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

if numel(Cfg.Z) ~= n_vars
    error('print_restriction_matrix:sizeMismatch', ...
        ['print_restriction_matrix: numel(Cfg.Z)=%d no coincide con ' ...
         'numel(Cfg.S)=%d. Ambos deben ser cell(n_vars,1) — ver Hallazgo 1 ' ...
         'del Chat 19 / README_cfg_reference.md.'], numel(Cfg.Z), n_vars);
end

%% ── Nombres de variables (filas) ─────────────────────────────────────────
if nargin >= 2 && ~isempty(Dataset) && isfield(Dataset, 'var_names') && isfield(Dataset, 'var_roles')
    endo_mask = strcmp(Dataset.var_roles, 'endogenous');
    vnames    = Dataset.var_names(endo_mask);
    if numel(vnames) ~= n_vars
        warning('print_restriction_matrix:datasetMismatch', ...
            ['numel(Dataset variables endogenas)=%d no coincide con ' ...
             'numel(Cfg.S)=%d. Usando etiquetas var_1..var_%d en su lugar.'], ...
            numel(vnames), n_vars, n_vars);
        vnames = arrayfun(@(i) sprintf('var_%d', i), 1:n_vars, 'UniformOutput', false);
    end
else
    vnames = arrayfun(@(i) sprintf('var_%d', i), 1:n_vars, 'UniformOutput', false);
end

%% ── Construir y mostrar una tabla por horizonte declarado ────────────────
any_conflict = false;

for h_idx = 1:n_horizons
    h_val = Cfg.HORIZONS_RESTRICT(h_idx);

    M = repmat('.', n_vars, n_vars);   % filas=variables, columnas=shocks

    for k = 1:n_vars   % k = shock
        % Restricciones de signo (Cfg.S{k})
        Sk = Cfg.S{k};
        for r = 1:size(Sk, 1)
            [vi, hi, sv] = parse_restriction_row(Sk(r,:), n_vars);
            if hi ~= h_idx, continue; end
            if M(vi, k) ~= '.'
                M(vi, k) = '!';
                any_conflict = true;
            else
                if sv > 0, M(vi, k) = '+'; else, M(vi, k) = '-'; end
            end
        end

        % Restricciones de cero (Cfg.Z{k})
        Zk = Cfg.Z{k};
        for r = 1:size(Zk, 1)
            [vi, hi, ~] = parse_restriction_row(Zk(r,:), n_vars);
            if hi ~= h_idx, continue; end
            if M(vi, k) ~= '.'
                M(vi, k) = '!';
                any_conflict = true;
            else
                M(vi, k) = '0';
            end
        end
    end

    %% ── Imprimir tabla ────────────────────────────────────────────────────
    fprintf('\n  Matriz de restricciones — h = %d  (variables x shocks, %dx%d)\n', ...
        h_val, n_vars, n_vars);

    name_w = max(cellfun(@length, vnames)) + 2;
    name_w = max(name_w, 10);

    % Encabezado
    fprintf('  %-*s', name_w, '');
    for k = 1:n_vars
        fprintf('  S%-3d', k);
    end
    fprintf('\n');
    fprintf('  %s\n', repmat('-', 1, name_w + 5*n_vars));

    % Filas
    for i = 1:n_vars
        fprintf('  %-*s', name_w, vnames{i});
        for k = 1:n_vars
            fprintf('   %s ', M(i,k));
        end
        fprintf('\n');
    end
end

fprintf('\n  [ + positivo | - negativo | 0 restringido a cero | . sin restriccion ]\n');
if any_conflict
    fprintf(['  [ADVERTENCIA] Se encontraron celdas marcadas con ''!'': hay ' ...
        'restriccion de signo Y de cero para la misma (variable, shock, ' ...
        'horizonte). Revisa la spec — esto normalmente indica un error.\n']);
end
fprintf('\n');

end
