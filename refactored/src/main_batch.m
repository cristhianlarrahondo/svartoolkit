function Results_all = main_batch(spec_list, Cfg_overrides)
%MAIN_BATCH  Corre múltiples specs secuencialmente.
%
%   Results_all = MAIN_BATCH(spec_list)
%   Results_all = MAIN_BATCH(spec_list, Cfg_overrides)
%
%   Para cada spec en spec_list:
%     1. Carga la spec con load_spec
%     2. Aplica Cfg_overrides si se proporcionan
%     3. Carga datos con load_data
%     4. Construye el posterior con build_posterior
%     5. Corre el estimador (run_pfa o run_is según Cfg.MODE)
%     6. Guarda Results en Results_all
%
%   Al terminar, llama compare_specs si hay ≥2 specs del mismo modo.
%
%   Entrada:
%     spec_list      cell array de rutas absolutas a specs, e.g.:
%                    {'refactored/config/spec_bnw_pfa.m', ...}
%     Cfg_overrides  struct opcional con campos que sobreescriben los del spec.
%                    Ejemplo: Cfg_overrides.ND = 500; Cfg_overrides.SEED = 99;
%
%   Salida:
%     Results_all   cell array {N×1} con un Results por spec

%% ── Validar entradas ─────────────────────────────────────────────────────
if ~iscell(spec_list) || isempty(spec_list)
    error('main_batch:emptySpecList', ...
        'main_batch: spec_list debe ser un cell array de rutas no vacío.');
end

if nargin < 2 || isempty(Cfg_overrides)
    Cfg_overrides = struct();
end

if ~isstruct(Cfg_overrides)
    error('main_batch:badOverrides', ...
        'main_batch: Cfg_overrides debe ser una struct (o vacío).');
end

n_specs     = numel(spec_list);
Results_all = cell(n_specs, 1);
spec_names  = cell(n_specs, 1);
Dataset_ref = [];   % para compare_specs
Cfg_ref     = [];

%% ── Agregar src al path (si no está ya) ──────────────────────────────────
this_dir  = fileparts(mfilename('fullpath'));
proj_root = fileparts(this_dir);
addpath(fullfile(proj_root, 'src'));
addpath(fullfile(proj_root, 'helpfunctions'));

%% ── Loop sobre specs ─────────────────────────────────────────────────────
sep = repmat('═', 1, 60);

for k = 1:n_specs

    spec_path = spec_list{k};
    fprintf('\n%s\n', sep);
    fprintf('  MAIN_BATCH  [%d/%d]  %s\n', k, n_specs, spec_path);
    fprintf('%s\n\n', sep);

    %% ── Cargar spec ──────────────────────────────────────────────────────
    Cfg = load_spec(spec_path);

    %% ── Aplicar overrides ────────────────────────────────────────────────
    override_fields = fieldnames(Cfg_overrides);
    for fi = 1:numel(override_fields)
        fname      = override_fields{fi};
        Cfg.(fname) = Cfg_overrides.(fname);
    end

    %% ── Nombre de la spec ────────────────────────────────────────────────
    if isfield(Cfg, 'SPEC_NAME') && ~isempty(Cfg.SPEC_NAME)
        sname = Cfg.SPEC_NAME;
    else
        [~, sname, ~] = fileparts(spec_path);
    end
    spec_names{k} = sname;

    %% ── Cargar datos ─────────────────────────────────────────────────────
    Dataset = load_data(Cfg);

    %% ── Construir posterior ──────────────────────────────────────────────
    PosteriorParams = build_posterior(Dataset, Cfg);

    %% ── Correr estimador ─────────────────────────────────────────────────
    if isfield(Cfg, 'SEED') && ~isempty(Cfg.SEED)
        rng(Cfg.SEED);
    end

    mode_upper = upper(Cfg.MODE);
    switch mode_upper
        case 'PFA'
            Results_all{k} = run_pfa(PosteriorParams, Cfg);
        case 'IS'
            Results_all{k} = run_is(PosteriorParams, Cfg);
        otherwise
            error('main_batch:unknownMode', ...
                'main_batch: Cfg.MODE ''%s'' no reconocido. Use ''pfa'' o ''is''.', Cfg.MODE);
    end

    fprintf('\n  [main_batch] Spec %d/%d completada: %s\n', k, n_specs, sname);

    % Guardar Dataset y Cfg de referencia para compare_specs
    if isempty(Dataset_ref)
        Dataset_ref = Dataset;
        Cfg_ref     = Cfg;
    end

end

%% ── compare_specs si hay ≥2 specs del mismo modo ─────────────────────────
modes_run = cellfun(@(R) R.LtildeStruct.mode, Results_all, 'UniformOutput', false);
unique_modes = unique(modes_run);
for mm = 1:numel(unique_modes)
    if sum(strcmp(modes_run, unique_modes{mm})) >= 2
        fprintf('\n%s\n', sep);
        fprintf('  Comparando specs del mismo modo: %s\n', upper(unique_modes{mm}));
        fprintf('%s\n', sep);
        compare_specs(Results_all, spec_names, Dataset_ref, Cfg_ref);
        break;
    end
end

fprintf('\n%s\n', sep);
fprintf('  MAIN_BATCH completado — %d specs procesadas.\n', n_specs);
fprintf('%s\n\n', sep);

end
