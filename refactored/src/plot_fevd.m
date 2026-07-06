function plot_fevd(Results, Dataset, Cfg)
%PLOT_FEVD  FEVD en barras apiladas por shock, un archivo por variable.
%
%   PLOT_FEVD(Results, Dataset, Cfg)
%
%   REDISEÑO COMPLETO (Chat 19, Hallazgo 6). Antes: UNA figura con barras
%   horizontales, una por variable, mostrando la contribución de un ÚNICO
%   shock (el identificado por run_pfa/run_is) en un ÚNICO horizonte fijo
%   (Cfg.INDEX_FEVD). Ahora: UN ARCHIVO POR VARIABLE, con el horizonte en
%   el eje X y barras APILADAS donde cada segmento de color es la
%   fracción de varianza explicada por cada shock calculado (ver
%   run_pfa.m/run_is.m — Results.FEVD ahora es
%   [nvar x n_fevd_shocks x n_fevd_h x ndraws], con Results.FEVD_shock_idx
%   y Results.FEVD_horizons documentando que shocks/horizontes contiene).
%
%   CAMBIO DE FIRMA: antes PLOT_FEVD(FEVD, Dataset, Cfg) recibia solo la
%   matriz; ahora recibe el Results struct completo (mismo patron que
%   PLOT_IRFS), porque necesita Results.FEVD_shock_idx/FEVD_horizons.
%
%   Los segmentos se apilan por MEDIANA (no se grafican bandas de
%   credibilidad por segmento — combinar bandas con barras apiladas por
%   shock es ambiguo; ver README_cfg_reference.md para la nota de
%   alcance). Si la suma de los shocks calculados no llega a 1, el resto
%   se apila como "Resto (no identificado/no calculado)" en gris.
%
%   NAMING (Chat 19, Hallazgo 9, adaptado a que FEVD es POR VARIABLE, no
%   por shock — ver discusión con el usuario): 'fevd_var<K>_<VARNAME>.png',
%   con K = indice ordinal real de la variable (1..nvar).
%
%   Campos de Cfg usados:
%     RESP_IDX      vector   (default: todas las variables, según
%                   Results.FEVD)
%     SHOCK_NAMES   cell array de strings (default: 'shock1','shock2',...
%                   vía resolve_shock_name.m) — usado en la LEYENDA, no en
%                   el nombre de archivo (que es por variable, no por shock).
%     FIG_SUFFIX    string   (default '')
%     MODE          string   (default 'unknown') — solo para el subtítulo
%     OUTPUT_DIR    string   (OPCIONAL) — ver plot_irfs.m/export_results.m

%% ── Guard: corrida omitida (p.ej. PFA con >1 choque restringido) ────────
[skip_run, skip_reason] = is_run_skipped(Results);
if skip_run
    fprintf('[plot_fevd] Omitido: %s\n', skip_reason);
    return;
end

%% ── Validar entrada mínima ───────────────────────────────────────────────
if ~isfield(Results, 'FEVD') || isempty(Results.FEVD)
    error('plot_fevd:emptyInput', ...
        'plot_fevd: Results.FEVD está vacío. Ejecuta run_pfa o run_is primero.');
end
if ~isfield(Results, 'FEVD_shock_idx') || ~isfield(Results, 'FEVD_horizons')
    error('plot_fevd:missingMetadata', ...
        ['plot_fevd: Results.FEVD_shock_idx / Results.FEVD_horizons ausentes. ' ...
         '¿Vienen de una version de run_pfa.m/run_is.m anterior al Chat 19?']);
end

FEVD          = Results.FEVD;               % [nvar x n_shocks x n_h x ndraws]
fevd_shock_idx = Results.FEVD_shock_idx(:)';
fevd_horizons  = Results.FEVD_horizons(:)';
[nvar, n_shocks_calc, n_h, ndraws] = size(FEVD);

if ndraws < 2
    error('plot_fevd:tooFewDraws', ...
        'plot_fevd: FEVD necesita al menos 2 draws para calcular la mediana.');
end
if numel(fevd_shock_idx) ~= n_shocks_calc || numel(fevd_horizons) ~= n_h
    error('plot_fevd:metadataSizeMismatch', ...
        ['plot_fevd: el tamaño de Results.FEVD_shock_idx/FEVD_horizons no ' ...
         'coincide con las dimensiones de Results.FEVD.']);
end

%% ── Defaults de Cfg ──────────────────────────────────────────────────────
fig_suffix = '';
if isfield(Cfg, 'FIG_SUFFIX') && ~isempty(Cfg.FIG_SUFFIX)
    fig_suffix = Cfg.FIG_SUFFIX;
end

mode_str = 'unknown';
if isfield(Cfg, 'MODE') && ~isempty(Cfg.MODE)
    mode_str = lower(Cfg.MODE);
end

shock_names = {};
if isfield(Cfg, 'SHOCK_NAMES') && ~isempty(Cfg.SHOCK_NAMES)
    shock_names = Cfg.SHOCK_NAMES;
end

response_idx = 1:nvar;
if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
    ri = Cfg.RESP_IDX;
    response_idx = ri(ri >= 1 & ri <= nvar);
end
nresp = numel(response_idx);

%% ── Labels de variables endógenas ────────────────────────────────────────
endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
all_labels = Dataset.var_labels(endo_mask);

label_resp = cell(1, nresp);
for kk = 1:nresp
    idx = response_idx(kk);
    if idx <= numel(all_labels)
        label_resp{kk} = all_labels{idx};
    else
        label_resp{kk} = sprintf('Var %d', idx);
    end
end

%% ── Labels de shocks (para la leyenda) ───────────────────────────────────
label_shock = cell(1, n_shocks_calc);
for jj = 1:n_shocks_calc
    label_shock{jj} = resolve_shock_name(shock_names, fevd_shock_idx(jj));
end

%% ── Paths de salida ──────────────────────────────────────────────────────
if isfield(Cfg, 'OUTPUT_DIR') && ~isempty(Cfg.OUTPUT_DIR)
    fig_dir = fullfile(Cfg.OUTPUT_DIR, 'figures');
else
    src_root  = fileparts(mfilename('fullpath'));
    proj_root = fileparts(src_root);
    fig_dir   = fullfile(proj_root, 'output', 'figures');
end
if ~isfolder(fig_dir), mkdir(fig_dir); end

%% ── Parámetros visuales ─────────────────────────────────────────────────
fontsize_title = 9;
fontsize_axes  = 8;
axiswidth      = 1;
color_rest     = [0.80 0.80 0.80];   % gris — "resto no identificado"
shock_colors   = lines(max(n_shocks_calc, 1));   % paleta MATLAB estandar

%% ── Una figura por variable de respuesta ────────────────────────────────
for kk = 1:nresp
    v_idx = response_idx(kk);

    % Medianas [n_h x n_shocks_calc]
    med_mat = zeros(n_h, n_shocks_calc);
    for jj = 1:n_shocks_calc
        for hh_i = 1:n_h
            sl = FEVD(v_idx, jj, hh_i, :);
            med_mat(hh_i, jj) = quantile(sl(:), 0.50);
        end
    end
    rest_vec = max(1 - sum(med_mat, 2), 0);   % complemento a 1, nunca negativo

    hFig = figure('Name', sprintf('FEVD - %s', label_resp{kk}), 'NumberTitle', 'off');
    set(hFig, 'Position', [50 50 560 340]);
    ax = axes('Parent', hFig);

    bar_data = [med_mat, rest_vec];
    hbars = bar(ax, fevd_horizons, bar_data, 'stacked', 'EdgeColor', 'none');
    for jj = 1:n_shocks_calc
        hbars(jj).FaceColor = shock_colors(jj, :);
    end
    hbars(end).FaceColor = color_rest;

    xlabel(ax, 'Horizonte', 'FontSize', fontsize_axes);
    ylabel(ax, 'Fracción de varianza explicada', 'FontSize', fontsize_axes);
    set(ax, 'YLim', [0 1]);
    set(ax, 'FontSize', fontsize_axes);
    set(ax, 'LineWidth', axiswidth);
    grid(ax, 'on'); box(ax, 'off');
    set(ax, 'GridAlpha', 0.15);

    title_str    = sprintf('FEVD — %s', label_resp{kk});
    subtitle_str = sprintf('Modo: %s', upper(mode_str));
    title(ax, {title_str; subtitle_str}, 'FontSize', fontsize_title, 'Interpreter', 'none');

    legend(ax, [label_shock, {'Resto (no identificado)'}], ...
        'Location', 'eastoutside', 'FontSize', fontsize_axes - 1, 'Box', 'off');

    set(hFig, 'PaperPositionMode', 'auto');

    % NAMING (Chat 19, Hallazgo 9, adaptado a FEVD por variable — ver
    % docstring): fevd_var<K>_<VARNAME>.png
    var_name_safe = regexprep(label_resp{kk}, '[^a-zA-Z0-9_]', '_');
    fname = fullfile(fig_dir, sprintf('fevd_var%d_%s%s.png', v_idx, var_name_safe, fig_suffix));
    print(fname, '-dpng', '-r150');
    fprintf('Figura FEVD (variable %d: %s) guardada en: %s\n', v_idx, label_resp{kk}, fname);
end

end
