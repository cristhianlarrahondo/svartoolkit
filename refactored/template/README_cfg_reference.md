# SVAR Toolkit — Referencia completa de campos `Cfg`

Este documento cubre **todos** los campos de `Cfg` usados en el toolkit, con
tipo, valores válidos, default, efecto, y en qué sección del pipeline se
usan. Es el complemento detallado de la tabla rápida en `README_template.md`.

Convención de esta tabla: "Obligatorio" significa que `validate_cfg.m` lanza
error si el campo falta. "Opcional" significa que la función que lo usa
tiene un default seguro si el campo no está definido.

---

## 1. Datos

| Campo | Tipo | Valores válidos | Default | Efecto | Usado en |
|---|---|---|---|---|---|
| `DATA_FILE` | char | ruta absoluta a `.xlsx` | — (obligatorio; `''` usa `data/data_bnw.xlsx` legado) | Archivo que lee `load_data.m` | `load_data.m` |
| `SCALE_FACTOR` | double escalar | > 0 | — (obligatorio) | Multiplica `Dataset.Y_raw` antes de construir Y/X. `100` para pasar log-niveles a log-porcentajes; `1` si los datos ya están en la unidad correcta | `build_posterior.m` |
| `VAR_ROLES` | cell de char | `'endogenous'` \| `'exogenous'`, mismo largo que columnas de la hoja `data` | todas `'endogenous'` si no se define | Determina qué columnas entran al VAR. Roles **nunca** se leen del Excel | `load_data.m` |
| `DUMMIES` | struct array | ver `build_dummies.m` (tipos: `oneoff`, `pulse`, `step`, `seasonal`) | `[]` (sin dummies) | Agrega columnas exógenas adicionales a `xt`, al final (después de la constante) | `build_posterior.m`, `build_dummies.m` |
| `TRANSFORMS` | — | — | — | **No implementado.** Se evaluó en el Chat 13 (Lote 6) y se descartó deliberadamente: las transformaciones de series (log, diferencias, etc.) son responsabilidad del usuario **antes** de construir el `.xlsx`. Si ves este campo mencionado en documentación antigua, no tiene efecto en el código actual. | — |

## 2. Modelo VAR

| Campo | Tipo | Valores válidos | Default | Efecto | Usado en |
|---|---|---|---|---|---|
| `NLAG` | double escalar | entero > 0 | — (obligatorio) | Número de rezagos `p` del VAR | `build_posterior.m` |
| `NEX` | double escalar | `0` \| `1` | — (obligatorio) | `1` = incluir constante en `xt`; `0` = sin constante | `build_posterior.m` |
| `HORIZON` | double escalar | entero > 0 | — (obligatorio) | Horizonte máximo para el cual se calculan IRFs | `run_pfa.m`, `run_is.m` |
| `INDEX_FEVD` | double escalar | entero, `≤ HORIZON` | — (obligatorio) | Horizonte al cual se calcula la FEVD | `run_pfa.m`, `run_is.m` |
| `PRIOR` | struct | `PRIOR.type` ∈ `{'diffuse','minnesota','sims_zha','niw_custom','natural_conjugate'}` + hiperparámetros según el tipo (ver `build_posterior.m`) | `struct('type','diffuse')` si no se define | Tipo de prior NIW usado para construir el posterior | `build_posterior.m` |

## 3. Muestreo

| Campo | Tipo | Valores válidos | Default | Efecto | Usado en |
|---|---|---|---|---|---|
| `MODE` | char | `'pfa'` \| `'is'` \| `'timing'` | — (obligatorio) | Selecciona el algoritmo de identificación | `main.m` / pipelines |
| `ND` | double escalar | entero > 0 | — (obligatorio) | Número de draws (candidatos, en IS; totales, en PFA) | `run_pfa.m`, `run_is.m` |
| `MAX_IS_DRAWS` | double escalar | entero > 0 | — (obligatorio si `MODE='is'`) | Máximo de draws efectivos tras el resampling de IS. No aplica en PFA (se incluye por completitud en las specs) | `run_is.m` |
| `CONJUGATE` | char | `'structural'` \| `'irfs'` | — (obligatorio si `MODE='is'`) | Método de cálculo de pesos IS. BNW: PFA usa `'irfs'`, IS usa `'structural'` | `run_pfa.m`, `run_is.m` |
| `SEED` | double escalar | entero ≥ 0 | — (obligatorio) | Semilla de `rng()` antes de estimar — clave para reproducibilidad exacta | pipelines (antes de `run_pfa`/`run_is`) |
| `MIN_ACCEPT_RATE` | double escalar | `(0,1)` | `0.30` | Umbral de tasa de aceptación IS bajo el cual se imprime una advertencia | `run_is.m` |

## 4. Restricciones de identificación

| Campo | Tipo | Valores válidos | Default | Efecto | Usado en |
|---|---|---|---|---|---|
| `HORIZONS_RESTRICT` | double vector | `0` \| `[0 1 2]` \| `0:H` | — (obligatorio) | Horizonte(s) sobre los que aplican `S`/`Z` | `run_pfa.m`, `run_is.m`, `SetupInfo.m` |
| `NS` | double escalar | entero ≥ 1 | — (obligatorio, pero **vestigial**: solo lo usa `run_timing.m`; `run_pfa.m`/`run_is.m` no lo leen) | Se mantiene por compatibilidad con specs de timing | `run_timing.m` |
| `S` | cell(n_vars,1) | cada `S{k}` es `[] ` o matriz `[n_filas x (numel(HORIZONS_RESTRICT)*n_vars)]`, construida con `build_restriction_row.m` | — (obligatorio) | Restricciones de **signo**. **REGLA CRÍTICA (Chat 19, Hallazgo 1): SIEMPRE `cell(n_vars,1)`, sin importar cuántos shocks tengan restricción declarada — nunca `cell(n_shocks,1)`.** | `SetupInfo.m`, `run_pfa.m`, `run_is.m`, `structural_restrictions_generic.m` |
| `Z` | cell(n_vars,1) | ídem `S`, pero para restricciones de **cero**. En PFA debe ir todo vacío (`cell(n_vars,1)` con celdas `[]`) | — (obligatorio) | Restricciones de cero (solo tienen efecto real en `MODE='is'`) | ídem `S` |

## 5. Nombre y guardado

| Campo | Tipo | Valores válidos | Default | Efecto | Usado en |
|---|---|---|---|---|---|
| `SPEC_NAME` | char | cualquier string, se sanitiza para nombre de archivo | `'spec'` | Nombre usado en el `.xlsx` de salida y en la hoja `metadata` | `export_results.m` |
| `SAVE_RESULTS` | logical | `true` \| `false` | — | Si `true`, guarda `.mat` con los draws en `output/results/` (mecanismo separado de `export_results.m`, que siempre exporta a Excel independientemente de este campo) | pipelines |
| `OUTPUT_DIR` | char | ruta absoluta a la carpeta `output/` del proyecto | si no se define: `refactored/output/` (legado, compartido entre proyectos — **evitar**) | Carpeta base donde `plot_irfs.m`, `plot_fevd.m` y `export_results.m` escriben `figures/` y `tables/` | `plot_irfs.m`, `plot_fevd.m`, `export_results.m` |
| `ITER_SHOW` | double escalar | entero > 0 | — | Cada cuántos draws se imprime progreso en consola | `run_pfa.m`, `run_is.m` |

## 6. Output y visualización

| Campo | Tipo | Valores válidos | Default | Efecto | Usado en |
|---|---|---|---|---|---|
| `PLOT_IRFS` | logical | `true` \| `false` | — | Controla si el pipeline llama `plot_irfs.m` (el pipeline decide, no `plot_irfs.m` mismo) | pipelines |
| `SUMMARY_HORIZONS` | double vector 0-based | horizontes dentro de `[0, HORIZON]` | `[0 4 8 20 40]` | Horizontes mostrados en la tabla de consola | `print_summary.m` |
| `CRED_BANDS` | double `[N x 2]` | cuantiles en `(0,1)`, cada fila `[p_lo p_hi]` | `[0.16 0.84]` | Bandas de credibilidad graficadas/exportadas. `plot_fevd.m` solo usa la primera fila | `plot_irfs.m`, `plot_fevd.m`, `export_results.m`, `print_summary.m` |
| `SHOCK_IDX` | double escalar \| vector \| `'all'` | `1..n_vars` | `LtildeStruct.shock_idx` (el shock realmente estimado) | Shock(s) a graficar/exportar/resumir. **Desde el Chat 19 soporta vector y `'all'`** — antes solo aceptaba escalar | `select_irfs.m` (vía `plot_irfs.m`, `export_results.m`, `print_summary.m`) |
| `RESP_IDX` | double vector | `1..n_vars` | todas las variables | Subconjunto de variables de respuesta a graficar/exportar | `select_irfs.m`, `plot_fevd.m`, `export_results.m` |
| `IRF_TYPE` | char | `'irf'` \| `'cirf'` \| `'both'` | `'irf'` | Si se grafican/exportan IRFs, CIRFs (acumuladas), o ambas | `plot_irfs.m`, `export_results.m` |
| `IRF_NORM` | char | `'none'` \| `'1sd'` \| `'unit'` \| `'own_unit'` | `'none'` | Tipo de normalización draw-by-draw aplicada antes de graficar | `plot_irfs.m` (vía `normalize_irfs.m`) |
| `NORM_SHOCK_IDX`, `NORM_VAR`, `NORM_HORIZON`, `NORM_VALUE` | según caso | según `IRF_NORM` | según `IRF_NORM` | Parámetros adicionales requeridos por ciertos tipos de `IRF_NORM` | `normalize_irfs.m` |
| `FIG_SUFFIX` | char | cualquier string (p.ej. `'_pfa'`, `'_test'`) | `''` | Sufijo agregado al nombre de archivo de las figuras, para no pisar corridas anteriores | `plot_irfs.m`, `plot_fevd.m` |

## 7. Timing (solo `run_timing.m`, no aplica a PFA/IS)

| Campo | Tipo | Valores válidos | Default | Efecto | Usado en |
|---|---|---|---|---|---|
| `TIMING_VARIANT` | double escalar \| `[]` | `1..5` (ver Tabla 4 del paper) o `[]` si no aplica | `[]` | Variante de timing a medir | `run_timing.m` |
| `DERIV_SIDED` | double escalar | `1` \| `2` | `2` | `1` = derivada numérica one-sided, `2` = two-sided | `run_timing.m` |

---

## Campos "de output" vs "de estimación" (Chat 19, Hallazgo 5)

Desde el Chat 19, `src/get_output_fields.m` define la lista canónica de
campos que **no afectan el muestreo** y por tanto pueden recargarse desde la
spec sin volver a estimar (ver `src/refresh_cfg_output.m` y la Sección 5 de
`pipeline_template.m`/`pipeline_bnw.m`):

```
SUMMARY_HORIZONS, CRED_BANDS, SHOCK_IDX, RESP_IDX, IRF_TYPE, IRF_NORM,
NORM_SHOCK_IDX, NORM_VAR, NORM_HORIZON, NORM_VALUE, PLOT_IRFS,
FIG_SUFFIX, OUTPUT_DIR
```

Todo lo demás (`DATA_FILE`, `NLAG`, `HORIZON`, `MODE`, `ND`, `S`, `Z`,
`SEED`, `HORIZONS_RESTRICT`, `PRIOR`, `DUMMIES`, ...) es "de estimación": si
lo editas, necesitas volver a correr `build_posterior`/`run_pfa`/`run_is`
para que el cambio tenga efecto.

## Ver también

- `README_template.md` — guía paso a paso para crear un caso nuevo
- `src/build_restriction_row.m` — convención de columnas de `S`/`Z`
- `src/print_restriction_matrix.m` — vista de conjunto de las restricciones declaradas
- `src/get_output_fields.m` / `src/refresh_cfg_output.m` — separación estimación/output
- `validate/validate_cfg.m` — validación automática de `Cfg` antes de estimar
