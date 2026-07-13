function save_erpt_run(Results, ERPT, Dataset, Cfg)
%SAVE_ERPT_RUN  Persiste una corrida ERPT completa (IS + calculate_erpt).
%
%   SAVE_ERPT_RUN(Results, ERPT, Dataset, Cfg)
%
%   Guarda Results, ERPT, Dataset y Cfg COMPLETOS en
%   <Cfg.OUTPUT_DIR>/results_is.mat.
%
%   Motivo (ver .md de cierre de ERPT-Chat 3, seccion "Pendiente
%   importante: manejo de outputs para ERPT-Chat 4"): con Cfg.ND=3e5,
%   cada una de las 4 corridas baseline toma varios minutos a decenas de
%   minutos. Sin persistencia, cualquier ajuste a la tabla comparativa
%   (ERPT-Chat 4) obligaria a re-correr las 4 estimaciones desde cero.
%
%   Decision confirmada en ERPT-Chat 4: se guarda el .mat COMPLETO
%   (Results_is + ERPT), no una version liviana con solo ratio_draws.
%
%   Requiere Cfg.OUTPUT_DIR y Cfg.SPEC_NAME (todas las specs baseline los
%   definen — ver spec_aa_diffuse_v0.m et al.).
%
%   Ver tambien: load_erpt_run.m (carga lo que esta funcion guarda).

if ~isfield(Cfg, 'OUTPUT_DIR') || isempty(Cfg.OUTPUT_DIR)
    error('save_erpt_run:missingOutputDir', ...
        'Cfg.OUTPUT_DIR no esta definido — no se puede persistir la corrida.');
end
if ~isfield(Cfg, 'SPEC_NAME') || isempty(Cfg.SPEC_NAME)
    error('save_erpt_run:missingSpecName', ...
        'Cfg.SPEC_NAME no esta definido — no se puede persistir la corrida.');
end
if ~isstruct(Results) || ~isstruct(ERPT) || ~isstruct(Dataset)
    error('save_erpt_run:badInputTypes', ...
        'Results, ERPT y Dataset deben ser structs.');
end

if ~isfolder(Cfg.OUTPUT_DIR)
    mkdir(Cfg.OUTPUT_DIR);
end

mat_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
save(mat_path, 'Results', 'ERPT', 'Dataset', 'Cfg', '-v7.3');

fprintf('  [save_erpt_run] %s: guardado en %s\n', Cfg.SPEC_NAME, mat_path);

end
