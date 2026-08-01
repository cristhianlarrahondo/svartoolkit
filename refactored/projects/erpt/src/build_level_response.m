function Level = build_level_response(Results, Dataset, Cfg, transform_type, resp_vars)
%BUILD_LEVEL_RESPONSE  Serie L(h) (nivel acumulado) por choque y variable,
%   en TODOS los horizontes 0..HORIZON -- objeto de la Figura 2 (ERPT-Chat
%   21, decision 2), que reemplaza a la CIRF generica (cumsum) para
%   variables a/a.
%
%   Level = BUILD_LEVEL_RESPONSE(Results, Dataset, Cfg, transform_type)
%   Level = BUILD_LEVEL_RESPONSE(Results, Dataset, Cfg, transform_type, resp_vars)
%
%   NO es un calculo nuevo: reutiliza exactamente la misma recursion que
%   calculate_erpt.m usa internamente para la Tabla 1 (ERPT-Chat 1,
%   decision 2) -- ahora expuesta como accumulate_level.m/resolve_aa_lag.m
%   (ERPT-Chat 22) -- pero evaluada en TODOS los horizontes (para graficar
%   una serie continua) en vez de solo en el vector discreto de
%   Cfg.ERPT_HORIZONS (que es lo que necesita la Tabla 1).
%
%   ── Entradas ─────────────────────────────────────────────────────────
%     Results         struct de run_is.m (Results.LtildeStruct, mode='is').
%     Dataset         struct de load_data.m (var_names, var_roles,
%                     var_labels, freq).
%     Cfg             struct de la spec activa. Campos usados:
%                       SHOCK_IDX    escalar | vector | 'all' (default 'all')
%                       SHOCK_NAMES  cell array (default {})
%                       CRED_BANDS   [N x 2] (default [0.16 0.84])
%                       ERPT_DENOM_VAR (default 'ner', se antepone a
%                                      resp_vars si no viene ya incluida)
%     transform_type  'mm' | 'aa' -- OBLIGATORIO, mismo criterio que
%                     calculate_erpt.m (Nota 1 de ese archivo).
%     resp_vars       cell array de nombres de variable a incluir (orden
%                     preservado). Default: Cfg.ERPT_DENOM_VAR seguido de
%                     Cfg.ERPT_PRICE_VARS (mismo default que
%                     calculate_erpt.m) -- p.ej. {'ner','imp_inf',
%                     'pro_inf','con_inf'}, para que la Figura 2 incluya
%                     el panel de `ner` junto a los precios (decision 2).
%
%   ── Salida ───────────────────────────────────────────────────────────
%     Level.transform_type, .horizons (0:HORIZON), .cred_bands, .vars
%     Level.shocks(k).idx      indice real del choque
%     Level.shocks(k).name     nombre resuelto (Cfg.SHOCK_NAMES o 'shockN')
%     Level.shocks(k).vars(v).var       nombre de la variable
%     Level.shocks(k).vars(v).median    [1 x (HORIZON+1)]
%     Level.shocks(k).vars(v).band_lo   [n_bands x (HORIZON+1)]
%     Level.shocks(k).vars(v).band_hi   [n_bands x (HORIZON+1)]
%
%   Vive en projects/erpt/src/build_level_response.m -- Tipo S, NO toca
%   src/ compartido, NO modifica compute_cirfs.m (core), NO requiere
%   regresion BNW.
%
%   Ver tambien: calculate_erpt.m, accumulate_level.m, resolve_aa_lag.m,
%   graficar_nivel.m, select_irfs.m

%% ── Validar transform_type (mismo criterio que calculate_erpt.m) ────────
if nargin < 4 || isempty(transform_type)
    error('build_level_response:missingTransform', ...
        'transform_type es obligatorio: ''mm'' o ''aa'' (ver Nota 1 en calculate_erpt.m).');
end
transform_type = lower(transform_type);
if ~ismember(transform_type, {'mm', 'aa'})
    error('build_level_response:badTransform', ...
        'transform_type debe ser ''mm'' o ''aa''. Recibido: ''%s''.', transform_type);
end

%% ── Validar Results.LtildeStruct (solo IS en este proyecto) ─────────────
if ~isfield(Results, 'LtildeStruct')
    error('build_level_response:missingLtildeStruct', 'Results.LtildeStruct no existe.');
end
LtildeStruct = Results.LtildeStruct;
if ~isfield(LtildeStruct, 'mode') || ~strcmpi(LtildeStruct.mode, 'is')
    error('build_level_response:onlyIS', ...
        ['build_level_response.m asume flujo IS (projects/erpt no tiene rama ' ...
         'PFA). Mode recibido: %s.'], LtildeStruct.mode);
end

%% ── Adjuntar var_labels a LtildeStruct (mismo patron que calculate_erpt.m)
if ~isfield(Dataset, 'var_roles') || ~isfield(Dataset, 'var_names')
    error('build_level_response:badDataset', ...
        'Dataset debe traer var_names y var_roles (ver load_data.m).');
end
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
var_names = Dataset.var_names(endo_mask);
if isfield(Dataset, 'var_labels') && ~isempty(Dataset.var_labels)
    LtildeStruct.var_labels = Dataset.var_labels(endo_mask);
end

%% ── Variables de respuesta: default = denom + price_vars (Nota, arriba) ─
if nargin < 5 || isempty(resp_vars)
    denom_var = 'ner';
    if isfield(Cfg, 'ERPT_DENOM_VAR') && ~isempty(Cfg.ERPT_DENOM_VAR)
        denom_var = Cfg.ERPT_DENOM_VAR;
    end
    if isfield(Cfg, 'ERPT_PRICE_VARS') && ~isempty(Cfg.ERPT_PRICE_VARS)
        price_vars = Cfg.ERPT_PRICE_VARS;
    else
        price_vars = {'imp_inf', 'pro_inf', 'con_inf'};
    end
    resp_vars = [{denom_var}, price_vars];
end
if ~iscell(resp_vars) || isempty(resp_vars)
    error('build_level_response:badRespVars', ...
        'resp_vars debe ser un cell array no vacio de nombres de variable.');
end

n_vars    = numel(resp_vars);
resp_idx  = zeros(1, n_vars);
for i = 1:n_vars
    idx = find(strcmp(var_names, resp_vars{i}), 1);
    if isempty(idx)
        error('build_level_response:varNotFound', ...
            'Variable ''%s'' no encontrada en Dataset.var_names (endogenas): %s.', ...
            resp_vars{i}, strjoin(var_names, ', '));
    end
    resp_idx(i) = idx;
end

%% ── Rezago a/a (Nota 2 de calculate_erpt.m, ahora en resolve_aa_lag.m) ───
if strcmp(transform_type, 'aa')
    lag = resolve_aa_lag(Dataset);
else
    lag = [];
end

%% ── Choques a procesar: mismo criterio que calculate_erpt.m/select_irfs.m
shock_idx_req = 'all';
if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
    shock_idx_req = Cfg.SHOCK_IDX;
end
shock_names = {};
if isfield(Cfg, 'SHOCK_NAMES') && ~isempty(Cfg.SHOCK_NAMES)
    shock_names = Cfg.SHOCK_NAMES;
end

%% ── Bandas de credibilidad (mismo formato que calculate_erpt.m) ──────────
cred_bands = [0.16 0.84];
if isfield(Cfg, 'CRED_BANDS') && ~isempty(Cfg.CRED_BANDS)
    cb = Cfg.CRED_BANDS;
    if isvector(cb), cb = reshape(cb, 1, []); end
    if size(cb, 2) == 2
        cred_bands = cb;
    end
end
n_bands = size(cred_bands, 1);

%% ── Horizontes: TODOS (0..HORIZON), no el vector discreto de la Tabla 1 ─
horizon_max = LtildeStruct.horizon;
horizons    = 0:horizon_max;
nh          = numel(horizons);

%% ── Extraer IRFs de todas las variables pedidas, para todos los choques ─
[irfs_by_shock, ~, ~, shock_idx_resolved] = ...
    select_irfs(LtildeStruct, shock_idx_req, resp_idx, shock_names);
n_shocks = numel(shock_idx_resolved);

%% ── Construir salida ──────────────────────────────────────────────────
Level = struct();
Level.transform_type = transform_type;
Level.horizons        = horizons;
Level.cred_bands       = cred_bands;
Level.vars             = resp_vars;
Level.shocks           = struct('idx', {}, 'name', {}, 'vars', {});

for j = 1:n_shocks
    sidx   = shock_idx_resolved(j);
    label  = resolve_shock_name(shock_names, sidx);
    irfs_j = irfs_by_shock{j};   % [horizon+1 x numel(resp_idx) x ndraws]

    shock_entry = struct('idx', sidx, 'name', label, ...
        'vars', struct('var', {}, 'median', {}, 'band_lo', {}, 'band_hi', {}));

    for v = 1:n_vars
        L_v = accumulate_level(irfs_j(:, v, :), transform_type, lag);   % [nh x 1 x ndraws]

        med = zeros(1, nh);
        blo = zeros(n_bands, nh);
        bhi = zeros(n_bands, nh);
        for hh = 1:nh
            sl = reshape(L_v(hh, 1, :), 1, []);
            med(hh) = quantile(sl, 0.50);
            for bb = 1:n_bands
                blo(bb, hh) = quantile(sl, cred_bands(bb, 1));
                bhi(bb, hh) = quantile(sl, cred_bands(bb, 2));
            end
        end

        var_entry.var     = resp_vars{v};
        var_entry.median  = med;
        var_entry.band_lo = blo;
        var_entry.band_hi = bhi;

        shock_entry.vars(end+1) = var_entry;
    end

    Level.shocks(end+1) = shock_entry;
end

end
