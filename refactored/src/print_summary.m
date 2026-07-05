function print_summary(LtildeStruct, Dataset, Cfg)
%PRINT_SUMMARY  Imprime mediana + intervalos de credibilidad para horizontes clave.
%
%   PRINT_SUMMARY(LtildeStruct, Dataset, Cfg)
%
%   Imprime en consola una tabla tabular:
%     Shock × Respuesta × Horizonte | Mediana | [p_lo, p_hi]
%
%   Campos de Cfg usados (todos con defaults seguros):
%     SUMMARY_HORIZONS  vector 0-based  (default [0 4 8 20 40])
%     CRED_BANDS        [N x 2]         (default [0.16 0.84])
%     SHOCK_IDX         escalar         (default LtildeStruct.shock_idx)
%     RESP_IDX          vector          (default todos)
%
%   Soporta PFA (3D) e IS (4D) transparentemente vía select_irfs.

%% ── Guard: corrida omitida (p.ej. PFA con >1 choque restringido) ────────
[skip_run, skip_reason] = is_run_skipped(LtildeStruct);
if skip_run
    fprintf('[print_summary] Omitido: %s\n', skip_reason);
    return;
end

%% ── Defaults de Cfg ──────────────────────────────────────────────────────
summary_horizons = [0 4 8 20 40];
if isfield(Cfg, 'SUMMARY_HORIZONS') && ~isempty(Cfg.SUMMARY_HORIZONS)
    summary_horizons = Cfg.SUMMARY_HORIZONS;
end

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

shock_idx = LtildeStruct.shock_idx;
if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
    shock_idx = Cfg.SHOCK_IDX;
end

response_idx = 1:LtildeStruct.nvar;
if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
    response_idx = Cfg.RESP_IDX;
end

%% ── Adjuntar var_labels a LtildeStruct ─────────────────────────────────
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
all_labels = Dataset.var_labels(endo_mask);
LtildeStruct.var_labels = all_labels;

%% ── Extraer IRFs del subconjunto shock-response ─────────────────────────
[irfs, label_shock, label_resp] = select_irfs(LtildeStruct, shock_idx, response_idx);
% irfs: [horizon+1, nresp, ndraws]

horizon_max = LtildeStruct.horizon;
nresp       = size(irfs, 2);

%% ── Filtrar y validar horizontes pedidos ─────────────────────────────────
% Convertir de 0-based a índices 1-based
h_valid = summary_horizons(summary_horizons >= 0 & summary_horizons <= horizon_max);
if isempty(h_valid)
    fprintf('[print_summary] Ningún horizonte en SUMMARY_HORIZONS está dentro de [0, %d].\n', horizon_max);
    return;
end
h_idx = h_valid + 1;   % índices 1-based en el array

%% ── Calcular estadísticos ────────────────────────────────────────────────
% med_mat   : [numel(h_idx), nresp]
% bands_lo  : [n_bands, numel(h_idx), nresp]
% bands_hi  : [n_bands, numel(h_idx), nresp]
nh = numel(h_idx);
med_mat  = zeros(nh, nresp);
bands_lo = zeros(n_bands, nh, nresp);
bands_hi = zeros(n_bands, nh, nresp);

for ii = 1:nh
    for jj = 1:nresp
        sl = irfs(h_idx(ii), jj, :);
        sl = sl(:);
        med_mat(ii, jj) = quantile(sl, 0.50);
        for bb = 1:n_bands
            bands_lo(bb, ii, jj) = quantile(sl, cred_bands(bb, 1));
            bands_hi(bb, ii, jj) = quantile(sl, cred_bands(bb, 2));
        end
    end
end

%% ── Modo de estimación ───────────────────────────────────────────────────
mode_str = upper(LtildeStruct.mode);

%% ── Imprimir tabla ───────────────────────────────────────────────────────
sep_wide = repmat('═', 1, 72);
sep_thin = repmat('─', 1, 72);

fprintf('\n%s\n', sep_wide);
fprintf('  IRF SUMMARY — %s   [%s]\n', mode_str, ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf('  Shock: %s\n', label_shock);
fprintf('%s\n', sep_wide);

% Construir encabezado de bandas
band_hdr = '';
for bb = 1:n_bands
    band_hdr = [band_hdr, sprintf('  [p%.0f, p%.0f]         ', ...
        cred_bands(bb,1)*100, cred_bands(bb,2)*100)]; %#ok<AGROW>
end
fprintf('  %-20s  h   %8s  %s\n', 'Respuesta', 'Mediana', strtrim(band_hdr));
fprintf('%s\n', sep_thin);

for jj = 1:nresp
    resp_name = label_resp{jj};
    for ii = 1:nh
        h_label = h_valid(ii);
        med_val = med_mat(ii, jj);

        % Construir string de bandas
        band_str = '';
        for bb = 1:n_bands
            band_str = [band_str, sprintf('  [%8.4f, %8.4f]', ...
                bands_lo(bb, ii, jj), bands_hi(bb, ii, jj))]; %#ok<AGROW>
        end

        if ii == 1
            % Primera fila de esta variable: imprimir nombre
            fprintf('  %-20s  %2d  %8.4f%s\n', resp_name, h_label, med_val, band_str);
        else
            fprintf('  %-20s  %2d  %8.4f%s\n', '', h_label, med_val, band_str);
        end
    end
    fprintf('%s\n', sep_thin);
end

fprintf('\n');

end

