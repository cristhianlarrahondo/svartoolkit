# SVAR Toolkit — Cómo crear un nuevo caso de estudio

Esta carpeta `template/` es tu punto de partida para aplicar el toolkit a cualquier dataset nuevo.

---

## Los 5 pasos para empezar

### Paso 1 — Prepara tu dataset

Tu archivo `.xlsx` debe tener **dos hojas**:

**Hoja 1: `data`**
| fecha | var_1 | var_2 | ... |
|---|---|---|---|
| 31/01/1970 | 0.12 | -0.03 | ... |

- Fechas en formato DD/MM/YYYY (último día del mes para datos mensuales)
- Variables ya transformadas (log-diferencias, %, etc.)
- Sin celdas vacías en la muestra que usarás

**Hoja 2: `varinfo`**
| var_name | role | label |
|---|---|---|
| prod_growth | endogenous | Global oil production (mbpd) |
| act_growth | endogenous | Global activity index |

- `role`: siempre `endogenous` para variables del VAR
- `label`: nombre largo para gráficas y tablas
- El **orden de las filas** determina los índices (var_1, var_2, ...) usados en las restricciones
- Si tu Excel trae MÁS variables de las que quieres usar en un caso de
  estudio particular, no hace falta editar el Excel: usa `Cfg.VARS` en la
  spec para seleccionar/reordenar por nombre (ver Paso 3 y
  `README_cfg_reference.md`, campo `VARS`) — Chat 19, Hallazgo 7.

---

### Paso 2 — Copia y renombra la carpeta

```
cp -r refactored/template/  refactored/projects/mi_caso/
```

Resultado esperado:
```
refactored/projects/mi_caso/
├── data/                    ← pon aquí tu xlsx
├── config/
│   ├── spec_template_pfa.m  → renombra a spec_micaso_pfa.m
│   └── spec_template_is.m   → renombra a spec_micaso_is.m
└── pipeline_template.m      → renombra a pipeline_micaso.m
```

---

### Paso 3 — Edita las specs

Abre `spec_micaso_pfa.m` y edita las secciones marcadas con `← EDITAR`:

1. **Datos**: cambia el nombre del archivo xlsx
2. **Modelo**: ajusta `NLAG`, `HORIZON`, `SCALE_FACTOR`
3. **Restricciones**: declara tus restricciones Z y S

#### Cómo declarar restricciones

> **REGLA (Chat 19) — LEE ESTO PRIMERO:** `Cfg.S` y `Cfg.Z` **siempre** se
> dimensionan a `cell(n_vars, 1)`, sin importar cuántos shocks tengan
> restricciones realmente declaradas. Con 6 variables y 4 shocks de
> interés, sigue siendo `cell(6, 1)`, **no** `cell(4, 1)`. Los shocks sin
> restricción simplemente quedan con `Cfg.S{k} = []`. Esto lo exigen
> internamente `SetupInfo.m`, `run_pfa.m`, `run_is.m` y
> `structural_restrictions_generic.m` (todos indexan `1:n_vars`). Si usas
> `cell(n_shocks,1)`, obtendrás un error de dimensiones al estimar.
> Ver `README_cfg_reference.md` para la referencia completa de campos.

Las variables tienen **índices numéricos** según el orden en la hoja `varinfo`:
- var_1 = primera fila de varinfo
- var_2 = segunda fila
- etc.

Cada fila de `Cfg.S{k}`/`Cfg.Z{k}` se construye con la función compartida
`build_restriction_row.m` (vive en `refactored/src/`), que calcula el
offset de columna correcto para cualquier horizonte — no la armes a mano
con `eye(n_vars)`:

```matlab
row = build_restriction_row(var_idx, horizon_idx, n_vars, n_horizons, sign_val)
```

- `var_idx`: índice ordinal de la variable (1..n_vars)
- `horizon_idx`: índice **ordinal** dentro de `Cfg.HORIZONS_RESTRICT` (NO
  es el valor del horizonte). Si `HORIZONS_RESTRICT = [0 1 2]`,
  `horizon_idx=2` se refiere a h=1 (el segundo elemento del vector).
- `n_vars`: número de variables endógenas (`Dataset.nvar`)
- `n_horizons`: `numel(Cfg.HORIZONS_RESTRICT)`
- `sign_val`: `+1` (positivo) o `-1` (negativo) para `S`; `+1` por
  convención para `Z` (el signo no importa en `Z`)

**Restricciones de signo (S)** — para PFA e IS:

```matlab
n_vars = 4;                              % número de variables endógenas
Cfg.HORIZONS_RESTRICT = 0;                % solo h=0
n_horizons = numel(Cfg.HORIZONS_RESTRICT);

% "La variable 1 responde POSITIVAMENTE al shock 1 en h=0"
Cfg.S{1} = build_restriction_row(1, 1, n_vars, n_horizons, 1);

% "La variable 3 responde NEGATIVAMENTE al shock 1 en h=0"
Cfg.S{1} = [Cfg.S{1}; build_restriction_row(3, 1, n_vars, n_horizons, -1)];

% "La variable 2 responde POSITIVAMENTE al shock 2 en h=0"
Cfg.S{2} = build_restriction_row(2, 1, n_vars, n_horizons, 1);
```

**Restricciones de cero (Z)** — solo para IS:

```matlab
% "La variable 1 NO responde al shock 2 en h=0"
% (prod no responde contemporáneamente a actividad)
Cfg.Z{2} = build_restriction_row(1, 1, n_vars, n_horizons, 1);
```

**Horizonte de las restricciones**:

```matlab
Cfg.HORIZONS_RESTRICT = 0;        % solo en h=0 (lo más común)
Cfg.HORIZONS_RESTRICT = [0 1 2];  % en h=0, h=1 y h=2
Cfg.HORIZONS_RESTRICT = 0:4;      % en h=0 hasta h=4 (estilo Uhlig 2005)
```

**Ejemplo multi-horizonte** (`HORIZONS_RESTRICT = [0 1 2]`, la variable 1
responde positivo en los tres horizontes declarados):

```matlab
n_vars = 4;
Cfg.HORIZONS_RESTRICT = [0 1 2];
n_horizons = numel(Cfg.HORIZONS_RESTRICT);   % = 3

Cfg.S{1} = [ ...
  build_restriction_row(1, 1, n_vars, n_horizons, 1); ...  % var_1+ en h=0 (horizon_idx=1)
  build_restriction_row(1, 2, n_vars, n_horizons, 1); ...  % var_1+ en h=1 (horizon_idx=2)
  build_restriction_row(1, 3, n_vars, n_horizons, 1) ];    % var_1+ en h=2 (horizon_idx=3)
```

> **Nota — limitación real de PFA**: PFA (Mountford & Uhlig, 2009)
> identifica **un solo choque por corrida** (limitación estructural del
> método, no del toolkit). Si tu spec de PFA declara `Cfg.S{k}` no vacío
> para más de un índice `k`, `run_pfa.m` lo detecta automáticamente, emite
> un warning, y devuelve `Results.skipped = true` en vez de fallar más
> adelante — usa `Cfg.MODE='is'` con la spec IS equivalente en ese caso,
> que sí resuelve múltiples choques restringidos simultáneamente.
> PFA solo usa restricciones de signo (`S`); deja `Z` vacío. IS puede usar
> `S` y `Z` juntos.

---

### Paso 4 — Edita el pipeline

Abre `pipeline_micaso.m` y edita la **Sección 0**:

```matlab
REF_ROOT  = '/ruta/absoluta/a/refactored';   % ← tu ruta
PROJ_NAME = 'mi_caso';                        % ← nombre de tu carpeta
```

También actualiza los nombres de las specs en las Secciones 1–6:
```matlab
SPEC_PFA = 'spec_micaso_pfa';
SPEC_IS  = 'spec_micaso_is';
```

---

### Paso 5 — Ejecuta sección a sección

Abre `pipeline_micaso.m` en el Editor de MATLAB y ejecuta con **Ctrl+Enter**:

| Sección | Qué hace | Cuándo correrla |
|---|---|---|
| **Sección 0** | Setup de rutas | Primera vez y cada sesión nueva |
| **Sección 1** | Carga datos, muestra estadísticas | Después de Sección 0 |
| **Sección 2** | Imprime config y restricciones en lenguaje natural | Para verificar antes de estimar |
| **Sección 3** | Estimación PFA (nd=500 testing) — avisa de inmediato si PFA fue omitido por restringir más de un choque | Después de verificar config |
| **Sección 4** | Estimación IS (nd=500 testing) | Después de Sección 3 |
| **Sección 5** | IRF, FEVD, diagnósticos, gráficas | Después de Secciones 3 y 4 |
| **Sección 6** | Export a Excel | Al final |

> **Para producción** (resultados finales): en las Secciones 3 y 4, cambia `Cfg_pfa.ND = 5000` antes de correr.

> **Editar solo un parámetro de gráfica** (Chat 19): si después de estimar
> quieres cambiar `SHOCK_IDX`, `CRED_BANDS`, `SUMMARY_HORIZONS`, `IRF_TYPE`,
> `IRF_NORM` u `OUTPUT_DIR`, edita la spec y vuelve a correr **solo la
> Sección 5** — el pipeline recarga esos campos automáticamente
> (`refresh_cfg_output.m`) sin necesidad de re-estimar. Si en cambio
> cambias algo que sí afecta el muestreo (`S`, `Z`, `NLAG`, `HORIZON`,
> `MODE`, `ND`, `SEED`, ...), sí necesitas re-correr las Secciones 3–4.

---

## Referencia rápida de campos Cfg

> Esta es una referencia RÁPIDA. Para la lista completa de TODOS los
> campos Cfg (tipo, valores válidos, default, efecto, dónde se usan),
> ver **`README_cfg_reference.md`**.

| Campo | Descripción | Típico |
|---|---|---|
| `DATA_FILE` | Ruta al xlsx | — |
| `VARS` | Selecciona/reordena columnas de la hoja `data` por nombre, sin editar el Excel (opcional; Chat 19) | ver `README_cfg_reference.md` |
| `SCALE_FACTOR` | Factor de escala de los datos | `1` (ya en %) o `100` (log) |
| `NLAG` | Número de lags del VAR | `4` (trim) / `12` o `24` (mens) |
| `NEX` | Constante: `1`=sí, `0`=no | `1` |
| `HORIZON` | Horizonte máximo IRF | `20`–`60` |
| `INDEX_FEVD` | Default de `FEVD_HORIZONS` si este no se define | `≤ HORIZON` |
| `FEVD_HORIZONS` | Horizontes en los que se calcula la FEVD (Chat 19). Campo DE ESTIMACIÓN, no de output | `1:HORIZON` para la curva completa |
| `ND` | Draws (testing: 500, prod: 5000+) | `500` |
| `SEED` | Semilla aleatoria | `0` |
| `HORIZONS_RESTRICT` | Horizontes de las restricciones | `0` |
| `S{k}` | Sign restrictions sobre shock k (vía `build_restriction_row`). **`S` siempre es `cell(n_vars,1)`** — ver regla arriba | ver arriba |
| `Z{k}` | Zero restrictions sobre shock k (solo IS, vía `build_restriction_row`). **`Z` siempre es `cell(n_vars,1)`** | ver arriba |
| `SHOCK_IDX` | Shock(s) identificado(s) a graficar/exportar (y, en IS, a incluir en la FEVD) | escalar \| vector \| `'all'` (soporta varios desde Chat 19) |
| `SHOCK_NAMES` | Nombre de cada shock, para leyendas/títulos/nombres de archivo (Chat 19) | `{'supply','demand',...}` |
| `CRED_BANDS` | Bandas de credibilidad | `[0.16 0.84]` |
| `SUMMARY_HORIZONS` | Horizontes para tabla consola | `[0 1 4 8 12 20]` |
| `OUTPUT_DIR` | Carpeta de salida del proyecto (figuras/tablas) | `fullfile(ex_dir, 'output')` — **siempre defínelo**, o las figuras/tablas caen en el folder legado compartido `refactored/output/` |

---

## Ver también

- `projects/oil_market/pipeline_oil.m` — ejemplo con datos reales (pausado, ver su README)
- `projects/bnw/pipeline_bnw.m` — ejemplo de referencia completo (BNW 2018), con `build_restriction_row` y aviso de `Results.skipped`
- `src/build_restriction_row.m` — documentación completa de la convención de columnas
- `src/print_restriction_matrix.m` — vista de conjunto variables x shocks de tus restricciones (Chat 19)
- `src/load_data.m` — documentación del formato de datos
- `validate/validate_cfg.m` — validación automática de la config antes de estimar
- `README_cfg_reference.md` — referencia completa de TODOS los campos Cfg (Chat 19)
- `src/get_output_fields.m` / `src/refresh_cfg_output.m` — permite editar parámetros de gráfica/exportación (SHOCK_IDX, CRED_BANDS, SUMMARY_HORIZONS, IRF_TYPE, IRF_NORM, OUTPUT_DIR) y re-correr la Sección 5 del pipeline SIN volver a estimar (Chat 19)


