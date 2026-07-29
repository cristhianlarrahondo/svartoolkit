function erpt_print_cirf_digest(LtildeStruct, Dataset, Cfg)
%ERPT_PRINT_CIRF_DIGEST  Digesto de consola para CIRF (identico al helper
%   de validate_erpt16/17.m -- print_summary.m no soporta CIRF directamente).

    cred_bands = [0.16 0.84];
    if isfield(Cfg, 'CRED_BANDS') && ~isempty(Cfg.CRED_BANDS)
        cred_bands = Cfg.CRED_BANDS;
    end
    n_bands = size(cred_bands, 1);

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
    summary_horizons = [0 4 8 20 40];
    if isfield(Cfg, 'SUMMARY_HORIZONS') && ~isempty(Cfg.SUMMARY_HORIZONS)
        summary_horizons = Cfg.SUMMARY_HORIZONS;
    end

    endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
    all_labels = Dataset.var_labels(endo_mask);
    LtildeStruct.var_labels = all_labels;

    [irfs_by_shock, label_shock_arr, label_resp, shock_idx_resolved] = ...
        select_irfs(LtildeStruct, shock_idx_req, response_idx, shock_names);

    horizon_max = LtildeStruct.horizon;
    h_valid = summary_horizons(summary_horizons >= 0 & summary_horizons <= horizon_max);
    h_idx   = h_valid + 1;
    nh      = numel(h_idx);
    n_shocks = numel(shock_idx_resolved);

    sep_wide = repmat('=', 1, 72);
    sep_thin = repmat('-', 1, 72);

    for j = 1:n_shocks
        cirfs_j = compute_cirfs(irfs_by_shock{j});
        nresp   = size(cirfs_j, 2);

        fprintf('\n%s\n', sep_wide);
        fprintf('  CIRF SUMMARY (digesto)   Shock: %s\n', label_shock_arr{j});
        fprintf('%s\n', sep_wide);

        band_hdr = '';
        for bb = 1:n_bands
            band_hdr = [band_hdr, sprintf('  [p%.0f, p%.0f]         ', ...
                cred_bands(bb,1)*100, cred_bands(bb,2)*100)]; %#ok<AGROW>
        end
        fprintf('  %-20s  h   %8s  %s\n', 'Respuesta', 'Mediana', strtrim(band_hdr));
        fprintf('%s\n', sep_thin);

        for jj = 1:nresp
            for ii = 1:nh
                sl = squeeze(cirfs_j(h_idx(ii), jj, :));
                med_val = quantile(sl, 0.50);
                band_str = '';
                for bb = 1:n_bands
                    q = quantile(sl, cred_bands(bb, :));
                    band_str = [band_str, sprintf('  [%8.4f, %8.4f]', q(1), q(2))]; %#ok<AGROW>
                end
                if ii == 1
                    fprintf('  %-20s  %2d  %8.4f%s\n', label_resp{jj}, h_valid(ii), med_val, band_str);
                else
                    fprintf('  %-20s  %2d  %8.4f%s\n', '', h_valid(ii), med_val, band_str);
                end
            end
            fprintf('%s\n', sep_thin);
        end
    end
    fprintf('\n');
end
