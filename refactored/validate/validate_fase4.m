%% validate_fase4.m — Verificación de Fase 4: Especificaciones de timing
%
% PROTOCOLO: ejecutar desde cualquier working directory.
% OUTPUT:    solo valores numéricos en consola, sin figuras ni .mat.
%
% Verificaciones:
%   [0] Rutas sin '..' prohibidos en archivos nuevos
%   [1] 4L1Z n=5: los 5 timings → patron T1<T2, T3<T2, T4<T3, T5<T4
%   [2] 4L1Z n=5: count (Timing 4) ~ 1542 ± 30%
%   [3] 4L1Z n=5: ESS/count (Timing 4) >= 0.79
%   [4] 12L3Z n=5: Timing 1 (rapido, sin pesos IS) → count ~ 2231 ± 30%
%   [5] 12L3Z n=5: Timing 4 (lento, ~5-15 min) → ESS/count >= 0.79
%       NOTA: [5] se puede saltar si el tiempo es limitado.
%
% NOTA: Los timings absolutos varían según máquina. Se verifican
%       desigualdades de orden (patron relativo), NO valores absolutos.
%       Las referencias de count son aproximadas (rng(0), seed exacta).

fprintf('\n');
fprintf('=============================================================\n');
fprintf('  VALIDATE FASE 4 - Timing specs (Tabla 4 ARW 2018)\n');
fprintf('=============================================================\n\n');

%% Localizar proyecto
validate_root = fileparts(mfilename('fullpath'));   % .../refactored/validate/
proj_root     = fileparts(validate_root);           % .../refactored/

addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'config'));
addpath(fullfile(proj_root, 'helpfunctions'));

%% ── [0] Verificacion de rutas ───────────────────────────────────────────
fprintf('[0] Verificacion de rutas...\n');
files_to_check = {
    fullfile(proj_root, 'config', 'spec_timing_4L1Z.m'),  ...
    fullfile(proj_root, 'config', 'spec_timing_12L3Z.m'), ...
    fullfile(proj_root, 'src',    'run_timing.m'),         ...
    fullfile(proj_root, 'src',    'load_data_timing.m'),   ...
};
all_routes_ok = true;
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
    lines_f   = strsplit(text, char(10));
    bad_found = false;
    for li = 1:numel(lines_f)
        ln_trim = strtrim(lines_f{li});
        if isempty(ln_trim) || ln_trim(1) == '%'; continue; end
        if ~isempty(regexp(ln_trim, '(?<!\.)\.\.(?!\.)([/\\])', 'once'))
            fprintf('  FALLO rutas: %s%s (linea %d)\n', fname, fext, li);
            bad_found     = true;
            all_routes_ok = false;
        end
    end
    if ~bad_found
        fprintf('  OK: %s%s\n', fname, fext);
    end
end
fprintf('\n');

%% ── [1] 4L1Z n=5: los 5 timings ────────────────────────────────────────
fprintf('[1] 4L1Z n=5: ejecutando 5 timings (T2 y T3 son los mas lentos)...\n\n');

t_4L5  = zeros(1, 5);
cnt_4L5 = zeros(1, 5);
ne_4L5  = zeros(1, 5);

for tv = 1:5
    fprintf('  T%d ... ', tv);
    Cfg4 = spec_timing_4L1Z();
    Cfg4.NVAR           = 5;
    Cfg4.TIMING_VARIANT = tv;
    Cfg4.ITER_SHOW      = 99999;
    D4 = load_data_timing(Cfg4);
    P4 = build_posterior(D4, Cfg4);
    R4 = run_timing(Cfg4, D4, P4);
    t_4L5(tv)   = R4.tElapsed;
    cnt_4L5(tv) = R4.count;
    ne_4L5(tv)  = R4.ne;
    fprintf('%.1f seg | count=%d | ESS=%d | ESS/count=%.4f\n', ...
        R4.tElapsed, R4.count, R4.ne, R4.ne / max(R4.count,1));
end

fprintf('\n  Timings (seg): T1=%.1f T2=%.1f T3=%.1f T4=%.1f T5=%.1f\n', ...
    t_4L5(1), t_4L5(2), t_4L5(3), t_4L5(4), t_4L5(5));

%% ── [a] Patron ──────────────────────────────────────────────────────────
fprintf('\n[a] Patron de timings:\n');
c12 = t_4L5(1) < t_4L5(2);
c32 = t_4L5(3) < t_4L5(2);
c43 = t_4L5(4) < t_4L5(3);
c54 = t_4L5(5) < t_4L5(4);
patron_ok = c12 && c32 && c43 && c54;
if c12; fprintf('  PASA  T1(%.1f) < T2(%.1f)\n', t_4L5(1), t_4L5(2));
else;   fprintf('  FALLO T1(%.1f) >= T2(%.1f)\n', t_4L5(1), t_4L5(2)); end
if c32; fprintf('  PASA  T3(%.1f) < T2(%.1f)\n', t_4L5(3), t_4L5(2));
else;   fprintf('  FALLO T3(%.1f) >= T2(%.1f)\n', t_4L5(3), t_4L5(2)); end
if c43; fprintf('  PASA  T4(%.1f) < T3(%.1f)\n', t_4L5(4), t_4L5(3));
else;   fprintf('  FALLO T4(%.1f) >= T3(%.1f)\n', t_4L5(4), t_4L5(3)); end
if c54; fprintf('  PASA  T5(%.1f) < T4(%.1f)\n', t_4L5(5), t_4L5(4));
else;   fprintf('  FALLO T5(%.1f) >= T4(%.1f)\n', t_4L5(5), t_4L5(4)); end

%% ── [2] count 4L1Z ──────────────────────────────────────────────────────
fprintf('\n[2] count 4L1Z n=5 (Timing 4):\n');
count_ref_4L = 1542;
ratio_4L     = abs(cnt_4L5(4) - count_ref_4L) / count_ref_4L;
count_ok_4L  = ratio_4L <= 0.30;
fprintf('  count=%d (ref~%d, tol+-30%%)\n', cnt_4L5(4), count_ref_4L);
if count_ok_4L; fprintf('  PASA (dif=%.1f%%)\n', ratio_4L*100);
else;           fprintf('  WARN: dif=%.1f%% (posible variacion de semilla)\n', ratio_4L*100); end

%% ── [3] ESS/count 4L1Z ──────────────────────────────────────────────────
fprintf('\n[3] ESS/count 4L1Z n=5 (Timing 4):\n');
ess_r_4L = ne_4L5(4) / max(cnt_4L5(4), 1);
ess_ok_4L = ess_r_4L >= 0.79;
fprintf('  ESS=%d count=%d ESS/count=%.4f (ref>=0.79)\n', ne_4L5(4), cnt_4L5(4), ess_r_4L);
if ess_ok_4L; fprintf('  PASA\n');
else;         fprintf('  FALLO *** ESS/count=%.4f < 0.79 ***\n', ess_r_4L); end

%% ── [4] 12L3Z n=5: Timing 1 (rapido, para verificar count) ─────────────
fprintf('\n[4] 12L3Z n=5: Timing 1 (rapido, sin pesos IS)...\n');
Cfg12_T1 = spec_timing_12L3Z();
Cfg12_T1.NVAR           = 5;
Cfg12_T1.TIMING_VARIANT = 1;
Cfg12_T1.ITER_SHOW      = 99999;
D12 = load_data_timing(Cfg12_T1);
P12 = build_posterior(D12, Cfg12_T1);
R12_T1 = run_timing(Cfg12_T1, D12, P12);

count_ref_12 = 2231;
ratio_12     = abs(R12_T1.count - count_ref_12) / count_ref_12;
count_ok_12  = ratio_12 <= 0.30;
fprintf('  T1: %.1f seg | count=%d (ref~%d, tol+-30%%)\n', ...
    R12_T1.tElapsed, R12_T1.count, count_ref_12);
if count_ok_12; fprintf('  PASA (dif=%.1f%%)\n', ratio_12*100);
else;           fprintf('  WARN: dif=%.1f%%\n', ratio_12*100); end

%% ── [5] 12L3Z n=5: Timing 4 (lento, ESS) ───────────────────────────────
fprintf('\n[5] 12L3Z n=5: Timing 4 (puede tardar 5-15 min)...\n');
Cfg12_T4 = spec_timing_12L3Z();
Cfg12_T4.NVAR           = 5;
Cfg12_T4.TIMING_VARIANT = 4;
Cfg12_T4.ITER_SHOW      = 99999;
R12_T4 = run_timing(Cfg12_T4, D12, P12);   % reutiliza D12, P12

ess_r_12 = R12_T4.ne / max(R12_T4.count, 1);
ess_ok_12 = ess_r_12 >= 0.79;
fprintf('  T4: %.1f seg | count=%d | ESS=%d | ESS/count=%.4f\n', ...
    R12_T4.tElapsed, R12_T4.count, R12_T4.ne, ess_r_12);
if ess_ok_12; fprintf('  PASA (ESS/count>=0.79)\n');
else;         fprintf('  FALLO *** ESS/count=%.4f < 0.79 ***\n', ess_r_12); end

%% ── RESUMEN FINAL ────────────────────────────────────────────────────────
fprintf('\n=============================================================\n');
fprintf('  RESUMEN VALIDATE FASE 4\n');
fprintf('=============================================================\n');
all_pass = all_routes_ok && patron_ok && count_ok_4L && ess_ok_4L && count_ok_12 && ess_ok_12;
if all_routes_ok; fprintf('  [OK]   [0] Rutas\n');
else;              fprintf('  [FAIL] [0] Rutas con relativas prohibidas\n'); end
if patron_ok; fprintf('  [OK]   [a] Patron T1<T2, T3<T2, T4<T3, T5<T4\n');
else;         fprintf('  [FAIL] [a] Patron de timings\n'); end
if count_ok_4L; fprintf('  [OK]   [2] count 4L1Z=%d (ref~%d)\n', cnt_4L5(4), count_ref_4L);
else;           fprintf('  [WARN] [2] count 4L1Z=%d (ref~%d, dif=%.0f%%)\n', cnt_4L5(4), count_ref_4L, ratio_4L*100); end
if ess_ok_4L;  fprintf('  [OK]   [3] ESS/count 4L1Z =%.4f\n', ess_r_4L);
else;          fprintf('  [FAIL] [3] ESS/count 4L1Z =%.4f < 0.79\n', ess_r_4L); end
if count_ok_12; fprintf('  [OK]   [4] count 12L3Z=%d (ref~%d)\n', R12_T1.count, count_ref_12);
else;           fprintf('  [WARN] [4] count 12L3Z=%d (ref~%d, dif=%.0f%%)\n', R12_T1.count, count_ref_12, ratio_12*100); end
if ess_ok_12;  fprintf('  [OK]   [5] ESS/count 12L3Z=%.4f\n', ess_r_12);
else;          fprintf('  [FAIL] [5] ESS/count 12L3Z=%.4f < 0.79\n', ess_r_12); end
fprintf('\n');
if all_pass; fprintf('  *** FASE 4 PASA ***\n');
else;        fprintf('  *** FASE 4 CON OBSERVACIONES ***\n'); end
fprintf('=============================================================\n\n');
