# situacion

Lenguaje para describir situaciones tabulares y materializarlas en varias
arquitecturas de salida.

La misma descripción produce hoy un libro de cálculo, una página web con
recálculo vivo y un informe en texto plano. Ninguna de las tres arquitecturas
sabe que las otras existen.

> **El nombre es provisional.** Todavía no está decidido cómo se llama el
> lenguaje, y `situacion` es lo que se usa mientras tanto.

Por dónde empezar:

- **[`ejemplos/`](ejemplos/README.md)** — las situaciones de la facultad
  escritas en el lenguaje, cada una junto al Excel, la página web y el texto
  que produce, ya generados para abrirlos sin instalar nada.

## Pruébalo

```sh
./demostrar.sh
```

Toma las seis descripciones de `corpus/`, genera sus artefactos, los
materializa y compara todo lo que producen con el evaluador de referencia:
cada hoja del libro recalculada por LibreOffice, el texto plano leído por sus
columnas, el cálculo de la página ejecutado con Node y lo que la página dibuja
en un navegador sin pantalla. Después escribe en el libro y en la página como
lo haría quien los usa, y repite todo con los casos de robustez de
`pruebas/casos/`: situaciones ajenas al corpus con etiquetas, valores, números,
fechas y vistas que el corpus nunca tuvo. Tarda alrededor de un minuto y medio.

Lo que conviene abrir después:

```sh
xdg-open salida/horario-del-grupo.xlsx     # la rejilla dia por turno
xdg-open salida/horario-del-grupo.html     # la misma, en el navegador
xdg-open salida/defensas-de-tesis.html     # escribe un estudiante y mira
xdg-open salida/departamento.xlsx          # reparte la carga y mira la cobertura
xdg-open salida/horario-saul.html          # el horario real del Saul Delgado
```

## Los comandos

| Comando | Qué hace |
|---|---|
| `./demostrar.sh` | Todo: genera, materializa y verifica el corpus y los casos de robustez |
| `./ejecutar-pruebas.sh` | 119 pruebas. Código 1 si algo falla |
| `./demostrar-robustez.sh` | Solo los casos de robustez de `pruebas/casos/` |
| `./explorar.sh` | Genera y verifica los experimentos de `exploracion/` |
| `./generar-demostracion.sh` | Solo genera los artefactos |
| `python3 materializador/materializar.py <plano.json> <salida.xlsx>` | Plano de libro a `.xlsx` |
| `./ejemplos/actualizar.sh` | Regenera los resultados versionados de `ejemplos/` |

## Requisitos

SBCL. Para el materializador, Python con openpyxl; para las verificaciones,
LibreOffice, Node y Chromium (sin Chromium se saltan las comprobaciones de la
página dibujada, y se dice).

**El núcleo, el protocolo, el análisis y las pruebas no tienen ninguna
dependencia.** Arrancan con un SBCL recién instalado y nada más, y eso es a
propósito: es lo que tiene que poder hacer quien reciba el protocolo para añadir
su propia arquitectura.

## Qué hay

```
situacion.asd      declara los sistemas; su grafo de dependencias ES la prueba
                   de dos criterios de diseno

nucleo/            el modelo semantico y el evaluador de referencia.
                   25 nodos. No sabe que existe ninguna arquitectura
lenguaje/          las macros: la sintaxis
analisis/          las comprobaciones estaticas, sin arquitectura
protocolo/         el contrato de extension: 13 operaciones, 20 capacidades
texto/             arquitectura de texto plano
excel/             arquitectura de hoja de calculo
web/               arquitectura de pagina con recalculo vivo
corpus/            seis descripciones de situaciones reales
pruebas/           invariantes, nucleo, alcance, conformidad y robustez
pruebas/casos/     casos de robustez: situaciones ajenas al corpus
demostracion/      el guion que genera todo
materializador/    Python y Node: plano a .xlsx, los verificadores (libro,
                   texto, calculo y dibujo de la pagina) y las sondas de uso
ejemplos/          indice de las descripciones, con sus resultados ya generados
exploracion/       experimentos: cinco dominios ajenos y el primer Saul Delgado
```

**14 453 líneas de Lisp** (con las pruebas y los casos de robustez), 1 149 de
Python y 450 de JavaScript.

(`exploracion/` tiene 2 935 líneas más: son las descripciones de los
experimentos, no pertenecen a ningún sistema y no cuentan como código del
trabajo. Tiene su propio README.)

## Las seis fases de la compilación

```
  descripcion escrita en el lenguaje
        |
   (1) LECTURA          las macros expanden a constructores
   (2) CONSTRUCCION     el arbol de nodos
   (3) RESOLUCION       los simbolos pasan a ser referencias
   (4) COMPROBACION     estatica, sin arquitectura
        |
  == SITUACION RESUELTA ==   la representacion intermedia
        |
   (5) PLANIFICACION    por arquitectura. Aqui ocurre la degradacion
   (6) EMISION          por arquitectura. Sale el artefacto
```

## Las tres reglas que el sistema hace cumplir

1. **El núcleo no depende de nada.**
2. **El protocolo no ve el lenguaje.** Una arquitectura no puede usar las macros
   ni por descuido: el sistema no compila si lo intenta.
3. **Ninguna arquitectura ve a otra.** Lo que dos compartan sube a una clase de
   capacidad.

Las tres las comprueba el invariante I3, leyendo `situacion.asd`.

## El invariante que da nombre al trabajo

En `protocolo/operacion.lisp` hay una macro, `definir-operacion`, que **rechaza
en tiempo de expansión** cualquier operación del protocolo que no reciba la
arquitectura como primer parámetro:

```lisp
(definir-operacion compilar-formula
  (nodo mapa-de-columnas fila primera-fila ultima-fila))

;; => La operacion COMPILAR-FORMULA del protocolo no recibe la arquitectura.
```

Ésa es, literalmente, la forma de `compile-excel-formula` de la tesis de 2026.
No es una convención: quien la escriba, no compila.

## La inversión de capacidades

Del informe de conformidad del horario del grupo, en una ejecución real:

| | texto | excel | web |
|---|---|---|---|
| nativas | 6 | 16 | **17** |
| emuladas | 1 | 1 | 0 |
| degradadas | 4 | 0 | 0 |

La hoja de cálculo, que parece la más capaz, **emula** la tabla cruzada —fija los
dos ejes al generar y se inventa una columna de clave compuesta— mientras que la
página la cumple de forma nativa y recalcula los ejes al dibujar.

**No hay una arquitectura que pueda más y otras que puedan menos. Cada una puede
cosas distintas.**

## La tabla cruzada, que es la idea que más rindió

El horario del grupo parecía fuera del modelo: una rejilla de día por turno no es
una lista de filas. La salida fue darse cuenta de que **la matriz nunca fue una
estructura de datos**. Los datos son una colección de filas —día, turno,
asignatura, aula—. Lo que es matriz es la presentación, y la presentación es una
vista:

```lisp
(vista rejilla :de casillas :entrada t
               :etiqueta "Horario semanal"
               :filas turno :columnas dia :muestra asignatura)
```

Es el mismo criterio que el lenguaje aplica en todas partes: la intención se
declara, el mecanismo lo inventa cada arquitectura. Y baja el coste de "toca el
núcleo y las tres arquitecturas" a "tres ranuras y un método por destino".

## La evidencia

`./demostrar.sh` compara cada valor que produce cada destino con el del
evaluador de referencia del núcleo, y falla si una hoja del libro no se
compara, si compara cero celdas o si alguna celda vale un error de fórmula.
Del corpus, en una ejecución real:

| | Libro (LibreOffice) | Texto | Cálculo de la página | Página dibujada |
|---|---|---|---|---|
| plan-del-grupo | 36 | 36 | 54 | 37 |
| defensas-de-tesis | 56 | 60 | 68 | 62 |
| horario-del-grupo | 96 | 103 | 121 | 107 |
| departamento | 231 | 227 | 250 | 230 |
| horario-saul | 3 585 | 3 630 | 3 210 | 3 639 |
| seder | 237 | 254 | 256 | 261 |

Y lo mismo con los nueve casos de robustez. Cero discrepancias.

Los dos destinos no comparten nada: uno evalúa fórmulas A1 dentro de una
rejilla, el otro ejecuta funciones sobre arreglos.

## Cómo se añade una arquitectura nueva

1. Definir la clase, heredando de las capacidades que cumple.
2. Definir su clase de plan.
3. Especializar `planificar` y `emitir`.
4. Especializar `emitir-expresion` para cada tipo de nodo.
5. Especializar `resolver-carencia` para lo que no cumple.
6. Pasar el juego de pruebas de conformidad.

Nada de eso toca el núcleo, el protocolo ni ninguna otra arquitectura. La de
texto plano sirve de plantilla mínima.

## Historia

Este repositorio empezó como tres generadores de libros de Excel escritos a
medida en Python (horarios, tribunales, gestión del departamento). Ese código
se retiró una vez que este lenguaje cubrió las mismas tres situaciones sin
depender de nada de aquel enfoque.

Sigue accesible en el historial de git (se retiró en `30878a9`) para quien
necesite contrastar una descripción del corpus con el libro original.
