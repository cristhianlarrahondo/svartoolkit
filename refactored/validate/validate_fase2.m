%VALIDATE_FASE2  Verifica reproduccion numerica exacta del modo PFA.
%
%   Ejecutar desde cualquier working directory.
%   Imprime resultados en consola; NO genera figuras ni guarda .mat.
%
%   Checks:
%     a. Ltilde(1,1,1)         - primer IRF draw 1
%     b. Ltilde(end,end,end)   - ultimo IRF ultimo draw
%     c. median(Ltilde(:,2,:), 'all') - mediana IRF stock prices
%     d. FEVD mediana stock prices a horizonte 40

fprintf('\n=======================================================\n');
fprintf(' VALIDATE FASE 2 — Modo PFA\n');
fprintf('=======================================================\n\n');

%% ── Calcular ruta raiz del proyecto ─────────────────────────────────────
val_root  = fileparts(mfilename('fullpath'));   % .../refactored/validate/
proj_root = fileparts(val_root);               % .../refactored/

%% ── Agregar paths necesarios ─────────────────────────────────────────────
addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'config'));
addpath(fullfile(proj_root, 'helpfunctions'));

%% ── Verificar ausencia de '..' en archivos src ───────────────────────────
fprintf('--- Check 0: Rutas sin ".." en src/ ---\n');
DOTDOT_PATTERN = '\.\.[/\\]';
src_files = dir(fullfile(proj_root, 'src', '*.m'));
dotdot_found = false;
for k = 1:numel(src_files)
    fpath = fullfile(src_files(k).folder, src_files(k).name);
    txt   = fileread(fpath);
    lines = strsplit(txt, newline);
    for li = 1:numel(lines)
        ln = lines{li};
        % Ignorar continuation lines (...) y comentarios
        if contains(ln, '...') || (numel(strtrim(ln))>0 && strtrim(ln)(1)=='%')
            continue;
        end
        if ~isempty(regexp(ln, DOTDOT_PATTERN, 'once'))
            fprintf('  ADVERTENCIA: ".." en %s linea %d: %s\n', src_files(k).name, li, strtrim(ln));
            dotdot_found = true;
        end
    end
end
if ~dotdot_found
    fprintf('  PASA: ningun archivo src/ usa rutas relativas con ".."\n');
end

%% ── Cargar Cfg ───────────────────────────────────────────────────────────
fprintf('\n--- Check 1: Carga de Cfg ---\n');
run(fullfile(proj_root, 'config', 'spec_bnw_pfa.m'));
fprintf('  Cfg.MODE  = %s\n', Cfg.MODE);
fprintf('  Cfg.ND    = %g\n', Cfg.ND);
fprintf('  Cfg.NLAG  = %d\n', Cfg.NLAG);
fprintf('  PASA: Cfg cargado correctamente\n');

%% ── Cargar datos ─────────────────────────────────────────────────────────
fprintf('\n--- Check 2: Dataset ---\n');
Dataset = load_data(Cfg);
fprintf('  Dataset.nvar       = %d\n', Dataset.nvar);
fprintf('  Dataset.nvar_total = %d\n', Dataset.nvar_total);
fprintf('  size(Y_raw)        = [%d x %d]\n', size(Dataset.Y_raw,1), size(Dataset.Y_raw,2));
if Dataset.nvar == 5 && Dataset.nvar_total == 5
    fprintf('  PASA: dimensiones del dataset correctas\n');
else
    fprintf('  FALLA: dimensiones inesperadas\n');
end

%% ── Construir posterior ──────────────────────────────────────────────────
fprintf('\n--- Check 3: build_posterior ---\n');
PP = build_posterior(Dataset, Cfg);
fprintf('  n=%d, p=%d, m=%d, T=%d\n', PP.n, PP.p, PP.m, PP.T);
fprintf('  nnuTilde  = %d\n', PP.nnuTilde);
fprintf('  PphiTilde(1,1) = %.10f\n', PP.PphiTilde(1,1));
fprintf('  PASA: PosteriorParams construido\n');

%% ── Run PFA con semilla fija ─────────────────────────────────────────────
fprintf('\n--- Check 4: run_pfa con rng(0) ---\n');
fprintf('  (corriendo %g draws, esperar ~2-5 min...)\n', Cfg.ND);
tic;
rng(0);
Results = run_pfa(PP, Cfg);
elapsed = toc;
fprintf('  Tiempo transcurrido: %.1f segundos\n', elapsed);

Ltilde = Results.LtildeStruct.data;
FEVD   = Results.FEVD;

%% ── Valores de verificacion ──────────────────────────────────────────────
fprintf('\n--- Valores de verificacion ---\n');

val_a = Ltilde(1, 1, 1);
val_b = Ltilde(end, end, end);
val_c = median(Ltilde(:, 2, :), 'all');
val_d = median(FEVD(2, :));     % FEVD de stock prices (var 2)

fprintf('  a. Ltilde(1,1,1)                 = %.10f\n', val_a);
fprintf('  b. Ltilde(end,end,end)           = %.10f\n', val_b);
fprintf('  c. median(Ltilde(:,2,:),all)     = %.10f\n', val_c);
fprintf('  d. median(FEVD(2,:)) @ h=40      = %.10f\n', val_d);

%% ── Checks adicionales de sanidad ────────────────────────────────────────
fprintf('\n--- Checks de sanidad ---\n');

% LtildeStruct
LS = Results.LtildeStruct;
fprintf('  LtildeStruct.mode      = %s\n', LS.mode);
fprintf('  LtildeStruct.shock_idx = %d\n', LS.shock_idx);
fprintf('  LtildeStruct.horizon   = %d\n', LS.horizon);
fprintf('  LtildeStruct.nvar      = %d\n', LS.nvar);
fprintf('  LtildeStruct.ndraws    = %d\n', LS.ndraws);
fprintf('  size(Ltilde)           = [%d %d %d]\n', size(Ltilde,1), size(Ltilde,2), size(Ltilde,3));

% Mediana stock prices en h=0 debe ser positiva (restriccion de signo)
med_sp_h0 = median(squeeze(Ltilde(1, 2, :)));
fprintf('  median(Ltilde(1,2,:)) = %.6f  [debe ser > 0]\n', med_sp_h0);
if med_sp_h0 > 0
    fprintf('  PASA: restriccion de signo satisfecha en mediana\n');
else
    fprintf('  ADVERTENCIA: mediana de stock prices en h=0 no es positiva\n');
end

% TFP en h=0 debe ser cercano a 0 (restriccion de cero)
med_tfp_h0 = median(squeeze(Ltilde(1, 1, :)));
fprintf('  median(Ltilde(1,1,:)) = %.10f  [debe ser ~0]\n', med_tfp_h0);
if abs(med_tfp_h0) < 1e-6
    fprintf('  PASA: restriccion de cero TFP satisfecha en mediana\n');
else
    fprintf('  ADVERTENCIA: TFP en h=0 no es cero (|val|=%.2e)\n', abs(med_tfp_h0));
end

fprintf('\n=======================================================\n');
fprintf(' FIN DE VALIDATE FASE 2\n');
fprintf(' Pegar este output completo en el chat para verificacion.\n');
fprintf('=======================================================\n\n');
