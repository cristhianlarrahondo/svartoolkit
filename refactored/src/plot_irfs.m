function plot_irfs(LtildeStruct, Dataset, Cfg, Results)
%PLOT_IRFS  Figura unificada de IRFs y/o CIRFs.
%
%   PLOT_IRFS(LtildeStruct, Dataset, Cfg)
%   PLOT_IRFS(LtildeStruct, Dataset, Cfg, Results)
%
%   Soporta:
%     A1: selector shock-response vía select_irfs
%     A2: Cfg.IRF_TYPE = 'irf' | 'cirf' | 'both'
%     A3: Cfg.CRED_BANDS = [p_lo p_hi; ...]  (N bandas configurables)
%     A7: normalización vía normalize_irfs si Cfg.IRF_NORM está definido
%
%   Campos de Cfg usados (todos opcionales; con defaults seguros):
%     IRF_TYPE      'irf' (def) | 'cirf' | 'both'
%     CRED_BANDS    [0.16 0.84] (def) — array [N x 2] de cuantiles
%     IRF_NORM      'none' (def) | '1sd' | 'unit' | 'own_unit'
%     NORM_SHOCK_IDX, NORM_VAR, NORM_HORIZON, NORM_VALUE — según IRF_NORM
%     SHOCK_IDX     índice del shock a graficar (def: LtildeStruct.shock_idx)
%     RESP_IDX      índice(s) de variables de respuesta (def: todos)
%     OUTPUT_DIR    string (OPCIONAL) — ruta absoluta a la carpeta output/
%                   del proyecto que llama (p.ej. examples/bnw/output/).
%                   Si no está definido, se usa el comportamiento legado:
%                   refactored/output/.

%% ── Argumentos opcionales ────────────────────────────────────────────────
if nargin < 4
    Results = struct();
end

%% ── Parámetros de control con defaults ──────────────────────────────────
irf_type = 'irf';
if isfield(Cfg, 'IRF_TYPE') && ~isempty(Cfg.IRF_TYPE)
    irf_type = lower(Cfg.IRF_TYPE);
end
valid_types = {'irf', 'cirf', 'both'};
if ~ismember(irf_type, valid_types)
    error('plot_irfs:unknownIRFType', ...
        'Cfg.IRF_TYPE = ''%s'' no valido. Usar: ''irf'', ''cirf'', ''both''.', irf_type);
end

% Bandas de credibilidad
cred_bands = [0.16 0.84];
if isfield(Cfg, 'CRED_BANDS') && ~isempty(Cfg.CRED_BANDS)
    cred_bands = Cfg.CRED_BANDS;
    if isvector(cred_bands)
        cred_bands = reshape(cred_bands, 1, []);   % forzar fila [1x2]
    end
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
[irfs_raw, ~, label_resp] = select_irfs(LtildeStruct, shock_idx, response_idx);
% irfs_raw: [horizon+1, numel(response_idx), ndraws]

horizon = LtildeStruct.horizon;
nresp   = size(irfs_raw, 2);

%% ── Normalización (A7) ───────────────────────────────────────────────────
[irfs_norm_arr, scale_factors] = normalize_irfs(irfs_raw, irf_norm, Cfg, Results);

%% ── CIRFs si se necesitan ────────────────────────────────────────────────
if ismember(irf_type, {'cirf', 'both'})
    cirfs_norm_arr = compute_cirfs(irfs_norm_arr);
end

%% ── Calcular estadísticos ────────────────────────────────────────────────
%   med_mat  : [T x K]
%   bands_lo : [n_bands x T x K]
%   bands_hi : [n_bands x T x K]
function [med_mat, bands_lo, bands_hi] = calc_stats(arr)
    T_ = size(arr, 1);
    K_ = size(arr, 2);
    med_mat  = zeros(T_, K_);
    bands_lo = zeros(n_bands, T_, K_);
    bands_hi = zeros(n_bands, T_, K_);
    for ii = 1:T_
        for jj = 1:K_
            sl = arr(ii, jj, :);
            sl = sl(:);   % siempre columna, independiente de ndims
            med_mat(ii, jj) = quantile(sl, 0.50);
            for bb = 1:n_bands
                bands_lo(bb, ii, jj) = quantile(sl, cred_bands(bb, 1));
                bands_hi(bb, ii, jj) = quantile(sl, cred_bands(bb, 2));
            end
        end
    end
end

%% ── Parámetros visuales ──────────────────────────────────────────────────
fontsizetitle = 8;
fontsizeaxes  = 8;
axiswidth     = 1;
color_median  = [0, 1.0000, 0.4961];

% Orden de bandas: más estrecha → más oscura
band_widths = cred_bands(:,2) - cred_bands(:,1);
[~, order_asc]  = sort(band_widths, 'ascend');   % más estrecha primero
[~, order_desc] = sort(band_widths, 'descend');  % más ancha primero (para graficar exterior primero)

% Paleta de grises: índice 1 (más estrecha) = más oscuro
gray_levels = linspace(0.45, 0.75, max(n_bands, 2));
color_bands = zeros(n_bands, 3);
for bb = 1:n_bands
    rank_bb = find(order_asc == bb);
    if n_bands == 1
        color_bands(bb, :) = 0.65 * [1 1 1];
    else
        color_bands(bb, :) = gray_levels(rank_bb) * [1 1 1];
    end
end

x_plot = (0:horizon)';   % columna — garantiza consistencia con vectores de banda

%% ── Helper: graficar un panel ────────────────────────────────────────────
function plot_panel(med_mat, bands_lo, bands_hi, kk, panel_title)
    % Mediana: x_plot columna, med columna
    med_vec = med_mat(:, kk);   % [T x 1]
    plot(x_plot, med_vec, 'LineWidth', 2, 'Color', color_median);
    hold on;
    yline(0, '-r');

    % Bandas: exterior (más ancha) primero, interior (más estrecha) encima
    for bb_plot = 1:n_bands
        bb = order_desc(bb_plot);
        % Extraer como vector columna explícitamente
        hi_vec = reshape(bands_hi(bb, :, kk), [], 1);   % [T x 1]
        lo_vec = reshape(bands_lo(bb, :, kk), [], 1);   % [T x 1]
        x_fill = [x_plot; flipud(x_plot)];              % [2T x 1]
        y_fill = [hi_vec; flipud(lo_vec)];              % [2T x 1]
        fill(x_fill, y_fill, color_bands(bb, :), ...
             'FaceAlpha', 0.5, 'EdgeColor', 'none');
    end

    xlabel('Quarters');
    set(gca, 'XTick', [0 10 20 30 40]);
    set(gca, 'LineWidth', axiswidth);
    set(gca, 'FontSize', fontsizeaxes);
    grid on; box off;
    set(gca, 'GridAlpha', 0.05);
    title(panel_title, 'Interpreter', 'tex', 'FontSize', fontsizetitle);
end

%% ── Ruta de salida ───────────────────────────────────────────────────────
% Si Cfg.OUTPUT_DIR está definido (proyectos en examples/<nombre>/), las
% figuras se escriben ahí. Si no está definido, se preserva el
% comportamiento legado: relativo a refactored/ (motor compartido), para
% no romper specs existentes que no definen este campo.
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
mode_str = LtildeStruct.mode;
% Sufijo opcional para el nombre de archivo (ej. '_test' evita pisar produccion)
fig_suffix = '';
if isfield(Cfg, 'FIG_SUFFIX') && ~isempty(Cfg.FIG_SUFFIX)
    fig_suffix = Cfg.FIG_SUFFIX;
end

%% ── Figura IRF ───────────────────────────────────────────────────────────
if ismember(irf_type, {'irf', 'both'})
    [irf_med, irf_blo, irf_bhi] = calc_stats(irfs_norm_arr);

    hFig1 = figure('Name', 'IRFs', 'NumberTitle', 'off');
    set(hFig1, 'Position', [0 20 500 250]);
    n_panels = min(nresp, 5);
    for kk = 1:n_panels
        subplot(2, 3, kk);
        plot_panel(irf_med, irf_blo, irf_bhi, kk, label_resp{kk});
    end
    set(gcf, 'PaperPositionMode', 'auto');
    fname1 = fullfile(fig_dir, ['irfs_', mode_str, fig_suffix, '.png']);
    print(fname1, '-dpng');
    fprintf('Figura IRF guardada en: %s\n', fname1);
end

%% ── Figura CIRF ──────────────────────────────────────────────────────────
if ismember(irf_type, {'cirf', 'both'})
    [cirf_med, cirf_blo, cirf_bhi] = calc_stats(cirfs_norm_arr);

    hFig2 = figure('Name', 'CIRFs', 'NumberTitle', 'off');
    set(hFig2, 'Position', [50 20 500 250]);
    n_panels = min(nresp, 5);
    for kk = 1:n_panels
        subplot(2, 3, kk);
        plot_panel(cirf_med, cirf_blo, cirf_bhi, kk, [label_resp{kk}, ' (cum.)']);
    end
    set(gcf, 'PaperPositionMode', 'auto');
    fname2 = fullfile(fig_dir, ['cirfs_', mode_str, fig_suffix, '.png']);
    print(fname2, '-dpng');
    fprintf('Figura CIRF guardada en: %s\n', fname2);
end

%% ── Resumen de normalización ─────────────────────────────────────────────
if ~strcmp(irf_norm, 'none')
    fprintf('[plot_irfs] Normalizacion aplicada: %s\n', irf_norm);
    fprintf('  Factor medio (draw 1): [');
    fprintf(' %.4f', scale_factors(:, 1));
    fprintf(' ]\n');
end

end

