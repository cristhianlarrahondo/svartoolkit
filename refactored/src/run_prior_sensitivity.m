function Results_list = run_prior_sensitivity(spec_path, prior_list, Dataset, Cfg_base)
%RUN_PRIOR_SENSITIVITY  Compara medianas de IRFs entre variantes de prior.
%
%   Results_list = RUN_PRIOR_SENSITIVITY(spec_path, prior_list, Dataset, Cfg_base)
%
%   Parametros:
%     spec_path  — ruta absoluta al archivo de spec (para info de display)
%     prior_list — cell array de structs Cfg.PRIOR, e.g.:
%                  { struct('type','diffuse'), ...
%                    struct('type','minnesota','lambda1',0.1,'lambda2',0.5,'lambda3',1) }
%     Dataset    — struct devuelto por load_data
%     Cfg_base   — struct Cfg base (se sobreescribe solo el campo PRIOR)
%
%   Retorna:
%     Results_list — cell array de structs Results (uno por prior)
%
%   Tabla de consola:
%     Medianas de IRF en horizontes Cfg_base.SUMMARY_HORIZONS,
%     para cada combinacion (response, horizonte) dado el shock de interes.
%     Dimensiones de Ltilde:
%       PFA: [horizon+1, nvar, nd]         -> indexar (h_idx, resp, :)
%       IS:  [horizon+1, nvar, nvar, ne]   -> indexar (h_idx, resp, shock, :)

%% ── Validaciones de entrada ──────────────────────────────────────────────
if isempty(prior_list) || ~iscell(prior_list)
    error('run_prior_sensitivity:invalidInput', ...
        'prior_list debe ser un cell array no vacio de structs Cfg.PRIOR.');
end
for k = 1:numel(prior_list)
    if ~isstruct(prior_list{k})
        error('run_prior_sensitivity:invalidInput', ...
            'Cada elemento de prior_list debe ser una struct.');
    end
    if ~isfield(prior_list{k}, 'type')
        error('run_prior_sensitivity:missingField', ...
            'Cada struct en prior_list debe tener el campo .type.');
    end
end

%% ── Configuracion de horizontes y variables ──────────────────────────────
if isfield(Cfg_base, 'SUMMARY_HORIZONS')
    horizons = Cfg_base.SUMMARY_HORIZONS;
else
    horizons = [0, 4, 8, 20, 40];
end
% Asegurar que los horizontes no excedan el HORIZON del Cfg
max_horizon = Cfg_base.HORIZON;
horizons    = horizons(horizons <= max_horizon);

% Indice del shock de interes (por defecto: 1)
if isfield(Cfg_base, 'SHOCK_IDX')
    shock_idx = Cfg_base.SHOCK_IDX(1);   % un solo shock para la tabla
else
    shock_idx = 1;
end

% Variables de respuesta (por defecto: todas)
if isfield(Cfg_base, 'RESP_IDX')
    resp_idx = Cfg_base.RESP_IDX;
else
    resp_idx = 1:Dataset.nvar;
end

n_prior   = numel(prior_list);
n_horizon = numel(horizons);
n_resp    = numel(resp_idx);
mode      = lower(Cfg_base.MODE);

%% ── Header ───────────────────────────────────────────────────────────────
fprintf('\n');
fprintf('============================================================\n');
fprintf('  RUN_PRIOR_SENSITIVITY\n');
if ~isempty(spec_path)
    [~, spec_name, ~] = fileparts(spec_path);
    fprintf('  Spec: %s\n', spec_name);
end
fprintf('  Priors: %d | Modo: %s | Shock: %d\n', n_prior, upper(mode), shock_idx);
fprintf('============================================================\n\n');

%% ── Correr build_posterior + muestreador para cada prior ─────────────────
Results_list = cell(n_prior, 1);
prior_names  = cell(n_prior, 1);

for k = 1:n_prior
    pr_struct  = prior_list{k};
    prior_name = lower(strtrim(pr_struct.type));
    prior_names{k} = prior_name;

    fprintf('[%d/%d] Prior: %s ... ', k, n_prior, prior_name);

    Cfg_k       = Cfg_base;
    Cfg_k.PRIOR = pr_struct;

    Posterior_k = build_posterior(Dataset, Cfg_k);

    rng(Cfg_base.SEED);
    switch mode
        case 'pfa'
            Results_k = run_pfa(Posterior_k, Cfg_k);
        case 'is'
            Results_k = run_is(Posterior_k, Cfg_k);
        otherwise
            error('run_prior_sensitivity:unknownMode', ...
                'MODE "%s" no reconocido. Use "pfa" o "is".', mode);
    end

    Results_list{k} = Results_k;
    fprintf('OK\n');
end

%% ── Tabla de medianas de IRF ─────────────────────────────────────────────
% Dimensiones:
%   PFA Ltilde: [H+1, nvar, nd]        -> mediana(Ldata(h_idx, r, :))
%   IS  Ltilde: [H+1, nvar, nvar, ne]  -> mediana(Ldata(h_idx, r, s, :))
% h_idx = horizonte + 1  (h=0 -> idx=1, h=4 -> idx=5, etc.)

fprintf('\n');
fprintf('── Tabla de medianas IRF  (Shock=%d) ───────────────────────\n', shock_idx);
fprintf('   Horizontes: ');
fprintf('%d ', horizons);
fprintf('\n\n');

% Ancho de columna para nombres de prior (al menos 12 chars)
col_w = max(12, max(cellfun(@numel, prior_names)) + 2);
hdr   = sprintf('%-20s', 'Resp / Horizonte');
for k = 1:n_prior
    hdr = [hdr, sprintf('  %-*s', col_w, prior_names{k})]; %#ok<AGROW>
end
fprintf('%s\n', hdr);
fprintf('%s\n', repmat('-', 1, numel(hdr)));

for ri = 1:n_resp
    r = resp_idx(ri);
    % Usar label si disponible
    if isfield(Dataset, 'var_labels') && r <= numel(Dataset.var_labels)
        resp_label = Dataset.var_labels{r};
        if numel(resp_label) > 10
            resp_label = resp_label(1:10);
        end
    else
        resp_label = sprintf('Var%d', r);
    end

    for hi = 1:n_horizon
        h     = horizons(hi);
        h_idx = h + 1;   % h=0 -> row 1, h=4 -> row 5, ...

        row_label = sprintf('%s h=%d', resp_label, h);
        row_str   = sprintf('%-20s', row_label);

        for k = 1:n_prior
            Ldata = Results_list{k}.LtildeStruct.data;

            switch mode
                case 'pfa'
                    % Ltilde PFA: [horizon+1, nvar, nd]
                    med_val = median(Ldata(h_idx, r, :), 'all');
                case 'is'
                    % Ltilde IS:  [horizon+1, nvar, nvar, ne]
                    med_val = median(Ldata(h_idx, r, shock_idx, :), 'all');
            end

            row_str = [row_str, sprintf('  %+*.6f', col_w, med_val)]; %#ok<AGROW>
        end
        fprintf('%s\n', row_str);
    end
    % Linea en blanco entre variables
    if ri < n_resp
        fprintf('\n');
    end
end

fprintf('%s\n\n', repmat('-', 1, numel(hdr)));

end
