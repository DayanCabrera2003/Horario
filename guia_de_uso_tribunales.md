# Guía de uso — Generador de tribunales de tesis

Guía práctica y paso a paso para **usar** la herramienta que arma el Excel de las
defensas de tesis: cómo generarlo, cómo llenar los dos archivos YAML, qué
escribir para ver funcionar cada cosa, y qué se puede y qué no se puede hacer.

> Esta guía es para la persona que planifica las defensas: cómo generar el Excel
> y cómo llenar los YAML. Para el generador de horarios de clases, ver
> [`guia_de_uso.md`](guia_de_uso.md).

---

## Contenido

1. [En 30 segundos](#1-en-30-segundos)
2. [Instalar (una sola vez)](#2-instalar-una-sola-vez)
3. [Los dos comandos que usarás](#3-los-dos-comandos-que-usarás)
4. [Archivo 1 — `tribunal.yaml` (la estructura)](#4-archivo-1--tribunalyaml-la-estructura)
5. [Archivo 2 — `asignaciones.yaml` (las asignaciones)](#5-archivo-2--asignacionesyaml-las-asignaciones)
6. [Recetario: qué escribir para ver funcionar cada cosa](#6-recetario-qué-escribir-para-ver-funcionar-cada-cosa)
7. [Cómo leer el Excel generado](#7-cómo-leer-el-excel-generado)
8. [Errores comunes y qué significan](#8-errores-comunes-y-qué-significan)
9. [Qué se puede y qué no se puede hacer](#9-qué-se-puede-y-qué-no-se-puede-hacer)
10. [Flujo de trabajo recomendado](#10-flujo-de-trabajo-recomendado)

---

## 1. En 30 segundos

```bash
# 1) genera la plantilla vacía (para llenar a mano en Excel)
python generar_tribunales.py --config config/tribunal.yaml --salida tesis.xlsx

# 2) o genera un libro ya lleno desde un YAML de asignaciones
python generar_tribunales.py --config config/tribunal.yaml \
                             --asignaciones config/asignaciones.yaml \
                             --salida tesis.xlsx
```

Abres el `.xlsx` en Excel o LibreOffice. En cada **hoja de día** eliges el
estudiante de cada defensa en un desplegable y el tribunal se rellena solo; si un
profesor queda citado en dos locales a la misma hora, se **resalta en rojo**. En
la hoja **Localizar** escribes el id de una persona y ves resaltados todos los
momentos en los que participa.

---

## 2. Instalar (una sola vez)

Necesitas **Python ≥ 3.11**.

```bash
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Comprueba que funciona:

```bash
python generar_tribunales.py --config config/tribunal.yaml --salida prueba.xlsx
```

Si imprime `Generado: prueba.xlsx`, listo.

---

## 3. Los dos comandos que usarás

El programa tiene un solo punto de entrada, `generar_tribunales.py`, con tres
opciones:

| Opción | Qué es | Por defecto |
|--------|--------|-------------|
| `--config` | El YAML de **estructura** (profesores, estudiantes, locales, días, momentos, tesis). | `config/tribunal.yaml` |
| `--asignaciones` | El YAML de **asignaciones** (opcional). Si lo pones, el Excel sale lleno; si no, sale vacío. | *(ninguno)* |
| `--salida` | Nombre del archivo `.xlsx` a crear. | `tesis.xlsx` |

### Los dos modos

**Modo A — esqueleto vacío** (no pasas `--asignaciones`):

```bash
python generar_tribunales.py --config config/tribunal.yaml --salida esqueleto.xlsx
```

Genera toda la estructura (hojas por día con sus tablas por local, desplegables,
colores) pero **sin asignaciones**. Es la plantilla para que la llenes a mano en
Excel; a medida que eliges estudiantes, el tribunal se completa y los choques se
resaltan en vivo.

**Modo B — copia fiel** (pasas `--asignaciones`):

```bash
python generar_tribunales.py --config config/tribunal.yaml \
                             --asignaciones config/asignaciones.yaml \
                             --salida propuesta.xlsx
```

Genera lo mismo pero con las defensas **ya colocadas** desde el YAML. Útil para
versionar la planificación en texto y regenerar el Excel cuando quieras.

> **Regla de oro:** puedes regenerar el `.xlsx` mil veces; la fuente de verdad
> son los YAML. No edites el `.xlsx` "a mano" si piensas regenerarlo, porque se
> sobrescribe.

---

## 4. Archivo 1 — `tribunal.yaml` (la estructura)

Describe **quiénes y qué hay**: profesores, estudiantes, locales, qué días con
qué momentos, y las tesis con su tribunal. Todo se referencia por **id**.

### Esqueleto mínimo

```yaml
profesores:
  - {id: PIAD, nombre: "Pedro I. Alonso Díaz", grado: "Dr."}
  - {id: MARA, nombre: "María Ramírez",        grado: "MSc."}
  - {id: LGOM, nombre: "Luis Gómez",           grado: "Dr."}
  - {id: ANSU, nombre: "Ana Suárez",           grado: "MSc."}

estudiantes:
  - {id: JPER, nombre: "Juan Pérez"}

locales:
  - {id: POST, nombre: "Postgrado"}
  - {id: DECA, nombre: "Decanato"}

dias:
  - fecha: 2026-07-27
    momentos:
      - {inicio: "09:00", fin: "10:00"}
      - {inicio: "10:00", fin: "11:00"}
  - fecha: 2026-07-28
    momentos:
      - {inicio: "09:00", fin: "10:00"}

tesis:
  - {estudiante: JPER, tutor: PIAD, oponente: MARA, presidente: LGOM, secretario: ANSU}
```

### Campo por campo

- **`profesores`** — lista de profesores. Cada uno tiene:
  - **`id`** — código corto (lo que se escribe y se muestra en las celdas). El id
    existe justamente para escribir poco, por ejemplo `PIAD` en vez del nombre
    completo.
  - **`nombre`** — nombre largo (solo referencia; no aparece en las tablas).
  - **`grado`** — grado científico (opcional).
- **`estudiantes`** — lista de estudiantes, con `id` y `nombre`.
- **`locales`** — lista de locales (aulas/salas), con `id` y `nombre`. El
  **nombre** es lo que titula cada tabla en la hoja de día.
- **`dias`** — lista de días. Cada día tiene:
  - **`fecha`** — la fecha (formato `AAAA-MM-DD`). Es también el **nombre de la
    hoja** de ese día en el Excel.
  - **`momentos`** — la lista de momentos (franjas) posibles **de ese día**. Cada
    momento tiene `inicio` y `fin` (`HH:MM`). Los momentos pueden ser distintos
    de un día a otro.
- **`tesis`** — lista de tesis. Cada tesis se identifica por su **estudiante** y
  lleva su tribunal: `tutor`, `oponente`, `presidente`, `secretario` (todos son
  ids de profesor). El estudiante no es profesor.

> **Todo por id.** Los desplegables muestran ids, las tablas muestran ids y en la
> hoja Localizar se escribe el id. Los nombres completos viven solo en el YAML.

---

## 5. Archivo 2 — `asignaciones.yaml` (las asignaciones)

Solo lo necesitas en **modo copia fiel**. Dice qué tesis va en cada local, día y
momento. La tesis se identifica por su **estudiante**.

### Estructura

```yaml
- {estudiante: JPER, local: POST, fecha: 2026-07-27, momento: "09:00-10:00"}
```

Es una lista; cada línea es una defensa colocada. Campos:

- **`estudiante`** — id de un estudiante (identifica la tesis). Debe existir.
- **`local`** — id de un local. Debe existir.
- **`fecha`** — una de las fechas de `dias`. Debe existir.
- **`momento`** — el id del momento, en formato `inicio-fin` (por ejemplo
  `"09:00-10:00"`). Debe ser uno de los momentos **de esa fecha**.

No tienes que colocar todas las tesis: solo pon las que quieras fijar. El resto
lo llenas a mano en Excel.

---

## 6. Recetario: qué escribir para ver funcionar cada cosa

### Tribunal autocompletado (hoja de día)

Coloca una tesis (o elige el estudiante en el desplegable dentro de Excel). Las
columnas Tutor, Oponente, Presidente y Secretario se rellenan solas buscando el
tribunal de esa tesis.

```yaml
- {estudiante: JPER, local: POST, fecha: 2026-07-27, momento: "09:00-10:00"}
```

En la hoja `2026-07-27`, tabla `Postgrado`, fila `09:00-10:00`: aparece `JPER` y
su tribunal completo.

### Colisión de profesor → **rojo** (hoja de día)

Haz que **el mismo profesor** quede en **dos locales distintos** en el **mismo
momento** del día.

```yaml
# PIAD es tutor de la tesis de JPER y secretario de la de LFDZ.
# Ambas caen a las 09:00 en locales distintos -> PIAD choca.
- {estudiante: JPER, local: POST, fecha: 2026-07-27, momento: "09:00-10:00"}
- {estudiante: LFDZ, local: DECA, fecha: 2026-07-27, momento: "09:00-10:00"}
```

En la hoja `2026-07-27`, las celdas donde aparece `PIAD` (en `Postgrado` y en
`Decanato`, a las 09:00) se pintan de rojo. Que un mismo profesor tenga dos
roles en **una misma** tesis (un solo local) **no** es colisión.

### Localizar a una persona → **amarillo** (hoja Localizar)

No hay que escribir nada en el YAML: en la hoja `Localizar`, escribe el id de un
profesor o estudiante en la celda de entrada (arriba, junto a "Localizar a:").
Se resaltan todos los momentos en los que esa persona participa, por día y
local.

- Un **profesor**: se resaltan todas sus defensas.
- Un **estudiante**: se resalta el único momento de su propia defensa.

---

## 7. Cómo leer el Excel generado

El archivo tiene tres tipos de hoja:

### Una hoja por día (`2026-07-27`, `2026-07-28`, …)

Una tabla apilada por cada local. Columnas: `Momento | Estudiante | Tutor |
Oponente | Presidente | Secretario`. Filas = los momentos de ese día.

- La columna **Estudiante** es la que se llena (desplegable de ids de
  estudiantes). Al elegir uno, colocas esa tesis en ese local y momento.
- Las columnas de **profesores** se rellenan solas por fórmula: son el tribunal
  de la tesis elegida. No se escriben a mano.
- **Rojo:** colisión — ese profesor está en dos locales distintos en el mismo
  momento. La leyenda al pie lo recuerda.

### Hoja `Localizar`

- Una **celda de entrada global** (arriba) donde escribes el id de una persona.
- Una tabla de una columna por cada combinación **día–local**, con los momentos
  de ese día.
- **Amarillo:** el momento donde la persona escrita participa. La leyenda al pie
  lo recuerda.

### Hoja `Datos` (oculta)

Es interna (tabla tesis-tribunal + lista de estudiantes para los desplegables y
las fórmulas). Normalmente no la tocas. Si quieres verla: clic derecho en una
pestaña → *Mostrar hoja oculta*.

> **Importante:** para ver los valores y colores hay que abrir el archivo en
> Excel o LibreOffice, que es quien **recalcula las fórmulas**. Recién generado,
> las columnas de profesor pueden verse vacías hasta que el programa recalcula al
> abrir (normalmente automático).

---

## 8. Errores comunes y qué significan

Si algo está mal en los YAML, el programa **no genera** el Excel y te dice qué
pasó (`Error de configuración: ...`). Los más frecuentes:

| Mensaje | Causa | Solución |
|---------|-------|----------|
| `'profesores' no puede estar vacio` | Falta la lista de profesores. | Añade `profesores: [...]`. |
| `'estudiantes' no puede estar vacio` | Falta la lista de estudiantes. | Añade `estudiantes: [...]`. |
| `'locales' no puede estar vacio` | Falta la lista de locales. | Añade `locales: [...]`. |
| `dia <fecha>: faltan 'momentos'` | Un día sin momentos. | Añade su lista `momentos:`. |
| `tesis: estudiante inexistente '<id>'` | Una tesis referencia un estudiante que no existe. | Créalo en `estudiantes` o corrige el id. |
| `tesis <est>: <rol> inexistente '<id>'` | Un rol (tutor/oponente/…) referencia un profesor que no existe. | Créalo en `profesores` o corrige el id. |
| `asignacion: estudiante inexistente '<id>'` | La asignación usa un estudiante que no existe. | Corrige el id o añade la tesis. |
| `asignacion: local inexistente '<id>'` | La asignación usa un local que no existe. | Corrige el id o añade el local. |
| `asignacion: fecha inexistente '<fecha>'` | La fecha no está en `dias`. | Escríbela igual que en `dias`. |
| `asignacion <fecha>: momento inexistente '<id>'` | El momento no está entre los de esa fecha. | Usa un `inicio-fin` que exista ese día. |

---

## 9. Qué se puede y qué no se puede hacer

### Se puede

- Tener **muchos profesores, estudiantes, locales, días y tesis**.
- Momentos **distintos por día** (cada día define los suyos).
- Generar el **esqueleto vacío** para llenar a mano, o la **copia fiel** desde
  YAML.
- Versionar la planificación en texto (YAML) y **regenerar** el Excel cuando
  quieras.
- Detectar automáticamente **choques de profesor** (mismo profesor en dos
  locales a la vez) y **localizar** a cualquier persona por sus momentos.

### No se puede (límites actuales)

- La herramienta **no resuelve la planificación por ti**: construye la
  estructura, valida y resalta, pero **tú** decides las asignaciones.
- La colisión se controla **solo entre profesores** (el estudiante aparece en una
  sola tesis).
- El rol **`vocal`** no está incluido por ahora (se puede añadir después).
- No se avisa si colocas la **misma tesis en dos celdas** distintas al editar a
  mano (es edición libre).
- Todo se maneja por **id**: las tablas muestran ids, no nombres completos.
- Los **nombres de hoja** son la fecha (`AAAA-MM-DD`). Fechas con caracteres
  inválidos para Excel (`: \ / ? * [ ]`) darían problemas.
- La entrada es por **YAML**: no se carga desde Excel ni desde una interfaz
  gráfica.

---

## 10. Flujo de trabajo recomendado

1. **Define la estructura una vez** en `tribunal.yaml` (profesores, estudiantes,
   locales, días con sus momentos, y las tesis con su tribunal). Esto cambia
   poco.
2. **Genera el esqueleto vacío** y ábrelo para revisar que las hojas por día,
   las tablas por local y los desplegables son los que esperas:
   ```bash
   python generar_tribunales.py --config config/tribunal.yaml --salida esqueleto.xlsx
   ```
3. **Arma la planificación.** Dos caminos:
   - **A mano en Excel** sobre el esqueleto, eligiendo el estudiante de cada
     defensa; el tribunal se completa y los choques se resaltan.
   - **En YAML** (`asignaciones.yaml`) si prefieres tenerlo versionado en texto,
     y regeneras con `--asignaciones`.
4. **Revisa los rojos** (colisiones de profesor) y usa la hoja `Localizar` para
   comprobar la agenda de cada persona. Corrige y regenera.
5. **Itera.** Cambia el YAML, regenera, vuelve a mirar. El `.xlsx` es desechable;
   los YAML son lo que guardas.
