function main(spec_name)
%MAIN  Punto de entrada único del SVAR Toolkit refactorizado.
%
%   MAIN(SPEC_NAME) carga la configuración especificada por SPEC_NAME,
%   construye la struct Cfg y despacha al runner correspondiente
%   según Cfg.MODE: 'pfa', 'is' ó 'timing'.
%
%   Ejemplo:
%       main('spec_bnw_pfa')
%       main('spec_bnw_is')
%       main('spec_timing_4L1Z')
%       main('spec_timing_12L3Z')
%
%   Convenciones de ruta: NUNCA se usa pwd, cd, ni '..'.
%   Cada archivo calcula su ubicación con fileparts(mfilename('fullpath')).

%% ── Localizar raíz del proyecto ─────────────────────────────────────────
proj_root = fileparts(mfilename('fullpath'));   % .../refactored/

%% ── Añadir src/, config/ y helpfunctions/ al path ───────────────────────
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

% Los configs nuevos (timing) son funciones que devuelven Cfg.
% Los configs anteriores (pfa, is) son scripts que populan Cfg.
% Detectar por la primera línea: si empieza con 'function', es función.
fid  = fopen(cfg_path, 'r');
line = strtrim(fgetl(fid));
fclose(fid);

if startsWith(line, 'function')
    % Config tipo función: llamar por nombre y recibir Cfg
    cfg_func = str2func(spec_name);
    Cfg = cfg_func();
else
    % Config tipo script: run() popula Cfg en este workspace
    run(cfg_path);
end

%% ── Validar configuración ───────────────────────────────────────────────
addpath(fullfile(proj_root, 'validate'));
validate_cfg(Cfg);

%% ── Cargar datos según modo ─────────────────────────────────────────────
if strcmp(Cfg.MODE, 'timing')
    Dataset = load_data_timing(Cfg);
else
    if isempty(Cfg.DATA_FILE)
        Cfg.DATA_FILE = '';
    end
    Dataset = load_data(Cfg);
end

%% ── Construir posterior NIW ─────────────────────────────────────────────
Posterior = build_posterior(Dataset, Cfg);

%% ── Despachar según modo ────────────────────────────────────────────────
switch lower(Cfg.MODE)
    case 'pfa'
        rng(Cfg.SEED);
        Results = run_pfa(Posterior, Cfg);

    case 'is'
        rng(Cfg.SEED);
        Results = run_is(Posterior, Cfg);

    case 'timing'
        % run_timing gestiona su propio rng internamente
        Results = run_timing(Cfg, Dataset, Posterior);
        fprintf('\n=== Timing %d completado ===\n', Cfg.TIMING_VARIANT);
        fprintf('  tElapsed : %.1f seg\n', Results.tElapsed);
        fprintf('  count    : %d draws satisfacen signs\n', Results.count);
        fprintf('  ESS      : %d\n', Results.ne);
        fprintf('  ESS/count: %.4f\n', Results.ne / max(Results.count, 1));

    otherwise
        error('main:unknownMode', ...
            'Cfg.MODE desconocido: ''%s''. Usa ''pfa'', ''is'' o ''timing''.', Cfg.MODE);
end

%% ── Plotting (sólo modos pfa/is) ────────────────────────────────────────
if ismember(lower(Cfg.MODE), {'pfa', 'is'}) && Cfg.PLOT_IRFS
    plot_irfs(Results.LtildeStruct, Dataset, Cfg);
end

%% ── Guardar resultados (sólo si se pide) ────────────────────────────────
if isfield(Cfg, 'SAVE_RESULTS') && Cfg.SAVE_RESULTS
    out_dir   = fullfile(proj_root, 'output', 'results');
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    out_file  = fullfile(out_dir, [spec_name, '_', timestamp, '.mat']);
    save(out_file, 'Results', 'Dataset', 'Cfg');
    fprintf('Resultados guardados en: %s\n', out_file);
end

end
