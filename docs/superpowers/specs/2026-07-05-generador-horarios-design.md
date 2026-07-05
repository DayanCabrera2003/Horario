# Diseño — Generador de horarios (v1)

- **Fecha:** 2026-07-05
- **Autor:** dcabrera (con tutor Fernando Rodríguez)
- **Estado:** Aprobado en brainstorming, pendiente de revisión de spec

## 1. Contexto y objetivo

La tesis automatiza la generación y el mantenimiento de los horarios de la facultad, que
hoy se arman a mano en una hoja de cálculo (LibreOffice). El tutor entregó una **prueba de
concepto** hecha manualmente (`propuesta-de-horarios-2026-07-03-para-enviar.ods`) que ya hace
casi todo lo deseado, pero cuyas fórmulas hubo que copiar y pegar celda por celda. Eso es lo
que se automatiza.

El plan del tutor es **iterativo y práctico**: él manda "batches" de indicaciones, el estudiante
las materializa en código, y con las primeras interacciones se descubre qué se pide normalmente
para luego darle al tutor una herramienta/formato autónomo. Lemas guía: *"terminado es mejor que
perfecto"* y *"tan cableado como nuestras conciencias lo permitan"* (primero valores fijos,
después parametrizar).

**Objetivo de v1:** un generador en **Python + openpyxl** que, a partir de un archivo de
configuración, produzca un workbook `.xlsx` con **fórmulas vivas** y **formato condicional**,
reproduciendo (y superando) la prueba de concepto del tutor.

## 2. Alcance

### Dentro de v1
- Generar el workbook completo: hoja oculta `Datos`, una hoja por grupo, y la hoja `Aulas`.
- Modo **esqueleto vacío** (horario sin asignar) y modo **copia fiel** (horario cargado desde
  config), con el mismo generador; la diferencia es solo si se provee el archivo de horarios.
- Fórmulas vivas: `Asignadas` (COUNTIF), `Faltan`, y ocupación de aulas (concatenación de grupos).
- Formato condicional: asignatura desconocida, aula inexistente (amarillo), asignatura
  sobre-planificada (rojo), frecuencia exacta cumplida (verde), color por "año" en `Aulas` con
  detección de conflicto entre años.
- Dropdowns (validación de datos) para asignatura y aula, con fuente en `Datos`.

### Fuera de v1 (posibles batches futuros)
- Resolución/optimización automática del horario (solver). v1 solo construye el "esqueleto
  inteligente"; el humano rellena las asignaciones.
- Parametrización total (nº de turnos, celdas por intersección, nº de grupos) más allá de lo
  ya centralizado en `layout.py`.
- Entrada vía Excel o UI. v1 usa archivos de configuración.

## 3. Convenio de nombres (dominio)

Identificador de grupo `Casg`:
- `C` = carrera (facultad tiene **C, D, M**),
- `a` = año,
- `s` = sesión (solo **C1** tiene 2 sesiones; el resto tiene 1),
- `g` = grupo.

Ejemplo: `N213` = carrera N, año 2, sesión 1, grupo 3. Grupos de ejemplo:
`C111, C112, C113, C121, C122, C211, C212, C311, C312, C411, C412, M111, M211, M311, M411,
D111, D211, D311, D411`.

Un **"año"** (a efectos de color) es la combinación carrera+año: `C1..C4, M1..M4, D1..D4`.
Cada año tiene un color propio **definido en código** (el usuario no lo cambia).

## 4. Configuración (entrada)

Formato **YAML** (legible, admite comentarios, editable a mano). Dos archivos:

### `config/facultad.yaml` — estructura estable
```yaml
aulas: [Aula 1, Aula 2, Aula 3, Aula 4, Aula 5, Aula 6, Aula 7, Aula 8, Aula 9, Lab]
dias:   [Lunes, Martes, Miércoles, Jueves, Viernes]
turnos: 6

carreras:
  C:
    nombre: Carrera C
    años:
      1:
        sesiones:
          1: { grupos: [1, 2, 3] }   # C111, C112, C113
          2: { grupos: [1, 2] }      # C121, C122
        asignaturas:
          - { id: AMI-C,  nombre: "Análisis Matemático I (Conf)", frecuencia: 1 }
          - { id: AMI-CP, nombre: "Análisis Matemático I (C.P.)", frecuencia: 2 }
          # ...
      2:
        sesiones: { 1: { grupos: [1, 2] } }
        asignaturas: [ ... ]
  M: { ... }
  D: { ... }
```

Decisiones:
- El id `Casg` se **deriva**, no se escribe a mano.
- Las **asignaturas viven a nivel de año** (todos los grupos de un año comparten tabla, como en
  la demo). **En v1 las dos sesiones de C1 comparten la misma tabla de asignaturas.** Extensible
  a nivel de sesión sin romper el esquema.
- Los **colores por año NO van en config**; van en código.

### `config/horarios.yaml` — asignaciones (opcional)
```yaml
C111:
  Lunes:  { 1: { asig: L-C,   aula: Aula 6 }, 2: { asig: AM1-C, aula: Aula 3 } }
  Martes: { 1: { asig: Pro-C, aula: Aula 4 } }
  # días/turnos sin entrada → celda vacía
```
Si el archivo no se provee → **esqueleto vacío**.

### Validación de config
- `config.py` valida y da errores claros: carrera/año/grupo bien formados, aulas del horario
  existen en la lista maestra, asignaturas referenciadas existen, turnos dentro de rango.

## 5. Arquitectura (modular ligero)

```
tesis-horarios/
├── config/
│   ├── facultad.yaml
│   └── horarios.yaml            (opcional)
├── horarios/
│   ├── __init__.py
│   ├── config.py                # carga + valida YAML → objetos del modelo
│   ├── modelo.py                # dataclasses del dominio
│   ├── estilos.py               # colores por año + reglas de formato condicional
│   ├── layout.py                # mapeo único de filas/columnas
│   ├── hoja_datos.py            # hoja oculta con listas maestras y auxiliares
│   ├── hoja_grupo.py            # construye una hoja de grupo
│   ├── hoja_aulas.py            # construye la hoja Aulas
│   └── generador.py             # orquesta: config → Workbook → .xlsx
├── tests/
├── generar.py                   # CLI de entrada
└── pyproject.toml
```

### Modelo de dominio (`modelo.py`, dataclasses puras)
```
Aula(nombre)
Asignatura(id, nombre, frecuencia)
Grupo(carrera, año, sesion, numero)      → .id == "C111", .año_codigo == "C1"
Anio(carrera, numero, asignaturas[])     → .color
Facultad(carreras, aulas, dias, turnos, grupos[])
Asignacion(asig, aula)
Horario(grupo_id, celdas: {(dia, turno): Asignacion})
```

### Principio de aislamiento
- `layout.py` es la **única** fuente de posiciones. Cambiar "2 celdas por cruce → 3" o mover una
  tabla es un cambio de un solo lugar; el resto lo respeta.
- Cada constructor de hoja no conoce las internas de los otros; se comunican por el modelo y por
  `layout`.

## 6. Layout de las hojas

### Hoja de grupo (ej. `C111`)
- `A1 = "Grupo"`, `B1 = "C111"`.
- **Tabla de horario:** filas 4–15 (2 filas por turno: **asignatura arriba, aula abajo**),
  columnas C–G (Lun–Vie), fila 3 con encabezado de días, columna A con etiqueta de turno.
- **Tabla de asignaturas** (a la derecha, cols I–M): `id | nombre | Frec | Asignadas | Faltan`.

### Hoja oculta `Datos`
- Lista maestra de aulas (fuente de dropdowns y de la validación "aula inexistente").
- Celdas auxiliares para la "firma de año" de cada celda de `Aulas` (ver §7).

### Hoja `Aulas`
- 5 bloques (uno por día); columnas = aulas; filas = 6 turnos; cada celda con fórmula que junta
  los grupos que ocupan esa aula/turno/día, separados por coma.

## 7. Fórmulas vivas y formato condicional

### Fórmulas
- `Asignadas` = `COUNTIF(rango_horario_del_grupo; id_asignatura)`.
- `Faltan` = `Frec − Asignadas`.
- Celda de ocupación en `Aulas` = concatenación sobre **todos** los grupos:
  `IF(hoja_grupo!celda_aula = aula; id_grupo & " "; "")`, luego `TRIM`/`SUBSTITUTE` de espacios a
  comas. Generada por código para los N grupos.

### Formato condicional
| Dónde | Regla | Color |
|---|---|---|
| Horario, celda asignatura | abreviatura no está en la tabla de asignaturas del grupo | naranja |
| Horario, celda aula | aula no está en `Datos` | amarillo |
| Tabla asignaturas | `Asignadas > Frec` | rojo |
| Tabla asignaturas | `Asignadas = Frec` | verde |
| Hoja `Aulas` | color según el "año" del grupo en la celda | 1 regla por año |
| Hoja `Aulas` | años distintos en la misma celda | conflicto (rojo intenso) |

### Resolución del color por año en `Aulas` (antes una limitación)
El prefijo del id codifica el año (`C111 → C1`). Por cada celda de `Aulas` se calcula una
**"firma de año"** en la hoja `Datos`:
- **0 grupos** → sin color.
- **1 año** (uno o varios grupos, todos del mismo año) → color de ese año (caso normal: grupos
  del mismo año comparten conferencia).
- **≥2 años distintos** → color de **conflicto** reservado; es una anomalía real (aula compartida
  por años distintos en el mismo turno) que el planificador debe ver.

Implementación: `hoja_datos.py` genera, por celda de `Aulas`, una firma con fórmulas
`COUNTIF` sobre las hojas de grupo (una comprobación de presencia por año) que devuelve el código
del año único o `"MIX"`. Se fija `COUNTIF` (no `SUMPRODUCT`) para que el texto de la fórmula sea
determinista y verificable en los tests.
El formato condicional de la celda visible se apoya en esa firma: una regla por año + una regla
`= "MIX"` → conflicto. Determinista y sin depender del orden de las reglas.

## 8. Interfaz de línea de comandos

```bash
python generar.py                                   # esqueleto vacío → salida por defecto
python generar.py --horarios config/horarios.yaml   # copia fiel
python generar.py --config config/facultad.yaml --salida propuesta.xlsx
```

**Salida por defecto:** `horarios.xlsx` en el directorio actual. `--config` por defecto es
`config/facultad.yaml`.

## 9. Estrategia de pruebas

- **Modelo/config:** tests unitarios de derivación de ids (`Casg`), `.año_codigo`, validación de
  config (casos válidos e inválidos con mensajes claros).
- **Layout:** tests de que las direcciones calculadas no se solapan y son estables.
- **Generación:** generar el workbook en memoria y verificar con openpyxl que existen las hojas,
  celdas clave, fórmulas esperadas (texto de la fórmula) y reglas de formato condicional.
- **Copia fiel:** cargar el `horarios.yaml` derivado de la demo del tutor y comprobar que las
  fórmulas de `Asignadas`/ocupación quedan escritas donde corresponde (verificación estructural;
  el recálculo real lo hace Excel/LibreOffice al abrir).

## 10. Limitaciones conocidas
- El recálculo de fórmulas ocurre al abrir el archivo en Excel/LibreOffice (openpyxl no evalúa
  fórmulas). Los tests verifican el **texto** de la fórmula, no su resultado numérico.
- v1 no resuelve el horario automáticamente; construye el esqueleto inteligente.
```
