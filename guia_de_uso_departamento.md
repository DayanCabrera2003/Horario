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
práctica (desplegable en la columna Profesor). Al lado de la tabla, un panel te
dice en todo momento **cuántas horas y cuántas asignaturas** lleva cada
profesor. Las hojas **Carga por profesor** y **Cobertura por asignatura** se
recalculan solas. Los colores avisan de lo que falta y de quién está
sobrecargado.

A partir de ahí no hace falta volver a Python: los profesores y las asignaturas
nuevas se añaden **dentro del propio Excel** (sección 5).

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
  # Opcionales: cuántas filas libres trae el libro para crecer sin regenerarlo.
  profesores_reserva: 5    # huecos libres en el claustro (5 por defecto)
  asignaturas_reserva: 10  # huecos libres en la hoja Asignaturas (10 por defecto)
  filas_carga_reserva: 20  # filas libres al final de Asignación (20 por defecto)

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

| Id | Asignatura | Carrera | Tipo | Grupo | Horas | Profesor | Nombre |
|---|---|---|---|---|---|---|---|
| `EST-CC` ▾ | Estadística (CC) | Ciencia de la Computación | `Conf` ▾ | - | 32 | `PIAD` ▾ | Pedro I. Alonso Diaz |
| `EST-CC` ▾ | Estadística (CC) | Ciencia de la Computación | `CP` ▾ | 1 | 32 | `MARA` ▾ | Maria Ramirez |
| `EST-CC` ▾ | Estadística (CC) | Ciencia de la Computación | `CP` ▾ | 2 | 32 | | |

De las ocho columnas **solo escribes cuatro**: `Id`, `Tipo`, `Grupo` y
`Profesor`. El nombre de la asignatura, la carrera, las horas y el nombre del
profesor se calculan solos a partir de ellas. Por eso, si corriges una
asignatura en la hoja `Asignaturas`, la corrección llega aquí sola.

En la columna **Profesor** eliges el id en el desplegable. También puedes
**escribir un id que no está en la lista** (por ejemplo, un profesor invitado):
aparece un aviso no bloqueante, el valor se conserva y la fila se pinta de
ámbar para que no pase inadvertido. La columna **Nombre**, que normalmente
resuelve el id a su nombre completo, muestra en ese caso `(desconocido)`. Lo
mismo vale para la columna `Id`: un id de asignatura que no existe pinta la fila
de ámbar.

### El panel de profesores

A la derecha de la tabla, separado por una columna en blanco, hay una fila por
profesor con:

| Id | Nombre | Horas | Asignaturas | Tope |
|---|---|---|---|---|
| PIAD | Pedro I. Alonso Diaz | 128 | 2 | 160 |

- **Horas** — la suma de las horas de todas las filas que le has asignado.
- **Asignaturas** — cuántas asignaturas **distintas** imparte. La conferencia y
  los dos grupos de CP de la misma asignatura son tres filas de carga, pero
  **una sola asignatura**.
- La fila se pinta de **rojo** en cuanto las horas pasan del tope.

Se actualiza solo, según eliges profesores en la columna de al lado.

### Añadir un profesor

1. Ve a la hoja **`Profesores`** y escribe en la primera fila libre su `Id`,
   `Nombre`, `Grado` y `Tope horas`.
2. Ya está. Aparece en el desplegable de `Asignación`, tiene su fila en el panel
   y tiene su bloque en `Carga por profesor`.

### Añadir una asignatura

1. Ve a la hoja **`Asignaturas`** y escribe en la primera fila libre su `Id`,
   `Nombre`, `Carrera`, `Horas Conf`, `Horas CP por grupo` y `Grupos CP`. El
   `Total` se calcula solo.
2. Mira la hoja **`Cobertura por asignatura`**: la asignatura ya está ahí, en
   naranja, diciendo `Sin filas de carga`.
3. Vuelve a **`Asignación`** y crea sus filas de carga en las **filas libres del
   final**: una para la conferencia y **una por cada grupo de CP**. En cada una
   escribes solo el `Id` (desplegable), el `Tipo` (`Conf` o `CP`) y el `Grupo`.
   El nombre, la carrera y las horas salen solos.
4. Elige el profesor de cada fila.
5. La fila de `Cobertura` se pone **verde** y dice `Completa`.

Si te olvidas de crear alguna fila de carga, `Cobertura` no dice `Completa`:
dice **`Faltan N horas de carga`**, comparando las horas que has creado con las
que la asignatura declara. Es el aviso de que falta un grupo por crear.

## 6. Cómo leer cada hoja

- **Portada** — la hoja por la que abre el libro. Dice de qué YAML salió, cuándo
  se generó y qué hay en cada hoja, con un enlace a cada una y la marca de si en
  ella *se escribe* o *se calcula*.
- **Profesores** — el claustro: `Id | Nombre | Grado | Tope horas | Origen del
  tope`. La última columna responde la pregunta que se hace quien mira un tope:
  ese 160, ¿lo declaró el profesor o le viene del departamento? **Aquí se
  añaden y se corrigen los profesores.**
- **Asignaturas** — el plan del semestre: `Id | Nombre | Carrera | Horas Conf |
  Horas CP por grupo | Grupos CP | Total`. El total se calcula solo
  (`Conf + CP × grupos`). **Aquí se añaden y se corrigen las asignaturas.**
- **Asignación** — donde se reparte la carga, con el panel de profesores al
  lado. Todo lo demás se deriva de aquí.
- **Carga por profesor** — un bloque por profesor: id, nombre, grado y tope, el
  detalle de lo que imparte (asignatura, tipo, grupo, horas) y su **TOTAL** de
  horas. Se rellena solo. Aquí no se escribe nada.
- **Cobertura por asignatura** — una fila por asignatura del plan:

  | Columna | Qué dice |
  |---|---|
  | Horas planificadas | Las que la asignatura declara en la hoja `Asignaturas` |
  | Filas de carga | Cuántas filas suyas existen en `Asignación` |
  | Horas en filas | Las horas que suman esas filas |
  | Horas asignadas | De esas, las que ya tienen profesor |
  | Filas sin profesor | Cuántas están todavía en amarillo |
  | Estado | Qué falta, en texto |

  La columna **Estado** dice una de cuatro cosas: `Completa`, `Sin filas de
  carga` (la asignatura existe pero nadie ha empezado), `Faltan N horas de
  carga` (falta crear alguna fila) o `Faltan N profesores`.

  Para ver **quién** imparte cada grupo de una asignatura, filtra por su id en
  la hoja `Asignación`.
- **Auxiliar** — oculta; contiene las tablas auxiliares de las fórmulas.
  No hay que tocarla.


### Añadir datos sin regenerar el libro

Las tres hojas donde se escribe (`Profesores`, `Asignaturas` y `Asignación`)
traen debajo de sus datos **filas libres ya preparadas**, con sus fórmulas
puestas. Escribes en la primera libre y el dato entra en cuanto Calc o Excel
recalculan. No hace falta Python ni regenerar nada.

Cuántas filas libres trae cada una lo decide el YAML (sección 4); de fábrica son
**5 profesores, 10 asignaturas y 20 filas de carga**.

Tres límites que conviene tener claros:

- **No dejes filas en blanco en medio de una lista.** La lista se corta ahí y
  todo lo que quede debajo desaparece del desplegable, sin ningún aviso. Si
  borras una fila del medio, sube las de abajo.
- **Cuando se acaben las filas libres hay que regenerar** el libro desde el
  YAML, subiendo la reserva que se haya agotado. Eso sí necesita Python.
- **Crear las filas de carga de una asignatura nueva es manual.** Excel no puede
  insertar filas él solo, así que hay que escribir una por la conferencia y una
  por cada grupo de CP. La hoja `Cobertura` vigila que no se te olvide ninguna.

### Qué se puede editar y qué está bloqueado

Las hojas van **protegidas**, sin contraseña. No es seguridad: es para que no se
borre una fórmula sin querer.

| Hoja | Celdas editables |
|---|---|
| `Profesores` | `Id`, `Nombre`, `Grado`, `Tope horas` (el **origen del tope** se calcula) |
| `Asignaturas` | `Id`, `Nombre`, `Carrera`, `Horas Conf`, `Horas CP por grupo`, `Grupos CP` (el **Total** se calcula) |
| `Asignación` | `Id`, `Tipo`, `Grupo`, `Profesor` (las otras cuatro columnas y el panel se calculan) |
| `Carga por profesor`, `Cobertura por asignatura`, `Portada`, `Auxiliar` | Ninguna; se calculan solas |

El color de la pestaña lo resume: **morado** = los datos del problema,
**azul** = aquí se reparte la carga, **gris azulado** = esto se calcula solo.

`Asignación` lleva **autofiltro** en los encabezados, útil para aislar una
asignatura, una carrera o las filas que aún no tienen profesor. Deja filtrar
pero **no ordenar**, y es a propósito: cada fila tiene una gemela, por posición,
en la hoja auxiliar de la que salen el detalle de `Carga por profesor` y la
cuenta de asignaturas del panel. Filtrar solo esconde filas; ordenar las movería
de sitio y esas cuentas pasarían a leer la fila equivocada sin avisar.
`Cobertura por asignatura` sí se puede ordenar: allí cada fila se resuelve por
su id.

Las hojas llevan los **encabezados fijos**: al bajar por la lista siguen a la
vista el título y la fila de encabezados. En `Asignación`, además, una **línea
gruesa** separa las filas de carga de una asignatura de las de la siguiente,
para que la conferencia y sus grupos de CP se lean como un bloque. Esa línea se
traza al generar el libro: si cambias a mano el `Id` de una fila, la línea se
queda donde estaba. Es solo estética; el agrupamiento real se ve filtrando.

Si necesitas tocar una celda calculada, quita la protección: en Excel, pestaña
*Revisar* → *Desproteger hoja*; en LibreOffice Calc, *Herramientas* → *Proteger
hoja* (se desmarca). No pide contraseña. Ojo: si sobrescribes la fórmula, la
pierdes, y la única forma de recuperarla es volver a generar el libro.

## 7. Los colores

Cada hoja lleva su leyenda. En resumen:

| Color | Dónde | Significado |
|---|---|---|
| Amarillo | Asignación | Fila de carga sin profesor todavía |
| Ámbar | Asignación | El id escrito no está en la lista (profesor o asignatura) |
| Rojo | Asignación (panel) y Carga por profesor (fila TOTAL) | El profesor supera su tope de horas |
| Verde | Cobertura por asignatura | Asignatura completa: todo creado y asignado |
| Naranja | Cobertura por asignatura | Asignatura incompleta: ver la columna Estado |

---

## 8. Errores comunes y qué significan

Todos se informan al generar, con `Error de configuración: ...`:

- `id duplicado 'X'` — dos profesores (o dos asignaturas) con el mismo id.
- `asignatura X: hay grupos de CP pero 'horas_cp' es 0` — declara las horas por
  grupo o quita los grupos.
- `asignatura X: sin carga (ni Conf ni grupos de CP)` — la asignatura no genera
  ninguna fila; sobra o le faltan horas.
- `'tope_horas' debe ser un entero positivo` — el tope no puede ser 0 ni
  negativo (si no quieres tope, omítelo).
- `asignatura X: 'horas_cp' debe ser un entero no negativo` — el valor no es un
  entero, o es negativo. Vale igual para `horas_conf` y `grupos_cp`. Ojo con el
  YAML: `no` se lee como el booleano `false`, así que `horas_cp: no` cae aquí.
- `departamento: 'filas_por_profesor' debe ser un entero positivo` — cada bloque
  de la hoja Carga por profesor necesita al menos una línea de detalle.
- `profesor: falta 'nombre'` — a una entrada del YAML le falta un campo
  obligatorio o lo tiene vacío. En las asignaturas el mensaje lleva el id:
  `asignatura X: falta 'carrera'`.
- `'profesores' no puede estar vacío` — la lista no existe o quedó vacía; lo
  mismo para `'asignaturas'`.

---

## 9. Límites conocidos

- Cada fila de carga la imparte **un solo profesor** (no hay co-impartición de
  una misma conferencia o grupo).
- En la hoja Carga por profesor cada bloque reserva `filas_por_profesor` líneas de
  detalle. Si un profesor imparte más cosas de las que caben, la última línea
  muestra `(+N más)`: súbele el valor en el YAML y regenera.
- Las **filas libres son finitas** (sección 4). Cuando se acaban, hay que
  regenerar el libro con la reserva más alta.
- **Crear las filas de carga de una asignatura nueva es manual:** una por la
  conferencia y una por cada grupo de CP. Excel no puede insertarlas solo.
- El libro cubre **un semestre**. Para el otro semestre, otro YAML y otro
  libro.
- El `.xlsx` es el lugar de trabajo y, a diferencia de los otros generadores,
  aguanta el curso entero sin volver al YAML: los profesores y las asignaturas
  se añaden dentro del libro. El YAML sigue siendo el punto de partida y el
  sitio al que volver cuando se agoten las filas libres.
