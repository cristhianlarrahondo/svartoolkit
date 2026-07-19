%VALIDATE_ERPT11  ERPT-Chat 11 -- Smoke test (ND~=3000) de las 8 specs
%   nuevas/corregidas del grupo mm_minn: 4 "Minnesota corregida" (lambda1
%   revertido 0.1->0.2, D2-D4 de ERPT-Chat 10) + 4 "niw_custom" (D5,
%   variante adicional con Psi_bar de rezago-1 propio = 0.90). Protocolo
%   Tipo S (config-only; no toca build_posterior.m, run_is.m ni
%   load_data.m -- niw_custom ya existia en build_posterior.m desde el
%   Chat 12 original del toolkit).
%
%   Ejecutar COMPLETO (F5), nunca por secciones. Pegar el output de
%   consola en el chat para verificacion.
%
%   -- Que hace ------------------------------------------------------------
%   BLOQUE 1 -- Construccion de Cfg.PRIOR: por spec, verifica que los
%     campos y valores esperados esten presentes (lambda1/2/3 para las 4
%     minn corregidas; nu_bar/Phi_bar/Psi_bar/Omega_bar con la estructura
%     de D5 para las 4 niw_custom), sin correr nada de muestreo.
%   BLOQUE 2 -- Smoke end-to-end (Cfg.ND=3000) de las 8 specs: load_data ->
%     validate_cfg -> build_posterior -> run_is -> calculate_erpt, sin
%     error. Por spec, calcula la fraccion de draws CRUDOS (los Cfg.ND
%     candidatos de run_is, antes del filtro de signos/resampling -- mismo
%     criterio y misma limitacion conceptual que check_stability.m del
%     core, reimplementado LOCALMENTE en este script por la misma razon
%     documentada en diagnose_erpt9_dynamics.m: check_stability.m infiere
%     nex asumiendo solo Cfg.NEX y no contempla las dummies COVID
%     exogenas -- no se modifica el archivo compartido, Tipo S).
%   BLOQUE 3 -- Tabla comparativa de fraccion estable contra los
%     benchmarks ya establecidos (ERPT-Chat 9): 88.98% mm_diffuse, 24-25%
%     mm_minn roto (lambda1=0.1), 57.98% aa_minn. Veredicto por spec segun
%     el umbral D6 (>70% -> apta para corrida cientifica ND=3e6 en un chat
%     posterior).
%   BLOQUE 4 -- Casos de error esperados (niw_custom sin un campo
%     requerido -> build_posterior:missingHyperparameter; minnesota sin
%     lambda3 -> idem).
%
%   NOTA: no se corre Bloque 0 (regresion BNW) -- este chat no toca
%   run_is.m/build_posterior.m/load_data.m (confirmado en ERPT-Chat 10,
%   D6 de la Bitacora Seccion C: "ERPT-Chat 11 tampoco los tocara").

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 11 -- 8 specs (smoke ND~3000): Minnesota\n');
fprintf('   corregida (lambda1=0.2) + niw_custom (D5)\n');
fprintf('======================================================\n\n');

%% -- Controles de corrida (editar aqui) ------------------------------------
ND_SMOKE           = 3000;    % draws candidatos para el smoke test
STABLE_PASS_THRESH = 0.70;    % D6: >70% -> apta para corrida cientifica

%% -- Rutas (F5 completo -> mfilename('fullpath') es confiable) -------------
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);            % .../refactored/projects/erpt
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);       % .../refactored
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(PROJ_CFG);
addpath(PROJ_SRC);

fprintf('  REF_ROOT   : %s\n', REF_ROOT);
fprintf('  PROJ_ROOT  : %s\n', PROJ_ROOT);
fprintf('  ND_SMOKE   : %g\n\n', ND_SMOKE);

V = {'FAIL', 'OK  '};

% Los 8 specs de este chat, agrupados en 2 familias de 4.
minn_specs = { ...
    'spec_A_base_mm_minn_lag2_v0', 'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_rob_mm_minn_lag2_v0',  'spec_A_rob_mm_minn_lag4_v0'  };

niwc_specs = { ...
    'spec_A_base_mm_niwcustom_lag2_v0', 'spec_A_base_mm_niwcustom_lag4_v0', ...
    'spec_A_rob_mm_niwcustom_lag2_v0',  'spec_A_rob_mm_niwcustom_lag4_v0'  };

all_specs = [minn_specs, niwc_specs];
NAMED_SHOCKS = {'Cam', 'Dem', 'Ofe'};   % 3 choques nombrados (Mon removido desde ERPT-Chat 9)

% =========================================================================
%  BLOQUE 1 -- Construccion de Cfg.PRIOR (sin correr muestreo)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- Construccion de Cfg.PRIOR por spec\n');
fprintf('======================================================\n\n');

bloque1_ok   = true;
bloque1_msgs = {};

fprintf('  --- Familia "Minnesota corregida" (lambda1=0.2, lambda2=0.5, lambda3=2) ---\n');
for ss = 1:numel(minn_specs)
    spec_name = minn_specs{ss};
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));

    ok = isfield(Cfg, 'PRIOR') && strcmpi(Cfg.PRIOR.type, 'minnesota') && ...
         isfield(Cfg.PRIOR, 'lambda1') && isfield(Cfg.PRIOR, 'lambda2') && isfield(Cfg.PRIOR, 'lambda3') && ...
         abs(Cfg.PRIOR.lambda1 - 0.2) < 1e-12 && abs(Cfg.PRIOR.lambda2 - 0.5) < 1e-12 && abs(Cfg.PRIOR.lambda3 - 2) < 1e-12;

    if ~ok
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: Cfg.PRIOR no tiene lambda1=0.2/lambda2=0.5/lambda3=2 esperados', spec_name); %#ok<AGROW>
    end
    fprintf('  %-38s lambda1=%.2f lambda2=%.2f lambda3=%.2f   %s\n', ...
        spec_name, Cfg.PRIOR.lambda1, Cfg.PRIOR.lambda2, Cfg.PRIOR.lambda3, V{int32(ok)+1});
end
fprintf('\n');

fprintf('  --- Familia "niw_custom" (D5: misma varianza, Psi_bar rezago-1=0.90) ---\n');
for ss = 1:numel(niwc_specs)
    spec_name = niwc_specs{ss};
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));

    has_fields = isfield(Cfg, 'PRIOR') && strcmpi(Cfg.PRIOR.type, 'niw_custom') && ...
        all(isfield(Cfg.PRIOR, {'nu_bar', 'Phi_bar', 'Psi_bar', 'Omega_bar'}));

    ok = has_fields;
    if has_fields
        n = numel(Cfg.VARS);
        p = Cfg.NLAG;
        % Diagonal de Psi_bar en el bloque de rezago-1 debe ser 0.90.
        psi_diag_lag1 = diag(Cfg.PRIOR.Psi_bar(1:n, 1:n));
        ok = ok && all(abs(psi_diag_lag1 - 0.90) < 1e-10);
        % Resto de Psi_bar (rezagos >1 + exogenas) debe ser cero.
        Psi_rest = Cfg.PRIOR.Psi_bar((n+1):end, :);
        ok = ok && all(Psi_rest(:) == 0);
        % nu_bar=0, Phi_bar=zeros(n) (vagos por defecto).
        ok = ok && (Cfg.PRIOR.nu_bar == 0) && isequal(Cfg.PRIOR.Phi_bar, zeros(n));
        % Omega_bar cuadrada [m x m], positiva en la diagonal.
        m = size(Cfg.PRIOR.Omega_bar, 1);
        ok = ok && isequal(size(Cfg.PRIOR.Omega_bar), [m m]) && all(diag(Cfg.PRIOR.Omega_bar) > 0);
    end

    if ~ok
        bloque1_ok = false;
        bloque1_msgs{end+1} = sprintf('%s: Cfg.PRIOR (niw_custom) no cumple la estructura D5 esperada', spec_name); %#ok<AGROW>
    end
    fprintf('  %-38s nu_bar=%g  Psi_bar(lag1 diag)=0.90  Omega_bar %dx%d   %s\n', ...
        spec_name, Cfg.PRIOR.nu_bar, size(Cfg.PRIOR.Omega_bar,1), size(Cfg.PRIOR.Omega_bar,2), V{int32(ok)+1});
end
fprintf('\n');

if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA -- las 8 specs construyen Cfg.PRIOR segun D2-D5.\n\n');
else
    fprintf('  >> BLOQUE 1: NO PASA. Detalle:\n');
    for i = 1:numel(bloque1_msgs)
        fprintf('     - %s\n', bloque1_msgs{i});
    end
    fprintf('\n');
end

% =========================================================================
%  BLOQUE 2 -- Smoke end-to-end (ND=3000) + estabilidad de draws crudos
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Smoke end-to-end (ND=%g) + estabilidad\n', ND_SMOKE);
fprintf('======================================================\n\n');

bloque2_ok   = true;
bloque2_msgs = {};
frac_stable_by_spec = struct();

for ss = 1:numel(all_specs)
    spec_name = all_specs{ss};
    fprintf('------------------------------------------------------\n');
    fprintf('  [%d/%d] Spec: %s\n', ss, numel(all_specs), spec_name);
    fprintf('------------------------------------------------------\n');

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;
    Cfg.ND           = ND_SMOKE;

    if contains(spec_name, '_aa_')
        transform_type = 'aa'; %#ok<NASGU>
    else
        transform_type = 'mm';
    end

    try
        Dataset_spec = load_data(Cfg);
        fprintf('  Dataset: %d endogenas, freq=%s, T=%d obs\n', ...
            Dataset_spec.nvar, Dataset_spec.freq, size(Dataset_spec.Y_raw, 1));

        validate_cfg(Cfg, Dataset_spec);
        Posterior_spec = build_posterior(Dataset_spec, Cfg);

        if isfield(Posterior_spec, 'ndummies') && Posterior_spec.ndummies ~= 2
            fprintf('  [ALERTA] se esperaban 2 dummies COVID, hay %d.\n', Posterior_spec.ndummies);
        end

        rng('default'); rng(Cfg.SEED);
        tic;
        Results_spec = run_is(Posterior_spec, Cfg);
        t_elapsed = toc;
        fprintf('  Tiempo: %.1f seg | ne=%d\n', t_elapsed, Results_spec.ne);

        ERPT_spec = calculate_erpt(Results_spec, Dataset_spec, Cfg, transform_type); %#ok<NASGU>

        % -- Checks estructurales minimos ----------------------------------
        names_out = {ERPT_spec.shocks.name};
        if ~all(ismember(NAMED_SHOCKS, names_out))
            bloque2_ok = false;
            bloque2_msgs{end+1} = sprintf('%s: faltan choques nombrados (esperados %s; presentes %s)', ...
                spec_name, strjoin(NAMED_SHOCKS, '/'), strjoin(names_out, '/')); %#ok<AGROW>
        end

        % -- Estabilidad sobre los ND draws crudos (candidatos, pre-resampling)
        frac_stable = p_local_check_stability(Results_spec, Cfg);
        frac_stable_by_spec.(spec_name) = frac_stable;

    catch ME
        bloque2_ok = false;
        bloque2_msgs{end+1} = sprintf('%s: ERROR -- %s', spec_name, ME.message); %#ok<AGROW>
        fprintf('  [ERROR] %s\n', ME.message);
        frac_stable_by_spec.(spec_name) = NaN;
    end
    fprintf('\n');
end

if bloque2_ok
    fprintf('  >> BLOQUE 2: PASA -- las 8 specs corrieron end-to-end sin error.\n\n');
else
    fprintf('  >> BLOQUE 2: NO PASA. Detalle:\n');
    for i = 1:numel(bloque2_msgs)
        fprintf('     - %s\n', bloque2_msgs{i});
    end
    fprintf('\n');
end

% =========================================================================
%  BLOQUE 3 -- Tabla comparativa de estabilidad vs. benchmarks (ERPT-Chat 9)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Fraccion estable vs. benchmarks (ERPT-Chat 9)\n');
fprintf('======================================================\n\n');

fprintf('  Benchmarks ya establecidos (draws crudos, ERPT-Chat 9):\n');
fprintf('    mm_diffuse            : 88.98%%  (referencia \"sano\")\n');
fprintf('    mm_minn (lambda1=0.1) : 24-25%%  (roto, motivo de este chat)\n');
fprintf('    aa_minn (lambda1=0.1) : 57.98%%  (no se toca en este chat)\n\n');

fprintf('  %-38s %12s %10s\n', 'spec', 'frac_estable', 'veredicto');
spec_verdicts = struct();
for ss = 1:numel(all_specs)
    spec_name = all_specs{ss};
    fs = frac_stable_by_spec.(spec_name);
    if isnan(fs)
        verdict = 'N/A (error)';
    elseif fs >= STABLE_PASS_THRESH
        verdict = sprintf('>= %.0f%% OK', 100*STABLE_PASS_THRESH);
    else
        verdict = sprintf('< %.0f%%', 100*STABLE_PASS_THRESH);
    end
    spec_verdicts.(spec_name) = verdict;
    if isnan(fs)
        fprintf('  %-38s %12s %10s\n', spec_name, 'NaN', verdict);
    else
        fprintf('  %-38s %11.2f%% %10s\n', spec_name, 100*fs, verdict);
    end
end
fprintf('\n');

% -- Comparacion por familia (promedio simple, informativo) --------------
minn_fracs = cellfun(@(s) frac_stable_by_spec.(s), minn_specs);
niwc_fracs = cellfun(@(s) frac_stable_by_spec.(s), niwc_specs);
fprintf('  Promedio "Minnesota corregida" (4 specs) : %.2f%%\n', 100*mean(minn_fracs(~isnan(minn_fracs))));
fprintf('  Promedio "niw_custom"          (4 specs) : %.2f%%\n\n', 100*mean(niwc_fracs(~isnan(niwc_fracs))));

fprintf('  Lectura (D6, ERPT-Chat-10-discusion-cierre.md):\n');
fprintf('    Si "Minnesota corregida" alcanza >%.0f%% -> va a corrida cientifica\n', 100*STABLE_PASS_THRESH);
fprintf('    (ND=3e6) en un chat posterior; niw_custom queda documentada como\n');
fprintf('    alternativa explorada pero no necesaria para el paper.\n');
fprintf('    Si ninguna basta -> segunda iteracion (lambda1=0.3 y/o Psi_bar=0.85),\n');
fprintf('    a discutir antes de escalar computo.\n\n');

% =========================================================================
%  BLOQUE 4 -- Casos de error esperados
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 4 -- Casos de error esperados\n');
fprintf('======================================================\n\n');

bloque4_ok   = true;
bloque4_msgs = {};

% Caso 1: minnesota sin lambda3 -> build_posterior:missingHyperparameter
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [minn_specs{1} '.m']));
    Cfg.PRIOR = rmfield(Cfg.PRIOR, 'lambda3');
    Dataset_bad = load_data(Cfg);
    build_posterior(Dataset_bad, Cfg);
    bloque4_ok = false; bloque4_msgs{end+1} = 'minnesota sin lambda3: NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] minnesota sin lambda3 no genero error\n');
catch ME
    fprintf('  [OK] minnesota sin lambda3 -> error esperado: %s\n', ME.identifier);
end

% Caso 2: niw_custom sin Omega_bar -> build_posterior:missingHyperparameter
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [niwc_specs{1} '.m']));
    Cfg.PRIOR = rmfield(Cfg.PRIOR, 'Omega_bar');
    Dataset_bad = load_data(Cfg);
    build_posterior(Dataset_bad, Cfg);
    bloque4_ok = false; bloque4_msgs{end+1} = 'niw_custom sin Omega_bar: NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] niw_custom sin Omega_bar no genero error\n');
catch ME
    fprintf('  [OK] niw_custom sin Omega_bar -> error esperado: %s\n', ME.identifier);
end

% Caso 3: niw_custom con Omega_bar mal dimensionada -> error en build_posterior
% (X_aug'*X_aug + OomegaBarInverse falla por dimensiones incompatibles)
try
    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [niwc_specs{1} '.m']));
    Cfg.PRIOR.Omega_bar = Cfg.PRIOR.Omega_bar(1:end-1, 1:end-1);   % quita 1 fila/col
    Dataset_bad = load_data(Cfg);
    build_posterior(Dataset_bad, Cfg);
    bloque4_ok = false; bloque4_msgs{end+1} = 'niw_custom Omega_bar mal dimensionada: NO lanzo error'; %#ok<AGROW>
    fprintf('  [FAIL] niw_custom Omega_bar mal dimensionada no genero error\n');
catch ME
    fprintf('  [OK] niw_custom Omega_bar mal dimensionada -> error esperado: %s\n', ME.identifier);
end

fprintf('\n');
if bloque4_ok
    fprintf('  >> BLOQUE 4: PASA -- los 3 casos de error se comportan como se esperaba.\n\n');
else
    fprintf('  >> BLOQUE 4: NO PASA. Detalle:\n');
    for i = 1:numel(bloque4_msgs)
        fprintf('     - %s\n', bloque4_msgs{i});
    end
    fprintf('\n');
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('======================================================\n');
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 11\n');
fprintf('======================================================\n');
fprintf('  Bloque 1 (Construccion Cfg.PRIOR, 8 specs) : %s\n', iif_local(bloque1_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 2 (Smoke end-to-end, ND=%-6g)       : %s\n', ND_SMOKE, iif_local(bloque2_ok, 'PASA', 'NO PASA'));
fprintf('  Bloque 3 (Tabla de estabilidad)             : (informativo, ver arriba)\n');
fprintf('  Bloque 4 (Casos de error)                   : %s\n', iif_local(bloque4_ok, 'PASA', 'NO PASA'));
fprintf('------------------------------------------------------\n');
if bloque1_ok && bloque2_ok && bloque4_ok
    fprintf('  GLOBAL : PASA (estructura y ejecucion sin error)\n');
    fprintf('  Veredicto CIENTIFICO de estabilidad por spec (umbral %.0f%%): ver Bloque 3.\n', 100*STABLE_PASS_THRESH);
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% -- Helpers locales --------------------------------------------------------
function out = iif_local(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

function frac_stable = p_local_check_stability(Results, Cfg)
%P_LOCAL_CHECK_STABILITY  Copia local de la logica de check_stability.m
%   (core, sin modificar), con UNA correccion: nex_total incluye las
%   dummies exogenas (Cfg.NEX + numel(Cfg.DUMMIES)), no solo Cfg.NEX --
%   misma razon documentada en diagnose_erpt9_dynamics.m (ERPT-Chat 9).
%   Mide sobre TODOS los draws candidatos (Cfg.ND), no solo los aceptados/
%   resampleados -- proxy de la poblacion candidata, no de ne.
    required = {'Bdraws', 'LtildeStruct'};
    for ii = 1:numel(required)
        if ~isfield(Results, required{ii})
            error('p_local_check_stability:missingField', ...
                'Results no contiene campo .%s.', required{ii});
        end
    end

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
    p = (m_rows - nex_total) / n;
    if p ~= floor(p) || p < 1
        error('p_local_check_stability:badDims', ...
            'No se pudo inferir el numero de lags (m_rows=%d, n=%d, nex_total=%d).', ...
            m_rows, n, nex_total);
    end
    p = round(p);

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
