function export_results(Results, Dataset, Cfg)
%EXPORT_RESULTS  Exporta resultados a Excel con 5 hojas estructuradas.
%
%   EXPORT_RESULTS(Results, Dataset, Cfg)
%
%   Genera un archivo .xlsx con las siguientes hojas:
%     1. metadata       — spec, fecha, variables, modo, semilla
%     2. irf_summary    — shock × response × horizon (0:HORIZON) | median | pX | pY
%     3. cirf_summary   — ídem para CIRFs (solo si IRF_TYPE incluye 'cirf')
%     4. fevd_summary   — variable | median | pX | pY
%     5. run_diagnostics — ESS, tasa aceptación, tiempo, nd
%
%   Nota: irf_summary y cirf_summary exportan TODOS los horizontes (0 a Cfg.HORIZON).
%   Para tabla de solo horizontes clave usar print_summary con Cfg.SUMMARY_HORIZONS.
%
%   Campos de Cfg usados:
%     CRED_BANDS         (default [0.16 0.84])
%     SHOCK_IDX          (default LtildeStruct.shock_idx)
%     RESP_IDX           (default todos)
%     IRF_TYPE           'irf' | 'cirf' | 'both'  (default 'irf')
%     SPEC_NAME          string  (default 'spec')
%     SEED               scalar  (default 0)
%     MODE               string
%     OUTPUT_DIR         string (OPCIONAL) — ruta absoluta a la carpeta
%                        output/ del proyecto que llama (p.ej.
%                        examples/bnw/output/). Si no está definido, se usa
%                        el comportamiento legado: refactored/output/.
%
%   El archivo se guarda en <OUTPUT_DIR o refactored/output>/tables/<SPEC_NAME>_results.xlsx

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
cred_bands = [0.16 0.84];
if isfield(Cfg, 'CRED_BANDS') && ~isempty(Cfg.CRED_BANDS)
    cb = Cfg.CRED_BANDS;
    if isvector(cb), cb = reshape(cb, 1, []); end
    if size(cb, 2) == 2, cred_bands = cb; end
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
if isfield(Cfg, 'SEED'), seed = Cfg.SEED; end

mode_str = 'unknown';
if isfield(Cfg, 'MODE') && ~isempty(Cfg.MODE)
    mode_str = lower(Cfg.MODE);
end

%% ── Paths ────────────────────────────────────────────────────────────────
% Si Cfg.OUTPUT_DIR está definido (proyectos en examples/<nombre>/), los
% resultados se escriben ahí. Si no está definido, se preserva el
% comportamiento legado: relativo a refactored/ (motor compartido), para
% no romper specs existentes que no definen este campo.
if isfield(Cfg, 'OUTPUT_DIR') && ~isempty(Cfg.OUTPUT_DIR)
    tables_dir = fullfile(Cfg.OUTPUT_DIR, 'tables');
else
    src_root   = fileparts(mfilename('fullpath'));
    proj_root  = fileparts(src_root);
    tables_dir = fullfile(proj_root, 'output', 'tables');
end
if ~isfolder(tables_dir), mkdir(tables_dir); end

safe_name = regexprep(spec_name, '[^a-zA-Z0-9_]', '_');
xlsx_path = fullfile(tables_dir, [safe_name, '_results.xlsx']);
if isfile(xlsx_path), delete(xlsx_path); end

%% ── Variables endógenas ──────────────────────────────────────────────────
LtildeStruct = Results.LtildeStruct;
nvar         = LtildeStruct.nvar;
horizon_max  = LtildeStruct.horizon;

endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
all_labels = Dataset.var_labels(endo_mask);
LtildeStruct.var_labels = all_labels;

shock_idx = LtildeStruct.shock_idx;
if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
    shock_idx = Cfg.SHOCK_IDX;
end

response_idx = 1:nvar;
if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
    ri = Cfg.RESP_IDX;
    response_idx = ri(ri >= 1 & ri <= nvar);
end

%% ── Extraer IRFs — todos los horizontes ─────────────────────────────────
[irfs_raw, label_shock, label_resp] = select_irfs(LtildeStruct, shock_idx, response_idx);
nresp = numel(response_idx);

% Todos los horizontes de 0 a horizon_max
h_all  = 0:horizon_max;          % 0-based
h_idx  = h_all + 1;              % 1-based en el array
nh     = numel(h_all);

%% ── Construir nombres de columnas de bandas ──────────────────────────────
band_col_names = cell(1, n_bands * 2);
for bb = 1:n_bands
    band_col_names{(bb-1)*2 + 1} = sprintf('p%.0f', cred_bands(bb,1) * 100);
    band_col_names{(bb-1)*2 + 2} = sprintf('p%.0f', cred_bands(bb,2) * 100);
end

irf_col_names  = [{'shock', 'response', 'horizon', 'median'}, band_col_names];
fevd_col_names = [{'variable', 'median'}, band_col_names];

%% ── Helper: construir tabla de IRFs ──────────────────────────────────────
function rows = build_irf_rows(irfs_arr, label_shock_in, label_resp_in, ...
                                h_all_in, h_idx_in, nh_in, nresp_in, ...
                                cred_bands_in, n_bands_in)
    n_cols = 4 + n_bands_in * 2;
    rows   = cell(nh_in * nresp_in, n_cols);
    row_k  = 1;
    for ii = 1:nh_in
        for jj = 1:nresp_in
            sl    = irfs_arr(h_idx_in(ii), jj, :);
            med_v = quantile(sl(:), 0.50);
            rows{row_k, 1} = label_shock_in;
            rows{row_k, 2} = label_resp_in{jj};
            rows{row_k, 3} = h_all_in(ii);
            rows{row_k, 4} = med_v;
            for bb = 1:n_bands_in
                rows{row_k, 4 + (bb-1)*2 + 1} = quantile(sl(:), cred_bands_in(bb, 1));
                rows{row_k, 4 + (bb-1)*2 + 2} = quantile(sl(:), cred_bands_in(bb, 2));
            end
            row_k = row_k + 1;
        end
    end
end

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 1: metadata
%% ══════════════════════════════════════════════════════════════════════════
meta_data = {
    'spec_name',        spec_name;
    'fecha_run',        datestr(now, 'yyyy-mm-dd HH:MM:SS');
    'modo',             mode_str;
    'semilla',          num2str(seed);
    'nd',               num2str(Cfg.ND);
    'horizon',          num2str(horizon_max);
    'nvar',             num2str(nvar);
    'nlag',             num2str(Cfg.NLAG);
    'shock_idx',        num2str(shock_idx);
    'shock_label',      label_shock;
    'variables',        strjoin(all_labels, ', ');
    'irf_type',         irf_type;
    'cred_bands',       mat2str(cred_bands);
    'horizons_export',  sprintf('0:%d (todos)', horizon_max);
};
T_meta = cell2table(meta_data, 'VariableNames', {'campo', 'valor'});
writetable(T_meta, xlsx_path, 'Sheet', 'metadata', 'WriteVariableNames', true);

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 2: irf_summary  (todos los horizontes)
%% ══════════════════════════════════════════════════════════════════════════
if ismember(irf_type, {'irf', 'both'})
    rows_irf = build_irf_rows(irfs_raw, label_shock, label_resp, ...
                               h_all, h_idx, nh, nresp, cred_bands, n_bands);
    T_irf = cell2table(rows_irf, 'VariableNames', irf_col_names);
    writetable(T_irf, xlsx_path, 'Sheet', 'irf_summary', 'WriteVariableNames', true);
else
    T_empty = cell2table({'(IRF_TYPE no incluye irf)'}, 'VariableNames', {'nota'});
    writetable(T_empty, xlsx_path, 'Sheet', 'irf_summary', 'WriteVariableNames', true);
end

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 3: cirf_summary  (todos los horizontes)
%% ══════════════════════════════════════════════════════════════════════════
if ismember(irf_type, {'cirf', 'both'})
    cirfs_raw = compute_cirfs(irfs_raw);
    rows_cirf = build_irf_rows(cirfs_raw, label_shock, label_resp, ...
                                h_all, h_idx, nh, nresp, cred_bands, n_bands);
    T_cirf = cell2table(rows_cirf, 'VariableNames', irf_col_names);
    writetable(T_cirf, xlsx_path, 'Sheet', 'cirf_summary', 'WriteVariableNames', true);
else
    T_empty2 = cell2table({'(IRF_TYPE no incluye cirf)'}, 'VariableNames', {'nota'});
    writetable(T_empty2, xlsx_path, 'Sheet', 'cirf_summary', 'WriteVariableNames', true);
end

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 4: fevd_summary
%% ══════════════════════════════════════════════════════════════════════════
FEVD     = Results.FEVD;
FEVD_sel = FEVD(response_idx, :);

n_fevd_cols = 2 + n_bands * 2;
rows_fevd   = cell(nresp, n_fevd_cols);
for jj = 1:nresp
    sl    = FEVD_sel(jj, :)';
    rows_fevd{jj, 1} = label_resp{jj};
    rows_fevd{jj, 2} = quantile(sl, 0.50);
    for bb = 1:n_bands
        rows_fevd{jj, 2 + (bb-1)*2 + 1} = quantile(sl, cred_bands(bb, 1));
        rows_fevd{jj, 2 + (bb-1)*2 + 2} = quantile(sl, cred_bands(bb, 2));
    end
end
T_fevd = cell2table(rows_fevd, 'VariableNames', fevd_col_names);
writetable(T_fevd, xlsx_path, 'Sheet', 'fevd_summary', 'WriteVariableNames', true);

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 5: run_diagnostics
%% ══════════════════════════════════════════════════════════════════════════
switch lower(mode_str)
    case 'pfa'
        diag_data = {
            'modo',         mode_str;
            'nd',           num2str(Cfg.ND);
            'nd_efectivo',  num2str(LtildeStruct.ndraws);
            'ESS',          'N/A (PFA)';
            'tasa_acept',   'N/A (PFA)';
            'tiempo_s',     sprintf('%.2f', Results.t_elapsed);
        };
    case 'is'
        accept_rate = sum(Results.uw > 0) / Cfg.ND;
        diag_data = {
            'modo',         mode_str;
            'nd',           num2str(Cfg.ND);
            'ESS_ne',       num2str(Results.ne);
            'ESS_ratio',    sprintf('%.4f', Results.ne / Cfg.ND);
            'tasa_acept',   sprintf('%.4f', accept_rate);
            'tiempo_s',     sprintf('%.2f', Results.t_elapsed);
        };
    otherwise
        diag_data = {
            'modo',     mode_str;
            'nd',       num2str(Cfg.ND);
            'tiempo_s', sprintf('%.2f', Results.t_elapsed);
        };
end
T_diag = cell2table(diag_data, 'VariableNames', {'metrica', 'valor'});
writetable(T_diag, xlsx_path, 'Sheet', 'run_diagnostics', 'WriteVariableNames', true);

fprintf('export_results: archivo guardado en:\n  %s\n', xlsx_path);
fprintf('  Hojas: metadata | irf_summary | cirf_summary | fevd_summary | run_diagnostics\n');
fprintf('  IRFs exportados: horizontes 0:%d × %d respuestas\n', horizon_max, nresp);

end
