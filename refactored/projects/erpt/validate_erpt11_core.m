%VALIDATE_ERPT11_CORE  ERPT-Chat 11 (Tipo R-core) -- valida el ajuste al
%   core motivado por los hallazgos de este chat:
%     1. Cfg.PRIOR.own_lag1_mean (minnesota/natural_conjugate) -- escalar o
%        vector, desplaza la media del coeficiente propio de rezago-1
%        (antes fija en 1.0). Default=1, retrocompatible.
%     2. Cfg.PRIOR.sum_coefs_target (sims_zha) -- generalizacion analoga
%        para el dummy "suma de coeficientes" (mu5). Default=1, retrocomp.
%     3. check_stability.m corregido para incluir Cfg.DUMMIES al inferir
%        el numero de lags (antes fallaba con dummies exogenas presentes).
%
%   Los 3 cambios son opcionales/retrocompatibles por diseno. Protocolo
%   Tipo R-core: implementado directo en el contexto ERPT (no se abre un
%   Chat N aparte), retro-documentado con el mismo rigor de un Tipo R
%   normal -- regresion BNW obligatoria (Bloque 0), sin excepcion, aunque
%   este cambio no debiera afectar el camino 'diffuse' que usa BNW.
%
%   Ejecutar COMPLETO (F5). Pegar el output de consola en el chat.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 11 CORE (Tipo R-core)\n');
fprintf('   own_lag1_mean / sum_coefs_target / check_stability fix\n');
fprintf('======================================================\n\n');

%% -- Rutas ----------------------------------------------------------------
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(PROJ_CFG);
addpath(PROJ_SRC);

V   = {'FAIL', 'OK  '};
TOL = 1e-8;

% =========================================================================
%  BLOQUE 0 -- Regresion BNW (PFA + IS), ND nativo -- OBLIGATORIO
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 0 -- Regresion BNW (PFA + IS), ND nativo\n');
fprintf('======================================================\n\n');

clear Cfg;
Cfg = struct();
run(fullfile(REF_ROOT, 'config', 'spec_bnw_pfa.m'));
Cfg.PLOT_IRFS = false; Cfg.SAVE_RESULTS = false;
Dataset_bnw_pfa   = load_data(Cfg);
Posterior_bnw_pfa = build_posterior(Dataset_bnw_pfa, Cfg);
rng(0);
Results_pfa = run_pfa(Posterior_bnw_pfa, Cfg);
Ltilde_pfa  = Results_pfa.LtildeStruct.data;
val_pfa = Ltilde_pfa(end,end,end);
REF_PFA = -0.2326865051;
ok_pfa  = abs(val_pfa - REF_PFA) <= TOL;
fprintf('  PFA Ltilde(end,end,end)      = %.10f  (ref %.10f)  %s\n', val_pfa, REF_PFA, V{int32(ok_pfa)+1});

clear Cfg;
Cfg = struct();
run(fullfile(REF_ROOT, 'config', 'spec_bnw_is.m'));
Cfg.PLOT_IRFS = false; Cfg.SAVE_RESULTS = false;
Dataset_bnw_is   = load_data(Cfg);
Posterior_bnw_is = build_posterior(Dataset_bnw_is, Cfg);
rng('default'); rng(0);
Results_is = run_is(Posterior_bnw_is, Cfg);
Ltilde_is  = Results_is.LtildeStruct.data;
val_is = Ltilde_is(end,end,end,end);
REF_IS = 0.2041864191;
ok_is  = abs(val_is - REF_IS) <= TOL;
fprintf('  IS  Ltilde(end,end,end,end)  = %.10f  (ref %.10f)  %s\n\n', val_is, REF_IS, V{int32(ok_is)+1});

bloque0_ok = ok_pfa && ok_is;
if bloque0_ok
    fprintf('  >> BLOQUE 0: PASA -- baseline BNW intacto (prior ''diffuse'' no fue tocado).\n\n');
else
    fprintf('  >> BLOQUE 0: NO PASA -- DETENER. No continuar con el resto sin revisar esto.\n\n');
end

% =========================================================================
%  BLOQUE 1 -- Retrocompatibilidad: defaults reproducen el comportamiento
%  previo EXACTAMENTE (minnesota, natural_conjugate, sims_zha)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- Retrocompatibilidad (defaults sin cambio)\n');
fprintf('======================================================\n\n');

bloque1_ok   = true;
bloque1_msgs = {};

% -- minnesota: default (sin campo) == own_lag1_mean=1 explicito --------
clear Cfg;
Cfg = struct();
run(fullfile(PROJ_CFG, 'spec_A_base_mm_minn_lag2_v0.m'));
Cfg.PLOT_IRFS = false; Cfg.SAVE_RESULTS = false; Cfg.ND = 100;
Dataset1   = load_data(Cfg);
Posterior_default = build_posterior(Dataset1, Cfg);

Cfg_explicit = Cfg;
Cfg_explicit.PRIOR.own_lag1_mean = 1;
Posterior_explicit = build_posterior(Dataset1, Cfg_explicit);

ok = same_posterior(Posterior_default, Posterior_explicit, TOL);
if ~ok, bloque1_ok = false; bloque1_msgs{end+1} = 'minnesota: default != own_lag1_mean=1 explicito'; end
fprintf('  minnesota: default == own_lag1_mean=1 explicito                      %s\n', V{int32(ok)+1});

% -- natural_conjugate: default == own_lag1_mean=1 explicito ------------
Cfg_nc = Cfg;
Cfg_nc.PRIOR = struct('type', 'natural_conjugate', 'lambda1', 0.2, 'lambda2', 0.5, 'lambda3', 2);
Posterior_nc_default = build_posterior(Dataset1, Cfg_nc);
Cfg_nc_explicit = Cfg_nc;
Cfg_nc_explicit.PRIOR.own_lag1_mean = 1;
Posterior_nc_explicit = build_posterior(Dataset1, Cfg_nc_explicit);

ok = same_posterior(Posterior_nc_default, Posterior_nc_explicit, TOL);
if ~ok, bloque1_ok = false; bloque1_msgs{end+1} = 'natural_conjugate: default != own_lag1_mean=1 explicito'; end
fprintf('  natural_conjugate: default == own_lag1_mean=1 explicito               %s\n', V{int32(ok)+1});

% -- sims_zha: default == sum_coefs_target=1 explicito ------------------
Cfg_sz = Cfg;
Cfg_sz.PRIOR = struct('type', 'sims_zha', 'mu5', 1, 'mu6', 1);
Posterior_sz_default = build_posterior(Dataset1, Cfg_sz);
Cfg_sz_explicit = Cfg_sz;
Cfg_sz_explicit.PRIOR.sum_coefs_target = 1;
Posterior_sz_explicit = build_posterior(Dataset1, Cfg_sz_explicit);

ok = same_posterior(Posterior_sz_default, Posterior_sz_explicit, TOL);
if ~ok, bloque1_ok = false; bloque1_msgs{end+1} = 'sims_zha: default != sum_coefs_target=1 explicito'; end
fprintf('  sims_zha: default == sum_coefs_target=1 explicito                     %s\n\n', V{int32(ok)+1});

if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- retrocompatibilidad confirmada en los 3 priors.\n\n');
else
    fprintf('  >> BLOQUE 1: NO PASA. Detalle:\n');
    for i = 1:numel(bloque1_msgs), fprintf('     - %s\n', bloque1_msgs{i}); end
    fprintf('\n');
end

% =========================================================================
%  BLOQUE 2 -- Nuevo parametro funciona + cross-validacion clave
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- own_lag1_mean / sum_coefs_target\n');
fprintf('======================================================\n\n');

bloque2_ok   = true;
bloque2_msgs = {};

% -- CROSS-VALIDACION CLAVE: minnesota+own_lag1_mean=0.97 (core nuevo)
%    debe reproducir EXACTAMENTE niw_custom+build_niw_custom_prior(.,0.97)
%    (helper ERPT) -- misma formula de Omega_bar, misma media desplazada,
%    solo cambia el mecanismo (generico del core vs. ad hoc de ERPT).
clear Cfg;
Cfg = struct();
run(fullfile(PROJ_CFG, 'spec_A_base_mm_niwcustom_lag2_v0.m'));   % ya trae Cfg.PRIOR niw_custom, psi=0.97
Cfg.PLOT_IRFS = false; Cfg.SAVE_RESULTS = false; Cfg.ND = 100;
Dataset2 = load_data(Cfg);
Posterior_niwcustom = build_posterior(Dataset2, Cfg);   % ruta ERPT (helper ad hoc)

Cfg_minn_shifted = Cfg;
Cfg_minn_shifted.PRIOR = struct('type', 'minnesota', 'lambda1', 0.2, 'lambda2', 0.5, ...
    'lambda3', 2, 'own_lag1_mean', 0.97);
Posterior_minn_shifted = build_posterior(Dataset2, Cfg_minn_shifted);   % ruta core nueva

diff_psi   = max(abs(Posterior_niwcustom.PpsiTilde(:)   - Posterior_minn_shifted.PpsiTilde(:)));
diff_omega = max(abs(Posterior_niwcustom.OomegaTilde(:) - Posterior_minn_shifted.OomegaTilde(:)));
diff_phi   = max(abs(Posterior_niwcustom.PphiTilde(:)   - Posterior_minn_shifted.PphiTilde(:)));
ok = (diff_psi < TOL) && (diff_omega < TOL) && (diff_phi < TOL);
if ~ok
    bloque2_ok = false;
    bloque2_msgs{end+1} = sprintf('minnesota(own_lag1_mean=0.97) NO reproduce niw_custom (diffs: psi=%.2e, omega=%.2e, phi=%.2e)', ...
        diff_psi, diff_omega, diff_phi);
end
fprintf('  minnesota(own_lag1_mean=0.97) == niw_custom(psi=0.97) [Psi/Omega/PhiTilde]  %s\n', V{int32(ok)+1});
fprintf('    max diffs: psi=%.2e, omega=%.2e, phi=%.2e\n\n', diff_psi, diff_omega, diff_phi);

% -- own_lag1_mean como VECTOR (valores distintos por variable) ----------
n = Dataset2.nvar;
vec_target = linspace(0.90, 1.0, n)';
Cfg_vec = Cfg;
Cfg_vec.PRIOR = struct('type', 'minnesota', 'lambda1', 0.2, 'lambda2', 0.5, ...
    'lambda3', 2, 'own_lag1_mean', vec_target);
try
    Posterior_vec = build_posterior(Dataset2, Cfg_vec); %#ok<NASGU>
    fprintf('  minnesota con own_lag1_mean vectorial (%d valores distintos): corrio sin error   OK\n\n', n);
catch ME
    bloque2_ok = false;
    bloque2_msgs{end+1} = sprintf('own_lag1_mean vectorial fallo: %s', ME.message);
    fprintf('  [FAIL] own_lag1_mean vectorial: %s\n\n', ME.message);
end

% -- sum_coefs_target distinto de 1 produce un posterior distinto -------
Cfg_sz_shifted = Cfg;
Cfg_sz_shifted.PRIOR = struct('type', 'sims_zha', 'mu5', 1, 'mu6', 1, 'sum_coefs_target', 0.9);
Posterior_sz_shifted = build_posterior(Dataset2, Cfg_sz_shifted);
Cfg_sz_default2 = Cfg;
Cfg_sz_default2.PRIOR = struct('type', 'sims_zha', 'mu5', 1, 'mu6', 1);
Posterior_sz_default2 = build_posterior(Dataset2, Cfg_sz_default2);
diff_sz = max(abs(Posterior_sz_shifted.PpsiTilde(:) - Posterior_sz_default2.PpsiTilde(:)));
ok = diff_sz > TOL;   % deben SER DISTINTOS (sum_coefs_target=0.9 cambia el resultado)
if ~ok
    bloque2_ok = false;
    bloque2_msgs{end+1} = 'sims_zha: sum_coefs_target=0.9 no produjo diferencia respecto a default=1';
end
fprintf('  sims_zha: sum_coefs_target=0.9 produce posterior distinto a default=1        %s\n\n', V{int32(ok)+1});

if bloque2_ok
    fprintf('  >> BLOQUE 2: PASA -- own_lag1_mean/sum_coefs_target funcionan y la\n');
    fprintf('     cross-validacion contra niw_custom confirma equivalencia matematica.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA. Detalle:\n');
    for i = 1:numel(bloque2_msgs), fprintf('     - %s\n', bloque2_msgs{i}); end
    fprintf('\n');
end

% =========================================================================
%  BLOQUE 3 -- Fix de check_stability.m (dummies exogenas)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- check_stability.m corregido (Cfg.DUMMIES)\n');
fprintf('======================================================\n\n');

bloque3_ok   = true;
bloque3_msgs = {};

% -- Reusa el cache ya generado en la corrida cientifica de este chat
%    (ND=3e5, con Cfg.DUMMIES=2 dummies COVID) para probar check_stability.m
%    DIRECTAMENTE (antes fallaba con estas specs) y cruzarlo contra la
%    reimplementacion local ya usada en validate_erpt11*.m/diagnose_erpt11_*.m
%    -- deben coincidir EXACTAMENTE (misma formula, misma correccion).
clear Cfg;
Cfg = struct();
run(fullfile(PROJ_CFG, 'spec_A_base_mm_niwcustom_lag2_v0.m'));
cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');

if isfile(cache_path)
    [Results_cached, ~, ~, Cfg_cached] = load_erpt_run(Cfg.OUTPUT_DIR);
    try
        frac_core = check_stability(Results_cached, Cfg_cached);
        frac_local = p_local_check_stability(Results_cached, Cfg_cached);
        diff_frac = abs(frac_core - frac_local);
        ok = diff_frac < 1e-12;
        if ~ok
            bloque3_ok = false;
            bloque3_msgs{end+1} = sprintf('check_stability.m (%.6f) != reimplementacion local (%.6f)', frac_core, frac_local);
        end
        fprintf('  check_stability.m (core) corrio SIN ERROR con Cfg.DUMMIES presente    OK\n');
        fprintf('  check_stability.m = %.6f  vs.  reimplementacion local = %.6f          %s\n\n', ...
            frac_core, frac_local, V{int32(ok)+1});
    catch ME
        bloque3_ok = false;
        bloque3_msgs{end+1} = sprintf('check_stability.m fallo con dummies presentes: %s', ME.message);
        fprintf('  [FAIL] check_stability.m con dummies: %s\n\n', ME.message);
    end
else
    fprintf('  [ALERTA] No se encontro cache en %s -- corre validate_erpt11_scientific.m\n', cache_path);
    fprintf('  primero, o este bloque no puede probar el caso con dummies reales.\n\n');
end

% -- Caso sin dummies (BNW, ndummies=0): debe seguir funcionando IGUAL ---
clear Cfg;
Cfg = struct();
run(fullfile(REF_ROOT, 'config', 'spec_bnw_is.m'));
try
    frac_bnw2 = check_stability(Results_is, Cfg);
    fprintf('  check_stability.m sin dummies (BNW): corrio sin error, frac=%.4f    OK\n\n', frac_bnw2);
catch ME
    bloque3_ok = false;
    bloque3_msgs{end+1} = sprintf('check_stability.m sin dummies (BNW) fallo: %s', ME.message);
    fprintf('  [FAIL] check_stability.m sin dummies (BNW): %s\n\n', ME.message);
end

if bloque3_ok
    fprintf('  >> BLOQUE 3: PASA -- check_stability.m funciona con y sin dummies,\n');
    fprintf('     y coincide exactamente con la reimplementacion local ya usada en ERPT.\n\n');
else
    fprintf('  >> BLOQUE 3: NO PASA. Detalle:\n');
    for i = 1:numel(bloque3_msgs), fprintf('     - %s\n', bloque3_msgs{i}); end
    fprintf('\n');
end

% =========================================================================
%  BLOQUE 4 -- Casos de error esperados
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 4 -- Casos de error esperados\n');
fprintf('======================================================\n\n');

bloque4_ok   = true;
bloque4_msgs = {};

% Caso 1: own_lag1_mean con dimension incorrecta (ni escalar ni [n x 1])
try
    Cfg_bad = Cfg_minn_shifted;
    Cfg_bad.PRIOR.own_lag1_mean = [0.9, 0.95];   % 2 elementos, pero n=6
    build_posterior(Dataset2, Cfg_bad);
    bloque4_ok = false; bloque4_msgs{end+1} = 'own_lag1_mean mal dimensionado: NO lanzo error';
    fprintf('  [FAIL] own_lag1_mean mal dimensionado no genero error\n');
catch ME
    fprintf('  [OK] own_lag1_mean mal dimensionado -> error esperado: %s\n', ME.identifier);
end

% Caso 2: sum_coefs_target con dimension incorrecta
try
    Cfg_bad2 = Cfg_sz_shifted;
    Cfg_bad2.PRIOR.sum_coefs_target = [0.9, 0.95, 0.99];   % 3 elementos, pero n=6
    build_posterior(Dataset2, Cfg_bad2);
    bloque4_ok = false; bloque4_msgs{end+1} = 'sum_coefs_target mal dimensionado: NO lanzo error';
    fprintf('  [FAIL] sum_coefs_target mal dimensionado no genero error\n');
catch ME
    fprintf('  [OK] sum_coefs_target mal dimensionado -> error esperado: %s\n', ME.identifier);
end

fprintf('\n');
if bloque4_ok
    fprintf('  >> BLOQUE 4: PASA.\n\n');
else
    fprintf('  >> BLOQUE 4: NO PASA. Detalle:\n');
    for i = 1:numel(bloque4_msgs), fprintf('     - %s\n', bloque4_msgs{i}); end
    fprintf('\n');
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('======================================================\n');
fprintf('        VEREDICTO GLOBAL ERPT-CHAT 11 CORE (Tipo R-core)\n');
fprintf('======================================================\n');
fprintf('  Bloque 0 (Regresion BNW, obligatoria)     : %s\n', iif_local(bloque0_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 1 (Retrocompatibilidad defaults)   : %s\n', iif_local(bloque1_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 2 (Nuevos parametros + cross-val)  : %s\n', iif_local(bloque2_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 3 (check_stability.m corregido)    : %s\n', iif_local(bloque3_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 4 (Casos de error)                 : %s\n', iif_local(bloque4_ok, 'PASA', 'NO PASA'));
fprintf('------------------------------------------------------\n');
if bloque0_ok && bloque1_ok && bloque2_ok && bloque3_ok && bloque4_ok
    fprintf('  GLOBAL : PASA\n');
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba. Condicion Tipo\n');
    fprintf('  R-core: si Bloque 0 (BNW) no pasa, NO PASA global sin excepcion.\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% -- Helpers locales --------------------------------------------------------
function out = iif_local(cond, a, b)
    if cond, out = a; else, out = b; end
end

function ok = same_posterior(P1, P2, tol)
%SAME_POSTERIOR  Compara los 3 componentes finales del posterior NIW
%   (PpsiTilde, OomegaTilde, PphiTilde) entre dos corridas de
%   build_posterior.m, dentro de una tolerancia. Usado en Bloque 1 para
%   confirmar que un campo opcional ausente vs. presente con su valor
%   default produce EXACTAMENTE el mismo resultado (retrocompatibilidad).
    ok = isequal(size(P1.PpsiTilde), size(P2.PpsiTilde)) && ...
         max(abs(P1.PpsiTilde(:)   - P2.PpsiTilde(:)))   <= tol && ...
         max(abs(P1.OomegaTilde(:) - P2.OomegaTilde(:))) <= tol && ...
         max(abs(P1.PphiTilde(:)   - P2.PphiTilde(:)))   <= tol;
end

function frac_stable = p_local_check_stability(Results, Cfg)
%P_LOCAL_CHECK_STABILITY  Misma copia local usada en validate_erpt11.m,
%   diagnose_erpt11_niwcustom_sensitivity.m y validate_erpt11_scientific.m
%   -- sirve aqui como referencia independiente para cross-validar el fix
%   aplicado a check_stability.m (core).
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
