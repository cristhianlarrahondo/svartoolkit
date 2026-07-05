%MAIN_OIL  Punto de entrada del ejemplo: mercado petrolero (BH 2019).
%
%   MAIN_OIL demuestra el flujo completo de uso del SVAR Toolkit con un
%   dataset distinto al de referencia (BNW):
%     1. Estima VAR(24) con spec_oil_pfa (solo sign restrictions)
%     2. Estima VAR(24) con spec_oil_is  (sign + zero restriction)
%     3. Imprime resumen IRF en consola (print_summary)
%     4. Exporta resultados PFA a Excel  (export_results)
%
%   No duplica lógica de src/. Llama directamente a las funciones del toolkit.
%
%   Uso desde MATLAB (cualquier working directory):
%     >> run('ruta/a/refactored/projects/oil_market/main_oil.m')
%   O bien ejecutar el archivo completo con F5 (no sección a sección con F9).
%
%   Convenciones de ruta: NUNCA se usa pwd, cd, ni '..'.

fprintf('\n');
fprintf('================================================================\n');
fprintf('  SVAR Toolkit — Ejemplo: Mercado Petrolero (BH 2019)\n');
fprintf('  Algoritmo: Arias, Rubio-Ramirez y Waggoner (2018)\n');
fprintf('================================================================\n\n');

%% ── Rutas ────────────────────────────────────────────────────────────────
% mfilename('fullpath') devuelve ruta temporal cuando el Editor ejecuta
% secciones (%%) — en ese caso usamos which() para obtener la ruta real.
this_file = mfilename('fullpath');
if contains(this_file, tempdir) || isempty(this_file)
    % Ejecutando desde el Editor (sección) o sin nombre: usar which()
    this_file = which('main_oil');
end
if isempty(this_file)
    error('main_oil:pathError', ...
        ['No se puede resolver la ruta de main_oil.m.\n' ...
         'Asegurate de que refactored/ esté en el MATLAB path, o\n' ...
         'ejecuta el archivo completo con F5 en lugar de sección a sección.']);
end

ex_root  = fileparts(this_file);           % .../projects/oil_market/
ref_root = fileparts(fileparts(ex_root));  % .../refactored/

addpath(fullfile(ref_root, 'src'));
addpath(fullfile(ref_root, 'config'));
addpath(fullfile(ref_root, 'helpfunctions'));
addpath(fullfile(ref_root, 'validate'));
addpath(fullfile(ex_root,  'config'));

%% ── Verificar datos ──────────────────────────────────────────────────────
data_path = fullfile(ex_root, 'data', 'data_bau.xlsx');
if ~isfile(data_path)
    error('main_oil:dataMissing', ...
        'Archivo no encontrado:\n  %s\nColoca data_bau.xlsx en projects/oil_market/data/', ...
        data_path);
end
fprintf('[OK] Datos: %s\n\n', data_path);

%% ── Cargar specs ─────────────────────────────────────────────────────────
clear Cfg;
run(fullfile(ex_root, 'config', 'spec_oil_pfa.m'));
Cfg_pfa = Cfg; clear Cfg;

clear Cfg;
run(fullfile(ex_root, 'config', 'spec_oil_is.m'));
Cfg_is = Cfg; clear Cfg;

% Testing: nd=500; para producción cambiar a 5000
Cfg_pfa.ND          = 500;
Cfg_pfa.PLOT_IRFS   = false;
Cfg_is.ND           = 500;
Cfg_is.MAX_IS_DRAWS = 500;
Cfg_is.PLOT_IRFS    = false;

%% ── PASO 1: PFA ──────────────────────────────────────────────────────────
fprintf('--- PASO 1: Estimacion PFA (nd=%d) ---\n', Cfg_pfa.ND);
rng(Cfg_pfa.SEED);
Dataset_pfa = load_data(Cfg_pfa);
Post_pfa    = build_posterior(Dataset_pfa, Cfg_pfa);
rng(Cfg_pfa.SEED);
Results_pfa = run_pfa(Post_pfa, Cfg_pfa);

fprintf('\n--- Resumen IRF PFA (shock de oferta) ---\n');
print_summary(Results_pfa.LtildeStruct, Dataset_pfa, Cfg_pfa);

%% ── PASO 2: IS ───────────────────────────────────────────────────────────
fprintf('\n--- PASO 2: Estimacion IS (nd=%d) ---\n', Cfg_is.ND);
rng(Cfg_is.SEED);
Dataset_is = load_data(Cfg_is);
Post_is    = build_posterior(Dataset_is, Cfg_is);
rng(Cfg_is.SEED);
Results_is = run_is(Post_is, Cfg_is);

fprintf('\n--- Resumen IRF IS (shock de oferta) ---\n');
print_summary(Results_is.LtildeStruct, Dataset_is, Cfg_is);

%% ── PASO 3: Exportar PFA ─────────────────────────────────────────────────
fprintf('\n--- PASO 3: Exportando resultados PFA ---\n');
out_dir = fullfile(ref_root, 'output', 'tables');
if ~isfolder(out_dir), mkdir(out_dir); end
export_results(Results_pfa, Dataset_pfa, Cfg_pfa);

%% ── Diagnóstico final ────────────────────────────────────────────────────
accept_rate = sum(Results_is.uw > 0) / Cfg_is.ND;
fprintf('\n================================================================\n');
fprintf('  RESULTADO FINAL\n');
fprintf('  PFA nd       : %d\n', Cfg_pfa.ND);
fprintf('  IS  nd       : %d  |  ne(ESS)=%d  |  acept=%.4f\n', ...
        Cfg_is.ND, Results_is.ne, accept_rate);
fprintf('  Variables    : %s\n', strjoin(Dataset_pfa.var_names, ', '));
fprintf('  Frecuencia   : %s  |  Horizonte: %d meses\n', ...
        Dataset_pfa.freq, Cfg_pfa.HORIZON);
fprintf('  Para produccion: aumentar ND a 5000 en ambas specs.\n');
fprintf('================================================================\n\n');

