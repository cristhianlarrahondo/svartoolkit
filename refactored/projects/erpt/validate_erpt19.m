%VALIDATE_ERPT19  ERPT-Chat 19 -- Ejercicio C: 3 sistemas de 5 variables
%   {ner, X_inf, ea, ir, tot}, uno por variable de inflacion. Identificacion
%   cerrada en ERPT-Chat 18 (Discusion, APROBADA), con la asimetria
%   NER-Oferta resuelta via Opcion 1 (ner⊥Ofe=0 SOLO en el sistema de
%   imports).
%
%   Tipo S. No toca run_is.m / build_posterior.m / load_data.m -- las 3
%   specs son pura construccion de Cfg.VARS/Cfg.S/Cfg.Z (post-procesamiento
%   de config). Sin regresion BNW, sin cambios en la Bitacora (Seccion C).
%
%   CACHE-FIRST: corre cada sistema a ND_TARGET=1e6 si no existe cache
%   valido; reusa el patron local_run_spec() de validate_erpt15/17.m
%   (reset determinista `rng('default'); rng(Cfg.SEED)` antes de run_is;
%   captura de stable_frac/frac_top/accept_rate/ne ANTES de aligerar
%   Results con rmfield).
%
%   ── Resumen de bloques ──────────────────────────────────────────────────
%     BLOQUE 1 -- Estimacion/carga cache-first de los 3 sistemas a ND=1e6;
%                 por sistema: ne, tasa de aceptacion, fraccion estable,
%                 top-5%% peso IS + Pareto-k (este ultimo impreso a consola
%                 por diagnose_is_weights dentro de local_run_spec, sobre
%                 el Results crudo).
%     BLOQUE 2 -- Set completo de outputs por sistema (estandar ERPT-Chat
%                 14 decision 5): (a) diagnosticos; (b) IRF+CIRF bandas
%                 68%%/90%% (consola + PNG + Excel); (c) FEVD de las 5
%                 endogenas; (d) digesto ERPT en 5 horizontes, bandas
%                 propias de la spec.
%     BLOQUE 3 -- Consolidado transversal: ERPT Cam->X_inf en los 3
%                 sistemas a los 5 horizontes, mapeado POR NOMBRE de choque
%                 (critico: imp reordena a Cam->Ofe->Dem), verificando la
%                 jerarquia imp_inf > pro_inf > con_inf. Exporta a
%                 output/comparison/erpt19_ejercicioC_consolidado.xlsx.
%     BLOQUE 4 -- Cotejo DC-4: verificacion textual de (i) ner⊥Ofe=0 SOLO
%                 en imports y (ii) la jerarquia de signos contra el cache
%                 del Ejercicio A (spec ganadora, cache-only, nunca se
%                 re-estima).
%     VEREDICTO GLOBAL
%
%   Ejecutar COMPLETO (F5). Pegar el output de consola en el chat.

fprintf('\n');
fprintf('======================================================\n');
fprintf('   VALIDATE ERPT-CHAT 19 -- Ejercicio C (3 sistemas)\n');
fprintf('======================================================\n\n');

%% ── Controles de corrida (editar aqui) ------------------------------------
USE_CACHE       = true;      % true = reusar <OUTPUT_DIR>/results_is.mat si ND cacheado >= ND_TARGET
ND_TARGET       = 1e6;       % ND cientifico final (corrida unica de robustez por sistema)
WIN_SPEC        = 'spec_A_rob_aa_diffuse_lag4_v0';   % ganadora Ejercicio A (cotejo Bloque 4)
NE_MIN          = 200;       % umbral duro usado desde ERPT-Chat 8 (informativo aqui)
STABLE_FRAC_MIN = 0.70;      % gate Paso 1 ERPT-Chat 15 (informativo aqui)
BAND_68_90      = [0.16 0.84;   % 68% bilateral
                   0.05 0.95]; % 90% bilateral -- SOLO para IRF/CIRF (Bloque 2b).
                                % El ERPT (Bloque 2d/3) usa las bandas
                                % PROPIAS de la spec (Cfg.CRED_BANDS =
                                % [0.25 0.75]).

% -- Definicion de los 3 sistemas (spec, choques nombrados EN ORDEN, precio) --
%    named_shocks va en el ORDEN POSICIONAL de Cfg.SHOCK_NAMES de cada spec
%    (imp: Cam,Ofe,Dem ; pro/con: Cam,Dem,Ofe). El mapeo transversal del
%    Bloque 3 es POR NOMBRE, no por posicion.
SYS(1) = struct('spec','spec_C_rob_aa_diffuse_lag4_imp_v0', ...
                'named_shocks',{{'Cam','Ofe','Dem'}}, 'price_var','imp_inf');
SYS(2) = struct('spec','spec_C_rob_aa_diffuse_lag4_pro_v0', ...
                'named_shocks',{{'Cam','Dem','Ofe'}}, 'price_var','pro_inf');
SYS(3) = struct('spec','spec_C_rob_aa_diffuse_lag4_con_v0', ...
                'named_shocks',{{'Cam','Dem','Ofe'}}, 'price_var','con_inf');
n_sys = numel(SYS);

fprintf('  USE_CACHE : %d   |   ND_TARGET : %g\n', USE_CACHE, ND_TARGET);
for s = 1:n_sys
    fprintf('  Sistema %d : %-38s  (X_inf=%s)\n', s, SYS(s).spec, SYS(s).price_var);
end
fprintf('\n');

%% ── Rutas -------------------------------------------------------------------
val_file      = mfilename('fullpath');
PROJ_ROOT     = fileparts(val_file);
PROJECTS_ROOT = fileparts(PROJ_ROOT);
REF_ROOT      = fileparts(PROJECTS_ROOT);
PROJ_CFG      = fullfile(PROJ_ROOT, 'config');
PROJ_SRC      = fullfile(PROJ_ROOT, 'src');
REF_SRC       = fullfile(REF_ROOT, 'src');
REF_CFG_DIR   = fullfile(REF_ROOT, 'config');
REF_HELP      = fullfile(REF_ROOT, 'helpfunctions');
REF_VALIDATE  = fullfile(REF_ROOT, 'validate');

addpath(REF_SRC); addpath(REF_CFG_DIR); addpath(REF_HELP);
addpath(REF_VALIDATE); addpath(PROJ_CFG); addpath(PROJ_SRC);

V = {'FAIL', 'OK  '};

% Contenedores de resultados por sistema (indexados 1..n_sys)
RUN = repmat(struct('ok',false,'used_cache',false,'ne',NaN,'accept_rate',NaN, ...
    'stable_frac',NaN,'frac_top',NaN,'Results',[],'Dataset',[],'Cfg',[],'ERPT',[]), n_sys, 1);

% =========================================================================
%  BLOQUE 1 -- Estimacion/carga cache-first de los 3 sistemas
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 1 -- Estimacion/carga de los 3 sistemas\n');
fprintf('======================================================\n\n');

bloque1_ok = true;
for s = 1:n_sys
    fprintf('  --- Sistema %d: %s (cache-first, ND_TARGET=%g) ---\n', s, SYS(s).spec, ND_TARGET);
    try
        out = local_run_spec(SYS(s).spec, PROJ_CFG, USE_CACHE, ND_TARGET);
        if ~out.ok
            error('validate_erpt19:specFailed', '%s', out.err_msg);
        end
        RUN(s).ok          = true;
        RUN(s).used_cache  = out.used_cache;
        RUN(s).ne          = out.ne;
        RUN(s).accept_rate = out.accept_rate;
        RUN(s).stable_frac = out.stable_frac;
        RUN(s).frac_top    = out.frac_top;
        RUN(s).Results     = out.Results;
        RUN(s).Dataset     = out.Dataset;
        RUN(s).Cfg         = out.Cfg;
        RUN(s).ERPT        = out.ERPT;

        fprintf('  used_cache       : %d\n', out.used_cache);
        fprintf('  ne               : %d\n', out.ne);
        fprintf('  tasa aceptacion  : %.4f\n', out.accept_rate);
        fprintf('  frac. estable    : %.4f  (gate informativo Paso 1 ERPT-Chat 15: >= %.2f)\n', ...
            out.stable_frac, STABLE_FRAC_MIN);
        fprintf('  frac. peso top-5%%: %.4f  (Pareto-k impreso arriba por diagnose_is_weights)\n', out.frac_top);
        if out.ne < NE_MIN
            fprintf('  [aviso] ne=%d < NE_MIN=%d.\n', out.ne, NE_MIN);
        end
        if out.stable_frac < STABLE_FRAC_MIN
            fprintf('  [aviso] frac. estable %.4f < %.2f -- informativo (este chat no reabre\n', ...
                out.stable_frac, STABLE_FRAC_MIN);
            fprintf('  el gate de seleccion de ERPT-Chat 15).\n');
        end
        fprintf('  >> Sistema %d: OK.\n\n', s);
    catch ME
        bloque1_ok = false;
        fprintf('  [ERROR] %s\n', ME.message);
        fprintf('  >> Sistema %d: NO PASA.\n\n', s);
    end
end

if bloque1_ok
    fprintf('  >> BLOQUE 1: PASA.\n\n');
else
    fprintf('  >> BLOQUE 1: NO PASA -- no se puede continuar de forma confiable.\n\n');
end

% =========================================================================
%  BLOQUE 2 -- Set completo de outputs por sistema
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 2 -- Outputs completos por sistema\n');
fprintf('======================================================\n\n');

bloque2_ok = true;
for s = 1:n_sys
    fprintf('======================================================\n');
    fprintf('  BLOQUE 2 -- Sistema %d: %s\n', s, SYS(s).spec);
    fprintf('======================================================\n\n');
    try
        if ~RUN(s).ok || isempty(RUN(s).Results)
            error('validate_erpt19:noResults', 'Sistema %d no estimado en Bloque 1.', s);
        end
        Results = RUN(s).Results; Dataset = RUN(s).Dataset;
        Cfg = RUN(s).Cfg; ERPT = RUN(s).ERPT;
        named_shocks = SYS(s).named_shocks; price_var = SYS(s).price_var;

        % Resolver indices de los choques nombrados (por NOMBRE)
        shock_idx_named = zeros(1, numel(named_shocks));
        for i = 1:numel(named_shocks)
            shock_idx_named(i) = find(strcmp(Cfg.SHOCK_NAMES, named_shocks{i}), 1);
        end

        % ── (a) Diagnosticos (valores YA calculados en Bloque 1, sobre el
        %        Results crudo; el struct aqui ya viene aligerado por rmfield,
        %        no se re-invoca check_stability/diagnose_is_weights) ────────
        fprintf('  --- (a) Diagnosticos de corrida ---\n');
        fprintf('  ne (draws efectivos)       : %d\n', RUN(s).ne);
        fprintf('  Tasa de aceptacion         : %.4f\n', RUN(s).accept_rate);
        fprintf('  Fraccion draws estables    : %.4f\n', RUN(s).stable_frac);
        fprintf('  Fraccion peso IS en top-5%% : %.4f\n\n', RUN(s).frac_top);

        % ── (b) IRF + CIRF, bandas 68%/90%, 3 choques nombrados x 5 endogenas ─
        fprintf('  --- (b) IRF + CIRF (bandas 68%%/90%%; %s/%s/%s; consola + PNG + Excel) ---\n', ...
            named_shocks{1}, named_shocks{2}, named_shocks{3});
        Cfg_disp                  = Cfg;
        Cfg_disp.CRED_BANDS       = BAND_68_90;
        Cfg_disp.SHOCK_IDX        = shock_idx_named;   % solo los 3 nombrados
        Cfg_disp.SUMMARY_HORIZONS = Cfg.ERPT_HORIZONS;
        % (sin RESP_IDX -> las 5 respuestas endogenas)

        print_summary(Results.LtildeStruct, Dataset, Cfg_disp);
        local_print_cirf_digest(Results.LtildeStruct, Dataset, Cfg_disp);
        plot_irfs(Results.LtildeStruct, Dataset, Cfg_disp, Results);
        export_results(Results, Dataset, Cfg_disp);
        fprintf('\n');

        % ── (c) FEVD, TODAS las 5 variables endogenas (sin RESP_IDX) ────────
        fprintf('  --- (c) FEVD (las 5 variables endogenas: ner, %s, ea, ir, tot) ---\n', price_var);
        plot_fevd(Results, Dataset, Cfg);
        fprintf('\n');

        % ── (d) ERPT, 5 horizontes, bandas propias de la spec ───────────────
        fprintf('  --- (d) ERPT -- %s (bandas propias [%.2f, %.2f]) ---\n', ...
            SYS(s).spec, ERPT.cred_bands(1,1), ERPT.cred_bands(1,2));
        local_print_erpt_digest(ERPT, named_shocks, {price_var});

        fprintf('  >> BLOQUE 2 (Sistema %d): PASA.\n\n', s);
    catch ME
        bloque2_ok = false;
        fprintf('  [ERROR] %s\n', ME.message);
        fprintf('  >> BLOQUE 2 (Sistema %d): NO PASA.\n\n', s);
    end
end

% =========================================================================
%  BLOQUE 3 -- Consolidado transversal ERPT Cam->X_inf (mapeo POR NOMBRE)
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 3 -- Consolidado ERPT Cam->X_inf (3 sistemas)\n');
fprintf('======================================================\n\n');

bloque3_ok = true;
hierarchy_ok_all = true;
try
    if any(~[RUN.ok])
        error('validate_erpt19:incompleteBloque1', 'Bloque 1 no completo -- no se puede consolidar.');
    end

    horizons_ref = RUN(1).ERPT.horizons(:)';
    nh = numel(horizons_ref);

    % Matriz de medianas Cam->X_inf: filas = sistema, columnas = horizonte
    Med = nan(n_sys, nh);
    Lo  = nan(n_sys, nh);
    Hi  = nan(n_sys, nh);
    rows = {};   % para tabla larga

    for s = 1:n_sys
        ERPT = RUN(s).ERPT; price_var = SYS(s).price_var;
        names_all = {ERPT.shocks.name};
        k = find(strcmp(names_all, 'Cam'), 1);   % MAPEO POR NOMBRE
        if isempty(k)
            error('validate_erpt19:noCam', 'Choque Cam no hallado en ERPT de %s.', SYS(s).spec);
        end
        prices_arr = ERPT.shocks(k).prices;
        p = find(strcmp({prices_arr.var}, price_var), 1);
        if isempty(p)
            error('validate_erpt19:noPrice', 'Price_var %s no hallada en ERPT de %s.', price_var, SYS(s).spec);
        end
        Med(s,:) = prices_arr(p).median(:)';
        Lo(s,:)  = prices_arr(p).band_lo(1,:);   % banda 25% (propia de la spec)
        Hi(s,:)  = prices_arr(p).band_hi(1,:);   % banda 75%
        for hh = 1:nh
            rows(end+1,:) = { SYS(s).spec, price_var, horizons_ref(hh), ...
                Med(s,hh), Lo(s,hh), Hi(s,hh) }; %#ok<AGROW>
        end
    end

    % -- Impresion consolidada + verificacion de jerarquia imp>pro>con -------
    fprintf('  ERPT Cam -> X_inf (mediana [banda propia 25%%,75%%]) por sistema y horizonte:\n\n');
    fprintf('  %-6s', 'h');
    fprintf('  %-26s  %-26s  %-26s\n', 'imp_inf', 'pro_inf', 'con_inf');
    fprintf('  %s\n', repmat('-', 1, 92));
    for hh = 1:nh
        fprintf('  h=%-4d', horizons_ref(hh));
        for s = 1:n_sys
            fprintf('  %8.3f [%7.3f,%7.3f]', Med(s,hh), Lo(s,hh), Hi(s,hh));
        end
        fprintf('\n');
    end
    fprintf('\n');

    fprintf('  Verificacion jerarquia imp_inf > pro_inf > con_inf (sobre medianas):\n');
    for hh = 1:nh
        h_ok = (Med(1,hh) > Med(2,hh)) && (Med(2,hh) > Med(3,hh));
        hierarchy_ok_all = hierarchy_ok_all && h_ok;
        if h_ok
            veredicto = 'SE CUMPLE';
        else
            veredicto = 'NO se cumple';
        end
        fprintf('    h=%-3d : imp=%.3f  pro=%.3f  con=%.3f   -> %s\n', ...
            horizons_ref(hh), Med(1,hh), Med(2,hh), Med(3,hh), veredicto);
    end
    if hierarchy_ok_all
        fprintf('  >> Jerarquia imp>pro>con: SE CUMPLE en los %d horizontes.\n\n', nh);
    else
        fprintf(['  >> Jerarquia imp>pro>con: NO se cumple en todos los horizontes\n' ...
                 '     (resultado empirico informativo -- ver .md de framing economico\n' ...
                 '     de ERPT-Chat 16 sobre la variabilidad relativa de con_inf).\n\n']);
    end

    % -- Exportar consolidado ------------------------------------------------
    T_cons = cell2table(rows, 'VariableNames', ...
        {'spec','price_var','horizon','erpt_median','erpt_lo_p25','erpt_hi_p75'});

    % Tabla ancha auxiliar (jerarquia por horizonte)
    T_hier = table(horizons_ref(:), Med(1,:)', Med(2,:)', Med(3,:)', ...
        (Med(1,:)' > Med(2,:)') & (Med(2,:)' > Med(3,:)'), ...
        'VariableNames', {'horizon','imp_inf','pro_inf','con_inf','imp_gt_pro_gt_con'});

    comparison_dir = fullfile(PROJ_ROOT, 'output', 'comparison');
    if ~isfolder(comparison_dir), mkdir(comparison_dir); end
    xlsx_path = fullfile(comparison_dir, 'erpt19_ejercicioC_consolidado.xlsx');
    if isfile(xlsx_path), delete(xlsx_path); end
    writetable(T_cons, xlsx_path, 'Sheet', 'erpt_cam_consolidado');
    writetable(T_hier, xlsx_path, 'Sheet', 'jerarquia_por_horizonte');
    fprintf('  Consolidado exportado (2 hojas) a:\n    %s\n\n', xlsx_path);

    fprintf('  >> BLOQUE 3: PASA.\n\n');
catch ME
    bloque3_ok = false;
    fprintf('  [ERROR] %s\n', ME.message);
    fprintf('  >> BLOQUE 3: NO PASA.\n\n');
end

% =========================================================================
%  BLOQUE 4 -- Cotejo DC-4: asimetria ner⊥Ofe=0 + jerarquia de signos vs A
% =========================================================================
fprintf('======================================================\n');
fprintf('  BLOQUE 4 -- Cotejo DC-4 (asimetria + signos vs Ej. A)\n');
fprintf('======================================================\n\n');

bloque4_ok = true;
try
    % ── (i) Asimetria ner⊥Ofe=0 : deterministica, leida de Cfg.Z de cada spec ─
    %        Se espera: SOLO el sistema imports tiene ner(=col 1)=0 bajo Ofe.
    fprintf('  --- (i) Asimetria ner⊥Ofe=0 (esperado: SOLO en imports) ---\n');
    asym_ok = true;
    expected_ner_zero = [true, false, false];   % imp, pro, con
    for s = 1:n_sys
        Cfg = RUN(s).Cfg;
        ofe_pos = find(strcmp(Cfg.SHOCK_NAMES, 'Ofe'), 1);
        Zofe = Cfg.Z{ofe_pos};
        has_ner_zero = ~isempty(Zofe) && any(Zofe(:,1) ~= 0);   % col 1 = ner (h=0)
        match = (has_ner_zero == expected_ner_zero(s));
        asym_ok = asym_ok && match;
        fprintf('    %-38s Ofe(pos %d): ner=0 -> %-5s (esperado %-5s) : %s\n', ...
            SYS(s).spec, ofe_pos, mat2str(has_ner_zero), mat2str(expected_ner_zero(s)), ...
            V{int32(match)+1});
    end
    if asym_ok
        fprintf('  >> (i) Asimetria ner⊥Ofe=0 correctamente localizada SOLO en imports.\n\n');
    else
        fprintf('  >> (i) [FALLA] la asimetria no coincide con el diseno DC-4.\n\n');
    end

    % ── (ii) Jerarquia de signos Cam->X_inf: C (3 sistemas) vs A (cache-only) ─
    fprintf('  --- (ii) Signos Cam->X_inf: Ejercicio C vs Ejercicio A (ganadora) ---\n');
    sign_note = '';
    A_available = false;
    try
        clear Cfg;
        Cfg = struct();
        run(fullfile(PROJ_CFG, [WIN_SPEC '.m']));
        cache_path_A = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
        if ~isfile(cache_path_A)
            error('validate_erpt19:noACache', ...
                'No existe cache de la ganadora (%s). Ejecuta validate_erpt15/16.m para poblarlo.', cache_path_A);
        end
        [~, ERPT_A, ~, ~] = load_erpt_run(Cfg.OUTPUT_DIR);
        A_available = true;

        namesA = {ERPT_A.shocks.name};
        kA = find(strcmp(namesA, 'Cam'), 1);
        pricesA = ERPT_A.shocks(kA).prices;
        pvA = {pricesA.var};
        horA = ERPT_A.horizons(:)';

        price_order = {'imp_inf','pro_inf','con_inf'};
        MedA = nan(3, numel(horA));
        for pp = 1:3
            ip = find(strcmp(pvA, price_order{pp}), 1);
            if ~isempty(ip), MedA(pp,:) = pricesA(ip).median(:)'; end
        end

        fprintf('    A (ganadora, 6 vars, Cam->precio) medianas por horizonte:\n');
        fprintf('    %-6s  %10s  %10s  %10s\n', 'h', 'imp_inf', 'pro_inf', 'con_inf');
        for hh = 1:numel(horA)
            fprintf('    h=%-4d  %10.3f  %10.3f  %10.3f\n', horA(hh), MedA(1,hh), MedA(2,hh), MedA(3,hh));
        end

        % Cotejo de SIGNO Cam->X_inf entre A y C, horizonte a horizonte
        fprintf('\n    Cotejo de signo Cam->X_inf (A vs C), por variable y horizonte:\n');
        sign_consistent = true;
        for pp = 1:3
            % localizar el sistema C con ese price_var
            sC = find(strcmp({SYS.price_var}, price_order{pp}), 1);
            for hh = 1:numel(horA)
                % emparejar horizonte de A con el de C (mismos [3 6 12 24 36])
                hcol = find(RUN(sC).ERPT.horizons == horA(hh), 1);
                if isempty(hcol), continue; end
                ncam = {RUN(sC).ERPT.shocks.name};
                kc = find(strcmp(ncam,'Cam'),1);
                pc = find(strcmp({RUN(sC).ERPT.shocks(kc).prices.var}, price_order{pp}),1);
                medC = RUN(sC).ERPT.shocks(kc).prices(pc).median(hcol);
                same_sign = (sign(MedA(pp,hh)) == sign(medC)) || (MedA(pp,hh)==0) || (medC==0);
                sign_consistent = sign_consistent && same_sign;
                if ~same_sign
                    fprintf('    [signo divergente] %s h=%d : A=%.3f  C=%.3f\n', ...
                        price_order{pp}, horA(hh), MedA(pp,hh), medC);
                end
            end
        end
        if sign_consistent
            fprintf('    >> Signo Cam->X_inf CONSISTENTE entre A y C en todos los horizontes/variables.\n');
            sign_note = 'consistente';
        else
            fprintf('    >> Signo Cam->X_inf con divergencias (ver lineas arriba) -- informativo.\n');
            sign_note = 'con divergencias (informativo)';
        end

        % Jerarquia de magnitud en A (referencia)
        fprintf('\n    Jerarquia imp>pro>con en A (referencia, sobre medianas):\n');
        for hh = 1:numel(horA)
            hokA = (MedA(1,hh) > MedA(2,hh)) && (MedA(2,hh) > MedA(3,hh));
            fprintf('      h=%-3d : %s\n', horA(hh), V{int32(hokA)+1});
        end
    catch MEA
        fprintf('    [aviso] Cotejo contra A omitido: %s\n', MEA.message);
        sign_note = 'no evaluado (cache A ausente)';
    end
    fprintf('\n');

    % Veredicto del bloque: la parte deterministica (asimetria) es el gate;
    % la consistencia de signo vs A es evidencia informativa.
    bloque4_ok = asym_ok;
    fprintf('  >> BLOQUE 4: gate = asimetria ner⊥Ofe (%s); signos vs A = %s.\n', ...
        V{int32(asym_ok)+1}, sign_note);
    if bloque4_ok
        fprintf('  >> BLOQUE 4: PASA.\n\n');
    else
        fprintf('  >> BLOQUE 4: NO PASA (asimetria no coincide con DC-4).\n\n');
    end
catch ME
    bloque4_ok = false;
    fprintf('  [ERROR] %s\n', ME.message);
    fprintf('  >> BLOQUE 4: NO PASA.\n\n');
end

% =========================================================================
%  VEREDICTO GLOBAL
% =========================================================================
fprintf('======================================================\n');
fprintf('              VEREDICTO GLOBAL ERPT-CHAT 19\n');
fprintf('======================================================\n');
fprintf('  Bloque 1 (estimacion/carga 3 sistemas)        : %s\n', V{int32(bloque1_ok)+1});
fprintf('  Bloque 2 (outputs completos por sistema)      : %s\n', V{int32(bloque2_ok)+1});
fprintf('  Bloque 3 (consolidado Cam->X_inf + jerarquia) : %s\n', V{int32(bloque3_ok)+1});
fprintf('  Bloque 4 (cotejo DC-4: asimetria + signos)    : %s\n', V{int32(bloque4_ok)+1});
fprintf('------------------------------------------------------\n');
if bloque1_ok && bloque2_ok && bloque3_ok && bloque4_ok
    fprintf('  GLOBAL : PASA\n');
else
    fprintf('  GLOBAL : NO PASA -- revisar bloques marcados arriba\n');
end
fprintf('  (Nota: la jerarquia imp>pro>con del Bloque 3 es evidencia\n');
fprintf('   economica informativa, no un gate del veredicto.)\n');
fprintf('======================================================\n\n');
fprintf('Pegar este output completo en el chat para verificacion.\n\n');


%% ── Helpers locales ---------------------------------------------------------

function out = local_run_spec(spec_name, PROJ_CFG, USE_CACHE, ND_TARGET)
%LOCAL_RUN_SPEC  Carga (cache-first) o corre una spec a ND_TARGET.
%   Identico al helper de validate_erpt15/17.m -- reset determinista de RNG
%   por spec (`rng('default'); rng(Cfg.SEED)`) inmediatamente antes de
%   run_is. Captura stable_frac/frac_top/accept_rate/ne sobre el Results
%   CRUDO (con Bdraws) antes de aligerar con rmfield.

    if contains(spec_name, '_aa_')
        transform_type = 'aa';
    else
        transform_type = 'mm';
    end

    out = struct('spec_name', spec_name, 'ok', true, 'err_msg', '', ...
        'used_cache', false, 'transform', transform_type, ...
        'Results', [], 'Dataset', [], 'Cfg', [], 'ERPT', [], ...
        'stable_frac', NaN, 'accept_rate', NaN, 'ne', NaN, 'frac_top', NaN);

    try
        Cfg = struct();
        run(fullfile(PROJ_CFG, [spec_name '.m']));

        cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
        used_cache = false;
        Results_spec = []; ERPT_spec = []; Dataset_spec = [];

        if USE_CACHE && isfile(cache_path)
            try
                peek = load(cache_path, 'Cfg');
                nd_cached = NaN;
                if isfield(peek, 'Cfg') && isfield(peek.Cfg, 'ND')
                    nd_cached = peek.Cfg.ND;
                end
                if ~isnan(nd_cached) && nd_cached >= ND_TARGET
                    [Results_spec, ERPT_spec, Dataset_spec, Cfg_cached] = load_erpt_run(Cfg.OUTPUT_DIR);
                    used_cache = true;
                    Cfg = Cfg_cached;
                else
                    fprintf('  [%s] cache a ND=%g < objetivo ND=%g -- recalculando desde cero.\n', ...
                        spec_name, nd_cached, ND_TARGET);
                end
            catch
                used_cache = false;
            end
        end

        if ~used_cache
            Cfg.ND = ND_TARGET;
            Dataset_spec = load_data(Cfg);
            validate_cfg(Cfg, Dataset_spec);
            Posterior_spec = build_posterior(Dataset_spec, Cfg);

            % -- RESET DETERMINISTA POR SPEC --
            rng('default'); rng(Cfg.SEED);
            tic;
            Results_spec = run_is(Posterior_spec, Cfg);
            Results_spec.t_elapsed = toc;

            ERPT_spec = calculate_erpt(Results_spec, Dataset_spec, Cfg, transform_type);
            save_erpt_run(Results_spec, ERPT_spec, Dataset_spec, Cfg);
        end

        % -- Diagnosticos que requieren draws crudos (Results.Bdraws) --
        %    Se calculan ANTES de aligerar. save_erpt_run persiste el
        %    Results COMPLETO, asi que en cache-hit tambien traen Bdraws.
        stable_frac = check_stability(Results_spec, Cfg);
        frac_top    = diagnose_is_weights(Results_spec, Cfg);
        accept_rate = sum(Results_spec.uw > 0) / Cfg.ND;
        ne_val      = Results_spec.ne;

        % -- Aligerar antes de devolver (draws crudos ya persistidos) --
        Results_light = rmfield(Results_spec, {'Bdraws', 'Sigmadraws', 'Qdraws'});

        out.used_cache  = used_cache;
        out.Results     = Results_light;
        out.Dataset     = Dataset_spec;
        out.Cfg         = Cfg;
        out.ERPT        = ERPT_spec;
        out.stable_frac = stable_frac;
        out.accept_rate = accept_rate;
        out.ne          = ne_val;
        out.frac_top    = frac_top;

    catch ME
        out.ok      = false;
        out.err_msg = ME.message;
    end
end

function local_print_cirf_digest(LtildeStruct, Dataset, Cfg)
%LOCAL_PRINT_CIRF_DIGEST  Digesto de consola para CIRF (identico al helper
%   de validate_erpt16/17.m -- print_summary.m no soporta CIRF directamente).

    cred_bands = [0.16 0.84];
    if isfield(Cfg, 'CRED_BANDS') && ~isempty(Cfg.CRED_BANDS)
        cred_bands = Cfg.CRED_BANDS;
    end
    n_bands = size(cred_bands, 1);

    shock_idx_req = LtildeStruct.shock_idx;
    if isfield(Cfg, 'SHOCK_IDX') && ~isempty(Cfg.SHOCK_IDX)
        shock_idx_req = Cfg.SHOCK_IDX;
    end
    response_idx = 1:LtildeStruct.nvar;
    if isfield(Cfg, 'RESP_IDX') && ~isempty(Cfg.RESP_IDX)
        response_idx = Cfg.RESP_IDX;
    end
    shock_names = {};
    if isfield(Cfg, 'SHOCK_NAMES') && ~isempty(Cfg.SHOCK_NAMES)
        shock_names = Cfg.SHOCK_NAMES;
    end
    summary_horizons = [0 4 8 20 40];
    if isfield(Cfg, 'SUMMARY_HORIZONS') && ~isempty(Cfg.SUMMARY_HORIZONS)
        summary_horizons = Cfg.SUMMARY_HORIZONS;
    end

    endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
    all_labels = Dataset.var_labels(endo_mask);
    LtildeStruct.var_labels = all_labels;

    [irfs_by_shock, label_shock_arr, label_resp, shock_idx_resolved] = ...
        select_irfs(LtildeStruct, shock_idx_req, response_idx, shock_names);

    horizon_max = LtildeStruct.horizon;
    h_valid = summary_horizons(summary_horizons >= 0 & summary_horizons <= horizon_max);
    h_idx   = h_valid + 1;
    nh      = numel(h_idx);
    n_shocks = numel(shock_idx_resolved);

    sep_wide = repmat('=', 1, 72);
    sep_thin = repmat('-', 1, 72);

    for j = 1:n_shocks
        cirfs_j = compute_cirfs(irfs_by_shock{j});
        nresp   = size(cirfs_j, 2);

        fprintf('\n%s\n', sep_wide);
        fprintf('  CIRF SUMMARY (digesto)   Shock: %s\n', label_shock_arr{j});
        fprintf('%s\n', sep_wide);

        band_hdr = '';
        for bb = 1:n_bands
            band_hdr = [band_hdr, sprintf('  [p%.0f, p%.0f]         ', ...
                cred_bands(bb,1)*100, cred_bands(bb,2)*100)]; %#ok<AGROW>
        end
        fprintf('  %-20s  h   %8s  %s\n', 'Respuesta', 'Mediana', strtrim(band_hdr));
        fprintf('%s\n', sep_thin);

        for jj = 1:nresp
            for ii = 1:nh
                sl = squeeze(cirfs_j(h_idx(ii), jj, :));
                med_val = quantile(sl, 0.50);
                band_str = '';
                for bb = 1:n_bands
                    q = quantile(sl, cred_bands(bb, :));
                    band_str = [band_str, sprintf('  [%8.4f, %8.4f]', q(1), q(2))]; %#ok<AGROW>
                end
                if ii == 1
                    fprintf('  %-20s  %2d  %8.4f%s\n', label_resp{jj}, h_valid(ii), med_val, band_str);
                else
                    fprintf('  %-20s  %2d  %8.4f%s\n', '', h_valid(ii), med_val, band_str);
                end
            end
            fprintf('%s\n', sep_thin);
        end
    end
    fprintf('\n');
end

function local_print_erpt_digest(ERPT, named_shocks, price_vars)
%LOCAL_PRINT_ERPT_DIGEST  Digesto de consola de ERPT.shocks (identico al
%   helper de validate_erpt16/17.m).
    names_all = {ERPT.shocks.name};
    horizons  = ERPT.horizons;

    for kk = 1:numel(named_shocks)
        k_idx = find(strcmp(names_all, named_shocks{kk}), 1);
        if isempty(k_idx)
            fprintf('  [aviso] choque %s no encontrado en ERPT.shocks.\n', named_shocks{kk});
            continue;
        end
        prices_arr = ERPT.shocks(k_idx).prices;
        pvar_names = {prices_arr.var};

        fprintf('  Choque: %s\n', named_shocks{kk});
        for pp = 1:numel(price_vars)
            p_idx = find(strcmp(pvar_names, price_vars{pp}), 1);
            if isempty(p_idx)
                fprintf('    [aviso] price_var %s no encontrada.\n', price_vars{pp});
                continue;
            end
            fprintf('    %-10s', price_vars{pp});
            for hh = 1:numel(horizons)
                fprintf('  h=%-2d: %7.3f [%6.3f, %6.3f]', horizons(hh), ...
                    prices_arr(p_idx).median(hh), ...
                    prices_arr(p_idx).band_lo(1, hh), prices_arr(p_idx).band_hi(1, hh));
            end
            fprintf('\n');
        end
        fprintf('\n');
    end
end
