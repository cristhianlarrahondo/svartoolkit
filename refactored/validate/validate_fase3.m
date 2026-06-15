%VALIDATE_FASE3  Verificacion numerica del modo IS (Fase 3).
%
%   Ejecutar desde cualquier working directory.
%   Compara contra valores de referencia exactos del original con rng(0),
%   obtenidos ejecutando original/figure_1_panel_b/run_mainfile1.m.
%
%   Checks:
%     a) Ltilde(1,1,1,1)                          — primer elemento 4D
%     b) Ltilde(end,end,end,end)                  — ultimo elemento
%     c) median(squeeze(Ltilde(:,2,1,:)), 'all')  — mediana IRF stock prices al shock 1
%     d) median(FEVD(2,:))                        — FEVD stock prices @ h=40
%     e) ESS / nd                                 — fraccion de draws efectivos
%
%   Valores de referencia (original ejecutado con rng(0)):
%     a) 0.0000000000
%     b) 0.2041864191
%     c) 2.9521795528
%     d) 0.2580366201
%     e) 0.389133  (ne=11674, nd=30000)
%
%   Tolerancia: 1e-6 para IRFs/FEVD (dependencia de orden de operaciones float)
%               exacto para ne, ESS/nd, ESS/sign

%% ── Rutas absolutas ──────────────────────────────────────────────────────
val_root  = fileparts(mfilename('fullpath'));   % .../refactored/validate/
proj_root = fileparts(val_root);               % .../refactored/
src_dir   = fullfile(proj_root, 'src');
cfg_dir   = fullfile(proj_root, 'config');
help_dir  = fullfile(proj_root, 'helpfunctions');

addpath(src_dir);
addpath(cfg_dir);
addpath(help_dir);

fprintf('\n========================================================\n');
fprintf('  VALIDATE FASE 3 — Modo IS (Importance Sampler)\n');
fprintf('========================================================\n\n');

%% ── Fijar semilla (igual que el original) ────────────────────────────────
rng('default');
rng(0);

%% ── Cargar Cfg ───────────────────────────────────────────────────────────
Cfg = struct();
run(fullfile(cfg_dir, 'spec_bnw_is.m'));

%% ── Cargar datos y calcular posterior ───────────────────────────────────
Dataset         = load_data(Cfg);
PosteriorParams = build_posterior(Dataset, Cfg);

%% ── Ejecutar IS ──────────────────────────────────────────────────────────
fprintf('Ejecutando run_is (nd=%d, maxdraws=%d)...\n', Cfg.ND, Cfg.MAX_IS_DRAWS);
fprintf('Esto puede tardar varios minutos.\n\n');
tic;
Results = run_is(PosteriorParams, Cfg);
t_elapsed = toc;
fprintf('\nTiempo total: %.1f seg\n\n', t_elapsed);

%% ── Extraer objetos de verificacion ─────────────────────────────────────
Ltilde = Results.LtildeStruct.data;   % [horizon+1, n, n, ne]
FEVD   = Results.FEVD;                % [n, ne]
ne     = Results.ne;
nd     = Cfg.ND;

%% ── Valores de referencia (original, rng(0)) ────────────────────────────
REF.a = 0.0000000000;
REF.b = 0.2041864191;
REF.c = 2.9521795528;
REF.d = 0.2580366201;
REF.e = 0.389133;
REF.ne = 11674;

TOL_irf  = 1e-6;   % tolerancia para IRFs y FEVD
TOL_ess  = 1e-6;   % tolerancia para ESS

%% ── Calcular metricas ───────────────────────────────────────────────────

% a) Primer elemento 4D
val_a = Ltilde(1, 1, 1, 1);

% b) Ultimo elemento 4D
val_b = Ltilde(end, end, end, end);

% c) Mediana IRF stock prices (variable 2) al shock 1, todos horizontes
slice_c = squeeze(Ltilde(:, 2, 1, :));   % [horizon+1, ne]
val_c   = median(slice_c, 'all');

% d) Mediana FEVD stock prices a horizonte 40
val_d = median(FEVD(2, :));

% e) ESS / nd
val_e = ne / nd;

%% ── Veredictos ───────────────────────────────────────────────────────────
ok_a  = abs(val_a - REF.a) <= TOL_irf;
ok_b  = abs(val_b - REF.b) <= TOL_irf;
ok_c  = abs(val_c - REF.c) <= TOL_irf;
ok_d  = abs(val_d - REF.d) <= TOL_irf;
ok_e  = abs(val_e - REF.e) <= TOL_ess;
ok_ne = (ne == REF.ne);

% Helper inline para veredicto
verd = @(ok) 'OK  ' * ok + 'FAIL' * ~ok;  % char array trick no confiable
% Usamos celda de strings:
V = {'FAIL','OK  '};

%% ── Imprimir resultados ──────────────────────────────────────────────────
fprintf('------ Metricas de verificacion ------\n');
fprintf('                          Calculado          Referencia         Status\n');
fprintf('a) Ltilde(1,1,1,1)      = %.10f   %.10f   %s\n', val_a, REF.a, V{int32(ok_a)+1});
fprintf('b) Ltilde(end,end,end,end)= %.10f   %.10f   %s\n', val_b, REF.b, V{int32(ok_b)+1});
fprintf('c) median(Ltilde(:,2,1,:))= %.10f   %.10f   %s\n', val_c, REF.c, V{int32(ok_c)+1});
fprintf('d) median(FEVD(2,:))    = %.10f   %.10f   %s\n', val_d, REF.d, V{int32(ok_d)+1});
fprintf('e) ESS/nd               = %.6f       %.6f       %s\n', val_e, REF.e, V{int32(ok_e)+1});
fprintf('   ne                   = %d             %d             %s\n', ne, REF.ne, V{int32(ok_ne)+1});
fprintf('\n');

%% ── Verificacion de restricciones de identificacion ─────────────────────
median_sp_h0  = median(squeeze(Ltilde(1, 2, 1, :)));
median_tfp_h0 = median(squeeze(Ltilde(1, 1, 1, :)));
ok_sign = (median_sp_h0 > 0);
ok_zero = (abs(median_tfp_h0) < 1e-8);
fprintf('------ Restricciones de identificacion ------\n');
fprintf('median(Ltilde(1,2,1,:)) [StockPrices h=0] = %.10f  (>0: %s)\n', median_sp_h0, V{int32(ok_sign)+1});
fprintf('median(Ltilde(1,1,1,:)) [TFP h=0]         = %.10f  (~0: %s)\n', median_tfp_h0, V{int32(ok_zero)+1});
fprintf('\n');

%% ── Diagnostico IS ───────────────────────────────────────────────────────
n_signs = sum(Results.uw > 0);
ess_sign = ne / n_signs;
fprintf('------ Diagnostico IS ------\n');
fprintf('Draws satisfaciendo sign restrictions = %d / %d  (%.1f%%)\n', n_signs, nd, 100*n_signs/nd);
fprintf('ESS / sign-draws                      = %.6f  (paper: 0.780000)  %s\n', ess_sign, V{int32(abs(ess_sign-0.780035)<1e-4)+1});
fprintf('\n');

%% ── Tamanos de arrays ────────────────────────────────────────────────────
fprintf('------ Tamanos ------\n');
fprintf('size(Ltilde) = [%d %d %d %d]\n', size(Ltilde,1), size(Ltilde,2), size(Ltilde,3), size(Ltilde,4));
fprintf('size(FEVD)   = [%d %d]\n', size(FEVD,1), size(FEVD,2));
fprintf('\n');

%% ── Veredicto final ──────────────────────────────────────────────────────
all_ok = ok_a && ok_b && ok_c && ok_d && ok_e && ok_ne && ok_sign && ok_zero;
fprintf('========================================================\n');
if all_ok
    fprintf('  VEREDICTO FINAL: PASA\n');
else
    fprintf('  VEREDICTO FINAL: NO PASA\n');
    fprintf('  Checks fallidos:\n');
    if ~ok_a,  fprintf('    - a) Ltilde(1,1,1,1)\n'); end
    if ~ok_b,  fprintf('    - b) Ltilde(end,end,end,end)\n'); end
    if ~ok_c,  fprintf('    - c) median IRF StockPrices\n'); end
    if ~ok_d,  fprintf('    - d) median FEVD StockPrices\n'); end
    if ~ok_e,  fprintf('    - e) ESS/nd\n'); end
    if ~ok_ne, fprintf('    - ne exacto\n'); end
end
fprintf('========================================================\n\n');
