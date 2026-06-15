function plot_fevd(FEVD, Dataset, Cfg)
%PLOT_FEVD  Grafica la Forecast Error Variance Decomposition con bandas.
%
%   PLOT_FEVD(FEVD, Dataset, Cfg)
%
%   Entrada:
%     FEVD      [nvar x ndraws]  — matriz de FEVD (campo Results.FEVD)
%               Cada columna FEVD(:, d) es la fracción de varianza
%               explicada por el shock identificado, por variable.
%     Dataset   struct de load_data — se usan var_labels y var_roles
%     Cfg       struct de configuración — campos usados:
%                 CRED_BANDS    [N x 2]  (default [0.16 0.84])
%                 FIG_SUFFIX    string   (default '')
%                 RESP_IDX      vector   (default todos)
%
%   Salida: figura guardada en output/figures/fevd_<mode>.png

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
    if isvector(cb)
        cb = reshape(cb, 1, []);
    end
    if size(cb, 2) == 2
        cred_bands = cb;
    end
end
n_bands = size(cred_bands, 1);

fig_suffix = '';
if isfield(Cfg, 'FIG_SUFFIX') && ~isempty(Cfg.FIG_SUFFIX)
    fig_suffix = Cfg.FIG_SUFFIX;
end

% Modo de estimación (para nombre de archivo)
mode_str = 'unknown';
if isfield(Cfg, 'MODE') && ~isempty(Cfg.MODE)
    mode_str = lower(Cfg.MODE);
end

%% ── Labels de variables endógenas ────────────────────────────────────────
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
all_labels = Dataset.var_labels(endo_mask);

% Subconjunto de respuestas
response_idx = 1:nvar;
if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
    response_idx = Cfg.RESP_IDX;
    response_idx = response_idx(response_idx >= 1 & response_idx <= nvar);
end
nresp = numel(response_idx);

%% ── Construir labels ─────────────────────────────────────────────────────
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

bands_lo = zeros(n_bands, nresp);
bands_hi = zeros(n_bands, nresp);
for bb = 1:n_bands
    bands_lo(bb, :) = quantile(FEVD_sel, cred_bands(bb, 1), 2)';
    bands_hi(bb, :) = quantile(FEVD_sel, cred_bands(bb, 2), 2)';
end

%% ── Parámetros visuales ─────────────────────────────────────────────────
color_median  = [0, 1.0000, 0.4961];
gray_levels   = linspace(0.45, 0.75, max(n_bands, 2));
% orden de bandas para gráfico: más estrecha primero en el sort
band_widths   = cred_bands(:,2) - cred_bands(:,1);
[~, order_asc]  = sort(band_widths, 'ascend');
[~, order_desc] = sort(band_widths, 'descend');
color_bands   = zeros(n_bands, 3);
for bb = 1:n_bands
    rank_bb = find(order_asc == bb);
    if n_bands == 1
        color_bands(bb, :) = 0.65 * [1 1 1];
    else
        color_bands(bb, :) = gray_levels(rank_bb) * [1 1 1];
    end
end

fontsizetitle = 8;
fontsizeaxes  = 8;
axiswidth     = 1;

%% ── Graficar ─────────────────────────────────────────────────────────────
hFig = figure('Name', 'FEVD', 'NumberTitle', 'off');
set(hFig, 'Position', [0 20 500 250]);

n_panels = min(nresp, 5);
x_vars   = 1:n_panels;   % eje X: índice de variable

% Preparar subplot (barra + bandas por variable)
subplot_rows = ceil(n_panels / 3);
subplot_cols = min(n_panels, 3);

for kk = 1:n_panels
    subplot(subplot_rows, subplot_cols, kk);

    % Barras de error (bandas): exterior primero
    hold on;
    for bb_plot = 1:n_bands
        bb = order_desc(bb_plot);
        lo = bands_lo(bb, kk);
        hi = bands_hi(bb, kk);
        % Rectángulo centrado en variable kk
        fill([0.6 1.4 1.4 0.6], [lo lo hi hi], color_bands(bb, :), ...
             'FaceAlpha', 0.5, 'EdgeColor', 'none');
    end

    % Mediana como línea horizontal + punto
    plot([0.6 1.4], [med_fevd(kk) med_fevd(kk)], ...
         'Color', color_median, 'LineWidth', 2);
    plot(1, med_fevd(kk), 'o', ...
         'MarkerFaceColor', color_median, 'MarkerEdgeColor', color_median, ...
         'MarkerSize', 6);

    % Formato del panel
    xlim([0.4 1.6]);
    ylim([0 1]);
    set(gca, 'XTick', []);
    set(gca, 'LineWidth', axiswidth);
    set(gca, 'FontSize', fontsizeaxes);
    grid on; box off;
    set(gca, 'GridAlpha', 0.05);
    ylabel('Fracción de varianza');
    title(label_resp{kk}, 'Interpreter', 'tex', 'FontSize', fontsizetitle);
end

set(gcf, 'PaperPositionMode', 'auto');

%% ── Guardar figura ───────────────────────────────────────────────────────
src_root  = fileparts(mfilename('fullpath'));
proj_root = fileparts(src_root);
fig_dir   = fullfile(proj_root, 'output', 'figures');
if ~isfolder(fig_dir)
    mkdir(fig_dir);
end

fname = fullfile(fig_dir, ['fevd_', mode_str, fig_suffix, '.png']);
print(fname, '-dpng');
fprintf('Figura FEVD guardada en: %s\n', fname);

end
