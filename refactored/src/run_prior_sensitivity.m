function Results_list = run_prior_sensitivity(spec_path, prior_list, Dataset, Cfg_base)
%RUN_PRIOR_SENSITIVITY  Compara medianas de IRFs entre variantes de prior.
%
%   Results_list = RUN_PRIOR_SENSITIVITY(spec_path, prior_list, Dataset, Cfg_base)
%
%   Parametros:
%     spec_path  — ruta absoluta al archivo de spec (solo se usa para el
%                  nombre del modelo en el output; Dataset y Cfg_base ya
%                  fueron cargados por el llamador)
%     prior_list — cell array de structs Cfg.PRIOR, e.g.:
%                  { struct('type','diffuse'), ...
%                    struct('type','minnesota','lambda1',0.1,'lambda2',0.5,'lambda3',1) }
%     Dataset    — struct devuelto por load_data
%     Cfg_base   — struct Cfg base (se sobreescribe solo el campo PRIOR)
%
%   Retorna:
%     Results_list — cell array de structs Results (uno por prior)
%
%   Imprime en consola:
%     Tabla de medianas de IRFs en los horizontes Cfg_base.SUMMARY_HORIZONS
%     para cada combinacion (shock, respuesta, horizonte).

%% ── Validaciones de entrada ──────────────────────────────────────────────
if isempty(prior_list) || ~iscell(prior_list)
    error('run_prior_sensitivity:invalidInput', ...
        'prior_list debe ser un cell array no vacio de structs Cfg.PRIOR.');
end
if numel(prior_list) < 1
    error('run_prior_sensitivity:invalidInput', ...
        'prior_list debe contener al menos 1 prior.');
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
if isfield(Cfg_base, 'RESP_IDX')
    resp_idx = Cfg_base.RESP_IDX;
else
    resp_idx = 1:Dataset.nvar;
end
if isfield(Cfg_base, 'SHOCK_IDX')
    shock_idx = Cfg_base.SHOCK_IDX;
else
    shock_idx = 1;   % primer shock por defecto
end

n_prior   = numel(prior_list);
n_horizon = numel(horizons);
n_resp    = numel(resp_idx);
n_shock   = numel(shock_idx);

%% ── Correr build_posterior + run_pfa/run_is para cada prior ─────────────
Results_list = cell(n_prior, 1);
prior_names  = cell(n_prior, 1);
mode_used    = cell(n_prior, 1);

fprintf('\n');
fprintf('============================================================\n');
fprintf('  RUN_PRIOR_SENSITIVITY\n');
if ~isempty(spec_path)
    [~, spec_name, ~] = fileparts(spec_path);
    fprintf('  Spec: %s\n', spec_name);
end
fprintf('  Priors: %d | Modo: %s\n', n_prior, upper(Cfg_base.MODE));
fprintf('============================================================\n\n');

for k = 1:n_prior
    pr_struct  = prior_list{k};
    prior_name = lower(strtrim(pr_struct.type));
    prior_names{k} = prior_name;

    fprintf('[%d/%d] Prior: %s ... ', k, n_prior, prior_name);

    % Sobreescribir solo el campo PRIOR en Cfg_base
    Cfg_k       = Cfg_base;
    Cfg_k.PRIOR = pr_struct;

    % Construir posterior con el prior k
    Posterior_k = build_posterior(Dataset, Cfg_k);

    % Correr muestreador segun el modo del spec
    rng(Cfg_base.SEED);
    switch lower(Cfg_base.MODE)
        case 'pfa'
            Results_k = run_pfa(Posterior_k, Cfg_k);
        case 'is'
            Results_k = run_is(Posterior_k, Cfg_k);
        otherwise
            error('run_prior_sensitivity:unknownMode', ...
                'MODE "%s" no reconocido. Use "pfa" o "is".', Cfg_base.MODE);
    end

    Results_list{k} = Results_k;
    mode_used{k}    = lower(Cfg_base.MODE);
    fprintf('OK\n');
end

%% ── Construir tabla de medianas ──────────────────────────────────────────
fprintf('\n');
fprintf('── Tabla de medianas IRF ───────────────────────────────────\n');
fprintf('   Horizontes: ');
fprintf('%d ', horizons);
fprintf('\n\n');

% Encabezado de columnas
hdr = sprintf('%-22s', 'Shock/Resp/H');
for k = 1:n_prior
    hdr = [hdr, sprintf('  %-16s', prior_names{k})]; %#ok<AGROW>
end
fprintf('%s\n', hdr);
fprintf('%s\n', repmat('-', 1, numel(hdr)));

% Filas: una por (shock, respuesta, horizonte)
for si = 1:n_shock
    s = shock_idx(si);
    for ri = 1:n_resp
        r = resp_idx(ri);
        for hi = 1:n_horizon
            h = horizons(hi);

            row_label = sprintf('S%d->R%d h=%d', s, r, h);
            row_str   = sprintf('%-22s', row_label);

            for k = 1:n_prior
                Ldata = Results_list{k}.LtildeStruct.data;
                nd_k  = size(Ldata, ndims(Ldata));

                if strcmpi(mode_used{k}, 'pfa')
                    % PFA: Ltilde es 3D [n_resp x n_shock x nd]
                    % Horizonte no esta en la dimension (IRFs ya son por draw)
                    % En PFA, Ltilde acumula draws; la dimension horizonte
                    % esta en compute_irfs_pfa. Verificamos estructura.
                    % Ldata: [n_resp, n_shock, nd] (IRF en horizonte max o promedio?)
                    % Nota: en el toolkit, Ltilde PFA es [n x n x nd] (draw-level)
                    %       donde cada draw es la IRF de un periodo especifico.
                    %       Para sensibilidad usamos la mediana sobre draws.
                    med_val = median(Ldata(r, s, :), 'all');
                else
                    % IS: Ltilde es 4D [n_resp x n_shock x n_horizons x nd_eff]
                    % Buscar indice del horizonte
                    if isfield(Results_list{k}, 'horizons')
                        hvec = Results_list{k}.horizons;
                    elseif isfield(Cfg_base, 'HORIZONS')
                        hvec = Cfg_base.HORIZONS;
                    else
                        hvec = 0:40;
                    end
                    h_idx = find(hvec == h, 1);
                    if isempty(h_idx)
                        med_val = NaN;
                    else
                        med_val = median(Ldata(r, s, h_idx, :), 'all');
                    end
                end

                row_str = [row_str, sprintf('  %+16.8f', med_val)]; %#ok<AGROW>
            end
            fprintf('%s\n', row_str);
        end
    end
end

fprintf('%s\n', repmat('-', 1, 22 + n_prior * 18));
fprintf('\n');

end
