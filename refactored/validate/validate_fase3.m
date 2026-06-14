%VALIDATE_FASE3  Verificacion numerica del modo IS (Fase 3).
%
%   Ejecutar desde cualquier working directory.
%   Compara contra valores de referencia del original con rng(0).
%
%   Checks:
%     a) Ltilde(1,1,1,1)                          — primer elemento 4D
%     b) Ltilde(end,end,end,end)                  — ultimo elemento
%     c) median(squeeze(Ltilde(:,2,1,:)), 'all')  — mediana IRF stock prices al shock 1
%     d) FEVD mediana stock prices a horizonte 40
%     e) ESS / nd                                 — fraccion de draws efectivos
%
%   Tolerancia: 1e-10 para comparacion con referencias.

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

%% ── Calcular metricas ───────────────────────────────────────────────────

% a) Primer elemento 4D
val_a = Ltilde(1, 1, 1, 1);

% b) Ultimo elemento 4D
val_b = Ltilde(end, end, end, end);

% c) Mediana IRF stock prices (variable 2) al shock 1 (optimismo), todos horizontes
%    Ltilde(:, 2, 1, :) => variable 2, shock 1
slice_c = squeeze(Ltilde(:, 2, 1, :));   % [horizon+1, ne]
val_c   = median(slice_c, 'all');

% d) Mediana FEVD stock prices a horizonte 40
%    FEVD(2, :) = contribucion al stock prices
val_d = median(FEVD(2, :));

% e) ESS / nd
val_e = ne / nd;

%% ── Imprimir resultados ──────────────────────────────────────────────────
fprintf('------ Metricas de verificacion ------\n');
fprintf('a) Ltilde(1,1,1,1)                         = %.10f\n', val_a);
fprintf('b) Ltilde(end,end,end,end)                  = %.10f\n', val_b);
fprintf('c) median(Ltilde(:,2,1,:), all)             = %.10f\n', val_c);
fprintf('d) median(FEVD(2,:)) @ h=40                 = %.10f\n', val_d);
fprintf('e) ESS/nd  (ne=%d / nd=%d)              = %.6f\n', ne, nd, val_e);
fprintf('\n');

%% ── Informacion adicional de tamano ─────────────────────────────────────
fprintf('------ Tamanos de arrays ------\n');
fprintf('size(Ltilde)  = [%d %d %d %d]\n', size(Ltilde, 1), size(Ltilde, 2), ...
                                             size(Ltilde, 3), size(Ltilde, 4));
fprintf('size(FEVD)    = [%d %d]\n', size(FEVD, 1), size(FEVD, 2));
fprintf('ne (ESS)      = %d\n', ne);
fprintf('nd            = %d\n', nd);
fprintf('\n');

%% ── Verificacion de signo en h=0 (restriccion de identificacion) ─────────
% Mediana de Ltilde(1, 2, 1, :) debe ser > 0 (stock prices > 0)
median_sp_h0 = median(squeeze(Ltilde(1, 2, 1, :)));
% Mediana de Ltilde(1, 1, 1, :) debe ser ~ 0 (TFP ~ 0 por zero restriction)
median_tfp_h0 = median(squeeze(Ltilde(1, 1, 1, :)));
fprintf('------ Verificacion de restricciones de identificacion ------\n');
fprintf('median(Ltilde(1,2,1,:)) [StockPrices h=0] = %.10f  (debe ser > 0)\n', median_sp_h0);
fprintf('median(Ltilde(1,1,1,:)) [TFP h=0]         = %.10f  (debe ser ~ 0)\n', median_tfp_h0);
fprintf('\n');

%% ── Diagnostico de pesos IS ─────────────────────────────────────────────
n_signs = sum(Results.uw > 0);
fprintf('------ Diagnostico pesos IS ------\n');
fprintf('Draws satisfaciendo sign restrictions = %d / %d  (%.1f%%)\n', ...
    n_signs, nd, 100*n_signs/nd);
fprintf('ESS como fraccion de sign-draws       = %.4f\n', ne / n_signs);
fprintf('\n');

%% ── Valores de referencia del paper (ARW 2018, Tabla III) ───────────────
% FEVD mediana stock prices @ h=40 con IS = 0.26
% FEVD mediana consumption @ h=40 con IS = 0.16
% FEVD mediana hours @ h=40 con IS = 0.17
fprintf('------ Referencia ARW (2018), Tabla III (IS) ------\n');
fprintf('FEVD median TFP       @ h=40: calculado=%.4f  (paper: ~0.10)\n', median(FEVD(1,:)));
fprintf('FEVD median StockP    @ h=40: calculado=%.4f  (paper: ~0.26)\n', median(FEVD(2,:)));
fprintf('FEVD median Cons      @ h=40: calculado=%.4f  (paper: ~0.16)\n', median(FEVD(3,:)));
fprintf('FEVD median RealRate  @ h=40: calculado=%.4f  (paper: ~0.19)\n', median(FEVD(4,:)));
fprintf('FEVD median Hours     @ h=40: calculado=%.4f  (paper: ~0.17)\n', median(FEVD(5,:)));
fprintf('\n');

fprintf('========================================================\n');
fprintf('  validate_fase3.m COMPLETADO\n');
fprintf('========================================================\n\n');
