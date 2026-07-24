# Generadores de Excel

Este repositorio contiene **dos** generadores de libros de Excel (`.xlsx`) que
comparten la misma arquitectura (paquete `comun/` con formato, leyenda y estilos
base) y el mismo enfoque: a partir de archivos YAML producen una hoja de cálculo
lista para llenar o revisar, con validaciones, desplegables y colores que ayudan
a detectar problemas a simple vista.

1. **Generador de horarios de clases** (`generar.py`, paquete `horarios/`).
2. **Generador de tribunales de tesis** (`generar_tribunales.py`, paquete
   `tribunales/`).

Ambos son independientes: cada uno tiene su propia configuración, su propia CLI
y sus propias hojas.

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
    verde = frecuencia exacta cumplida.
  - Hoja Aulas: un color por año y rojo intenso para conflicto (dos años
    distintos en la misma aula y turno).
- Los encabezados (días, turnos y cabeceras de tabla) quedan fijos al hacer
  scroll y las tablas llevan un borde exterior más marcado.

Detalle paso a paso en [`guia_de_uso.md`](guia_de_uso.md).

---

## Generador de tribunales de tesis

Planifica las defensas de tesis: qué tribunal (estudiante, tutor, oponente,
presidente, secretario) va en cada local, día y momento. El `.xlsx` generado
contiene:

- Una **hoja por día** con una tabla por local. Eliges el estudiante en un
  desplegable (por id) y el tribunal se autocompleta con fórmulas. Se **resalta
  la colisión** cuando un profesor cae en dos locales distintos en el mismo
  momento.
- Una hoja **Localizar**: escribes el id de un profesor o estudiante en una
  celda de entrada global y se resaltan todos los momentos en los que participa,
  por día y local.
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

## Tests

```bash
python -m pytest
```
