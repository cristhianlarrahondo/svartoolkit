function fields = get_output_fields()
%GET_OUTPUT_FIELDS  Lista canonica de campos Cfg "de output/presentacion".
%
%   fields = GET_OUTPUT_FIELDS()
%
%   Contexto (Chat 19, Hallazgo 5): las Secciones 5-6 de los pipelines
%   (post-estimacion, export) reutilizaban Cfg_pfa/Cfg_is tal como
%   quedaron cargados ANTES de estimar (Secciones 3-4). Si el usuario
%   editaba la spec despues de estimar para cambiar solo un parametro de
%   presentacion, el cambio no se reflejaba sin re-estimar.
%
%   Esta funcion es la unica fuente de verdad de que campos son "de
%   output" (no afectan el muestreo/estimacion, solo la presentacion
%   posterior). La usa refresh_cfg_output.m para recargar EXCLUSIVAMENTE
%   estos campos desde la spec, sin tocar los campos de estimacion
%   (DATA_FILE, NLAG, HORIZON, MODE, ND, S, Z, SEED, HORIZONS_RESTRICT,
%   etc.), que solo cambian si se vuelve a correr build_posterior/run_pfa/
%   run_is.
%
%   IMPORTANTE: si en el futuro agregas un campo Cfg nuevo, decide
%   explicitamente si es "de output" (va aqui) o "de estimacion" (no se
%   toca por refresh_cfg_output.m). No asumas por defecto.
%
%   NOTA (Chat 19): Cfg.FEVD_HORIZONS deliberadamente NO esta en esta
%   lista, aunque a primera vista parezca "de presentacion" (como
%   SUMMARY_HORIZONS). A diferencia de SUMMARY_HORIZONS (que solo filtra
%   horizontes YA calculados en Ltilde para mostrarlos en consola),
%   Cfg.FEVD_HORIZONS controla QUE HORIZONTES SE CALCULAN dentro de
%   run_pfa.m/run_is.m (ver esos archivos) — cambiarlo requiere volver a
%   correr la estimacion completa, igual que Cfg.SHOCK_IDX cuando afecta
%   la seleccion de shocks para el calculo de FEVD en run_is.m (aunque
%   Cfg.SHOCK_IDX SI esta en esta lista porque tambien controla, por
%   separado, la seleccion de IRFs ya calculadas — su efecto sobre FEVD es
%   la excepcion, no la regla).
%
%   Ver tambien: refresh_cfg_output.m, README_cfg_reference.md

fields = { ...
    'SUMMARY_HORIZONS', ...   % print_summary.m
    'CRED_BANDS', ...         % plot_irfs.m, plot_fevd.m, export_results.m, print_summary.m
    'SHOCK_IDX', ...          % select_irfs.m (via plot_irfs/export_results/print_summary)
    'SHOCK_NAMES', ...        % resolve_shock_name.m (via select_irfs/plot_irfs/plot_fevd/export_results)
    'RESP_IDX', ...           % select_irfs.m, plot_fevd.m, export_results.m
    'IRF_TYPE', ...           % plot_irfs.m, export_results.m
    'IRF_NORM', ...           % plot_irfs.m (via normalize_irfs.m)
    'NORM_SHOCK_IDX', ...     % normalize_irfs.m
    'NORM_VAR', ...           % normalize_irfs.m
    'NORM_HORIZON', ...       % normalize_irfs.m
    'NORM_VALUE', ...         % normalize_irfs.m
    'PLOT_IRFS', ...          % controla si el pipeline llama plot_irfs.m
    'FIG_SUFFIX', ...         % plot_irfs.m, plot_fevd.m
    'OUTPUT_DIR' ...          % plot_irfs.m, plot_fevd.m, export_results.m
};

end

