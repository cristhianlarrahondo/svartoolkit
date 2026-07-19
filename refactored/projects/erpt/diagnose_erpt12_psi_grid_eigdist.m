%DIAGNOSE_ERPT12_PSI_GRID_EIGDIST  ERPT-Chat 12 -- Opcion 2: grilla de
%   psi_own_lag1 en niw_custom, evaluando no solo si cruza el umbral
%   binario de estabilidad (check_stability.m, max|eig|<1) sino DONDE cae
%   la masa de max|eig(F)| -- para ver si algun psi aleja la masa de la
%   frontera (>=0.98), en vez de solo cruzarla.
%
%   Motivacion (hallazgo de diagnose_erpt12_niwcustom_cache_integrity.m,
%   Parte 3): con psi=0.97, ND=3e5, el 70.8%% de los draws "estables" de
%   niw_custom caen en max|eig| en [0.98,1.0) -- contra 28.4%% en
%   mm_diffuse. El gate binario dice "estable" en ambos casos con numeros
%   parecidos (89-97%% vs 89-96%%), pero la distribucion condicional es
%   muy distinta. Este script prueba si psi mas agresivo (mas lejos de 1.0)
%   corrige eso, o si el problema persiste sin importar psi.
%
%   NO toca build_posterior.m/run_is.m/check_stability.m ni
%   build_niw_custom_prior.m (Tipo S, exploratorio). Usa ND_SMOKE (no la
%   corrida cientifica completa) para la grilla -- son 6 valores x 2
%   dinamicas (lag2/lag4; base y rob comparten la MISMA forma reducida,
%   ya confirmado en diagnose_erpt12_niwcustom_cache_integrity.m: valores
%   identicos entre base_mm_niwcustom y rob_mm_niwcustom -- la
%   identificacion estructural no afecta Bdraws/eigenvalores). No hace
%   falta correr las 4 -- 2 bastan y ahorran la mitad del tiempo.
%
%   Ejecutar COMPLETO (F5). Pegar el output completo en el chat.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   DIAGNOSTICO ERPT-CHAT 12 -- grilla psi x distribucion eig\n');
fprintf('======================================================\n\n');

%% -- Controles -----------------------------------------------------------
ND_SMOKE = 3000;
PSI_GRID = [0.80, 0.85, 0.90, 0.93, 0.95, 0.97];
BUCKETS  = [0, 0.90, 0.95, 0.98, 0.995, 1.0];
BUCKET_LABELS = {'<0.90', '0.90-0.95', '0.95-0.98', '0.98-0.995', '0.995-1.0'};

%% -- Rutas -----------------------------------------------------------------
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

fprintf('  ND_SMOKE : %g\n', ND_SMOKE);
fprintf('  PSI_GRID : %s\n\n', mat2str(PSI_GRID));

% Solo 2 dinamicas -- base y rob comparten forma reducida (confirmado)
dyn_specs = {'spec_A_base_mm_niwcustom_lag2_v0', 'spec_A_base_mm_niwcustom_lag4_v0'};
dyn_labels = {'lag2', 'lag4'};

% -- Referencia mm_diffuse (YA cacheada a ND=3e5 -- no se recorre, solo se
%    carga y se le calcula la misma distribucion de buckets para comparar
%    en igualdad de condiciones) --------------------------------------------
diffuse_specs = {'spec_A_base_mm_diffuse_lag2_v0', 'spec_A_base_mm_diffuse_lag4_v0'};

fprintf('======================================================\n');
fprintf('  REFERENCIA -- mm_diffuse (cache ND=3e5, sin recorrer)\n');
fprintf('======================================================\n\n');

diffuse_bucket_pct = zeros(numel(diffuse_specs), numel(BUCKET_LABELS));
diffuse_frac_stable = zeros(1, numel(diffuse_specs));

for dd = 1:numel(diffuse_specs)
    spec_name = diffuse_specs{dd};
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS = false; Cfg.SAVE_RESULTS = false;

    [Results_spec, ~, ~, Cfg_cached] = load_erpt_run(Cfg.OUTPUT_DIR);
    [frac_st, bucket_pct] = p_eig_distribution(Results_spec, Cfg_cached, BUCKETS);

    diffuse_frac_stable(dd) = frac_st;
    diffuse_bucket_pct(dd, :) = bucket_pct;

    fprintf('  %-12s  frac_estable=%6.2f%%   buckets: ', dyn_labels{dd}, 100*frac_st);
    for bb = 1:numel(BUCKET_LABELS)
        fprintf('%s=%.1f%%  ', BUCKET_LABELS{bb}, 100*bucket_pct(bb));
    end
    fprintf('\n');
end
fprintf('\n');

% =========================================================================
%  GRILLA -- psi_own_lag1 x {lag2, lag4}
% =========================================================================
fprintf('======================================================\n');
fprintf('  GRILLA -- psi_own_lag1 (niw_custom), ND_SMOKE=%g\n', ND_SMOKE);
fprintf('======================================================\n\n');

frac_stable_grid = nan(numel(dyn_specs), numel(PSI_GRID));
bucket_grid       = nan(numel(dyn_specs), numel(PSI_GRID), numel(BUCKET_LABELS));

for ss = 1:numel(dyn_specs)
    spec_name = dyn_specs{ss};
    fprintf('------------------------------------------------------\n');
    fprintf('  Dinamica: %s (%s)\n', spec_name, dyn_labels{ss});
    fprintf('------------------------------------------------------\n');

    for kk = 1:numel(PSI_GRID)
        psi_val = PSI_GRID(kk);

        clear Cfg;
        Cfg = struct();
        run(fullfile(PROJ_CFG, [spec_name '.m']));
        Cfg.PLOT_IRFS    = false;
        Cfg.SAVE_RESULTS = false;
        Cfg.ND           = ND_SMOKE;
        Cfg.PRIOR        = build_niw_custom_prior(Cfg, psi_val);

        try
            Dataset_spec   = load_data(Cfg);
            validate_cfg(Cfg, Dataset_spec);
            Posterior_spec = build_posterior(Dataset_spec, Cfg);

            rng('default'); rng(Cfg.SEED);
            Results_spec = run_is(Posterior_spec, Cfg);

            [frac_st, bucket_pct] = p_eig_distribution(Results_spec, Cfg, BUCKETS);
            frac_stable_grid(ss, kk)  = frac_st;
            bucket_grid(ss, kk, :)    = bucket_pct;

            fprintf('  psi=%.2f  ne=%-4d  frac_estable=%6.2f%%   buckets: ', ...
                psi_val, Results_spec.ne, 100*frac_st);
            for bb = 1:numel(BUCKET_LABELS)
                fprintf('%s=%.1f%%  ', BUCKET_LABELS{bb}, 100*bucket_pct(bb));
            end
            fprintf('\n');
        catch ME
            fprintf('  psi=%.2f  ->  [ERROR] %s\n', psi_val, ME.message);
        end
    end
    fprintf('\n');
end

% =========================================================================
%  RESUMEN -- "masa lejos de la frontera" = buckets 1-3 (<0.98) / total estable
% =========================================================================
fprintf('======================================================\n');
fprintf('  RESUMEN -- fraccion de draws ESTABLES con max|eig| < 0.98\n');
fprintf('  (buckets <0.90 + 0.90-0.95 + 0.95-0.98, sobre el total de draws)\n');
fprintf('======================================================\n\n');

fprintf('  %-10s', 'psi');
for ss = 1:numel(dyn_specs)
    fprintf('  %12s', dyn_labels{ss});
end
fprintf('\n');

for kk = 1:numel(PSI_GRID)
    fprintf('  %-10.2f', PSI_GRID(kk));
    for ss = 1:numel(dyn_specs)
        away_from_frontier = sum(bucket_grid(ss, kk, 1:3));   % buckets <0.98
        fprintf('  %11.1f%%', 100*away_from_frontier);
    end
    fprintf('\n');
end

fprintf('\n  --- Referencia mm_diffuse (mismo indicador) ---\n');
fprintf('  %-10s', '(diffuse)');
for dd = 1:numel(diffuse_specs)
    away_diffuse = sum(diffuse_bucket_pct(dd, 1:3));
    fprintf('  %11.1f%%', 100*away_diffuse);
end
fprintf('\n\n');

fprintf('  Lectura: si ningun psi de la grilla se acerca al nivel de mm_diffuse\n');
fprintf('  en esta columna, confirma que el problema no es psi -- es que CUALQUIER\n');
fprintf('  prior centrado cerca de un valor alto de persistencia en rezago-1 bajo\n');
fprintf('  mm produce una dinamica cerca de la frontera, independientemente de\n');
fprintf('  donde se posicione esa media dentro de [0.80, 0.97].\n\n');

fprintf('======================================================\n');
fprintf('Pegar este output completo en el chat.\n\n');


%% -- Helper local --------------------------------------------------------
function [frac_stable, bucket_pct] = p_eig_distribution(Results, Cfg, buckets)
%P_EIG_DISTRIBUTION  Calcula max|eig(F)| por draw y lo clasifica en buckets.
%   bucket_pct(k) = fraccion (sobre nd total) de draws con
%   buckets(k) <= max|eig| < buckets(k+1); el ultimo bucket ademas exige
%   max|eig| < 1 (i.e. estable). frac_stable = sum(bucket_pct).
    Bdraws = Results.Bdraws;
    nd     = numel(Bdraws);
    n      = Results.LtildeStruct.nvar;

    nex_const = 0;
    if isfield(Cfg, 'NEX'), nex_const = Cfg.NEX; end
    ndummies = 0;
    if isfield(Cfg, 'DUMMIES'), ndummies = numel(Cfg.DUMMIES); end
    nex_total = nex_const + ndummies;

    B_example = Bdraws{1};
    m_rows    = size(B_example, 1);
    p = round((m_rows - nex_total) / n);
    np = p * n;
    F_lower = [eye(np - n), zeros(np - n, n)];

    nbuck = numel(buckets) - 1;
    counts = zeros(1, nbuck);

    for s = 1:nd
        B_s = Bdraws{s};
        B_lags = B_s(1:n*p, :);
        F_top = zeros(n, np);
        for l = 1:p
            F_top(:, (l-1)*n+1:l*n) = B_lags((l-1)*n+1:l*n, :)';
        end
        F = [F_top; F_lower];
        mx = max(abs(eig(F)));

        for bb = 1:nbuck
            if bb < nbuck
                if mx >= buckets(bb) && mx < buckets(bb+1)
                    counts(bb) = counts(bb) + 1;
                    break;
                end
            else
                if mx >= buckets(bb) && mx < 1
                    counts(bb) = counts(bb) + 1;
                end
            end
        end
    end

    bucket_pct  = counts / nd;
    frac_stable = sum(bucket_pct);
end
