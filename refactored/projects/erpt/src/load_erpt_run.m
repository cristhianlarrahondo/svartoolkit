function [Results, ERPT, Dataset, Cfg] = load_erpt_run(output_dir)
%LOAD_ERPT_RUN  Carga una corrida ERPT previamente persistida por save_erpt_run.m.
%
%   [Results, ERPT, Dataset, Cfg] = LOAD_ERPT_RUN(output_dir)
%
%   output_dir  ruta absoluta a la carpeta OUTPUT_DIR de la spec (la
%               misma que Cfg.OUTPUT_DIR al momento de guardar).
%
%   Error explicito si <output_dir>/results_is.mat no existe — no crea
%   ni corre nada, es responsabilidad del llamador decidir si corre la
%   estimacion o usa el cache.
%
%   Ver tambien: save_erpt_run.m

if nargin < 1 || isempty(output_dir)
    error('load_erpt_run:missingOutputDir', 'output_dir es obligatorio.');
end

mat_path = fullfile(output_dir, 'results_is.mat');
if ~isfile(mat_path)
    error('load_erpt_run:notFound', ...
        'No existe %s — la corrida no ha sido persistida todavia.', mat_path);
end

S = load(mat_path, 'Results', 'ERPT', 'Dataset', 'Cfg');
if ~all(isfield(S, {'Results', 'ERPT', 'Dataset', 'Cfg'}))
    error('load_erpt_run:badFile', ...
        '%s no contiene los 4 campos esperados (Results, ERPT, Dataset, Cfg).', mat_path);
end

Results = S.Results;
ERPT    = S.ERPT;
Dataset = S.Dataset;
Cfg     = S.Cfg;

fprintf('  [load_erpt_run] Cargado desde cache: %s\n', mat_path);

end
