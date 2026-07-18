function T_long = build_erpt_comparison_long(ERPT_by_spec, spec_names, shock_names_sel)
%BUILD_ERPT_COMPARISON_LONG  Tabla ERPT en formato LARGO (tidy) para N specs.
%
%   T_long = BUILD_ERPT_COMPARISON_LONG(ERPT_by_spec, spec_names)
%   T_long = BUILD_ERPT_COMPARISON_LONG(ERPT_by_spec, spec_names, shock_names_sel)
%
%   Formato tidy: una fila por (spec, shock, price_var, horizon).
%     spec | shock | price_var | horizon | p_lo | median | p_hi
%
%   ── Motivo (ERPT-Chat 8) ─────────────────────────────────────────────────
%   Complementa build_erpt_comparison.m (formato ANCHO). Con 16 specs el
%   formato ancho tiene 16*3 = 48 columnas de valores: perfecto para Excel
%   (comparacion lado a lado), ilegible en consola. El formato largo escala
%   a cualquier numero de specs sin crecer en ancho (aqui 16*4*3*5 = 960
%   filas) y es directamente pivotable en Excel.
%
%   A diferencia de la version ANCHA, esta NO exige que todas las specs
%   compartan el mismo vector de horizontes ni las mismas price_vars: cada
%   spec aporta sus propias filas con sus propios horizontes/price_vars
%   (tomados de ERPT_by_spec.(spec).horizons / .price_vars). Igual que la
%   version ancha, usa band_lo(1,:)/band_hi(1,:) (primera banda de
%   Cfg.CRED_BANDS) y orden de columnas p_lo|median|p_hi (ERPT-Chat 5).
%
%   ── Entradas ─────────────────────────────────────────────────────────────
%     ERPT_by_spec     struct, un campo por spec_name = salida de calculate_erpt.m
%     spec_names       cell array de nombres de spec (orden de salida)
%     shock_names_sel  (opcional) cell array de nombres de choque a incluir,
%                      resueltos por NOMBRE contra ERPT.shocks(k).name
%                      (default {'Cam','Dem','Ofe'} -- 3 choques nombrados
%                      del Ejercicio A tras eliminar Mon en ERPT-Chat 9;
%                      antes de ERPT-Chat 9 el default incluia 'Mon').
%
%   ── Salida ───────────────────────────────────────────────────────────────
%     T_long   table -- spec | shock | price_var | horizon | p_lo | median | p_hi
%
%   Vive en projects/erpt/src/ (Tipo S -- no toca src/ compartido, no
%   requiere regresion BNW).
%
%   Ver tambien: build_erpt_comparison.m, calculate_erpt.m

if nargin < 3 || isempty(shock_names_sel)
    shock_names_sel = {'Cam', 'Dem', 'Ofe'};
end
if ~iscell(spec_names) || isempty(spec_names)
    error('build_erpt_comparison_long:badSpecNames', ...
        'spec_names debe ser un cell array no vacio.');
end
if ~iscell(shock_names_sel) || isempty(shock_names_sel)
    error('build_erpt_comparison_long:badShockNames', ...
        'shock_names_sel debe ser un cell array no vacio.');
end

n_specs  = numel(spec_names);
n_shocks = numel(shock_names_sel);

% Pre-conteo de filas para pre-asignar (evita crecer en el loop).
n_rows_est = 0;
for ss = 1:n_specs
    sn = spec_names{ss};
    if ~isfield(ERPT_by_spec, sn)
        error('build_erpt_comparison_long:missingSpec', ...
            'ERPT_by_spec no tiene el campo ''%s''.', sn);
    end
    n_rows_est = n_rows_est + n_shocks * numel(ERPT_by_spec.(sn).price_vars) ...
                 * numel(ERPT_by_spec.(sn).horizons);
end

spec_col  = cell(n_rows_est, 1);
shock_col = cell(n_rows_est, 1);
price_col = cell(n_rows_est, 1);
hz_col    = zeros(n_rows_est, 1);
plo_col   = zeros(n_rows_est, 1);
med_col   = zeros(n_rows_est, 1);
phi_col   = zeros(n_rows_est, 1);

r = 0;
for ss = 1:n_specs
    sn         = spec_names{ss};
    ERPT_ss    = ERPT_by_spec.(sn);
    horizons   = ERPT_ss.horizons(:)';
    price_vars = ERPT_ss.price_vars;
    names_ss   = {ERPT_ss.shocks.name};

    for kk = 1:n_shocks
        shock_name = shock_names_sel{kk};
        k_idx = find(strcmp(names_ss, shock_name), 1);
        if isempty(k_idx)
            error('build_erpt_comparison_long:shockNotFound', ...
                'Choque ''%s'' no encontrado en ERPT_by_spec.%s (disponibles: %s).', ...
                shock_name, sn, strjoin(names_ss, ', '));
        end
        prices_arr = ERPT_ss.shocks(k_idx).prices;
        pvar_names = {prices_arr.var};

        for pp = 1:numel(price_vars)
            price_var = price_vars{pp};
            p_idx = find(strcmp(pvar_names, price_var), 1);
            if isempty(p_idx)
                error('build_erpt_comparison_long:priceVarNotFound', ...
                    'Variable de precio ''%s'' no encontrada en ERPT_by_spec.%s, choque %s.', ...
                    price_var, sn, shock_name);
            end

            % band_lo/band_hi son [n_bands x nh], median es [1 x nh], todos
            % alineados a ERPT_ss.horizons -> el indice hh es directo.
            for hh = 1:numel(horizons)
                r = r + 1;
                spec_col{r}  = sn;
                shock_col{r} = shock_name;
                price_col{r} = price_var;
                hz_col(r)    = horizons(hh);
                plo_col(r)   = prices_arr(p_idx).band_lo(1, hh);
                med_col(r)   = prices_arr(p_idx).median(hh);
                phi_col(r)   = prices_arr(p_idx).band_hi(1, hh);
            end
        end
    end
end

T_long = table(spec_col(1:r), shock_col(1:r), price_col(1:r), hz_col(1:r), ...
    plo_col(1:r), med_col(1:r), phi_col(1:r), ...
    'VariableNames', {'spec', 'shock', 'price_var', 'horizon', 'p_lo', 'median', 'p_hi'});

end

