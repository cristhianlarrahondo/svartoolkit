%DIAGNOSE_ERPT9_PRIOR_SCALE  Diagnostico ligero (ERPT-Chat 9): compara la
%   varianza residual OLS (sig2) de 'ner' y 'con_inf' entre datasets mm y
%   aa, y la varianza de prior Minnesota que eso implica para el
%   coeficiente cruzado "ner rezagado -> con_inf", para verificar si el
%   prior Minnesota resulta efectivamente MAS LAXO bajo mm que bajo aa
%   (hipotesis planteada en el chat, a partir de leer build_posterior.m).
%
%   Por que sig2(j), no sig2(i): en la implementacion de 'minnesota' en
%   build_posterior.m (case 'minnesota'), omega_bar_diag(idx) para
%   idx=(l-1)*n+j depende de sig2(j) -- la varianza OLS de la variable
%   REGRESORA j, NO de la ecuacion i en que se usa. Osea que la
%   holgura del prior sobre "cuanto puede influir ner rezagado en
%   cualquier ecuacion (incluida con_inf)" depende de sig2(ner), no de
%   sig2(con_inf). Esta funcion extrae sig2(ner) y sig2(con_inf) de cada
%   dataset (mm y aa) via build_posterior (SOLO OLS -- no corre run_is,
%   no muestrea nada) y calcula la varianza de prior implicada para el
%   coeficiente cruzado ner(lag1) -> con_inf bajo 'minnesota'.
%
%   NO modifica build_posterior.m ni ningun archivo de src/ compartido --
%   solo LEE su output (PosteriorParams) para specs ya existentes. NO
%   corre run_is (no requiere minutos de computo, solo el ajuste OLS).
%
%   Ejecutar COMPLETO (F5).

fprintf('\n');
fprintf('======================================================\n');
fprintf('   DIAGNOSTICO ERPT-CHAT 9 -- escala de sig2 y prior Minnesota (mm vs aa)\n');
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

%% ── Specs a inspeccionar: los 4 minn (2 mm + 2 aa) + 1 mm_diffuse de control
spec_names = { ...
    'spec_A_base_mm_minn_lag2_v0', 'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_base_aa_minn_lag2_v0', 'spec_A_base_aa_minn_lag4_v0', ...
    'spec_A_base_mm_diffuse_lag2_v0' };   % control: mismo transform que mm_minn, prior diffuse (sin omega_bar)

fprintf('  Specs inspeccionadas: %s\n\n', strjoin(spec_names, ', '));

fprintf('  %-32s %10s %10s %10s %14s %18s\n', ...
    'spec', 'sig2(ner)', 'sig2(con)', 'ratio c/n', 'prior_var(l1)', 'prior_std(l1)');

for ss = 1:numel(spec_names)
    spec_name = spec_names{ss};

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    Cfg.PLOT_IRFS    = false;
    Cfg.SAVE_RESULTS = false;

    Dataset_spec = load_data(Cfg);
    Posterior_spec = build_posterior(Dataset_spec, Cfg);   % SOLO OLS + prior -- no run_is

    endo_mask = strcmp(Dataset_spec.var_roles, 'endogenous');
    var_names = Dataset_spec.var_names(endo_mask);
    idx_ner   = find(strcmp(var_names, 'ner'), 1);
    idx_con   = find(strcmp(var_names, 'con_inf'), 1);

    sig2_all = diag(Posterior_spec.Sigmau);
    sig2_ner = sig2_all(idx_ner);
    sig2_con = sig2_all(idx_con);
    ratio_cn = sig2_con / sig2_ner;

    % Reconstruir omega_bar_diag para el regresor "ner, lag 1" EXACTAMENTE
    % como lo hace build_posterior.m (case 'minnesota'), solo para
    % reportar -- no se usa para nada mas que imprimir el numero.
    if isfield(Cfg, 'PRIOR') && isfield(Cfg.PRIOR, 'type') && strcmpi(Cfg.PRIOR.type, 'minnesota')
        lambda1 = Cfg.PRIOR.lambda1;
        lambda2 = Cfg.PRIOR.lambda2;
        lambda3 = Cfg.PRIOR.lambda3;
        n = Dataset_spec.nvar;
        w = (1 + (n-1)*lambda2^2) / n;
        prior_var_ner_l1 = (lambda1 / 1^lambda3)^2 * sig2_ner * w;   % l=1
        prior_std_ner_l1 = sqrt(prior_var_ner_l1);
        pv_str  = sprintf('%14.6f', prior_var_ner_l1);
        pstd_str = sprintf('%18.6f', prior_std_ner_l1);
    else
        pv_str   = sprintf('%14s', 'n/a (diffuse)');
        pstd_str = sprintf('%18s', 'n/a');
    end

    fprintf('  %-32s %10.6f %10.6f %10.4f %s %s\n', ...
        spec_name, sig2_ner, sig2_con, ratio_cn, pv_str, pstd_str);
end

fprintf('\n');
fprintf('======================================================\n');
fprintf('  Lectura:\n');
fprintf('  - sig2(ner), sig2(con) = varianza residual OLS de cada variable en\n');
fprintf('    SU PROPIO dataset (mm o aa) -- confirma si la escala bruta difiere.\n');
fprintf('  - prior_var(l1)/prior_std(l1) = varianza/desv.estandar de prior\n');
fprintf('    Minnesota implicada para el coeficiente "ner(lag1) -> cualquier\n');
fprintf('    ecuacion" (formula real de build_posterior.m, case minnesota).\n');
fprintf('    Como esta varianza depende de sig2(ner) [la variable REGRESORA],\n');
fprintf('    NO de sig2(con_inf) [la ecuacion], un sig2(ner) grande bajo mm\n');
fprintf('    relativo a aa implicaria un prior mas laxo (menos shrinkage) sobre\n');
fprintf('    cuanto puede influir ner rezagado en con_inf bajo mm que bajo aa --\n');
fprintf('    consistente con un numerador (con_inf acumulado) menos controlado.\n');
fprintf('  - La fila mm_diffuse es control: mismo transform que mm_minn, pero\n');
fprintf('    prior_var no aplica (diffuse no tiene Omega informativo) -- sirve\n');
fprintf('    solo para comparar sig2(ner)/sig2(con) brutos del dataset mm.\n');
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat.\n\n');
