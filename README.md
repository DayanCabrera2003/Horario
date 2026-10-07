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
- **[`docs/`](docs/README.md)** — la documentación: la guía del lenguaje, el
  porqué, el diseño y el borrador de la tesis.

## Pruébalo

```sh
./demostrar.sh
```

Toma las cuatro descripciones de `corpus/`, genera dieciséis artefactos, los
materializa y comprueba —con LibreOffice y con Node— que los dos destinos vivos
calculan exactamente lo mismo que el evaluador de referencia. Tarda menos de un
minuto.

Lo que conviene abrir después:

```sh
xdg-open salida/horario-del-grupo.xlsx     # la rejilla dia por turno
xdg-open salida/horario-del-grupo.html     # la misma, en el navegador
xdg-open salida/defensas-de-tesis.html     # escribe un estudiante y mira
xdg-open salida/departamento.xlsx          # reparte la carga y mira la cobertura
```

## Los cuatro comandos

| Comando | Qué hace |
|---|---|
| `./demostrar.sh` | Todo: genera, materializa y verifica |
| `./ejecutar-pruebas.sh` | 64 pruebas, 559 comprobaciones. Código 1 si algo falla |
| `./generar-demostracion.sh` | Solo genera los artefactos |
| `python3 materializador/materializar.py <plano.json> <salida.xlsx>` | Plano de libro a `.xlsx` |
| `./ejemplos/actualizar.sh` | Regenera los resultados versionados de `ejemplos/` |

## Requisitos

SBCL. Para el materializador, Python con openpyxl; para las verificaciones,
LibreOffice y Node.

**El núcleo, el protocolo, el análisis y las pruebas no tienen ninguna
dependencia.** Arrancan con un SBCL recién instalado y nada más, y eso es a
propósito: es lo que tiene que poder hacer quien reciba el protocolo para añadir
su propia arquitectura.

## Qué hay

```
situacion.asd      declara los sistemas; su grafo de dependencias ES la prueba
                   de dos criterios de diseno

nucleo/            el modelo semantico y el evaluador de referencia.
                   24 nodos. No sabe que existe ninguna arquitectura
lenguaje/          las macros: la sintaxis
analisis/          las comprobaciones estaticas, sin arquitectura
protocolo/         el contrato de extension: 13 operaciones, 19 capacidades
texto/             arquitectura de texto plano
excel/             arquitectura de hoja de calculo
web/               arquitectura de pagina con recalculo vivo
corpus/            cuatro descripciones reales de la facultad
pruebas/           invariantes, nucleo, alcance y conformidad
demostracion/      el guion que genera todo
materializador/    Python y Node: plano a .xlsx, y las dos verificaciones
ejemplos/          indice de las descripciones, con sus resultados ya generados
docs/              la documentacion publicada
exploracion/       experimentos: el caso Saul Delgado y cinco dominios ajenos
```

**9 262 líneas de Lisp** (con las pruebas), 387 de Python y 112 de
JavaScript.

(`exploracion/` tiene 2 930 líneas más: son las descripciones de los
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
| nativas | 7 | 17 | **18** |
| emuladas | 1 | 1 | 0 |
| degradadas | 10 | 0 | 0 |

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

`./demostrar.sh` termina comprobando, por los dos lados, que cada valor
calculado coincide con el del evaluador de referencia del núcleo:

```
  ok   plan-del-grupo.xlsx:      30 celdas evaluadas por LibreOffice
  ok   defensas-de-tesis.xlsx:   52 celdas evaluadas por LibreOffice
  ok   horario-del-grupo.xlsx:   15 celdas evaluadas por LibreOffice
  ok   departamento.xlsx:       208 celdas evaluadas por LibreOffice
  ok   plan-del-grupo.html:      48 valores del JavaScript emitido
  ok   defensas-de-tesis.html:   60 valores del JavaScript emitido
  ok   horario-del-grupo.html:  105 valores del JavaScript emitido
  ok   departamento.html:       231 valores del JavaScript emitido
```

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
