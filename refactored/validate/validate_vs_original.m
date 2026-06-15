%VALIDATE_VS_ORIGINAL  Compara curvas completas (mediana + q16 + q84)
%   entre los .mat del original y el refactorizado, para PFA e IS.
%
%   Ejecutar desde cualquier working directory.
%   NO genera figuras ni guarda .mat.
%
%   Requiere los .mat locales del original:
%     original/figure_1_panel_a/results/matfiles/results.mat  (PFA)
%     original/figure_1_panel_b/results/matfiles/results.mat  (IS)
%
%   Para cada variable y modo imprime:
%     max|Δmedian|, max|Δq16|, max|Δq84|  sobre h=0..40

fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║   VALIDATE VS ORIGINAL — Curvas completas h=0..40           ║\n');
fprintf('║   Compara mediana + q16 + q84 contra .mat del original      ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

%% ── Rutas absolutas ──────────────────────────────────────────────────────
val_root  = fileparts(mfilename('fullpath'));   % .../refactored/validate/
proj_root = fileparts(val_root);               % .../refactored/
repo_root = fileparts(proj_root);              % .../svartoolkit/
src_dir   = fullfile(proj_root, 'src');
cfg_dir   = fullfile(proj_root, 'config');
help_dir  = fullfile(proj_root, 'helpfunctions');

addpath(src_dir);
addpath(cfg_dir);
addpath(help_dir);

% Rutas a los .mat del original
mat_pfa = fullfile(repo_root, 'original', 'figure_1_panel_a', ...
                   'results', 'matfiles', 'results.mat');
mat_is  = fullfile(repo_root, 'original', 'figure_1_panel_b', ...
                   'results', 'matfiles', 'results.mat');

% Labels de variables
var_names = {'TFP', 'StockPrices', 'Consumption', 'RealRate', 'Hours'};
n     = 5;
shock = 1;   % shock de optimismo (columna 1 en PFA, dimensión 3 en IS)

% =========================================================================
%  BLOQUE PFA
% =========================================================================
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║   BLOQUE PFA                                                 ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

%% ── Cargar original PFA ──────────────────────────────────────────────────
fprintf('Cargando original PFA desde:\n  %s\n\n', mat_pfa);
orig_pfa = load(mat_pfa, 'Ltilde', 'FEVD');
Lt_orig_pfa = orig_pfa.Ltilde;    % [41, 5, 10000]
FV_orig_pfa = orig_pfa.FEVD;      % [5, 10000]

%% ── Correr refactorizado PFA ─────────────────────────────────────────────
fprintf('Corriendo refactorizado PFA con rng(0)...\n');
Cfg = struct();
run(fullfile(cfg_dir, 'spec_bnw_pfa.m'));
Cfg.PLOT_IRFS    = false;
Cfg.SAVE_RESULTS = false;
Dataset   = load_data(Cfg);
Posterior = build_posterior(Dataset, Cfg);
rng(0);
tic;
Res_pfa = run_pfa(Posterior, Cfg);
fprintf('  Tiempo: %.1f seg\n\n', toc);

Lt_ref_pfa = Res_pfa.LtildeStruct.data;   % [41, 5, 10000]
FV_ref_pfa = Res_pfa.FEVD;                 % [5, 10000]

%% ── Comparar curvas PFA ──────────────────────────────────────────────────
fprintf('%-14s  %14s  %14s  %14s\n', 'Variable', 'max|Δmedian|', 'max|Δq16|', 'max|Δq84|');
fprintf('%s\n', repmat('─', 1, 62));

all_ok_pfa = true;
TOL = 1e-8;

for v = 1:n
    % Original: Ltilde(:, v, :) → [41, 10000]
    irf_orig = squeeze(Lt_orig_pfa(:, v, :));   % [41, 10000]
    irf_ref  = squeeze(Lt_ref_pfa(:, v, :));    % [41, 10000]

    med_orig = median(irf_orig, 2);   % [41, 1]
    q16_orig = quantile(irf_orig, 0.16, 2);
    q84_orig = quantile(irf_orig, 0.84, 2);

    med_ref  = median(irf_ref, 2);
    q16_ref  = quantile(irf_ref, 0.16, 2);
    q84_ref  = quantile(irf_ref, 0.84, 2);

    d_med = max(abs(med_orig - med_ref));
    d_q16 = max(abs(q16_orig - q16_ref));
    d_q84 = max(abs(q84_orig - q84_ref));

    ok = (d_med <= TOL) && (d_q16 <= TOL) && (d_q84 <= TOL);
    if ~ok; all_ok_pfa = false; end

    status = '✓';
    if ~ok; status = '✗'; end

    fprintf('%s %-12s  %14.6e  %14.6e  %14.6e\n', ...
        status, var_names{v}, d_med, d_q16, d_q84);
end

% FEVD
fed_orig = median(FV_orig_pfa, 2);   % [5,1]
fed_ref  = median(FV_ref_pfa,  2);
d_fevd   = max(abs(fed_orig - fed_ref));
ok_fevd  = d_fevd <= TOL;
if ~ok_fevd; all_ok_pfa = false; end
fprintf('%s %-12s  %14.6e  (mediana escalar por variable)\n', ...
    iif(ok_fevd,'✓','✗'), 'FEVD@h40', d_fevd);

fprintf('%s\n', repmat('─', 1, 62));
if all_ok_pfa
    fprintf('✓ PFA: reproducción exacta en toda la curva  (tol=%.0e)\n\n', TOL);
else
    fprintf('✗ PFA: hay diferencias > tol — ver filas marcadas con ✗\n\n');
end

% =========================================================================
%  BLOQUE IS
% =========================================================================
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║   BLOQUE IS                                                  ║\n');
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');

%% ── Cargar original IS ───────────────────────────────────────────────────
fprintf('Cargando original IS desde:\n  %s\n\n', mat_is);
orig_is = load(mat_is, 'Ltilde', 'FEVD', 'ne');
Lt_orig_is = orig_is.Ltilde;    % [41, 5, 5, 10000]
FV_orig_is = orig_is.FEVD;      % [5, 10000]
ne_orig    = orig_is.ne;

%% ── Correr refactorizado IS ──────────────────────────────────────────────
fprintf('Corriendo refactorizado IS con rng(0) (nd=30000, ~10-15 min)...\n');
Cfg = struct();
run(fullfile(cfg_dir, 'spec_bnw_is.m'));
Cfg.PLOT_IRFS    = false;
Cfg.SAVE_RESULTS = false;
Dataset   = load_data(Cfg);
Posterior = build_posterior(Dataset, Cfg);
rng('default'); rng(0);
tic;
Res_is = run_is(Posterior, Cfg);
fprintf('  Tiempo: %.1f seg\n\n', toc);

Lt_ref_is = Res_is.LtildeStruct.data;   % [41, 5, 5, ne]
FV_ref_is = Res_is.FEVD;                 % [5, ne]
ne_ref    = Res_is.ne;

fprintf('ne original = %d  |  ne refactorizado = %d  |  %s\n\n', ...
    ne_orig, ne_ref, iif(ne_orig == ne_ref, '✓ exacto', '✗ difieren'));

%% ── Comparar curvas IS ───────────────────────────────────────────────────
fprintf('%-14s  %14s  %14s  %14s\n', 'Variable', 'max|Δmedian|', 'max|Δq16|', 'max|Δq84|');
fprintf('%s\n', repmat('─', 1, 62));

all_ok_is = true;

for v = 1:n
    % IS: Ltilde(:, v, shock, draw) — shock=1
    irf_orig = squeeze(Lt_orig_is(:, v, shock, :));   % [41, 10000]
    irf_ref  = squeeze(Lt_ref_is(:,  v, shock, :));   % [41, ne]

    med_orig = median(irf_orig, 2);
    q16_orig = quantile(irf_orig, 0.16, 2);
    q84_orig = quantile(irf_orig, 0.84, 2);

    med_ref  = median(irf_ref, 2);
    q16_ref  = quantile(irf_ref, 0.16, 2);
    q84_ref  = quantile(irf_ref, 0.84, 2);

    d_med = max(abs(med_orig - med_ref));
    d_q16 = max(abs(q16_orig - q16_ref));
    d_q84 = max(abs(q84_orig - q84_ref));

    ok = (d_med <= TOL) && (d_q16 <= TOL) && (d_q84 <= TOL);
    if ~ok; all_ok_is = false; end

    fprintf('%s %-12s  %14.6e  %14.6e  %14.6e\n', ...
        iif(ok,'✓','✗'), var_names{v}, d_med, d_q16, d_q84);
end

% FEVD IS
fed_orig = median(FV_orig_is, 2);
fed_ref  = median(FV_ref_is,  2);
d_fevd_is = max(abs(fed_orig - fed_ref));
ok_fevd_is = d_fevd_is <= TOL;
if ~ok_fevd_is; all_ok_is = false; end
fprintf('%s %-12s  %14.6e  (mediana escalar por variable)\n', ...
    iif(ok_fevd_is,'✓','✗'), 'FEVD@h40', d_fevd_is);

fprintf('%s\n', repmat('─', 1, 62));
if all_ok_is
    fprintf('✓ IS: reproducción exacta en toda la curva  (tol=%.0e)\n\n', TOL);
else
    fprintf('✗ IS: hay diferencias > tol — ver filas marcadas con ✗\n\n');
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('╔══════════════════════════════════════════════════════════════╗\n');
fprintf('║              VEREDICTO GLOBAL                                ║\n');
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
fprintf('║  PFA : %-56s║\n', iif(all_ok_pfa, 'PASA — curvas exactas', 'NO PASA — ver diferencias'));
fprintf('║  IS  : %-56s║\n', iif(all_ok_is,  'PASA — curvas exactas', 'NO PASA — ver diferencias'));
fprintf('╠══════════════════════════════════════════════════════════════╣\n');
if all_ok_pfa && all_ok_is
    fprintf('║  GLOBAL : PASA — reproducción exacta en toda la curva        ║\n');
else
    fprintf('║  GLOBAL : NO PASA — hay diferencias en alguna curva          ║\n');
end
fprintf('╚══════════════════════════════════════════════════════════════╝\n\n');
fprintf('Pegar este output completo en el chat para verificación.\n\n');

%% ── Helper local ─────────────────────────────────────────────────────────
function out = iif(cond, a, b)
    if cond; out = a; else; out = b; end
end
