# Generador de horarios

Herramienta de línea de comandos que genera un libro de Excel (`.xlsx`) para
planificar los horarios de una facultad. A partir de dos archivos de
configuración en YAML produce una hoja de cálculo lista para llenar o revisar,
con validaciones y colores que ayudan a detectar errores a simple vista.

El `.xlsx` generado contiene:

- Una **hoja por grupo** con la rejilla de horario (días x turnos), una tabla
  de asignaturas con fórmulas de control (frecuencia, asignadas, faltan) y
  desplegables de aula y asignatura.
- Una hoja **Aulas** que muestra, por día y turno, qué grupos ocupan cada aula,
  coloreada por año y con marca de conflicto cuando dos años distintos coinciden
  en la misma aula.
- Una hoja **Datos** (oculta) con la lista maestra de aulas y las fórmulas
  auxiliares.

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

## Configuración

El generador lee dos YAML (ejemplos en la carpeta `config/`):

- **`facultad.yaml`** — la estructura: lista de aulas, días, número de turnos y,
  por carrera/año, las sesiones (grupos) y las asignaturas con su frecuencia.
- **`horarios.yaml`** — las asignaciones concretas (qué asignatura y aula van en
  cada día y turno de cada grupo). Es opcional: sin él se genera un esqueleto
  vacío para llenar a mano.

Hay configuraciones más completas en `config/facultad-completa.yaml` y
`config/horarios-completo.yaml`.

## Uso

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

## Cómo editar el Excel generado

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

## Tests

```bash
python -m pytest
```

## Más documentación

Para el detalle paso a paso (recetario de casos, estructura completa de los
YAML, errores comunes y flujo de trabajo recomendado), ver
[`guia_de_uso.md`](guia_de_uso.md).
