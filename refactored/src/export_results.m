function export_results(Results, Dataset, Cfg)
%EXPORT_RESULTS  Exporta resultados a Excel con 5 hojas estructuradas.
%
%   EXPORT_RESULTS(Results, Dataset, Cfg)
%
%   Genera un archivo .xlsx con las siguientes hojas:
%     1. metadata       — spec, fecha, variables, modo, semilla
%     2. irf_summary    — shock × response × horizon | median | pX | pY
%     3. cirf_summary   — ídem para CIRFs (solo si IRF_TYPE incluye 'cirf')
%     4. fevd_summary   — variable × (sin horizonte fijo) | median | pX | pY
%     5. run_diagnostics — ESS, tasa aceptación, tiempo, nd
%
%   Campos de Cfg usados:
%     SUMMARY_HORIZONS   (default [0 4 8 20 40])
%     CRED_BANDS         (default [0.16 0.84])
%     SHOCK_IDX          (default LtildeStruct.shock_idx)
%     RESP_IDX           (default todos)
%     IRF_TYPE           'irf' | 'cirf' | 'both'  (default 'irf')
%     SPEC_NAME          string  (default 'spec')
%     SEED               scalar  (default 0)
%     MODE               string
%
%   El archivo se guarda en output/tables/<SPEC_NAME>_results.xlsx

%% ── Validar entrada mínima ───────────────────────────────────────────────
if ~isfield(Results, 'LtildeStruct') || isempty(Results.LtildeStruct)
    error('export_results:missingLtilde', ...
        'export_results: Results.LtildeStruct está ausente o vacío.');
end
if ~isfield(Results, 'FEVD') || isempty(Results.FEVD)
    error('export_results:missingFEVD', ...
        'export_results: Results.FEVD está ausente o vacío.');
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

irf_type = 'irf';
if isfield(Cfg, 'IRF_TYPE') && ~isempty(Cfg.IRF_TYPE)
    irf_type = lower(Cfg.IRF_TYPE);
end

spec_name = 'spec';
if isfield(Cfg, 'SPEC_NAME') && ~isempty(Cfg.SPEC_NAME)
    spec_name = Cfg.SPEC_NAME;
end

seed = 0;
if isfield(Cfg, 'SEED')
    seed = Cfg.SEED;
end

mode_str = 'unknown';
if isfield(Cfg, 'MODE') && ~isempty(Cfg.MODE)
    mode_str = lower(Cfg.MODE);
end

%% ── Paths ────────────────────────────────────────────────────────────────
src_root   = fileparts(mfilename('fullpath'));
proj_root  = fileparts(src_root);
tables_dir = fullfile(proj_root, 'output', 'tables');
if ~isfolder(tables_dir)
    mkdir(tables_dir);
end

% Nombre limpio para archivo
safe_name = regexprep(spec_name, '[^a-zA-Z0-9_]', '_');
xlsx_path = fullfile(tables_dir, [safe_name, '_results.xlsx']);

% Eliminar archivo previo si existe (evitar hojas fantasma de versiones anteriores)
if isfile(xlsx_path)
    delete(xlsx_path);
end

%% ── Variables endógenas ──────────────────────────────────────────────────
endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
all_labels = Dataset.var_labels(endo_mask);
nvar       = LtildeStruct_safe(Results).nvar;

LtildeStruct = Results.LtildeStruct;
LtildeStruct.var_labels = all_labels;

shock_idx = LtildeStruct.shock_idx;
if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
    shock_idx = Cfg.SHOCK_IDX;
end

response_idx = 1:nvar;
if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
    response_idx = Cfg.RESP_IDX;
    response_idx = response_idx(response_idx >= 1 & response_idx <= nvar);
end

%% ── Extraer IRFs ─────────────────────────────────────────────────────────
[irfs_raw, label_shock, label_resp] = select_irfs(LtildeStruct, shock_idx, response_idx);
horizon_max = LtildeStruct.horizon;

% Filtrar horizontes dentro de rango
h_valid = summary_horizons(summary_horizons >= 0 & summary_horizons <= horizon_max);
h_idx   = h_valid + 1;
nh      = numel(h_idx);
nresp   = numel(response_idx);

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 1: metadata
%% ══════════════════════════════════════════════════════════════════════════
meta_labels = {'Campo', 'Valor'};
meta_vals   = {
    'spec_name',    spec_name;
    'fecha_run',    datestr(now, 'yyyy-mm-dd HH:MM:SS');
    'modo',         mode_str;
    'semilla',      num2str(seed);
    'nd',           num2str(Cfg.ND);
    'horizon',      num2str(LtildeStruct.horizon);
    'nvar',         num2str(nvar);
    'nlag',         num2str(Cfg.NLAG);
    'shock_idx',    num2str(shock_idx);
    'shock_label',  label_shock;
    'variables',    strjoin(all_labels, ', ');
    'irf_type',     irf_type;
    'cred_bands',   mat2str(cred_bands);
    'summary_horizons', mat2str(h_valid);
};
T_meta = cell2table([meta_vals(:,1), meta_vals(:,2)], 'VariableNames', meta_labels);
writetable(T_meta, xlsx_path, 'Sheet', 'metadata', 'WriteVariableNames', true);

%% ── Helper: calcular stats de IRF ───────────────────────────────────────
function rows = build_irf_rows(irfs_arr, h_valid_in, h_idx_in, nh_in, nresp_in, ...
                                label_shock_in, label_resp_in, cred_bands_in, n_bands_in)
    rows = {};
    for ii = 1:nh_in
        for jj = 1:nresp_in
            sl = irfs_arr(h_idx_in(ii), jj, :);
            sl = sl(:);
            med_v = quantile(sl, 0.50);

            band_vals = cell(1, n_bands_in*2);
            for bb = 1:n_bands_in
                band_vals{(bb-1)*2+1} = quantile(sl, cred_bands_in(bb, 1));
                band_vals{(bb-1)*2+2} = quantile(sl, cred_bands_in(bb, 2));
            end

            row = [label_shock_in, label_resp_in{jj}, h_valid_in(ii), med_v, band_vals{:}];
            rows = [rows; row]; %#ok<AGROW>
        end
    end
end

%% ── Construir encabezados de bandas ──────────────────────────────────────
band_col_names = {};
for bb = 1:n_bands
    band_col_names{end+1} = sprintf('p%.0f', cred_bands(bb,1)*100); %#ok<AGROW>
    band_col_names{end+1} = sprintf('p%.0f', cred_bands(bb,2)*100); %#ok<AGROW>
end
irf_col_names = [{'shock', 'response', 'horizon', 'median'}, band_col_names];

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 2: irf_summary
%% ══════════════════════════════════════════════════════════════════════════
if ismember(irf_type, {'irf', 'both'})
    rows_irf = build_irf_rows(irfs_raw, h_valid, h_idx, nh, nresp, ...
                               label_shock, label_resp, cred_bands, n_bands);
    if ~isempty(rows_irf)
        T_irf = cell2table(rows_irf, 'VariableNames', irf_col_names);
        writetable(T_irf, xlsx_path, 'Sheet', 'irf_summary', 'WriteVariableNames', true);
    end
else
    % Escribir hoja vacía con nota
    T_empty = cell2table({'(IRF_TYPE no incluye irf)'}, 'VariableNames', {'nota'});
    writetable(T_empty, xlsx_path, 'Sheet', 'irf_summary', 'WriteVariableNames', true);
end

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 3: cirf_summary
%% ══════════════════════════════════════════════════════════════════════════
if ismember(irf_type, {'cirf', 'both'})
    cirfs_raw = compute_cirfs(irfs_raw);
    rows_cirf = build_irf_rows(cirfs_raw, h_valid, h_idx, nh, nresp, ...
                                label_shock, label_resp, cred_bands, n_bands);
    if ~isempty(rows_cirf)
        T_cirf = cell2table(rows_cirf, 'VariableNames', irf_col_names);
        writetable(T_cirf, xlsx_path, 'Sheet', 'cirf_summary', 'WriteVariableNames', true);
    end
else
    T_empty2 = cell2table({'(IRF_TYPE no incluye cirf)'}, 'VariableNames', {'nota'});
    writetable(T_empty2, xlsx_path, 'Sheet', 'cirf_summary', 'WriteVariableNames', true);
end

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 4: fevd_summary
%% ══════════════════════════════════════════════════════════════════════════
FEVD = Results.FEVD;   % [nvar x ndraws_fevd]
FEVD_sel = FEVD(response_idx, :);   % [nresp x ndraws]

fevd_col_names = [{'variable', 'median'}, band_col_names];
rows_fevd = {};
for jj = 1:nresp
    sl = FEVD_sel(jj, :)';
    med_v = quantile(sl, 0.50);

    band_vals_f = cell(1, n_bands*2);
    for bb = 1:n_bands
        band_vals_f{(bb-1)*2+1} = quantile(sl, cred_bands(bb, 1));
        band_vals_f{(bb-1)*2+2} = quantile(sl, cred_bands(bb, 2));
    end

    row = [label_resp{jj}, med_v, band_vals_f{:}];
    rows_fevd = [rows_fevd; row]; %#ok<AGROW>
end

T_fevd = cell2table(rows_fevd, 'VariableNames', fevd_col_names);
writetable(T_fevd, xlsx_path, 'Sheet', 'fevd_summary', 'WriteVariableNames', true);

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 5: run_diagnostics
%% ══════════════════════════════════════════════════════════════════════════
diag_labels = {'metrica', 'valor'};
diag_vals   = {};

switch lower(mode_str)
    case 'pfa'
        nd_eff = LtildeStruct.ndraws;
        diag_vals = {
            'modo',          'pfa';
            'nd',            num2str(Cfg.ND);
            'nd_efectivo',   num2str(nd_eff);
            'ESS',           'N/A (PFA)';
            'tasa_acept',    'N/A (PFA)';
            'tiempo_s',      sprintf('%.2f', Results.t_elapsed);
        };

    case 'is'
        nd_eff = Results.ne;
        accept_rate = sum(Results.uw > 0) / Cfg.ND;
        diag_vals = {
            'modo',          'is';
            'nd',            num2str(Cfg.ND);
            'ESS_ne',        num2str(nd_eff);
            'ESS_ratio',     sprintf('%.4f', nd_eff / Cfg.ND);
            'tasa_acept',    sprintf('%.4f', accept_rate);
            'tiempo_s',      sprintf('%.2f', Results.t_elapsed);
        };

    otherwise
        diag_vals = {
            'modo',          mode_str;
            'nd',            num2str(Cfg.ND);
            'tiempo_s',      sprintf('%.2f', Results.t_elapsed);
        };
end

T_diag = cell2table(diag_vals, 'VariableNames', diag_labels);
writetable(T_diag, xlsx_path, 'Sheet', 'run_diagnostics', 'WriteVariableNames', true);

fprintf('export_results: archivo guardado en:\n  %s\n', xlsx_path);
fprintf('  Hojas: metadata | irf_summary | cirf_summary | fevd_summary | run_diagnostics\n');

end

%% ── Helper privado ───────────────────────────────────────────────────────
function ls = LtildeStruct_safe(Results)
%Wrapper para extraer LtildeStruct de Results con validación mínima.
    ls = Results.LtildeStruct;
end
