function plot_irfs(LtildeStruct, Dataset, Cfg)
%PLOT_IRFS  Figura unificada de IRFs (modo PFA por ahora; IS en Fase 3).
%
%   PLOT_IRFS(LtildeStruct, Dataset, Cfg)
%
%   Replica el estilo visual de original/figure_1_panel_a/results/
%   plothelpfunctions/store_results_and_plot_IRFs.m
%
%   LtildeStruct: struct canonica (de pack_ltilde.m)
%   Dataset:      struct de load_data.m (para labels)
%   Cfg:          struct de config/spec_*.m

%% ── Extraer draws segun modo ─────────────────────────────────────────────
j = LtildeStruct.shock_idx;
switch LtildeStruct.mode
    case 'pfa'
        % PFA: data es [horizon+1, nvar, nd]
        irf_draws = LtildeStruct.data;   % (horizon+1, nvar, nd)
    case 'is'
        % IS: data es [horizon+1, nvar, nvar, ne]; squeeze el shock de interes
        irf_draws = squeeze(LtildeStruct.data(:, :, j, :));  % (horizon+1, nvar, ne)
    otherwise
        error('plot_irfs:unknownMode', 'Modo desconocido: %s', LtildeStruct.mode);
end

horizon = LtildeStruct.horizon;
nvar    = LtildeStruct.nvar;

%% ── Calcular cuantiles ───────────────────────────────────────────────────
irf_median = zeros(horizon+1, nvar);
irf_lo     = zeros(horizon+1, nvar);
irf_hi     = zeros(horizon+1, nvar);

for ii = 1:horizon+1
    for jj = 1:nvar
        slice = squeeze(irf_draws(ii, jj, :));
        irf_median(ii, jj) = quantile(slice, 0.50);
        irf_lo(ii, jj)     = quantile(slice, 0.16);
        irf_hi(ii, jj)     = quantile(slice, 0.84);
    end
end

%% ── Labels ───────────────────────────────────────────────────────────────
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
labels    = Dataset.var_labels(endo_mask);
ylabels   = {'Percent','Percent','Percent','Percentage points','Percent'};
if numel(ylabels) < nvar
    ylabels = repmat({'Percent'}, 1, nvar);
end

%% ── Parametros visuales (igual que el original) ─────────────────────────
fontsizetitle  = 8;
fontsizeaxes   = 8;
axiswidth      = 1;
color_median   = [0, 1.0000, 0.4961];
color_band     = [0.6602, 0.6602, 0.6602];
x_plot         = 0:1:horizon;

%% ── Figura ───────────────────────────────────────────────────────────────
hFig = figure('Name', 'IRFs', 'NumberTitle', 'off');
set(hFig, 'Position', [0 20 500 250]);

n_panels = min(nvar, 5);   % mostrar hasta 5 paneles
rows = 2; cols = 3;

for kk = 1:n_panels
    subplot(rows, cols, kk);

    % Mediana
    plot(x_plot, irf_median(:, kk), 'LineWidth', 2, 'Color', color_median);
    hold on;

    % Cero horizontal
    yline(0, '-r');

    % Banda
    hi_vec = irf_hi(:, kk)';
    lo_vec = irf_lo(:, kk)';
    fill([x_plot, fliplr(x_plot)], [hi_vec, fliplr(lo_vec)], ...
         color_band, 'FaceAlpha', 0.5, 'EdgeColor', 'none');

    xlabel('Quarters');
    ylabel(ylabels{kk});
    set(gca, 'XTick', [0 10 20 30 40]);
    set(gca, 'LineWidth', axiswidth);
    set(gca, 'FontSize', fontsizeaxes);
    grid on; box off;
    H = gca; set(H, 'GridAlpha', 0.05);

    if kk <= numel(labels)
        title(labels{kk}, 'Interpreter', 'tex', 'FontSize', fontsizetitle);
    end
end

set(gcf, 'PaperPositionMode', 'auto');

%% ── Guardar figura si se solicita ────────────────────────────────────────
src_root  = fileparts(mfilename('fullpath'));   % .../refactored/src/
proj_root = fileparts(src_root);               % .../refactored/
fig_dir   = fullfile(proj_root, 'output', 'figures');
if ~isfolder(fig_dir)
    mkdir(fig_dir);
end

mode_str = LtildeStruct.mode;
print(fullfile(fig_dir, ['irfs_', mode_str, '.png']), '-dpng');
fprintf('Figura guardada en: %s\n', fullfile(fig_dir, ['irfs_', mode_str, '.png']));

end
