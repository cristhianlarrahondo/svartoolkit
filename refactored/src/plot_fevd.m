function plot_fevd(FEVD, Dataset, Cfg)
%PLOT_FEVD  Grafica la contribución del shock identificado a la FEVD.
%
%   PLOT_FEVD(FEVD, Dataset, Cfg)
%
%   Muestra, para cada variable endógena, la fracción de la varianza del
%   error de pronóstico (al horizonte Cfg.INDEX_FEVD) explicada por el
%   shock identificado. La barra apilada divide cada variable en:
%     - Fracción del shock identificado (mediana, con banda de credibilidad)
%     - Resto no explicado (complemento a 1)
%
%   FEVD: [nvar x ndraws] — salida de Results.FEVD (campo de run_pfa/run_is)
%         Cada columna es la fracción explicada por el shock en cada variable.
%
%   Campos de Cfg usados:
%     CRED_BANDS    [N x 2]  (default [0.16 0.84])
%     FIG_SUFFIX    string   (default '')
%     RESP_IDX      vector   (default todos)
%     MODE          string   (default 'unknown')
%     INDEX_FEVD    scalar   horizonte FEVD (para label del título)

%% ── Validar entrada ──────────────────────────────────────────────────────
if isempty(FEVD)
    error('plot_fevd:emptyInput', ...
        'plot_fevd: FEVD está vacío. Ejecuta run_pfa o run_is primero.');
end
if ~isnumeric(FEVD) || ndims(FEVD) ~= 2
    error('plot_fevd:badInput', ...
        'plot_fevd: FEVD debe ser una matriz numérica [nvar x ndraws].');
end

[nvar, ndraws] = size(FEVD);
if ndraws < 2
    error('plot_fevd:tooFewDraws', ...
        'plot_fevd: FEVD necesita al menos 2 draws para calcular bandas.');
end

%% ── Defaults de Cfg ──────────────────────────────────────────────────────
cred_bands = [0.16 0.84];
if isfield(Cfg, 'CRED_BANDS') && ~isempty(Cfg.CRED_BANDS)
    cb = Cfg.CRED_BANDS;
    if isvector(cb), cb = reshape(cb, 1, []); end
    if size(cb, 2) == 2, cred_bands = cb(1,:); end  % usar solo la primera banda
end

fig_suffix = '';
if isfield(Cfg, 'FIG_SUFFIX') && ~isempty(Cfg.FIG_SUFFIX)
    fig_suffix = Cfg.FIG_SUFFIX;
end

mode_str = 'unknown';
if isfield(Cfg, 'MODE') && ~isempty(Cfg.MODE)
    mode_str = lower(Cfg.MODE);
end

fevd_horizon = [];
if isfield(Cfg, 'INDEX_FEVD')
    fevd_horizon = Cfg.INDEX_FEVD;
end

%% ── Labels de variables endógenas ────────────────────────────────────────
endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
all_labels = Dataset.var_labels(endo_mask);

response_idx = 1:nvar;
if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
    ri = Cfg.RESP_IDX;
    response_idx = ri(ri >= 1 & ri <= nvar);
end
nresp = numel(response_idx);

label_resp = cell(1, nresp);
for kk = 1:nresp
    idx = response_idx(kk);
    if idx <= numel(all_labels)
        label_resp{kk} = all_labels{idx};
    else
        label_resp{kk} = sprintf('Var %d', idx);
    end
end

%% ── Calcular estadísticos ────────────────────────────────────────────────
FEVD_sel = FEVD(response_idx, :);   % [nresp x ndraws]
med_fevd  = quantile(FEVD_sel, 0.50, 2);   % [nresp x 1]
lo_fevd   = quantile(FEVD_sel, cred_bands(1), 2);
hi_fevd   = quantile(FEVD_sel, cred_bands(2), 2);

%% ── Layout: barra apilada horizontal ────────────────────────────────────
% Orden: variables de arriba abajo (invertir para que var 1 quede arriba)
order = nresp:-1:1;

med_plot = med_fevd(order);
lo_plot  = lo_fevd(order);
hi_plot  = hi_fevd(order);
rest_plot = 1 - med_plot;   % complemento a 1

labels_plot = label_resp(order);

%% ── Parámetros visuales ─────────────────────────────────────────────────
color_shock  = [0.20 0.60 0.20];   % verde oscuro — shock identificado
color_rest   = [0.85 0.85 0.85];   % gris claro — resto
color_ci_lo  = [0.10 0.45 0.10];   % verde más oscuro para límite inferior
color_ci_hi  = [0.40 0.75 0.40];   % verde más claro para límite superior
color_median = [0, 1.0, 0.4961];   % verde brillante — línea mediana

fontsize_title = 9;
fontsize_axes  = 8;
axiswidth      = 1;

%% ── Construir título ─────────────────────────────────────────────────────
if ~isempty(fevd_horizon)
    title_str = sprintf('FEVD — Contribución del shock identificado (h = %d)', fevd_horizon);
else
    title_str = 'FEVD — Contribución del shock identificado';
end
subtitle_str = sprintf('Modo: %s  |  Banda: [p%.0f, p%.0f]', ...
    upper(mode_str), cred_bands(1)*100, cred_bands(2)*100);

%% ── Figura ───────────────────────────────────────────────────────────────
fig_height = max(250, nresp * 45 + 80);
hFig = figure('Name', 'FEVD', 'NumberTitle', 'off');
set(hFig, 'Position', [50 50 560 fig_height]);

ax = axes('Parent', hFig);
hold(ax, 'on');

y_pos = 1:nresp;   % posición vertical de cada barra

for kk = 1:nresp
    yy = y_pos(kk);

    % Barra del resto (complemento, empieza en med)
    barh(ax, yy, rest_plot(kk), 0.5, 'BaseValue', med_plot(kk), ...
         'FaceColor', color_rest, 'EdgeColor', 'none');

    % Barra del shock identificado (de 0 a mediana)
    barh(ax, yy, med_plot(kk), 0.5, 'BaseValue', 0, ...
         'FaceColor', color_shock, 'EdgeColor', 'none');

    % Banda de credibilidad como segmento horizontal
    plot(ax, [lo_plot(kk), hi_plot(kk)], [yy yy], ...
         'k-', 'LineWidth', 2.5);
    % Marcadores de extremos de banda
    plot(ax, lo_plot(kk), yy, 'k|', 'MarkerSize', 8, 'LineWidth', 1.5);
    plot(ax, hi_plot(kk), yy, 'k|', 'MarkerSize', 8, 'LineWidth', 1.5);
    % Punto de mediana
    plot(ax, med_plot(kk), yy, 'o', ...
         'MarkerFaceColor', color_median, 'MarkerEdgeColor', [0 0 0], ...
         'MarkerSize', 7, 'LineWidth', 1);
end

%% ── Formato de ejes ──────────────────────────────────────────────────────
set(ax, 'YTick', y_pos, 'YTickLabel', labels_plot);
set(ax, 'XLim', [0 1]);
set(ax, 'YLim', [0.3 nresp + 0.7]);
set(ax, 'FontSize', fontsize_axes);
set(ax, 'LineWidth', axiswidth);
set(ax, 'XGrid', 'on');
set(ax, 'GridAlpha', 0.2);
box(ax, 'off');

% Línea vertical en 0.5 como referencia
xline(ax, 0.5, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.8, 'Alpha', 0.6);

xlabel(ax, 'Fracción de varianza', 'FontSize', fontsize_axes);
title(ax, {title_str; subtitle_str}, 'FontSize', fontsize_title, 'Interpreter', 'none');

%% ── Leyenda ──────────────────────────────────────────────────────────────
h_shock = patch(ax, NaN, NaN, color_shock, 'EdgeColor', 'none');
h_rest  = patch(ax, NaN, NaN, color_rest,  'EdgeColor', 'none');
h_ci    = plot(ax, NaN, NaN, 'k-', 'LineWidth', 2.5);
legend(ax, [h_shock, h_rest, h_ci], ...
    {'Shock identificado (mediana)', 'Resto (no identificado)', ...
     sprintf('IC [p%.0f–p%.0f]', cred_bands(1)*100, cred_bands(2)*100)}, ...
    'Location', 'southoutside', 'Orientation', 'horizontal', ...
    'FontSize', fontsize_axes - 1, 'Box', 'off');

set(hFig, 'PaperPositionMode', 'auto');

%% ── Guardar figura ───────────────────────────────────────────────────────
src_root  = fileparts(mfilename('fullpath'));
proj_root = fileparts(src_root);
fig_dir   = fullfile(proj_root, 'output', 'figures');
if ~isfolder(fig_dir), mkdir(fig_dir); end

fname = fullfile(fig_dir, ['fevd_', mode_str, fig_suffix, '.png']);
print(fname, '-dpng', '-r150');
fprintf('Figura FEVD guardada en: %s\n', fname);

end
