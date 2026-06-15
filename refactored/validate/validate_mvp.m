%VALIDATE_MVP  MVP Checkpoint — verifica reproducción numérica exacta de
%              spec_bnw_pfa (Fase 2) y spec_bnw_is (Fase 3) antes de
%              comenzar cualquier extensión de Fase 5.
%
%   Ejecutar desde cualquier working directory.
%   Imprime resultados en consola; NO genera figuras ni guarda .mat.
%
%   Checks PFA (spec_bnw_pfa, rng(0)):
%     P-a) Ltilde(1,1,1)                    = 0.0000000000
%     P-b) Ltilde(end,end,end)              = -0.2164638261
%     P-c) median(Ltilde(:,2,:),'all')      = 4.0563832215
%     P-d) median(FEVD(2,:)) @ h=40        = 0.4356588899
%
%   Checks IS (spec_bnw_is, rng(0)):
%     I-a) Ltilde(1,1,1,1)                  = 0.0000000000
%     I-b) Ltilde(end,end,end,end)          = 0.2041864191
%     I-c) median(Ltilde(:,2,1,:),'all')    = 2.9521795528
%     I-d) median(FEVD(2,:)) @ h=40        = 0.2580366201
%     I-e) ESS/nd                           = 0.389133
%     I-f) ne exacto                        = 11674
%
%   Tolerancias: 1e-6 para IRFs/FEVD; exacto para ne.

fprintf('\n')
fprintf('╔══════════════════════════════════════════════════════╗\n');
fprintf('║        VALIDATE MVP — SVAR Toolkit Checkpoint       ║\n');
fprintf('║        Fases 2 (PFA) + 3 (IS)   con rng(0)         ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n\n');

%% ── Rutas absolutas ──────────────────────────────────────────────────────
val_root  = fileparts(mfilename('fullpath'));   % .../refactored/validate/
proj_root = fileparts(val_root);               % .../refactored/
src_dir   = fullfile(proj_root, 'src');
cfg_dir   = fullfile(proj_root, 'config');
help_dir  = fullfile(proj_root, 'helpfunctions');

addpath(src_dir);
addpath(cfg_dir);
addpath(help_dir);

%% ── Tolerancias y helper de veredicto ───────────────────────────────────
TOL_irf  = 1e-6;
TOL_ess  = 1e-6;
V = {'FAIL', 'OK  '};    % V{1}=FAIL, V{2}=OK  (indexado con ok+1)

%% ── Check 0: Rutas sin ".." en src/ ─────────────────────────────────────
fprintf('━━━ Check 0: Rutas sin ".." en src/ ━━━━━━━━━━━━━━━━━\n');
DOTDOT_PATTERN = '\.\.[/\\]';
src_files = dir(fullfile(src_dir, '*.m'));
dotdot_found = false;
for k = 1:numel(src_files)
    fpath = fullfile(src_files(k).folder, src_files(k).name);
    txt   = fileread(fpath);
    lines = strsplit(txt, newline);
    for li = 1:numel(lines)
        ln     = lines{li};
        ln_trim = strtrim(ln);
        if contains(ln, '...') || (~isempty(ln_trim) && ln_trim(1) == '%')
            continue;
        end
        if ~isempty(regexp(ln, DOTDOT_PATTERN, 'once'))
            fprintf('  ADVERTENCIA: ".." en %s línea %d: %s\n', ...
                src_files(k).name, li, strtrim(ln));
            dotdot_found = true;
        end
    end
end
if ~dotdot_found
    fprintf('  OK  — ningún archivo src/ usa rutas relativas con ".."\n');
end

% =========================================================================
%  BLOQUE PFA
% =========================================================================
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════╗\n');
fprintf('║   BLOQUE PFA — spec_bnw_pfa                         ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n');

%% ── Cargar Cfg PFA ───────────────────────────────────────────────────────
fprintf('\n━━━ Check P-1: Carga de Cfg PFA ━━━━━━━━━━━━━━━━━━━━━━\n');
Cfg = struct();
run(fullfile(cfg_dir, 'spec_bnw_pfa.m'));
Cfg.PLOT_IRFS   = false;    % sin figuras
Cfg.SAVE_RESULTS = false;
fprintf('  Cfg.MODE = %s | Cfg.ND = %g | Cfg.SEED = %d\n', ...
    Cfg.MODE, Cfg.ND, Cfg.SEED);

%% ── Datos y posterior PFA ────────────────────────────────────────────────
fprintf('\n━━━ Check P-2: Dataset + Posterior ━━━━━━━━━━━━━━━━━━━━\n');
Dataset_pfa  = load_data(Cfg);
Posterior_pfa = build_posterior(Dataset_pfa, Cfg);
fprintf('  n=%d, p=%d, m=%d, T=%d  |  PphiTilde(1,1)=%.10f\n', ...
    Posterior_pfa.n, Posterior_pfa.p, Posterior_pfa.m, Posterior_pfa.T, ...
    Posterior_pfa.PphiTilde(1,1));

%% ── Run PFA con rng(0) ───────────────────────────────────────────────────
fprintf('\n━━━ Check P-3: run_pfa con rng(0) ━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  Corriendo %g draws PFA (esperar ~1-3 min)...\n', Cfg.ND);
rng(0);
tic;
Results_pfa = run_pfa(Posterior_pfa, Cfg);
t_pfa = toc;
fprintf('  Tiempo: %.1f seg\n', t_pfa);

%% ── Métricas PFA ─────────────────────────────────────────────────────────
Ltilde_pfa = Results_pfa.LtildeStruct.data;   % [41, 5, 10000]
FEVD_pfa   = Results_pfa.FEVD;                 % [5, 10000]

val_pa = Ltilde_pfa(1, 1, 1);
val_pb = Ltilde_pfa(end, end, end);
val_pc = median(Ltilde_pfa(:, 2, :), 'all');
val_pd = median(FEVD_pfa(2, :));

REF_pa =  0.0000000000;
REF_pb = -0.2164638261;
REF_pc =  4.0563832215;
REF_pd =  0.4356588899;

ok_pa = abs(val_pa - REF_pa) <= TOL_irf;
ok_pb = abs(val_pb - REF_pb) <= TOL_irf;
ok_pc = abs(val_pc - REF_pc) <= TOL_irf;
ok_pd = abs(val_pd - REF_pd) <= TOL_irf;

fprintf('\n━━━ Métricas PFA ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('                               Calculado          Referencia         Status\n');
fprintf('  P-a) Ltilde(1,1,1)        = %.10f   %.10f   %s\n', val_pa, REF_pa, V{int32(ok_pa)+1});
fprintf('  P-b) Ltilde(end,end,end)  = %.10f   %.10f   %s\n', val_pb, REF_pb, V{int32(ok_pb)+1});
fprintf('  P-c) median(Lt(:,2,:))   = %.10f   %.10f   %s\n',  val_pc, REF_pc, V{int32(ok_pc)+1});
fprintf('  P-d) median(FEVD(2,:))   = %.10f   %.10f   %s\n',  val_pd, REF_pd, V{int32(ok_pd)+1});

% Checks de identificación
med_sp_pfa  = median(squeeze(Ltilde_pfa(1, 2, :)));
med_tfp_pfa = median(squeeze(Ltilde_pfa(1, 1, :)));
ok_psign = med_sp_pfa > 0;
ok_pzero = abs(med_tfp_pfa) < 1e-6;
fprintf('\n  median(Lt(1,2,:)) [SP  h=0] = %.6f   (>0: %s)\n', med_sp_pfa,  V{int32(ok_psign)+1});
fprintf('  median(Lt(1,1,:)) [TFP h=0] = %.10f  (~0: %s)\n',  med_tfp_pfa, V{int32(ok_pzero)+1});

pfa_pasa = ok_pa && ok_pb && ok_pc && ok_pd && ok_psign && ok_pzero;
fprintf('\n');
if pfa_pasa
    fprintf('  ✓ SPEC BNW PFA: PASA\n');
else
    fprintf('  ✗ SPEC BNW PFA: NO PASA\n');
    if ~ok_pa, fprintf('      - P-a) Ltilde(1,1,1)\n'); end
    if ~ok_pb, fprintf('      - P-b) Ltilde(end,end,end)\n'); end
    if ~ok_pc, fprintf('      - P-c) median IRF StockPrices\n'); end
    if ~ok_pd, fprintf('      - P-d) median FEVD StockPrices\n'); end
end

% =========================================================================
%  BLOQUE IS
% =========================================================================
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════╗\n');
fprintf('║   BLOQUE IS — spec_bnw_is                           ║\n');
fprintf('╚══════════════════════════════════════════════════════╝\n');

%% ── Cargar Cfg IS ────────────────────────────────────────────────────────
fprintf('\n━━━ Check I-1: Carga de Cfg IS ━━━━━━━━━━━━━━━━━━━━━━━\n');
Cfg = struct();
run(fullfile(cfg_dir, 'spec_bnw_is.m'));
Cfg.PLOT_IRFS    = false;
Cfg.SAVE_RESULTS = false;
fprintf('  Cfg.MODE = %s | Cfg.ND = %g | Cfg.SEED = %d\n', ...
    Cfg.MODE, Cfg.ND, Cfg.SEED);

%% ── Datos y posterior IS ─────────────────────────────────────────────────
fprintf('\n━━━ Check I-2: Dataset + Posterior ━━━━━━━━━━━━━━━━━━━━\n');
Dataset_is   = load_data(Cfg);
Posterior_is = build_posterior(Dataset_is, Cfg);
fprintf('  n=%d, p=%d, m=%d, T=%d  |  PphiTilde(1,1)=%.10f\n', ...
    Posterior_is.n, Posterior_is.p, Posterior_is.m, Posterior_is.T, ...
    Posterior_is.PphiTilde(1,1));

%% ── Run IS con rng(0) ────────────────────────────────────────────────────
fprintf('\n━━━ Check I-3: run_is con rng(0) ━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('  Corriendo IS (nd=%g, maxdraws=%g, esperar ~10-15 min)...\n', ...
    Cfg.ND, Cfg.MAX_IS_DRAWS);
rng('default');
rng(0);
tic;
Results_is = run_is(Posterior_is, Cfg);
t_is = toc;
fprintf('  Tiempo: %.1f seg\n', t_is);

%% ── Métricas IS ──────────────────────────────────────────────────────────
Ltilde_is = Results_is.LtildeStruct.data;   % [41, 5, 5, ne]
FEVD_is   = Results_is.FEVD;                 % [5, ne]
ne_is     = Results_is.ne;
nd_is     = Cfg.ND;

val_ia = Ltilde_is(1, 1, 1, 1);
val_ib = Ltilde_is(end, end, end, end);
val_ic = median(squeeze(Ltilde_is(:, 2, 1, :)), 'all');
val_id = median(FEVD_is(2, :));
val_ie = ne_is / nd_is;

REF_ia = 0.0000000000;
REF_ib = 0.2041864191;
REF_ic = 2.9521795528;
REF_id = 0.2580366201;
REF_ie = 0.389133;
REF_ne = 11674;

ok_ia = abs(val_ia - REF_ia) <= TOL_irf;
ok_ib = abs(val_ib - REF_ib) <= TOL_irf;
ok_ic = abs(val_ic - REF_ic) <= TOL_irf;
ok_id = abs(val_id - REF_id) <= TOL_irf;
ok_ie = abs(val_ie - REF_ie) <= TOL_ess;
ok_ne = (ne_is == REF_ne);

fprintf('\n━━━ Métricas IS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('                                  Calculado          Referencia         Status\n');
fprintf('  I-a) Ltilde(1,1,1,1)         = %.10f   %.10f   %s\n', val_ia, REF_ia, V{int32(ok_ia)+1});
fprintf('  I-b) Ltilde(end,end,end,end) = %.10f   %.10f   %s\n', val_ib, REF_ib, V{int32(ok_ib)+1});
fprintf('  I-c) median(Lt(:,2,1,:))    = %.10f   %.10f   %s\n',  val_ic, REF_ic, V{int32(ok_ic)+1});
fprintf('  I-d) median(FEVD(2,:))      = %.10f   %.10f   %s\n',  val_id, REF_id, V{int32(ok_id)+1});
fprintf('  I-e) ESS/nd                  = %.6f       %.6f       %s\n', val_ie, REF_ie, V{int32(ok_ie)+1});
fprintf('  I-f) ne exacto               = %d             %d             %s\n', ne_is, REF_ne, V{int32(ok_ne)+1});

% Checks de identificación IS
med_sp_is  = median(squeeze(Ltilde_is(1, 2, 1, :)));
med_tfp_is = median(squeeze(Ltilde_is(1, 1, 1, :)));
ok_isign = med_sp_is > 0;
ok_izero = abs(med_tfp_is) < 1e-8;
fprintf('\n  median(Lt(1,2,1,:)) [SP  h=0] = %.6f   (>0: %s)\n', med_sp_is,  V{int32(ok_isign)+1});
fprintf('  median(Lt(1,1,1,:)) [TFP h=0] = %.10f  (~0: %s)\n',  med_tfp_is, V{int32(ok_izero)+1});

% Diagnóstico IS
n_signs  = sum(Results_is.uw > 0);
ess_sign = ne_is / n_signs;
fprintf('\n  Draws satisfaciendo signo = %d / %d  (%.1f%%)\n', ...
    n_signs, nd_is, 100*n_signs/nd_is);
fprintf('  ESS/sign-draws            = %.6f  (ref: 0.780035)\n', ess_sign);

is_pasa = ok_ia && ok_ib && ok_ic && ok_id && ok_ie && ok_ne && ok_isign && ok_izero;
fprintf('\n');
if is_pasa
    fprintf('  ✓ SPEC BNW IS: PASA\n');
else
    fprintf('  ✗ SPEC BNW IS: NO PASA\n');
    if ~ok_ia, fprintf('      - I-a) Ltilde(1,1,1,1)\n'); end
    if ~ok_ib, fprintf('      - I-b) Ltilde(end,end,end,end)\n'); end
    if ~ok_ic, fprintf('      - I-c) median IRF StockPrices\n'); end
    if ~ok_id, fprintf('      - I-d) median FEVD StockPrices\n'); end
    if ~ok_ie, fprintf('      - I-e) ESS/nd\n'); end
    if ~ok_ne, fprintf('      - I-f) ne exacto\n'); end
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('\n');
fprintf('╔══════════════════════════════════════════════════════╗\n');
fprintf('║              VEREDICTO GLOBAL MVP                   ║\n');
fprintf('╠══════════════════════════════════════════════════════╣\n');
fprintf('║  spec_bnw_pfa : %-38s║\n', iif(pfa_pasa, 'PASA', 'NO PASA'));
fprintf('║  spec_bnw_is  : %-38s║\n', iif(is_pasa,  'PASA', 'NO PASA'));
fprintf('╠══════════════════════════════════════════════════════╣\n');
if pfa_pasa && is_pasa
    fprintf('║  GLOBAL       : PASA — baseline MVP confirmado       ║\n');
else
    fprintf('║  GLOBAL       : NO PASA — revisar checks fallidos     ║\n');
end
fprintf('╚══════════════════════════════════════════════════════╝\n');
fprintf('\nTiempo total: PFA=%.1f seg | IS=%.1f seg | Total=%.1f seg\n\n', ...
    t_pfa, t_is, t_pfa + t_is);
fprintf('Pegar este output completo en el chat para verificación.\n\n');


%% ── Helper local ─────────────────────────────────────────────────────────
function out = iif(cond, a, b)
    if cond; out = a; else; out = b; end
end
