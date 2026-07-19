%DIAGNOSE_ERPT12_LAMBDA1_SENSITIVITY  ERPT-Chat 12 -- Grilla de lambda1 en
%   los 4 specs *_mm_minn_* antes de decidir si niw_custom REEMPLAZA o se
%   AGREGA a mm_minn en la tabla maestra del Ejercicio A.
%
%   Contexto (ERPT-Chat 10/11): D2 revirtio lambda1 de 0.1 a 0.2 (correccion
%   minima defendible de la inversion de sentido de ERPT-Chat 6 D3), pero el
%   smoke test de ERPT-Chat 11 mostro que 0.2 NO basta -- frac_estable subio
%   de ~25% (bug original, lambda1=0.1) a solo ~29-31% (lambda1=0.2),
%   practicamente sin mejora sustantiva. D2 dejaba explicitamente prevista
%   una segunda iteracion escalando lambda1 a 0.3 "si 0.2 no basta,
%   documentando explicitamente por que" -- ese paso nunca se ejecuto antes
%   de declarar niw_custom como la variante viable. Este script lo agota
%   antes de comprometer la decision REEMPLAZA/AGREGA de ERPT-Chat 12.
%
%   Logica: lambda1 mas grande = prior MAS laxo (mayor varianza, D1 de
%   ERPT-Chat 10: Var_prior propto lambda1^2) = menos shrinkage hacia el
%   RW puro (coef. propio de rezago-1 = 1, frontera de inestabilidad) = mas
%   peso relativo en el punto OLS (~0.97, estable). La grilla sube desde el
%   valor actual (0.2) hasta un valor claramente laxo (1.0) para ver donde
%   (si en algun punto) se cruza el umbral de estabilidad razonable.
%
%   NO toca build_posterior.m/run_is.m/load_data.m ni check_stability.m
%   (Tipo S, solo lee Cfg.PRIOR.lambda1 de cada spec y lo sobreescribe en
%   memoria). Usa check_stability.m del core directamente (ya corregido en
%   ERPT-Chat 11 para incluir Cfg.DUMMIES -- decision 7 de ese cierre; no
%   hace falta reimplementarlo localmente como en ERPT-Chat 9).
%
%   Exploratorio -- NO es parte del protocolo de cierre (mismo estatus que
%   diagnose_erpt9_*.m y diagnose_erpt11_niwcustom_sensitivity.m). No se
%   commitea como entregable oficial; queda en el repo como referencia.
%   Ejecutar COMPLETO (F5).

fprintf('\n');
fprintf('======================================================\n');
fprintf('   DIAGNOSTICO ERPT-CHAT 12 -- sensibilidad de lambda1\n');
fprintf('   (mm_minn, previo a decision REEMPLAZA vs AGREGA)\n');
fprintf('======================================================\n\n');

%% -- Controles -----------------------------------------------------------
ND_SMOKE    = 3000;
LAMBDA1_GRID = [0.2, 0.3, 0.4, 0.5, 0.7, 1.0];
PASS_THRESH = 0.70;   % mismo umbral usado en ERPT-Chat 10/11

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

fprintf('  ND_SMOKE     : %g\n', ND_SMOKE);
fprintf('  LAMBDA1_GRID : %s\n', mat2str(LAMBDA1_GRID));
fprintf('  PASS_THRESH  : %.0f%%\n\n', 100*PASS_THRESH);

% Los 4 specs mm_minn (base/rob x lag2/lag4). Cada archivo trae hoy
% lambda1=0.2 (corregido en ERPT-Chat 11) -- se sobreescribe en memoria
% con cada valor de la grilla, sin tocar el archivo.
minn_specs = { ...
    'spec_A_base_mm_minn_lag2_v0', 'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_rob_mm_minn_lag2_v0',  'spec_A_rob_mm_minn_lag4_v0'  };

% Referencia ya medida en el smoke test de ERPT-Chat 11 para lambda1=0.2
% (sanity check: el primer punto de la grilla debe reproducirla).
ref_frac_lambda02 = struct( ...
    'spec_A_base_mm_minn_lag2_v0', 0.2943, ...
    'spec_A_base_mm_minn_lag4_v0', 0.3147, ...
    'spec_A_rob_mm_minn_lag2_v0',  0.2943, ...
    'spec_A_rob_mm_minn_lag4_v0',  0.3147  ...
);

% =========================================================================
%  GRID DE SENSIBILIDAD
% =========================================================================
results_grid = struct();   % results_grid.(spec_name)(k) = frac_stable para LAMBDA1_GRID(k)

for ss = 1:numel(minn_specs)
    spec_name = minn_specs{ss};
    fprintf('======================================================\n');
    fprintf('  Spec: %s\n', spec_name);
    fprintf('======================================================\n');

    fracs = nan(1, numel(LAMBDA1_GRID));

    for kk = 1:numel(LAMBDA1_GRID)
        lam_val = LAMBDA1_GRID(kk);

        clear Cfg;
        Cfg = struct();
        run(fullfile(PROJ_CFG, [spec_name '.m']));   % deja Cfg.PRIOR.lambda1=0.2 (default actual)
        Cfg.PLOT_IRFS    = false;
        Cfg.SAVE_RESULTS = false;
        Cfg.ND           = ND_SMOKE;

        % Sobreescribir SOLO lambda1 de esta iteracion; lambda2/lambda3 sin
        % cambio (D3-D4 de ERPT-Chat 10: sin evidencia de que contribuyan).
        Cfg.PRIOR.lambda1 = lam_val;

        try
            Dataset_spec   = load_data(Cfg);
            validate_cfg(Cfg, Dataset_spec);
            Posterior_spec = build_posterior(Dataset_spec, Cfg);

            rng('default'); rng(Cfg.SEED);
            Results_spec = run_is(Posterior_spec, Cfg);

            frac_stable = check_stability(Results_spec, Cfg);
            fracs(kk) = frac_stable;

            fprintf('  lambda1=%.2f  ->  ne=%-4d  frac_estable=%6.2f%%\n', ...
                lam_val, Results_spec.ne, 100*frac_stable);
        catch ME
            fprintf('  lambda1=%.2f  ->  [ERROR] %s\n', lam_val, ME.message);
        end
    end

    results_grid.(spec_name) = fracs;

    % -- Sanity check: lambda1=0.2 debe reproducir el smoke test de Chat 11 --
    idx_02 = find(abs(LAMBDA1_GRID - 0.2) < 1e-9, 1);
    if ~isempty(idx_02) && ~isnan(fracs(idx_02))
        ref_val = ref_frac_lambda02.(spec_name);
        diff_pp = abs(fracs(idx_02) - ref_val) * 100;
        fprintf('  [sanity] lambda1=0.20 (%.2f%%) vs. smoke ERPT-Chat 11 (%.2f%%): diff=%.2f pp %s\n', ...
            100*fracs(idx_02), 100*ref_val, diff_pp, iif_local(diff_pp < 5, '(OK, coincide)', '(ALERTA: revisar)'));
    end
    fprintf('\n');
end

% =========================================================================
%  TABLA RESUMEN Y BUSQUEDA DEL PRIMER VALOR QUE CRUZA EL UMBRAL
% =========================================================================
fprintf('======================================================\n');
fprintf('  RESUMEN -- frac_estable por lambda1 (draws crudos)\n');
fprintf('======================================================\n\n');

fprintf('  %-32s', 'spec');
for kk = 1:numel(LAMBDA1_GRID)
    fprintf(' %7.2f', LAMBDA1_GRID(kk));
end
fprintf('\n');

mean_by_lam = zeros(1, numel(LAMBDA1_GRID));
for ss = 1:numel(minn_specs)
    spec_name = minn_specs{ss};
    fracs = results_grid.(spec_name);
    fprintf('  %-32s', spec_name);
    for kk = 1:numel(LAMBDA1_GRID)
        if isnan(fracs(kk))
            fprintf(' %7s', 'ERR');
        else
            fprintf(' %6.1f%%', 100*fracs(kk));
        end
    end
    fprintf('\n');
end

fprintf('  %-32s', '--- promedio (4 specs) ---');
for kk = 1:numel(LAMBDA1_GRID)
    vals = arrayfun(@(ss) results_grid.(minn_specs{ss})(kk), 1:numel(minn_specs));
    mean_by_lam(kk) = mean(vals(~isnan(vals)));
    fprintf(' %6.1f%%', 100*mean_by_lam(kk));
end
fprintf('\n\n');

fprintf('  Umbral: %.0f%% en LAS 4 specs simultaneamente (no solo el promedio)\n\n', 100*PASS_THRESH);

best_idx = [];
for kk = 1:numel(LAMBDA1_GRID)
    vals = arrayfun(@(ss) results_grid.(minn_specs{ss})(kk), 1:numel(minn_specs));
    if all(~isnan(vals)) && all(vals >= PASS_THRESH)
        best_idx = kk;
        break;
    end
end

if ~isempty(best_idx)
    fprintf('  >> Primer lambda1 (de menor a mayor) que cumple en las 4 specs: %.2f\n', LAMBDA1_GRID(best_idx));
    fprintf('     (frac_estable minima entre las 4 specs: %.2f%%)\n\n', ...
        100*min(arrayfun(@(ss) results_grid.(minn_specs{ss})(best_idx), 1:numel(minn_specs))));
    fprintf('  Nota: un lambda1 muy laxo debilita el proposito del prior Minnesota\n');
    fprintf('  (shrinkage hacia RW); si el valor que cruza el umbral es grande (ej. >=0.7),\n');
    fprintf('  eso en si mismo es evidencia de que Minnesota (tal como esta motivado\n');
    fprintf('  economicamente) no es viable bajo mm sin perder su proposito original --\n');
    fprintf('  argumento a favor de AGREGAR niw_custom en vez de forzar mm_minn.\n\n');
else
    fprintf('  >> NINGUN valor de la grilla (hasta lambda1=1.0) cumple >= %.0f%% en las 4 specs.\n', 100*PASS_THRESH);
    fprintf('     Esto agota la via de recalibrar lambda1: ni siquiera relajando el prior\n');
    fprintf('     al maximo razonable se alcanza estabilidad aceptable bajo mm_minn.\n');
    fprintf('     Evidencia a favor de que mm_minn (tal como esta especificado) no es\n');
    fprintf('     viable como variante independiente sin niw_custom.\n\n');
end

fprintf('======================================================\n');
fprintf('Pegar este output completo en el chat.\n\n');


%% -- Helper local ------------------------------------------------------
function out = iif_local(cond, a, b)
    if cond, out = a; else, out = b; end
end
