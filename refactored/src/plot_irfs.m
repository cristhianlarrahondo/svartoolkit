function plot_irfs(LtildeStruct, Dataset, Cfg, Results)
%PLOT_IRFS  Figura unificada de IRFs y/o CIRFs. Soporta uno o varios shocks.
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
%   CAMBIO (Chat 19, Hallazgo 4): Cfg.SHOCK_IDX ahora acepta escalar,
%   vector, o 'all' (todos los shocks identificados). Antes solo aceptaba
%   escalar; pasar un vector producia un error de MATLAB dentro de
%   select_irfs.m y no generaba ninguna figura. Ahora se genera UNA
%   FIGURA POR CADA SHOCK solicitado.
%
%   CAMBIO (Chat 19, Hallazgo 9): naming convention unificada para TODAS
%   las figuras: '<tipo>_shock<N>_<SHOCKNAME>.png' (p.ej.
%   'irf_shock1_supply.png'), usando Cfg.SHOCK_NAMES si esta definido
%   (default 'shock1', 'shock2', ... via resolve_shock_name.m). Esto
%   CAMBIA los nombres de archivo respecto a versiones anteriores del
%   toolkit (antes: 'irfs_<modo><sufijo>.png', sin nombre de shock) — es
%   un cambio deliberado, no retrocompatible en el nombre del archivo.
%
%   CAMBIO (Chat 19, Hallazgo 12): antes se graficaba como maximo
%   min(nresp,5) variables con un grid FIJO subplot(2,3,*) — con 6+
%   variables se truncaba una variable silenciosamente. Ahora el grid se
%   calcula dinamicamente (hasta 3 columnas) para graficar TODAS las
%   variables de respuesta solicitadas.
%
%   CAMBIO (Chat 19, Hallazgo 10): el titulo general (sgtitle) ahora
%   distingue IRF de CIRF ('IRF — Shock: <nombre>' vs 'CIRF — Shock:
%   <nombre>'). Los paneles individuales muestran SOLO el nombre de la
%   variable (ya no repiten "(cum.)" en cada panel de la figura CIRF).
%
%   CAMBIO (Chat 20): el label del eje X y sus marcas (XTick) ya NO estan
%   hardcodeados a 'Quarters'/[0 10 20 30 40] (asumian BNW trimestral con
%   horizon=40). Ahora el label sale de Dataset.freq ('Q'->'Quarters',
%   'M'->'Months', 'A'->'Years', 'S'->'Semesters', desconocida->'Horizonte'),
%   y las marcas se calculan dinamicamente segun Cfg.HORIZON.
%
%   Campos de Cfg usados (todos opcionales; con defaults seguros):
%     IRF_TYPE      'irf' (def) | 'cirf' | 'both'
%     CRED_BANDS    [0.16 0.84] (def) — array [N x 2] de cuantiles
%     IRF_NORM      'none' (def) | '1sd' | 'unit' | 'own_unit'
%     NORM_SHOCK_IDX, NORM_VAR, NORM_HORIZON, NORM_VALUE — según IRF_NORM
%     SHOCK_IDX     escalar | vector | 'all' (def: LtildeStruct.shock_idx)
%     SHOCK_NAMES   cell array de strings (def: 'shock1','shock2',...)
%     RESP_IDX      índice(s) de variables de respuesta (def: todos)
%     OUTPUT_DIR    string (OPCIONAL) — ruta absoluta a la carpeta output/
%                   del proyecto que llama (p.ej. projects/bnw/output/).
%                   Si no está definido, se usa el comportamiento legado:
%                   refactored/output/.

%% ── Argumentos opcionales ────────────────────────────────────────────────
if nargin < 4
    Results = struct();
end

%% ── Guard: corrida omitida (p.ej. PFA con >1 choque restringido) ────────
[skip_run, skip_reason] = is_run_skipped(LtildeStruct);
if skip_run
    fprintf('[plot_irfs] Omitido: %s\n', skip_reason);
    return;
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

% Shock(es) e índices de respuesta
shock_idx_req = LtildeStruct.shock_idx;
if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
    shock_idx_req = Cfg.SHOCK_IDX;
end
response_idx = 1:LtildeStruct.nvar;
if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
    response_idx = Cfg.RESP_IDX;
end

shock_names = {};
if isfield(Cfg, 'SHOCK_NAMES') && ~isempty(Cfg.SHOCK_NAMES)
    shock_names = Cfg.SHOCK_NAMES;
end

%% ── Adjuntar var_labels a LtildeStruct para select_irfs ─────────────────
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
all_labels = Dataset.var_labels(endo_mask);
LtildeStruct.var_labels = all_labels;

%% ── Extraer IRFs de TODOS los shocks solicitados ─────────────────────────
[irfs_by_shock, label_shock_arr, label_resp, shock_idx_resolved] = ...
    select_irfs(LtildeStruct, shock_idx_req, response_idx, shock_names);
% irfs_by_shock{j}: [horizon+1, numel(response_idx), ndraws]

horizon    = LtildeStruct.horizon;
n_shocks   = numel(shock_idx_resolved);

%% ── Ruta de salida (una sola vez, fuera del loop de shocks) ─────────────
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
fig_suffix = '';
if isfield(Cfg, 'FIG_SUFFIX') && ~isempty(Cfg.FIG_SUFFIX)
    fig_suffix = Cfg.FIG_SUFFIX;
end

%% ── Parámetros visuales (comunes a todos los shocks) ─────────────────────
fontsizetitle = 8;
fontsizeaxes  = 8;
axiswidth     = 1;
color_median  = [0, 1.0000, 0.4961];

band_widths = cred_bands(:,2) - cred_bands(:,1);
[~, order_asc]  = sort(band_widths, 'ascend');
[~, order_desc] = sort(band_widths, 'descend');

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

x_plot = (0:horizon)';

% Label del eje X segun la frecuencia REAL de los datos (Chat 20: antes
% estaba hardcodeado a 'Quarters', asumiendo BNW trimestral — ya no
% aplica en casos con otra frecuencia, p.ej. mensual en ERPT).
freq_labels = struct('Q', 'Quarters', 'M', 'Months', 'A', 'Years', 'S', 'Semesters');
if isfield(Dataset, 'freq') && isfield(freq_labels, Dataset.freq)
    x_axis_label = freq_labels.(Dataset.freq);
else
    x_axis_label = 'Horizonte';   % frecuencia desconocida ('?') o Dataset sin .freq
end

% XTick dinamico (Chat 20: antes hardcodeado a [0 10 20 30 40], asumiendo
% horizon=40 — con otro Cfg.HORIZON quedaban ticks vacios o cortados).
n_ticks = min(6, horizon + 1);
x_ticks = unique(round(linspace(0, horizon, n_ticks)));

%% ── Helper: calcular estadisticos ─────────────────────────────────────────
    function [med_mat, bands_lo, bands_hi] = calc_stats(arr)
        T_ = size(arr, 1);
        K_ = size(arr, 2);
        med_mat  = zeros(T_, K_);
        bands_lo = zeros(n_bands, T_, K_);
        bands_hi = zeros(n_bands, T_, K_);
        for ii = 1:T_
            for jj = 1:K_
                sl = arr(ii, jj, :);
                sl = sl(:);
                med_mat(ii, jj) = quantile(sl, 0.50);
                for bb = 1:n_bands
                    bands_lo(bb, ii, jj) = quantile(sl, cred_bands(bb, 1));
                    bands_hi(bb, ii, jj) = quantile(sl, cred_bands(bb, 2));
                end
            end
        end
    end

%% ── Helper: graficar un panel ────────────────────────────────────────────
    function plot_panel(med_mat, bands_lo, bands_hi, kk, panel_title)
        med_vec = med_mat(:, kk);
        plot(x_plot, med_vec, 'LineWidth', 2, 'Color', color_median);
        hold on;
        yline(0, '-r');

        for bb_plot = 1:n_bands
            bb = order_desc(bb_plot);
            hi_vec = reshape(bands_hi(bb, :, kk), [], 1);
            lo_vec = reshape(bands_lo(bb, :, kk), [], 1);
            x_fill = [x_plot; flipud(x_plot)];
            y_fill = [hi_vec; flipud(lo_vec)];
            fill(x_fill, y_fill, color_bands(bb, :), ...
                 'FaceAlpha', 0.5, 'EdgeColor', 'none');
        end

        xlabel(x_axis_label);
        set(gca, 'XTick', x_ticks);
        set(gca, 'LineWidth', axiswidth);
        set(gca, 'FontSize', fontsizeaxes);
        grid on; box off;
        set(gca, 'GridAlpha', 0.05);
        title(panel_title, 'Interpreter', 'tex', 'FontSize', fontsizetitle);
    end

%% ── Loop principal: UNA figura (o par IRF/CIRF) POR SHOCK ────────────────
for j = 1:n_shocks
    sidx        = shock_idx_resolved(j);
    irfs_raw    = irfs_by_shock{j};
    label_shock = label_shock_arr{j};
    nresp       = size(irfs_raw, 2);

    % Naming convention unificada (Chat 19, Hallazgo 9): SIEMPRE incluye
    % shock<N>_<nombre>, sin importar si se pidio uno o varios shocks
    % (cambio deliberado respecto al comportamiento anterior).
    shock_name_safe = regexprep(label_shock, '[^a-zA-Z0-9_]', '_');
    shock_tag       = sprintf('shock%d_%s', sidx, shock_name_safe);

    % Grid dinamico (Chat 19, Hallazgo 12): antes se truncaba a
    % min(nresp,5) con un grid fijo subplot(2,3,*). Ahora se grafican
    % TODAS las nresp variables de respuesta, hasta 3 columnas.
    n_panels = nresp;
    n_cols   = min(n_panels, 3);
    n_rows   = ceil(n_panels / n_cols);

    %% ── Normalización (A7) ───────────────────────────────────────────────
    [irfs_norm_arr, scale_factors] = normalize_irfs(irfs_raw, irf_norm, Cfg, Results);

    %% ── CIRFs si se necesitan ────────────────────────────────────────────
    if ismember(irf_type, {'cirf', 'both'})
        cirfs_norm_arr = compute_cirfs(irfs_norm_arr);
    end

    %% ── Figura IRF ───────────────────────────────────────────────────────
    if ismember(irf_type, {'irf', 'both'})
        [irf_med, irf_blo, irf_bhi] = calc_stats(irfs_norm_arr);

        hFig1 = figure('Name', sprintf('IRF - %s', label_shock), 'NumberTitle', 'off');
        set(hFig1, 'Position', [0 20 220*n_cols 220*n_rows]);
        % tiledlayout (en vez de subplot fijo) reserva automaticamente el
        % espacio del titulo general y el espaciado entre filas/columnas —
        % evita el overlap entre el titulo general y los paneles/labels
        % que ocurria con subplot() cuando hay 2+ filas.
        tl1 = tiledlayout(hFig1, n_rows, n_cols, 'TileSpacing', 'compact', 'Padding', 'compact');
        for kk = 1:n_panels
            nexttile(tl1);
            plot_panel(irf_med, irf_blo, irf_bhi, kk, label_resp{kk});
        end
        title(tl1, sprintf('IRF — Shock: %s', label_shock), 'FontSize', fontsizetitle);
        set(gcf, 'PaperPositionMode', 'auto');
        fname1 = fullfile(fig_dir, ['irf_', shock_tag, fig_suffix, '.png']);
        print(fname1, '-dpng');
        fprintf('Figura IRF (shock %d: %s) guardada en: %s\n', sidx, label_shock, fname1);
    end

    %% ── Figura CIRF ──────────────────────────────────────────────────────
    if ismember(irf_type, {'cirf', 'both'})
        [cirf_med, cirf_blo, cirf_bhi] = calc_stats(cirfs_norm_arr);

        hFig2 = figure('Name', sprintf('CIRF - %s', label_shock), 'NumberTitle', 'off');
        set(hFig2, 'Position', [50 20 220*n_cols 220*n_rows]);
        tl2 = tiledlayout(hFig2, n_rows, n_cols, 'TileSpacing', 'compact', 'Padding', 'compact');
        for kk = 1:n_panels
            nexttile(tl2);
            % Chat 19, Hallazgo 10: el panel solo muestra el nombre de la
            % variable — "CIRF" ya queda en el titulo general, no se repite aqui.
            plot_panel(cirf_med, cirf_blo, cirf_bhi, kk, label_resp{kk});
        end
        title(tl2, sprintf('CIRF — Shock: %s', label_shock), 'FontSize', fontsizetitle);
        set(gcf, 'PaperPositionMode', 'auto');
        fname2 = fullfile(fig_dir, ['cirf_', shock_tag, fig_suffix, '.png']);
        print(fname2, '-dpng');
        fprintf('Figura CIRF (shock %d: %s) guardada en: %s\n', sidx, label_shock, fname2);
    end

    %% ── Resumen de normalización ─────────────────────────────────────────
    if ~strcmp(irf_norm, 'none')
        fprintf('[plot_irfs] Shock %d — normalizacion aplicada: %s\n', sidx, irf_norm);
        fprintf('  Factor medio (draw 1): [');
        fprintf(' %.4f', scale_factors(:, 1));
        fprintf(' ]\n');
    end
end

end

