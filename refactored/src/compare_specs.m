function compare_specs(Results_all, spec_names, Dataset, Cfg)
%COMPARE_SPECS  Tabla de medianas de FEVD entre múltiples specs.
%
%   COMPARE_SPECS(Results_all, spec_names, Dataset, Cfg)
%
%   Compara la mediana del FEVD (al horizonte Cfg.INDEX_FEVD) entre
%   todas las specs del mismo modo. Imprime la tabla en consola.
%   Llamada automáticamente por main_batch si hay ≥2 specs del mismo modo.
%
%   Entrada:
%     Results_all   cell array {N×1} de structs Results
%     spec_names    cell array {N×1} de nombres de spec (strings)
%     Dataset       struct de load_data.m (para var_labels y var_roles)
%     Cfg           struct de configuración base

%% ── Validar entradas ─────────────────────────────────────────────────────
if ~iscell(Results_all) || isempty(Results_all)
    error('compare_specs:emptyInput', ...
        'compare_specs: Results_all debe ser un cell array no vacío.');
end

n_specs = numel(Results_all);

if ~iscell(spec_names) || numel(spec_names) ~= n_specs
    % Generar nombres genéricos si no se proveen
    spec_names = arrayfun(@(k) sprintf('spec_%d', k), 1:n_specs, 'UniformOutput', false);
end

%% ── Labels de variables ──────────────────────────────────────────────────
endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
all_labels = Dataset.var_labels(endo_mask);
n          = numel(all_labels);

%% ── Agrupar specs por modo ───────────────────────────────────────────────
modes_all = cell(n_specs, 1);
for k = 1:n_specs
    if isfield(Results_all{k}, 'LtildeStruct')
        modes_all{k} = Results_all{k}.LtildeStruct.mode;
    else
        modes_all{k} = 'unknown';
    end
end

unique_modes = unique(modes_all);

%% ── Para cada modo con ≥2 specs, imprimir tabla de FEVD ─────────────────
for mm = 1:numel(unique_modes)
    mode_m   = unique_modes{mm};
    idx_mode = find(strcmp(modes_all, mode_m));

    if numel(idx_mode) < 2
        continue;   % Necesitamos ≥2 specs del mismo modo
    end

    sep_wide = repmat('═', 1, 70);
    sep_thin = repmat('─', 1, 70);

    fprintf('\n%s\n', sep_wide);
    fprintf('  COMPARE_SPECS — FEVD medianas  [modo: %s]\n', upper(mode_m));
    fprintf('%s\n', sep_wide);

    % Encabezado con nombres de specs
    hdr = sprintf('  %-22s', 'Variable');
    for kk = idx_mode'
        sname = spec_names{kk};
        if numel(sname) > 12, sname = sname(end-11:end); end
        hdr = [hdr, sprintf('  %12s', sname)]; %#ok<AGROW>
    end
    fprintf('%s\n', hdr);
    fprintf('%s\n', sep_thin);

    % Fila por variable
    for jj = 1:n
        row_str = sprintf('  %-22s', all_labels{jj});
        for kk = idx_mode'
            R_k  = Results_all{kk};
            fevd = R_k.FEVD;   % [n x ndraws]
            if size(fevd, 1) >= jj && ~isempty(fevd)
                med_val = median(fevd(jj, :));
                row_str = [row_str, sprintf('  %12.4f', med_val)]; %#ok<AGROW>
            else
                row_str = [row_str, sprintf('  %12s', 'N/A')]; %#ok<AGROW>
            end
        end
        fprintf('%s\n', row_str);
    end

    fprintf('%s\n\n', sep_thin);
end

end
