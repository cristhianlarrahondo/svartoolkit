function compare_pfa_is(Results_pfa, Results_is, Dataset, Cfg)
%COMPARE_PFA_IS  Tabla comparativa de medianas e intervalos PFA vs IS.
%
%   COMPARE_PFA_IS(Results_pfa, Results_is, Dataset, Cfg)
%
%   Calcula y muestra en consola la diferencia de medianas e intervalos
%   de credibilidad entre PFA e IS para los mismos shocks y horizontes.
%   También exporta la tabla a un archivo .xlsx.
%
%   Campos de Cfg usados (con defaults):
%     SUMMARY_HORIZONS   vector  (default [0 4 8 20 40])
%     RESP_IDX           vector  (default todas las variables)
%     CRED_BANDS         [N×2]   (default [0.16 0.84])
%     SPEC_NAME          string  (default 'bnw')
%
%   Entrada:
%     Results_pfa   struct de run_pfa.m
%     Results_is    struct de run_is.m
%     Dataset       struct de load_data.m (para var_labels y var_roles)
%     Cfg           struct de configuración

%% ── Validar entradas ─────────────────────────────────────────────────────
if ~isfield(Results_pfa, 'LtildeStruct') || ~strcmpi(Results_pfa.LtildeStruct.mode, 'pfa')
    error('compare_pfa_is:badPFA', ...
        'compare_pfa_is: el primer argumento debe ser un Results de modo PFA.');
end
if ~isfield(Results_is, 'LtildeStruct') || ~strcmpi(Results_is.LtildeStruct.mode, 'is')
    error('compare_pfa_is:badIS', ...
        'compare_pfa_is: el segundo argumento debe ser un Results de modo IS.');
end

%% ── Defaults de Cfg ──────────────────────────────────────────────────────
summary_horizons = [0 4 8 20 40];
if isfield(Cfg, 'SUMMARY_HORIZONS') && ~isempty(Cfg.SUMMARY_HORIZONS)
    summary_horizons = Cfg.SUMMARY_HORIZONS;
end

cred_bands = [0.16 0.84];
if isfield(Cfg, 'CRED_BANDS') && ~isempty(Cfg.CRED_BANDS)
    cb = Cfg.CRED_BANDS;
    if isvector(cb), cb = reshape(cb, 1, []); end
    if size(cb, 2) == 2, cred_bands = cb(1,:); end   % usar solo la primera banda
end
p_lo = cred_bands(1);
p_hi = cred_bands(2);

spec_name = 'bnw';
if isfield(Cfg, 'SPEC_NAME') && ~isempty(Cfg.SPEC_NAME)
    spec_name = Cfg.SPEC_NAME;
end

%% ── Labels de variables ──────────────────────────────────────────────────
endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
all_labels = Dataset.var_labels(endo_mask);
n          = Results_pfa.LtildeStruct.nvar;

resp_idx = 1:n;
if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
    resp_idx = Cfg.RESP_IDX;
    resp_idx = resp_idx(resp_idx >= 1 & resp_idx <= n);
end

shock_idx = Results_pfa.LtildeStruct.shock_idx;
if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
    shock_idx = Cfg.SHOCK_IDX;
end

% Nombre del shock
if shock_idx <= numel(all_labels)
    shock_label = all_labels{shock_idx};
else
    shock_label = sprintf('Shock %d', shock_idx);
end

%% ── Extraer IRFs para ambos modos ───────────────────────────────────────
LS_pfa = Results_pfa.LtildeStruct;
LS_is  = Results_is.LtildeStruct;
LS_pfa.var_labels = all_labels;
LS_is.var_labels  = all_labels;

[irfs_pfa, ~, label_resp] = select_irfs(LS_pfa, shock_idx, resp_idx);
[irfs_is,  ~, ~          ] = select_irfs(LS_is,  shock_idx, resp_idx);
% irfs_*: [horizon+1, nresp, ndraws]

nresp = size(irfs_pfa, 2);

% Filtrar horizontes válidos
h_max   = min(LS_pfa.horizon, LS_is.horizon);
h_valid = summary_horizons(summary_horizons >= 0 & summary_horizons <= h_max);
nh      = numel(h_valid);

if isempty(h_valid)
    fprintf('[compare_pfa_is] No hay horizontes válidos en [0, %d].\n', h_max);
    return;
end

%% ── Calcular estadísticos ────────────────────────────────────────────────
% Para cada variable × horizonte: mediana e intervalo en PFA e IS
med_pfa = zeros(nh, nresp);
med_is  = zeros(nh, nresp);
lo_pfa  = zeros(nh, nresp);
hi_pfa  = zeros(nh, nresp);
lo_is   = zeros(nh, nresp);
hi_is   = zeros(nh, nresp);

for ii = 1:nh
    h_idx = h_valid(ii) + 1;
    for jj = 1:nresp
        sl_p = irfs_pfa(h_idx, jj, :); sl_p = sl_p(:);
        sl_i = irfs_is( h_idx, jj, :); sl_i = sl_i(:);
        med_pfa(ii,jj) = quantile(sl_p, 0.50);
        med_is(ii,jj)  = quantile(sl_i, 0.50);
        lo_pfa(ii,jj)  = quantile(sl_p, p_lo);
        hi_pfa(ii,jj)  = quantile(sl_p, p_hi);
        lo_is(ii,jj)   = quantile(sl_i, p_lo);
        hi_is(ii,jj)   = quantile(sl_i, p_hi);
    end
end

diff_med = med_pfa - med_is;

%% ── Imprimir tabla en consola ────────────────────────────────────────────
sep_wide = repmat('═', 1, 90);
sep_thin = repmat('─', 1, 90);
band_tag = sprintf('p%.0f/p%.0f', p_lo*100, p_hi*100);

fprintf('\n%s\n', sep_wide);
fprintf('  COMPARE_PFA_IS — Spec: %s\n', spec_name);
fprintf('  Shock: %s\n', shock_label);
fprintf('  Bandas: %s\n', band_tag);
fprintf('%s\n', sep_wide);
fprintf('  %-20s  h   %10s  %10s  %10s  %-18s  %-18s\n', ...
    'Variable', 'Med PFA', 'Med IS', 'Dif Med', ...
    sprintf('[%s] PFA', band_tag), sprintf('[%s] IS', band_tag));
fprintf('%s\n', sep_thin);

for jj = 1:nresp
    rname = label_resp{jj};
    for ii = 1:nh
        if ii == 1
            name_disp = rname;
        else
            name_disp = '';
        end
        fprintf('  %-20s  %2d  %10.4f  %10.4f  %10.4f  [%7.4f,%7.4f]  [%7.4f,%7.4f]\n', ...
            name_disp, h_valid(ii), ...
            med_pfa(ii,jj), med_is(ii,jj), diff_med(ii,jj), ...
            lo_pfa(ii,jj), hi_pfa(ii,jj), lo_is(ii,jj), hi_is(ii,jj));
    end
    fprintf('%s\n', sep_thin);
end
fprintf('\n');

%% ── Exportar a Excel ─────────────────────────────────────────────────────
this_dir  = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
tbl_dir   = fullfile(proj_root, 'output', 'tables');
if ~exist(tbl_dir, 'dir')
    mkdir(tbl_dir);
end
out_path = fullfile(tbl_dir, sprintf('compare_pfa_is_%s.xlsx', spec_name));

% Construir tabla para exportación
n_rows  = nh * nresp;
var_col = cell(n_rows, 1);
h_col   = zeros(n_rows, 1);
mp_col  = zeros(n_rows, 1);
mi_col  = zeros(n_rows, 1);
dm_col  = zeros(n_rows, 1);
lp_col  = zeros(n_rows, 1);
hp_col  = zeros(n_rows, 1);
li_col  = zeros(n_rows, 1);
hi_col2 = zeros(n_rows, 1);

row = 1;
for jj = 1:nresp
    for ii = 1:nh
        var_col{row} = label_resp{jj};
        h_col(row)   = h_valid(ii);
        mp_col(row)  = med_pfa(ii,jj);
        mi_col(row)  = med_is(ii,jj);
        dm_col(row)  = diff_med(ii,jj);
        lp_col(row)  = lo_pfa(ii,jj);
        hp_col(row)  = hi_pfa(ii,jj);
        li_col(row)  = lo_is(ii,jj);
        hi_col2(row) = hi_is(ii,jj);
        row = row + 1;
    end
end

T = table(var_col, h_col, mp_col, mi_col, dm_col, ...
          lp_col, hp_col, li_col, hi_col2, ...
    'VariableNames', {'variable', 'horizon', 'median_pfa', 'median_is', 'diff_median', ...
                      sprintf('lo_pfa_p%.0f', p_lo*100), ...
                      sprintf('hi_pfa_p%.0f', p_hi*100), ...
                      sprintf('lo_is_p%.0f',  p_lo*100), ...
                      sprintf('hi_is_p%.0f',  p_hi*100)});

% Limpiar archivo existente para evitar residuos de hojas
if isfile(out_path)
    delete(out_path);
end
writetable(T, out_path, 'Sheet', 'compare_pfa_is');

fprintf('  Tabla exportada a: output/tables/compare_pfa_is_%s.xlsx\n\n', spec_name);

end
