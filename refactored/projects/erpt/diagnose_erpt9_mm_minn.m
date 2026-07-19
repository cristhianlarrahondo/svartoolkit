%DIAGNOSE_ERPT9_MM_MINN  Diagnostico puntual (ERPT-Chat 9): inspecciona la
%   distribucion por draw de L_denom (nivel acumulado de 'ner', el
%   denominador del ratio de ERPT) en las 4 specs *_mm_minn_* frente a dos
%   comparadores (misma transform con prior distinto, mismo prior con
%   transform distinta), para verificar si el patron erratico de medianas
%   de ERPT (0.45-2.04, ver output de consola de este chat) se explica por
%   un denominador L_denom cercano a cero en esa combinacion especifica.
%
%   NO es un validate_*.m del protocolo de cierre -- es un script de
%   analisis exploratorio de un solo uso. NO corre ninguna estimacion
%   nueva: carga exclusivamente el cache ya persistido por validate_erpt9.m
%   (results_is.mat de cada spec). Si el cache no existe para alguna spec,
%   lanza error explicito (no estima nada por su cuenta).
%
%   Reproduce, para 'ner' unicamente (no para los price_vars), la misma
%   logica de acumulacion y seleccion de choques que calculate_erpt.m
%   (select_irfs + p_accumulate/compute_cirfs), usando directamente las
%   funciones ya existentes del core (select_irfs.m, compute_cirfs.m,
%   resolve_shock_name.m) -- no se duplica logica de negocio, solo se
%   inspecciona un intermedio (L_denom) que calculate_erpt.m no expone en
%   su salida (ERPT.shocks(k).prices(p).ratio_draws es el ratio ya
%   dividido, no el denominador).
%
%   Ejecutar COMPLETO (F5).

fprintf('\n');
fprintf('======================================================\n');
fprintf('   DIAGNOSTICO ERPT-CHAT 9 -- L_denom (ner) en mm_minn vs comparadores\n');
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

%% ── Specs a inspeccionar ────────────────────────────────────────────────
% Las 4 mm_minn (el patron erratico) + 2 comparadores: mismo transform
% (mm) con prior distinto (diffuse), y mismo prior (minn) con transform
% distinta (aa). Todos lag2 para simplificar la comparacion (el patron ya
% se ve en lag2 y lag4 por igual en el output de consola).
spec_names = { ...
    'spec_A_base_mm_minn_lag2_v0', 'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_rob_mm_minn_lag2_v0',  'spec_A_rob_mm_minn_lag4_v0', ...
    'spec_A_base_mm_diffuse_lag2_v0', ...   % comparador: mismo transform (mm), prior diffuse
    'spec_A_base_aa_minn_lag2_v0' };        % comparador: mismo prior (minn), transform aa

NAMED_SHOCKS  = {'Cam', 'Dem', 'Ofe'};
FOCUS_HORIZON = 36;

fprintf('  Specs inspeccionadas: %s\n', strjoin(spec_names, ', '));
fprintf('  Horizonte de foco: %d\n\n', FOCUS_HORIZON);

%% ── Loop principal ──────────────────────────────────────────────────────
for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};
    fprintf('------------------------------------------------------\n');
    fprintf('  Spec: %s\n', spec_name);
    fprintf('------------------------------------------------------\n');

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));

    out_dir = Cfg.OUTPUT_DIR;
    cache_path = fullfile(out_dir, 'results_is.mat');
    if ~isfile(cache_path)
        error('diagnose_erpt9_mm_minn:noCache', ...
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

    response_idx = denom_idx;   % solo 'ner' -- este diagnostico no mira precios
    [irfs_by_shock, ~, ~, shock_idx_resolved] = ...
        select_irfs(LtildeStruct, 'all', response_idx, shock_names_cfg);

    horizon_max = LtildeStruct.horizon;
    if FOCUS_HORIZON > horizon_max
        error('diagnose_erpt9_mm_minn:badHorizon', ...
            'FOCUS_HORIZON=%d excede horizon_max=%d para %s.', FOCUS_HORIZON, horizon_max, spec_name);
    end
    h_idx = FOCUS_HORIZON + 1;

    fprintf('  %-6s %8s %10s %10s %10s %10s %12s %14s %14s\n', ...
        'shock', 'ndraws', 'p05', 'median', 'p95', 'min|L|', 'frac|L|<0.5', 'frac|L|<0.1', 'frac signo!=med');

    for j = 1:numel(shock_idx_resolved)
        sidx  = shock_idx_resolved(j);
        label = resolve_shock_name(shock_names_cfg, sidx);
        if ~ismember(label, NAMED_SHOCKS)
            continue;   % solo Cam/Dem/Ofe -- residuales fuera de alcance de este diagnostico
        end

        irfs_j = irfs_by_shock{j};   % [horizon+1 x 1 x ndraws]

        switch transform_type
            case 'mm'
                L = compute_cirfs(irfs_j);
            case 'aa'
                H = size(irfs_j, 1);
                L = zeros(size(irfs_j));
                for hh = 1:H
                    if hh <= lag
                        L(hh, 1, :) = irfs_j(hh, 1, :);
                    else
                        L(hh, 1, :) = irfs_j(hh, 1, :) + L(hh - lag, 1, :);
                    end
                end
        end

        L_h = squeeze(L(h_idx, 1, :));   % [ndraws x 1]
        n_draws = numel(L_h);

        med_L   = median(L_h);
        p05     = quantile(L_h, 0.05);
        p95     = quantile(L_h, 0.95);
        min_abs = min(abs(L_h));
        frac_05 = sum(abs(L_h) < 0.5) / n_draws;
        frac_01 = sum(abs(L_h) < 0.1) / n_draws;
        frac_sign_flip = sum(sign(L_h) ~= sign(med_L)) / n_draws;

        fprintf('  %-6s %8d %10.4f %10.4f %10.4f %10.4f %12.4f %14.4f %14.4f\n', ...
            label, n_draws, p05, med_L, p95, min_abs, frac_05, frac_01, frac_sign_flip);
    end
    fprintf('\n');
end

fprintf('======================================================\n');
fprintf('  Lectura: L_denom es el nivel acumulado de ner en FOCUS_HORIZON (nivel,\n');
fprintf('  no ratio). frac|L|<0.5 / <0.1 = fraccion de draws con denominador\n');
fprintf('  pequeno en valor absoluto (candidato a ratio inflado). frac signo!=med\n');
fprintf('  = fraccion de draws cuyo signo difiere de la mediana (denominador\n');
fprintf('  cruza cero dentro de la distribucion -- ratio puede cambiar de signo\n');
fprintf('  o dispararse en esos draws). Comparar mm_minn (filas 1-4) contra\n');
fprintf('  mm_diffuse y aa_minn (comparadores, filas 5-6): si mm_minn muestra\n');
fprintf('  medianas de |L_denom| sistematicamente mas chicas y/o fracciones mas\n');
fprintf('  altas en las 3 columnas de cola que los comparadores, confirma la\n');
fprintf('  hipotesis de denominador cerca de cero como causa del patron erratico.\n');
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat.\n\n');
