%PIPELINE_OIL  Flujo completo — Ejemplo mercado petrolero (BH 2019).
%
%   Instancia concreta de pipeline_template.m para el ejemplo oil_market.
%   Demuestra cómo usar el SVAR Toolkit de punta a punta con un dataset
%   distinto al de referencia (BNW).
%
%   Ejecuta SECCIÓN A SECCIÓN con Ctrl+Enter (o F9).
%
%   FLUJO:
%     Sección 0 — Setup          (ejecutar primero, una sola vez)
%     Sección 1 — Explorar datos
%     Sección 2 — Revisar config
%     Sección 3 — Estimación PFA
%     Sección 4 — Estimación IS
%     Sección 5 — Post-estimación
%     Sección 6 — Export

%% ── Sección 0 — Setup de rutas ───────────────────────────────────────────
%
%  ┌─────────────────────────────────────────────────────────────────────┐
%  │  EDITAR SOLO ESTA LÍNEA. Luego Ctrl+Enter aquí.                    │
%  └─────────────────────────────────────────────────────────────────────┘
REF_ROOT = '/ruta/absoluta/a/refactored';   % ← EDITAR
%  Ejemplo: REF_ROOT = '/Users/cristhian/repos/svartoolkit/refactored';

EX_ROOT  = fullfile(REF_ROOT, 'examples', 'oil_market');
EX_CFG   = fullfile(EX_ROOT,  'config');
OUT_FIG  = fullfile(REF_ROOT, 'output', 'figures');
OUT_TAB  = fullfile(REF_ROOT, 'output', 'tables');

addpath(fullfile(REF_ROOT, 'src'));
addpath(fullfile(REF_ROOT, 'config'));
addpath(fullfile(REF_ROOT, 'helpfunctions'));
addpath(fullfile(REF_ROOT, 'validate'));
addpath(EX_CFG);

if ~isfolder(OUT_FIG), mkdir(OUT_FIG); end
if ~isfolder(OUT_TAB), mkdir(OUT_TAB); end

fprintf('\n[Setup OK] — oil_market\n');
fprintf('  REF_ROOT: %s\n\n', REF_ROOT);

%% ── Sección 1 — Cargar y explorar datos ─────────────────────────────────
%
%  Carga data_bau.xlsx y muestra variables, fechas y estadísticas.

clear Cfg;
run(fullfile(EX_CFG, 'spec_oil_pfa.m'));
Cfg_eda = Cfg; clear Cfg;

Dataset = load_data(Cfg_eda);

fprintf('\n');
fprintf('════════════════════════════════════════════\n');
fprintf('  DATOS: Mercado Petrolero (BH 2019)\n');
fprintf('════════════════════════════════════════════\n');
fprintf('  Frecuencia : %s (mensual)\n', Dataset.freq);
dates = Dataset.dates;
if iscell(dates)
    fprintf('  Inicio     : %s\n', dates{1});
    fprintf('  Fin        : %s\n', dates{end});
else
    fprintf('  Inicio     : %s\n', datestr(dates(1)));
    fprintf('  Fin        : %s\n', datestr(dates(end)));
end
fprintf('  T (total)  : %d observaciones\n', size(Dataset.Y_raw, 1));
fprintf('  T (modelo) : %d obs (tras lags: T-%d=%d)\n', Cfg_eda.NLAG, size(Dataset.Y_raw,1), size(Dataset.Y_raw,1)-Cfg_eda.NLAG);
fprintf('  n (endo)   : %d variables\n', Dataset.nvar);
fprintf('  p (lags)   : %d\n', Cfg_eda.NLAG);
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

%% ── Sección 2 — Revisar configuración ───────────────────────────────────
%
%  Imprime parámetros del modelo y traduce las restricciones Z/S a
%  lenguaje natural (variable, shock, horizonte, dirección).

clear Cfg;
run(fullfile(EX_CFG, 'spec_oil_pfa.m'));
Cfg_pfa = Cfg; clear Cfg;

clear Cfg;
run(fullfile(EX_CFG, 'spec_oil_is.m'));
Cfg_is = Cfg; clear Cfg;

for ii = 1:2
    if ii == 1, Cfg_show = Cfg_pfa; label = 'PFA';
    else,        Cfg_show = Cfg_is;  label = 'IS';  end

    fprintf('\n════════════════════════════════════════════\n');
    fprintf('  CONFIG: %s  (%s)\n', Cfg_show.SPEC_NAME, label);
    fprintf('════════════════════════════════════════════\n');
    fprintf('  Lags (p)   : %d\n', Cfg_show.NLAG);
    fprintf('  Horizonte  : %d meses\n', Cfg_show.HORIZON);
    fprintf('  FEVD en h  : %d\n', Cfg_show.INDEX_FEVD);
    fprintf('  Draws (nd) : %d\n', Cfg_show.ND);
    fprintf('  Semilla    : %d\n', Cfg_show.SEED);
    fprintf('  Horizontes restricciones: ');
    fprintf('%d ', Cfg_show.HORIZONS_RESTRICT); fprintf('\n\n');

    vnames = endo_names;   % del Dataset cargado en Sección 1
    n_v    = numel(Cfg_show.S);

    fprintf('  Restricciones de SIGNO (S):\n');
    any_s = false;
    for k = 1:n_v
        if ~isempty(Cfg_show.S{k})
            any_s = true;
            for row = 1:size(Cfg_show.S{k},1)
                sv = Cfg_show.S{k}(row,:);
                vi = find(abs(sv) > 0);
                if vi <= numel(vnames), vn = vnames{vi};
                else, vn = sprintf('var_%d',vi); end
                if sv(vi) > 0, dir = 'POSITIVO'; else, dir = 'NEGATIVO'; end
                h_str = format_horizons_oil(Cfg_show.HORIZONS_RESTRICT);
                fprintf('    Shock %d  →  %s (var %d): %s en %s\n', ...
                    k, vn, vi, dir, h_str);
            end
        end
    end
    if ~any_s, fprintf('    (ninguna)\n'); end

    fprintf('  Restricciones de CERO (Z):\n');
    any_z = false;
    for k = 1:n_v
        if ~isempty(Cfg_show.Z{k})
            any_z = true;
            for row = 1:size(Cfg_show.Z{k},1)
                zv = Cfg_show.Z{k}(row,:);
                vi = find(abs(zv) > 0);
                if vi <= numel(vnames), vn = vnames{vi};
                else, vn = sprintf('var_%d',vi); end
                h_str = format_horizons_oil(Cfg_show.HORIZONS_RESTRICT);
                fprintf('    Shock %d  →  %s (var %d): SIN RESPUESTA en %s\n', ...
                    k, vn, vi, h_str);
            end
        end
    end
    if ~any_z, fprintf('    (ninguna)\n'); end
end

fprintf('\n[Tip] Si algo no es lo que esperabas, edita la spec y vuelve a correr esta sección.\n\n');

%% ── Sección 3 — Estimación PFA ───────────────────────────────────────────
%
%  PFA: sign restrictions únicamente.
%  nd=500 para testing. Para producción: cambiar Cfg_pfa.ND = 5000.

clear Cfg;
run(fullfile(EX_CFG, 'spec_oil_pfa.m'));
Cfg_pfa = Cfg; clear Cfg;
Cfg_pfa.PLOT_IRFS = false;   % gráficas en Sección 5

if ~exist('Dataset', 'var')
    Dataset = load_data(Cfg_pfa);
end

fprintf('\n--- Estimación PFA (nd=%d) ---\n', Cfg_pfa.ND);
validate_cfg(Cfg_pfa);
Post_pfa    = build_posterior(Dataset, Cfg_pfa);
rng(Cfg_pfa.SEED);
Results_pfa = run_pfa(Post_pfa, Cfg_pfa);

%% ── Sección 4 — Estimación IS ────────────────────────────────────────────
%
%  IS: sign + zero restrictions.
%  nd=500 para testing. Para producción: Cfg_is.ND = 5000.

clear Cfg;
run(fullfile(EX_CFG, 'spec_oil_is.m'));
Cfg_is = Cfg; clear Cfg;
Cfg_is.PLOT_IRFS = false;

if ~exist('Dataset', 'var')
    Dataset = load_data(Cfg_is);
end

fprintf('\n--- Estimación IS (nd=%d) ---\n', Cfg_is.ND);
validate_cfg(Cfg_is);
Post_is    = build_posterior(Dataset, Cfg_is);
rng(Cfg_is.SEED);
Results_is = run_is(Post_is, Cfg_is);

%% ── Sección 5 — Post-estimación ──────────────────────────────────────────
%
%  Todas las funciones de análisis. Gráficas en pantalla + guardadas.
%  Requiere: Secciones 3 y 4 ejecutadas.

fprintf('\n════════════════════════════════════════════\n');
fprintf('  POST-ESTIMACIÓN\n');
fprintf('════════════════════════════════════════════\n\n');

% 5a. Resumen numérico
fprintf('--- IRF Summary (PFA) ---\n');
print_summary(Results_pfa.LtildeStruct, Dataset, Cfg_pfa);

fprintf('--- IRF Summary (IS) ---\n');
print_summary(Results_is.LtildeStruct, Dataset, Cfg_is);

% 5b. IRFs en pantalla + guardadas
fprintf('--- Gráficas IRF ---\n');
Cfg_p_pfa           = Cfg_pfa;
Cfg_p_pfa.FIG_SUFFIX = '_oil_pfa';
plot_irfs(Results_pfa.LtildeStruct, Dataset, Cfg_p_pfa);

Cfg_p_is            = Cfg_is;
Cfg_p_is.FIG_SUFFIX  = '_oil_is';
plot_irfs(Results_is.LtildeStruct, Dataset, Cfg_p_is);

% 5c. FEVD
fprintf('--- FEVD ---\n');
Cfg_f_pfa           = Cfg_pfa;
Cfg_f_pfa.FIG_SUFFIX = '_oil_pfa';
plot_fevd(Results_pfa.FEVD, Dataset, Cfg_f_pfa);

Cfg_f_is            = Cfg_is;
Cfg_f_is.FIG_SUFFIX  = '_oil_is';
plot_fevd(Results_is.FEVD, Dataset, Cfg_f_is);

% 5d. Comparación PFA vs IS
fprintf('--- Comparación PFA vs IS ---\n');
compare_pfa_is(Results_pfa, Results_is, Dataset, Cfg_pfa);

% 5e. Estabilidad
fprintf('--- Estabilidad del VAR ---\n');
check_stability(Results_pfa, Cfg_pfa);
check_stability(Results_is,  Cfg_is);

% 5f. Diagnóstico pesos IS
fprintf('--- Diagnóstico pesos IS ---\n');
diagnose_is_weights(Results_is, Cfg_is);

%% ── Sección 6 — Export ───────────────────────────────────────────────────
%
%  Exporta resultados a Excel. Archivo en output/tables/.

fprintf('\n--- Export PFA → Excel ---\n');
export_results(Results_pfa, Dataset, Cfg_pfa);

fprintf('--- Export IS → Excel ---\n');
export_results(Results_is, Dataset, Cfg_is);

fprintf('\n[OK] Tablas  → %s\n', OUT_TAB);
fprintf('[OK] Figuras → %s\n\n', OUT_FIG);

%% ── Función auxiliar ─────────────────────────────────────────────────────

function s = format_horizons_oil(H)
    if isscalar(H)
        s = sprintf('h=%d', H);
    elseif isequal(H(:)', H(1):H(end))
        s = sprintf('h=%d a h=%d', H(1), H(end));
    else
        s = ['h=' strjoin(arrayfun(@num2str, H(:)', 'UniformOutput', false), ',')];
    end
end
