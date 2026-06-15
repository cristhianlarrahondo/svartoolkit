%% validate_fase4.m — Verificación de Fase 4: Especificaciones de timing
%
% PROTOCOLO: ejecutar desde cualquier working directory.
% OUTPUT:    solo valores numéricos en consola, sin figuras ni .mat.
%
% Verificaciones:
%   (a) Patron de timings: T1 < T2, T3 < T2, T4 < T3, T5 < T4
%   (b) Draws satisfaciendo signs ~ 1542 (4L1Z n=5) y ~ 2231 (12L3Z n=5)
%   (c) ESS/count >= 0.79
%
% NOTA: Los timings absolutos varían según máquina. Se verifican
%       desigualdades de orden, NO valores absolutos.

fprintf('\n');
fprintf('=============================================================\n');
fprintf('  VALIDATE FASE 4 — Timing specs (Tabla 4 ARW 2018)\n');
fprintf('=============================================================\n\n');

%% ── Localizar proyecto ──────────────────────────────────────────────────
validate_root = fileparts(mfilename('fullpath'));   % .../refactored/validate/
proj_root     = fileparts(validate_root);           % .../refactored/

%% ── Añadir paths ────────────────────────────────────────────────────────
addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'config'));
addpath(fullfile(proj_root, 'helpfunctions'));

%% ── [0] Verificación de rutas (sin '..' prohibido) ─────────────────────
fprintf('[0] Verificacion de rutas en archivos nuevos...\n');
files_to_check = {
    fullfile(proj_root, 'config', 'spec_timing_4L1Z.m'),  ...
    fullfile(proj_root, 'config', 'spec_timing_12L3Z.m'), ...
    fullfile(proj_root, 'src',    'run_timing.m'),         ...
    fullfile(proj_root, 'src',    'load_data_timing.m'),   ...
};
DOTDOT_PATTERN = '\.\.[/\\]';
all_routes_ok  = true;
for fi = 1:numel(files_to_check)
    fpath = files_to_check{fi};
    [~, fname, fext] = fileparts(fpath);
    if ~isfile(fpath)
        fprintf('  FALTA: %s%s\n', fname, fext);
        all_routes_ok = false;
        continue;
    end
    fid  = fopen(fpath, 'r');
    text = fread(fid, '*char')';
    fclose(fid);
    lines_f = strsplit(text, char(10));
    bad_lines = {};
    for li = 1:numel(lines_f)
        ln_trim = strtrim(lines_f{li});
        if isempty(ln_trim) || ln_trim(1) == '%'
            continue;
        end
        % Prohibido: '..' seguido de / o \ que no sea parte de '...'
        if ~isempty(regexp(ln_trim, '(?<!\.)\.\.(?!\.)([/\\])', 'once'))
            bad_lines{end+1} = sprintf('    linea %d: %s', li, ln_trim); %#ok
        end
    end
    if isempty(bad_lines)
        fprintf('  OK rutas: %s%s\n', fname, fext);
    else
        fprintf('  FALLO rutas en %s%s:\n', fname, fext);
        for bi = 1:numel(bad_lines)
            fprintf('%s\n', bad_lines{bi});
        end
        all_routes_ok = false;
    end
end
fprintf('\n');

%% ── [1] CASO 4L1Z, n=5: los 5 timings ──────────────────────────────────
fprintf('[1] Caso 4L1Z n=5: ejecutando los 5 timings...\n');
fprintf('    (T2 y T3 son los mas lentos; T1,T4,T5 son rapidos)\n\n');

t_elapsed_4L5 = zeros(1, 5);
count_4L5     = zeros(1, 5);
ne_4L5        = zeros(1, 5);

for tv = 1:5
    fprintf('  Ejecutando Timing %d / 4L1Z n=5 ... ', tv);
    Cfg4 = spec_timing_4L1Z();
    Cfg4.NVAR           = 5;
    Cfg4.TIMING_VARIANT = tv;
    Cfg4.ITER_SHOW      = 99999;
    Dataset4   = load_data_timing(Cfg4);
    Posterior4 = build_posterior(Dataset4, Cfg4);
    Res = run_timing(Cfg4, Dataset4, Posterior4);
    t_elapsed_4L5(tv) = Res.tElapsed;
    count_4L5(tv)     = Res.count;
    ne_4L5(tv)        = Res.ne;
    fprintf('%.1f seg | count=%d | ESS=%d\n', Res.tElapsed, Res.count, Res.ne);
end

fprintf('\n  Timings absolutos 4L1Z n=5 (seg):\n');
fprintf('    T1=%.1f  T2=%.1f  T3=%.1f  T4=%.1f  T5=%.1f\n', ...
    t_elapsed_4L5(1), t_elapsed_4L5(2), t_elapsed_4L5(3), ...
    t_elapsed_4L5(4), t_elapsed_4L5(5));

%% ── [a] Patron de timings ───────────────────────────────────────────────
fprintf('\n[a] Verificacion patron de timings (4L1Z n=5):\n');

check_T1_T2 = t_elapsed_4L5(1) < t_elapsed_4L5(2);
check_T3_T2 = t_elapsed_4L5(3) < t_elapsed_4L5(2);
check_T4_T3 = t_elapsed_4L5(4) < t_elapsed_4L5(3);
check_T5_T4 = t_elapsed_4L5(5) < t_elapsed_4L5(4);
patron_ok   = check_T1_T2 && check_T3_T2 && check_T4_T3 && check_T5_T4;

if check_T1_T2
    fprintf('  PASA  T1 < T2  (%.1f < %.1f)\n', t_elapsed_4L5(1), t_elapsed_4L5(2));
else
    fprintf('  FALLO T1 < T2  (%.1f >= %.1f)\n', t_elapsed_4L5(1), t_elapsed_4L5(2));
end
if check_T3_T2
    fprintf('  PASA  T3 < T2  (%.1f < %.1f)\n', t_elapsed_4L5(3), t_elapsed_4L5(2));
else
    fprintf('  FALLO T3 < T2  (%.1f >= %.1f)\n', t_elapsed_4L5(3), t_elapsed_4L5(2));
end
if check_T4_T3
    fprintf('  PASA  T4 < T3  (%.1f < %.1f)\n', t_elapsed_4L5(4), t_elapsed_4L5(3));
else
    fprintf('  FALLO T4 < T3  (%.1f >= %.1f)\n', t_elapsed_4L5(4), t_elapsed_4L5(3));
end
if check_T5_T4
    fprintf('  PASA  T5 < T4  (%.1f < %.1f)\n', t_elapsed_4L5(5), t_elapsed_4L5(4));
else
    fprintf('  FALLO T5 < T4  (%.1f >= %.1f)\n', t_elapsed_4L5(5), t_elapsed_4L5(4));
end

%% ── [b1] Count para 4L1Z n=5 ───────────────────────────────────────────
fprintf('\n[b1] Draws satisfaciendo signs (4L1Z n=5, Timing 4):\n');
count_T4_4L5 = count_4L5(4);
count_ref_4L = 1542;
tol_count    = 0.30;
ratio_4L     = abs(count_T4_4L5 - count_ref_4L) / count_ref_4L;
count_ok_4L  = ratio_4L <= tol_count;
fprintf('  count = %d  (referencia: ~%d, tolerancia +-30%%)\n', ...
    count_T4_4L5, count_ref_4L);
if count_ok_4L
    fprintf('  PASA (diferencia: %.1f%%)\n', ratio_4L*100);
else
    fprintf('  ADVERTENCIA: diferencia %.1f%% (puede variar con semilla/version)\n', ratio_4L*100);
end

%% ── [c1] ESS/count para 4L1Z n=5 ───────────────────────────────────────
fprintf('\n[c1] ESS/count (4L1Z n=5, Timing 4):\n');
ess_ratio_4L = ne_4L5(4) / max(count_4L5(4), 1);
ess_ref      = 0.79;
ess_ok_4L    = ess_ratio_4L >= ess_ref;
fprintf('  ESS = %d | count = %d | ESS/count = %.4f  (ref: >= %.2f)\n', ...
    ne_4L5(4), count_4L5(4), ess_ratio_4L, ess_ref);
if ess_ok_4L
    fprintf('  PASA\n');
else
    fprintf('  FALLO *** ESS/count = %.4f < %.2f ***\n', ess_ratio_4L, ess_ref);
end

%% ── [2] CASO 12L3Z, n=5, Timing 4 ─────────────────────────────────────
fprintf('\n[2] Caso 12L3Z n=5: ejecutando Timing 4...\n');
fprintf('    (puede tardar varios minutos)\n\n');

Cfg12 = spec_timing_12L3Z();
Cfg12.NVAR           = 5;
Cfg12.TIMING_VARIANT = 4;
Cfg12.ITER_SHOW      = 99999;

Dataset12   = load_data_timing(Cfg12);
Posterior12 = build_posterior(Dataset12, Cfg12);
Res12       = run_timing(Cfg12, Dataset12, Posterior12);

fprintf('  tElapsed : %.1f seg\n', Res12.tElapsed);
fprintf('  count    : %d\n',       Res12.count);
fprintf('  ESS      : %d\n',       Res12.ne);
fprintf('  ESS/count: %.4f\n',     Res12.ne / max(Res12.count, 1));

%% ── [b2] Count para 12L3Z n=5 ──────────────────────────────────────────
fprintf('\n[b2] Draws satisfaciendo signs (12L3Z n=5, Timing 4):\n');
count_ref_12  = 2231;
ratio_12      = abs(Res12.count - count_ref_12) / count_ref_12;
count_ok_12   = ratio_12 <= tol_count;
fprintf('  count = %d  (referencia: ~%d, tolerancia +-30%%)\n', ...
    Res12.count, count_ref_12);
if count_ok_12
    fprintf('  PASA (diferencia: %.1f%%)\n', ratio_12*100);
else
    fprintf('  ADVERTENCIA: diferencia %.1f%%\n', ratio_12*100);
end

%% ── [c2] ESS/count para 12L3Z n=5 ─────────────────────────────────────
fprintf('\n[c2] ESS/count (12L3Z n=5, Timing 4):\n');
ess_ratio_12 = Res12.ne / max(Res12.count, 1);
ess_ok_12    = ess_ratio_12 >= ess_ref;
fprintf('  ESS/count = %.4f  (ref: >= %.2f)\n', ess_ratio_12, ess_ref);
if ess_ok_12
    fprintf('  PASA\n');
else
    fprintf('  FALLO *** ESS/count = %.4f < %.2f ***\n', ess_ratio_12, ess_ref);
end

%% ── RESUMEN FINAL ────────────────────────────────────────────────────────
fprintf('\n=============================================================\n');
fprintf('  RESUMEN VALIDATE FASE 4\n');
fprintf('=============================================================\n');
all_pass = all_routes_ok && patron_ok && count_ok_4L && ess_ok_4L && ess_ok_12;
if all_routes_ok; fprintf('  [OK]   Rutas sin relativas prohibidas\n');
else;              fprintf('  [FAIL] Rutas: hay rutas relativas prohibidas\n'); end
if patron_ok; fprintf('  [OK]   (a) Patron T1<T2, T3<T2, T4<T3, T5<T4\n');
else;         fprintf('  [FAIL] (a) Patron de timings\n'); end
if count_ok_4L; fprintf('  [OK]   (b1) count 4L1Z=%d  (ref~%d)\n', count_T4_4L5, count_ref_4L);
else;           fprintf('  [WARN] (b1) count 4L1Z=%d  (ref~%d, dif=%.0f%%)\n', ...
                    count_T4_4L5, count_ref_4L, ratio_4L*100); end
if count_ok_12; fprintf('  [OK]   (b2) count 12L3Z=%d (ref~%d)\n', Res12.count, count_ref_12);
else;           fprintf('  [WARN] (b2) count 12L3Z=%d (ref~%d, dif=%.0f%%)\n', ...
                    Res12.count, count_ref_12, ratio_12*100); end
if ess_ok_4L;  fprintf('  [OK]   (c1) ESS/count 4L1Z  = %.4f\n', ess_ratio_4L);
else;          fprintf('  [FAIL] (c1) ESS/count 4L1Z  = %.4f < 0.79\n', ess_ratio_4L); end
if ess_ok_12;  fprintf('  [OK]   (c2) ESS/count 12L3Z = %.4f\n', ess_ratio_12);
else;          fprintf('  [FAIL] (c2) ESS/count 12L3Z = %.4f < 0.79\n', ess_ratio_12); end
fprintf('\n');
if all_pass
    fprintf('  *** FASE 4 PASA ***\n');
else
    fprintf('  *** FASE 4 CON OBSERVACIONES (revisar items [FAIL] arriba) ***\n');
end
fprintf('=============================================================\n\n');
