%DIAGNOSE_ERPT9_DYNAMICS  Tercer diagnostico de ERPT-Chat 9: explora si el
%   patron erratico de mm_minn (numerador con_inf inflado, ya confirmado en
%   diagnose_erpt9_mm_minn(_v2).m; prior Minnesota YA DESCARTADO como causa
%   en diagnose_erpt9_prior_scale.m) se explica por dinamica/persistencia
%   del sistema estimado, en 3 chequeos:
%
%   (1) PERFIL POR HORIZONTE (gratis -- solo lee cache): L_price, L_denom
%       y el ratio en los 5 horizontes de Cfg.ERPT_HORIZONS. Si la
%       inflacion crece desproporcionadamente con el horizonte, apunta a
%       COMPOUNDING: mm acumula 37 terminos mensuales (CIRF estandar,
%       h=0..36) mientras aa telescopa solo 3 veces (h=12,24,36) sobre
%       valores ya interanuales -- un componente persistente en con_inf se
%       amplifica mucho mas sumando 37 terminos que reconstruyendo 3
%       bloques anuales.
%   (2) ESTABILIDAD DE DRAWS CRUDOS (barato -- reutiliza check_stability.m
%       del core SIN modificarlo, sobre el cache ya persistido). OJO —
%       limitacion real: check_stability.m mide estabilidad sobre TODOS
%       los Cfg.ND draws crudos del NIW (antes del filtro de signos y del
%       resampling IS), no sobre el subconjunto ne que efectivamente
%       alimenta el Ltilde final. Es un proxy de la poblacion candidata,
%       no de los draws aceptados -- se reporta con esa salvedad.
%   (3) ESTABILIDAD DEL PUNTO OLS (barato -- solo load_data+build_posterior,
%       sin muestreo): eigenvalor maximo (modulo) de la companion matrix
%       construida con el B de OLS crudo (antes de cualquier prior), igual
%       para diffuse/minnesota ya que el prior no afecta el punto OLS en
%       si. Compara si el DATO (mm vs aa) ya trae mas persistencia
%       independientemente del prior.
%
%   NO corre run_is. (2) reutiliza Results.Bdraws ya cacheado por
%   validate_erpt9.m (Cfg.ND=3e5 draws, ~10-30seg de eigendescomposiciones,
%   NO son minutos de estimacion nueva). (3) es un ajuste OLS, segundos.
%
%   Ejecutar COMPLETO (F5).

fprintf('\n');
fprintf('======================================================\n');
fprintf('   DIAGNOSTICO ERPT-CHAT 9 -- perfil por horizonte + estabilidad\n');
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

spec_names = { ...
    'spec_A_base_mm_minn_lag2_v0', 'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_rob_mm_minn_lag2_v0',  'spec_A_rob_mm_minn_lag4_v0', ...
    'spec_A_base_mm_diffuse_lag2_v0', ...
    'spec_A_base_aa_minn_lag2_v0' };

NAMED_SHOCKS    = {'Cam', 'Dem', 'Ofe'};
FOCUS_PRICE_VAR = 'con_inf';

% =========================================================================
%  (1) PERFIL POR HORIZONTE -- L_price, L_denom, ratio en los 5 horizontes
% =========================================================================
fprintf('======================================================\n');
fprintf('  (1) PERFIL POR HORIZONTE -- %s, choque Dem (el mas inflado)\n', FOCUS_PRICE_VAR);
fprintf('======================================================\n\n');

for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    out_dir = Cfg.OUTPUT_DIR;
    cache_path = fullfile(out_dir, 'results_is.mat');
    if ~isfile(cache_path)
        error('diagnose_erpt9_dynamics:noCache', 'No existe cache para %s.', spec_name);
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

    horizons_all = [3 6 12 24 36];
    fprintf('  --- %s (transform=%s) ---\n', spec_name, transform_type);
    fprintf('  %-6s', 'horiz');
    for hh = horizons_all, fprintf(' %9d', hh); end
    fprintf('\n');

    for j = 1:numel(shock_idx_resolved)
        sidx  = shock_idx_resolved(j);
        label = resolve_shock_name(shock_names_cfg, sidx);
        if ~strcmp(label, 'Dem')
            continue;   % foco: Dem, el shock mas inflado en el digesto de consola
        end
        irfs_j = irfs_by_shock{j};

        L_denom_full = p_accumulate_local(irfs_j(:, pos_denom, :), transform_type, lag);
        L_price_full = p_accumulate_local(irfs_j(:, pos_price, :), transform_type, lag);

        med_Lp = zeros(1, numel(horizons_all));
        med_Ld = zeros(1, numel(horizons_all));
        med_r  = zeros(1, numel(horizons_all));
        for kk = 1:numel(horizons_all)
            h_idx = horizons_all(kk) + 1;
            Lp = squeeze(L_price_full(h_idx, 1, :));
            Ld = squeeze(L_denom_full(h_idx, 1, :));
            med_Lp(kk) = median(Lp);
            med_Ld(kk) = median(Ld);
            med_r(kk)  = median(Lp ./ Ld);
        end

        fprintf('  %-6s', 'L_pr');
        for kk = 1:numel(horizons_all), fprintf(' %9.4f', med_Lp(kk)); end
        fprintf('   (Dem, mediana L_price)\n');
        fprintf('  %-6s', 'L_de');
        for kk = 1:numel(horizons_all), fprintf(' %9.4f', med_Ld(kk)); end
        fprintf('   (Dem, mediana L_denom)\n');
        fprintf('  %-6s', 'ratio');
        for kk = 1:numel(horizons_all), fprintf(' %9.4f', med_r(kk)); end
        fprintf('   (Dem, mediana ERPT)\n');
    end
    fprintf('\n');
end

% =========================================================================
%  (2) ESTABILIDAD DE DRAWS CRUDOS -- reutiliza check_stability.m (core)
% =========================================================================
fprintf('======================================================\n');
fprintf('  (2) ESTABILIDAD DE DRAWS CRUDOS (check_stability.m, sin modificar)\n');
fprintf('  NOTA: mide sobre TODOS los Cfg.ND draws candidatos, no solo los ne\n');
fprintf('  aceptados/resampleados -- proxy de la poblacion candidata.\n');
fprintf('======================================================\n\n');

for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    out_dir = Cfg.OUTPUT_DIR;
    [Results_spec, ~, ~, Cfg_cached] = load_erpt_run(out_dir);
    Cfg_cached.SPEC_NAME = spec_name;   % por si el cache no lo trae explicito
    check_stability(Results_spec, Cfg_cached);
end

% =========================================================================
%  (3) ESTABILIDAD DEL PUNTO OLS (antes de cualquier prior)
% =========================================================================
fprintf('======================================================\n');
fprintf('  (3) ESTABILIDAD DEL PUNTO OLS (B crudo, antes de prior)\n');
fprintf('======================================================\n\n');
fprintf('  %-32s %14s\n', 'spec', 'max|eig| OLS');

for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;

    Dataset_spec   = load_data(Cfg);
    Posterior_spec = build_posterior(Dataset_spec, Cfg);   % OLS + prior; usamos SOLO .B (OLS)

    n = Dataset_spec.nvar;
    p = Cfg.NLAG;
    B_lags = Posterior_spec.B(1:n*p, :);   % excluye constante/dummies

    np = p * n;
    F_lower = [eye(np - n), zeros(np - n, n)];
    F_top = zeros(n, np);
    for l = 1:p
        F_top(:, (l-1)*n+1:l*n) = B_lags((l-1)*n+1:l*n, :)';
    end
    F = [F_top; F_lower];
    max_eig = max(abs(eig(F)));

    fprintf('  %-32s %14.6f\n', spec_name, max_eig);
end
fprintf('\n');

fprintf('======================================================\n');
fprintf('  Lectura combinada:\n');
fprintf('  (1) Si el ratio de Dem crece mucho mas rapido con el horizonte en\n');
fprintf('      mm_minn que en los comparadores, y L_price crece mientras\n');
fprintf('      L_denom se mantiene estable, confirma compounding del numerador.\n');
fprintf('  (2)/(3) Un max|eig| mas cercano a 1 (o fraccion estable mas baja)\n');
fprintf('      en mm_minn que en mm_diffuse/aa_minn sugiere que la combinacion\n');
fprintf('      especifica produce dinamica reducida-forma mas persistente,\n');
fprintf('      consistente con (1).\n');
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat.\n\n');


%% ── Helper local ────────────────────────────────────────────────────────
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
            error('diagnose_erpt9_dynamics:badTransform', ...
                'transform_type interno invalido: ''%s''.', transform_type);
    end
end
