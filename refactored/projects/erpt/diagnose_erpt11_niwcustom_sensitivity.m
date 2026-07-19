%DIAGNOSE_ERPT11_NIWCUSTOM_SENSITIVITY  ERPT-Chat 11 (continuacion) --
%   Opcion 3 acordada tras el veredicto del smoke test: "Minnesota
%   corregida" (lambda1=0.2) quedo en ~30% de draws estables (insuficiente,
%   umbral 70%), mientras que niw_custom con psi_own_lag1=0.90 dio 100% en
%   las 4 specs mm. Antes de comprometer computo cientifico (ND=3e6, Opcion
%   4), este script busca el DESPLAZAMIENTO MINIMO de la media del prior
%   (psi_own_lag1, D5) que basta para cruzar el umbral -- intervencion mas
%   leve es mas defendible que 0.90 sin evidencia adicional.
%
%   Grid de psi_own_lag1 probado: [1.00 0.99 0.97 0.95 0.93 0.90].
%     - psi_own_lag1=1.00 es un CASO DE SANITY CHECK: con esa media,
%       niw_custom debe reproducir EXACTAMENTE el prior 'minnesota' (mismo
%       Omega_bar, misma estructura de Psi_bar) -- su frac_stable debe
%       coincidir con el ~30% ya medido para spec_A_*_mm_minn_lag*_v0 en el
%       smoke test previo de este chat. Si no coincide, hay un error en
%       build_niw_custom_prior.m que debe corregirse antes de continuar.
%     - Los demas valores exploran el camino entre esa frontera (RW exacta)
%       y 0.90 (ya confirmado en 100%).
%
%   NO toca build_posterior.m/run_is.m/load_data.m (Tipo S). Reutiliza
%   build_niw_custom_prior.m con su 2do argumento opcional (psi_own_lag1),
%   agregado en este mismo chat para permitir esta sensibilizacion sin
%   modificar los 4 specs niw_custom ya committeados (que siguen usando el
%   default 0.90 salvo que este diagnostico sugiera otro valor).
%
%   Exploratorio -- no es parte del protocolo de cierre (como los
%   diagnose_erpt9_*.m de ERPT-Chat 9). Ejecutar COMPLETO (F5).

fprintf('\n');
fprintf('======================================================\n');
fprintf('   DIAGNOSTICO ERPT-CHAT 11 -- sensibilidad de psi_own_lag1\n');
fprintf('   (niw_custom, Opcion 3, antes de la corrida ND=3e6)\n');
fprintf('======================================================\n\n');

%% -- Controles ---------------------------------------------------------
ND_SMOKE   = 3000;
PSI_GRID   = [1.00, 0.99, 0.97, 0.95, 0.93, 0.90];
PASS_THRESH = 0.70;

%% -- Rutas ---------------------------------------------------------------
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

fprintf('  ND_SMOKE    : %g\n', ND_SMOKE);
fprintf('  PSI_GRID    : %s\n', mat2str(PSI_GRID));
fprintf('  PASS_THRESH : %.0f%%\n\n', 100*PASS_THRESH);

% Los 4 specs mm (representados via sus archivos niw_custom -- se
% recalcula Cfg.PRIOR con cada psi de la grilla, sobreescribiendo el
% default 0.90 ya asignado dentro del spec).
niwc_specs = { ...
    'spec_A_base_mm_niwcustom_lag2_v0', 'spec_A_base_mm_niwcustom_lag4_v0', ...
    'spec_A_rob_mm_niwcustom_lag2_v0',  'spec_A_rob_mm_niwcustom_lag4_v0'  };

% Referencia ya medida en el smoke test de este chat (Minnesota corregida,
% equivalente matematico de psi_own_lag1=1.00).
ref_minn_frac = struct( ...
    'spec_A_base_mm_niwcustom_lag2_v0', 0.2943, ...   % spec_A_base_mm_minn_lag2_v0
    'spec_A_base_mm_niwcustom_lag4_v0', 0.3147, ...   % spec_A_base_mm_minn_lag4_v0
    'spec_A_rob_mm_niwcustom_lag2_v0',  0.2943, ...   % spec_A_rob_mm_minn_lag2_v0
    'spec_A_rob_mm_niwcustom_lag4_v0',  0.3147  ...   % spec_A_rob_mm_minn_lag4_v0
);

NAMED_SHOCKS = {'Cam', 'Dem', 'Ofe'};

% =========================================================================
%  GRID DE SENSIBILIDAD
% =========================================================================
results_grid = struct();   % results_grid.(spec_name)(k) = frac_stable para PSI_GRID(k)

for ss = 1:numel(niwc_specs)
    spec_name = niwc_specs{ss};
    fprintf('======================================================\n');
    fprintf('  Spec: %s\n', spec_name);
    fprintf('======================================================\n');

    fracs = nan(1, numel(PSI_GRID));

    for kk = 1:numel(PSI_GRID)
        psi_val = PSI_GRID(kk);

        clear Cfg;
        Cfg = struct();
        run(fullfile(PROJ_CFG, [spec_name '.m']));   % deja Cfg.PRIOR con default 0.90
        Cfg.PLOT_IRFS    = false;
        Cfg.SAVE_RESULTS = false;
        Cfg.ND           = ND_SMOKE;

        % Sobreescribir Cfg.PRIOR con el psi_own_lag1 de esta iteracion.
        Cfg.PRIOR = build_niw_custom_prior(Cfg, psi_val);

        try
            Dataset_spec   = load_data(Cfg);
            validate_cfg(Cfg, Dataset_spec);
            Posterior_spec = build_posterior(Dataset_spec, Cfg);

            rng('default'); rng(Cfg.SEED);
            Results_spec = run_is(Posterior_spec, Cfg);

            frac_stable = p_local_check_stability(Results_spec, Cfg);
            fracs(kk) = frac_stable;

            fprintf('  psi_own_lag1=%.2f  ->  ne=%-4d  frac_estable=%6.2f%%\n', ...
                psi_val, Results_spec.ne, 100*frac_stable);
        catch ME
            fprintf('  psi_own_lag1=%.2f  ->  [ERROR] %s\n', psi_val, ME.message);
        end
    end

    results_grid.(spec_name) = fracs;

    % -- Sanity check: psi=1.00 debe aproximar el benchmark Minnesota ----
    idx_100 = find(PSI_GRID == 1.00, 1);
    if ~isnan(fracs(idx_100))
        ref_val = ref_minn_frac.(spec_name);
        diff_pp = abs(fracs(idx_100) - ref_val) * 100;
        fprintf('  [sanity] psi=1.00 (%.2f%%) vs. Minnesota corregida medido (%.2f%%): diff=%.2f pp %s\n', ...
            100*fracs(idx_100), 100*ref_val, diff_pp, iif_local(diff_pp < 5, '(OK, coincide)', '(ALERTA: revisar formula)'));
    end
    fprintf('\n');
end

% =========================================================================
%  TABLA RESUMEN Y BUSQUEDA DEL VALOR MINIMO QUE CRUZA EL UMBRAL
% =========================================================================
fprintf('======================================================\n');
fprintf('  RESUMEN -- frac_estable por psi_own_lag1 (draws crudos)\n');
fprintf('======================================================\n\n');

fprintf('  %-38s', 'spec');
for kk = 1:numel(PSI_GRID)
    fprintf(' %7.2f', PSI_GRID(kk));
end
fprintf('\n');

mean_by_psi = zeros(1, numel(PSI_GRID));
for ss = 1:numel(niwc_specs)
    spec_name = niwc_specs{ss};
    fracs = results_grid.(spec_name);
    fprintf('  %-38s', spec_name);
    for kk = 1:numel(PSI_GRID)
        if isnan(fracs(kk))
            fprintf(' %7s', 'ERR');
        else
            fprintf(' %6.1f%%', 100*fracs(kk));
        end
    end
    fprintf('\n');
end

fprintf('  %-38s', '--- promedio (4 specs) ---');
for kk = 1:numel(PSI_GRID)
    vals = arrayfun(@(ss) results_grid.(niwc_specs{ss})(kk), 1:numel(niwc_specs));
    mean_by_psi(kk) = mean(vals(~isnan(vals)));
    fprintf(' %6.1f%%', 100*mean_by_psi(kk));
end
fprintf('\n\n');

% -- Encontrar el psi_own_lag1 MENOS agresivo (mas cercano a 1.0) que ----
% -- cruce el umbral en las 4 specs simultaneamente -----------------------
fprintf('  Umbral: %.0f%% en LAS 4 specs simultaneamente (no solo el promedio)\n\n', 100*PASS_THRESH);

best_idx = [];
% PSI_GRID esta ordenado de 1.00 (mas cerca de RW) a 0.90 (mas desplazado);
% buscamos el PRIMER valor (menos agresivo) que ya cumple en las 4 specs.
for kk = 1:numel(PSI_GRID)
    vals = arrayfun(@(ss) results_grid.(niwc_specs{ss})(kk), 1:numel(niwc_specs));
    if all(~isnan(vals)) && all(vals >= PASS_THRESH)
        best_idx = kk;
        break;
    end
end

if ~isempty(best_idx)
    fprintf('  >> Valor MENOS agresivo que cumple en las 4 specs: psi_own_lag1 = %.2f\n', PSI_GRID(best_idx));
    fprintf('     (frac_estable minima entre las 4 specs: %.2f%%)\n\n', ...
        100*min(arrayfun(@(ss) results_grid.(niwc_specs{ss})(best_idx), 1:numel(niwc_specs))));
    fprintf('  Recomendacion: usar psi_own_lag1 = %.2f para la corrida cientifica\n', PSI_GRID(best_idx));
    fprintf('  (Opcion 4), en vez del valor original D5 (0.90), si %.2f es menos agresivo.\n\n', PSI_GRID(best_idx));
else
    fprintf('  >> NINGUN valor de la grilla cumple >= %.0f%% en las 4 specs a la vez.\n', 100*PASS_THRESH);
    fprintf('     El valor mas bajo probado (0.90) es el que se usara si se decide seguir\n');
    fprintf('     con niw_custom (ya confirmado en 100%% en el smoke test previo).\n\n');
end

fprintf('======================================================\n');
fprintf('Pegar este output completo en el chat.\n\n');


%% -- Helpers locales ------------------------------------------------------
function out = iif_local(cond, a, b)
    if cond, out = a; else, out = b; end
end

function frac_stable = p_local_check_stability(Results, Cfg)
%P_LOCAL_CHECK_STABILITY  Misma copia local usada en validate_erpt11.m
%   (logica de check_stability.m del core, con nex_total corregido para
%   incluir dummies COVID -- ver nota en diagnose_erpt9_dynamics.m).
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

    n_stable = 0;
    for s = 1:nd
        B_s = Bdraws{s};
        B_lags = B_s(1:n*p, :);
        F_top = zeros(n, np);
        for l = 1:p
            F_top(:, (l-1)*n+1:l*n) = B_lags((l-1)*n+1:l*n, :)';
        end
        F = [F_top; F_lower];
        if max(abs(eig(F))) < 1
            n_stable = n_stable + 1;
        end
    end
    frac_stable = n_stable / nd;
end
