function ERPT = calculate_erpt(Results, Dataset, Cfg, transform_type, price_vars, denom_var, horizons)
%CALCULATE_ERPT  Exchange Rate Pass-Through a partir de draws IS (ARW 2018).
%
%   ERPT = CALCULATE_ERPT(Results, Dataset, Cfg, transform_type)
%   ERPT = CALCULATE_ERPT(Results, Dataset, Cfg, transform_type, price_vars, denom_var, horizons)
%
%   Implementa la formula unica acordada en ERPT-Chat 1 (decision 1), la
%   MISMA para todos los choques identificados (no hay distincion entre
%   "ERPT normal" y "ERPT shock-dependent"):
%
%       ERPT_{precio,j}(h) = L_{precio,j}(h) / L_{ner,j}(h)
%
%   donde L_{var,j}(h) es el nivel acumulado (decision 2) de la respuesta
%   de `var` al choque `j` en el horizonte `h`, y el ratio se calcula
%   POR DRAW antes de tomar mediana/bandas (decision 6).
%
%   ── Entradas ──────────────────────────────────────────────────────────
%     Results         struct de run_is.m. Debe traer Results.LtildeStruct
%                     con .mode == 'is' (este proyecto no usa PFA).
%     Dataset         struct de load_data.m (var_names, var_roles,
%                     var_labels, freq — mismo orden que LtildeStruct).
%     Cfg             struct de la spec activa. Campos usados (todos con
%                     default seguro si faltan):
%                       SHOCK_IDX       escalar | vector | 'all' (default 'all')
%                       SHOCK_NAMES     cell array de nombres (default {})
%                       CRED_BANDS      [N x 2] percentiles (default [0.16 0.84])
%                       ERPT_PRICE_VARS cell array (override de price_vars,
%                                       solo si el argumento no se paso)
%                       ERPT_DENOM_VAR  string (override de denom_var, solo
%                                       si el argumento no se paso)
%                       ERPT_HORIZONS   vector (override de horizons, solo
%                                       si el argumento no se paso)
%     transform_type  'mm' | 'aa'  — OBLIGATORIO, ver Nota 1 abajo.
%     price_vars      cell array de nombres de variables de precio.
%                     Precedencia: argumento explicito > Cfg.ERPT_PRICE_VARS
%                     > default {'imp_inf','pro_inf','con_inf'} (importados,
%                     productor, consumidor — decision 5 revisada en
%                     ERPT-Chat 2: originalmente 2 variables, ahora 3).
%                     OJO: esta convencion de nombres es la de
%                     data_erpt_mm.xlsx / data_erpt_aa.xlsx (los archivos
%                     nuevos). El archivo legacy data_erpt.xlsx
%                     (spec_v0.m/spec_v1.m actuales) usa nombres DISTINTOS
%                     (inf_imp, inf_p, inf_con) -- si se llama esta funcion
%                     contra ese dataset legacy hay que pasar price_vars
%                     explicito con esos nombres.
%     denom_var       nombre de la variable denominador. Precedencia:
%                     argumento explicito > Cfg.ERPT_DENOM_VAR > default
%                     'ner'.
%     horizons        vector de horizontes 0-based a reportar, en la
%                     unidad nativa de Dataset (meses en este proyecto).
%                     Precedencia: argumento explicito > Cfg.ERPT_HORIZONS
%                     > default [3 6 12 24 36] (3m, 6m, 1a, 2a, 3a —
%                     decision 3 revisada en ERPT-Chat 2: originalmente
%                     [1 6 12 24]). El mismo vector de horizontes aplica
%                     igual para 'mm' y 'aa': ambos representan el mismo
%                     objeto (nivel acumulado) en la misma escala temporal
%                     de meses, por construccion (ver decision 2) -- no
%                     requiere ajuste distinto por transform_type.
%
%   ── Salida ────────────────────────────────────────────────────────────
%     ERPT.transform_type, .horizons, .cred_bands, .denom_var, .price_vars
%     ERPT.shocks(k).idx      indice real del choque (columna de B)
%     ERPT.shocks(k).name     nombre resuelto (Cfg.SHOCK_NAMES o 'shockN')
%     ERPT.shocks(k).prices(p).var          nombre de la variable de precio
%     ERPT.shocks(k).prices(p).median       [1 x nh]
%     ERPT.shocks(k).prices(p).band_lo      [n_bands x nh]
%     ERPT.shocks(k).prices(p).band_hi      [n_bands x nh]
%     ERPT.shocks(k).prices(p).ratio_draws  [nh x ndraws] — crudo, sin
%                                            filtrar (decision 6), insumo
%                                            directo para la tabla
%                                            comparativa de ERPT-Chat 4.
%
%   ── Nota 1: por que transform_type es obligatorio y no se infiere ──────
%   Dataset.freq describe la PERIODICIDAD del muestreo (mensual/trimestral/
%   anual), no si la serie ya fue transformada a variacion mensual (m/m) o
%   interanual (a/a) antes de entrar al SVAR — esa transformacion ocurre
%   fuera del loader (Excel) y hoy no queda registrada en ningun campo de
%   Cfg/Dataset. Forzar el argumento explicito evita adivinar y evita un
%   error silencioso que cambiaria los numeros sin generar ningun error de
%   ejecucion.
%
%   ── Nota 2: reconstruccion de nivel L(h) (ERPT-Chat 1, decision 2) ──────
%     m/m:  L(h) = IRF(0) + IRF(1) + ... + IRF(h)          (CIRF estandar,
%           compute_cirfs.m, cumsum plano)
%     a/a:  L(h) = IRF_aa(h)                    para h < lag
%           L(h) = IRF_aa(h) + L(h-lag)          para h >= lag
%           lag se deriva de Dataset.freq (12 si 'M', 4 si 'Q', 1 si 'A');
%           HOY es 12 porque los datos del proyecto son mensuales
%           (confirmado — ver nota tecnica en el cierre de ERPT-Chat 1).
%
%   ── Nota 3: choques procesados ───────────────────────────────────────
%   Se procesan los choques indicados por Cfg.SHOCK_IDX (default 'all' =
%   1:nvar), exactamente el mismo criterio que select_irfs.m/
%   print_summary.m ya usan en el resto del pipeline. Esto hace que la
%   funcion sea agnostica al numero de choques con nombre economico
%   definido en la spec activa (hoy spec_v0/spec_v1 solo nombran 3 de los
%   6 — Cam, Dem, Ofe; los demas caen a 'shock4'/'shock5'/'shock6' via
%   resolve_shock_name.m). Si una spec futura (ERPT-Chat 3) agrega un
%   cuarto choque nombrado (p.ej. 'Mon'), esta funcion no requiere ningun
%   cambio.
%
%   Vive en projects/erpt/src/calculate_erpt.m — NO toca src/ compartido,
%   NO requiere regresion BNW (Tipo S, ver B.6 y cierre de ERPT-Chat 2).
%
%   Ver tambien: select_irfs.m, compute_cirfs.m, resolve_shock_name.m

%% ── Defaults de argumentos opcionales (arg explicito > Cfg.ERPT_* > hardcoded) ─
if nargin < 7 || isempty(horizons)
    if isfield(Cfg, 'ERPT_HORIZONS') && ~isempty(Cfg.ERPT_HORIZONS)
        horizons = Cfg.ERPT_HORIZONS;
    else
        horizons = [3 6 12 24 36];   % 3m, 6m, 1a, 2a, 3a
    end
end
if nargin < 6 || isempty(denom_var)
    if isfield(Cfg, 'ERPT_DENOM_VAR') && ~isempty(Cfg.ERPT_DENOM_VAR)
        denom_var = Cfg.ERPT_DENOM_VAR;
    else
        denom_var = 'ner';
    end
end
if nargin < 5 || isempty(price_vars)
    if isfield(Cfg, 'ERPT_PRICE_VARS') && ~isempty(Cfg.ERPT_PRICE_VARS)
        price_vars = Cfg.ERPT_PRICE_VARS;
    else
        price_vars = {'imp_inf', 'pro_inf', 'con_inf'};   % convencion data_erpt_mm/aa.xlsx
    end
end
if nargin < 4 || isempty(transform_type)
    error('calculate_erpt:missingTransform', ...
        ['transform_type es obligatorio: ''mm'' (CIRF estandar) o ''aa'' ' ...
         '(reconstruccion recursiva con rezago). No se infiere de ' ...
         'Dataset.freq -- ver Nota 1 en el encabezado de esta funcion.']);
end
transform_type = lower(transform_type);
if ~ismember(transform_type, {'mm', 'aa'})
    error('calculate_erpt:badTransform', ...
        'transform_type debe ser ''mm'' o ''aa''. Recibido: ''%s''.', transform_type);
end
if ~iscell(price_vars) || isempty(price_vars)
    error('calculate_erpt:badPriceVars', ...
        'price_vars debe ser un cell array no vacio de nombres de variable.');
end

%% ── Validar Results.LtildeStruct (solo IS en este proyecto) ─────────────
if ~isfield(Results, 'LtildeStruct')
    error('calculate_erpt:missingLtildeStruct', 'Results.LtildeStruct no existe.');
end
LtildeStruct = Results.LtildeStruct;
if ~isfield(LtildeStruct, 'mode') || ~strcmpi(LtildeStruct.mode, 'is')
    error('calculate_erpt:onlyIS', ...
        ['calculate_erpt.m asume flujo IS (projects/erpt no tiene rama PFA). ' ...
         'Mode recibido: %s.'], LtildeStruct.mode);
end

%% ── Adjuntar var_labels a LtildeStruct (mismo patron que print_summary.m) ─
if ~isfield(Dataset, 'var_roles') || ~isfield(Dataset, 'var_names')
    error('calculate_erpt:badDataset', ...
        'Dataset debe traer var_names y var_roles (ver load_data.m).');
end
endo_mask = strcmp(Dataset.var_roles, 'endogenous');
var_names = Dataset.var_names(endo_mask);
if isfield(Dataset, 'var_labels') && ~isempty(Dataset.var_labels)
    LtildeStruct.var_labels = Dataset.var_labels(endo_mask);
end

%% ── Resolver indices de variables por NOMBRE (nunca por posicion) ───────
denom_idx = p_resolve_var_idx(var_names, denom_var);
n_prices  = numel(price_vars);
price_idx = zeros(1, n_prices);
for i = 1:n_prices
    price_idx(i) = p_resolve_var_idx(var_names, price_vars{i});
end

%% ── Validar horizontes contra el horizonte maximo estimado ──────────────
horizon_max = LtildeStruct.horizon;
horizons = horizons(:)';
if any(horizons < 0) || any(horizons > horizon_max)
    error('calculate_erpt:badHorizons', ...
        'horizons debe estar en [0, %d]. Recibido: %s.', horizon_max, mat2str(horizons));
end
nh    = numel(horizons);
h_idx = horizons + 1;   % LtildeStruct.data: fila 1 = horizonte 0

%% ── Rezago para reconstruccion a/a (Nota 2) ──────────────────────────────
if strcmp(transform_type, 'aa')
    lag = p_resolve_aa_lag(Dataset);
    if any(horizons < 0)
        error('calculate_erpt:badHorizons', 'horizons no puede ser negativo.');
    end
else
    lag = [];
end

%% ── Choques a procesar (Nota 3): mismo criterio que select_irfs.m ───────
shock_idx_req = 'all';
if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
    shock_idx_req = Cfg.SHOCK_IDX;
end
shock_names = {};
if isfield(Cfg, 'SHOCK_NAMES') && ~isempty(Cfg.SHOCK_NAMES)
    shock_names = Cfg.SHOCK_NAMES;
end

%% ── Bandas de credibilidad (mismo formato que print_summary.m) ──────────
cred_bands = [0.16 0.84];
if isfield(Cfg, 'CRED_BANDS') && ~isempty(Cfg.CRED_BANDS)
    cb = Cfg.CRED_BANDS;
    if isvector(cb), cb = reshape(cb, 1, []); end
    if size(cb, 2) == 2
        cred_bands = cb;
    end
end
n_bands = size(cred_bands, 1);

%% ── Extraer IRFs (ner + precios) para todos los choques en una sola llamada
response_idx = unique([denom_idx, price_idx], 'stable');
[irfs_by_shock, ~, ~, shock_idx_resolved] = ...
    select_irfs(LtildeStruct, shock_idx_req, response_idx, shock_names);

pos_denom = find(response_idx == denom_idx, 1);
n_shocks  = numel(shock_idx_resolved);

%% ── Construir salida ──────────────────────────────────────────────────
ERPT = struct();
ERPT.transform_type = transform_type;
ERPT.horizons       = horizons;
ERPT.cred_bands     = cred_bands;
ERPT.denom_var      = denom_var;
ERPT.price_vars     = price_vars;
ERPT.shocks         = struct('idx', {}, 'name', {}, 'prices', {});

for j = 1:n_shocks
    sidx   = shock_idx_resolved(j);
    label  = resolve_shock_name(shock_names, sidx);
    irfs_j = irfs_by_shock{j};   % [horizon+1 x numel(response_idx) x ndraws]

    L_denom   = p_accumulate(irfs_j(:, pos_denom, :), transform_type, lag);
    L_denom_h = reshape(L_denom(h_idx, 1, :), nh, []);   % [nh x ndraws]

    shock_entry = struct('idx', sidx, 'name', label, ...
        'prices', struct('var', {}, 'median', {}, 'band_lo', {}, 'band_hi', {}, 'ratio_draws', {}));

    for p = 1:n_prices
        pos_price = find(response_idx == price_idx(p), 1);
        L_price   = p_accumulate(irfs_j(:, pos_price, :), transform_type, lag);
        L_price_h = reshape(L_price(h_idx, 1, :), nh, []);   % [nh x ndraws]

        % Decision 6: ratio POR DRAW, primero; sin filtrar denominadores
        % cercanos a cero ni cruces de signo (esperado, en particular en
        % S3/oferta bajo Opcion B set-identificada).
        ratio = L_price_h ./ L_denom_h;   % [nh x ndraws]

        med = zeros(1, nh);
        blo = zeros(n_bands, nh);
        bhi = zeros(n_bands, nh);
        for hh = 1:nh
            sl = ratio(hh, :);
            med(hh) = quantile(sl, 0.50);
            for bb = 1:n_bands
                blo(bb, hh) = quantile(sl, cred_bands(bb, 1));
                bhi(bb, hh) = quantile(sl, cred_bands(bb, 2));
            end
        end

        price_entry.var         = price_vars{p};
        price_entry.median      = med;
        price_entry.band_lo     = blo;
        price_entry.band_hi     = bhi;
        price_entry.ratio_draws = ratio;

        shock_entry.prices(end+1) = price_entry;
    end

    ERPT.shocks(end+1) = shock_entry;
end

end


%% ── Helpers locales ──────────────────────────────────────────────────────

function idx = p_resolve_var_idx(var_names, name)
%P_RESOLVE_VAR_IDX  Indice de `name` dentro de var_names (endogenas), por
%   NOMBRE (nunca por posicion) -- convencion obligatoria del toolkit.
    idx = find(strcmp(var_names, name), 1);
    if isempty(idx)
        error('calculate_erpt:varNotFound', ...
            'Variable ''%s'' no encontrada en Dataset.var_names (endogenas): %s.', ...
            name, strjoin(var_names, ', '));
    end
end

function lag = p_resolve_aa_lag(Dataset)
%P_RESOLVE_AA_LAG  Rezago de reconstruccion a/a segun Dataset.freq.
    if ~isfield(Dataset, 'freq')
        error('calculate_erpt:missingFreq', 'Dataset.freq no existe.');
    end
    switch Dataset.freq
        case 'M'
            lag = 12;
        case 'Q'
            lag = 4;
        case 'A'
            lag = 1;
        otherwise
            error('calculate_erpt:unknownFreq', ...
                ['No se pudo derivar el rezago de reconstruccion a/a: ' ...
                 'Dataset.freq = ''%s'' no reconocido (esperado M/Q/A).'], ...
                Dataset.freq);
    end
end

function L = p_accumulate(irf_slice, transform_type, lag)
%P_ACCUMULATE  Nivel acumulado L(h) segun ERPT-Chat 1, decision 2.
%
%   irf_slice: [horizon+1 x 1 x ndraws]
%   'mm': CIRF estandar (compute_cirfs.m, cumsum plano sobre dim 1)
%   'aa': L(h) = IRF(h) para h < lag; L(h) = IRF(h) + L(h-lag) para h >= lag
    switch transform_type
        case 'mm'
            L = compute_cirfs(irf_slice);
        case 'aa'
            H = size(irf_slice, 1);
            L = zeros(size(irf_slice));
            for h = 1:H   % h=1 <-> horizonte 0
                if h <= lag
                    L(h, 1, :) = irf_slice(h, 1, :);
                else
                    L(h, 1, :) = irf_slice(h, 1, :) + L(h - lag, 1, :);
                end
            end
        otherwise
            error('calculate_erpt:badTransform', ...
                'transform_type interno invalido: ''%s''.', transform_type);
    end
end
