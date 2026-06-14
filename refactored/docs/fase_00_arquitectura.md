# FASE 0 COMPLETADA — Arquitectura objetivo

## Estado actualizado

- [x] Fase 0 — Arquitectura objetivo
- [ ] Fase 1 — Esqueleto, rutas y data loader
- [ ] Fase 2 — Modo PFA
- [ ] Fase 3 — Modo Importance Sampler
- [ ] Fase 4 — Especificaciones de timing
- [ ] Fase 5 — Tweaks y extensiones

---

## Árbol de carpetas `refactored/`

```
refactored/
│
├── main.m                          ← punto de entrada único; recibe nombre de config y despacha
│
├── config/
│   ├── spec_bnw_pfa.m              ← BNW, modo PFA  (replica figure_1_panel_a)
│   ├── spec_bnw_is.m               ← BNW, modo IS   (replica figure_1_panel_b)
│   ├── spec_timing_4L1Z.m          ← timing: 4 lags, 3 signs, 1 zero (Tabla 4, parte 1)
│   └── spec_timing_12L3Z.m         ← timing: 12 lags, 3 signs, 3 zeros (Tabla 4, parte 2)
│
├── data/
│   └── data_bnw.xlsx               ← Hoja 1: fecha+variables | Hoja 2: metadata
│
├── src/
│   ├── load_data.m                 ← data loader canónico; devuelve Dataset struct
│   ├── build_posterior.m           ← arma Y, X, B, U y parámetros posterior NIW
│   ├── run_pfa.m                   ← loop PFA; devuelve Results struct con LtildeStruct
│   ├── run_is.m                    ← loop IS + resampling; devuelve Results struct
│   ├── run_timing.m                ← loop IS con medición de tiempo; switch por TIMING_VARIANT
│   ├── compute_irfs_pfa.m          ← IRFs para un draw PFA; retorna slice (horizon+1, nvar)
│   ├── compute_irfs_is.m           ← IRFs para un draw IS;  retorna matrix (horizon+1, nvar, nvar)
│   ├── pack_ltilde.m               ← normaliza Ltilde 3D/4D a LtildeStruct canónica
│   └── plot_irfs.m                 ← figura unificada PFA+IS; acepta LtildeStruct
│
├── helpfunctions/                  ← copia exacta de original/helpfunctions/ — NUNCA SE MODIFICA
│   └── *.m                         ← 37 funciones originales de ARW (2018)
│
├── output/
│   ├── figures/                    ← .png y .eps generados (en .gitignore)
│   └── results/                    ← .mat generados        (en .gitignore)
│
├── docs/
│   └── fase_00_arquitectura.md     ← este documento
│
├── validate/
│   ├── validate_fase1.m
│   ├── validate_fase2.m
│   ├── validate_fase3.m
│   └── validate_fase4.m
│
└── .gitignore                      ← excluye output/figures/, output/results/, *.mat, *.png, *.eps
```

---

## Decisiones de diseño fijadas

1. **Rutas absolutas vía `fileparts(mfilename('fullpath'))`** — ninguna función usa `pwd`, `cd` ni `..`. Cada archivo en `src/` calcula su propia ubicación en tiempo de ejecución.

2. **`helpfunctions/` es zona de no-tocar** — se copia íntegra de `original/helpfunctions/` y nunca se modifica. Cualquier wrapper o adaptador va en `src/`.

3. **`Cfg` es la única interfaz entre config y código** — ningún valor numérico de modelo, datos o muestreo aparece hardcodeado en `src/`. Todo se inyecta vía la struct `Cfg` que cada config popula.

4. **`Dataset` es la única interfaz con los datos** — ningún script accede directamente a `.xlsx` ni `.csv` salvo `load_data.m`. El scaling `×100` es responsabilidad de `build_posterior.m` (campo `Cfg.SCALE_FACTOR`), no del loader.

5. **`LtildeStruct` como tipo canónico de IRFs** — resuelve la asimetría 3D/4D sin ramificaciones esparcidas por el código. `pack_ltilde.m` normaliza antes de pasar a plotting.

6. **Un script de validación por fase** (`validate/validate_faseN.m`) — imprime valores numéricos en consola exclusivamente; nunca genera figuras ni guarda `.mat`.

7. **Outputs binarios fuera del repo** — `output/figures/` y `output/results/` están en `.gitignore`. Solo código y datos fuente van al repositorio.

8. **`main.m` como único punto de entrada** — el usuario siempre llama `main('spec_name')`. Los scripts de `src/` son funciones, no se corren directamente.

9. **`data_bnw.xlsx` con dos hojas** — Hoja 1: datos tabulares (columna 1 = fecha, resto = variables). Hoja 2: metadata con columnas `var_name | role | label`. El loader lee ambas y expone `Dataset.var_roles` para filtrar endógenas/exógenas.

10. **Colapsado de timing scripts** — los 30 archivos de `original/table_4/` se reemplazan por 2 configs + 1 función `run_timing.m` con `switch Cfg.TIMING_VARIANT` interno. Nada se duplica.

---

## Convenciones de nomenclatura

| Elemento | Convención | Ejemplo |
|---|---|---|
| Config files | `spec_<descripcion>.m` | `spec_bnw_is.m` |
| Funciones src | `verb_noun.m` en minúsculas con guión bajo | `load_data.m`, `run_pfa.m` |
| Validate scripts | `validate_faseN.m` con N de dos dígitos | `validate_fase02.m` |
| Variables MATLAB locales | `camelCase` | `ndraws`, `posteriorParams` |
| Structs de salida | `PascalCase` | `Results`, `Cfg`, `Dataset`, `LtildeStruct` |
| Constantes en Cfg | `UPPER_SNAKE` | `Cfg.ND_PFA`, `Cfg.HORIZON` |
| Rutas siempre | `fileparts(mfilename('fullpath'))` | (nunca `pwd` ni `cd`) |

---

## Esquema de config files

Cada config es un script `.m` que popula la struct `Cfg`. El `main.m` lo ejecuta con `run(cfg_path)`.

**Campos obligatorios de `Cfg`:**

```matlab
% ── MODELO ──────────────────────────────────────────────────────────────
Cfg.NLAG           = 4;             % número de lags
Cfg.NEX            = 1;             % 1 = incluir constante, 0 = sin constante
Cfg.HORIZON        = 40;            % horizonte máximo para IRFs
Cfg.INDEX_FEVD     = 40;            % horizonte para FEVD
Cfg.SCALE_FACTOR   = 100;           % factor de escala aplicado a los datos

% ── MUESTREO ────────────────────────────────────────────────────────────
Cfg.MODE           = 'pfa';         % 'pfa' | 'is'
Cfg.ND             = 1e4;           % draws ortogonal-reduced-form
Cfg.MAX_IS_DRAWS   = 1e4;           % max draws efectivos del IS (solo modo 'is')
Cfg.CONJUGATE      = 'structural';  % 'structural' | 'irfs' (solo modo 'is')
Cfg.SEED           = 0;             % semilla rng

% ── RESTRICCIONES ───────────────────────────────────────────────────────
Cfg.HORIZONS_RESTRICT = 0;          % horizontes sobre los que se imponen S y Z
Cfg.NS             = 1;             % objetos en F(theta) con restricciones
% Cfg.S = cell(nvar,1);  Cfg.S{1} = [...];   (se define en cada spec)
% Cfg.Z = cell(nvar,1);  Cfg.Z{1} = [...];   (se define en cada spec)

% ── DATOS ───────────────────────────────────────────────────────────────
Cfg.DATA_FILE      = '';            % vacío → usa data/data_bnw.xlsx del proyecto
                                    % alternativa: ruta absoluta a otro .xlsx

% ── TIMING (solo para run_timing.m) ─────────────────────────────────────
Cfg.TIMING_VARIANT = 4;             % 1–5 según Tabla 4
Cfg.DERIV_SIDED    = 2;             % 1 = one-sided, 2 = two-sided

% ── OUTPUT ──────────────────────────────────────────────────────────────
Cfg.SAVE_RESULTS   = false;         % true → guarda .mat en output/results/
Cfg.PLOT_IRFS      = true;          % true → genera figura
Cfg.ITER_SHOW      = 2000;          % frecuencia de progress display
```

---

## Interfaz del data loader

**Firma:** `Dataset = load_data(Cfg)`

**Lógica interna:**

```matlab
function Dataset = load_data(Cfg)
    % Construir ruta absoluta sin pwd ni cd
    src_root  = fileparts(mfilename('fullpath'));   % .../refactored/src/
    proj_root = fileparts(src_root);               % .../refactored/
    if isempty(Cfg.DATA_FILE)
        xlsx_path = fullfile(proj_root, 'data', 'data_bnw.xlsx');
    else
        xlsx_path = Cfg.DATA_FILE;
    end

    % Hoja 1: datos tabulares
    T1 = readtable(xlsx_path, 'Sheet', 1, 'ReadVariableNames', true);
    Dataset.dates   = T1{:,1};        % primera columna = fechas (datetime)
    Dataset.Y_raw   = T1{:,2:end};    % resto = variables (numeric)

    % Hoja 2: metadata
    T2 = readtable(xlsx_path, 'Sheet', 2, 'ReadVariableNames', true);
    % Columnas esperadas: var_name | role | label
    Dataset.var_names  = T2.var_name';
    Dataset.var_labels = T2.label';
    Dataset.var_roles  = T2.role';

    % Derivados
    endo_mask          = strcmp(Dataset.var_roles, 'endogenous');
    Dataset.nvar       = sum(endo_mask);
    Dataset.nvar_total = size(Dataset.Y_raw, 2);
    Dataset.source_file = xlsx_path;
end
```

**Struct `Dataset` que retorna:**

| Campo | Tipo | Descripción |
|---|---|---|
| `dates` | `[T×1 datetime]` | fechas de la serie |
| `Y_raw` | `[T×nvar_total double]` | datos crudos sin scaling |
| `var_names` | `{1×nvar_total cell}` | nombres cortos |
| `var_labels` | `{1×nvar_total cell}` | labels para gráficos |
| `var_roles` | `{1×nvar_total cell}` | `'endogenous'` / `'exogenous'` |
| `nvar` | `scalar` | número de variables endógenas |
| `nvar_total` | `scalar` | total columnas Hoja 1 (sin fecha) |
| `source_file` | `string` | ruta absoluta al `.xlsx` leído |

El scaling `× Cfg.SCALE_FACTOR` se aplica en `build_posterior.m`, no aquí.

---

## Resolución de la asimetría Ltilde 3D vs 4D

**Causa raíz confirmada en el código original:**

- **PFA:** `Ltilde(h, :, draw)` — almacena solo las IRFs del shock identificado, calculadas directamente con `(J'*(F'^h)*J)*hSigma'*q`.
- **IS:** `Ltilde(h, :, :, draw)` — almacena la matriz completa de IRFs por shock (`nvar × nvar` por horizonte) vía `IRF_horizons()`, porque el IS necesita evaluar restricciones sobre todos los shocks.

**Solución adoptada: struct `LtildeStruct`**

```matlab
% Creado por pack_ltilde.m
LtildeStruct.mode      = 'pfa';   % 'pfa' | 'is'
LtildeStruct.data      = Ltilde;  % array original 3D o 4D
LtildeStruct.shock_idx = 1;       % índice del shock de interés
LtildeStruct.horizon   = 40;
LtildeStruct.nvar      = 5;
LtildeStruct.ndraws    = nd;      % nd para PFA; ne (efectivos) para IS
```

**Extracción unificada en `plot_irfs.m`:**

```matlab
j = LtildeStruct.shock_idx;
switch LtildeStruct.mode
    case 'pfa'
        irf_draws = LtildeStruct.data;             % (horizon+1, nvar, nd)
    case 'is'
        irf_draws = squeeze(LtildeStruct.data(:,:,j,:));  % (horizon+1, nvar, ne)
end
% A partir de aquí el código de plotting es idéntico para ambos modos:
irf_median = median(irf_draws, 3);
irf_lo     = quantile(irf_draws, 0.16, 3);
irf_hi     = quantile(irf_draws, 0.84, 3);
```

---

## Sistema de versionado de especificaciones

- Cada `config/spec_*.m` es la fuente de verdad de una especificación; no existen scripts duplicados.
- `main.m` recibe el nombre del spec como argumento de string: `main('spec_bnw_pfa')`.
- Para variantes puntuales (ej. `nd=5e4`), se crea un nuevo `spec_bnw_pfa_nd5k.m` que hereda del base con el campo sobreescrito; no se duplica lógica de `src/`.
- Los outputs nombran el spec: `output/results/spec_bnw_pfa_<timestamp>.mat`.
- Los 30 archivos de timing de `original/table_4/` se colapsan en 2 configs + `run_timing.m` con `switch Cfg.TIMING_VARIANT` (valores 1–5) y `Cfg.NVAR` (5, 6 ó 7).

---

## Prompt de apertura para Fase 1

Copiar íntegramente al abrir el siguiente chat:

```
Somos el Chat 2 del proyecto SVAR Toolkit. Tarea: Fase 1 — Esqueleto, rutas y data loader.

## Acceso al repo
Token y métodos de acceso en las instrucciones del proyecto.
Repo: https://github.com/cristhianlarrahondo/svartoolkit

## Decisiones de diseño vigentes
Ver refactored/docs/fase_00_arquitectura.md en el repo (leerlo vía API antes de empezar).

## Tu tarea
Implementar en refactored/:
1. Estructura de carpetas completa (crear .gitkeep donde haga falta)
2. .gitignore apropiado
3. main.m — punto de entrada; recibe nombre de spec, carga Cfg, despacha a run_pfa/run_is
4. config/spec_bnw_pfa.m — spec de referencia con todos los campos de Cfg
5. src/load_data.m — data loader según interfaz definida en fase_00
6. validate/validate_fase1.m — verifica:
   a. Que main.m existe y es ejecutable desde cualquier working directory
   b. Que load_data.m lee data_bnw.xlsx y retorna Dataset con los campos correctos
   c. Que Dataset.nvar == 5, Dataset.nvar_total == 5 (o el número real de hojas)
   d. Que las rutas internas NO contienen '..' ni dependen de pwd

Protocolo: hacer commit de todos los archivos antes de pedir al usuario que ejecute.
Verificación: usuario ejecuta validate_fase1.m y pega el output en el chat.
```
