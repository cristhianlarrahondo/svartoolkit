function graficar_nivel(Results, Dataset, Cfg, bandas, resp_vars)
%GRAFICAR_NIVEL  Figura 2 (ERPT-Chat 21, decision 2): respuesta acumulada
%   del nivel L(h) = IRF(h) + L(h-12), por choque, con panel de `ner`
%   incluido. Reemplaza a las CIRF genericas (cumsum) retiradas del
%   reporte (mostrar_cirf.m / graficar_irf con IRF_TYPE='cirf' ya NO se
%   llaman para este objeto).
%
%   GRAFICAR_NIVEL(Results, Dataset, Cfg)
%   GRAFICAR_NIVEL(Results, Dataset, Cfg, bandas)
%   GRAFICAR_NIVEL(Results, Dataset, Cfg, bandas, resp_vars)
%
%   Autocontenida en projects/erpt/src/ -- NO llama a plot_irfs.m (core),
%   para no tocar ese archivo compartido con BNW/oil_market (decision del
%   usuario en ERPT-Chat 22: el relabel de ejes se resuelve solo del lado
%   ERPT). Reimplementa el estilo visual (mediana + banda sombreada) de
%   forma minima y autonoma.
%
%   ── Entradas ─────────────────────────────────────────────────────────
%     bandas      [1 x 2] cuantiles, p.ej. [0.16 0.84] (68%, default y
%                 unica banda soportada en el reporte final -- ERPT-Chat
%                 21 decision 1). Si se pasa [N x 2] solo se usa la
%                 primera fila (esta figura reporta una sola banda).
%     resp_vars   cell array de variables a graficar (orden = paneles).
%                 Default: mismo default que build_level_response.m
%                 (Cfg.ERPT_DENOM_VAR + Cfg.ERPT_PRICE_VARS).
%
%   Un archivo PNG por choque: 'nivel_shock<N>_<SHOCKNAME>.png' en
%   <Cfg.OUTPUT_DIR>/figures/ (mismo directorio que plot_irfs.m/plot_fevd.m).
%
%   Vive en projects/erpt/src/graficar_nivel.m -- Tipo S, no toca src/
%   compartido, no requiere regresion BNW.
%
%   Ver tambien: build_level_response.m, calculate_erpt.m

if nargin >= 4 && ~isempty(bandas)
    if isvector(bandas); bandas = reshape(bandas, 1, []); end
    Cfg.CRED_BANDS = bandas(1, :);   % una sola banda en esta figura
end
if nargin < 5
    resp_vars = [];
end

transform_type = 'aa';
if isfield(Cfg, 'ERPT_TRANSFORM') && ~isempty(Cfg.ERPT_TRANSFORM)
    transform_type = Cfg.ERPT_TRANSFORM;   % override explicito, si existiera
end

Level = build_level_response(Results, Dataset, Cfg, transform_type, resp_vars);

%% ── Ruta de salida (mismo patron que plot_irfs.m/plot_fevd.m) ───────────
if isfield(Cfg, 'OUTPUT_DIR') && ~isempty(Cfg.OUTPUT_DIR)
    fig_dir = fullfile(Cfg.OUTPUT_DIR, 'figures');
else
    src_root  = fileparts(mfilename('fullpath'));
    proj_root = fileparts(src_root);
    fig_dir   = fullfile(proj_root, 'output', 'figures');
end
if ~isfolder(fig_dir)
    mkdir(fig_dir);
end
fig_suffix = '';
if isfield(Cfg, 'FIG_SUFFIX') && ~isempty(Cfg.FIG_SUFFIX)
    fig_suffix = Cfg.FIG_SUFFIX;
end

%% ── Parametros visuales (mismo criterio que plot_irfs.m) ────────────────
fontsizetitle = 8;
fontsizeaxes  = 8;
axiswidth     = 1;
color_median  = [0, 1.0000, 0.4961];
color_band    = 0.65 * [1 1 1];

horizon = Level.horizons(end);
x_plot  = Level.horizons(:);

freq_labels = struct('Q', 'Quarters', 'M', 'Months', 'A', 'Years', 'S', 'Semesters');
if isfield(Dataset, 'freq') && isfield(freq_labels, Dataset.freq)
    x_axis_label = freq_labels.(Dataset.freq);
else
    x_axis_label = 'Horizonte';
end
n_ticks = min(6, horizon + 1);
x_ticks = unique(round(linspace(0, horizon, n_ticks)));

n_vars   = numel(Level.vars);
n_cols   = min(n_vars, 3);
n_rows   = ceil(n_vars / n_cols);

%% ── Etiqueta del eje Y por variable (post-proceso ERPT, sin tocar core) ──
%   Decision de disenio (ERPT-Chat 22): las 3 variables de precio (imp/pro/
%   con_inf) comparten la misma unidad de reporte "puntos porcentuales de
%   inflacion anual" (mismo criterio que el relabel de Figura 1). `ner`
%   se reporta en la unidad nativa de la variable (variacion % anual del
%   tipo de cambio, ya acumulada por la recursion L(h)).
    function lbl = ylabel_for(varname)
        if strcmp(varname, 'ner')
            lbl = 'variacion % anual acumulada (ner)';
        elseif any(strcmp(varname, {'imp_inf', 'pro_inf', 'con_inf'}))
            lbl = 'puntos porcentuales de inflacion anual';
        else
            lbl = 'nivel acumulado L(h)';
        end
    end

%% ── Una figura por choque ────────────────────────────────────────────────
n_shocks = numel(Level.shocks);
for j = 1:n_shocks
    sh          = Level.shocks(j);
    label_shock = sh.name;
    shock_name_safe = regexprep(label_shock, '[^a-zA-Z0-9_]', '_');
    shock_tag       = sprintf('shock%d_%s', sh.idx, shock_name_safe);

    hFig = figure('Name', sprintf('Nivel L(h) - %s', label_shock), 'NumberTitle', 'off');
    set(hFig, 'Position', [0 20 220*n_cols 220*n_rows]);
    tl = tiledlayout(hFig, n_rows, n_cols, 'TileSpacing', 'compact', 'Padding', 'compact');

    for v = 1:n_vars
        nexttile(tl);
        med_vec = sh.vars(v).median(:);
        lo_vec  = sh.vars(v).band_lo(1, :)';
        hi_vec  = sh.vars(v).band_hi(1, :)';

        plot(x_plot, med_vec, 'LineWidth', 2, 'Color', color_median);
        hold on;
        yline(0, '-r');
        x_fill = [x_plot; flipud(x_plot)];
        y_fill = [hi_vec; flipud(lo_vec)];
        fill(x_fill, y_fill, color_band, 'FaceAlpha', 0.5, 'EdgeColor', 'none');

        xlabel(x_axis_label);
        ylabel(ylabel_for(sh.vars(v).var));
        set(gca, 'XTick', x_ticks);
        set(gca, 'LineWidth', axiswidth);
        set(gca, 'FontSize', fontsizeaxes);
        grid on; box off;
        set(gca, 'GridAlpha', 0.05);
        title(sh.vars(v).var, 'Interpreter', 'none', 'FontSize', fontsizetitle);
    end
    title(tl, sprintf('Nivel acumulado L(h) — Shock: %s', label_shock), 'FontSize', fontsizetitle);
    set(gcf, 'PaperPositionMode', 'auto');

    fname = fullfile(fig_dir, ['nivel_', shock_tag, fig_suffix, '.png']);
    print(fname, '-dpng');
    fprintf('Figura Nivel L(h) (shock %d: %s) guardada en: %s\n', sh.idx, label_shock, fname);
end

end
