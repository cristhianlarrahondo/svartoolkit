function plot_irfs(LtildeStruct, Dataset, Cfg, Results)
%PLOT_IRFS  Figura unificada de IRFs y/o CIRFs.
%
%   PLOT_IRFS(LtildeStruct, Dataset, Cfg)
%   PLOT_IRFS(LtildeStruct, Dataset, Cfg, Results)
%
%   Replica el estilo visual de original/figure_1_panel_a y soporta:
%     A1: selector shock-response vía select_irfs
%     A2: Cfg.IRF_TYPE = 'irf' | 'cirf' | 'both'
%     A3: Cfg.CRED_BANDS = [p_lo p_hi; ...]  (N bandas configurables)
%     A7: normalización vía normalize_irfs si Cfg.IRF_NORM está definido
%
%   Entradas:
%     LtildeStruct  struct canónica (de pack_ltilde.m)
%     Dataset       struct de load_data.m (para var_labels)
%     Cfg           struct de config/spec_*.m
%     Results       struct de run_pfa/run_is (opcional; necesario para
%                   IRF_NORM = '1sd' que requiere Sigmadraws)
%
%   Campos de Cfg usados (todos opcionales; con defaults seguros):
%     IRF_TYPE      'irf' (def) | 'cirf' | 'both'
%     CRED_BANDS    [0.16 0.84] (def) — array de pares [lo hi] de cuantiles
%                   Ej: [0.16 0.84; 0.05 0.95] → dos bandas
%     IRF_NORM      'none' (def) | '1sd' | 'unit' | 'own_unit'
%     NORM_SHOCK_IDX, NORM_VAR, NORM_HORIZON, NORM_VALUE — según IRF_NORM
%     SHOCK_IDX     índice del shock a graficar (def: LtildeStruct.shock_idx)
%     RESP_IDX      índice(s) de variables de respuesta (def: todos)

%% ── Argumentos opcionales ────────────────────────────────────────────────
if nargin < 4
    Results = struct();
end

%% ── Parámetros de control con defaults ──────────────────────────────────
irf_type  = 'irf';
if isfield(Cfg, 'IRF_TYPE') && ~isempty(Cfg.IRF_TYPE)
    irf_type = lower(Cfg.IRF_TYPE);
end
valid_types = {'irf', 'cirf', 'both'};
if ~ismember(irf_type, valid_types)
    error('plot_irfs:unknownIRFType', ...
        'Cfg.IRF_TYPE = ''%s'' no es válido. Usar: ''irf'', ''cirf'', ''both''.', irf_type);
end

% Bandas de credibilidad: default [0.16 0.84] (una banda)
cred_bands = [0.16 0.84];
if isfield(Cfg, 'CRED_BANDS') && ~isempty(Cfg.CRED_BANDS)
    cred_bands = Cfg.CRED_BANDS;
    if isvector(cred_bands)
        cred_bands = cred_bands(:)';   % forzar fila
        if numel(cred_bands) ~= 2
            error('plot_irfs:invalidCredBands', ...
                'Cfg.CRED_BANDS debe tener 2 columnas (lo, hi). Recibido: %d elementos.', ...
                numel(cred_bands));
        end
    end
    % Si es vector ya tiene 2 cols; si es matriz tiene N filas x 2 cols
    if size(cred_bands, 2) ~= 2
        error('plot_irfs:invalidCredBands', ...
            'Cfg.CRED_BANDS debe ser [N x 2]. Recibido: [%d x %d].', ...
            size(cred_bands, 1), size(cred_bands, 2));
    end
end
n_bands = size(cred_bands, 1);

% Normalización
irf_norm = 'none';
if isfield(Cfg, 'IRF_NORM') && ~isempty(Cfg.IRF_NORM)
    irf_norm = lower(Cfg.IRF_NORM);
end

% Shock e índices de respuesta
shock_idx = LtildeStruct.shock_idx;
if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
    shock_idx = Cfg.SHOCK_IDX;
end
response_idx = 1:LtildeStruct.nvar;
if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
    response_idx = Cfg.RESP_IDX;
end

%% ── Adjuntar var_labels a LtildeStruct para select_irfs ─────────────────
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
all_labels = Dataset.var_labels(endo_mask);
LtildeStruct.var_labels = all_labels;

%% ── Extraer IRFs del subconjunto shock-response ──────────────────────────
[irfs_raw, label_shock, label_resp] = ...
    select_irfs(LtildeStruct, shock_idx, response_idx);
% irfs_raw: [horizon+1, numel(response_idx), ndraws]

horizon = LtildeStruct.horizon;
nresp   = size(irfs_raw, 2);

%% ── Normalización (A7) ───────────────────────────────────────────────────
% Para '1sd', normalize_irfs necesita Sigmadraws — los buscamos en Results
norm_input = Results;   % 4to arg de normalize_irfs

[irfs_norm, scale_factors] = normalize_irfs(irfs_raw, irf_norm, Cfg, norm_input);

%% ── Calcular CIRFs si se necesitan ──────────────────────────────────────
if ismember(irf_type, {'cirf', 'both'})
    cirfs_norm = compute_cirfs(irfs_norm);
end

%% ── Función auxiliar: calcular estadísticos de una figura ────────────────
%   Devuelve: median_mat [T x nresp], bands_lo/hi [n_bands x T x nresp]
function [med_mat, bands_lo, bands_hi] = calc_stats(arr)
    T_    = size(arr, 1);
    K_    = size(arr, 2);
    med_mat   = zeros(T_, K_);
    bands_lo  = zeros(n_bands, T_, K_);
    bands_hi  = zeros(n_bands, T_, K_);
    for ii = 1:T_
        for jj = 1:K_
            sl = squeeze(arr(ii, jj, :));
            med_mat(ii, jj) = quantile(sl, 0.50);
            for bb = 1:n_bands
                bands_lo(bb, ii, jj) = quantile(sl, cred_bands(bb, 1));
                bands_hi(bb, ii, jj) = quantile(sl, cred_bands(bb, 2));
            end
        end
    end
end

%% ── Parámetros visuales ──────────────────────────────────────────────────
fontsizetitle  = 8;
fontsizeaxes   = 8;
axiswidth      = 1;
color_median   = [0, 1.0000, 0.4961];
% Para múltiples bandas: interpolamos de gris claro (exterior) a gris medio (interior)
% La banda más estrecha (menor rango) → más oscura
% Calcular anchos de cada banda para ordenar
band_widths = cred_bands(:,2) - cred_bands(:,1);
[~, band_order] = sort(band_widths, 'ascend');  % más estrecha primero (más oscura)
% Paleta de grises: de más oscuro (interior) a más claro (exterior)
gray_levels = linspace(0.45, 0.75, n_bands);   % [0.45=oscuro, 0.75=claro]
% color_bands(k) = gris para la k-ésima banda en orden de anchura
color_bands = zeros(n_bands, 3);
for bb = 1:n_bands
    rank_bb = find(band_order == bb);   % posición (1=más estrecha)
    color_bands(bb, :) = gray_levels(rank_bb) * [1 1 1];
end

x_plot = 0:1:horizon;

%% ── Helper: graficar un panel (IRF o CIRF) ───────────────────────────────
function plot_panel(med_mat, bands_lo, bands_hi, kk, panel_title)
    % Mediana
    plot(x_plot, med_mat(:, kk), 'LineWidth', 2, 'Color', color_median);
    hold on;
    % Cero
    yline(0, '-r');
    % Bandas: de la más ancha (exterior, más clara) a la más estrecha (interior, más oscura)
    [~, order_desc] = sort(band_widths, 'descend');   % más ancha primero
    for bb_plot = 1:n_bands
        bb = order_desc(bb_plot);
        hi_vec = squeeze(bands_hi(bb, :, kk))';
        lo_vec = squeeze(bands_lo(bb, :, kk))';
        fill([x_plot, fliplr(x_plot)], [hi_vec, fliplr(lo_vec)], ...
             color_bands(bb, :), 'FaceAlpha', 0.5, 'EdgeColor', 'none');
    end
    xlabel('Quarters');
    set(gca, 'XTick', [0 10 20 30 40]);
    set(gca, 'LineWidth', axiswidth);
    set(gca, 'FontSize', fontsizeaxes);
    grid on; box off;
    H = gca; set(H, 'GridAlpha', 0.05);
    title(panel_title, 'Interpreter', 'tex', 'FontSize', fontsizetitle);
end

%% ── Ruta de salida ───────────────────────────────────────────────────────
src_root  = fileparts(mfilename('fullpath'));   % .../refactored/src/
proj_root = fileparts(src_root);               % .../refactored/
fig_dir   = fullfile(proj_root, 'output', 'figures');
if ~isfolder(fig_dir)
    mkdir(fig_dir);
end
mode_str = LtildeStruct.mode;

%% ── FIGURA 1: IRFs (si irf_type ∈ {'irf','both'}) ───────────────────────
if ismember(irf_type, {'irf', 'both'})
    [irf_med, irf_blo, irf_bhi] = calc_stats(irfs_norm);

    hFig1 = figure('Name', 'IRFs', 'NumberTitle', 'off');
    set(hFig1, 'Position', [0 20 500 250]);
    rows = 2; cols = 3;
    n_panels = min(nresp, 5);

    for kk = 1:n_panels
        subplot(rows, cols, kk);
        lbl = label_resp{kk};
        plot_panel(irf_med, irf_blo, irf_bhi, kk, lbl);
    end

    set(gcf, 'PaperPositionMode', 'auto');
    fname1 = fullfile(fig_dir, ['irfs_', mode_str, '.png']);
    print(fname1, '-dpng');
    fprintf('Figura IRF guardada en: %s\n', fname1);
end

%% ── FIGURA 2: CIRFs (si irf_type ∈ {'cirf','both'}) ────────────────────
if ismember(irf_type, {'cirf', 'both'})
    [cirf_med, cirf_blo, cirf_bhi] = calc_stats(cirfs_norm);

    hFig2 = figure('Name', 'CIRFs', 'NumberTitle', 'off');
    set(hFig2, 'Position', [50 20 500 250]);
    rows = 2; cols = 3;
    n_panels = min(nresp, 5);

    for kk = 1:n_panels
        subplot(rows, cols, kk);
        lbl = [label_resp{kk}, ' (cum.)'];
        plot_panel(cirf_med, cirf_blo, cirf_bhi, kk, lbl);
    end

    set(gcf, 'PaperPositionMode', 'auto');
    fname2 = fullfile(fig_dir, ['cirfs_', mode_str, '.png']);
    print(fname2, '-dpng');
    fprintf('Figura CIRF guardada en: %s\n', fname2);
end

%% ── Registrar factores de escala en Results (si se pasa por referencia) ──
% MATLAB no tiene paso por referencia en funciones normales, pero dejamos
% el campo disponible si el llamador captura: Results = plot_irfs(...)
% Por ahora solo imprimimos un resumen si hay normalización activa.
if ~strcmp(irf_norm, 'none')
    fprintf('[plot_irfs] Normalización aplicada: %s\n', irf_norm);
    fprintf('  Factor medio (draw 1): [');
    fprintf(' %.4f', scale_factors(:, 1));
    fprintf(' ]\n');
end

end
