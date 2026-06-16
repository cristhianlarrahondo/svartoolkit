# SVAR Toolkit — Ejemplo: Mercado Petrolero Global

## Resumen

Este ejemplo aplica el **SVAR Toolkit** (basado en Arias, Rubio-Ramírez y Waggoner 2018, ARW) a datos del mercado petrolero global, siguiendo el esquema de identificación de Kilian & Murphy (2012) discutido en Baumeister & Hamilton (2019, AER).

El caso de uso demuestra cómo usar el toolkit con un dataset distinto al de referencia (BNW), con variables mensuales y lags de 2 años.

---

## Contexto económico

El modelo identifica shocks estructurales en el mercado mundial de petróleo. La especificación replica el esquema de Kilian & Murphy (2012), que distingue:

- **Shock de oferta** (identificado): perturbación a la producción mundial de crudo.
- **Shock de demanda agregada**: variación en la actividad económica global.
- **Shock de demanda específica de petróleo**: movimiento en inventarios no explicado por oferta ni actividad.

La restricción central de identificación es que la producción de petróleo **no responde contemporáneamente** a la actividad económica (rigidez de la oferta en el corto plazo), combinada con la restricción de signo de que un shock positivo de oferta **sube la producción** y **baja el precio**.

---

## Variables del modelo (n = 4)

| Variable | Descripción | Transformación |
|---|---|---|
| `prod_growth` | Producción mundial de petróleo | 100 × Δlog(producción) |
| `act_growth` | Actividad económica global (índice IP OECD+6) | 100 × Δlog(IP) |
| `rpo_growth` | Precio real del petróleo (WTI) | 100 × Δlog(precio real) |
| `dinv` | Cambio en inventarios | 100 × Δinventarios / producción t-1 |

Las transformaciones vienen **aplicadas en el archivo xlsx**. El `SCALE_FACTOR = 1` en las specs (a diferencia del caso BNW donde los datos estaban en logaritmos sin escalar).

---

## Parámetros del VAR

| Parámetro | Valor | Justificación |
|---|---|---|
| Lags (p) | 24 | Frecuencia mensual; 2 años de dinámica |
| Constante | Sí | `Cfg.NEX = 1` |
| Muestra efectiva | 1973M2 – 2016M12 | T = 527 obs |
| Datos en xlsx | Desde 1971M2 | 24 meses previos para lags iniciales |
| Horizonte IRF | 60 meses | 5 años |
| Draws (testing) | nd = 500 | Para desarrollo rápido |
| Draws (producción) | nd = 5000 | Resultado final publicable |

---

## Esquema de identificación

### spec_oil_pfa — Solo sign restrictions

Identifica el **shock de oferta** (columna 1 de L₀) con:

| Variable | Restricción de signo en h=0 |
|---|---|
| prod_growth | ≥ 0 (producción sube) |
| act_growth | sin restricción |
| rpo_growth | ≤ 0 (precio baja) |
| dinv | sin restricción |

### spec_oil_is — Sign + zero restriction

Mismas sign restrictions, más:

| Restricción | Descripción |
|---|---|
| Zero: Ltilde(h=0, prod_growth, shock de actividad) = 0 | La oferta no responde contemporáneamente a la actividad |

Esta restricción de cero (Z{2} = e₁') permite usar el modo IS del toolkit, que maneja identificación mixta (sign + zero) exactamente como en el paper ARW 2018.

---

## Estructura de archivos

```
refactored/examples/oil_market/
├── data/
│   └── data_bau.xlsx          ← Datos: 1971M2–2016M12 (549 obs, 5 columnas)
├── config/
│   ├── spec_oil_pfa.m         ← Spec PFA (solo signs)
│   └── spec_oil_is.m          ← Spec IS (signs + zero)
├── main_oil.m                  ← Script de uso completo (pedagógico)
├── validate_oil.m              ← Verificación funcional
└── README_oil.md               ← Este archivo
```

---

## Cómo correr el ejemplo

### Opción 1: Flujo completo (main_oil.m)

```matlab
% Desde MATLAB, estando en la carpeta refactored/
run('examples/oil_market/main_oil.m')
```

Esto corre PFA e IS con nd=500 (testing), imprime un resumen en consola y exporta resultados a `output/tables/spec_oil_pfa_results.xlsx`.

### Opción 2: Correr una spec específica vía main.m del toolkit

```matlab
% Desde refactored/
cd('ruta/a/refactored')
addpath('examples/oil_market/config')
main('spec_oil_pfa')   % o 'spec_oil_is'
```

### Opción 3: Producción (nd = 5000)

Para aumentar el número de draws a producción, editar las specs:

```matlab
% En spec_oil_pfa.m y spec_oil_is.m:
Cfg.ND           = 5000;
Cfg.MAX_IS_DRAWS = 5000;
Cfg.SAVE_RESULTS = true;   % guarda .mat en output/results/
```

---

## Cómo interpretar los outputs

### Resumen IRF en consola (`print_summary`)

La tabla muestra para el **shock de oferta** (columna 1):

- **Mediana** del IRF a cada horizonte
- **Banda [16%, 84%]** de credibilidad bayesiana

Un shock positivo de oferta debería mostrar:
- `prod_growth` mediana positiva en h=0 (sign restriction activa)
- `rpo_growth` mediana negativa en h=0 (sign restriction activa)
- Reversión gradual en horizontes más largos

### Archivo Excel (`export_results`)

Generado en `output/tables/spec_oil_pfa_results.xlsx` con 5 hojas:

| Hoja | Contenido |
|---|---|
| `metadata` | Spec, fecha, variables, modo, semilla |
| `irf_summary` | Mediana + bandas para todos los horizontes |
| `cirf_summary` | Ídem para IRFs acumulados (si IRF_TYPE incluye 'cirf') |
| `fevd_summary` | Descomposición de varianza del error de predicción |
| `run_diagnostics` | ESS, tasa de aceptación, tiempo, nd |

### Diagnósticos IS

- **ESS (ne)**: effective sample size tras resampling por importancia. Un valor alto indica que los pesos son uniformes y el estimador IS es eficiente.
- **Tasa de aceptación**: fracción de draws que satisfacen las restricciones de signo. Con 2 sign restrictions moderadas, tasas de 30–60% son razonables.
- **Alerta**: si la tasa cae por debajo de `Cfg.MIN_ACCEPT_RATE` (default 0.05), el toolkit imprime una advertencia. Solución: aumentar `Cfg.ND`.

---

## Diferencias con el caso BNW (referencia)

| Característica | BNW | Oil Market |
|---|---|---|
| Variables | 5 (macro US) | 4 (petróleo global) |
| Frecuencia | Trimestral | Mensual |
| Lags | 4 | 24 |
| SCALE_FACTOR | 100 (datos en log) | 1 (ya en %) |
| Shock identificado | Optimismo (news shock) | Oferta de petróleo |
| Zero restriction | TFP h=0 (PFA y IS) | Oferta no responde a actividad (solo IS) |

---

## Extensión a nuevos casos

Para aplicar el toolkit a otro dataset:

1. Preparar el xlsx con dos hojas (datos + varinfo). Ver `src/load_data.m`.
2. Copiar `spec_oil_pfa.m` como template. Ajustar: `NLAG`, `HORIZON`, `SCALE_FACTOR`, `DATA_FILE`, matrices `Z` y `S`.
3. Crear carpeta en `examples/nombre_caso/` con la misma estructura.
4. Correr `validate_cfg(Cfg)` antes de lanzar `main()` para verificar la config.

---

## Referencias

- Arias, J.E., Rubio-Ramírez, J.F., Waggoner, D.F. (2018). Inference Based on Structural Vector Autoregressions Identified with Sign and Zero Restrictions: Theory and Applications. *Econometrica*, 86(2), 685–720.
- Baumeister, C., Hamilton, J.D. (2019). Structural Interpretation of Vector Autoregressions with Incomplete Identification: Revisiting the Role of Oil Supply and Demand Shocks. *American Economic Review*, 109(5), 1873–1910.
- Kilian, L., Murphy, D.P. (2012). Why Agnostic Sign Restrictions Are Not Enough: Understanding the Dynamics of Oil Market VAR Models. *Journal of the European Economic Association*, 10(5), 1166–1188.
