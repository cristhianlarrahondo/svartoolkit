%VALIDATE_RESTRICCIONES_PFA_IS  Validación Tipo R — ingesta de Cfg.S/Cfg.Z
%en PFA e IS, generalización multi-horizonte, y guard de PFA multi-choque.
%
%   Cubre:
%     SECCIÓN A — Regresión numérica estricta BNW (spec sin modificar, ND
%                 completo de la spec). Confirma que el refactor de
%                 run_pfa.m NO cambió los valores de referencia.
%     SECCIÓN B — Prueba de que el fix funciona: modificar Cfg.S{1} de BNW
%                 cambia el resultado de PFA (antes del fix, no cambiaba
%                 nada porque run_pfa.m ignoraba Cfg.S/Cfg.Z).
%     SECCIÓN C — Guard de PFA multi-choque: spec sintética con 2 choques
%                 restringidos. PFA debe omitirse con warning; las
%                 funciones de post-proceso no deben fallar con ese
%                 Results. La MISMA spec en modo IS debe correr normal.
%     SECCIÓN D — Multi-horizonte mecánico (sintético, un solo choque,
%                 sobre datos BNW) en PFA e IS.
%     SECCIÓN E — validate_cfg.m detecta S/Z mal dimensionados.
%
%   Uso: ejecutar desde MATLAB (cualquier working directory). Ajustar
%   REF_ROOT en la Sección 0 antes de correr.

fprintf('\n');
fprintf('================================================================\n');
fprintf(' VALIDATE_RESTRICCIONES_PFA_IS\n');
fprintf('================================================================\n\n');

%% ── Sección 0 — Rutas ────────────────────────────────────────────────────
%
%  ┌─────────────────────────────────────────────────────────────────────┐
%  │  EDITAR SOLO ESTA LÍNEA.                                            │
%  └─────────────────────────────────────────────────────────────────────┘
REF_ROOT = '/ruta/absoluta/a/refactored';   % ← EDITAR

EX_ROOT = fullfile(REF_ROOT, 'examples', 'bnw');
EX_CFG  = fullfile(EX_ROOT, 'config');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(EX_CFG);

n_pass = 0;
n_fail = 0;

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN A — Regresión numérica estricta BNW (ND completo de la spec)
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN A — Regresión numérica estricta BNW\n');
fprintf('---------------------------------------------\n');
fprintf('  Nota: usa el ND completo de cada spec (1e4 PFA, 3e4 IS).\n');
fprintf('  Puede tardar varios minutos.\n\n');

REF_PFA = -0.2326865051;
REF_IS  =  0.2041864191;
TOL     = 1e-6;

try
    clear Cfg;
    run(fullfile(EX_CFG, 'spec_bnw_pfa.m'));
    Cfg_pfa = Cfg; clear Cfg;

    Dataset_a  = load_data(Cfg_pfa);
    rng(Cfg_pfa.SEED);
    Post_a     = build_posterior(Dataset_a, Cfg_pfa);
    rng(Cfg_pfa.SEED);
    Results_a_pfa = run_pfa(Post_a, Cfg_pfa);

    v_a1 = Results_a_pfa.LtildeStruct.data(end,end,end);
    ok_a1 = abs(v_a1 - REF_PFA) < TOL;
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'A1: BNW PFA Ltilde(end,end,end) == -0.2326865051 (post-refactor)', ...
        ok_a1, sprintf('valor=%.10f (ref=%.10f)', v_a1, REF_PFA));
catch ME_a1
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'A1: BNW PFA regresión numérica', false, ME_a1.message);
end

try
    clear Cfg;
    run(fullfile(EX_CFG, 'spec_bnw_is.m'));
    Cfg_is = Cfg; clear Cfg;

    Dataset_a2 = load_data(Cfg_is);
    rng(Cfg_is.SEED);
    Post_a2    = build_posterior(Dataset_a2, Cfg_is);
    rng(Cfg_is.SEED);
    Results_a_is = run_is(Post_a2, Cfg_is);

    v_a2 = Results_a_is.LtildeStruct.data(end,end,end,end);
    ok_a2 = abs(v_a2 - REF_IS) < TOL;
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'A2: BNW IS Ltilde(end,end,end,end) == 0.2041864191 (post-refactor)', ...
        ok_a2, sprintf('valor=%.10f (ref=%.10f)', v_a2, REF_IS));
catch ME_a2
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'A2: BNW IS regresión numérica', false, ME_a2.message);
end

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN B — Prueba de que el fix funciona (PFA ya lee Cfg.S)
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN B — Modificar Cfg.S{1} cambia el resultado de PFA\n');
fprintf('-----------------------------------------------------------\n');

try
    clear Cfg;
    run(fullfile(EX_CFG, 'spec_bnw_pfa.m'));
    Cfg_b = Cfg; clear Cfg;
    Cfg_b.ND = 200;   % rápido, esto es una prueba funcional, no de regresión

    Dataset_b = load_data(Cfg_b);
    Post_b    = build_posterior(Dataset_b, Cfg_b);

    n_vars = numel(Cfg_b.S);
    nH     = numel(Cfg_b.HORIZONS_RESTRICT);

    % Original: sp (var 2) POSITIVO en h=0
    Cfg_b1 = Cfg_b;
    Cfg_b1.S{1} = build_restriction_row(2, 1, n_vars, nH, 1);
    rng(0);
    Results_b1 = run_pfa(Post_b, Cfg_b1);

    % Invertido: sp (var 2) NEGATIVO en h=0
    Cfg_b2 = Cfg_b;
    Cfg_b2.S{1} = build_restriction_row(2, 1, n_vars, nH, -1);
    rng(0);
    Results_b2 = run_pfa(Post_b, Cfg_b2);

    sp_h0_b1 = median(squeeze(Results_b1.LtildeStruct.data(1, 2, :)));
    sp_h0_b2 = median(squeeze(Results_b2.LtildeStruct.data(1, 2, :)));

    ok_b = (sp_h0_b1 > 0) && (sp_h0_b2 < 0) && (abs(sp_h0_b1 - sp_h0_b2) > 1e-6);
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'B1: invertir signo en Cfg.S{1} invierte el signo del resultado PFA', ...
        ok_b, sprintf('sp(h=0) signo original=%.4f, invertido=%.4f', sp_h0_b1, sp_h0_b2));
catch ME_b
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'B1: modificar Cfg.S cambia resultado PFA', false, ME_b.message);
end

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN C — Guard de PFA multi-choque
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN C — Guard de PFA multi-choque\n');
fprintf('----------------------------------------\n');

Results_c_pfa = [];
try
    clear Cfg;
    run(fullfile(EX_CFG, 'spec_bnw_pfa.m'));
    Cfg_c = Cfg; clear Cfg;
    Cfg_c.ND = 100;

    n_vars = numel(Cfg_c.S);
    nH     = numel(Cfg_c.HORIZONS_RESTRICT);
    % Agregar restricción en un SEGUNDO choque (sintético, sin pretensión
    % económica): var 3 (cons) positivo ante "choque 2"
    Cfg_c.S{2} = build_restriction_row(3, 1, n_vars, nH, 1);

    Dataset_c = load_data(Cfg_c);
    Post_c    = build_posterior(Dataset_c, Cfg_c);

    warning('off', 'all');
    rng(0);
    Results_c_pfa = run_pfa(Post_c, Cfg_c);
    warning('on', 'all');

    ok_c1 = isfield(Results_c_pfa, 'skipped') && Results_c_pfa.skipped;
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'C1: run_pfa detecta 2 choques restringidos y retorna skipped=true', ...
        ok_c1, '');
catch ME_c1
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C1: guard multi-choque PFA', false, ME_c1.message);
end

% C2: funciones de post-proceso no truenan con un Results skipped
if ~isempty(Results_c_pfa) && isfield(Results_c_pfa, 'skipped') && Results_c_pfa.skipped
    all_ok = true;
    detail_fail = '';
    try
        print_summary(Results_c_pfa.LtildeStruct, Dataset_c, Cfg_c);
        plot_irfs(Results_c_pfa.LtildeStruct, Dataset_c, Cfg_c);
        export_results(Results_c_pfa, Dataset_c, Cfg_c);
        check_stability(Results_c_pfa, Cfg_c);
        diagnose_is_weights(Results_c_pfa, Cfg_c);
    catch ME_c2
        all_ok = false;
        detail_fail = ME_c2.message;
    end
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'C2: post-proceso no falla al recibir Results.skipped=true', all_ok, detail_fail);
else
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C2: post-proceso con Results.skipped', false, ...
        'C1 no produjo un Results.skipped válido');
end

% C3: la MISMA spec con MODE='is' sí corre (multi-choque no es problema para IS)
try
    clear Cfg;
    run(fullfile(EX_CFG, 'spec_bnw_is.m'));
    Cfg_c_is = Cfg; clear Cfg;
    Cfg_c_is.ND         = 200;
    Cfg_c_is.MAX_IS_DRAWS = 200;

    n_vars = numel(Cfg_c_is.S);
    nH     = numel(Cfg_c_is.HORIZONS_RESTRICT);
    Cfg_c_is.S{2} = build_restriction_row(3, 1, n_vars, nH, 1);

    Dataset_c_is = load_data(Cfg_c_is);
    Post_c_is    = build_posterior(Dataset_c_is, Cfg_c_is);
    rng(0);
    Results_c_is = run_is(Post_c_is, Cfg_c_is);

    ok_c3 = strcmpi(Results_c_is.LtildeStruct.mode, 'is') && ...
            (~isfield(Results_c_is, 'skipped') || ~Results_c_is.skipped);
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'C3: la misma spec con MODE=''is'' SÍ corre con 2 choques restringidos', ...
        ok_c3, '');
catch ME_c3
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'C3: IS corre con multi-choque', false, ME_c3.message);
end

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN D — Multi-horizonte mecánico (sintético, un solo choque)
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN D — Multi-horizonte mecánico (PFA e IS)\n');
fprintf('--------------------------------------------------\n');

try
    clear Cfg;
    run(fullfile(EX_CFG, 'spec_bnw_pfa.m'));
    Cfg_d = Cfg; clear Cfg;
    Cfg_d.ND = 100;

    n_vars = numel(Cfg_d.S);
    Cfg_d.HORIZONS_RESTRICT = [0 1];
    nH = numel(Cfg_d.HORIZONS_RESTRICT);

    % sp positivo en h=0 (horizon_idx=1) Y en h=1 (horizon_idx=2)
    Cfg_d.S{1} = [ build_restriction_row(2, 1, n_vars, nH, 1); ...
                   build_restriction_row(2, 2, n_vars, nH, 1) ];
    % tfp = 0 en h=0 solamente (Z no necesita cubrir todos los horizontes)
    Cfg_d.Z{1} = build_restriction_row(1, 1, n_vars, nH, 1);

    Dataset_d = load_data(Cfg_d);
    validate_cfg(Cfg_d);
    Post_d    = build_posterior(Dataset_d, Cfg_d);
    rng(0);
    Results_d_pfa = run_pfa(Post_d, Cfg_d);

    ok_d1 = ~Results_d_pfa.skipped && ...
            isequal(size(Results_d_pfa.LtildeStruct.data), [Cfg_d.HORIZON+1, n_vars, Cfg_d.ND]);
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'D1: PFA con HORIZONS_RESTRICT=[0 1] corre y produce dimensiones correctas', ...
        ok_d1, sprintf('size(Ltilde)=[%s]', num2str(size(Results_d_pfa.LtildeStruct.data))));
catch ME_d1
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'D1: PFA multi-horizonte', false, ME_d1.message);
end

try
    clear Cfg;
    run(fullfile(EX_CFG, 'spec_bnw_is.m'));
    Cfg_d2 = Cfg; clear Cfg;
    Cfg_d2.ND = 200;
    Cfg_d2.MAX_IS_DRAWS = 200;

    n_vars = numel(Cfg_d2.S);
    Cfg_d2.HORIZONS_RESTRICT = [0 1];
    nH = numel(Cfg_d2.HORIZONS_RESTRICT);
    Cfg_d2.S{1} = [ build_restriction_row(2, 1, n_vars, nH, 1); ...
                    build_restriction_row(2, 2, n_vars, nH, 1) ];
    Cfg_d2.Z{1} = build_restriction_row(1, 1, n_vars, nH, 1);

    Dataset_d2 = load_data(Cfg_d2);
    validate_cfg(Cfg_d2);
    Post_d2    = build_posterior(Dataset_d2, Cfg_d2);
    rng(0);
    Results_d_is = run_is(Post_d2, Cfg_d2);

    ok_d2 = isfield(Results_d_is, 'LtildeStruct') && ...
            strcmpi(Results_d_is.LtildeStruct.mode, 'is');
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'D2: IS con HORIZONS_RESTRICT=[0 1] corre sin error', ok_d2, '');
catch ME_d2
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'D2: IS multi-horizonte', false, ME_d2.message);
end

fprintf('\n');

%% ═══════════════════════════════════════════════════════════════════════
%% SECCIÓN E — validate_cfg detecta S/Z mal dimensionados
%% ═══════════════════════════════════════════════════════════════════════
fprintf('SECCIÓN E — validate_cfg detecta dimensiones inconsistentes\n');
fprintf('----------------------------------------------------------------\n');

try
    clear Cfg;
    run(fullfile(EX_CFG, 'spec_bnw_pfa.m'));
    Cfg_e = Cfg; clear Cfg;

    % HORIZONS_RESTRICT de 2 elementos, pero S{1} mal construido con
    % solo n_vars columnas (el error clásico que motivó este chat)
    n_vars = numel(Cfg_e.S);
    Cfg_e.HORIZONS_RESTRICT = [0 1];
    Cfg_e.S{1} = eye(n_vars); Cfg_e.S{1} = Cfg_e.S{1}(2,:);   % solo n_vars cols, mal

    threw = false;
    try
        validate_cfg(Cfg_e);
    catch
        threw = true;
    end
    [n_pass, n_fail] = rpt(n_pass, n_fail, ...
        'E1: validate_cfg lanza error si S{k} no coincide con numel(HORIZONS_RESTRICT)*nvar', ...
        threw, '');
catch ME_e
    [n_pass, n_fail] = rpt(n_pass, n_fail, 'E1: validate_cfg detecta mal dimensionado', false, ME_e.message);
end

fprintf('\n');

%% ── Resumen final ────────────────────────────────────────────────────────
fprintf('================================================================\n');
fprintf(' RESUMEN: %d PASA  |  %d FALLA\n', n_pass, n_fail);
if n_fail == 0
    fprintf(' VEREDICTO: PASA\n');
else
    fprintf(' VEREDICTO: NO PASA — revisar las secciones con [FALLA]\n');
end
fprintf('================================================================\n\n');

%% ── Función auxiliar de reporte (debe ir al final: función local de script) ─
function [np, nf] = rpt(np, nf, label, ok, detail)
    if ok
        fprintf('  [PASA]  %s\n', label);
        np = np + 1;
    else
        fprintf('  [FALLA] %s\n', label);
        if nargin >= 5 && ~isempty(detail)
            fprintf('          %s\n', detail);
        end
        nf = nf + 1;
    end
end
