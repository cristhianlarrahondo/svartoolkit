function main(spec_name)
%MAIN  Punto de entrada único del SVAR Toolkit refactorizado.
%
%   MAIN(SPEC_NAME) carga la configuración especificada por SPEC_NAME,
%   construye la estructura Cfg y despacha al runner correspondiente
%   (run_pfa o run_is) según Cfg.MODE.
%
%   Ejemplo:
%       main('spec_bnw_pfa')
%       main('spec_bnw_is')
%
%   Convenciones de ruta: NUNCA se usa pwd, cd, ni '..'.
%   Cada archivo calcula su ubicación con fileparts(mfilename('fullpath')).

%% ── Localizar raíz del proyecto ─────────────────────────────────────────
proj_root = fileparts(mfilename('fullpath'));   % .../refactored/

%% ── Añadir src/ y config/ al path ──────────────────────────────────────
addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'config'));
addpath(fullfile(proj_root, 'helpfunctions'));

%% ── Validar argumento ───────────────────────────────────────────────────
if nargin < 1 || isempty(spec_name)
    error('main:missingArg', ...
        'Debes pasar el nombre de la spec. Ejemplo: main(''spec_bnw_pfa'')');
end

%% ── Cargar configuración ────────────────────────────────────────────────
cfg_path = fullfile(proj_root, 'config', [spec_name, '.m']);
if ~isfile(cfg_path)
    error('main:specNotFound', ...
        'Config file no encontrado: %s', cfg_path);
end

% Ejecutar el script de config; popula la variable Cfg en el workspace
% de esta función (run no crea variables en el caller por defecto;
% usamos evalin para capturar Cfg después de run).
run(cfg_path);                  % <-- popula Cfg en este workspace

%% ── Inyectar ruta de datos si está vacía ────────────────────────────────
if isempty(Cfg.DATA_FILE)
    Cfg.DATA_FILE = '';         % load_data resolverá la ruta absoluta
end

%% ── Cargar datos ────────────────────────────────────────────────────────
Dataset = load_data(Cfg);

%% ── Construir posterior NIW ─────────────────────────────────────────────
PosteriorParams = build_posterior(Dataset, Cfg);

%% ── Despachar según modo ────────────────────────────────────────────────
rng(Cfg.SEED);   % fijar semilla antes del loop de muestreo

switch lower(Cfg.MODE)
    case 'pfa'
        Results = run_pfa(PosteriorParams, Cfg);
    case 'is'
        Results = run_is(PosteriorParams, Cfg);
    otherwise
        error('main:unknownMode', ...
            'Cfg.MODE desconocido: ''%s''. Usa ''pfa'' o ''is''.', Cfg.MODE);
end

%% ── Plotting ────────────────────────────────────────────────────────────
if Cfg.PLOT_IRFS
    plot_irfs(Results.LtildeStruct, Dataset, Cfg);
end

%% ── Guardar resultados ──────────────────────────────────────────────────
if Cfg.SAVE_RESULTS
    out_dir   = fullfile(proj_root, 'output', 'results');
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    out_file  = fullfile(out_dir, [spec_name, '_', timestamp, '.mat']);
    save(out_file, 'Results', 'Dataset', 'Cfg');
    fprintf('Resultados guardados en: %s\n', out_file);
end

end
