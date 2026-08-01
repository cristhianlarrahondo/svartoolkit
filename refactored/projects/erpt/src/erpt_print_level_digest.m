function erpt_print_level_digest(Level, summary_horizons)
%ERPT_PRINT_LEVEL_DIGEST  Digesto de consola del nivel acumulado L(h)
%   (Figura 2, ERPT-Chat 21 decision 2). Mismo formato tabular que
%   erpt_print_cirf_digest.m (que reemplaza en los analisis_*.m), pero
%   sobre el objeto Level de build_level_response.m en vez de la CIRF
%   generica retirada.
%
%   ERPT_PRINT_LEVEL_DIGEST(Level)
%   ERPT_PRINT_LEVEL_DIGEST(Level, summary_horizons)
%
%   summary_horizons  vector 0-based de horizontes a imprimir (default
%                     [0 4 8 20 40], filtrado contra el maximo disponible
%                     en Level.horizons -- mismo default que print_summary.m).
%
%   Vive en projects/erpt/src/ -- Tipo S, no toca src/ compartido.

if nargin < 2 || isempty(summary_horizons)
    summary_horizons = [0 4 8 20 40];
end

horizon_max = Level.horizons(end);
h_valid = summary_horizons(summary_horizons >= 0 & summary_horizons <= horizon_max);
if isempty(h_valid)
    fprintf('[erpt_print_level_digest] Ningun horizonte solicitado esta dentro de [0, %d].\n', horizon_max);
    return;
end
h_idx = h_valid + 1;   % Level.horizons(1) = horizonte 0
nh    = numel(h_idx);

cred_bands = Level.cred_bands;
n_bands    = size(cred_bands, 1);

sep_wide = repmat('=', 1, 72);
sep_thin = repmat('-', 1, 72);

for j = 1:numel(Level.shocks)
    sh = Level.shocks(j);

    fprintf('\n%s\n', sep_wide);
    fprintf('  NIVEL L(h) SUMMARY (Figura 2)   Shock: %s\n', sh.name);
    fprintf('%s\n', sep_wide);

    band_hdr = '';
    for bb = 1:n_bands
        band_hdr = [band_hdr, sprintf('  [p%.0f, p%.0f]         ', ...
            cred_bands(bb,1)*100, cred_bands(bb,2)*100)]; %#ok<AGROW>
    end
    fprintf('  %-20s  h   %8s  %s\n', 'Variable', 'Mediana', strtrim(band_hdr));
    fprintf('%s\n', sep_thin);

    for v = 1:numel(sh.vars)
        for ii = 1:nh
            med_val = sh.vars(v).median(h_idx(ii));
            band_str = '';
            for bb = 1:n_bands
                band_str = [band_str, sprintf('  [%8.4f, %8.4f]', ...
                    sh.vars(v).band_lo(bb, h_idx(ii)), sh.vars(v).band_hi(bb, h_idx(ii)))]; %#ok<AGROW>
            end
            if ii == 1
                fprintf('  %-20s  %2d  %8.4f%s\n', sh.vars(v).var, h_valid(ii), med_val, band_str);
            else
                fprintf('  %-20s  %2d  %8.4f%s\n', '', h_valid(ii), med_val, band_str);
            end
        end
        fprintf('%s\n', sep_thin);
    end
end
fprintf('\n');

end
