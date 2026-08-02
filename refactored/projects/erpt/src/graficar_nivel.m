function graficar_nivel(Results, Dataset, Cfg, bandas, resp_vars)
%GRAFICAR_NIVEL  Figure 2 (ERPT-Chat 21, decision 2): accumulated level
%   response L(h) = IRF(h) + L(h-12), by shock, including the `ner` panel.
%   Replaces the generic CIRF (cumsum) retired from the report
%   (mostrar_cirf.m / graficar_irf with IRF_TYPE='cirf' are no longer
%   called for this object).
%
%   GRAFICAR_NIVEL(Results, Dataset, Cfg)
%   GRAFICAR_NIVEL(Results, Dataset, Cfg, bandas)
%   GRAFICAR_NIVEL(Results, Dataset, Cfg, bandas, resp_vars)
%
%   Self-contained in projects/erpt/src/ -- does NOT call plot_irfs.m
%   (core), so as to not touch that file shared with BNW/oil_market (user
%   decision in ERPT-Chat 22: the axis relabel is resolved entirely on the
%   ERPT side). Minimal, self-contained reimplementation of the visual
%   style (median + shaded band).
%
%   ERPT-Chat 22 (round 2, user feedback): all figure-facing text (titles,
%   axis labels) is in English -- the paper is written in English. Panel
%   titles use Dataset.var_labels (already English, e.g. "Imports
%   Inflation") instead of the raw variable name, for consistency with
%   Figure 1 (plot_irfs.m). Grid is now ceil(sqrt(n)) x ceil(n/cols)
%   (square-ish) instead of a fixed 3-column cap, to avoid an unbalanced
%   layout with 4 panels (3 on one row, 1 alone on the next).
%
%   ── Entradas ─────────────────────────────────────────────────────────
%     bandas      [1 x 2] quantiles, e.g. [0.16 0.84] (68%, default and
%                 only band supported in the final report -- ERPT-Chat 21
%                 decision 1). If [N x 2] is passed, only the first row
%                 is used (this figure reports a single band).
%     resp_vars   cell array of variables to plot (order = panels).
%                 Default: same default as build_level_response.m
%                 (Cfg.ERPT_DENOM_VAR + Cfg.ERPT_PRICE_VARS).
%
%   One PNG per shock: 'nivel_shock<N>_<SHOCKNAME>.png' in
%   <Cfg.OUTPUT_DIR>/figures/ (same directory as plot_irfs.m/plot_fevd.m).
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

%% ── Labels amigables de variable (mismo patron que plot_irfs.m/print_summary.m,
%    ya en ingles en el Excel de metadata -- p.ej. "Imports Inflation") ──
endo_mask       = strcmp(Dataset.var_roles, 'endogenous');
all_var_names   = Dataset.var_names(endo_mask);
all_var_labels  = Dataset.var_labels(endo_mask);
panel_label = @(varname) p_resolve_label(varname, all_var_names, all_var_labels);

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
    x_axis_label = 'Horizon';
end
n_ticks = min(6, horizon + 1);
x_ticks = unique(round(linspace(0, horizon, n_ticks)));

n_vars = numel(Level.vars);
n_cols = ceil(sqrt(n_vars));         % grid cuadrado, no 3-columnas fijo
n_rows = ceil(n_vars / n_cols);

%% ── Y-axis label per variable (English -- the paper is in English) ──────
%   Design decision (ERPT-Chat 22): the 3 price variables (imp/pro/
%   con_inf) share the same reporting unit "percentage points of annual
%   inflation" (same criterion as the Figure 1 relabel). `ner` is reported
%   in its native unit (annual % change of the exchange rate, already
%   accumulated by the L(h) recursion).
    function lbl = ylabel_for(varname)
        if strcmp(varname, 'ner')
            lbl = 'cumulative annual % change (ner)';
        elseif any(strcmp(varname, {'imp_inf', 'pro_inf', 'con_inf'}))
            lbl = 'percentage points of annual inflation';
        else
            lbl = 'accumulated level L(h)';
        end
    end

%% ── Una figura por choque ────────────────────────────────────────────────
n_shocks = numel(Level.shocks);
for j = 1:n_shocks
    sh          = Level.shocks(j);
    label_shock = sh.name;
    shock_name_safe = regexprep(label_shock, '[^a-zA-Z0-9_]', '_');
    shock_tag       = sprintf('shock%d_%s', sh.idx, shock_name_safe);

    hFig = figure('Name', sprintf('Level L(h) - %s', label_shock), 'NumberTitle', 'off');
    set(hFig, 'Position', [0 20 220*n_cols 220*n_rows]);
    tl = tiledlayout(hFig, n_rows, n_cols, 'TileSpacing', 'compact', 'Padding', 'compact');

    for v = 1:n_vars
        ax = nexttile(tl);
        med_vec = sh.vars(v).median(:);
        lo_vec  = sh.vars(v).band_lo(1, :)';
        hi_vec  = sh.vars(v).band_hi(1, :)';

        plot(ax, x_plot, med_vec, 'LineWidth', 2, 'Color', color_median);
        hold(ax, 'on');
        yline(ax, 0, '-r');
        x_fill = [x_plot; flipud(x_plot)];
        y_fill = [hi_vec; flipud(lo_vec)];
        fill(ax, x_fill, y_fill, color_band, 'FaceAlpha', 0.5, 'EdgeColor', 'none');

        xlabel(ax, x_axis_label);
        ylabel(ax, ylabel_for(sh.vars(v).var));
        set(ax, 'XTick', x_ticks);
        set(ax, 'LineWidth', axiswidth);
        set(ax, 'FontSize', fontsizeaxes);
        grid(ax, 'on'); box(ax, 'off');
        set(ax, 'GridAlpha', 0.05);
        title(ax, panel_label(sh.vars(v).var), 'Interpreter', 'none', 'FontSize', fontsizetitle);

        % -- Ocultar el toolbar interactivo de ejes en el PNG exportado
        %    (aviso de MATLAB "Exported image displays axes toolbar") --
        if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
            ax.Toolbar.Visible = 'off';
        end
    end
    title(tl, sprintf('Accumulated level L(h) — Shock: %s', label_shock), 'FontSize', fontsizetitle);
    set(gcf, 'PaperPositionMode', 'auto');

    fname = fullfile(fig_dir, ['nivel_', shock_tag, fig_suffix, '.png']);
    print(fname, '-dpng');
    fprintf('Level L(h) figure (shock %d: %s) saved to: %s\n', sh.idx, label_shock, fname);
end

end


function lbl = p_resolve_label(varname, var_names, var_labels)
%P_RESOLVE_LABEL  Etiqueta amigable (Dataset.var_labels) para `varname`,
%   por NOMBRE (nunca por posicion). Fallback al nombre crudo si no se
%   encuentra (nunca deberia pasar dentro de este proyecto).
    idx = find(strcmp(var_names, varname), 1);
    if isempty(idx) || idx > numel(var_labels)
        lbl = varname;
    else
        lbl = var_labels{idx};
    end
end
