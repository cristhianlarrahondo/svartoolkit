function Cfg_updated = refresh_cfg_output(Cfg_stale, spec_path)
%REFRESH_CFG_OUTPUT  Recarga SOLO los campos de output de una spec, sin
%tocar los campos de estimacion, y sin re-estimar.
%
%   Cfg_updated = REFRESH_CFG_OUTPUT(Cfg_stale, spec_path)
%
%   Contexto (Chat 19, Hallazgo 5 — Opcion A aprobada): las Secciones 5-6
%   de los pipelines (post-estimacion, export) usaban Cfg_pfa/Cfg_is tal
%   como quedaron cargados ANTES de run_pfa/run_is (Secciones 3-4). Si el
%   usuario editaba la spec despues de estimar para cambiar solo
%   SUMMARY_HORIZONS, CRED_BANDS, SHOCK_IDX, IRF_TYPE, IRF_NORM,
%   OUTPUT_DIR, etc. (campos que NO afectan el muestreo), el cambio no se
%   reflejaba sin re-correr la estimacion (costosa).
%
%   Esta funcion resuelve eso: vuelve a ejecutar la spec (run()) para
%   obtener una copia 100% fresca de Cfg, y sobreescribe en Cfg_stale
%   UNICAMENTE los campos listados en get_output_fields.m. Todos los
%   demas campos de Cfg_stale (DATA_FILE, NLAG, HORIZON, MODE, ND, S, Z,
%   SEED, HORIZONS_RESTRICT, SPEC_NAME, ...) se preservan intactos, tal
%   como quedaron en el momento de la estimacion — coherentes con
%   Results_pfa/Results_is, que ya fueron calculados con esos valores.
%
%   Entradas:
%     Cfg_stale   struct Cfg tal como quedo en el workspace despues de
%                 estimar (Secciones 3/4 del pipeline)
%     spec_path   ruta absoluta al archivo spec_*.m (mismo que se uso
%                 para estimar). Se re-ejecuta con run() en el workspace
%                 de esta funcion, por lo que NO contamina el caller.
%
%   Salida:
%     Cfg_updated   copia de Cfg_stale con los campos de
%                   get_output_fields.m actualizados a los valores
%                   actuales de la spec en disco.
%
%   Uso tipico en pipeline_template.m / pipeline_bnw.m, Seccion 5:
%
%     Cfg_pfa = refresh_cfg_output(Cfg_pfa, fullfile(PROJ_CFG, [SPEC_PFA '.m']));
%     Cfg_is  = refresh_cfg_output(Cfg_is,  fullfile(PROJ_CFG, [SPEC_IS  '.m']));
%     % ... ahora plot_irfs/plot_fevd/export_results/print_summary ven
%     % los valores de output mas recientes de la spec, sin haber vuelto
%     % a correr build_posterior/run_pfa/run_is.
%
%   NOTA: si editaste un campo de ESTIMACION (S, Z, NLAG, HORIZON, MODE,
%   ND, SEED, HORIZONS_RESTRICT, ...), esta funcion NO lo recoge — eso
%   requiere volver a correr las Secciones 3-4 completas, porque cambia
%   los draws/posterior. Ver get_output_fields.m para la lista exacta de
%   que si se recarga aqui.
%
%   Ver tambien: get_output_fields.m

if ~isfile(spec_path)
    error('refresh_cfg_output:specNotFound', ...
        'refresh_cfg_output: no se encontro el archivo de spec: %s', spec_path);
end

%% ── Ejecutar la spec en el workspace de esta funcion (aislado) ──────────
% run() popula la variable local `Cfg` en ESTE workspace de funcion, no
% en el del caller — por eso Cfg_stale del caller no se ve afectado hasta
% el output explicito de esta funcion.
run(spec_path);
if ~exist('Cfg', 'var')
    error('refresh_cfg_output:specDidNotDefineCfg', ...
        ['refresh_cfg_output: la spec %s no definio la variable Cfg. ' ...
         'Revisa que sea un archivo spec_*.m valido.'], spec_path);
end
Cfg_fresh = Cfg; %#ok<NODEF>

%% ── Sobreescribir SOLO los campos de output ──────────────────────────────
Cfg_updated = Cfg_stale;
output_fields = get_output_fields();

n_refreshed = 0;
for k = 1:numel(output_fields)
    fname = output_fields{k};
    if isfield(Cfg_fresh, fname)
        Cfg_updated.(fname) = Cfg_fresh.(fname);
        n_refreshed = n_refreshed + 1;
    end
end

fprintf('[refresh_cfg_output] %d campos de output recargados desde: %s\n', ...
    n_refreshed, spec_path);

end
