%PIPELINE  ERPT — solo Importance Sampler (no hay flujo PFA en este proyecto)
%
%   FLUJO:
%     Seccion 0 — Setup de rutas (REF_ROOT)                    (una sola vez)
%     Seccion 1 — SPEC_NAME editable + cargar datos + carpetas de output
%     Seccion 2 — Revisar config (restricciones Z/S en lenguaje natural)
%     Seccion 3 — Estimacion IS
%     Seccion 4 — Post-estimacion
%     Seccion 5 — Export
%
%   Para cambiar de variante (spec_v0, spec_v1, ...): editar UNA linea en
%   la Seccion 1 (SPEC_NAME) y volver a correr desde ahi. Cada spec define
%   su propio Cfg.OUTPUT_DIR = output/<SPEC_NAME>/, asi que las corridas
%   de distintas variantes nunca se pisan entre si.

%% ── Seccion 0 — Setup de rutas ───────────────────────────────────────────
%
%  ┌─────────────────────────────────────────────────────────────────────┐
%  │  EDITAR SOLO ESTA LINEA. Luego Ctrl+Enter aqui.                     │
%  └─────────────────────────────────────────────────────────────────────┘
REF_ROOT = '/Users/cristhianlarrahondo/Documents/GitHub/svartoolkit/refactored';   % ← EDITAR (motor compartido)

PROJ_ROOT = fullfile(REF_ROOT, 'projects', 'erpt');   % este proyecto
PROJ_CFG  = fullfile(PROJ_ROOT, 'config');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(PROJ_CFG);

fprintf('\n[Setup OK]\n');
fprintf('  REF_ROOT  : %s\n', REF_ROOT);
fprintf('  PROJ_ROOT : %s\n\n', PROJ_ROOT);

%% ── Seccion 1 — SPEC_NAME editable + cargar datos + carpetas output ─────
%
%  ┌─────────────────────────────────────────────────────────────────────┐
%  │  EDITAR SOLO ESTA LINEA para cambiar de variante.                   │
%  │  Debe existir config/<SPEC_NAME>.m (ej. 'spec_v0', 'spec_v1', ...)  │
%  └─────────────────────────────────────────────────────────────────────┘
SPEC_NAME = 'spec_v1';

clear Cfg;
run(fullfile(PROJ_CFG, [SPEC_NAME '.m']));
Cfg_is = Cfg; clear Cfg;

% Carpetas de output propias de esta spec (Cfg_is.OUTPUT_DIR = .../output/<SPEC_NAME>/)
OUT_FIG = fullfile(Cfg_is.OUTPUT_DIR, 'figures');
OUT_TAB = fullfile(Cfg_is.OUTPUT_DIR, 'tables');
if ~isfolder(OUT_FIG), mkdir(OUT_FIG); end
if ~isfolder(OUT_TAB), mkdir(OUT_TAB); end

fprintf('  Spec activa : %s\n', SPEC_NAME);
fprintf('  Figures  → %s\n', OUT_FIG);
fprintf('  Tables   → %s\n\n', OUT_TAB);

Dataset = load_data(Cfg_is);

fprintf('════════════════════════════════════════════\n');
fprintf('  DATOS: ERPT\n');
fprintf('════════════════════════════════════════════\n');
fprintf('  Spec activa: %s\n', SPEC_NAME);
fprintf('  Archivo    : %s\n', Cfg_is.DATA_FILE);
fprintf('  Frecuencia : %s\n', Dataset.freq);
dates = Dataset.dates;
if iscell(dates)
    fprintf('  Inicio     : %s\n', dates{1});
    fprintf('  Fin        : %s\n', dates{end});
else
    fprintf('  Inicio     : %s\n', datestr(dates(1)));
    fprintf('  Fin        : %s\n', datestr(dates(end)));
end
fprintf('  T (total)  : %d observaciones\n', size(Dataset.Y_raw, 1));
fprintf('  T (modelo) : %d obs (tras lags: T-%d=%d)\n', ...
    Cfg_is.NLAG, size(Dataset.Y_raw,1), size(Dataset.Y_raw,1)-Cfg_is.NLAG);
fprintf('  n (endo)   : %d variables\n', Dataset.nvar);
fprintf('  p (lags)   : %d\n', Cfg_is.NLAG);
fprintf('════════════════════════════════════════════\n\n');

endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
endo_names = Dataset.var_names(endo_mask);
endo_labs  = Dataset.var_labels(endo_mask);
Y_data     = Dataset.Y_raw;

fprintf('  %-4s  %-15s  %-32s  %8s  %8s  %8s  %8s\n', ...
    'Idx', 'Variable', 'Label', 'Media', 'Std', 'Min', 'Max');
fprintf('  %s\n', repmat('─', 1, 82));
for i = 1:numel(endo_names)
    col = Y_data(:,i);
    fprintf('  %-4d  %-15s  %-32s  %8.4f  %8.4f  %8.4f  %8.4f\n', ...
        i, endo_names{i}, endo_labs{i}, ...
        mean(col), std(col), min(col), max(col));
end
fprintf('\n');
n_nan = sum(isnan(Y_data(:)));
if n_nan == 0
    fprintf('  [OK] Sin NaN en la muestra.\n\n');
else
    fprintf('  [ALERTA] %d NaN encontrados.\n\n', n_nan);
end

%% ── Seccion 2 — Revisar configuracion ────────────────────────────────────
%
%  Imprime parametros del modelo y traduce las restricciones Z/S a
%  lenguaje natural (variable, shock, horizonte, direccion). Solo IS:
%  no hay rama PFA que condicionar.

fprintf('\n════════════════════════════════════════════\n');
fprintf('  CONFIG: %s (IS)\n', Cfg_is.SPEC_NAME);
fprintf('════════════════════════════════════════════\n');
fprintf('  Lags (p)   : %d\n', Cfg_is.NLAG);
fprintf('  Horizonte  : %d\n', Cfg_is.HORIZON);
fprintf('  FEVD en h  : %d\n', Cfg_is.INDEX_FEVD);
fprintf('  Draws (nd) : %d\n', Cfg_is.ND);
fprintf('  Semilla    : %d\n', Cfg_is.SEED);
fprintf('  Output dir : %s\n', Cfg_is.OUTPUT_DIR);
fprintf('  Horizontes restricciones: ');
fprintf('%d ', Cfg_is.HORIZONS_RESTRICT); fprintf('\n\n');

vnames = endo_names;   % del Dataset cargado en Seccion 1
n_v    = numel(Cfg_is.S);

fprintf('  Restricciones de SIGNO (S):\n');
any_s = false;
for k = 1:n_v
    if ~isempty(Cfg_is.S{k})
        any_s = true;
        for row = 1:size(Cfg_is.S{k},1)
            sv = Cfg_is.S{k}(row,:);
            vi = find(abs(sv) > 0);
            if vi <= numel(vnames), vn = vnames{vi};
            else, vn = sprintf('var_%d',vi); end
            if sv(vi) > 0, dir = 'POSITIVO'; else, dir = 'NEGATIVO'; end
            h_str = format_horizons_erpt(Cfg_is.HORIZONS_RESTRICT);
            fprintf('    Shock %d (%s)  →  %s (var %d): %s en %s\n', ...
                k, Cfg_is.SHOCK_NAMES{k}, vn, vi, dir, h_str);
        end
    end
end
if ~any_s, fprintf('    (ninguna)\n'); end

fprintf('  Restricciones de CERO (Z):\n');
any_z = false;
for k = 1:n_v
    if ~isempty(Cfg_is.Z{k})
        any_z = true;
        for row = 1:size(Cfg_is.Z{k},1)
            zv = Cfg_is.Z{k}(row,:);
            vi = find(abs(zv) > 0);
            if vi <= numel(vnames), vn = vnames{vi};
            else, vn = sprintf('var_%d',vi); end
            h_str = format_horizons_erpt(Cfg_is.HORIZONS_RESTRICT);
            fprintf('    Shock %d (%s)  →  %s (var %d): SIN RESPUESTA en %s\n', ...
                k, Cfg_is.SHOCK_NAMES{k}, vn, vi, h_str);
        end
    end
end
if ~any_z, fprintf('    (ninguna)\n'); end

% Matriz de restricciones completa: vista de conjunto variables x shocks,
% complementaria a la traduccion fila por fila de arriba.
print_restriction_matrix(Cfg_is, Dataset);

fprintf('\n[Tip] Si algo no es lo que esperabas, edita la spec activa y vuelve a correr esta seccion.\n\n');

%% ── Seccion 3 — Estimacion IS ────────────────────────────────────────────
%
%  IS: sign + zero restrictions (Algorithm 3, ARW 2018).

fprintf('\n--- Estimacion IS (nd=%d) ---\n', Cfg_is.ND);
validate_cfg(Cfg_is, Dataset);
Post_is    = build_posterior(Dataset, Cfg_is);
rng(Cfg_is.SEED);
Results_is = run_is(Post_is, Cfg_is);

%% ── Seccion 4 — Post-estimacion ──────────────────────────────────────────
%
%  Todas las funciones de analisis. Figuras y tablas SIEMPRE en
%  output/<SPEC_NAME>/ (via Cfg_is.OUTPUT_DIR), nunca en refactored/output/.
%  Requiere: Seccion 3 ejecutada.

fprintf('\n════════════════════════════════════════════\n');
fprintf('  POST-ESTIMACION: %s\n', Cfg_is.SPEC_NAME);
fprintf('════════════════════════════════════════════\n\n');

% Recargar SOLO los campos de output (no afecta el muestreo ya corrido)
Cfg_is = refresh_cfg_output(Cfg_is, fullfile(PROJ_CFG, [SPEC_NAME '.m']));

% 4a. Resumen numerico
fprintf('--- IRF Summary ---\n');
print_summary(Results_is.LtildeStruct, Dataset, Cfg_is);

% 4b. IRFs en pantalla + guardadas
fprintf('--- Graficas IRF ---\n');
plot_irfs(Results_is.LtildeStruct, Dataset, Cfg_is);

% 4c. FEVD
fprintf('--- FEVD ---\n');
plot_fevd(Results_is, Dataset, Cfg_is);

% 4d. Estabilidad
fprintf('--- Estabilidad del VAR ---\n');
check_stability(Results_is, Cfg_is);

% 4e. Diagnostico pesos IS
fprintf('--- Diagnostico pesos IS ---\n');
diagnose_is_weights(Results_is, Cfg_is);

%% ── Seccion 5 — Export ───────────────────────────────────────────────────
%
%  Exporta resultados a Excel. Archivo en output/<SPEC_NAME>/tables/
%  (via Cfg_is.OUTPUT_DIR), nunca en refactored/output/.

fprintf('--- Export → Excel ---\n');
export_results(Results_is, Dataset, Cfg_is);

fprintf('\n[OK] Tablas  → %s\n', fullfile(Cfg_is.OUTPUT_DIR, 'tables'));
fprintf('[OK] Figuras → %s\n\n', fullfile(Cfg_is.OUTPUT_DIR, 'figures'));

%% ── Funcion auxiliar ─────────────────────────────────────────────────────

function s = format_horizons_erpt(H)
    if isscalar(H)
        s = sprintf('h=%d', H);
    elseif isequal(H(:)', H(1):H(end))
        s = sprintf('h=%d a h=%d', H(1), H(end));
    else
        s = ['h=' strjoin(arrayfun(@num2str, H(:)', 'UniformOutput', false), ',')];
    end
end
