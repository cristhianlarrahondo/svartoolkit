%DIAGNOSE_ERPT9_MM_MINN_V2  Extension del diagnostico anterior (ERPT-Chat 9):
%   ademas de L_denom (ner acumulado), ahora inspecciona L_price (con_inf
%   acumulado) y la relacion conjunta L_price/L_denom por draw, para
%   distinguir dos hipotesis:
%     (a) el patron erratico de mm_minn viene de un DENOMINADOR chico
%         (descartado por diagnose_erpt9_mm_minn.m -- L_denom no se ve
%         sistematicamente mas chico en mm_minn que en los comparadores);
%     (b) el patron viene de un NUMERADOR (L_price) sistematicamente mas
%         grande en mm_minn, o de una correlacion draw-a-draw entre
%         L_price y L_denom propia de esa combinacion transform x prior.
%
%   Como la MEDIANA de ERPT (no solo las colas) ya esta inflada en mm_minn,
%   y solo ~3-8%% de los draws tienen |L_denom|<0.1 (diagnostico previo),
%   un denominador chico en pocos draws no alcanza para mover una mediana
%   -- por eso se revisa el numerador y la correlacion conjunta.
%
%   NO corre ninguna estimacion nueva -- carga exclusivamente el cache ya
%   persistido por validate_erpt9.m. Si el cache no existe, error explicito.
%
%   Ejecutar COMPLETO (F5).

fprintf('\n');
fprintf('======================================================\n');
fprintf('   DIAGNOSTICO ERPT-CHAT 9 (v2) -- L_price, L_denom y su relacion conjunta\n');
fprintf('======================================================\n\n');

%% ── Rutas ────────────────────────────────────────────────────────────────
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(PROJ_CFG);
addpath(PROJ_SRC);

%% ── Specs a inspeccionar (mismos 6 del diagnostico previo) ─────────────
spec_names = { ...
    'spec_A_base_mm_minn_lag2_v0', 'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_rob_mm_minn_lag2_v0',  'spec_A_rob_mm_minn_lag4_v0', ...
    'spec_A_base_mm_diffuse_lag2_v0', ...
    'spec_A_base_aa_minn_lag2_v0' };

NAMED_SHOCKS    = {'Cam', 'Dem', 'Ofe'};
FOCUS_HORIZON   = 36;
FOCUS_PRICE_VAR = 'con_inf';   % misma variable de precio del digesto de consola de validate_erpt9.m

fprintf('  Specs inspeccionadas: %s\n', strjoin(spec_names, ', '));
fprintf('  Horizonte de foco: %d | price_var: %s\n\n', FOCUS_HORIZON, FOCUS_PRICE_VAR);

%% ── Loop principal ──────────────────────────────────────────────────────
for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};
    fprintf('------------------------------------------------------\n');
    fprintf('  Spec: %s\n', spec_name);
    fprintf('------------------------------------------------------\n');

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));

    out_dir    = Cfg.OUTPUT_DIR;
    cache_path = fullfile(out_dir, 'results_is.mat');
    if ~isfile(cache_path)
        error('diagnose_erpt9_mm_minn_v2:noCache', ...
            'No existe cache para %s (%s). Este script NO estima -- correr validate_erpt9.m primero.', ...
            spec_name, cache_path);
    end
    [Results_spec, ~, Dataset_spec, Cfg_cached] = load_erpt_run(out_dir);
    Cfg = Cfg_cached;

    if contains(spec_name, '_aa_')
        transform_type = 'aa';
    else
        transform_type = 'mm';
    end

    LtildeStruct = Results_spec.LtildeStruct;
    endo_mask  = strcmp(Dataset_spec.var_roles, 'endogenous');
    var_names  = Dataset_spec.var_names(endo_mask);
    denom_idx  = find(strcmp(var_names, 'ner'), 1);
    price_idx  = find(strcmp(var_names, FOCUS_PRICE_VAR), 1);

    if strcmp(transform_type, 'aa')
        switch Dataset_spec.freq
            case 'M', lag = 12;
            case 'Q', lag = 4;
            case 'A', lag = 1;
        end
    else
        lag = [];
    end

    shock_names_cfg = {};
    if isfield(Cfg, 'SHOCK_NAMES') && ~isempty(Cfg.SHOCK_NAMES)
        shock_names_cfg = Cfg.SHOCK_NAMES;
    end

    response_idx = unique([denom_idx, price_idx], 'stable');
    [irfs_by_shock, ~, ~, shock_idx_resolved] = ...
        select_irfs(LtildeStruct, 'all', response_idx, shock_names_cfg);
    pos_denom = find(response_idx == denom_idx, 1);
    pos_price = find(response_idx == price_idx, 1);

    horizon_max = LtildeStruct.horizon;
    h_idx = FOCUS_HORIZON + 1;
    if FOCUS_HORIZON > horizon_max
        error('diagnose_erpt9_mm_minn_v2:badHorizon', ...
            'FOCUS_HORIZON=%d excede horizon_max=%d para %s.', FOCUS_HORIZON, horizon_max, spec_name);
    end

    fprintf('  %-6s %10s %10s %10s %10s %10s %12s %14s\n', ...
        'shock', 'med|Lp|', 'p95|Lp|', 'med|Ld|', 'corr(Lp,Ld)', 'med(ratio)', 'med(ratio)', 'med(ratio)');
    fprintf('  %-6s %10s %10s %10s %10s %10s %12s %14s\n', ...
        '', '', '', '', '', 'TODOS', 'Ld_chico*', 'Ld_grande*');

    for j = 1:numel(shock_idx_resolved)
        sidx  = shock_idx_resolved(j);
        label = resolve_shock_name(shock_names_cfg, sidx);
        if ~ismember(label, NAMED_SHOCKS)
            continue;
        end

        irfs_j = irfs_by_shock{j};   % [horizon+1 x numel(response_idx) x ndraws]

        L_denom_full = p_accumulate_local(irfs_j(:, pos_denom, :), transform_type, lag);
        L_price_full = p_accumulate_local(irfs_j(:, pos_price, :), transform_type, lag);

        L_denom = squeeze(L_denom_full(h_idx, 1, :));   % [ndraws x 1]
        L_price = squeeze(L_price_full(h_idx, 1, :));   % [ndraws x 1]
        ratio   = L_price ./ L_denom;

        n_draws  = numel(L_denom);
        med_Lp   = median(abs(L_price));
        p95_Lp   = quantile(abs(L_price), 0.95);
        med_Ld   = median(abs(L_denom));
        corr_pd  = corr(L_price, L_denom);
        med_ratio_all = median(ratio);

        % Submuestra "Ld chico": el 25% de draws con |L_denom| mas pequeno.
        % Submuestra "Ld grande": el 25% de draws con |L_denom| mas grande.
        [~, order] = sort(abs(L_denom));
        n_q = round(n_draws * 0.25);
        idx_small = order(1:n_q);
        idx_large = order(end-n_q+1:end);
        med_ratio_small = median(ratio(idx_small));
        med_ratio_large = median(ratio(idx_large));

        fprintf('  %-6s %10.4f %10.4f %10.4f %10.4f %12.4f %14.4f %14.4f\n', ...
            label, med_Lp, p95_Lp, med_Ld, corr_pd, med_ratio_all, med_ratio_small, med_ratio_large);
    end
    fprintf('\n');
end

fprintf('======================================================\n');
fprintf('  Lectura:\n');
fprintf('  - med|Lp|, p95|Lp| = magnitud del NUMERADOR (con_inf acumulado). Si\n');
fprintf('    mm_minn tiene medianas de |L_price| sistematicamente mas grandes\n');
fprintf('    que mm_diffuse/aa_minn (con med|Ld| similar), la inflacion del ERPT\n');
fprintf('    viene del numerador, no del denominador.\n');
fprintf('  - corr(Lp,Ld) = correlacion draw-a-draw entre precio y ner acumulados.\n');
fprintf('    Una correlacion propia de mm_minn (alta o de signo distinto a los\n');
fprintf('    comparadores) sugiere que la combinacion transform x prior induce\n');
fprintf('    una dependencia conjunta que no se ve mirando cada variable sola.\n');
fprintf('  - med(ratio) TODOS vs Ld_chico (25%% de draws con |L_denom| mas chico)\n');
fprintf('    vs Ld_grande (25%% con |L_denom| mas grande): si el ratio en\n');
fprintf('    Ld_chico es mucho mayor que en Ld_grande, la inflacion SI se\n');
fprintf('    concentra en los draws de denominador chico (matiza el diagnostico\n');
fprintf('    previo); si son similares entre si y ya inflados respecto a los\n');
fprintf('    comparadores, la inflacion es un fenomeno de la mayoria de draws,\n');
fprintf('    no de una cola con denominador chico.\n');
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat.\n\n');


%% ── Helper local (misma logica que calculate_erpt.m / p_accumulate) ────────
function L = p_accumulate_local(irf_slice, transform_type, lag)
    switch transform_type
        case 'mm'
            L = compute_cirfs(irf_slice);
        case 'aa'
            H = size(irf_slice, 1);
            L = zeros(size(irf_slice));
            for h = 1:H
                if h <= lag
                    L(h, 1, :) = irf_slice(h, 1, :);
                else
                    L(h, 1, :) = irf_slice(h, 1, :) + L(h - lag, 1, :);
                end
            end
        otherwise
            error('diagnose_erpt9_mm_minn_v2:badTransform', ...
                'transform_type interno invalido: ''%s''.', transform_type);
    end
end
