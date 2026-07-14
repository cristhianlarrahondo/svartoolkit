function T = build_irf_comparison(Results_by_spec, Dataset_by_spec, Cfg_by_spec, spec_names, kind, horizons_sel)
%BUILD_IRF_COMPARISON  Tabla comparativa cruzada de IRFs/CIRFs entre N specs.
%
%   T = BUILD_IRF_COMPARISON(Results_by_spec, Dataset_by_spec, Cfg_by_spec, ...
%           spec_names, kind)
%   T = BUILD_IRF_COMPARISON(..., horizons_sel)
%
%   Construye una tabla ANCHA (mismo patron que build_erpt_comparison.m):
%   una fila por combinacion choque x variable_respuesta x horizonte, con
%   un bloque de 3 columnas (mediana | p_lo | p_hi) por cada spec.
%
%   ── Decision confirmada en ERPT-Chat 5 ──────────────────────────────────
%     - Alcance: TODOS los choques (Cfg.SHOCK_IDX='all', 1:nvar) x TODAS
%       las variables endogenas (no solo Cam/Dem/Ofe x price_vars, a
%       diferencia de build_erpt_comparison.m).
%     - Horizontes: subconjunto explicito (default: Cfg.ERPT_HORIZONS de la
%       primera spec) por legibilidad -- 6 choques x 6 variables x 37
%       horizontes x N specs seria excesivo para una tabla ancha.
%     - Se exige que todas las specs compartan nvar, var_names (orden),
%       shock_idx resuelto y Cfg.CRED_BANDS -- error explicito si no.
%
%   ── Entradas ─────────────────────────────────────────────────────────────
%     Results_by_spec   struct, un campo por spec_name, salida de run_is.m
%     Dataset_by_spec   struct, un campo por spec_name, salida de load_data.m
%     Cfg_by_spec       struct, un campo por spec_name (usa .SHOCK_NAMES,
%                       .CRED_BANDS)
%     spec_names        cell array de nombres de spec, EN EL ORDEN deseado
%     kind              'irf' | 'cirf'
%     horizons_sel      (opcional) vector de horizontes 0-based. Default:
%                       Cfg_by_spec.(spec_names{1}).ERPT_HORIZONS
%
%   ── Salida ───────────────────────────────────────────────────────────────
%     T   table -- shock | variable | horizon | <spec>_median | <spec>_p_lo
%         | <spec>_p_hi (bloque repetido por cada spec, orden de spec_names)
%
%   Vive en projects/erpt/src/ (Tipo S -- no toca src/ compartido, no
%   requiere regresion BNW).
%
%   Ver tambien: build_erpt_comparison.m, build_fevd_comparison.m,
%   select_irfs.m, compute_cirfs.m

if nargin < 5 || isempty(kind)
    error('build_irf_comparison:missingKind', 'kind es obligatorio: ''irf'' o ''cirf''.');
end
kind = lower(kind);
if ~ismember(kind, {'irf', 'cirf'})
    error('build_irf_comparison:badKind', 'kind debe ser ''irf'' o ''cirf''. Recibido: ''%s''.', kind);
end
if ~iscell(spec_names) || isempty(spec_names)
    error('build_irf_comparison:badSpecNames', 'spec_names debe ser un cell array no vacio.');
end
n_specs = numel(spec_names);

for ss = 1:n_specs
    sn = spec_names{ss};
    if ~isfield(Results_by_spec, sn) || ~isfield(Dataset_by_spec, sn) || ~isfield(Cfg_by_spec, sn)
        error('build_irf_comparison:missingSpec', ...
            'Results_by_spec/Dataset_by_spec/Cfg_by_spec deben tener el campo ''%s''.', sn);
    end
end

if nargin < 6 || isempty(horizons_sel)
    Cfg1 = Cfg_by_spec.(spec_names{1});
    if isfield(Cfg1, 'ERPT_HORIZONS') && ~isempty(Cfg1.ERPT_HORIZONS)
        horizons_sel = Cfg1.ERPT_HORIZONS;
    else
        horizons_sel = [3 6 12 24 36];
    end
end
horizons_sel = horizons_sel(:)';
nh = numel(horizons_sel);

%% ── Validar consistencia entre specs (nvar, var_names, cred_bands) ──────
var_names_ref  = {};
cred_bands_ref = [];
for ss = 1:n_specs
    sn = spec_names{ss};
    Dataset_ss = Dataset_by_spec.(sn);
    Cfg_ss     = Cfg_by_spec.(sn);

    endo_mask_ss = strcmp(Dataset_ss.var_roles, 'endogenous');
    vn_ss = Dataset_ss.var_names(endo_mask_ss);

    cb_ss = [0.16 0.84];
    if isfield(Cfg_ss, 'CRED_BANDS') && ~isempty(Cfg_ss.CRED_BANDS)
        cb_ss = Cfg_ss.CRED_BANDS(1, :);
    end

    if isempty(var_names_ref)
        var_names_ref  = vn_ss;
        cred_bands_ref = cb_ss;
    else
        if ~isequal(var_names_ref, vn_ss)
            error('build_irf_comparison:mismatchedVarNames', ...
                'Las specs comparadas no comparten las mismas variables endogenas (orden incluido): ''%s''.', sn);
        end
        if ~isequal(cred_bands_ref, cb_ss)
            error('build_irf_comparison:mismatchedCredBands', ...
                'Las specs comparadas no comparten el mismo Cfg.CRED_BANDS (primera banda): ''%s'' tiene %s, se esperaba %s.', ...
                sn, mat2str(cb_ss), mat2str(cred_bands_ref));
        end
    end
end
nvar = numel(var_names_ref);

%% ── Extraer, por spec, IRFs/CIRFs de todos los choques x todas las vars ──
data_by_spec  = struct();   % data_by_spec.(sn){j} = [horizon+1 x nvar x ndraws]
labels_shock_ref = {};
for ss = 1:n_specs
    sn = spec_names{ss};
    Results_ss = Results_by_spec.(sn);
    Dataset_ss = Dataset_by_spec.(sn);
    Cfg_ss     = Cfg_by_spec.(sn);

    if ~isfield(Results_ss, 'LtildeStruct')
        error('build_irf_comparison:missingLtilde', 'Results_by_spec.%s.LtildeStruct no existe.', sn);
    end
    LtildeStruct_ss = Results_ss.LtildeStruct;

    endo_mask_ss = strcmp(Dataset_ss.var_roles, 'endogenous');
    if isfield(Dataset_ss, 'var_labels') && ~isempty(Dataset_ss.var_labels)
        LtildeStruct_ss.var_labels = Dataset_ss.var_labels(endo_mask_ss);
    end

    shock_names_ss = {};
    if isfield(Cfg_ss, 'SHOCK_NAMES') && ~isempty(Cfg_ss.SHOCK_NAMES)
        shock_names_ss = Cfg_ss.SHOCK_NAMES;
    end

    [irfs_by_shock_ss, labels_shock_ss, ~, shock_idx_resolved_ss] = ...
        select_irfs(LtildeStruct_ss, 'all', 1:nvar, shock_names_ss);

    if numel(shock_idx_resolved_ss) ~= nvar
        error('build_irf_comparison:unexpectedShockCount', ...
            '''%s'': se esperaban %d choques (''all''), se obtuvieron %d.', sn, nvar, numel(shock_idx_resolved_ss));
    end

    if strcmp(kind, 'cirf')
        for j = 1:numel(irfs_by_shock_ss)
            irfs_by_shock_ss{j} = compute_cirfs(irfs_by_shock_ss{j});
        end
    end

    if isempty(labels_shock_ref)
        labels_shock_ref = labels_shock_ss;
    elseif ~isequal(labels_shock_ref, labels_shock_ss)
        error('build_irf_comparison:mismatchedShockNames', ...
            'Las specs comparadas no resuelven los mismos nombres de choque: ''%s'' tiene {%s}, se esperaba {%s}.', ...
            sn, strjoin(labels_shock_ss, ','), strjoin(labels_shock_ref, ','));
    end

    data_by_spec.(sn) = irfs_by_shock_ss;
end

%% ── Nombres de columnas por spec (bloque de 3) ───────────────────────────
col_names = cell(1, n_specs * 3);
for ss = 1:n_specs
    safe_sn = regexprep(spec_names{ss}, '[^a-zA-Z0-9_]', '_');
    col_names{(ss-1)*3 + 1} = sprintf('%s_median', safe_sn);
    col_names{(ss-1)*3 + 2} = sprintf('%s_p_lo', safe_sn);
    col_names{(ss-1)*3 + 3} = sprintf('%s_p_hi', safe_sn);
end

%% ── Construir filas: shock x variable x horizon ──────────────────────────
n_shocks  = nvar;   % 'all' -> 1:nvar
n_rows    = n_shocks * nvar * nh;
row_shock = cell(n_rows, 1);
row_var   = cell(n_rows, 1);
row_hz    = zeros(n_rows, 1);
data_cols = cell(n_rows, n_specs * 3);

r = 0;
for kk = 1:n_shocks
    shock_name = labels_shock_ref{kk};
    for vv = 1:nvar
        var_name = var_names_ref{vv};
        for hh = 1:nh
            r = r + 1;
            row_shock{r} = shock_name;
            row_var{r}   = var_name;
            row_hz(r)    = horizons_sel(hh);
            h_idx        = horizons_sel(hh) + 1;   % 1-based

            for ss = 1:n_specs
                sn      = spec_names{ss};
                irfs_kk = data_by_spec.(sn){kk};        % [horizon+1 x nvar x ndraws]
                sl      = irfs_kk(h_idx, vv, :);
                cb      = cred_bands_ref;

                data_cols{r, (ss-1)*3 + 1} = quantile(sl(:), 0.50);
                data_cols{r, (ss-1)*3 + 2} = quantile(sl(:), cb(1));
                data_cols{r, (ss-1)*3 + 3} = quantile(sl(:), cb(2));
            end
        end
    end
end

all_rows      = [row_shock, row_var, num2cell(row_hz), data_cols];
all_col_names = [{'shock', 'variable', 'horizon'}, col_names];
T             = cell2table(all_rows, 'VariableNames', all_col_names);

end
