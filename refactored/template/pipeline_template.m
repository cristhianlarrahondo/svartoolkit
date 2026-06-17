%PIPELINE_TEMPLATE  Flujo completo de análisis SVAR — plantilla genérica.
%
%   Ejecuta este script SECCIÓN A SECCIÓN con Ctrl+Enter (o F9).
%   Cada sección %% es independiente y puede correrse en cualquier orden
%   una vez que la Sección 0 haya sido ejecutada en la sesión.
%
%   FLUJO COMPLETO:
%     Sección 0 — Setup de rutas         (ejecutar primero, una sola vez)
%     Sección 1 — Cargar y explorar datos
%     Sección 2 — Revisar configuración
%     Sección 3 — Estimación PFA
%     Sección 4 — Estimación IS
%     Sección 5 — Post-estimación (IRFs, FEVD, diagnósticos)
%     Sección 6 — Export de resultados
%
%   ANTES DE EMPEZAR:
%     1. Copia template/ a examples/mi_caso/
%     2. Edita REF_ROOT en la Sección 0 con la ruta absoluta a refactored/
%     3. Edita EX_NAME con el nombre de tu carpeta de ejemplo
%     4. Ajusta spec_template_pfa.m y spec_template_is.m con tu modelo

%% ── Sección 0 — Setup de rutas ───────────────────────────────────────────
%
%  ┌─────────────────────────────────────────────────────────────────────┐
%  │  EDITAR ESTAS DOS LÍNEAS. Luego Ctrl+Enter aquí y ya no se tocan.  │
%  └─────────────────────────────────────────────────────────────────────┘
REF_ROOT = '/ruta/absoluta/a/refactored';   % ← EDITAR (sin barra final)
EX_NAME  = 'mi_caso';                        % ← EDITAR nombre de tu ejemplo
%  Ejemplos:
%    REF_ROOT = '/Users/cristhian/repos/svartoolkit/refactored';
%    EX_NAME  = 'oil_market';
%
%  Por qué hardcodeamos la ruta:
%  mfilename('fullpath') falla cuando se ejecutan secciones %% desde el
%  Editor de MATLAB (copia el archivo a una carpeta temporal). Al poner
%  la ruta explícita aquí, Ctrl+Enter funciona sin problema.

EX_ROOT    = fullfile(REF_ROOT, 'examples', EX_NAME);
EX_CFG     = fullfile(EX_ROOT,  'config');
EX_DATA    = fullfile(EX_ROOT,  'data');
OUT_FIG    = fullfile(REF_ROOT, 'output', 'figures');
OUT_TAB    = fullfile(REF_ROOT, 'output', 'tables');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(EX_CFG);

if ~isfolder(OUT_FIG), mkdir(OUT_FIG); end
if ~isfolder(OUT_TAB), mkdir(OUT_TAB); end

fprintf('\n[Setup OK]\n');
fprintf('  REF_ROOT : %s\n', REF_ROOT);
fprintf('  Ejemplo  : %s\n', EX_NAME);
fprintf('  Figures  → %s\n', OUT_FIG);
fprintf('  Tables   → %s\n', OUT_TAB);

%% ── Sección 1 — Cargar y explorar datos ─────────────────────────────────
%
%  Carga el dataset y muestra un resumen: variables, fechas, estadísticas.
%  Requiere: Sección 0 ejecutada.

% Cfg mínima para cargar datos (usa spec_pfa para tener NLAG y SCALE_FACTOR)
clear Cfg;
SPEC_PFA = 'spec_template_pfa';   % ← EDITAR: nombre de tu spec PFA
run(fullfile(EX_CFG, [SPEC_PFA '.m']));
Cfg_eda = Cfg; clear Cfg;

Dataset = load_data(Cfg_eda);

fprintf('\n');
fprintf('════════════════════════════════════════════\n');
fprintf('  DATOS: %s\n', EX_NAME);
fprintf('════════════════════════════════════════════\n');
fprintf('  Archivo  : %s\n', Cfg_eda.DATA_FILE);
fprintf('  Frec.    : %s\n', Dataset.freq);

% Fechas
dates = Dataset.dates;
if iscell(dates)
    fprintf('  Inicio   : %s\n', dates{1});
    fprintf('  Fin      : %s\n', dates{end});
else
    fprintf('  Inicio   : %s\n', datestr(dates(1)));
    fprintf('  Fin      : %s\n', datestr(dates(end)));
end
fprintf('  T (total): %d observaciones\n',   size(Dataset.Y_raw, 1));
fprintf('  T (modelo): %d obs (tras lags: T-%d=%d)\n', Cfg_eda.NLAG, size(Dataset.Y_raw,1), size(Dataset.Y_raw,1)-Cfg_eda.NLAG);
fprintf('  n (endo) : %d variables\n',       Dataset.nvar);
fprintf('  p (lags) : %d\n',                 Cfg_eda.NLAG);
fprintf('════════════════════════════════════════════\n\n');

% Tabla de variables
endo_mask  = strcmp(Dataset.var_roles, 'endogenous');
endo_names = Dataset.var_names(endo_mask);
endo_labs  = Dataset.var_labels(endo_mask);
Y_data     = Dataset.Y_raw;   % [T x n] muestra efectiva (sin lags iniciales)

fprintf('  %-4s  %-20s  %-30s  %8s  %8s  %8s  %8s\n', ...
    'Idx', 'Variable', 'Label', 'Media', 'Std', 'Min', 'Max');
fprintf('  %s\n', repmat('─', 1, 80));
for i = 1:numel(endo_names)
    col = Y_data(:,i);
    fprintf('  %-4d  %-20s  %-30s  %8.4f  %8.4f  %8.4f  %8.4f\n', ...
        i, endo_names{i}, endo_labs{i}, ...
        mean(col), std(col), min(col), max(col));
end
fprintf('\n');

% Verificación de NaN
n_nan = sum(isnan(Y_data(:)));
if n_nan == 0
    fprintf('  [OK] Sin valores faltantes (NaN) en la muestra.\n\n');
else
    fprintf('  [ALERTA] %d valores faltantes (NaN) encontrados.\n\n', n_nan);
end

%% ── Sección 2 — Revisar configuración ───────────────────────────────────
%
%  Imprime todos los parámetros relevantes de la spec y traduce las
%  restricciones Z y S a lenguaje natural.
%  Requiere: Sección 0 ejecutada.

SPEC_IS  = 'spec_template_is';    % ← EDITAR: nombre de tu spec IS

% Cargar ambas specs
clear Cfg;
run(fullfile(EX_CFG, [SPEC_PFA '.m']));
Cfg_pfa = Cfg; clear Cfg;

clear Cfg;
run(fullfile(EX_CFG, [SPEC_IS '.m']));
Cfg_is = Cfg; clear Cfg;

% Imprimir resumen de config
for ii = 1:2
    if ii == 1, Cfg_show = Cfg_pfa; label = 'PFA';
    else,        Cfg_show = Cfg_is;  label = 'IS';  end

    fprintf('\n════════════════════════════════════════════\n');
    fprintf('  CONFIG: %s  (%s)\n', Cfg_show.SPEC_NAME, label);
    fprintf('════════════════════════════════════════════\n');
    fprintf('  Datos       : %s\n', Cfg_show.DATA_FILE);
    fprintf('  Lags (p)    : %d\n', Cfg_show.NLAG);
    fprintf('  Constante   : %s\n', bool2str(Cfg_show.NEX > 0));
    fprintf('  Horizonte   : %d períodos\n', Cfg_show.HORIZON);
    fprintf('  FEVD en h   : %d\n', Cfg_show.INDEX_FEVD);
    fprintf('  Draws (nd)  : %d\n', Cfg_show.ND);
    fprintf('  Semilla     : %d\n', Cfg_show.SEED);
    fprintf('  Scale factor: %g\n', Cfg_show.SCALE_FACTOR);
    fprintf('  Horizontes restricciones: ');
    fprintf('%d ', Cfg_show.HORIZONS_RESTRICT); fprintf('\n');
    fprintf('\n');

    % Tabla de restricciones en lenguaje natural
    % Obtener nombres de variables desde Dataset si está disponible
    if exist('Dataset', 'var') && isfield(Dataset, 'var_names')
        em = strcmp(Dataset.var_roles, 'endogenous');
        vnames = Dataset.var_names(em);
    else
        vnames = arrayfun(@(i) sprintf('var_%d', i), ...
                          1:numel(Cfg_show.S), 'UniformOutput', false);
    end
    n_v = numel(Cfg_show.S);

    fprintf('  Restricciones de SIGNO (S):\n');
    any_sign = false;
    for k = 1:n_v
        if ~isempty(Cfg_show.S{k})
            any_sign = true;
            for row = 1:size(Cfg_show.S{k}, 1)
                sv    = Cfg_show.S{k}(row,:);
                vi    = find(abs(sv) > 0);
                sgn   = sv(vi);
                vname = get_varname(vnames, vi);
                if sgn > 0, dir = 'POSITIVO'; else, dir = 'NEGATIVO'; end
                h_str = format_horizons(Cfg_show.HORIZONS_RESTRICT);
                fprintf('    Shock %d → %s (%s): %s en %s\n', ...
                    k, vname, sprintf('var_%d',vi), dir, h_str);
            end
        end
    end
    if ~any_sign, fprintf('    (ninguna)\n'); end

    fprintf('  Restricciones de CERO (Z):\n');
    any_zero = false;
    for k = 1:n_v
        if ~isempty(Cfg_show.Z{k})
            any_zero = true;
            for row = 1:size(Cfg_show.Z{k}, 1)
                zv    = Cfg_show.Z{k}(row,:);
                vi    = find(abs(zv) > 0);
                vname = get_varname(vnames, vi);
                h_str = format_horizons(Cfg_show.HORIZONS_RESTRICT);
                fprintf('    Shock %d → %s (%s): SIN RESPUESTA en %s\n', ...
                    k, vname, sprintf('var_%d',vi), h_str);
            end
        end
    end
    if ~any_zero, fprintf('    (ninguna)\n'); end
end

fprintf('\n[Tip] Si algo no es lo que esperabas, edita la spec y vuelve a correr esta sección.\n\n');

%% ── Sección 3 — Estimación PFA ───────────────────────────────────────────
%
%  Corre el algoritmo PFA y guarda Results_pfa en el workspace.
%  Requiere: Sección 0 ejecutada. Dataset opcional (si no, lo carga).

clear Cfg;
run(fullfile(EX_CFG, [SPEC_PFA '.m']));
Cfg_pfa = Cfg; clear Cfg;
Cfg_pfa.PLOT_IRFS = false;   % gráficas en Sección 5

if ~exist('Dataset', 'var')
    Dataset = load_data(Cfg_pfa);
end

fprintf('\n--- Estimación PFA ---\n');
validate_cfg(Cfg_pfa);   % verifica config antes de correr
Post_pfa    = build_posterior(Dataset, Cfg_pfa);
rng(Cfg_pfa.SEED);
Results_pfa = run_pfa(Post_pfa, Cfg_pfa);

%% ── Sección 4 — Estimación IS ────────────────────────────────────────────
%
%  Corre el algoritmo IS y guarda Results_is en el workspace.
%  Requiere: Sección 0 ejecutada. Dataset opcional (si no, lo carga).

clear Cfg;
run(fullfile(EX_CFG, [SPEC_IS '.m']));
Cfg_is = Cfg; clear Cfg;
Cfg_is.PLOT_IRFS = false;

if ~exist('Dataset', 'var')
    Dataset = load_data(Cfg_is);
end

fprintf('\n--- Estimación IS ---\n');
validate_cfg(Cfg_is);
Post_is    = build_posterior(Dataset, Cfg_is);
rng(Cfg_is.SEED);
Results_is = run_is(Post_is, Cfg_is);

%% ── Sección 5 — Post-estimación ──────────────────────────────────────────
%
%  IRFs, FEVD, diagnósticos. Gráficas en pantalla + guardadas en output/.
%  Requiere: Secciones 3 y 4 ejecutadas.

fprintf('\n════════════════════════════════════════════\n');
fprintf('  POST-ESTIMACIÓN\n');
fprintf('════════════════════════════════════════════\n\n');

% ── 5a. Resumen numérico en consola ──────────────────────────────────────
fprintf('--- IRF Summary (PFA) ---\n');
print_summary(Results_pfa.LtildeStruct, Dataset, Cfg_pfa);

fprintf('--- IRF Summary (IS) ---\n');
print_summary(Results_is.LtildeStruct, Dataset, Cfg_is);

% ── 5b. Gráficas IRF ─────────────────────────────────────────────────────
fprintf('--- Gráficas IRF ---\n');
Cfg_plot_pfa          = Cfg_pfa;
Cfg_plot_pfa.FIG_SUFFIX = '_pfa';
plot_irfs(Results_pfa.LtildeStruct, Dataset, Cfg_plot_pfa);

Cfg_plot_is           = Cfg_is;
Cfg_plot_is.FIG_SUFFIX = '_is';
plot_irfs(Results_is.LtildeStruct, Dataset, Cfg_plot_is);

% ── 5c. FEVD ─────────────────────────────────────────────────────────────
fprintf('--- FEVD ---\n');
Cfg_fevd_pfa          = Cfg_pfa;
Cfg_fevd_pfa.FIG_SUFFIX = '_pfa';
plot_fevd(Results_pfa.FEVD, Dataset, Cfg_fevd_pfa);

Cfg_fevd_is           = Cfg_is;
Cfg_fevd_is.FIG_SUFFIX = '_is';
plot_fevd(Results_is.FEVD, Dataset, Cfg_fevd_is);

% ── 5d. Comparación PFA vs IS ────────────────────────────────────────────
fprintf('--- Comparación PFA vs IS ---\n');
compare_pfa_is(Results_pfa, Results_is, Dataset, Cfg_pfa);

% ── 5e. Estabilidad del VAR ──────────────────────────────────────────────
fprintf('--- Estabilidad ---\n');
check_stability(Results_pfa, Cfg_pfa);
check_stability(Results_is,  Cfg_is);

% ── 5f. Diagnóstico de pesos IS ──────────────────────────────────────────
fprintf('--- Diagnóstico pesos IS ---\n');
diagnose_is_weights(Results_is, Cfg_is);

%% ── Sección 6 — Export ───────────────────────────────────────────────────
%
%  Exporta resultados a Excel en output/tables/.
%  Requiere: Secciones 3 y 4 ejecutadas.

fprintf('\n--- Export PFA → Excel ---\n');
export_results(Results_pfa, Dataset, Cfg_pfa);

fprintf('--- Export IS → Excel ---\n');
export_results(Results_is, Dataset, Cfg_is);

fprintf('\n[OK] Archivos guardados en: %s\n', OUT_TAB);
fprintf('     Gráficas guardadas en: %s\n\n', OUT_FIG);

%% ── Funciones auxiliares internas ────────────────────────────────────────

function s = bool2str(b)
    if b, s = 'Sí'; else, s = 'No'; end
end

function name = get_varname(vnames, idx)
    if idx <= numel(vnames)
        name = vnames{idx};
    else
        name = sprintf('var_%d', idx);
    end
end

function s = format_horizons(H)
    if isscalar(H)
        s = sprintf('h=%d', H);
    elseif isequal(H, H(1):H(end))
        s = sprintf('h=%d a h=%d', H(1), H(end));
    else
        s = ['h=' strjoin(arrayfun(@num2str, H, 'UniformOutput', false), ',')];
    end
end
