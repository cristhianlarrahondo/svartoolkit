%DIAGNOSE_ERPT12_NIWCUSTOM_CACHE_INTEGRITY  ERPT-Chat 12 -- Verificacion
%   directa del cache de las 4 specs mm_niwcustom (y, como contraste, las 4
%   mm_minn) tras el hallazgo inesperado en validate_erpt12.m: las medianas
%   de ERPT en mm_niwcustom (con supuesto 89-97% de draws estables) salieron
%   en el mismo orden de magnitud que mm_minn (roto, ~30% estable).
%
%   Sospecha del usuario: mixup de cache (niwcustom cargo, por error, algo
%   que en realidad corresponde a minn). Este script NO asume la respuesta
%   -- la verifica leyendo directamente Cfg.PRIOR de cada cache.
%
%   Ademas, si el cache resulta correcto (sin mixup), prueba la hipotesis
%   alternativa: que check_stability.m (max|eig(F)|<1) no distingue entre
%   "bien comportado" y "cuasi-raiz-unitaria" (eig muy cercano a 1), lo
%   cual seguiria produciendo cumsums de 36 meses explosivos sin que la
%   spec se marque como inestable.
%
%   Solo LEE cache existente (load_erpt_run) -- no corre ninguna
%   estimacion nueva, no toca build_posterior.m/run_is.m/check_stability.m
%   (Tipo S, exploratorio, no forma parte del protocolo de cierre).
%   Ejecutar COMPLETO (F5).

fprintf('\n');
fprintf('======================================================\n');
fprintf('   DIAGNOSTICO ERPT-CHAT 12 -- integridad de cache\n');
fprintf('   niwcustom vs minn vs diffuse (mm)\n');
fprintf('======================================================\n\n');

%% -- Rutas -----------------------------------------------------------------
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

minn_specs = { ...
    'spec_A_base_mm_minn_lag2_v0', 'spec_A_base_mm_minn_lag4_v0', ...
    'spec_A_rob_mm_minn_lag2_v0',  'spec_A_rob_mm_minn_lag4_v0'  };

niwc_specs = { ...
    'spec_A_base_mm_niwcustom_lag2_v0', 'spec_A_base_mm_niwcustom_lag4_v0', ...
    'spec_A_rob_mm_niwcustom_lag2_v0',  'spec_A_rob_mm_niwcustom_lag4_v0'  };

diffuse_specs = { ...
    'spec_A_base_mm_diffuse_lag2_v0', 'spec_A_base_mm_diffuse_lag4_v0', ...
    'spec_A_rob_mm_diffuse_lag2_v0',  'spec_A_rob_mm_diffuse_lag4_v0'  };

% =========================================================================
%  PARTE 1 -- Integridad del cache: que Cfg.PRIOR quedo realmente guardado
% =========================================================================
fprintf('======================================================\n');
fprintf('  PARTE 1 -- Contenido real de Cfg.PRIOR en cache\n');
fprintf('======================================================\n\n');

all_specs = [minn_specs, niwc_specs, diffuse_specs];
Results_all = struct();
Cfg_all     = struct();

for ss = 1:numel(all_specs)
    spec_name = all_specs{ss};

    clear Cfg;
    Cfg = struct();
    run(fullfile(PROJ_CFG, [spec_name '.m']));
    out_dir = Cfg.OUTPUT_DIR;

    fprintf('------------------------------------------------------\n');
    fprintf('  Spec: %s\n', spec_name);
    fprintf('  OUTPUT_DIR esperado: %s\n', out_dir);

    if ~isfile(fullfile(out_dir, 'results_is.mat'))
        fprintf('  [SIN CACHE] no existe results_is.mat en este directorio.\n\n');
        continue;
    end

    [Results_spec, ~, ~, Cfg_cached] = load_erpt_run(out_dir);

    fprintf('  Cfg_cached.SPEC_NAME (guardado dentro del .mat) : %s\n', Cfg_cached.SPEC_NAME);
    fprintf('  Coincide con nombre de archivo/carpeta          : %s\n', ...
        iif_local(strcmp(Cfg_cached.SPEC_NAME, spec_name), 'SI', 'NO -- ALERTA'));
    fprintf('  Cfg_cached.PRIOR.type                           : %s\n', Cfg_cached.PRIOR.type);

    if strcmp(Cfg_cached.PRIOR.type, 'minnesota')
        fprintf('  Cfg_cached.PRIOR.lambda1                        : %.3f\n', Cfg_cached.PRIOR.lambda1);
    elseif strcmp(Cfg_cached.PRIOR.type, 'niw_custom')
        psi_diag = diag(Cfg_cached.PRIOR.Psi_bar);
        fprintf('  diag(Cfg_cached.PRIOR.Psi_bar) (rezago-1 propio): %s\n', mat2str(psi_diag', 4));
        fprintf('  (esperado: 0.97 en las 6 posiciones; si aparece 1.00, el cache\n');
        fprintf('   corresponde en realidad a Minnesota puro, no a niw_custom)\n');
    elseif strcmp(Cfg_cached.PRIOR.type, 'diffuse')
        fprintf('  (prior diffuse -- sin hiperparametros de shrinkage)\n');
    end

    fprintf('  ND cacheado                                     : %g\n', Cfg_cached.ND);
    fprintf('  ne                                              : %d\n', Results_spec.ne);
    fprintf('\n');

    Results_all.(spec_name) = Results_spec;
    Cfg_all.(spec_name)     = Cfg_cached;
end

% =========================================================================
%  PARTE 2 -- Estabilidad real (check_stability.m del core) sobre el cache
% =========================================================================
fprintf('======================================================\n');
fprintf('  PARTE 2 -- Estabilidad (check_stability.m) por spec\n');
fprintf('======================================================\n\n');

frac_stable_all = struct();
for ss = 1:numel(all_specs)
    spec_name = all_specs{ss};
    if ~isfield(Results_all, spec_name), continue; end
    frac_stable_all.(spec_name) = check_stability(Results_all.(spec_name), Cfg_all.(spec_name));
end

fprintf('  --- mm_minn ---\n');
for ss = 1:numel(minn_specs)
    sn = minn_specs{ss};
    if isfield(frac_stable_all, sn)
        fprintf('  %-38s %6.2f%%\n', sn, 100*frac_stable_all.(sn));
    end
end
fprintf('\n  --- mm_niwcustom ---\n');
for ss = 1:numel(niwc_specs)
    sn = niwc_specs{ss};
    if isfield(frac_stable_all, sn)
        fprintf('  %-38s %6.2f%%\n', sn, 100*frac_stable_all.(sn));
    end
end
fprintf('\n  --- mm_diffuse (referencia bien comportada) ---\n');
for ss = 1:numel(diffuse_specs)
    sn = diffuse_specs{ss};
    if isfield(frac_stable_all, sn)
        fprintf('  %-38s %6.2f%%\n', sn, 100*frac_stable_all.(sn));
    end
end
fprintf('\n');
fprintf('  Si mm_niwcustom sale ~89-97%% aqui (consistente con el smoke test de\n');
fprintf('  ERPT-Chat 11), NO hay mixup de cache -- el problema es otro (ver Parte 3).\n');
fprintf('  Si sale ~25-30%% (igual que mm_minn), confirma la sospecha: el cache de\n');
fprintf('  niwcustom quedo mal escrito/leido.\n\n');

% =========================================================================
%  PARTE 3 -- Distribucion de max|eig(F)| (cuasi-raiz-unitaria)
% =========================================================================
fprintf('======================================================\n');
fprintf('  PARTE 3 -- Distribucion de max|eig(F)| (draws crudos)\n');
fprintf('======================================================\n\n');
fprintf('  Hipotesis: check_stability.m exige solo max|eig|<1 -- no distingue\n');
fprintf('  "bien comportado" (ej. <0.95) de "cuasi-raiz-unitaria" (ej. 0.98-0.999),\n');
fprintf('  que igual produce cumsums de 36 meses muy grandes.\n\n');

buckets = [0, 0.90, 0.95, 0.98, 0.995, 1.0];   % limites de los buckets
bucket_labels = {'<0.90', '0.90-0.95', '0.95-0.98', '0.98-0.995', '0.995-1.0(estable)'};

groups = {minn_specs, niwc_specs, diffuse_specs};
group_labels = {'mm_minn', 'mm_niwcustom', 'mm_diffuse'};

for gg = 1:numel(groups)
    specs_g = groups{gg};
    fprintf('  --- %s (promedio de max|eig| por bucket, entre los 4 specs) ---\n', group_labels{gg});

    bucket_counts_total = zeros(1, numel(buckets)-1);
    nd_total = 0;

    for ss = 1:numel(specs_g)
        sn = specs_g{ss};
        if ~isfield(Results_all, sn), continue; end

        Results_spec = Results_all.(sn);
        Cfg_spec     = Cfg_all.(sn);

        Bdraws = Results_spec.Bdraws;
        nd     = numel(Bdraws);
        n      = Results_spec.LtildeStruct.nvar;

        nex_const = 0;
        if isfield(Cfg_spec, 'NEX'), nex_const = Cfg_spec.NEX; end
        ndummies = 0;
        if isfield(Cfg_spec, 'DUMMIES'), ndummies = numel(Cfg_spec.DUMMIES); end
        nex_total = nex_const + ndummies;

        B_example = Bdraws{1};
        m_rows    = size(B_example, 1);
        p = round((m_rows - nex_total) / n);
        np = p * n;
        F_lower = [eye(np - n), zeros(np - n, n)];

        for s = 1:nd
            B_s = Bdraws{s};
            B_lags = B_s(1:n*p, :);
            F_top = zeros(n, np);
            for l = 1:p
                F_top(:, (l-1)*n+1:l*n) = B_lags((l-1)*n+1:l*n, :)';
            end
            F = [F_top; F_lower];
            mx = max(abs(eig(F)));

            for bb = 1:numel(buckets)-1
                if mx >= buckets(bb) && mx < buckets(bb+1)
                    bucket_counts_total(bb) = bucket_counts_total(bb) + 1;
                    break;
                elseif bb == numel(buckets)-1 && mx < 1
                    bucket_counts_total(bb) = bucket_counts_total(bb) + 1;
                end
            end
        end
        nd_total = nd_total + nd;
    end

    if nd_total > 0
        for bb = 1:numel(bucket_labels)
            fprintf('    %-20s %6.2f%%\n', bucket_labels{bb}, 100*bucket_counts_total(bb)/nd_total);
        end
    else
        fprintf('    [sin datos -- cache no encontrado para este grupo]\n');
    end
    fprintf('\n');
end

fprintf('======================================================\n');
fprintf('Pegar este output completo en el chat.\n\n');


%% -- Helper local ------------------------------------------------------
function out = iif_local(cond, a, b)
    if cond, out = a; else, out = b; end
end
