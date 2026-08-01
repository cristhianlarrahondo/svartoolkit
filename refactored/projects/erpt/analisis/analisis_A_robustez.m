% analisis_A_robustez.m -- Barrido de 16 specs + sensibilidad al prior
%   (Ejercicio A, Colombia). Anexo A del paper.
%
%   Decidido en ERPT-Chat 22 (loose end #1 de ERPT-Chat 20): SI se
%   construye como do-file legible, separado de la maquinaria de
%   validacion (validate_erpt15/16.m), que sigue siendo la fuente de
%   verdad de la CASCADA de seleccion de 4 pasos (Paso 1 gate estabilidad
%   >=70%, Paso 2 ancho de banda, Paso 3 desempate cualitativo, Paso 4
%   confirmacion) -- ese criterio NO se recalcula aqui.
%
%   100% CACHE-ONLY: las 16 specs ya fueron estimadas en ERPT-Chat 15/16
%   (results_is.mat persistido por spec). Este archivo NO re-estima nada
%   -- solo carga, recalcula percentiles de reporte a 68% (ERPT-Chat 21
%   decision 1) y tabula. Si algun cache no existe todavia, correr primero
%   validate_erpt15.m (Bloque 1) o validate_erpt16.m.
%
%   Requisito: correr iniciar.m UNA VEZ en la sesion.

%% PASO 0 -- Botones (edita aqui)
WIN_SPEC = 'spec_A_rob_aa_diffuse_lag4_v0';   % ganadora (ERPT-Chat 15/16), como referencia
bandas   = [0.16 0.84];                       % 68% -- banda unica de reporte (Chat 21)
shocks   = {'Cam', 'Dem', 'Ofe'};

spec_names = { ...
    'spec_A_base_aa_diffuse_lag2_v0',   'spec_A_base_aa_diffuse_lag4_v0', ...
    'spec_A_base_aa_minn_lag2_v0',      'spec_A_base_aa_minn_lag4_v0', ...
    'spec_A_base_mm_diffuse_lag2_v0',   'spec_A_base_mm_diffuse_lag4_v0', ...
    'spec_A_base_mm_niwcustom_lag2_v0', 'spec_A_base_mm_niwcustom_lag4_v0', ...
    'spec_A_rob_aa_diffuse_lag2_v0',    'spec_A_rob_aa_diffuse_lag4_v0', ...
    'spec_A_rob_aa_minn_lag2_v0',       'spec_A_rob_aa_minn_lag4_v0', ...
    'spec_A_rob_mm_diffuse_lag2_v0',    'spec_A_rob_mm_diffuse_lag4_v0', ...
    'spec_A_rob_mm_niwcustom_lag2_v0',  'spec_A_rob_mm_niwcustom_lag4_v0' };
n_specs = numel(spec_names);

fprintf('\n=== Ejercicio A -- Anexo de robustez (16 specs, cache-only) ===\n\n');

%% PASO 1 -- Cargar las 16 specs desde cache (sin re-estimar nada)
ERPT_by_spec    = struct();
Results_by_spec = struct();
Cfg_by_spec     = struct();
stable_frac_by_spec = containers.Map();

for ss = 1:n_specs
    sn  = spec_names{ss};
    Cfg = cargar_spec(sn);
    cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
    if ~isfile(cache_path)
        error('analisis_A_robustez:missingCache', ...
            ['No existe cache para %s (%s). Correr validate_erpt15.m ' ...
             '(Bloque 1) o validate_erpt16.m primero -- este do-file no ' ...
             're-estima.'], sn, cache_path);
    end
    [Results_ss, ~, Dataset_ss, Cfg_ss] = load_erpt_run(Cfg.OUTPUT_DIR);

    transform_type = 'mm';
    if contains(sn, '_aa_'); transform_type = 'aa'; end

    % -- Recalcular ERPT a bandas 68% (post-proceso, sin re-estimar) --
    Cfg_ss.CRED_BANDS = bandas;
    ERPT_ss = calculate_erpt(Results_ss, Dataset_ss, Cfg_ss, transform_type);

    ERPT_by_spec.(sn)    = ERPT_ss;
    Results_by_spec.(sn) = Results_ss;
    Cfg_by_spec.(sn)     = Cfg_ss;
    stable_frac_by_spec(sn) = check_stability(Results_ss, Cfg_ss);

    fprintf('  [%2d/%d] %-38s  ne=%-7d  frac.estable=%.4f\n', ...
        ss, n_specs, sn, Results_ss.ne, stable_frac_by_spec(sn));
end
fprintf('\n');

%% PASO 2 -- Tabla comparativa (formato largo/tidy, banda 68%)
T_long = build_erpt_comparison_long(ERPT_by_spec, spec_names, shocks);
fprintf('  Tabla de robustez: %d filas (16 specs x %d choques x price_vars x horizontes)\n\n', ...
    height(T_long), numel(shocks));
disp(head(T_long, 12));
fprintf('  ... (%d filas en total; ver T_long en el workspace)\n\n', height(T_long));

%% PASO 3 -- Notas de exclusion (con evidencia numerica de este cache)
fprintf('  --- Notas de exclusion (Paso 1: gate de estabilidad >= 70%%) ---\n');
for ss = 1:n_specs
    sn = spec_names{ss};
    sf = stable_frac_by_spec(sn);
    if sf < 0.70
        fprintf('  [excluida Paso 1] %-38s  frac.estable=%.4f < 0.70\n', sn, sf);
    end
end
fprintf('\n');
fprintf('  Ganadora (ERPT-Chat 15/16, Pasos 2-4): %s\n', WIN_SPEC);
fprintf('  (la cascada completa de seleccion vive en validate_erpt15.m -- \n');
fprintf('   este do-file no la recalcula, solo tabula el universo de 16 a 68%%.)\n\n');

%% PASO 4 -- Exportar a Excel (mismo directorio de comparaciones que ERPT-Chat 16)
comp_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'output', 'comparison');
if ~isfolder(comp_dir); mkdir(comp_dir); end
out_xlsx = fullfile(comp_dir, 'erpt22_anexoA_robustez_68pct.xlsx');
writetable(T_long, out_xlsx);
fprintf('  Tabla exportada: %s\n\n', out_xlsx);
