# SVAR Toolkit — Manual de uso e instructivo metodológico

> Basado en Arias, Rubio-Ramírez y Waggoner (2018), *"Inference Based on Structural Vector Autoregressions Identified with Sign and Zero Restrictions"*, Econometrica 86(2).

---

## Contenido

1. [Instalación y estructura](#1-instalación-y-estructura)
2. [Formato de datos requerido](#2-formato-de-datos-requerido)
3. [Guía de uso paso a paso](#3-guía-de-uso-paso-a-paso)
4. [Outputs e interpretación](#4-outputs-e-interpretación)
5. [Extensiones y flujos avanzados](#5-extensiones-y-flujos-avanzados)
6. [Notas metodológicas](#6-notas-metodológicas)

---

## 1. Instalación y estructura

### 1.1 Requisitos

- **MATLAB R2019b o superior** (requerido para `sheetnames()`, `datetime` arrays y `writecell`)
- Toolboxes: Optimization Toolbox (para `fmincon` en PFA), Statistics and Machine Learning Toolbox (para `quantile`, `chi2rnd`)
- No se requieren toolboxes de series de tiempo

### 1.2 Estructura de carpetas

```
svartoolkit/
│
├── original/              ← código original ARW 2018. NUNCA se modifica.
│
└── refactored/            ← toolkit refactorizado
    │
    ├── main.m             ← punto de entrada único
    │
    ├── config/            ← especificaciones de modelo
    │   ├── spec_bnw_pfa.m
    │   ├── spec_bnw_is.m
    │   ├── spec_timing_4L1Z.m
    │   └── spec_timing_12L3Z.m
    │
    ├── data/              ← datos en .xlsx (formato dos hojas)
    │   ├── data_bnw.xlsx
    │   └── data_timing.xlsx
    │
    ├── src/               ← funciones del toolkit
    │   ├── load_data.m
    │   ├── build_dummies.m
    │   ├── build_posterior.m
    │   ├── run_pfa.m
    │   ├── run_is.m
    │   ├── run_timing.m
    │   ├── pack_ltilde.m
    │   ├── compute_irfs_pfa.m
    │   ├── compute_irfs_is.m
    │   ├── compute_cirfs.m
    │   ├── select_irfs.m
    │   ├── normalize_irfs.m
    │   ├── plot_irfs.m
    │   ├── print_run_summary.m
    │   ├── validate_cfg.m
    │   ├── print_summary.m
    │   ├── plot_fevd.m
    │   ├── export_results.m
    │   ├── load_spec.m
    │   ├── diagnose_is_weights.m
    │   ├── check_stability.m
    │   ├── compare_pfa_is.m
    │   ├── compare_specs.m
    │   ├── main_batch.m
    │   └── run_prior_sensitivity.m
    │
    ├── helpfunctions/     ← funciones originales ARW 2018. NUNCA se modifican.
    │   └── *.m            (37 funciones: SetupInfo, ZIRF, IRF_horizons, etc.)
    │
    ├── output/
    │   ├── figures/       ← .png generados (en .gitignore)
    │   ├── results/       ← .mat guardados (en .gitignore)
    │   └── tables/        ← .xlsx exportados (en .gitignore)
    │
    ├── docs/
    │   └── manual.md      ← este documento
    │
    └── validate/          ← scripts de verificación por fase/lote
        ├── validate_mvp.m
        ├── validate_lote*.m
        └── ...
```

### 1.3 Configurar el path de MATLAB

Ejecutar una vez desde cualquier directorio de trabajo:

```matlab
% Reemplazar con la ruta absoluta a la carpeta refactored/ en tu máquina
addpath(genpath('/ruta/absoluta/a/svartoolkit/refactored'));
```

Alternativamente, agregar al `startup.m` de MATLAB para persistencia entre sesiones. El toolkit no usa `cd` ni rutas relativas: todas las funciones calculan su posición en disco vía `fileparts(mfilename('fullpath'))`.

---

## 2. Formato de datos requerido

### 2.1 Estructura del archivo .xlsx

El toolkit requiere un archivo Excel con **exactamente dos hojas**:

**Hoja 1 — Datos tabulares**

| fecha      | var1   | var2   | ... |
|------------|--------|--------|-----|
| 31/03/1965 | 3.2415 | 0.8821 | ... |
| 30/06/1965 | 3.2518 | 0.8834 | ... |

- La primera columna debe contener fechas.
- Las columnas restantes corresponden a las variables del modelo.
- Los encabezados de columna deben coincidir con los `var_name` de la Hoja 2.

**Hoja 2 — Metadata (varinfo)**

| var_name | role        | label                     |
|----------|-------------|---------------------------|
| gdp      | endogenous  | GDP growth (%)            |
| infl     | endogenous  | Inflation (%)             |
| frate    | endogenous  | Federal funds rate (%)    |
| const    | exogenous   | Constant                  |

Columnas requeridas:

| Columna    | Descripción                                      |
|------------|--------------------------------------------------|
| `var_name` | Nombre corto de la variable (sin espacios)       |
| `role`     | `'endogenous'` o `'exogenous'`                   |
| `label`    | Etiqueta larga para gráficos y tablas            |

### 2.2 Formato de fecha

- **Obligatorio:** formato `DD/MM/AAAA` en Excel (tipo fecha real, no texto).
- **Convención de período:** último mes del período.

| Período  | Fecha correcta |
|----------|----------------|
| Q1 AAAA  | 31/03/AAAA     |
| Q2 AAAA  | 30/06/AAAA     |
| Q3 AAAA  | 30/09/AAAA     |
| Q4 AAAA  | 31/12/AAAA     |
| Anual    | 31/12/AAAA     |
| Mensual  | último día del mes |

### 2.3 Responsabilidad del usuario sobre transformaciones

El toolkit carga los datos en la unidad en que están en el xlsx. **El usuario es responsable de aplicar todas las transformaciones** (logaritmo, diferencias, tasas de crecimiento) antes de guardar el archivo de datos. El campo `Cfg.SCALE_FACTOR` permite multiplicar por un escalar global (por ejemplo, ×100 para pasar de unidades decimales a porcentajes), pero no sustituye transformaciones no lineales.

El toolkit registra la ruta del archivo cargado en `Dataset.source_file` para trazabilidad.

---

## 3. Guía de uso paso a paso

### 3.1 Flujo básico

```matlab
% Desde cualquier directorio con el path ya configurado:
Results = main('spec_bnw_pfa');   % corre spec de PFA
Results = main('spec_bnw_is');    % corre spec de IS
```

`main.m` carga el config, valida `Cfg`, llama al estimador correspondiente (`run_pfa` o `run_is`) y devuelve la struct `Results`.

### 3.2 Crear un config desde cero

Un config es un script `.m` ubicado en `config/` que popula la struct `Cfg`. Copiar como plantilla:

```matlab
% config/spec_mi_modelo.m

% ── DATOS ──────────────────────────────────────────────────────────────────
Cfg.DATA_FILE    = '';       % '' → usa data/data_bnw.xlsx del proyecto
                             % alternativa: ruta absoluta a otro .xlsx
Cfg.SCALE_FACTOR = 100;      % multiplica todos los datos al cargar

% ── MODELO ─────────────────────────────────────────────────────────────────
Cfg.NLAG         = 4;        % número de lags
Cfg.NEX          = 1;        % 1 = incluir constante, 0 = sin constante
Cfg.HORIZON      = 40;       % horizonte máximo para IRFs
Cfg.INDEX_FEVD   = 40;       % horizonte para FEVD

% ── MUESTREO ───────────────────────────────────────────────────────────────
Cfg.MODE         = 'pfa';    % 'pfa' | 'is'
Cfg.ND           = 1e4;      % draws ortogonal-reduced-form
Cfg.SEED         = 0;        % semilla rng

% ── SOLO PARA MODO IS ──────────────────────────────────────────────────────
Cfg.MAX_IS_DRAWS = 1e4;      % máx draws efectivos del IS
Cfg.CONJUGATE    = 'structural'; % 'structural' | 'irfs'

% ── RESTRICCIONES ──────────────────────────────────────────────────────────
n = 5;   % número de variables endógenas (ajustar)
Cfg.HORIZONS_RESTRICT = 0;   % horizonte sobre el que se imponen S y Z

Cfg.NS = 1;                  % número de objetos en F(theta) con restricciones
Cfg.S  = cell(n, 1);
Cfg.S{1} = [1 0 0 0 0;       % restricciones de signo: columna del shock
             0 0 0 0 0;       %   1=positivo, -1=negativo, 0=sin restricción
             0 0 0 0 0;
             0 0 0 0 0;
             0 0 0 0 0];

Cfg.Z  = cell(n, 1);
Cfg.Z{1} = [];               % restricciones de cero: filas = variables,
                             %   columnas = shocks a igualar cero

% ── PRIOR ──────────────────────────────────────────────────────────────────
% Omitir este bloque = prior diffuse (default, paper original)
% Cfg.PRIOR.type = 'minnesota';
% Cfg.PRIOR.lambda1 = 0.2;
% Cfg.PRIOR.lambda2 = 0.5;
% Cfg.PRIOR.lambda3 = 1.0;

% ── OUTPUT ─────────────────────────────────────────────────────────────────
Cfg.SPEC_NAME    = 'mi_modelo';    % prefijo de archivos generados
Cfg.SAVE_RESULTS = false;          % true → guarda Results en output/results/
Cfg.PLOT_IRFS    = true;           % true → genera figura PNG
Cfg.ITER_SHOW    = 2000;           % frecuencia de reporte de progreso

% ── IRF Y PLOTTING ─────────────────────────────────────────────────────────
Cfg.IRF_TYPE     = 'irf';          % 'irf' | 'cirf' | 'both'
Cfg.CRED_BANDS   = [0.16 0.84];    % cuantiles de credibilidad (N×2)
Cfg.IRF_NORM     = 'none';         % 'none' | '1sd' | 'unit' | 'own_unit'
Cfg.SHOCK_IDX    = 1;              % índice del shock a graficar
Cfg.RESP_IDX     = [];             % [] = todas las variables
Cfg.FIG_SUFFIX   = '';             % sufijo para nombre del archivo PNG
```

### 3.3 Referencia completa de campos Cfg

#### Campos obligatorios

| Campo            | Tipo       | Default | Descripción                               |
|------------------|------------|---------|-------------------------------------------|
| `MODE`           | string     | —       | `'pfa'` \| `'is'` \| `'timing'`          |
| `NLAG`           | int        | —       | Número de lags del VAR                    |
| `NEX`            | int        | —       | 1 = constante incluida, 0 = sin ella      |
| `HORIZON`        | int        | —       | Horizonte máximo de IRFs                  |
| `INDEX_FEVD`     | int        | —       | Horizonte de FEVD                         |
| `SCALE_FACTOR`   | scalar     | —       | Factor multiplicativo global de los datos |
| `ND`             | int        | —       | Número de draws ortogonal-reduced-form    |
| `SEED`           | int        | —       | Semilla `rng`                             |
| `NS`             | int        | —       | Número de shocks identificados            |
| `S`              | cell(n,1)  | —       | Matrices de restricciones de signo        |
| `Z`              | cell(n,1)  | —       | Matrices de restricciones de cero         |
| `HORIZONS_RESTRICT` | vector  | —       | Horizontes sobre los que aplican S y Z    |

#### Campos opcionales — muestreo IS

| Campo          | Default        | Descripción                                       |
|----------------|----------------|---------------------------------------------------|
| `MAX_IS_DRAWS` | `1e4`          | Máximo de draws efectivos en IS                   |
| `CONJUGATE`    | `'structural'` | Parametrización del IS: `'structural'` \| `'irfs'` |

#### Campos opcionales — datos y path

| Campo       | Default | Descripción                                              |
|-------------|---------|----------------------------------------------------------|
| `DATA_FILE` | `''`    | Ruta absoluta al .xlsx; `''` usa `data/data_bnw.xlsx`   |
| `SPEC_NAME` | `''`    | Prefijo para nombres de archivos de salida               |

#### Campos opcionales — output

| Campo          | Default       | Descripción                                    |
|----------------|---------------|------------------------------------------------|
| `SAVE_RESULTS` | `false`       | Guardar Results como .mat                      |
| `PLOT_IRFS`    | `true`        | Generar figura PNG de IRFs                     |
| `ITER_SHOW`    | `2000`        | Frecuencia de reporte de progreso              |

#### Campos opcionales — IRF y plotting

| Campo              | Default          | Descripción                                             |
|--------------------|------------------|---------------------------------------------------------|
| `IRF_TYPE`         | `'irf'`          | `'irf'` \| `'cirf'` \| `'both'`                        |
| `CRED_BANDS`       | `[0.16 0.84]`    | Cuantiles de credibilidad (N filas × 2 columnas)        |
| `IRF_NORM`         | `'none'`         | `'none'` \| `'1sd'` \| `'unit'` \| `'own_unit'`        |
| `SHOCK_IDX`        | `1`              | Índice del shock a graficar/seleccionar                 |
| `RESP_IDX`         | `[]` (todas)     | Índices de variables de respuesta                       |
| `FIG_SUFFIX`       | `''`             | Sufijo para nombre del PNG (evita sobreescribir)        |
| `SUMMARY_HORIZONS` | `[0 4 8 20 40]`  | Horizontes para `print_summary`                         |
| `NORM_SHOCK_IDX`   | `1`              | Shock para normalización `'unit'`/`'own_unit'`          |
| `NORM_VAR`         | `1`              | Variable para normalización `'unit'`                    |
| `NORM_HORIZON`     | `0`              | Horizonte para normalización `'unit'`                   |
| `NORM_VALUE`       | `1`              | Valor objetivo para normalización `'unit'`              |

#### Campos opcionales — diagnósticos

| Campo              | Default | Descripción                                        |
|--------------------|---------|----------------------------------------------------|
| `MIN_ACCEPT_RATE`  | `0.10`  | Umbral de alerta para tasa de aceptación PFA       |

#### Campos opcionales — prior

| Campo              | Default     | Descripción                                             |
|--------------------|-------------|---------------------------------------------------------|
| `PRIOR.type`       | `'diffuse'` | Tipo de prior (ver sección 3.5)                         |
| `PRIOR.lambda1`    | —           | Tightness (Minnesota, natural conjugate, Sims-Zha)     |
| `PRIOR.lambda2`    | —           | Mezcla own/cross (Minnesota, natural conjugate)         |
| `PRIOR.lambda3`    | —           | Decaimiento por lag (Minnesota, natural conjugate)      |
| `PRIOR.mu5`        | —           | Coeficiente suma de coeficientes (Sims-Zha)            |
| `PRIOR.mu6`        | —           | Coeficiente tendencia común (Sims-Zha)                 |
| `PRIOR.nu_bar`     | —           | Grados de libertad NIW (niw_custom, natural_conjugate) |
| `PRIOR.Phi_bar`    | —           | Matriz escala NIW (niw_custom)                         |
| `PRIOR.Psi_bar`    | —           | Media de B (niw_custom)                               |
| `PRIOR.Omega_bar`  | —           | Varianza de B (niw_custom)                            |

#### Campos opcionales — dummies exógenas

| Campo      | Default | Descripción                                                  |
|------------|---------|--------------------------------------------------------------|
| `DUMMIES`  | —       | Struct array con dummies exógenas (ver sección 3.6)          |

### 3.4 Correr PFA e IS

```matlab
% Correr solo PFA
Results_pfa = main('spec_bnw_pfa');

% Correr solo IS
Results_is  = main('spec_bnw_is');

% Correr ambos manualmente (para comparación posterior)
Results_pfa = main('spec_bnw_pfa');
Results_is  = main('spec_bnw_is');
```

Para correr desde código (sin usar `main.m`):

```matlab
% Carga Cfg y Dataset explícitamente
Cfg = load_spec('/ruta/a/config/spec_bnw_pfa.m');
Dataset = load_data(Cfg);
PosteriorParams = build_posterior(Dataset, Cfg);

% PFA
Results = run_pfa(Dataset, PosteriorParams, Cfg);

% IS
Results = run_is(Dataset, PosteriorParams, Cfg);
```

### 3.5 Cambiar el prior (Cfg.PRIOR)

El campo `Cfg.PRIOR.type` selecciona el prior. Si el campo no existe, el toolkit usa `'diffuse'` (paper original).

**Prior diffuse (default)**

```matlab
% No se requiere ningún campo adicional
% Equivalente explícito:
Cfg.PRIOR.type = 'diffuse';
```

**Prior Minnesota** — shrinkage hacia random walk; recomendado cuando hay muchas variables o lags.

```matlab
Cfg.PRIOR.type    = 'minnesota';
Cfg.PRIOR.lambda1 = 0.2;   % tightness: 0=muy informativo, 1=difuso
Cfg.PRIOR.lambda2 = 0.5;   % mezcla own/cross: 1=sin distinción, 0=máx. shrinkage cross
Cfg.PRIOR.lambda3 = 1.0;   % decaimiento por lag: 1=lineal, 2=cuadrático
```

**Prior Sims-Zha** — dummies de suma de coeficientes y tendencia común. Diseñado para datos estacionarios o en diferencias. Con datos en log-niveles emite `warning('build_posterior:simsZhaScale')`.

```matlab
Cfg.PRIOR.type    = 'sims_zha';
Cfg.PRIOR.lambda1 = 0.2;   % tightness general
Cfg.PRIOR.mu5     = 0.5;   % coeficiente suma de coeficientes
Cfg.PRIOR.mu6     = 0.5;   % coeficiente tendencia común
```

> **Advertencia:** no usar Sims-Zha con datos en log-niveles sin transformar previamente las series a diferencias o log-diferencias. Ver sección 6.4.

**Prior NIW custom** — NIW informativo con hiperparámetros explícitos.

```matlab
n = 5; % número de variables endógenas
Cfg.PRIOR.type    = 'niw_custom';
Cfg.PRIOR.nu_bar  = 20;            % grados de libertad (debe ser > n+1)
Cfg.PRIOR.Phi_bar = eye(n) * 50;   % matriz escala (n×n, definida positiva)
Cfg.PRIOR.Psi_bar = zeros(n*Cfg.NLAG + Cfg.NEX, n); % media de B
Cfg.PRIOR.Omega_bar = eye(n*Cfg.NLAG + Cfg.NEX);    % varianza de B
```

**Prior natural conjugate** — Minnesota en forma NIW estricta (Kadiyala & Karlsson 1997).

```matlab
Cfg.PRIOR.type    = 'natural_conjugate';
Cfg.PRIOR.lambda1 = 0.2;
Cfg.PRIOR.lambda2 = 0.5;
Cfg.PRIOR.lambda3 = 1.0;
Cfg.PRIOR.nu_bar  = 30;   % opcional; default = n+1+T/10
```

### 3.6 Dummies exógenas (Cfg.DUMMIES)

Las dummies se declaran como un struct array en `Cfg.DUMMIES`. Cada elemento define una dummy:

```matlab
% Dummy puntual (one-off): valor 1 en una fecha específica
Cfg.DUMMIES(1).type  = 'oneoff';
Cfg.DUMMIES(1).name  = 'd_covid';
Cfg.DUMMIES(1).date  = [2020, 3];  % [year, month] — convención último mes del período

% Dummy de pulso (rango): valor 1 en intervalo [date_start, date_end]
Cfg.DUMMIES(2).type       = 'pulse';
Cfg.DUMMIES(2).name       = 'd_crisis';
Cfg.DUMMIES(2).date_start = [2008, 9];
Cfg.DUMMIES(2).date_end   = [2009, 6];

% Dummy de escalón (step): valor 0 antes de date, 1 desde date en adelante
Cfg.DUMMIES(3).type  = 'step';
Cfg.DUMMIES(3).name  = 'd_volcker';
Cfg.DUMMIES(3).date  = [1979, 9];

% Dummy estacional: valor 1 en el mes especificado de cada año
Cfg.DUMMIES(4).type  = 'seasonal';
Cfg.DUMMIES(4).name  = 'd_q1';
Cfg.DUMMIES(4).month = 3;   % mes del período (convención último mes: Q1=3)
```

Las dummies se incorporan al final de la matriz de regresores exógenos `xt`, después de la constante. `PosteriorParams.ndummies` documenta cuántas dummies se incluyeron. Si no se define `Cfg.DUMMIES`, el modelo es idéntico al caso sin dummies.

---

## 4. Outputs e interpretación

### 4.1 Struct Results

Tanto `run_pfa` como `run_is` devuelven una struct `Results` con los siguientes campos:

| Campo              | Descripción                                                          |
|--------------------|----------------------------------------------------------------------|
| `LtildeStruct`     | Struct canónica de IRFs (ver sección 4.2)                            |
| `FEVD`             | Descomposición de varianza del error de predicción (nvar × HORIZON+1) |
| `accept_rate`      | Tasa de aceptación draws (PFA) o fracción efectiva IS               |
| `ESS`              | Tamaño efectivo de muestra (solo IS)                                 |
| `ne`               | Número de draws efectivos usados (solo IS)                           |
| `elapsed_time`     | Tiempo de ejecución en segundos                                      |
| `scale_factors`    | Factores de normalización por draw (si `IRF_NORM ≠ 'none'`)         |
| `Cfg`              | Struct Cfg usada en la corrida                                       |
| `Dataset`          | Struct Dataset con datos y metadata                                  |

### 4.2 LtildeStruct — representación canónica de IRFs

Las IRFs se almacenan en una struct unificada que abstrae la diferencia entre PFA (array 3D) e IS (array 4D):

```matlab
LtildeStruct.mode      % 'pfa' | 'is'
LtildeStruct.data      % array 3D (horizon+1, nvar, ndraws) para PFA
                       % array 4D (horizon+1, nvar, nvar, ndraws) para IS
LtildeStruct.shock_idx % índice del shock de interés
LtildeStruct.horizon   % horizonte máximo
LtildeStruct.nvar      % número de variables
LtildeStruct.ndraws    % nd (PFA) o ne (IS)
```

### 4.3 Funciones de post-procesamiento

**`select_irfs`** — extrae un subconjunto de shocks y variables de respuesta.

```matlab
% Seleccionar shock 1, respuestas 2 y 4
LS = select_irfs(Results.LtildeStruct, ...
                 'shock_idx', 1, ...
                 'resp_idx',  [2 4], ...
                 'Dataset',   Results.Dataset);
% LS es una LtildeStruct reducida con labels actualizados
```

**`normalize_irfs`** — aplica normalización draw-by-draw.

```matlab
% Normalizar por 1 desviación estándar del shock (replica paper)
[irfs_norm, sf] = normalize_irfs(LtildeStruct, PosteriorParams, '1sd');

% Fijar respuesta de variable 2 en h=0 a valor 1
[irfs_norm, sf] = normalize_irfs(LtildeStruct, PosteriorParams, 'unit', ...
    'shock_idx', 1, 'var', 2, 'horizon', 0, 'value', 1);

% Fijar respuesta propia en h=0 a 1 (unitaria)
[irfs_norm, sf] = normalize_irfs(LtildeStruct, PosteriorParams, 'own_unit', ...
    'shock_idx', 1);
```

Los factores de escala se guardan en `Results.scale_factors` cuando se usa normalización desde `main.m` vía `Cfg.IRF_NORM`.

**`plot_irfs`** — genera la figura de IRFs (mediana + banda de credibilidad).

```matlab
% Llamada directa (main.m la llama automáticamente si Cfg.PLOT_IRFS = true)
plot_irfs(Results.LtildeStruct, Cfg, Results.Dataset);

% Con normalización previa
LS_norm = Results.LtildeStruct;
LS_norm.data = irfs_norm;
plot_irfs(LS_norm, Cfg, Results.Dataset, Results);
```

La figura se guarda en `output/figures/<mode>_irfs<FIG_SUFFIX>.png` a 150 dpi.

**`print_summary`** — tabla de mediana + intervalos en consola para horizontes seleccionados.

```matlab
print_summary(Results.LtildeStruct, Cfg, Results.Dataset);
% Imprime en consola: shock × variable × horizonte | mediana | [q_lo, q_hi]
% Horizontes mostrados: Cfg.SUMMARY_HORIZONS (default [0 4 8 20 40])
% Bandas: todas las filas de Cfg.CRED_BANDS
```

**`plot_fevd`** — gráfico de descomposición de varianza del error de predicción.

```matlab
plot_fevd(Results.FEVD, Results.LtildeStruct, Cfg, Results.Dataset);
% Genera barra apilada: fracción explicada por el shock identificado (verde)
%   vs. resto (gris), con IC para la primera banda de Cfg.CRED_BANDS
% Guarda en output/figures/fevd_<mode><FIG_SUFFIX>.png
```

**`export_results`** — exporta a Excel (sin draws individuales).

```matlab
export_results(Results, Cfg, Results.Dataset);
% Genera output/tables/<SPEC_NAME>_results.xlsx con 5 hojas:
%   Hoja 1: metadata (spec, fecha, variables, semilla, transformaciones)
%   Hoja 2: irf_summary  (shock × response × horizon | median | p_lo | p_hi)
%   Hoja 3: cirf_summary (ídem para CIRFs, o nota si IRF_TYPE no incluye 'cirf')
%   Hoja 4: fevd_summary (shock × variable × horizon | median | p_lo | p_hi)
%   Hoja 5: run_diagnostics (ESS, tasa aceptación, tiempo, Pareto-k)
```

El formato tidy del Excel permite recrear todas las figuras y tablas en R o Python sin MATLAB.

### 4.4 Diagnósticos de ejecución

**`print_run_summary`** — resumen en consola al terminar.

```matlab
print_run_summary(Results, Cfg);
```

Imprime: número de draws, draws efectivos (IS), tasa de aceptación (PFA), ESS, tiempo de ejecución, y alerta si la tasa de aceptación está por debajo de `Cfg.MIN_ACCEPT_RATE` (default 10%).

**`diagnose_is_weights`** — análisis de la distribución de pesos del IS.

```matlab
diagnose_is_weights(Results, Cfg);
% Genera histograma de pesos normalizados
% Calcula índice Pareto-k via estimador de Hill (top-20% cola)
% Emite alerta si el top-5% de draws concentra más del 50% del peso total
% Guarda PNG en output/figures/is_weights_<SPEC_NAME>.png
```

Umbrales del índice Pareto-k: k < 0.5 = saludable; 0.5–0.7 = advertencia; ≥ 0.7 = pesos problemáticos.

> **Nota:** con restricciones de cero estrictas, valores k > 1 son normales (cola muy pesada). El índice de ARW (2018) con la spec BNW arroja k ≈ 8.4.

**`check_stability`** — fracción de draws con VAR estacionario.

```matlab
frac = check_stability(Results, Cfg);
% frac: escalar en [0,1]
% Emite advertencia si frac < 0.99
fprintf('Fracción de draws estables: %.1f%%\n', frac*100);
```

La fracción esperada con el prior NIW difuso de ARW es ~87.6%, dado que el prior no penaliza regiones no estacionarias del espacio de parámetros.

---

## 5. Extensiones y flujos avanzados

### 5.1 Comparación PFA vs IS

```matlab
compare_pfa_is(Results_pfa, Results_is, Cfg, Dataset);
% Imprime tabla mediana + IC por variable y horizonte para ambos estimadores
% Exporta output/tables/compare_pfa_is_<SPEC_NAME>.xlsx
```

El primer argumento debe corresponder a modo `'pfa'` y el segundo a `'is'`. Los horizontes mostrados se controlan con `Cfg.SUMMARY_HORIZONS`.

### 5.2 Análisis de robustez a priors

```matlab
% Definir lista de priors a comparar
prior_list = {
    struct('type', 'diffuse'), ...
    struct('type', 'minnesota', 'lambda1', 0.2, 'lambda2', 0.5, 'lambda3', 1.0), ...
    struct('type', 'natural_conjugate', 'lambda1', 0.2, 'lambda2', 0.5, 'lambda3', 1.0)
};

% Cargar datos y config base
Cfg_base = load_spec('config/spec_bnw_pfa.m');
Dataset  = load_data(Cfg_base);

% Correr sensibilidad
Results_list = run_prior_sensitivity('config/spec_bnw_pfa.m', prior_list, Dataset, Cfg_base);
% Imprime tabla de medianas de IRF por prior, en Cfg.SUMMARY_HORIZONS
% Retorna cell array de structs Results (uno por prior)
```

### 5.3 Correr múltiples specs en batch

```matlab
% Definir lista de specs
spec_paths = {
    '/ruta/a/config/spec_bnw_pfa.m', ...
    '/ruta/a/config/spec_bnw_is.m'
};

% Overrides opcionales (se aplican sobre Cfg de cada spec)
Cfg_overrides.SEED = 42;
Cfg_overrides.ND   = 5000;

% Correr batch
Results_all = main_batch(spec_paths, Cfg_overrides);
% Corre cada spec secuencialmente
% Llama compare_specs automáticamente si hay ≥2 specs del mismo modo
% Retorna cell array de structs Results
```

**`compare_specs`** — tabla de medianas de FEVD entre specs del mismo modo.

```matlab
compare_specs(Results_all, Cfg_base, Dataset);
% Muestra tabla comparativa para specs del mismo modo ('pfa' o 'is')
% En batch mixto PFA+IS, agrupa por modo y genera una tabla por modo
```

### 5.4 CIRFs (Impulse Response Functions acumuladas)

Configurar `Cfg.IRF_TYPE = 'cirf'` o `'both'` para incluir CIRFs en las figuras y en `export_results`. Para calcular CIRFs manualmente:

```matlab
cirfs = compute_cirfs(irfs_draws);
% irfs_draws: array de IRFs (horizon+1, nvar, ndraws)
% cirfs:      cumsum a lo largo del horizonte, mismas dimensiones
```

---

## 6. Notas metodológicas

### 6.1 PFA vs IS: diferencias y cuándo usar cada uno

El toolkit implementa los dos algoritmos de inferencia de ARW (2018):

**Prior-based Frequentist Algorithm (PFA)** es el algoritmo de identificación por signos y ceros mediante proyección sobre el conjunto identificado. En cada draw de la forma reducida, busca ortogonalización `Q` tal que el impulso resultante satisfaga las restricciones. Usa `fmincon` internamente.

- Apropiado para: restricciones de signo puras o mixtas signo/cero, especialmente cuando el conjunto identificado tiene interior no vacío.
- Ventaja: más rápido por draw, interpretación frecuentista de las bandas de credibilidad.
- Limitación: la tasa de aceptación puede caer cuando las restricciones son muy estrictas.

**Importance Sampler (IS)** muestrea directamente de la distribución posterior sobre las ortogonalizaciones, corrigiendo por el peso de importancia derivado de las restricciones de cero exactas.

- Apropiado para: restricciones de cero exactas (impacto contemporáneo nulo, respuesta cero en horizonte específico).
- Ventaja: tasa de aceptación efectiva más alta cuando los ceros son dominantes.
- Limitación: los pesos pueden concentrarse en pocos draws (monitorear con `diagnose_is_weights`).

**Regla práctica:** si el modelo tiene ceros exactos como restricciones de identificación, preferir IS. Si las restricciones son solo de signo, PFA es más eficiente. Comparar los resultados con `compare_pfa_is` como verificación de robustez.

### 6.2 Interpretar el ESS y la tasa de aceptación

**PFA — tasa de aceptación:**

- Es la fracción de draws de la forma reducida para los que se encontró una ortogonalización `Q` que satisface todas las restricciones.
- Valores normales: 5%–50% dependiendo de la especificación.
- Si `accept_rate < Cfg.MIN_ACCEPT_RATE` (default 10%), `print_run_summary` emite una advertencia. Considerar relajar restricciones o aumentar `Cfg.ND`.

**IS — ESS y ne:**

- `ne` = número de draws efectivos con peso positivo (después de descartar draws con peso ~0).
- `ESS` = tamaño efectivo de muestra, que tiene en cuenta la varianza de los pesos de importancia.
- `ESS/nd ≈ 0.39` en la spec BNW del paper es normal.
- Si `ESS/nd < 0.1`, los pesos están muy concentrados: aumentar `Cfg.ND` o revisar las restricciones.

### 6.3 Estabilidad de draws VAR

La fracción de draws con VAR estacionario (todos los eigenvalores de la companion matrix dentro del círculo unitario) reportada por `check_stability` puede estar por debajo de 1 con el prior NIW difuso. Esto es metodológicamente esperado: ARW (2018) no filtran por estabilidad. Filtrar condicionaría la inferencia en una región del espacio de parámetros no respaldada por el prior.

Para aumentar la fracción de draws estables, usar el prior Minnesota o natural conjugate: el shrinkage hacia el random walk reduce la masa en regiones explosivas.

### 6.4 Advertencia sobre prior Sims-Zha con datos en log-niveles

Sims & Zha (1998) derivaron el prior asumiendo que las series tienen medias muestrales `y0 ~ O(1)`. Con datos en log-niveles (valores típicos 100–1000), los dummies de observación pueden dominar la verosimilitud y sesgar la estimación.

La implementación normaliza internamente `y0` por `sigma_j` antes de construir los dummies (convención BEAR Toolbox BCE). Aun así, si `y0/sigma > 10`, el toolkit emite `warning('build_posterior:simsZhaScale')`.

**Práctica recomendada:** aplicar el prior Sims-Zha solo sobre series que ya estén en diferencias, log-diferencias o demeaned.

### 6.5 Extensiones diferidas

Las siguientes extensiones fueron evaluadas y pospuestas para desarrollo futuro:

- **D1/D2 — Identidades contables post-estimación:** requieren diseño adicional para manejar transformaciones no lineales y variables fuera del modelo estimado.
- **F3 — Identificación narrativa** (Antolín-Díaz & Rubio-Ramírez 2018): el paper es técnicamente compatible con el framework de ARW, pero requiere una capa adicional de restricciones sobre shocks históricos.
- **E4 — Revisión de posterior:** histogramas marginales de `B` y `Sigma` para diagnóstico visual del prior.
- **B7 — Config builder interactivo:** asistente de línea de comandos para generar configs.
- **E7 — Sensibilidad al prior extendida:** versión con múltiples runs paralelos y comparación automática de posteriors marginales.

---

## Apéndice A — Valores de referencia numéricos

Verificados con `validate_mvp.m` y `validate_lote*.m`. Cualquier modificación a `src/run_pfa.m`, `src/run_is.m` o `src/build_posterior.m` debe reproducir estos valores exactos con `rng(0)`.

**PFA** (`spec_bnw_pfa`, nd = 10 000, rng(0)):

| Métrica                           | Valor           |
|-----------------------------------|-----------------|
| `Ltilde(1,1,1)`                   |  0.0000000000   |
| `Ltilde(end,end,end)`             | −0.2326865051   |
| `median(Ltilde(:,2,:), 'all')`    |  5.4910402086   |
| `median(FEVD(2,:))`               |  0.7305634882   |

**IS** (`spec_bnw_is`, nd = 30 000, rng(0)):

| Métrica                              | Valor           |
|--------------------------------------|-----------------|
| `Ltilde(1,1,1,1)`                    |  0.0000000000   |
| `Ltilde(end,end,end,end)`            |  0.2041864191   |
| `median(Ltilde(:,2,1,:), 'all')`     |  2.9521795528   |
| `median(FEVD(2,:))`                  |  0.2580366201   |
| `ESS/nd`                             |  0.389133       |
| `ne`                                 |  11 674         |

---

## Apéndice B — Inventario completo de funciones src/

| Función                  | Descripción breve                                                          |
|--------------------------|----------------------------------------------------------------------------|
| `load_data`              | Carga datos desde .xlsx (dos hojas); devuelve `Dataset`                    |
| `build_dummies`          | Genera matriz de dummies exógenas desde `Cfg.DUMMIES` y `Dataset.dates`    |
| `build_posterior`        | Construye Y, X, OLS y parámetros posterior NIW para 5 tipos de prior       |
| `run_pfa`                | Loop PFA; devuelve `Results` con `LtildeStruct`                            |
| `run_is`                 | Loop IS + resampling; devuelve `Results` con `LtildeStruct`                |
| `run_timing`             | Loop IS con medición de tiempo; switch por `Cfg.TIMING_VARIANT`            |
| `pack_ltilde`            | Normaliza array Ltilde 3D/4D a `LtildeStruct` canónica                    |
| `compute_irfs_pfa`       | IRFs para un draw PFA; retorna slice (horizon+1, nvar)                     |
| `compute_irfs_is`        | IRFs para un draw IS; retorna matrix (horizon+1, nvar, nvar)               |
| `compute_cirfs`          | Operador acumulado puro: `cumsum(irfs, 1)`                                 |
| `select_irfs`            | Extrae subconjunto shock-response de `LtildeStruct`; actualiza labels      |
| `normalize_irfs`         | Normalización draw-by-draw: `'none'` / `'1sd'` / `'unit'` / `'own_unit'`  |
| `plot_irfs`              | Figura mediana + bandas; acepta `LtildeStruct`; guarda PNG                 |
| `print_run_summary`      | Resumen ESS, tasa aceptación, tiempo en consola                            |
| `validate_cfg`           | Valida campos obligatorios de `Cfg` antes de correr                        |
| `print_summary`          | Tabla mediana + IC en consola para horizontes clave                        |
| `plot_fevd`              | Barra apilada FEVD con IC; guarda PNG                                      |
| `export_results`         | Excel 5 hojas con summary (sin draws); formato tidy                        |
| `load_spec`              | Ejecuta spec dentro de función (evita error workspace estático)            |
| `diagnose_is_weights`    | Histograma pesos IS; Pareto-k; alerta concentración                        |
| `check_stability`        | Fracción de draws con VAR estable (eigenvalores en círculo unitario)       |
| `compare_pfa_is`         | Tabla numérica diferencias PFA vs IS en horizontes seleccionados           |
| `compare_specs`          | Tabla de medianas FEVD entre múltiples specs del mismo modo                |
| `main_batch`             | Corre lista de specs secuencialmente; llama `compare_specs`                |
| `run_prior_sensitivity`  | Compara medianas IRF entre variantes de prior                              |

---

*Documento generado por el Chat 14 del proyecto SVAR Toolkit. Versión 1.0 — Junio 2026.*
