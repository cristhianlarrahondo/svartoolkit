function [T_erpt, T_diag] = build_erpt_comparison(ERPT_by_spec, Results_by_spec, Cfg_by_spec, spec_names, shock_names_sel)
%BUILD_ERPT_COMPARISON  Tabla comparativa cruzada de ERPT entre N specs.
%
%   [T_erpt, T_diag] = BUILD_ERPT_COMPARISON(ERPT_by_spec, Results_by_spec, Cfg_by_spec, spec_names)
%   [T_erpt, T_diag] = BUILD_ERPT_COMPARISON(..., shock_names_sel)
%
%   Construye una tabla ANCHA (mismo patron que export_results.m): una
%   fila por combinacion choque x variable_de_precio x horizonte, con un
%   bloque de 3 columnas (mediana | p_lo | p_hi) por cada spec comparada.
%
%   ── Decisiones confirmadas en ERPT-Chat 4 ───────────────────────────────
%     - Choques incluidos: solo los NOMBRADOS por defecto {'Cam','Dem','Ofe'}
%       (NO los 3 residuales sin nombre economico — override posible via
%       shock_names_sel si un chat futuro lo requiere).
%     - Horizontes: TODOS los de Cfg.ERPT_HORIZONS. Se exige que las N
%       specs comparadas compartan el MISMO vector de horizontes y el
%       mismo conjunto de price_vars — si no, error explicito (no se
%       intenta alinear/interpolar entre vectores distintos).
%     - a/a y m/m se comparan lado a lado SIN ajuste de escala (decision 4,
%       ERPT-Chat 1: mismo vector de horizontes, misma escala de meses).
%     - ratio por draw (nunca ratio de medianas) ya viene resuelto en
%       ERPT_by_spec.(spec).shocks(k).prices(p).median/band_lo/band_hi —
%       esta funcion solo tabula, no recalcula ratios.
%     - ne y tasa de aceptacion de cada corrida van junto a la tabla ERPT,
%       en una tabla separada (T_diag) del mismo archivo de salida.
%
%   ── Entradas ─────────────────────────────────────────────────────────────
%     ERPT_by_spec      struct, un campo por spec_name (nombre de campo =
%                        spec_names{k}), cada uno = salida de calculate_erpt.m
%     Results_by_spec    struct, un campo por spec_name, salida de run_is.m
%                        (usa .ne, .uw, .t_elapsed)
%     Cfg_by_spec        struct, un campo por spec_name (usa .ND)
%     spec_names         cell array de nombres de spec, EN EL ORDEN
%                        deseado de columnas/filas de salida
%     shock_names_sel    (opcional) cell array de nombres de choque a
%                        incluir, resueltos por NOMBRE contra
%                        ERPT.shocks(k).name (default {'Cam','Dem','Ofe'})
%
%   ── Salidas ──────────────────────────────────────────────────────────────
%     T_erpt   table -- shock | price_var | horizon | <spec>_median |
%              <spec>_p_lo | <spec>_p_hi (bloque repetido por cada spec,
%              en el orden de spec_names)
%     T_diag   table -- spec | nd | ne | ess_ratio | accept_rate | tiempo_s
%
%   Vive en projects/erpt/src/ (Tipo S — no toca src/ compartido, no
%   requiere regresion BNW).
%
%   Ver tambien: calculate_erpt.m, save_erpt_run.m, export_results.m

if nargin < 5 || isempty(shock_names_sel)
    shock_names_sel = {'Cam', 'Dem', 'Ofe'};
end
if ~iscell(spec_names) || isempty(spec_names)
    error('build_erpt_comparison:badSpecNames', ...
        'spec_names debe ser un cell array no vacio.');
end
if ~iscell(shock_names_sel) || isempty(shock_names_sel)
    error('build_erpt_comparison:badShockNames', ...
        'shock_names_sel debe ser un cell array no vacio.');
end

n_specs = numel(spec_names);

%% ── Validar presencia de cada spec en las 3 structs de entrada ───────────
for ss = 1:n_specs
    sn = spec_names{ss};
    if ~isfield(ERPT_by_spec, sn)
        error('build_erpt_comparison:missingSpecErpt', ...
            'ERPT_by_spec no tiene el campo ''%s''.', sn);
    end
    if ~isfield(Results_by_spec, sn)
        error('build_erpt_comparison:missingSpecResults', ...
            'Results_by_spec no tiene el campo ''%s''.', sn);
    end
    if ~isfield(Cfg_by_spec, sn)
        error('build_erpt_comparison:missingSpecCfg', ...
            'Cfg_by_spec no tiene el campo ''%s''.', sn);
    end
end

%% ── Validar que todas las specs compartan horizontes y price_vars ────────
horizons_ref   = [];
price_vars_ref = {};
for ss = 1:n_specs
    sn    = spec_names{ss};
    h_ss  = ERPT_by_spec.(sn).horizons;
    pv_ss = ERPT_by_spec.(sn).price_vars;
    if isempty(horizons_ref)
        horizons_ref   = h_ss;
        price_vars_ref = pv_ss;
    else
        if ~isequal(horizons_ref, h_ss)
            error('build_erpt_comparison:mismatchedHorizons', ...
                ['Las specs comparadas no comparten el mismo vector de ' ...
                 'horizontes: ''%s'' tiene %s, se esperaba %s (mismo ' ...
                 'vector para todas — ver ERPT-Chat 1, decision 4: a/a ' ...
                 'y m/m van lado a lado sin ajuste de escala).'], ...
                sn, mat2str(h_ss), mat2str(horizons_ref));
        end
        if ~isequal(sort(price_vars_ref), sort(pv_ss))
            error('build_erpt_comparison:mismatchedPriceVars', ...
                'Las specs comparadas no comparten las mismas price_vars: ''%s'' tiene {%s}, se esperaba {%s}.', ...
                sn, strjoin(pv_ss, ','), strjoin(price_vars_ref, ','));
        end
    end
end
horizons   = horizons_ref(:)';
price_vars = price_vars_ref;
nh         = numel(horizons);
n_prices   = numel(price_vars);
n_shocks   = numel(shock_names_sel);

%% ── Nombres de columnas por spec (bloque de 3: median | p_lo | p_hi) ─────
col_names = cell(1, n_specs * 3);
for ss = 1:n_specs
    safe_sn = regexprep(spec_names{ss}, '[^a-zA-Z0-9_]', '_');
    col_names{(ss-1)*3 + 1} = sprintf('%s_median', safe_sn);
    col_names{(ss-1)*3 + 2} = sprintf('%s_p_lo', safe_sn);
    col_names{(ss-1)*3 + 3} = sprintf('%s_p_hi', safe_sn);
end

%% ── Construir filas: shock x price_var x horizon ─────────────────────────
n_rows    = n_shocks * n_prices * nh;
row_shock = cell(n_rows, 1);
row_price = cell(n_rows, 1);
row_hz    = zeros(n_rows, 1);
data_cols = cell(n_rows, n_specs * 3);

r = 0;
for kk = 1:n_shocks
    shock_name = shock_names_sel{kk};
    for pp = 1:n_prices
        price_var = price_vars{pp};
        for hh = 1:nh
            r = r + 1;
            row_shock{r} = shock_name;
            row_price{r} = price_var;
            row_hz(r)    = horizons(hh);

            for ss = 1:n_specs
                sn      = spec_names{ss};
                ERPT_ss = ERPT_by_spec.(sn);

                names_ss = {ERPT_ss.shocks.name};
                k_idx    = find(strcmp(names_ss, shock_name), 1);
                if isempty(k_idx)
                    error('build_erpt_comparison:shockNotFound', ...
                        'Choque ''%s'' no encontrado en ERPT_by_spec.%s (choques disponibles: %s).', ...
                        shock_name, sn, strjoin(names_ss, ', '));
                end

                prices_arr = ERPT_ss.shocks(k_idx).prices;
                pvar_names = {prices_arr.var};
                p_idx      = find(strcmp(pvar_names, price_var), 1);
                if isempty(p_idx)
                    error('build_erpt_comparison:priceVarNotFound', ...
                        'Variable de precio ''%s'' no encontrada en ERPT_by_spec.%s, choque %s.', ...
                        price_var, sn, shock_name);
                end

                h_idx = find(ERPT_ss.horizons == horizons(hh), 1);

                data_cols{r, (ss-1)*3 + 1} = prices_arr(p_idx).median(h_idx);
                data_cols{r, (ss-1)*3 + 2} = prices_arr(p_idx).band_lo(1, h_idx);
                data_cols{r, (ss-1)*3 + 3} = prices_arr(p_idx).band_hi(1, h_idx);
            end
        end
    end
end

all_rows      = [row_shock, row_price, num2cell(row_hz), data_cols];
all_col_names = [{'shock', 'price_var', 'horizon'}, col_names];
T_erpt        = cell2table(all_rows, 'VariableNames', all_col_names);

%% ── T_diag: ne, tasa de aceptacion, tiempo por spec ───────────────────────
diag_rows = cell(n_specs, 6);
for ss = 1:n_specs
    sn     = spec_names{ss};
    Res_ss = Results_by_spec.(sn);
    Cfg_ss = Cfg_by_spec.(sn);

    if ~isfield(Cfg_ss, 'ND')
        error('build_erpt_comparison:missingND', 'Cfg_by_spec.%s.ND no existe.', sn);
    end
    if ~isfield(Res_ss, 'ne') || ~isfield(Res_ss, 'uw')
        error('build_erpt_comparison:missingResultsFields', ...
            'Results_by_spec.%s debe traer .ne y .uw (salida de run_is.m).', sn);
    end

    nd_ss       = Cfg_ss.ND;
    ne_ss       = Res_ss.ne;
    ess_ratio   = ne_ss / nd_ss;
    accept_rate = sum(Res_ss.uw > 0) / nd_ss;
    tiempo_s    = NaN;
    if isfield(Res_ss, 't_elapsed')
        tiempo_s = Res_ss.t_elapsed;
    end

    diag_rows(ss, :) = {sn, nd_ss, ne_ss, ess_ratio, accept_rate, tiempo_s};
end
T_diag = cell2table(diag_rows, 'VariableNames', ...
    {'spec', 'nd', 'ne', 'ess_ratio', 'accept_rate', 'tiempo_s'});

end
