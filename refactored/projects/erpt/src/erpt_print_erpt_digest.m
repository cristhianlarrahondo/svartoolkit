function erpt_print_erpt_digest(ERPT, named_shocks, price_vars)
%ERPT_PRINT_ERPT_DIGEST  Digesto de consola de ERPT.shocks (identico al
%   helper de validate_erpt16/17.m).
    names_all = {ERPT.shocks.name};
    horizons  = ERPT.horizons;

    for kk = 1:numel(named_shocks)
        k_idx = find(strcmp(names_all, named_shocks{kk}), 1);
        if isempty(k_idx)
            fprintf('  [aviso] choque %s no encontrado en ERPT.shocks.\n', named_shocks{kk});
            continue;
        end
        prices_arr = ERPT.shocks(k_idx).prices;
        pvar_names = {prices_arr.var};

        fprintf('  Choque: %s\n', named_shocks{kk});
        for pp = 1:numel(price_vars)
            p_idx = find(strcmp(pvar_names, price_vars{pp}), 1);
            if isempty(p_idx)
                fprintf('    [aviso] price_var %s no encontrada.\n', price_vars{pp});
                continue;
            end
            fprintf('    %-10s', price_vars{pp});
            for hh = 1:numel(horizons)
                fprintf('  h=%-2d: %7.3f [%6.3f, %6.3f]', horizons(hh), ...
                    prices_arr(p_idx).median(hh), ...
                    prices_arr(p_idx).band_lo(1, hh), prices_arr(p_idx).band_hi(1, hh));
            end
            fprintf('\n');
        end
        fprintf('\n');
    end
end
