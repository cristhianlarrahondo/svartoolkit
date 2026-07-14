function export_results(Results, Dataset, Cfg)
%EXPORT_RESULTS  Exporta resultados a Excel con hojas estructuradas.
%
%   EXPORT_RESULTS(Results, Dataset, Cfg)
%
%   Genera un archivo .xlsx con las siguientes hojas:
%     1. metadata                — spec, fecha, variables, modo, semilla
%     2. irf_summary[_s<k>]      — UNA HOJA POR CADA SHOCK solicitado,
%                                  formato ANCHO (Chat 19, Hallazgo 11):
%                                  columnas shock | horizon | <resp1>_p<lo> |
%                                  <resp1>_median | <resp1>_p<hi> | <resp2>_p<lo> | ...
%                                  (ERPT-Chat 5: orden p_lo|median|p_hi por
%                                  entidad, antes median|p_lo|p_hi) — una
%                                  fila por horizonte, horizonte ascendente
%                                  desde 0.
%     3. cirf_summary[_s<k>]     — idem para CIRFs (solo si IRF_TYPE incluye 'cirf')
%     4. fevd_summary[_v<k>]     — UNA HOJA POR CADA VARIABLE de respuesta
%                                  (Chat 19, Hallazgo 6: FEVD es multi-shock
%                                  y multi-horizonte ahora — ver run_pfa.m/
%                                  run_is.m). Formato ancho: columnas
%                                  horizon | <shock1>_p<lo> | <shock1>_median |
%                                  <shock1>_p<hi> | <shock2>_p<lo> | ...
%     5. run_diagnostics         — ESS, tasa aceptacion, tiempo, nd
%
%   CAMBIO (Chat 19, Hallazgo 11): las hojas irf_summary/cirf_summary
%   pasan de formato LARGO (una fila por shock x response x horizon) a
%   formato ANCHO (una fila por horizonte, una variable de respuesta por
%   bloque de columnas). Rompe compatibilidad de columnas con versiones
%   anteriores del toolkit — cambio deliberado, aprobado explicitamente.
%
%   CAMBIO (Chat 19, Hallazgo 6): fevd_summary pasa de una unica hoja
%   variable|median|pX|pY (un solo shock, un solo horizonte) a una hoja
%   POR VARIABLE con horizon como fila y un bloque de columnas por shock
%   calculado (Results.FEVD_shock_idx) — mismo criterio de "una unidad de
%   organizacion por variable" usado en plot_fevd.m.
%
%   Campos de Cfg usados:
%     CRED_BANDS         (default [0.16 0.84])
%     SHOCK_IDX          escalar | vector | 'all' (default LtildeStruct.shock_idx)
%     SHOCK_NAMES        cell array de strings (default 'shock1','shock2',...)
%     RESP_IDX           (default todos)
%     IRF_TYPE           'irf' | 'cirf' | 'both'  (default 'irf')
%     SPEC_NAME          string  (default 'spec')
%     SEED               scalar  (default 0)
%     MODE               string
%     OUTPUT_DIR         string (OPCIONAL) — ruta absoluta a la carpeta
%                        output/ del proyecto que llama (p.ej.
%                        projects/bnw/output/). Si no está definido, se usa
%                        el comportamiento legado: refactored/output/.
%     EXPORT_HORIZONS    vector (OPCIONAL, ERPT-Chat 5) — subconjunto de
%                        horizontes 0-based a incluir en irf_summary/
%                        cirf_summary. Si no está definido (comportamiento
%                        LEGADO sin cambios), se exportan TODOS los
%                        horizontes 0:horizon_max, igual que antes de este
%                        campo. No afecta fevd_summary (ver
%                        Results.FEVD_horizons para eso).
%
%   El archivo se guarda en <OUTPUT_DIR o refactored/output>/tables/<SPEC_NAME>_results.xlsx

%% ── Guard: corrida omitida (p.ej. PFA con >1 choque restringido) ────────
[skip_run, skip_reason] = is_run_skipped(Results);
if skip_run
    fprintf('[export_results] Omitido: %s\n', skip_reason);
    return;
end

%% ── Validar entrada mínima ───────────────────────────────────────────────
if ~isfield(Results, 'LtildeStruct') || isempty(Results.LtildeStruct)
    error('export_results:missingLtilde', ...
        'export_results: Results.LtildeStruct está ausente o vacío.');
end
if ~isfield(Results, 'FEVD') || isempty(Results.FEVD)
    error('export_results:missingFEVD', ...
        'export_results: Results.FEVD está ausente o vacío.');
end
if ~isfield(Results, 'FEVD_shock_idx') || ~isfield(Results, 'FEVD_horizons')
    error('export_results:missingFevdMetadata', ...
        ['export_results: Results.FEVD_shock_idx / Results.FEVD_horizons ' ...
         'ausentes. ¿Vienen de una version de run_pfa.m/run_is.m anterior ' ...
         'al Chat 19?']);
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

shock_names = {};
if isfield(Cfg, 'SHOCK_NAMES') && ~isempty(Cfg.SHOCK_NAMES)
    shock_names = Cfg.SHOCK_NAMES;
end

%% ── Paths ────────────────────────────────────────────────────────────────
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

shock_idx_req = LtildeStruct.shock_idx;
if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
    shock_idx_req = Cfg.SHOCK_IDX;
end

response_idx = 1:nvar;
if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
    ri = Cfg.RESP_IDX;
    response_idx = ri(ri >= 1 & ri <= nvar);
end

%% ── Extraer IRFs — todos los horizontes, todos los shocks solicitados ───
[irfs_by_shock, label_shock_arr, label_resp, shock_idx_resolved] = ...
    select_irfs(LtildeStruct, shock_idx_req, response_idx, shock_names);
nresp    = numel(response_idx);
n_shocks = numel(shock_idx_resolved);

% Todos los horizontes de 0 a horizon_max, salvo que Cfg.EXPORT_HORIZONS
% restrinja el subconjunto a exportar (ERPT-Chat 5; default = comportamiento
% legado sin cambios).
h_all = 0:horizon_max;          % 0-based
if isfield(Cfg, 'EXPORT_HORIZONS') && ~isempty(Cfg.EXPORT_HORIZONS)
    eh = Cfg.EXPORT_HORIZONS(:)';
    if any(eh < 0) || any(eh > horizon_max)
        error('export_results:badExportHorizons', ...
            'Cfg.EXPORT_HORIZONS debe estar en [0, %d]. Recibido: %s.', ...
            horizon_max, mat2str(eh));
    end
    h_all = unique(eh, 'stable');
end
h_idx  = h_all + 1;              % 1-based en el array
nh     = numel(h_all);

%% ── Helper: nombres de columnas por bloque de "entidad" (respuesta/shock) ─
function col_names = build_block_col_names(entity_names, cred_bands_in, n_bands_in)
%   Orden por entidad (ERPT-Chat 5, lectura natural izq->der): limites
%   inferiores de banda MAS ANCHA a MAS ANGOSTA, luego la mediana, luego
%   limites superiores de banda MAS ANGOSTA a MAS ANCHA. Con n_bands_in=1
%   (caso tipico del proyecto) esto es simplemente p_lo | median | p_hi.
    n_entities = numel(entity_names);
    col_names  = cell(1, n_entities * (1 + 2*n_bands_in));
    kk_col = 1;
    for ee = 1:n_entities
        safe_e = regexprep(entity_names{ee}, '[^a-zA-Z0-9_]', '_');
        for bb = n_bands_in:-1:1
            col_names{kk_col} = sprintf('%s_p%.0f', safe_e, cred_bands_in(bb,1)*100); kk_col = kk_col + 1;
        end
        col_names{kk_col} = sprintf('%s_median', safe_e); kk_col = kk_col + 1;
        for bb = 1:n_bands_in
            col_names{kk_col} = sprintf('%s_p%.0f', safe_e, cred_bands_in(bb,2)*100); kk_col = kk_col + 1;
        end
    end
end

%% ── Helper: construir tabla ANCHA de IRFs/CIRFs (un shock, todas las resp) ─
function rows = build_irf_rows_wide(irfs_arr, label_shock_in, ...
                                     h_all_in, h_idx_in, nh_in, nresp_in, ...
                                     cred_bands_in, n_bands_in)
    n_data_cols = nresp_in * (1 + 2*n_bands_in);
    rows = cell(nh_in, 2 + n_data_cols);
    for ii = 1:nh_in
        rows{ii, 1} = label_shock_in;
        rows{ii, 2} = h_all_in(ii);
        col = 3;
        for jj = 1:nresp_in
            sl = irfs_arr(h_idx_in(ii), jj, :);
            for bb = n_bands_in:-1:1
                rows{ii, col} = quantile(sl(:), cred_bands_in(bb,1)); col = col + 1;
            end
            rows{ii, col} = quantile(sl(:), 0.50); col = col + 1;
            for bb = 1:n_bands_in
                rows{ii, col} = quantile(sl(:), cred_bands_in(bb,2)); col = col + 1;
            end
        end
    end
end

%% ── Helper: construir tabla ANCHA de FEVD (una variable, todos los shocks) ─
function rows = build_fevd_rows_wide(FEVD_in, v_idx_in, ...
                                      fevd_horizons_in, n_h_in, n_shocks_in, ...
                                      cred_bands_in, n_bands_in)
    n_data_cols = n_shocks_in * (1 + 2*n_bands_in);
    rows = cell(n_h_in, 1 + n_data_cols);
    for hh_i = 1:n_h_in
        rows{hh_i, 1} = fevd_horizons_in(hh_i);
        col = 2;
        for jj = 1:n_shocks_in
            sl = FEVD_in(v_idx_in, jj, hh_i, :);
            for bb = n_bands_in:-1:1
                rows{hh_i, col} = quantile(sl(:), cred_bands_in(bb,1)); col = col + 1;
            end
            rows{hh_i, col} = quantile(sl(:), 0.50); col = col + 1;
            for bb = 1:n_bands_in
                rows{hh_i, col} = quantile(sl(:), cred_bands_in(bb,2)); col = col + 1;
            end
        end
    end
end

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 1: metadata
%% ══════════════════════════════════════════════════════════════════════════
irf_sheet_names_preview  = cell(1, n_shocks);
cirf_sheet_names_preview = cell(1, n_shocks);
for j = 1:n_shocks
    sidx_j = shock_idx_resolved(j);
    if n_shocks == 1
        irf_sheet_names_preview{j}  = 'irf_summary';
        cirf_sheet_names_preview{j} = 'cirf_summary';
    else
        irf_sheet_names_preview{j}  = sprintf('irf_summary_s%d', sidx_j);
        cirf_sheet_names_preview{j} = sprintf('cirf_summary_s%d', sidx_j);
    end
end

meta_data = {
    'spec_name',        spec_name;
    'fecha_run',        datestr(now, 'yyyy-mm-dd HH:MM:SS');
    'modo',             mode_str;
    'semilla',          num2str(seed);
    'nd',               num2str(Cfg.ND);
    'horizon',          num2str(horizon_max);
    'nvar',             num2str(nvar);
    'nlag',             num2str(Cfg.NLAG);
    'shock_idx',        mat2str(shock_idx_resolved);
    'shock_labels',     strjoin(label_shock_arr, ', ');
    'variables',        strjoin(all_labels, ', ');
    'irf_type',         irf_type;
    'cred_bands',       mat2str(cred_bands);
    'horizons_export',  mat2str(h_all);
    'hojas_irf',        strjoin(irf_sheet_names_preview, ', ');
    'hojas_cirf',       strjoin(cirf_sheet_names_preview, ', ');
    'fevd_shock_idx',   mat2str(Results.FEVD_shock_idx);
    'fevd_horizons',    mat2str(Results.FEVD_horizons);
};
T_meta = cell2table(meta_data, 'VariableNames', {'campo', 'valor'});
writetable(T_meta, xlsx_path, 'Sheet', 'metadata', 'WriteVariableNames', true);

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 2: irf_summary — UNA HOJA POR CHOQUE, formato ANCHO (Hallazgo 11)
%% ══════════════════════════════════════════════════════════════════════════
resp_col_names = build_block_col_names(label_resp, cred_bands, n_bands);
irf_col_names  = [{'shock', 'horizon'}, resp_col_names];

irf_sheet_names = cell(1, n_shocks);
if ismember(irf_type, {'irf', 'both'})
    for j = 1:n_shocks
        sidx_j = shock_idx_resolved(j);
        rows_j = build_irf_rows_wide(irfs_by_shock{j}, label_shock_arr{j}, ...
                                      h_all, h_idx, nh, nresp, cred_bands, n_bands);
        T_irf_j = cell2table(rows_j, 'VariableNames', irf_col_names);
        if n_shocks == 1
            sheet_name = 'irf_summary';
        else
            sheet_name = sprintf('irf_summary_s%d', sidx_j);
        end
        irf_sheet_names{j} = sheet_name;
        writetable(T_irf_j, xlsx_path, 'Sheet', sheet_name, 'WriteVariableNames', true);
    end
else
    T_empty = cell2table({'(IRF_TYPE no incluye irf)'}, 'VariableNames', {'nota'});
    writetable(T_empty, xlsx_path, 'Sheet', 'irf_summary', 'WriteVariableNames', true);
    irf_sheet_names = {'irf_summary'};
end

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 3: cirf_summary — UNA HOJA POR CHOQUE (mismo criterio que HOJA 2)
%% ══════════════════════════════════════════════════════════════════════════
cirf_sheet_names = cell(1, n_shocks);
if ismember(irf_type, {'cirf', 'both'})
    for j = 1:n_shocks
        sidx_j  = shock_idx_resolved(j);
        cirfs_j = compute_cirfs(irfs_by_shock{j});
        rows_j  = build_irf_rows_wide(cirfs_j, label_shock_arr{j}, ...
                                       h_all, h_idx, nh, nresp, cred_bands, n_bands);
        T_cirf_j = cell2table(rows_j, 'VariableNames', irf_col_names);
        if n_shocks == 1
            sheet_name = 'cirf_summary';
        else
            sheet_name = sprintf('cirf_summary_s%d', sidx_j);
        end
        cirf_sheet_names{j} = sheet_name;
        writetable(T_cirf_j, xlsx_path, 'Sheet', sheet_name, 'WriteVariableNames', true);
    end
else
    T_empty2 = cell2table({'(IRF_TYPE no incluye cirf)'}, 'VariableNames', {'nota'});
    writetable(T_empty2, xlsx_path, 'Sheet', 'cirf_summary', 'WriteVariableNames', true);
    cirf_sheet_names = {'cirf_summary'};
end

%% ══════════════════════════════════════════════════════════════════════════
%  HOJA 4: fevd_summary — UNA HOJA POR VARIABLE (Chat 19, Hallazgo 6)
%% ══════════════════════════════════════════════════════════════════════════
FEVD           = Results.FEVD;              % [nvar x n_fevd_shocks x n_fevd_h x ndraws]
fevd_shock_idx = Results.FEVD_shock_idx(:)';
fevd_horizons  = Results.FEVD_horizons(:)';
n_fevd_shocks  = numel(fevd_shock_idx);
n_fevd_h       = numel(fevd_horizons);

fevd_shock_names = cell(1, n_fevd_shocks);
for jj = 1:n_fevd_shocks
    fevd_shock_names{jj} = resolve_shock_name(shock_names, fevd_shock_idx(jj));
end
fevd_col_names = [{'horizon'}, build_block_col_names(fevd_shock_names, cred_bands, n_bands)];

fevd_sheet_names = cell(1, nresp);
for kk = 1:nresp
    v_idx  = response_idx(kk);
    rows_k = build_fevd_rows_wide(FEVD, v_idx, fevd_horizons, n_fevd_h, ...
                                   n_fevd_shocks, cred_bands, n_bands);
    T_fevd_k = cell2table(rows_k, 'VariableNames', fevd_col_names);
    if nresp == 1
        sheet_name = 'fevd_summary';
    else
        sheet_name = sprintf('fevd_summary_v%d', v_idx);
    end
    fevd_sheet_names{kk} = sheet_name;
    writetable(T_fevd_k, xlsx_path, 'Sheet', sheet_name, 'WriteVariableNames', true);
end

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
fprintf('  Hojas: metadata | %s | %s | %s | run_diagnostics\n', ...
    strjoin(irf_sheet_names, ' | '), strjoin(cirf_sheet_names, ' | '), ...
    strjoin(fevd_sheet_names, ' | '));
fprintf('  IRFs exportados: horizontes 0:%d x %d respuestas x %d shock(s) [%s]\n', ...
    horizon_max, nresp, n_shocks, num2str(shock_idx_resolved));
fprintf('  FEVD exportada: %d variable(s) x %d shock(s) x %d horizonte(s)\n', ...
    nresp, n_fevd_shocks, n_fevd_h);

end
