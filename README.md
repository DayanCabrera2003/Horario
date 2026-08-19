# Generadores de Excel

Este repositorio contiene **tres** generadores de libros de Excel (`.xlsx`) que
comparten la misma arquitectura (paquete `comun/` con formato, leyenda y estilos
base) y el mismo enfoque: a partir de archivos YAML producen una hoja de cálculo
lista para llenar o revisar, con validaciones, desplegables y colores que ayudan
a detectar problemas a simple vista.

1. **Generador de horarios de clases** (`generar.py`, paquete `horarios/`).
2. **Generador de tribunales de tesis** (`generar_tribunales.py`, paquete
   `tribunales/`).
3. **Generador de gestión del departamento** (`generar_departamento.py`,
   paquete `departamento/`).

Los tres son independientes: cada uno tiene su propia configuración, su propia
CLI y sus propias hojas.

## Requisitos

- Python 3.11 o superior.

## Instalación

```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Para desarrollo y tests:

```bash
pip install -r requirements-dev.txt
```

---

## Generador de horarios de clases

Planifica los horarios de una facultad. El `.xlsx` generado contiene:

- Una **hoja por grupo** con la rejilla de horario (días x turnos), una tabla
  de asignaturas con fórmulas de control (frecuencia, asignadas, faltan) y
  desplegables de aula y asignatura.
- Una hoja **Aulas** que muestra, por día y turno, qué grupos ocupan cada aula,
  coloreada por año y con marca de conflicto cuando dos años distintos coinciden
  en la misma aula.
- Una hoja **Datos** (oculta) con la lista maestra de aulas y las fórmulas
  auxiliares.

### Configuración

El generador lee dos YAML (ejemplos en la carpeta `config/`):

- **`facultad.yaml`** — la estructura: lista de aulas, días, número de turnos y,
  por carrera/año, las sesiones (grupos) y las asignaturas con su frecuencia.
- **`horarios.yaml`** — las asignaciones concretas (qué asignatura y aula van en
  cada día y turno de cada grupo). Es opcional: sin él se genera un esqueleto
  vacío para llenar a mano.

Hay configuraciones más completas en `config/facultad-completa.yaml` y
`config/horarios-completo.yaml`.

### Uso

Generar una plantilla vacía (solo la estructura, para llenar en Excel):

```bash
python generar.py --config config/facultad.yaml --salida esqueleto.xlsx
```

Generar un horario ya lleno desde un YAML de asignaciones:

```bash
python generar.py --config config/facultad.yaml --horarios config/horarios.yaml --salida propuesta.xlsx
```

Opciones de `generar.py`:

- `--config` — ruta del YAML de facultad (por defecto `config/facultad.yaml`).
- `--horarios` — ruta del YAML de asignaciones (opcional; sin él, esqueleto vacío).
- `--salida` — ruta del `.xlsx` a generar (por defecto `horarios.xlsx`).

### Cómo editar el Excel generado

- Las celdas de **aula** y **asignatura** tienen un desplegable de ayuda. Puedes
  escribir valores fuera de la lista (por ejemplo, un aula nueva que no está en
  la facultad): aparece un aviso no bloqueante y el valor se conserva al aceptar.
- Los colores se explican en la **leyenda** incluida en cada hoja:
  - Hoja de grupo: amarillo = aula fuera del listado, naranja = asignatura fuera
    de la tabla del grupo, rojo = sobre-planificada (asignadas > frecuencia),
    verde = frecuencia exacta cumplida. El rojo y el verde colorean la **fila
    completa** de la asignatura, no solo la casilla "Asignadas".
  - Hoja Aulas: un color por año y rojo intenso para conflicto (dos años
    distintos en la misma aula y turno).
- En la rejilla del horario:
  - La columna de **turnos** va pegada a la de los días (sin hueco).
  - Una **línea gruesa** separa cada turno del siguiente (cada turno son dos
    filas: asignatura arriba, aula debajo).
  - Las filas de **aula** llevan un fondo neutro que marca dónde va cada aula,
    útil al arrastrar y soltar.
  - Las celdas llevan algo de **padding** (sangría, centrado vertical y mayor
    alto de fila) para que en Calc no queden apretadas.
- Los encabezados (días, turnos y cabeceras de tabla) quedan fijos al hacer
  scroll y las tablas llevan un borde exterior más marcado.

Detalle paso a paso en [`guia_de_uso.md`](guia_de_uso.md).

---

## Generador de tribunales de tesis

Planifica las defensas de tesis: qué tribunal (estudiante, tutor, oponente,
presidente, secretario) va en cada local, día y momento. El `.xlsx` generado
contiene:

- Una hoja **Tribunales** (la primera visible) con la información completa de
  cada tesis en **nombres**, no en ids: estudiante y los cuatro roles del
  tribunal (tutor, oponente, presidente, secretario). Sirve para leer el
  tribunal de un vistazo sin descifrar los identificadores.
- Una **hoja por día** con una tabla por local. Eliges el estudiante en un
  desplegable (por id) y el tribunal se autocompleta con fórmulas. Se **resalta
  la colisión** cuando un profesor cae en dos locales distintos en el mismo
  momento.
- Una hoja **Localizar**: escribes el id de un profesor o estudiante en una
  celda de entrada global y se resaltan todos los momentos en los que participa,
  por día y local. Junto a cada momento, una columna **Rol** indica en calidad
  de qué participa (tutor, oponente, presidente, secretario o estudiante).
- Una hoja **Datos** (oculta) con la tabla tesis-tribunal y la lista de
  estudiantes que alimentan los desplegables y las fórmulas.

### Configuración

El generador lee dos YAML (ejemplos en la carpeta `config/`):

- **`tribunal.yaml`** — la estructura: profesores, estudiantes, locales, días con
  sus momentos, y las tesis con su tribunal. Todo se referencia por id.
- **`asignaciones.yaml`** — qué tesis va en cada local, día y momento (la tesis se
  identifica por su estudiante). Es opcional: sin él se genera un esqueleto vacío
  para llenar a mano.

### Uso

Generar una plantilla vacía (solo la estructura, para llenar en Excel):

```bash
python generar_tribunales.py --config config/tribunal.yaml --salida tesis.xlsx
```

Generar un libro ya lleno desde un YAML de asignaciones:

```bash
python generar_tribunales.py --config config/tribunal.yaml --asignaciones config/asignaciones.yaml --salida tesis.xlsx
```

Opciones de `generar_tribunales.py`:

- `--config` — ruta del YAML de tribunal (por defecto `config/tribunal.yaml`).
- `--asignaciones` — ruta del YAML de asignaciones (opcional; sin él, esqueleto vacío).
- `--salida` — ruta del `.xlsx` a generar (por defecto `tesis.xlsx`).

Detalle paso a paso en [`guia_de_uso_tribunales.md`](guia_de_uso_tribunales.md).

---

## Generador de gestión del departamento

Reparte la carga docente de un semestre: qué profesor imparte cada conferencia
y cada grupo de clase práctica. A diferencia de los otros dos generadores, aquí
la decisión se toma **dentro del Excel** y los reportes se recalculan solos.
El `.xlsx` generado contiene:

- Una hoja **Asignación** (la única editable): cada asignatura expandida a sus
  *filas de carga* (la conferencia + una fila por grupo de CP), con un
  desplegable de profesor por fila. Amarillo = fila sin profesor; ámbar = id
  fuera de la lista.
- Una hoja **Profesores**: por profesor, qué imparte (asignatura, tipo, grupo,
  horas) y su total de horas, todo por fórmulas. Rojo cuando supera su tope
  (global del departamento o propio del profesor).
- Una hoja **Asignaturas**: por asignatura, quién cubre cada fila de carga.
  Título verde si está completa, naranja si falta alguien.
- Una hoja **Datos** (oculta) con las listas y la tabla auxiliar de las
  fórmulas.

### Configuración

Un único YAML (ejemplo en `config/departamento.yaml`): el departamento (nombre,
semestre, tope de horas opcional), los profesores (id, nombre, grado, tope
propio opcional) y las asignaturas del semestre (nombre, carrera, horas de
conferencia, horas de CP **por grupo** y cantidad de grupos de CP).

### Uso

```bash
python generar_departamento.py --config config/departamento.yaml --salida gestion.xlsx
```

Opciones de `generar_departamento.py`:

- `--config` — ruta del YAML del departamento (por defecto `config/departamento.yaml`).
- `--salida` — ruta del `.xlsx` a generar (por defecto `departamento.xlsx`).

Detalle paso a paso en [`guia_de_uso_departamento.md`](guia_de_uso_departamento.md).

---

## Importar tribunales desde Excel

El paquete `extraccion/` convierte los Excel de tribunales (formato de Carmen:
`Día, Hora, Estudiante, Tutor, Presidente, Secretario, Vocal, Oponente, Local,
Observaciones`) al `tribunal.yaml` y `asignaciones.yaml` que consume el generador.

```bash
python importar_tribunales.py entrada1.xlsx entrada2.xlsx \
    --tribunal tribunal.yaml \
    --asignaciones asignaciones.yaml \
    --revision revision-tribunales.md
```

Qué hace la importación:

- **Normaliza nombres**: separa el grado (`MSc.`, `Dr.`…), quita anotaciones entre
  paréntesis y unifica variantes y erratas del mismo profesor en un único `id`.
- **Deduplica de forma conservadora** y deja el mapa `id → nombre` (con las
  variantes fusionadas) en el **informe de revisión** para verificarlo a mano.
- **Detecta co-tutorías** (varios tutores), **tesis conjuntas** (varios
  estudiantes) y el **vocal**.
- **Normaliza locales** (`Posgrado`/`Postgrado` → uno) y **horas** (las de la tarde
  escritas como `1:30` se interpretan como `13:30`).
- Registra en el informe las **incidencias** (filas sin fecha/estudiante, horas o
  locales no reconocibles) para revisarlas.

Conviene revisar el informe (sobre todo las fusiones de nombres) y corregir el
YAML antes de generar el libro definitivo.

---

## Importar el horario desde el PDF

La transcripción del horario del Primer Período 2024-2025 de MATCOM (PDF de
Gianni) vive en `extraccion/datos_horario_2024.py` (datos puros: por grupo,
turno → día → celda tal cual el PDF). El módulo `extraccion/horario_pdf.py` la
convierte al `facultad.yaml` y `horarios.yaml` del generador de horarios:

```bash
python importar_horario.py \
    --facultad facultad.yaml \
    --horarios horarios.yaml \
    --incidencias incidencias-horario.md
```

Reglas de conversión:

- **Turnos** tal cual el PDF (1-3 mañana, 4-6 tarde según cada año).
- **Tipo de clase** en el id de la asignatura: `ED c 2` → `ED-C` en `Aula 2`;
  `ED cp 2` → `ED-CP`. Sin marca de tipo, el id es la abreviatura sola.
- **Aula** normalizada: `Aula 4`/`4` → `Aula 4`; `Lab`, `Lab2`, `SEDER` tal cual.
- **Frecuencia** de cada asignatura = número de veces que aparece en el grid.
- **Anotaciones** entre paréntesis (`(con C211)`, `(s. 1-8)`) se ignoran.
- Las **celdas divididas por semanas** (`F ... / ICD ...`) toman la primera y
  registran la segunda como incidencia.
- Las celdas que no se reconocen (electivas sin aula, notación rara) quedan en el
  informe de **incidencias** para revisarlas y completarlas a mano.

---

## Tests

```bash
python -m pytest
```
