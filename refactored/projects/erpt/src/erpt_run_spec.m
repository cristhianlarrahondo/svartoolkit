function out = erpt_run_spec(spec_name, PROJ_CFG, USE_CACHE, ND_TARGET, opts)
%ERPT_RUN_SPEC  Carga (cache-first) o corre una spec a ND_TARGET.
%   Helper compartido del proyecto ERPT (promovido de local_run_spec de
%   validate_erpt15/17/19.m). Reset determinista de RNG por spec
%   (`rng('default'); rng(Cfg.SEED)`) inmediatamente antes de run_is, por
%   lo que el resultado numerico es identico sin importar orden/worker.
%
%   opts (opcional):
%     .compute_frac_top (default true)  -> llama diagnose_is_weights dentro
%                                          (imprime Pareto-k, retorna frac_top).
%                                          Poner false en barridos batch (v15).
%     .quiet_cfg        (default false) -> fuerza Cfg.PLOT_IRFS/SAVE_RESULTS=false
%                                          (modo batch de 16 specs).
%   Los draws de run_is NO dependen de opts (solo side-effects).
%   Identico al helper de validate_erpt15/17.m -- reset determinista de RNG
%   por spec (`rng('default'); rng(Cfg.SEED)`) inmediatamente antes de
%   run_is. Captura stable_frac/frac_top/accept_rate/ne sobre el Results
%   CRUDO (con Bdraws) antes de aligerar con rmfield.

    if nargin < 5 || isempty(opts); opts = struct(); end
    if ~isfield(opts, 'compute_frac_top'); opts.compute_frac_top = true;  end
    if ~isfield(opts, 'quiet_cfg');        opts.quiet_cfg        = false; end

    if contains(spec_name, '_aa_')
        transform_type = 'aa';
    else
        transform_type = 'mm';
    end

    out = struct('spec_name', spec_name, 'ok', true, 'err_msg', '', ...
        'used_cache', false, 'transform', transform_type, ...
        'Results', [], 'Dataset', [], 'Cfg', [], 'ERPT', [], ...
        'stable_frac', NaN, 'accept_rate', NaN, 'ne', NaN, 'frac_top', NaN);

    try
        Cfg = struct();
        run(fullfile(PROJ_CFG, [spec_name '.m']));
        if opts.quiet_cfg
            Cfg.PLOT_IRFS    = false;   % modo batch (v15): sin plots por spec
            Cfg.SAVE_RESULTS = false;
        end

        cache_path = fullfile(Cfg.OUTPUT_DIR, 'results_is.mat');
        used_cache = false;
        Results_spec = []; ERPT_spec = []; Dataset_spec = [];

        if USE_CACHE && isfile(cache_path)
            try
                peek = load(cache_path, 'Cfg');
                nd_cached = NaN;
                if isfield(peek, 'Cfg') && isfield(peek.Cfg, 'ND')
                    nd_cached = peek.Cfg.ND;
                end
                if ~isnan(nd_cached) && nd_cached >= ND_TARGET
                    [Results_spec, ERPT_spec, Dataset_spec, Cfg_cached] = load_erpt_run(Cfg.OUTPUT_DIR);
                    used_cache = true;
                    Cfg = Cfg_cached;
                else
                    fprintf('  [%s] cache a ND=%g < objetivo ND=%g -- recalculando desde cero.\n', ...
                        spec_name, nd_cached, ND_TARGET);
                end
            catch
                used_cache = false;
            end
        end

        if ~used_cache
            Cfg.ND = ND_TARGET;
            Dataset_spec = load_data(Cfg);
            validate_cfg(Cfg, Dataset_spec);
            Posterior_spec = build_posterior(Dataset_spec, Cfg);

            % -- RESET DETERMINISTA POR SPEC --
            rng('default'); rng(Cfg.SEED);
            tic;
            Results_spec = run_is(Posterior_spec, Cfg);
            Results_spec.t_elapsed = toc;

            ERPT_spec = calculate_erpt(Results_spec, Dataset_spec, Cfg, transform_type);
            save_erpt_run(Results_spec, ERPT_spec, Dataset_spec, Cfg);
        end

        % -- Diagnosticos que requieren draws crudos (Results.Bdraws) --
        %    Se calculan ANTES de aligerar. save_erpt_run persiste el
        %    Results COMPLETO, asi que en cache-hit tambien traen Bdraws.
        stable_frac = check_stability(Results_spec, Cfg);
        if opts.compute_frac_top
            frac_top = diagnose_is_weights(Results_spec, Cfg);
        else
            frac_top = NaN;
        end
        accept_rate = sum(Results_spec.uw > 0) / Cfg.ND;
        ne_val      = Results_spec.ne;

        % -- Aligerar antes de devolver (draws crudos ya persistidos) --
        Results_light = rmfield(Results_spec, {'Bdraws', 'Sigmadraws', 'Qdraws'});

        out.used_cache  = used_cache;
        out.Results     = Results_light;
        out.Dataset     = Dataset_spec;
        out.Cfg         = Cfg;
        out.ERPT        = ERPT_spec;
        out.stable_frac = stable_frac;
        out.accept_rate = accept_rate;
        out.ne          = ne_val;
        out.frac_top    = frac_top;

    catch ME
        out.ok      = false;
        out.err_msg = ME.message;
    end
end
