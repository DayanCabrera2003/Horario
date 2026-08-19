# Guía de uso — Generador de gestión del departamento

Guía práctica para **usar** la herramienta que arma el Excel de gestión del
departamento: decidir qué profesor imparte cada asignatura del semestre y leer,
de esa decisión, la carga de cada profesor y el reparto de cada asignatura.

> Esta guía es para quien reparte la carga docente del departamento. Para el
> generador de horarios de clases, ver [`guia_de_uso.md`](guia_de_uso.md); para
> el de tribunales de tesis, [`guia_de_uso_tribunales.md`](guia_de_uso_tribunales.md).

---

## Contenido

1. [En 30 segundos](#1-en-30-segundos)
2. [Instalar (una sola vez)](#2-instalar-una-sola-vez)
3. [El comando](#3-el-comando)
4. [El archivo `departamento.yaml`](#4-el-archivo-departamentoyaml)
5. [Cómo se trabaja en el Excel](#5-cómo-se-trabaja-en-el-excel)
6. [Cómo leer cada hoja](#6-cómo-leer-cada-hoja)
7. [Los colores](#7-los-colores)
8. [Errores comunes y qué significan](#8-errores-comunes-y-qué-significan)
9. [Límites conocidos](#9-límites-conocidos)

---

## 1. En 30 segundos

```bash
python generar_departamento.py --config config/departamento.yaml --salida gestion.xlsx
```

Abres `gestion.xlsx` en Excel o LibreOffice. En la hoja **Asignación** eliges,
fila por fila, qué profesor imparte cada conferencia y cada grupo de clase
práctica (desplegable en la columna Profesor). Las hojas **Profesores** y
**Asignaturas** se recalculan solas: cuántas horas acumula cada profesor, qué
imparte, y quién cubre cada asignatura. Los colores avisan de lo que falta y de
quién está sobrecargado.

---

## 2. Instalar (una sola vez)

Necesitas **Python ≥ 3.11**.

```bash
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

---

## 3. El comando

```bash
python generar_departamento.py --config config/departamento.yaml --salida gestion.xlsx
```

- `--config` — ruta del YAML del departamento (por defecto
  `config/departamento.yaml`).
- `--salida` — ruta del `.xlsx` a generar (por defecto `departamento.xlsx`).

El Excel se genera siempre "vacío de decisiones": las decisiones se toman
dentro del propio archivo y viven allí.

---

## 4. El archivo `departamento.yaml`

```yaml
departamento:
  nombre: Matemática Aplicada
  semestre: "2026-2027 / 1"
  tope_horas: 160          # opcional: tope global de horas por profesor
  filas_por_profesor: 8    # opcional: filas reservadas por bloque (10 por defecto)

profesores:
  - {id: PIAD, nombre: "Pedro I. Alonso Diaz", grado: "Dr."}
  - {id: ANSU, nombre: "Ana Suarez", grado: "MSc.", tope_horas: 80}  # tope propio

asignaturas:
  - id: EST-CC
    nombre: "Estadística (CC)"
    carrera: "Ciencia de la Computación"
    horas_conf: 32     # horas de conferencia del semestre
    horas_cp: 32       # horas de clase práctica POR GRUPO
    grupos_cp: 2       # cuántos grupos de CP existen
```

Puntos importantes:

- **La misma asignatura para dos carreras son dos entradas** (`EST-CC` y
  `EST-MAT`), como en el ejemplo de `config/departamento.yaml`.
- **Las horas de CP son por grupo:** cada grupo recibe el programa completo.
  Con `horas_cp: 32` y `grupos_cp: 2` hay 64 horas de CP que repartir.
- El **tope de horas** es opcional. Si un profesor declara `tope_horas`, el
  suyo manda sobre el global. Sin ningún tope, no hay alerta de sobrecarga.
- Una asignatura puede ser **solo de conferencias** (`horas_cp: 0` y
  `grupos_cp: 0`) o **solo de CP** (`horas_conf: 0`).

---

## 5. Cómo se trabaja en el Excel

Cada asignatura se expande a sus **filas de carga**: una para la conferencia y
una por cada grupo de CP. Ese es el "átomo" que se asigna: una fila, un
profesor.

| Asignatura | Tipo | Grupo | Horas | Profesor | Nombre |
|---|---|---|---|---|---|
| Estadística (CC) | Conf | - | 32 | `PIAD` ▾ | Pedro I. Alonso Diaz |
| Estadística (CC) | CP | 1 | 32 | `MARA` ▾ | Maria Ramirez |
| Estadística (CC) | CP | 2 | 32 | | |

En la columna **Profesor** eliges el id en el desplegable. También puedes
**escribir un id que no está en la lista** (por ejemplo, un profesor invitado):
aparece un aviso no bloqueante, el valor se conserva y la fila se pinta de
ámbar para que no pase inadvertido.

---

## 6. Cómo leer cada hoja

- **Asignación** — la única que se edita. Todo lo demás se deriva de aquí.
- **Profesores** — un bloque por profesor: id, nombre, grado y tope, el detalle
  de lo que imparte (asignatura, tipo, grupo, horas) y su **TOTAL** de horas.
  Se rellena solo al elegir profesores en Asignación.
- **Asignaturas** — un bloque por asignatura con sus filas de carga y quién
  cubre cada una. El título del bloque cambia de color según esté completa.
- **Datos** — oculta; contiene las listas y tablas auxiliares de las fórmulas.
  No hay que tocarla.

---

## 7. Los colores

Cada hoja lleva su leyenda. En resumen:

| Color | Dónde | Significado |
|---|---|---|
| Amarillo | Asignación | Fila de carga sin profesor todavía |
| Ámbar | Asignación | El id escrito no está en la lista de profesores |
| Rojo | Profesores (fila TOTAL) | El profesor supera su tope de horas |
| Verde | Asignaturas (título) | Asignatura completa: todas sus filas asignadas |
| Naranja | Asignaturas (título) | Asignatura incompleta: falta alguna fila |

---

## 8. Errores comunes y qué significan

Todos se informan al generar, con `Error de configuracion: ...`:

- `id duplicado 'X'` — dos profesores (o dos asignaturas) con el mismo id.
- `asignatura X: hay grupos de CP pero 'horas_cp' es 0` — declara las horas por
  grupo o quita los grupos.
- `asignatura X: sin carga (ni Conf ni grupos de CP)` — la asignatura no genera
  ninguna fila; sobra o le faltan horas.
- `'tope_horas' debe ser un entero positivo` — el tope no puede ser 0 ni
  negativo (si no quieres tope, omítelo).

---

## 9. Límites conocidos

- Cada fila de carga la imparte **un solo profesor** (no hay co-impartición de
  una misma conferencia o grupo).
- En la hoja Profesores cada bloque reserva `filas_por_profesor` líneas de
  detalle. Si un profesor imparte más cosas de las que caben, la última línea
  muestra `(+N más)`: súbele el valor en el YAML y regenera.
- El libro cubre **un semestre**. Para el otro semestre, otro YAML y otro
  libro.
- Como en los otros generadores, el `.xlsx` es el lugar de trabajo, pero la
  configuración (profesores, asignaturas) vive en el YAML: si cambia, se
  regenera el Excel y se vuelven a elegir los profesores.
