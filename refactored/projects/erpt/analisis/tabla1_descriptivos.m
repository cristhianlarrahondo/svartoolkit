% tabla1_descriptivos.m -- Tabla 1 del paper: estadisticos descriptivos,
%   SOLO full sample (reemplaza la version anterior desglosada por
%   episodio). Script independiente: no corre ningun SVAR, no depende de
%   ninguna spec ni de Results/Posterior -- lee directamente el .xlsx de
%   datos via el loader canonico (load_data.m, core) y calcula los
%   estadisticos sobre las series crudas.
%
%   Requisito: correr iniciar.m UNA VEZ en la sesion (agrega load_data.m
%   al path).
%
%   Variables reportadas (orden de la Tabla 1 del paper) y su nombre en
%   data_erpt_aa.xlsx:
%     NER  -> ner        | pi^M -> imp_inf   | pi^p -> pro_inf
%     pi^c -> con_inf     | EA   -> ea        | IIR  -> ir
%     ToT  -> tot         | BCOM -> com_price | WTI  -> oil_price
%
%   Fuente de datos: refactored/projects/erpt/data/data_erpt_aa.xlsx,
%   hoja "data" (a/a, muestra completa). Es el MISMO archivo que alimenta
%   la spec ganadora (spec_A_rob_aa_diffuse_lag4_v0) -- no se construye
%   ningun dataset nuevo para esta tabla.

%% PASO 0 -- Botones (edita aqui)
data_file   = 'data_erpt_aa.xlsx';   % vive en projects/erpt/data/
vars        = {'ner','imp_inf','pro_inf','con_inf','ea','ir','tot','com_price','oil_price'};
display_lbl = {'NER_t*','pi_t^M','pi_t^p','pi_t^c','EA_t','IIR_t','ToT_t','BCOM_t*','WTI_t*'};
% '*' = variables reportadas como variacion % anual (convencion del paper,
% NER/BCOM/WTI); el resto ya son tasas/variaciones nativas.

%% PASO 1 -- Rutas (nunca pwd/cd/'..')
this_file  = mfilename('fullpath');
if isempty(this_file) || contains(this_file, tempdir)
    this_file = matlab.desktop.editor.getActiveFilename;   % robusto en el Editor
end
ANALISIS_DIR = fileparts(this_file);              % .../projects/erpt/analisis
PROJ_ROOT    = fileparts(ANALISIS_DIR);           % .../projects/erpt

%% PASO 2 -- Cargar datos (loader canonico, SIN estimar nada)
Cfg = struct();
Cfg.DATA_FILE = fullfile(PROJ_ROOT, 'data', data_file);
Cfg.VARS      = vars;             % selecciona y reordena columnas por nombre
% Cfg.VAR_ROLES se deja sin definir -- load_data.m asume 'endogenous' para
% todas por default; el rol no importa aqui, solo se usan los datos crudos.

Dataset = load_data(Cfg);
Y = Dataset.Y_raw;                % [T x 9], orden = vars
T = size(Y, 1);

fprintf('\n=== Tabla 1 -- Descriptivos (full sample) ===\n');
fprintf('  Archivo : %s\n', Dataset.source_file);
fprintf('  Muestra : %s a %s (N=%d)\n\n', ...
    Dataset.dates_str{1}, Dataset.dates_str{end}, T);

%% PASO 3 -- Calcular estadisticos descriptivos
nvar  = numel(vars);
stats = table( ...
    display_lbl(:), ...
    mean(Y, 1)',   median(Y, 1)',   std(Y, 0, 1)', ...
    min(Y, [], 1)', max(Y, [], 1)', repmat(T, nvar, 1), ...
    'VariableNames', {'Variable','Mean','Median','Std_Dev','Min','Max','N'});

disp(stats);

%% PASO 4 -- Exportar a Excel (2 hojas: datos crudos + Tabla 1)
out_dir = fullfile(PROJ_ROOT, 'output', 'tables');
if ~isfolder(out_dir), mkdir(out_dir); end
out_xlsx = fullfile(out_dir, 'Table1_DescriptiveStats_FullSample.xlsx');

% -- Hoja "data": fecha + las 9 series crudas, exactamente como se usaron
T_data = [table(Dataset.dates, 'VariableNames', {'fecha'}), ...
          array2table(Y, 'VariableNames', vars)];
writetable(T_data, out_xlsx, 'Sheet', 'data', 'WriteVariableNames', true);

% -- Hoja "Table 1": estadisticos ya calculados en PASO 3
writetable(stats, out_xlsx, 'Sheet', 'Table 1', 'WriteVariableNames', true);

fprintf('\n  Tabla 1 exportada a: %s\n', out_xlsx);
fprintf('  (hojas: "data" = crudos, "Table 1" = Mean/Median/Std.Dev./Min/Max/N)\n\n');

% NOTA: a diferencia de un workbook armado a mano en Excel, aqui los
% valores de "Table 1" son el resultado de un calculo en MATLAB sobre los
% datos de "data" -- si cambia el .xlsx fuente, basta con volver a correr
% este script (no hay formulas de Excel que mantener sincronizadas).
