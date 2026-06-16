%MAIN_OIL  Punto de entrada del ejemplo: mercado petrolero (BH 2019).
%
%   MAIN_OIL corre el caso de uso completo de mercado petrolero:
%     1. Estima el VAR(24) con spec_oil_pfa (solo sign restrictions)
%     2. Estima el VAR(24) con spec_oil_is  (sign + zero restriction)
%     3. Imprime resumen en consola con print_summary
%     4. Exporta resultados a Excel con export_results
%
%   Propósito pedagógico: documenta el flujo completo de uso del toolkit
%   con un dataset distinto al de referencia (BNW). No duplica lógica
%   de src/ — llama main() del toolkit directamente.
%
%   Uso desde MATLAB (desde cualquier directorio):
%     >> run('ruta/a/refactored/examples/oil_market/main_oil.m')
%   O bien, con refactored/ en el path:
%     >> main_oil
%
%   Convenciones de ruta: NUNCA se usa pwd, cd, ni '..'.
%   Cada ruta se calcula con fileparts(mfilename('fullpath')).

fprintf('\n');
fprintf('================================================================\n');
fprintf('  SVAR Toolkit — Ejemplo: Mercado Petrolero (BH 2019)\n');
fprintf('  Algoritmo: Arias, Rubio-Ramirez y Waggoner (2018)\n');
fprintf('================================================================\n\n');

%% ── Localizar directorios ────────────────────────────────────────────────
ex_root   = fileparts(mfilename('fullpath'));   % .../examples/oil_market/
ref_root  = fileparts(fileparts(ex_root));      % .../refactored/

% Añadir src, config, helpfunctions y validate del toolkit al path
addpath(fullfile(ref_root, 'src'));
addpath(fullfile(ref_root, 'config'));
addpath(fullfile(ref_root, 'helpfunctions'));
addpath(fullfile(ref_root, 'validate'));

% Añadir config del ejemplo al path
addpath(fullfile(ex_root, 'config'));

%% ── Verificar que data_bau.xlsx existe ───────────────────────────────────
data_path = fullfile(ex_root, 'data', 'data_bau.xlsx');
if ~isfile(data_path)
    error('main_oil:dataMissing', ...
        ['Archivo de datos no encontrado:\n  %s\n' ...
         'Asegurate de que data_bau.xlsx esté en examples/oil_market/data/'], ...
        data_path);
end
fprintf('[OK] Datos encontrados: %s\n\n', data_path);

%% ── PASO 1: Estimación PFA (solo sign restrictions) ─────────────────────
fprintf('--- PASO 1: Estimacion PFA (sign restrictions) ---\n');
fprintf('    Spec: spec_oil_pfa  |  nd=%d (testing)\n', 500);
fprintf('    Puede tomar varios minutos...\n\n');

main('spec_oil_pfa');

% Recuperar Results del workspace (main los deja en el caller si no guarda)
% Alternativa: cargar el .mat si SAVE_RESULTS=true. Aquí re-corremos para
% obtener Results explícitamente.
Cfg_pfa = struct();
run(fullfile(ex_root, 'config', 'spec_oil_pfa.m'));
Cfg_pfa = Cfg;
clear Cfg;

rng(Cfg_pfa.SEED);
Dataset_pfa  = load_data(Cfg_pfa);
Post_pfa     = build_posterior(Dataset_pfa, Cfg_pfa);
rng(Cfg_pfa.SEED);
Results_pfa  = run_pfa(Post_pfa, Cfg_pfa);

fprintf('\n--- Resumen IRF — PFA (shock de oferta) ---\n');
print_summary(Results_pfa.LtildeStruct, Dataset_pfa, Cfg_pfa);

%% ── PASO 2: Estimación IS (sign + zero restriction) ─────────────────────
fprintf('\n--- PASO 2: Estimacion IS (sign + zero restrictions) ---\n');
fprintf('    Spec: spec_oil_is  |  nd=%d (testing)\n', 500);
fprintf('    Puede tomar varios minutos...\n\n');

Cfg_is = struct();
run(fullfile(ex_root, 'config', 'spec_oil_is.m'));
Cfg_is = Cfg;
clear Cfg;

rng(Cfg_is.SEED);
Dataset_is   = load_data(Cfg_is);
Post_is      = build_posterior(Dataset_is, Cfg_is);
rng(Cfg_is.SEED);
Results_is   = run_is(Post_is, Cfg_is);

fprintf('\n--- Resumen IRF — IS (shock de oferta) ---\n');
print_summary(Results_is.LtildeStruct, Dataset_is, Cfg_is);

%% ── PASO 3: Exportar resultados PFA a Excel ──────────────────────────────
fprintf('\n--- PASO 3: Exportando resultados PFA a Excel ---\n');
Cfg_pfa.SPEC_NAME = 'spec_oil_pfa';

% Asegurar que el directorio de output existe
out_dir = fullfile(ref_root, 'output', 'tables');
if ~isfolder(out_dir)
    mkdir(out_dir);
end

export_results(Results_pfa, Dataset_pfa, Cfg_pfa);

%% ── PASO 4: Diagnóstico final ────────────────────────────────────────────
fprintf('\n================================================================\n');
fprintf('  RESULTADO FINAL\n');
fprintf('================================================================\n');
fprintf('  PFA  nd       : %d draws\n',    Cfg_pfa.ND);
fprintf('  IS   nd       : %d draws\n',    Cfg_is.ND);
fprintf('  IS   ne (ESS) : %d\n',          Results_is.ne);
accept_rate = sum(Results_is.uw > 0) / Cfg_is.ND;
fprintf('  IS   acept.   : %.4f\n',        accept_rate);
fprintf('  Variables     : %s\n',          strjoin(Dataset_pfa.var_names, ', '));
fprintf('  Frecuencia    : %s\n',          Dataset_pfa.freq);
fprintf('  Horizonte IRF : %d meses\n',    Cfg_pfa.HORIZON);
fprintf('\n');
fprintf('Para produccion: aumentar nd a 5000 (PFA) y ND a 5000 (IS).\n');
fprintf('================================================================\n\n');
