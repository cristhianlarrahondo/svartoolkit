function T_by_shock = build_fevd_comparison(Results_by_spec, Dataset_by_spec, Cfg_by_spec, spec_names, horizons_sel)
%BUILD_FEVD_COMPARISON  Tabla comparativa cruzada de FEVD entre N specs, por choque.
%
%   T_by_shock = BUILD_FEVD_COMPARISON(Results_by_spec, Dataset_by_spec, ...
%       Cfg_by_spec, spec_names)
%   T_by_shock = BUILD_FEVD_COMPARISON(..., horizons_sel)
%
%   ── Decision confirmada en ERPT-Chat 5 ──────────────────────────────────
%     La comparacion cruzada de FEVD se organiza POR CHOQUE (a diferencia
%     de plot_fevd.m/export_results.m, que organizan por VARIABLE dentro de
%     una misma spec). Para cada choque calculado (Results.FEVD_shock_idx),
%     se arma una tabla ANCHA: fila = variable x horizonte, bloque de 3
%     columnas (mediana | p_lo | p_hi) por cada spec comparada.
%
%   ── Entradas ─────────────────────────────────────────────────────────────
%     Results_by_spec   struct, un campo por spec_name, salida de run_is.m
%                       (usa .FEVD, .FEVD_shock_idx, .FEVD_horizons)
%     Dataset_by_spec   struct, un campo por spec_name, salida de load_data.m
%     Cfg_by_spec       struct, un campo por spec_name (usa .SHOCK_NAMES,
%                       .CRED_BANDS)
%     spec_names        cell array de nombres de spec, EN EL ORDEN deseado
%     horizons_sel      (opcional) vector de horizontes. Default:
%                       Cfg_by_spec.(spec_names{1}).ERPT_HORIZONS. Debe
%                       ser subconjunto de Results.FEVD_horizons en TODAS
%                       las specs comparadas -- error explicito si no.
%
%   ── Salida ───────────────────────────────────────────────────────────────
%     T_by_shock   struct, un campo por nombre de choque resuelto (p.ej.
%                  'Cam', 'Dem', 'Ofe', 'shock4', ...). Cada campo es una
%                  tabla: variable | horizon | <spec>_median | <spec>_p_lo
%                  | <spec>_p_hi
%
%   Vive en projects/erpt/src/ (Tipo S -- no toca src/ compartido, no
%   requiere regresion BNW).
%
%   Ver tambien: build_erpt_comparison.m, build_irf_comparison.m,
%   plot_fevd.m, export_results.m

if ~iscell(spec_names) || isempty(spec_names)
    error('build_fevd_comparison:badSpecNames', 'spec_names debe ser un cell array no vacio.');
end
n_specs = numel(spec_names);

for ss = 1:n_specs
    sn = spec_names{ss};
    if ~isfield(Results_by_spec, sn) || ~isfield(Dataset_by_spec, sn) || ~isfield(Cfg_by_spec, sn)
        error('build_fevd_comparison:missingSpec', ...
            'Results_by_spec/Dataset_by_spec/Cfg_by_spec deben tener el campo ''%s''.', sn);
    end
    Res_ss = Results_by_spec.(sn);
    if ~isfield(Res_ss, 'FEVD') || ~isfield(Res_ss, 'FEVD_shock_idx') || ~isfield(Res_ss, 'FEVD_horizons')
        error('build_fevd_comparison:missingFevdFields', ...
            'Results_by_spec.%s debe traer .FEVD, .FEVD_shock_idx y .FEVD_horizons.', sn);
    end
end

if nargin < 5 || isempty(horizons_sel)
    Cfg1 = Cfg_by_spec.(spec_names{1});
    if isfield(Cfg1, 'ERPT_HORIZONS') && ~isempty(Cfg1.ERPT_HORIZONS)
        horizons_sel = Cfg1.ERPT_HORIZONS;
    else
        horizons_sel = [3 6 12 24 36];
    end
end
horizons_sel = horizons_sel(:)';
nh = numel(horizons_sel);

%% ── Validar consistencia entre specs (var_names, fevd_shock_idx, cred_bands, horizontes) ──
var_names_ref     = {};
fevd_shock_idx_ref = [];
cred_bands_ref    = [];
h_idx_by_spec     = struct();   % indices dentro de Results.FEVD_horizons para horizons_sel

for ss = 1:n_specs
    sn = spec_names{ss};
    Dataset_ss = Dataset_by_spec.(sn);
    Cfg_ss     = Cfg_by_spec.(sn);
    Res_ss     = Results_by_spec.(sn);

    endo_mask_ss = strcmp(Dataset_ss.var_roles, 'endogenous');
    vn_ss = Dataset_ss.var_names(endo_mask_ss);

    cb_ss = [0.16 0.84];
    if isfield(Cfg_ss, 'CRED_BANDS') && ~isempty(Cfg_ss.CRED_BANDS)
        cb_ss = Cfg_ss.CRED_BANDS(1, :);
    end

    fevd_shock_idx_ss = Res_ss.FEVD_shock_idx(:)';
    fevd_horizons_ss  = Res_ss.FEVD_horizons(:)';

    h_idx_ss = zeros(1, nh);
    for hh = 1:nh
        idx_h = find(fevd_horizons_ss == horizons_sel(hh), 1);
        if isempty(idx_h)
            error('build_fevd_comparison:horizonNotInFevd', ...
                ['Horizonte %d no esta en Results.FEVD_horizons de la spec ''%s'' ' ...
                 '(disponibles: %s).'], horizons_sel(hh), sn, mat2str(fevd_horizons_ss));
        end
        h_idx_ss(hh) = idx_h;
    end
    h_idx_by_spec.(sn) = h_idx_ss;

    if isempty(var_names_ref)
        var_names_ref      = vn_ss;
        fevd_shock_idx_ref = fevd_shock_idx_ss;
        cred_bands_ref     = cb_ss;
    else
        if ~isequal(var_names_ref, vn_ss)
            error('build_fevd_comparison:mismatchedVarNames', ...
                'Las specs comparadas no comparten las mismas variables endogenas (orden incluido): ''%s''.', sn);
        end
        if ~isequal(fevd_shock_idx_ref, fevd_shock_idx_ss)
            error('build_fevd_comparison:mismatchedFevdShockIdx', ...
                'Las specs comparadas no comparten el mismo Results.FEVD_shock_idx: ''%s'' tiene %s, se esperaba %s.', ...
                sn, mat2str(fevd_shock_idx_ss), mat2str(fevd_shock_idx_ref));
        end
        if ~isequal(cred_bands_ref, cb_ss)
            error('build_fevd_comparison:mismatchedCredBands', ...
                'Las specs comparadas no comparten el mismo Cfg.CRED_BANDS (primera banda): ''%s''.', sn);
        end
    end
end
nvar      = numel(var_names_ref);
n_shocks  = numel(fevd_shock_idx_ref);

%% ── Nombres de choque resueltos (mismo criterio para todas las specs) ────
Cfg1 = Cfg_by_spec.(spec_names{1});
shock_names_1 = {};
if isfield(Cfg1, 'SHOCK_NAMES') && ~isempty(Cfg1.SHOCK_NAMES)
    shock_names_1 = Cfg1.SHOCK_NAMES;
end
shock_label = cell(1, n_shocks);
for jj = 1:n_shocks
    shock_label{jj} = resolve_shock_name(shock_names_1, fevd_shock_idx_ref(jj));
end

%% ── Nombres de columnas por spec (bloque de 3) ───────────────────────────
col_names = cell(1, n_specs * 3);
for ss = 1:n_specs
    safe_sn = regexprep(spec_names{ss}, '[^a-zA-Z0-9_]', '_');
    col_names{(ss-1)*3 + 1} = sprintf('%s_median', safe_sn);
    col_names{(ss-1)*3 + 2} = sprintf('%s_p_lo', safe_sn);
    col_names{(ss-1)*3 + 3} = sprintf('%s_p_hi', safe_sn);
end
all_col_names = [{'variable', 'horizon'}, col_names];

%% ── Una tabla por choque: filas = variable x horizonte ──────────────────
T_by_shock = struct();
for jj = 1:n_shocks
    n_rows    = nvar * nh;
    row_var   = cell(n_rows, 1);
    row_hz    = zeros(n_rows, 1);
    data_cols = cell(n_rows, n_specs * 3);

    r = 0;
    for vv = 1:nvar
        var_name = var_names_ref{vv};
        for hh = 1:nh
            r = r + 1;
            row_var{r} = var_name;
            row_hz(r)  = horizons_sel(hh);

            for ss = 1:n_specs
                sn       = spec_names{ss};
                Res_ss   = Results_by_spec.(sn);
                h_idx_ss = h_idx_by_spec.(sn);
                sl       = Res_ss.FEVD(vv, jj, h_idx_ss(hh), :);
                cb       = cred_bands_ref;

                data_cols{r, (ss-1)*3 + 1} = quantile(sl(:), 0.50);
                data_cols{r, (ss-1)*3 + 2} = quantile(sl(:), cb(1));
                data_cols{r, (ss-1)*3 + 3} = quantile(sl(:), cb(2));
            end
        end
    end

    all_rows = [row_var, num2cell(row_hz), data_cols];
    T_shock  = cell2table(all_rows, 'VariableNames', all_col_names);

    field_name = matlab.lang.makeValidName(shock_label{jj});
    T_by_shock.(field_name) = T_shock;
end

end
