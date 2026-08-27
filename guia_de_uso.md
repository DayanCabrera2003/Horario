# Guía de uso — Generador de horarios

Guía práctica y paso a paso para **usar** la herramienta: cómo generar el Excel, cómo llenar los
dos archivos YAML, qué escribir para ver funcionar cada cosa, y qué se puede y qué no se puede hacer.

> Esta guía es para la persona que arma los horarios: cómo generar el Excel y cómo llenar los YAML.
> Para el generador de tribunales de tesis, ver [`guia_de_uso_tribunales.md`](guia_de_uso_tribunales.md);
> para el de gestión del departamento, [`guia_de_uso_departamento.md`](guia_de_uso_departamento.md).

---

## Contenido

1. [En 30 segundos](#1-en-30-segundos)
2. [Instalar (una sola vez)](#2-instalar-una-sola-vez)
3. [Los dos comandos que usarás](#3-los-dos-comandos-que-usarás)
4. [Archivo 1 — `facultad.yaml` (la estructura)](#4-archivo-1--facultadyaml-la-estructura)
5. [Archivo 2 — `horarios.yaml` (las asignaciones)](#5-archivo-2--horariosyaml-las-asignaciones)
6. [Recetario: qué escribir para ver funcionar cada cosa](#6-recetario-qué-escribir-para-ver-funcionar-cada-cosa)
7. [Cómo leer el Excel generado](#7-cómo-leer-el-excel-generado)
8. [Errores comunes y qué significan](#8-errores-comunes-y-qué-significan)
9. [Qué se puede y qué no se puede hacer](#9-qué-se-puede-y-qué-no-se-puede-hacer)
10. [Flujo de trabajo recomendado](#10-flujo-de-trabajo-recomendado)

---

## 1. En 30 segundos

```bash
# 1) genera la plantilla vacía (para llenar a mano en Excel)
python generar.py --salida esqueleto.xlsx

# 2) o genera un horario ya lleno desde un YAML
python generar.py --horarios config/horarios.yaml --salida propuesta.xlsx
```

Abres el `.xlsx` en Excel o LibreOffice y **se colorea solo**: verde donde una asignatura ya cumple
su frecuencia, rojo donde te pasaste, naranja si escribiste una asignatura que no existe, amarillo si
pusiste un aula que no existe, y la hoja `Ocupación de aulas` te muestra qué grupos ocupan cada aula
a cada hora
(en rojo intenso si dos años distintos chocan en la misma aula).

---

## 2. Instalar (una sola vez)

Necesitas **Python ≥ 3.11**.

```bash
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate
pip install -e .
```

Comprueba que funciona:

```bash
python generar.py --salida prueba.xlsx
```

Si imprime `Generado: prueba.xlsx`, listo.

---

## 3. Los dos comandos que usarás

El programa tiene un solo punto de entrada, `generar.py`, con tres opciones:

| Opción | Qué es | Por defecto |
|--------|--------|-------------|
| `--config` | El YAML de **estructura** (aulas, días, turnos, carreras, grupos, asignaturas). | `config/facultad.yaml` |
| `--horarios` | El YAML de **asignaciones** (opcional). Si lo pones, el Excel sale lleno; si no, sale vacío. | *(ninguno)* |
| `--salida` | Nombre del archivo `.xlsx` a crear. | `horarios.xlsx` |

### Los dos modos

**Modo A — esqueleto vacío** (no pasas `--horarios`):

```bash
python generar.py --config config/facultad.yaml --salida esqueleto.xlsx
```

Genera toda la estructura (hojas, fórmulas, colores, menús desplegables) pero **sin horario**. Es la
plantilla para que llenes las celdas a mano en Excel; a medida que escribes, se colorea en vivo.

**Modo B — copia fiel** (pasas `--horarios`):

```bash
python generar.py --config config/facultad.yaml \
                  --horarios config/horarios.yaml \
                  --salida propuesta.xlsx
```

Genera lo mismo pero con el horario **ya escrito** desde el YAML. Útil para versionar el horario en
texto y regenerar el Excel cuando quieras.

> **Regla de oro:** puedes regenerar el `.xlsx` mil veces; la fuente de verdad son los YAML. No edites
> el `.xlsx` "a mano" si piensas regenerarlo, porque se sobrescribe.

---

## 4. Archivo 1 — `facultad.yaml` (la estructura)

Describe **cómo es tu facultad**: qué aulas hay, qué días y turnos, y qué carreras/años/grupos/
asignaturas existen. Es lo primero que debes tener bien.

### Esqueleto mínimo

```yaml
aulas: [Aula 1, Aula 2, Aula 3, Lab]     # lista de aulas que existen
dias:   [Lunes, Martes, Miércoles, Jueves, Viernes]
turnos: 6                                 # cuántos turnos por día

carreras:
  C:                                      # <- letra de la carrera
    nombre: Ciencias de la Computación
    años:
      1:                                  # <- número de año
        sesiones:
          1: { grupos: [1, 2, 3] }        # sesión 1 -> grupos C111, C112, C113
          2: { grupos: [1, 2] }           # sesión 2 -> grupos C121, C122
        asignaturas:
          - { id: AMI-C,  nombre: "Análisis Matemático I (Conf)", frecuencia: 1 }
          - { id: AMI-CP, nombre: "Análisis Matemático I (C.P.)", frecuencia: 2 }
          - { id: EF,     nombre: "Educación Física",             frecuencia: 1 }
```

### Campo por campo

- **`aulas`** — la lista completa de aulas válidas. Cualquier aula que uses en el horario tiene que
  estar aquí. Los nombres pueden ser lo que quieras (`Aula 1`, `Lab`, `Salón`, `A-204`…).
- **`dias`** — los días de la semana. El texto tiene que coincidir **exactamente** con lo que pongas
  luego en el horario (`Miércoles` con tilde, etc.).
- **`turnos`** — un número entero ≥ 1. Cuántas franjas horarias tiene cada día.
- **`carreras`** — un diccionario. La **clave** (`C`, `M`, `D`) es la letra de la carrera; se usa para
  formar el id de grupo. `nombre` es solo descriptivo.
- **`años`** — dentro de cada carrera, un diccionario por número de año.
  - **`sesiones`** — normalmente solo `1`. Si un año tiene grupos en dos sesiones (turno mañana/tarde),
    usas `1` y `2`. Cada sesión lista sus **`grupos`** (los números de grupo).
  - **`asignaturas`** — la lista de asignaturas de ese año. Cada una tiene:
    - **`id`** — código corto (lo que se escribe en las celdas del horario). Ej. `AMI-C`.
    - **`nombre`** — nombre largo (solo aparece en la tabla de asignaturas).
    - **`frecuencia`** — cuántas veces por semana debe darse.

### Cómo se forman los ids de grupo

El id `Casg` se arma automáticamente = **C**arrera + **a**ño + **s**esión + **g**rupo.

```
carrera C, año 1, sesión 1, grupo 2   ->   C112
carrera M, año 2, sesión 1, grupo 1   ->   M211
```

No los escribes tú: salen de combinar `carreras × años × sesiones × grupos`.

### Los profesores (opcional)

Dos secciones más, las dos opcionales. Sin ellas el libro sale como siempre; con ellas gana las hojas
`Profesores` y `Docencia`.

```yaml
profesores:
  - { id: PIAD, nombre: "Pedro I. Alonso Díaz", grado: "Dr.", tope_horas: 160 }
  - { id: MARA, nombre: "María Ramírez",        grado: "MSc." }   # sin tope

docencia:
  C111:                    # <- id de grupo
    AMI-C:  PIAD           # <- asignatura: profesor
    AMI-CP: MARA
  C112:
    AMI-CP: PIAD           # el mismo AMI-CP, otro grupo, otro profesor
```

- **`profesores`** — `id` y `nombre` obligatorios; `grado` y `tope_horas` opcionales. El id es lo que
  se escribe en `docencia`, igual que con las asignaturas.
- **`docencia`** — la jerarquía es **grupo → asignatura → profesor**. La clave es el par (grupo,
  asignatura) y no la asignatura sola porque en el YAML las asignaturas cuelgan del **año**: el mismo
  `AMI-CP` lo imparten profesores distintos en cada grupo del año.
- No hay que declararlo todo: los pares que falten quedan sin profesor.

El programa valida las tres referencias y **no genera** el Excel si alguna falla: un profesor que no
existe, un grupo que no existe, o una asignatura que no es del año de ese grupo.

### Convenio de asignaturas (recomendado, no obligatorio)

Por convención se distingue con sufijo:
- **`-C`** = conferencia (la comparten varios grupos del año en la misma aula).
- **`-CP`** = clase práctica (cada grupo en su aula).

No es una regla del programa, es una costumbre que hace más legibles los ids y los colores.

---

## 5. Archivo 2 — `horarios.yaml` (las asignaciones)

Solo lo necesitas en **modo copia fiel**. Dice, para cada grupo, qué asignatura y qué aula van en cada
día y turno.

### Estructura

```yaml
C111:                 # <- id de grupo (tiene que existir en facultad.yaml)
  Lunes:              # <- día (tiene que estar en 'dias')
    1: { asig: AMI-C,  aula: Aula 1 }   # turno 1: asignatura AMI-C en Aula 1
    2: { asig: AMI-CP, aula: Aula 2 }   # turno 2
    3: { asig: AMI-CP, aula: Aula 2 }   # turno 3
  Martes:
    1: { asig: Pro-C,  aula: Aula 1 }
```

La jerarquía es siempre: **grupo → día → turno → `{ asig, aula }`**.

- **`asig`** — el `id` de una asignatura. (Si escribes uno que no existe, no falla al generar, pero
  se pinta de naranja en el Excel — útil para detectar erratas.)
- **`aula`** — el nombre de un aula. **Tiene que existir** en `facultad.yaml`, o el programa da error.

No tienes que llenar todos los turnos ni todos los días: solo pon las celdas que quieras ocupar.

### Truco de sintaxis

Puedes escribir cada turno en una línea (`{ ... }` es YAML "flow", más compacto) o expandido:

```yaml
# Compacto (una línea por turno):
C111:
  Lunes: { 1: {asig: AMI-C, aula: Aula 1}, 2: {asig: AMI-CP, aula: Aula 2} }

# Expandido (más legible para horarios largos):
C111:
  Lunes:
    1:
      asig: AMI-C
      aula: Aula 1
    2:
      asig: AMI-CP
      aula: Aula 2
```

Ambos son equivalentes.

---

## 6. Recetario: qué escribir para ver funcionar cada cosa

Cada "efecto" del Excel se dispara con algo concreto en el YAML.

### Frecuencia exacta → **verde** (tabla de asignaturas)

Planifica una asignatura **exactamente** tantas veces como su `frecuencia`.

```yaml
# AMI-CP tiene frecuencia 2 -> ponla 2 veces:
C111:
  Lunes:  { 2: {asig: AMI-CP, aula: Aula 2}, 3: {asig: AMI-CP, aula: Aula 2} }
```

En la hoja `C111`, la fila `AMI-CP` queda verde (`Asignadas=2`, `Faltan=0`).

### Sobre-planificada → **rojo** (tabla de asignaturas)

Ponla **más veces** de las que dice su frecuencia.

```yaml
# AMI-CP frecuencia 2, pero la ponemos 3 veces:
C121:
  Lunes:  { 2: {asig: AMI-CP, aula: Aula 5}, 3: {asig: AMI-CP, aula: Aula 5} }
  Martes: { 1: {asig: AMI-CP, aula: Aula 5} }
```

La fila `AMI-CP` queda roja (`Asignadas=3 > Frec=2`, `Faltan=-1`).

### Asignatura desconocida → **naranja** (celda del horario)

Escribe un `asig` que **no exista** en las asignaturas del año.

```yaml
C121:
  Martes: { 2: {asig: XYZ-C, aula: Aula 5} }   # XYZ-C no existe -> celda naranja
```

Sirve para cazar erratas de tipeo. (Ojo: sí necesita un `aula` válida para que el generador acepte la
línea.)

### Aula inválida → **amarillo** (celda del horario)

**No se puede** disparar desde el YAML: el generador rechaza cualquier aula que no exista y da error.
Este resaltado solo aparece **editando a mano** una celda de aula en el Excel y escribiendo un aula
inexistente. Es una red de seguridad para la edición manual, no para el YAML.

### Aula puesta sin asignatura → **rojo** (celda del horario)

Tampoco se puede disparar desde el YAML: el generador exige `asig` **y** `aula` en cada celda, y sin
uno de los dos da error. Aparece al **editar a mano**: si escribes el aula de un turno y te dejas la
asignatura, la casilla de **asignatura** (la de arriba del par) se pinta de rojo.

Es el caso típico de un horario a medio llenar: ya sabes dónde va la clase pero aún no cuál es. El
resaltado está para que ese turno no se quede olvidado.

### Conferencia compartida → varios grupos concatenados (hoja `Ocupación de aulas`)

Pon **la misma aula, día y turno** a varios grupos del **mismo año**.

```yaml
C111: { Lunes: { 1: {asig: AMI-C, aula: Aula 1} } }
C112: { Lunes: { 1: {asig: AMI-C, aula: Aula 1} } }
C113: { Lunes: { 1: {asig: AMI-C, aula: Aula 1} } }
```

En `Ocupación de aulas`, la celda `Aula 1 / Lunes T1` mostrará `C111,C112,C113`, pintada con el color del año C1
(no es conflicto: es el mismo año compartiendo conferencia).

### Conflicto entre años (MIX) → **rojo intenso** (hoja `Ocupación de aulas`)

Pon **la misma aula/día/turno** a grupos de **años distintos** (distinta carrera o distinto año).

```yaml
C111: { Lunes: { 2: {asig: AMI-CP, aula: Aula 2} } }   # año C1
M111: { Lunes: { 2: {asig: AM1-CP, aula: Aula 2} } }   # año M1  -> ¡chocan!
```

En `Ocupación de aulas`, `Aula 2 / Lunes T2` mostrará `C111,M111` en **rojo intenso**: dos años distintos no pueden
ocupar la misma aula a la misma hora. Este es el detector de choques estrella de la herramienta.

### Color por año → hoja `Ocupación de aulas`

No hay que hacer nada especial: cada año (C1, C2, …, M1…, D1…) tiene un color fijo. Al llenar aulas de
distintos años, la hoja `Ocupación de aulas` se pinta como un mapa de calor por año
automáticamente.

> **Ejemplo completo ya hecho:** en el repo están `config/facultad-completa.yaml` +
> `config/horarios-completo.yaml`, que incluyen a propósito **todos** estos casos (verde, rojo,
> naranja, conferencia compartida y conflicto MIX). Genera y ábrelos para verlos todos juntos:
> ```bash
> python generar.py --config config/facultad-completa.yaml \
>                   --horarios config/horarios-completo.yaml \
>                   --salida propuesta-completa.xlsx
> ```

---

## 7. Cómo leer el Excel generado

El archivo tiene tres clases de hoja: la **portada**, las de **datos del problema** (de dónde sale
todo) y las de **trabajo** (donde se planifica y se consulta).

### Hoja `Portada`

La hoja por la que abre el libro. Dice de qué YAML salió, cuándo se generó y cuántos grupos y aulas abarca, y
lista las demás hojas con un enlace a cada una y la marca de qué es cada una: *datos del problema*,
*se escribe* o *se calcula*.

### Las hojas de datos: `Aulas`, `Asignaturas`, `Grupos` y `Estructura`

Son la estructura de la facultad, tal como la declara `facultad.yaml`, escrita en el propio libro.
Hasta ahora había que abrir el YAML para verla.

- **`Aulas`** — la lista de aulas válidas. Es la misma que alimenta los desplegables.
- **`Asignaturas`** — una fila por asignatura de cada año (`Carrera | Año | Id | Nombre |
  Frecuencia`). En el YAML las asignaturas cuelgan del año, así que aquí se ven aplanadas.
- **`Grupos`** — los ids de grupo con sus piezas (`Grupo | Carrera | Año | Sesión | Número`). El id
  `C112` no se declara en ninguna parte: sale de combinar carreras × años × sesiones × grupos, y esta
  hoja lo escribe.
- **`Estructura`** — los días, cuántos turnos tiene cada uno y el tamaño del libro. Los días importan
  más de lo que parece: el texto tiene que coincidir **exactamente** con el del `horarios.yaml`,
  tildes incluidas.

Se pueden ordenar y filtrar, pero **no se editan**: por ahora la fuente sigue siendo el YAML.

### Hojas `Profesores` y `Docencia` (solo si el YAML declara profesores)

- **`Profesores`** — el claustro: `Id | Nombre | Grado | Tope horas`.
- **`Docencia`** — quién imparte qué: `Grupo | Asignatura | Profesor | Nombre`. Una fila por par
  (grupo, asignatura), porque el mismo `AMI-CP` lo puede dar un profesor distinto en cada grupo.

Si `facultad.yaml` no trae la sección `profesores`, estas dos hojas no se crean y el libro sale como
antes.

### Hoja `Ocupación de aulas`

Un bloque por día. Filas = turnos, columnas = aulas. Cada celda dice **qué grupos** ocupan esa aula a
esa hora. Colores:
- **Color del año** (azules = carrera C, verdes = M, naranjas = D; más oscuro a mayor año): esa
  aula/turno la ocupa un único año.
- **Rojo intenso:** conflicto — dos años distintos en la misma aula/turno.
- **Vacía:** aula libre a esa hora.

Debajo del último bloque hay una **leyenda** con el color de cada año presente y el del conflicto. La
columna de turnos queda **fija** al desplazarte a la derecha.

Es tu vista de "ocupación del edificio".

### Una hoja por grupo (`C111`, `C112`, …)

- **Izquierda:** la rejilla del horario. Columnas = días, filas = turnos. Cada turno usa **dos filas**:
  arriba la asignatura, abajo el aula.
- **Derecha:** la tabla de asignaturas (`id | Nombre | Frec | Asignadas | Faltan`). `Asignadas` cuenta
  sola cuántas veces pusiste esa asignatura; `Faltan` = lo que te falta (0 = completo, negativo = te
  pasaste). Verde = exacto, rojo = pasado.
- **Menús desplegables:** al hacer clic en una celda de asignatura sale la lista de asignaturas del
  grupo; en una celda de aula, la lista de aulas válidas. (Sirven al editar a mano.)
- **Leyenda:** debajo de la tabla de asignaturas, con el significado de cada color. Incluye el rojo de
  **aula puesta sin asignatura**, que marca los turnos a medio llenar.
- **Encabezados fijos:** los días y los turnos no se van al hacer scroll.
- **Lista para imprimir:** la hoja sale **apaisada** y ajustada a **una página de ancho**, con los
  encabezados repetidos arriba de cada página. No hay que tocar la configuración de impresión.

### Hoja `Auxiliar` (oculta)

Es interna (aulas válidas + cálculos de apoyo para los colores). Normalmente no la tocas. Si quieres
verla: clic derecho en una pestaña → *Mostrar hoja oculta*.

> **Importante:** para ver los valores y colores hay que abrir el archivo en Excel o LibreOffice, que
> es quien **recalcula las fórmulas**. Recién generado, algunas celdas pueden verse vacías hasta que el
> programa recalcula al abrir (normalmente automático).

### Qué se puede editar y qué está bloqueado

Las hojas van **protegidas**, sin contraseña. No es seguridad: es para que no se
borre una fórmula sin querer.

- **Hojas de grupo** (`C111`, `M211`, …): se edita la **rejilla del horario**,
  es decir la asignatura y el aula de cada turno. La tabla de asignaturas de la
  derecha se calcula sola y está bloqueada.
- **Hoja `Ocupación de aulas`**: nada editable, se calcula entera. Sí se puede **ordenar y
  filtrar** aun estando protegida.
- **`Portada`** y **`Auxiliar`**: nada editable.

El **color de la pestaña** ayuda a moverse cuando la barra es un muro de nombres: cada año tiene el
suyo (todos los grupos de `C1` comparten color, los de `C2` otro…) y `Ocupación de aulas`, que se
calcula sola, va
en gris azulado.

Si necesitas tocar una celda calculada, quita la protección: en Excel, pestaña
*Revisar* → *Desproteger hoja*; en LibreOffice Calc, *Herramientas* → *Proteger
hoja* (se desmarca). No pide contraseña. Ojo: si sobrescribes la fórmula, la
pierdes, y la única forma de recuperarla es volver a generar el libro.

---

## 8. Errores comunes y qué significan

Si algo está mal en los YAML, el programa **no genera** el Excel y te dice qué pasó
(`Error de configuración: ...`). Los más frecuentes:

| Mensaje | Causa | Solución |
|---------|-------|----------|
| `'turnos' debe ser un entero >= 1` | Falta o está mal `turnos`. | Pon un número, ej. `turnos: 6`. |
| `'aulas' no puede estar vacío` | No definiste aulas. | Añade la lista `aulas: [...]`. |
| `<Carrera><Año>: faltan 'asignaturas'` | Un año sin asignaturas. | Añade su bloque `asignaturas:`. |
| `Horario para grupo inexistente: XNNN` | En el horario usaste un grupo que no sale de `facultad.yaml`. | Créalo en la estructura o corrige el id. |
| `día desconocido 'X'` | Un día del horario no está en `dias` (¿tilde, mayúscula?). | Escríbelo igual que en `dias`. |
| `turno N fuera de rango` | Turno mayor que `turnos` (o < 1). | Ajusta el turno o sube `turnos`. |
| `cada celda necesita 'asig' y 'aula'` | Una celda sin uno de los dos campos. | Completa `{asig: ..., aula: ...}`. |
| `aula 'X' no existe` | Un aula del horario no está en `aulas`. | Corrige el nombre o añádela a `aulas`. |
| `profesores: id duplicado 'X'` | Dos profesores con el mismo id. | Cambia uno de los dos. |
| `docencia: grupo inexistente 'X'` | La docencia usa un grupo que no sale de `carreras`. | Corrige el id o créalo. |
| `docencia G: asignatura 'X' no es de su año` | Le asignaste a un grupo algo que su año no imparte. | Míralo en la hoja `Asignaturas`. |
| `docencia G/A: profesor inexistente 'X'` | La docencia usa un profesor que no está en `profesores`. | Corrige el id o decláralo. |

> Nota: una **asignatura** desconocida NO da error (se resalta en naranja en el Excel). Un **aula**
> desconocida SÍ da error. Es a propósito: el aula es más "dura" que la asignatura.

---

## 9. Qué se puede y qué no se puede hacer

### Se puede

- Tener **varias carreras, años, sesiones y grupos** (la estructura es libre).
- Cambiar el **número de turnos**, la lista de **aulas** y de **días**.
- Generar el **esqueleto vacío** para llenar a mano, o la **copia fiel** desde YAML.
- Versionar los horarios en texto (YAML) y **regenerar** el Excel cuando quieras.
- Detectar automáticamente: frecuencias cumplidas/excedidas, asignaturas inexistentes, aulas
  inexistentes (al editar), ocupación de aulas y **choques de aula entre años**.
- Ver los **menús desplegables** de asignaturas y aulas al editar a mano.

### No se puede (límites actuales)

- La herramienta **no resuelve el horario por ti**: construye la estructura, valida y colorea, pero
  **tú** decides las asignaciones.
- Solo controla la **ocupación de aulas**. No detecta un profesor dando dos clases a la vez ni dos
  asignaturas en el mismo turno de un mismo grupo.
- Los **colores** de los años están definidos en el código; no se cambian desde el YAML.
- Las **aulas con comillas** (`"`) en el nombre no están soportadas.
- La entrada es por **YAML**: no se carga el horario desde Excel ni desde una interfaz gráfica.

---

## 10. Flujo de trabajo recomendado

1. **Define la facultad una vez** en `facultad.yaml` (aulas, días, turnos, carreras, años, grupos,
   asignaturas con su frecuencia). Esto cambia poco.
2. **Genera el esqueleto vacío** y ábrelo para revisar que la estructura (grupos, tabla de
   asignaturas, dropdowns) es la que esperas:
   ```bash
   python generar.py --salida esqueleto.xlsx
   ```
3. **Arma el horario.** Dos caminos:
   - **A mano en Excel** sobre el esqueleto, usando los desplegables; los colores te guían.
   - **En YAML** (`horarios.yaml`) si prefieres tenerlo versionado en texto, y regeneras con
     `--horarios`.
4. **Revisa los colores:** rojo (te pasaste), naranja (errata de asignatura), y sobre todo la hoja
   `Ocupación de aulas` en rojo intenso (choques de aula entre años). Corrige y regenera.
5. **Itera.** Cambia el YAML, regenera, vuelve a mirar. El `.xlsx` es desechable; los YAML son lo que
   guardas.
