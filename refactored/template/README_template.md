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

---

### Paso 2 — Copia y renombra la carpeta

```
cp -r refactored/template/  refactored/examples/mi_caso/
```

Resultado esperado:
```
refactored/examples/mi_caso/
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

Las variables tienen **índices numéricos** según el orden en la hoja `varinfo`:
- var_1 = primera fila de varinfo
- var_2 = segunda fila
- etc.

**Restricciones de signo (S)** — para PFA e IS:

```matlab
n_vars = 4;          % número de variables endógenas
e      = eye(n_vars);

% "La variable 1 responde POSITIVAMENTE al shock 1 en h=0"
Cfg.S{1} = e(1,:);

% "La variable 3 responde NEGATIVAMENTE al shock 1 en h=0"
Cfg.S{1} = [Cfg.S{1}; -e(3,:)];

% "La variable 2 responde POSITIVAMENTE al shock 2 en h=0"
Cfg.S{2} = e(2,:);
```

**Restricciones de cero (Z)** — solo para IS:

```matlab
% "La variable 1 NO responde al shock 2 en h=0"
% (prod no responde contemporáneamente a actividad)
Cfg.Z{2} = e(1,:);
```

**Horizonte de las restricciones**:

```matlab
Cfg.HORIZONS_RESTRICT = 0;        % solo en h=0 (lo más común)
Cfg.HORIZONS_RESTRICT = [0 1 2];  % en h=0, h=1 y h=2
Cfg.HORIZONS_RESTRICT = 0:4;      % en h=0 hasta h=4 (estilo Uhlig 2005)
```

> **Nota**: PFA usa solo S (dejar Z vacío). IS puede usar S y Z.
> Si no tienes restricciones de cero, usa solo PFA.

---

### Paso 4 — Edita el pipeline

Abre `pipeline_micaso.m` y edita la **Sección 0**:

```matlab
REF_ROOT = '/ruta/absoluta/a/refactored';   % ← tu ruta
EX_NAME  = 'mi_caso';                        % ← nombre de tu carpeta
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
| **Sección 3** | Estimación PFA (nd=500 testing) | Después de verificar config |
| **Sección 4** | Estimación IS (nd=500 testing) | Después de Sección 3 |
| **Sección 5** | IRF, FEVD, diagnósticos, gráficas | Después de Secciones 3 y 4 |
| **Sección 6** | Export a Excel | Al final |

> **Para producción** (resultados finales): en las Secciones 3 y 4, cambia `Cfg_pfa.ND = 5000` antes de correr.

---

## Referencia rápida de campos Cfg

| Campo | Descripción | Típico |
|---|---|---|
| `DATA_FILE` | Ruta al xlsx | — |
| `SCALE_FACTOR` | Factor de escala de los datos | `1` (ya en %) o `100` (log) |
| `NLAG` | Número de lags del VAR | `4` (trim) / `12` o `24` (mens) |
| `NEX` | Constante: `1`=sí, `0`=no | `1` |
| `HORIZON` | Horizonte máximo IRF | `20`–`60` |
| `INDEX_FEVD` | Horizonte para FEVD | `≤ HORIZON` |
| `ND` | Draws (testing: 500, prod: 5000+) | `500` |
| `SEED` | Semilla aleatoria | `0` |
| `HORIZONS_RESTRICT` | Horizontes de las restricciones | `0` |
| `S{k}` | Sign restrictions sobre shock k | ver arriba |
| `Z{k}` | Zero restrictions sobre shock k (solo IS) | ver arriba |
| `SHOCK_IDX` | Índice del shock identificado | `1` |
| `CRED_BANDS` | Bandas de credibilidad | `[0.16 0.84]` |
| `SUMMARY_HORIZONS` | Horizontes para tabla consola | `[0 1 4 8 12 20]` |

---

## Ver también

- `examples/oil_market/pipeline_oil.m` — ejemplo completo con datos reales
- `examples/oil_market/config/spec_oil_pfa.m` — spec con restricciones documentadas
- `src/load_data.m` — documentación del formato de datos
- `validate/validate_cfg.m` — validación automática de la config antes de estimar
