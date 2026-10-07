# Arquitectura del sistema

Documento de diseño. Define la estructura del sistema que hay que construir: el
modelo de evaluación, el núcleo semántico, las fases de compilación, el protocolo
de arquitectura, la jerarquía de capacidades, el mecanismo de degradación, la
estructura de sistemas y paquetes, y los invariantes que hacen que todo eso sea
comprobable en vez de prometido.

**Lo que este documento no cubre, a propósito:** calendario, fases de trabajo,
pasos de investigación y el guion del documento de tesis. Eso va aparte.

Requisito de lectura previa: `01-PARA-ENTENDER.md`. Este documento da por
sabidos el problema, el vocabulario y el diagnóstico de las tres tesis
anteriores.

Fecha: 2026-09-20. Estado: propuesta, sin implementar. Ninguna decisión de aquí
es irreversible antes del experimento de refutación.

**Nombre provisional del sistema: `situacion`.** No está decidido. Todos los nombres de paquete de este documento usan ese
prefijo y habrá que renombrarlos cuando se decida.

---

## Índice

1. [Criterios de diseño](#1-criterios-de-diseño)
2. [El modelo de evaluación](#2-el-modelo-de-evaluación)
3. [El núcleo semántico](#3-el-núcleo-semántico)
4. [Cómo se compila](#4-cómo-se-compila)
5. [El protocolo de arquitectura](#5-el-protocolo-de-arquitectura)
6. [La jerarquía de capacidades](#6-la-jerarquía-de-capacidades)
7. [El mecanismo de degradación](#7-el-mecanismo-de-degradación)
8. [Estructura de sistemas y paquetes](#8-estructura-de-sistemas-y-paquetes)
9. [La arquitectura de Excel y la frontera del materializador](#9-la-arquitectura-de-excel-y-la-frontera-del-materializador)
10. [Texto, web y SQL: por qué existen en el diseño](#10-texto-web-y-sql-por-qué-existen-en-el-diseño)
11. [Invariantes arquitectónicos verificables](#11-invariantes-arquitectónicos-verificables)
12. [El juego de pruebas de conformidad](#12-el-juego-de-pruebas-de-conformidad)
13. [Registro de decisiones](#13-registro-de-decisiones)
14. [Riesgos arquitectónicos](#14-riesgos-arquitectónicos)
15. [Correspondencia de vocabulario](#15-correspondencia-de-vocabulario)

---

## 1. Criterios de diseño

Seis criterios. Los cinco primeros son **comprobables por una prueba
automática**, y esa es la característica que los distingue de los "principios de
diseño" de las tesis anteriores, que eran afirmaciones. La sección 11 dice cómo
se comprueba cada uno.

**C1 — Ninguna palabra de direccionamiento cruza hacia arriba.** En el núcleo y
en el protocolo no puede aparecer vocabulario de posición: letra de columna,
coordenada, número de fila, rango, celda, hoja, libro, ni el nombre de ninguna
función de Excel, ni `openpyxl`, ni `xlsx`.

Matiz importante para que la prueba sea honesta y no teatro: **`fila` sí es
palabra del dominio.** Una colección tiene filas, y `(de fila campo)` es
vocabulario legítimo. Lo prohibido es la *dirección* de una fila, no su
existencia. La lista negra es de direccionamiento, no de estructura.

**C2 — Toda función del protocolo recibe la arquitectura y se especializa en
ella.** Éste es el criterio que la tesis de 2026 incumple en el punto exacto
donde más importa (`compile-excel-formula`), y es el que más barato sale
comprobar: se recorre el paquete del protocolo y se mira la lista de parámetros
especializados de cada función genérica.

**C3 — Las arquitecturas no ven el lenguaje.** Un backend depende del protocolo
y nada más. No puede ver las macros, ni los sinónimos, ni los accesores en
español. Si intenta usarlos, el sistema no compila. La independencia deja de ser
una promesa y pasa a ser algo que la herramienta impide violar.

**C4 — Ninguna arquitectura ve a otra.** No hay dependencias entre backends. El
de web no puede reutilizar nada del de Excel, ni al revés. Si dos comparten algo,
ese algo sube a una clase de capacidad (sección 6), que es el único sitio donde
se comparte.

**C5 — Lo que una arquitectura se inventa es suyo y no sale de ahí.** Las hojas
auxiliares, las columnas de apoyo, las filas de reserva y el plano de libro
pertenecen a la arquitectura que los necesita. Ningún otro sistema los referencia.

**C6 — Un archivo, una responsabilidad.** Regla del proyecto. Si un
archivo crece, falta una separación; se refactoriza antes de seguir. Este
criterio no se comprueba solo, pero sí se vigila: la sección 8 fija de antemano
qué va en cada archivo.

### El criterio de calidad del lenguaje, que no es automático

Heredado de la mejor idea de 2025: **Fernando tiene que poder leer una
descripción y decir si es correcta sin que se la expliquen.** Si hace falta
explicarla, el vocabulario está mal elegido. Ningún test puede comprobar eso;
se comprueba enseñándoselo.

---

## 2. El modelo de evaluación

Ninguna de las tres tesis anteriores define su modelo de evaluación, y es lo que
hace falta para que "cualquier arquitectura" signifique algo preciso. Aquí se
declara.

### 2.1 El modelo

Una situación materializada es un **grafo de dependencias entre valores con
nombre**. Tres piezas:

1. **Valores con nombre.** Cada campo de cada fila de cada colección es un valor
   con nombre. También lo son los parámetros.
2. **Derivaciones.** Un valor derivado es una **función pura** de otros valores
   con nombre. Pura significa: mismo entrada, misma salida, sin efectos, sin
   depender de dónde esté escrita.
3. **Recálculo.** Cuando un valor de entrada cambia, todos los valores que
   dependen de él —directa o transitivamente— se vuelven a calcular.

Nótese lo que **no** dice el modelo: no dice que las derivaciones se escriban una
vez y se repliquen por filas ajustando referencias. Eso es el modelo de Excel, y
es precisamente la trampa en la que cayeron las tres tesis. Aquí una derivación
se define **por fila**, sobre una fila ligada explícitamente, y cómo se replique
es asunto de cada arquitectura.

### 2.2 Qué cumple cada arquitectura

| Arquitectura | Rejilla | Recálculo | Entrada | Dominio de entrada | Orden declarado | Uno a muchos | Distintos | Navegación |
|---|---|---|---|---|---|---|---|---|
| Excel / Calc | sí | vivo | sí | sí, avisando | por columna | emulado | emulado | pestañas y enlaces |
| Web | no | vivo | sí | sí | sí | sí | sí | rutas |
| Emacs (`org-table`) | sí | bajo demanda | sí | sí | por columna | emulado | emulado | buffers |
| SQL | no | al consultar | parcial | parcial | sí | sí | sí | no |
| PDF / HTML estático | no | **congelado** | **no** | **no** | sí | sí | sí | enlaces |

Esta tabla es a la vez una contribución teórica del trabajo y la especificación
de la jerarquía de la sección 6: cada columna es una clase de capacidad y cada
fila es una composición.

### 2.3 El nivel de recálculo es una capacidad, no una decisión global

El dossier plantea como decisión abierta si las derivaciones son vivas o
congeladas, y recomienda vivas. La arquitectura propone no elegir:

> **El lenguaje siempre describe derivaciones vivas. El nivel de recálculo que
> una arquitectura puede ofrecer —`viva`, `bajo-demanda`, `congelada`— es una
> capacidad que esa arquitectura declara.**

Consecuencias, y son todas buenas:

- El PDF deja de ser un caso que el diseño no contempla y pasa a ser una
  degradación declarada, con su línea en el informe de conformidad.
- La decisión deja de ser irreversible: añadir una arquitectura con recálculo
  distinto no obliga a revisar el lenguaje.
- La tabla de 2.2 se vuelve ejecutable en vez de ilustrativa.

Sigue siendo decisión de Fernando.

---

## 3. El núcleo semántico

Todo lo de esta sección vive en el sistema `situacion/nucleo` y no sabe que
existe ninguna arquitectura.

### 3.1 El modelo de situación

```
situacion
  nombre
  parametros   : lista de parametro
  colecciones  : lista de coleccion
  marcas       : lista de marca
  vistas       : lista de vista

parametro
  nombre
  tipo
  rol          : :fijo | :entrada        ; un tope de carga se edita; una
  valor                                  ; constante del dominio no

coleccion
  nombre
  campos       : lista de campo
  clave        : lista de campo          ; puede ser compuesta
  orden        : campo o nil             ; solo con orden se puede hablar
                                         ; de fila anterior y siguiente
  crecimiento  : nil | :crece            ; intencion, nunca mecanismo
  origen       : :declarada
               | (:una-fila-por <campo> :de <coleccion>)

campo
  nombre                                 ; identificador interno
  etiqueta     : texto                   ; lo que se ve
  tipo         : :texto :entero :numero :hora :fecha :booleano
  rol          : :fijo | :entrada | :derivado
  opcional     : booleano
  dominio      : nil | expresion-de-conjunto   ; solo si rol = :entrada
  al-violar    : :advertir | :impedir          ; solo si hay dominio
  expresion    : nil | expresion               ; solo si rol = :derivado

marca
  nombre                                 ; el significado, no el color
  condicion    : expresion booleana
  alcance      : lista de campo          ; sobre que se senala
  severidad    : :informativa | :advertencia | :problema
  explicacion  : nil | expresion de texto

vista
  nombre
  fuente       : coleccion
  secciones    : nil | campo             ; una seccion por valor de este campo
  agrupacion   : nil | campo
  es-entrada   : booleano                ; punto de entrada del documento
  enlaza-con   : lista de vista
```

Tres decisiones dentro de este modelo merecen justificarse:

**El rol de campo es el concepto nuevo del trabajo.** No aparece en ninguna de
las tres tesis. De una sola declaración salen, en Excel, el bloqueo de la celda y
el color de la pestaña; en web, si el campo es un `input` o un texto; en SQL, si
es columna o vista; en Emacs, si el cursor puede entrar ahí. Sale del corpus:
donde hoy hay 75 llamadas de protección repartidas, hay un solo hecho del
dominio.

**`crecimiento` declara intención, no mecanismo.** `:crece` dice *"esta lista no
está cerrada; el usuario añadirá filas después de generar"*. Es un hecho del
dominio. Las filas de reserva y el rango que crece con `OFFSET` y `COUNTA` son lo
que Excel se inventa para cumplirlo; la web pone un botón. El lenguaje no nombra
ninguna de las dos cosas.

**`origen (:una-fila-por ...)` sube al dominio el "hueco gemelo" del corpus.**
Hoy, la hoja de cobertura del departamento tiene una fila por cada fila de la
hoja de asignaturas, emparejadas por posición, con fórmulas
`=IF(Asignaturas!A5="","",Asignaturas!A5)`. En el dominio eso es *"la cobertura
tiene una fila por asignatura del plan"*. El emparejamiento por posición es
mecanismo de Excel.

### 3.2 El álgebra de expresión

Sale del corpus, no de la especulación. Cada construcción tiene su sitio en los
tres libros.

```
;; valores
<literal>                                       42, "texto", 09:00
(parametro <nombre>)
(de <variable-de-fila> <campo>)

;; operaciones
(+ a b) (- a b) (* a b) (/ a b)
(= a b) (/= a b) (< a b) (<= a b) (> a b) (>= a b)
(y ...) (o ...) (no a)
(si <cond> <entonces> <si-no>)
(vacio? a)                                      ; "no se ha escrito nada aqui"

;; texto
(texto ...)                                     ; concatena
(plural <n> "singular" "plural")                ; concordancia

;; conjuntos: alimentan :dominio
(los <campo> de <coleccion>)
(los <campo> de <coleccion> :donde <cond>)

;; agregados con filtro
(cuantas <coleccion> :donde <cond>)
(suma <campo> de <coleccion> :donde <cond>)
(minimo <campo> de <coleccion> :donde <cond>)
(maximo <campo> de <coleccion> :donde <cond>)
(cuantas-distintas <campo> de <coleccion> :donde <cond>)

;; busqueda por clave
(la-fila-de <coleccion> :donde <cond>)
(el <campo> de <expresion-de-fila> :si-no <valor>)

;; relacion uno a muchos
(las-filas-de <coleccion> :donde <cond>)

;; cuantificacion
(existe <var> :en <coleccion> :donde <cond> [:distinta-de <var>])
(comparten <var-a> <var-b> (<campo> ...))        ; azucar: existe un campo
                                                 ; de la lista con valor comun

;; vecindad: solo si la coleccion declara orden
(anterior <var>)
(siguiente <var>)
```

**Justificación de cada bloque contra el corpus:**

| Construcción | Dónde está hoy |
|---|---|
| `la-fila-de` / `el ... de` | 11 usos de `VLOOKUP`: `tribunales/hoja_dia.py:42`, `departamento/hoja_asignacion.py:88`, `departamento/hoja_carga.py:102`, `horarios/hoja_grupo.py:291` |
| clave compuesta en `:donde` | `horarios/hoja_grupo.py:291`, clave `"<grupo>#<asignatura>"` |
| `cuantas`, `suma` con filtro | `COUNTIF`, `SUMIF`, `COUNTIFS`, `SUMIFS` en `departamento/hoja_cobertura.py` |
| `cuantas-distintas` | `departamento/hoja_datos.py`, columnas L:M, el rodeo plano |
| `las-filas-de` | `departamento/hoja_carga.py`, detalle de carga por profesor |
| `existe` / `comparten` | los tres libros; es el cuantificador existencial de 2026 |
| `plural` | `departamento/hoja_cobertura.py`, "Falta 1 profesor" / "Faltan N profesores" |
| `anterior` / `siguiente` | la parrilla de TV de 2026; el aula de la fila de abajo en horarios |
| `vacio?` | la guarda `IF(...="","",...)` que aparece en casi toda fórmula del corpus |

**Lo que se rehace de 2026.** `expr-counta` —"contar celdas no vacías"— no entra.
En el dominio la pregunta es *cuántas filas hay*, y eso es `(cuantas coleccion)`.
"Celda vacía" solo tiene sentido donde hay una rejilla preasignada con huecos, y
esa rejilla es invención de Excel. `vacio?` sí entra, pero significa otra cosa:
*un campo de entrada que el usuario todavía no ha rellenado*, que sí es un hecho
del dominio.

### 3.3 Ámbitos y variables de fila

Esto es la respuesta al riesgo más profundo del trabajo, y es una pieza del
núcleo, no del protocolo.

Un **ámbito** dice qué variables de fila hay ligadas y sobre qué colección
recorre cada una:

```
ambito
  ligaduras : alist de (simbolo . coleccion)
  actual    : simbolo                ; cual de ellas es "la fila actual"
```

Reglas del núcleo:

1. **Toda derivación se evalúa en un ámbito.** El ámbito de la expresión de un
   campo derivado liga `fila` a la colección de ese campo. No hay forma de
   escribir una expresión sin ámbito.
2. **`(de v campo)` exige que `v` esté ligada** y que `campo` pertenezca a la
   colección sobre la que `v` recorre. Se comprueba en la fase de resolución.
3. **`existe` liga una variable nueva** y extiende el ámbito para su condición.
4. **`(anterior v)` y `(siguiente v)` exigen que la colección de `v` declare
   orden.** Si no lo declara, es un error de compilación, detectado sin
   consultar a ninguna arquitectura.

Esa cuarta regla es la que impide que se cuele el modelo de Excel. `previous-of`
en 2026 significaba de hecho "la fila de arriba en la rejilla". Aquí "anterior"
significa "la anterior según el orden declarado", que se traduce sin ambigüedad:
en SQL es una función de ventana sobre ese `ORDER BY`, en JavaScript es el índice
anterior del arreglo ordenado, en Excel es una referencia relativa **porque el
backend de Excel se ha comprometido a escribir las filas en ese orden**, y eso
queda registrado en su plan.

El ámbito **no contiene ninguna dirección**. Es la pieza que sustituye a
`fila`, `primera-fila` y `ultima-fila` de 2026.

### 3.4 El evaluador de referencia

Una pieza del núcleo, no del protocolo: dada una situación resuelta y unos
datos, calcula los valores derivados y dice qué marcas disparan.

Su primera justificación es mecánica: una arquitectura con derivaciones
congeladas —un PDF, un HTML estático— necesita que alguien evalúe las
expresiones antes de escribirlas, y ese alguien no puede ser un backend, porque
entonces cada uno tendría su propia semántica.

Pero lo que lo convierte en una de las piezas más valiosas del sistema son las
otras tres cosas que trae:

**Es la definición de qué significa el lenguaje.** La semántica deja de ser "lo
que haga Excel" y pasa a estar escrita en un sitio. Toda arquitectura tiene que
coincidir con él, y esa coincidencia es comprobable.

**Es un oráculo que no depende de ningún destino.** Se puede probar una
expresión —una búsqueda por clave, un cuantificador, un conteo de distintos—
sin generar ningún archivo y sin tener ningún backend escrito. Eso permite que
el álgebra de expresión de la sección 3.2 se desarrolle y se pruebe entera
antes de que exista la primera arquitectura, que es justo lo contrario de lo
que hicieron las tres tesis anteriores.

**Y cierra el lazo de la verificación desde el primer día.** El evaluador da el
valor esperado; LibreOffice, tras el round-trip, da el valor real. Comparar los
dos es el invariante I8, y con esta pieza está disponible con una tabla de tres
filas en vez de al final del trabajo. Ninguna de las tres tesis anteriores tuvo
nada equivalente: la de 2026 afirma que sus fórmulas se evalúan y lo respalda
con capturas, que es lo más lejos que se llegó.

Vive en `situacion/nucleo` y no tiene dependencias.

---

## 4. Cómo se compila

Seis fases. Las cuatro primeras no conocen ninguna arquitectura; las dos últimas
son lo que un backend implementa.

```
  descripcion en el DSL
        |
   (1) LECTURA            macroexpansion: las formas del lenguaje se
        |                 convierten en llamadas a constructores
        v
   (2) CONSTRUCCION       instancias CLOS: el arbol
        |
        v
   (3) RESOLUCION         los simbolos pasan a ser referencias a objetos;
        |                 se construye el grafo de dependencias
        v
   (4) COMPROBACION       estatica, sin arquitectura
        |
        v
  == SITUACION RESUELTA ==   <-- la representacion intermedia
        |                        (lo que la tesis afirma independiente)
        |
   (5) PLANIFICACION      por arquitectura. Aqui ocurre la degradacion.
        |                 Salida: el plan (opaco) + el informe de conformidad
        v
   (6) EMISION            por arquitectura. Salida: el artefacto
        |
        v
  .xlsx / pagina web / .sql / .el
```

### Fase 1 — Lectura

Las macros del sistema `situacion/lenguaje` expanden las formas del DSL a
llamadas a los constructores de `situacion/nucleo`. Aquí es donde se cobra la
ventaja del DSL interno que identificó Arcia en 2017: **no hay analizador léxico
ni sintáctico porque los hace el intérprete de Lisp**.

Es también donde viven las comodidades de lectura heredadas de 2025: los
sinónimos de constructor y la generación de accesores gramaticales.

### Fase 2 — Construcción

Instancias CLOS. Nada está resuelto todavía: los nombres siguen siendo símbolos.
Un campo derivado guarda su expresión como árbol, no como texto.

### Fase 3 — Resolución

Convierte símbolos en referencias:

- cada `(de v campo)` apunta al objeto campo real;
- cada `(la-fila-de c :donde ...)` apunta a la colección real;
- cada `:dominio (los x de y)` se resuelve;
- cada marca resuelve su alcance.

Y construye el **grafo de dependencias** entre valores derivados, que es lo que
hace falta para la comprobación de ciclos y, más adelante, para que cada
arquitectura sepa en qué orden materializar.

### Fase 4 — Comprobación estática

Todo lo que se puede detectar sin saber a dónde se va a generar:

| Comprobación | Ejemplo de lo que caza |
|---|---|
| Referencias | `(de fila tutorr)` con una errata |
| Ciclos | un derivado que depende de sí mismo |
| Orden | `(anterior fila)` sobre una colección sin orden declarado |
| Coherencia de rol | un campo `:derivado` con `:dominio`, que no tiene sentido |
| Tipos ligeros | comparar una hora con un texto |
| Clave | `la-fila-de` cuyo `:donde` no determina una fila |
| Alcance de marca | una marca que señala un campo de otra colección |

Estas comprobaciones son, por sí solas, una de las recomendaciones explícitas de
la tesis de 2026, que pedía *"una herramienta de validación estática del AST que
detecte referencias a columnas inexistentes o rangos cruzados inconsistentes"*.

El resultado de la fase 4 es la **situación resuelta**: la representación
intermedia. El criterio C1 se aplica exactamente aquí. Si en esta estructura
aparece una letra de columna, el diseño está mal.

### Fase 5 — Planificación

**Esta fase es nueva. Ni 2025 ni 2026 la tienen, y es la que hace que la
degradación sea un paso de primera clase en vez de una decisión improvisada
enterrada en un `format`.**

Entrada: la situación resuelta más una arquitectura. Salida: dos cosas.

1. **El plan.** Un objeto cuya forma pertenece por completo a la arquitectura. El
   de Excel decide aquí qué hoja, qué columna y qué fila ocupa cada cosa, cuántas
   filas de reserva hace falta, qué hojas auxiliares hay que inventarse y en qué
   orden. El de web decide qué componentes hay y cómo se llaman sus variables.
   **El núcleo nunca mira dentro.**
2. **El informe de conformidad.** La lista de qué pidió la descripción y cómo lo
   resolvió esta arquitectura (sección 7).

Separar planificación de emisión es lo que permite que `emitir-expresion` no
necesite recibir números de fila: cuando llega la emisión, el plan ya sabe dónde
va todo, y el backend lo consulta por su cuenta.

### Fase 6 — Emisión

El backend escribe su artefacto consultando su plan. Para web, SQL y Emacs eso es
texto directo. Para Excel es un plano de libro que un materializador convierte en
archivo (sección 9).

### 4.1 Traza de una derivación, de punta a punta

Para que las seis fases no queden abstractas. Tomamos el autocompletado del
tribunal del libro de defensas.

**Lo que se escribe:**

```lisp
(campo tutor :rol derivado
  (el tutor de (la-fila-de tesis
                 :donde (= estudiante (de fila estudiante)))
      :si-no ""))
```

**Tras la fase 4** (situación resuelta), en prosa: *el campo `tutor` de
`citaciones` es derivado; su expresión, en un ámbito donde `fila` recorre
`citaciones`, busca la fila de `tesis` cuya clave `estudiante` coincide con el
campo `estudiante` de la fila actual, toma su campo `tutor`, y si no hay tal fila
vale texto vacío.* Cero direcciones.

**Fase 5, Excel.** El plan decide: `citaciones` ocupa las columnas A..G de una
hoja por día; `tesis` vive en una hoja de datos con un rango nombrado
`TesisTribunal` cuya primera columna es la clave; `tutor` es la columna 2 de ese
rango. Registra el compromiso de que la clave sea la primera columna, porque
`VLOOKUP` lo exige.

**Fase 6, Excel.** Consultando el plan sale:

```
=IF($B4="","",IFERROR(VLOOKUP($B4,TesisTribunal,2,FALSE),""))
```

Que es, carácter a carácter, lo que hoy produce `tribunales/hoja_dia.py:40-43`.

**Fase 5, web.** No hay direcciones que repartir. El plan registra que `tesis` se
indexa por `estudiante` en un `Map`, y que el campo es computado.

**Fase 6, web:**

```js
get tutor() {
  const t = tesisPorEstudiante.get(this.estudiante);
  return t ? t.tutor : "";
}
```

**Fase 5 y 6, SQL.** El plan decide que `citaciones` es una tabla y la parte
derivada una vista; la emisión produce un `LEFT JOIN` con `COALESCE`.

Las tres salidas son distintas. La expresión del núcleo es la misma, y ninguna de
las tres decisiones de direccionamiento subió por encima de la fase 5.

---

## 5. El protocolo de arquitectura

El sistema `situacion/protocolo` es el contrato de extensión: lo que Fernando
recibiría para hacer Emacs por su cuenta.

### 5.1 Las funciones genéricas

```lisp
;;; -------- declaracion de la arquitectura --------

(defgeneric capacidades (arquitectura)
  (:documentation
   "Lista de capacidades que esta arquitectura declara cumplir de forma
    nativa. Normalmente se deduce de las superclases y no hace falta
    especializarla."))

(defgeneric nivel-de-recalculo (arquitectura)
  (:documentation
   ":viva, :bajo-demanda o :congelada. Ver seccion 2.3."))

;;; -------- planificacion (fase 5) --------

(defgeneric planificar (arquitectura situacion)
  (:documentation
   "Construye el plan de esta arquitectura para esta situacion.
    El plan es un objeto cuya forma pertenece a la arquitectura; el
    nucleo no lo inspecciona nunca. Senala `carencia-de-capacidad`
    cada vez que la situacion pide algo que esta arquitectura no
    cumple de forma nativa.
    Devuelve (values plan informe)."))

(defgeneric planificar-coleccion (arquitectura coleccion plan))
(defgeneric planificar-campo     (arquitectura campo coleccion plan))
(defgeneric planificar-vista     (arquitectura vista plan))

;;; -------- emision (fase 6) --------

(defgeneric emitir (arquitectura plan destino)
  (:documentation
   "Escribe el artefacto. `destino` es un flujo o una ruta."))

(defgeneric emitir-expresion (arquitectura expresion ambito plan)
  (:documentation
   "Traduce un nodo de expresion a lo que esta arquitectura use para
    expresar calculo.
      ambito : que variables de fila hay ligadas y sobre que coleccion
               recorre cada una. No contiene ninguna direccion.
      plan   : el plan de esta arquitectura, donde vive el
               direccionamiento que ella misma decidio en la fase 5.
    ESTA es la operacion que en 2026 se llamaba `compile-excel-formula`
    y no recibia la arquitectura. Ver seccion 5.3."))

(defgeneric emitir-marca   (arquitectura marca ambito plan))
(defgeneric emitir-entrada (arquitectura campo ambito plan))
(defgeneric emitir-vista   (arquitectura vista plan))

;;; -------- carencias (seccion 7) --------

(defgeneric resolver-carencia (arquitectura capacidad nodo)
  (:documentation
   "Que hace esta arquitectura cuando le piden `capacidad` y no la
    cumple. Devuelve (values respuesta nota), donde respuesta es
    :emula, :degrada o :rechaza, y nota es el texto que ira al
    informe de conformidad."))
```

**Trece** funciones genéricas, contadas sobre el registro del protocolo. Una
arquitectura mínima —solo datos y derivaciones congeladas— especializa cinco;
una completa, las trece.

*(El número no es decorativo, y ya se separó una vez: este documento dijo once,
luego doce, y el código tiene trece porque `materializar` —el punto de entrada
de alto nivel— también es una operación. Los invariantes I2 e I6 recorren el
registro, así que la cuenta se puede comprobar en vez de recordarla.)*

### 5.2 Qué sustituye a `col-map` y a `fila`

El punto central del diseño. Dos objetos, con papeles distintos:

**`ambito` — del núcleo, del dominio.** Dice qué variables de fila hay ligadas.
Es la misma para todas las arquitecturas. No tiene direcciones.

**`plan` — de la arquitectura, opaco.** Es donde vive el direccionamiento. Lo
fabrica, lo llena y lo lee la propia arquitectura; el núcleo se limita a
transportarlo de una función a otra sin abrirlo.

El `col-map` de 2026 no desaparece: **baja de sitio.** Sigue existiendo, dentro
del plan del backend de Excel, que es donde tiene sentido. Lo que desaparece es
que esté en la firma del punto de extensión.

### 5.3 Contraste explícito con 2026

| 2026 | Aquí |
|---|---|
| `compile-excel-formula` | `emitir-expresion` |
| el nombre menciona el destino | el nombre no menciona ningún destino |
| no recibe la arquitectura | `arquitectura` es el primer parámetro y está especializado |
| `col-map`: símbolo → letra de Excel | el direccionamiento vive en el `plan`, que es del backend |
| `fila`, `primera-fila`, `ultima-fila` | `ambito`: qué variables de fila hay ligadas |
| `data-names`, sin documentar | — |
| `generate-code` sí recibe `lang`, pero solo cubre la estructura | todas las funciones reciben la arquitectura, estructura y cálculo por igual |
| la distinción entre las dos genéricas la motiva el destino ("una produce cadena, la otra produce JSON") | la distinción la motiva la fase: planificar o emitir |

Ese último renglón importa más de lo que parece. En 2026, que hubiera dos
funciones genéricas distintas se justificaba porque *en Excel* una expresión
produce texto que se incrusta y una estructura produce un objeto JSON. Eso es una
propiedad del backend colándose en el diseño del protocolo. Aquí la división es
temporal —primero se planifica, después se emite— y vale igual para cualquier
destino.

---

## 6. La jerarquía de capacidades

Recupera la idea que la tesis de 2017 atribuye a ADOL\* y GEMURAL, y que **ni
2017 ni 2025 ni 2026 llegaron a implementar**: componer por propiedades en vez de
enumerar destinos.

**Son doce**, no once: a las once de la tabla de 2.2 se añadió
`con-crecimiento` al implementarlo, porque es precisamente la que sostiene el
argumento de la inversión de capacidades y no tenía columna propia.

```lisp
;;; La raiz. Todo destino es una arquitectura.
(defclass arquitectura () ())

;;; Las propiedades componibles. Cada una corresponde a una columna de
;;; la tabla de la seccion 2.2.
(defclass con-rejilla                (arquitectura) ())
(defclass con-derivacion-viva        (arquitectura) ())
(defclass con-derivacion-por-consulta(arquitectura) ())
(defclass con-entrada                (arquitectura) ())
(defclass con-dominio-de-entrada     (arquitectura) ())
(defclass con-orden-declarado        (arquitectura) ())
(defclass con-relacion-uno-a-muchos  (arquitectura) ())
(defclass con-conteo-de-distintos    (arquitectura) ())
(defclass con-marcado-visual         (arquitectura) ())
(defclass con-marcado-textual        (arquitectura) ())
(defclass con-navegacion             (arquitectura) ())

;;; Las arquitecturas concretas son composiciones.
(defclass excel (con-rejilla con-derivacion-viva con-entrada
                 con-dominio-de-entrada con-orden-declarado
                 con-marcado-visual con-marcado-textual
                 con-navegacion)
  ())

(defclass web (con-derivacion-viva con-entrada con-dominio-de-entrada
               con-orden-declarado con-relacion-uno-a-muchos
               con-conteo-de-distintos con-marcado-visual
               con-marcado-textual con-navegacion)
  ())

(defclass sql (con-derivacion-por-consulta con-orden-declarado
               con-relacion-uno-a-muchos con-conteo-de-distintos
               con-marcado-textual)
  ())
```

### 6.1 Para qué sirve de verdad

No es taxonomía decorativa. Sirve para tres cosas concretas:

**Primera: compartir métodos sin que dos arquitecturas se vean.** Un método puede
especializarse en la **propiedad**, no en la arquitectura:

```lisp
;; Vale para Excel y para web, que no se conocen entre si.
(defmethod emitir-marca ((a con-marcado-visual) marca ambito plan) ...)

;; Vale para SQL y para la impresion en blanco y negro.
(defmethod emitir-marca ((a con-marcado-textual) marca ambito plan) ...)
```

Es exactamente el mecanismo por el que, en la idea original, añadir Java después
de C# costaba casi nada. Satisface el criterio C4 sin renunciar a compartir.

**Segunda: reglas transversales con métodos auxiliares.** La otra idea de 2017
(`recognize-pattern` y los métodos `:before`) aplicada aquí:

```lisp
;; En cualquier arquitectura con entrada, lo derivado es de solo lectura.
;; Una regla, un sitio, todas las arquitecturas presentes y futuras.
(defmethod planificar-campo :after ((a con-entrada) campo coleccion plan)
  (when (eq (rol campo) :derivado)
    (marcar-como-solo-lectura plan campo)))
```

**Tercera: decidir qué hay que degradar.** Comparar lo que la situación pide con
lo que la arquitectura declara es una operación sobre clases, y sale gratis.

### 6.2 Cómo se añade una arquitectura

Es la pregunta que Fernando quiere poder responder, y la respuesta tiene que
caber en una página:

1. Definir la clase, heredando de las propiedades que cumple.
2. Definir su clase de plan.
3. Especializar `planificar` y `emitir`.
4. Especializar `emitir-expresion` para cada tipo de nodo de expresión.
5. Especializar `resolver-carencia` para lo que no cumple.
6. Pasar el juego de pruebas de conformidad (sección 12).

**Nada de eso toca el núcleo, el protocolo ni ninguna otra arquitectura.** Y el
criterio C3 garantiza que ni siquiera se pueda intentar.

---

## 7. El mecanismo de degradación

Ninguna de las tres tesis anteriores se plantea qué pasa cuando una arquitectura
no puede expresar algo. 2026 lo reconoce en una nota al pie —*"podría simplemente
prescindir de esta funcionalidad"*— y ahí queda.

### 7.1 Las cuatro respuestas

| Respuesta | Cuándo | Ejemplo real del corpus |
|---|---|---|
| **cumple** | Nativo | Web mostrando `las-filas-de`: es una lista |
| **emula** | No lo tiene, pero puede fabricarlo. Declara a qué coste | Excel ante `las-filas-de`: hoja auxiliar con clave numerada, líneas reservadas y aviso "(+3 más)" al desbordarse |
| **degrada** | Hay una versión más pobre que sigue sirviendo para lo mismo | SQL ante una marca: una columna con el nombre del estado en texto |
| **rechaza** | No hay versión honesta y fingirla sería mentir | PDF ante `:rol entrada`: no hay dónde escribir |

La frontera entre **degrada** y **rechaza** es la que hay que defender: se degrada
cuando el resultado sigue cumpliendo el propósito por otra vía; se rechaza cuando
el resultado *parecería* correcto y no lo sería. Un documento que aparenta admitir
entrada y no la admite es peor que un error.

### 7.2 Se implementa con el sistema de condiciones

Ésta es la decisión de diseño de la que más partido se puede sacar, y es
idiomática de Common Lisp:

```lisp
(define-condition carencia-de-capacidad ()
  ((capacidad    :initarg :capacidad    :reader capacidad)
   (nodo         :initarg :nodo         :reader nodo)
   (arquitectura :initarg :arquitectura :reader arquitectura)))
```

Durante la planificación, cuando un backend encuentra algo que no cumple,
**señala** la condición y ofrece reinicios (`restarts`):

```lisp
(restart-case (signal 'carencia-de-capacidad ...)
  (emular   (nota) ...)
  (degradar (nota) ...)
  (omitir   (nota) ...))
```

Por qué esto es mejor que devolver un valor: **la política queda fuera del
backend**. El compilador instala un manejador, y ese manejador puede ser:

- `:permisiva` — acepta emular y degradar, anota todo. Es la de por defecto.
- `:estricta` — cualquier carencia es un error. Sirve para saber exactamente qué
  descripciones son puras.
- `:solo-nativo` — ni siquiera se permite emular. Sirve para medir cuánto de una
  descripción cae de verdad dentro de una arquitectura.

Esas tres políticas, aplicadas a los tres libros del corpus y a las cuatro
arquitecturas, son una tabla de resultados experimentales, y salen gratis del
diseño.

### 7.3 El informe de conformidad

Cada reinicio tomado deja una línea:

```
Situacion: defensas-de-tesis      Arquitectura: excel
-----------------------------------------------------------------------
cumple    coleccion tesis                       datos fijos
cumple    campo citaciones.estudiante           entrada con dominio
cumple    campo citaciones.tutor                busqueda por clave
cumple    marca profesor-citado-dos-veces       marcado visual
emula     coleccion citaciones :crece           20 filas de reserva; el
                                                rango crece con lo escrito.
                                                Limite: no admite huecos.
-----------------------------------------------------------------------
4 nativas, 1 emulada, 0 degradadas, 0 rechazadas
```

**Ese informe es la evidencia que 2026 no tenía.** Convierte "el mecanismo de
extensión funciona" en algo que se enseña, y el renglón de límite de la emulación
—*"no admite huecos"*— es exactamente la clase de detalle que hoy vive enterrado
en el docstring de `comun/rangos.py` y que separa un prototipo de algo usable.

---

## 8. Estructura de sistemas y paquetes

Definiciones ASDF, un archivo una responsabilidad (criterio C6). El grafo de
dependencias **es** la prueba de los criterios C3 y C4, así que se escribe con
cuidado y se comprueba (sección 11).

```
situacion.asd

  situacion/nucleo              depende de: (nada)
    paquete.lisp                exporta el vocabulario del nucleo
    nodo.lisp                   la clase raiz y la macro defnodo
    situacion.lisp              la situacion y los parametros
    coleccion.lisp              colecciones, clave, orden, crecimiento
    campo.lisp                  campos, rol, tipo, dominio
    expresion.lisp              el algebra de la seccion 3.2
    ambito.lisp                 ambitos y variables de fila ligadas
    marca.lisp                  marcas, severidad, explicacion
    vista.lisp                  vistas, secciones, navegacion

  situacion/lenguaje            depende de: nucleo
    paquete.lisp
    macros.lisp                 situacion, coleccion, campo, marca, vista
    expresiones.lisp            las formas de expresion como constructores
    sinonimos.lisp              varios nombres para un mismo constructor
    gramatica.lisp              accesores en espanol, de def-entidad (2025)

  situacion/analisis            depende de: nucleo
    paquete.lisp
    resolucion.lisp             simbolos -> objetos
    dependencias.lisp           el grafo y la deteccion de ciclos
    comprobacion.lisp           las comprobaciones estaticas de la fase 4
    diagnostico.lisp            errores legibles, con el sitio de la descripcion

  situacion/protocolo           depende de: nucleo
    paquete.lisp
    capacidades.lisp            la jerarquia de clases de la seccion 6
    genericas.lisp              las once funciones genericas
    carencia.lisp               la condicion, los reinicios y las politicas
    informe.lisp                el informe de conformidad

  situacion/conformidad         depende de: protocolo, lenguaje
    paquete.lisp
    casos.lisp                  las descripciones minimas, una por capacidad
    aserciones.lisp             que debe cumplir cada arquitectura en cada caso
    ejecutor.lisp               corre la suite contra una arquitectura dada

  situacion/excel               depende de: protocolo
    paquete.lisp
    arquitectura.lisp           la clase y sus capacidades
    plan.lisp                   direccionamiento: hojas, columnas, filas, rangos
    reserva.lisp                filas de reserva y rangos que crecen
    auxiliar.lisp               hojas auxiliares que se inventa
    carencia.lisp               como emula y degrada lo que no cumple
    formula.lisp                emitir-expresion a notacion A1
    marcado.lisp                formato condicional y paleta
    entrada.lisp                validacion de datos y proteccion de celdas
    plano.lisp                  el plano de libro y su serializacion

  situacion/web                 depende de: protocolo
  situacion/sql                 depende de: protocolo

  situacion/corpus              depende de: lenguaje
    tribunales.lisp             la descripcion del libro de defensas
    horarios.lisp
    departamento.lisp

  situacion/pruebas             depende de: todo
    invariantes.lisp            las pruebas de la seccion 11
    nucleo/ lenguaje/ analisis/ excel/ web/ sql/
```

Y, fuera del sistema Lisp:

```
materializador/                 Python. Ver seccion 9.
    plano.py                    lee el plano de libro
    escribir.py                 llama a openpyxl
    (reutiliza comun/ del repositorio Horario)
```

### 8.1 Las reglas de dependencia, dichas explícitamente

| Regla | Qué criterio garantiza |
|---|---|
| `nucleo` no depende de nada | La representación intermedia no puede contaminarse |
| `protocolo` depende solo de `nucleo` | C2: el contrato se define contra el dominio |
| `protocolo` **no** depende de `lenguaje` | C3: un backend no ve las macros |
| `protocolo` **no** depende de ninguna arquitectura | El contrato no se define contra su primer implementador — que es justo el error de 2026 |
| toda arquitectura depende solo de `protocolo` | C3 |
| ninguna arquitectura depende de otra | C4 |
| nadie fuera de `situacion/excel` referencia `plano.lisp` | C5 |

La cuarta regla merece subrayarse. En 2026 el punto de extensión se escribió
mirando Excel, que era lo único que había. Aquí el protocolo se define contra el
núcleo y el juego de pruebas de conformidad, y las arquitecturas llegan después.
El orden de construcción **es** una decisión arquitectónica: el protocolo se
escribe antes que el primer backend, y se falsa cuanto antes con dos.

---

## 9. La arquitectura de Excel y la frontera del materializador

### 9.1 Por qué hay un materializador en Python

Comprobado el 2026-09-20: no existe ninguna librería de Common Lisp capaz de
**escribir** xlsx con fórmulas, formato condicional, validación de datos, rangos
nombrados y protección de celdas. `cl-excel` no soporta fórmulas; `cl-xlsx` y
`lisp-xl` son de lectura. Escribir un emisor OOXML desde cero son semanas de
trabajo que no aportan nada a la pregunta de la tesis, y reintroducirían bugs que
el corpus ya resolvió contra el usuario real.

### 9.2 Dónde está exactamente la frontera

```
  situacion/excel  (Lisp)
     fase 5: plan          decide hojas, columnas, filas, reservas, auxiliares
     fase 6: emision       produce el PLANO DE LIBRO
        |                  (celdas A1, formulas ya compiladas, estilos,
        |                   rangos nombrados, validaciones, protecciones,
        |                   reglas de formato condicional)
        |
        |   <--- frontera: por DEBAJO del punto de extension
        v
  materializador  (Python)
     lee el plano, llama a openpyxl, reutiliza comun/
        |
        v
      .xlsx
```

El plano de libro es **100% vocabulario de Excel**, y eso está bien: a esa altura
ya estamos dentro del backend de Excel. Lo que importa son las tres reglas:

1. **Lo posee `situacion/excel`.** Criterio C5.
2. **Ningún otro sistema lo conoce.** Web, SQL y Emacs no tienen materializador:
   emiten texto directamente. La asimetría la causa que xlsx sea un contenedor
   binario comprimido, que es un hecho mecánico, no semántico.
3. **El núcleo no lo ve nunca.**

### 9.3 Por qué esto no es el error de 2026, dicho para la defensa

Se parece por fuera, así que hay que poder explicarlo en dos frases:

> En 2026, el JSON con fórmulas de Excel **era el punto de extensión**: era el
> sitio por donde, según la tesis, iba a entrar un backend HTML. Por eso la
> afirmación era falsa — lo que ese JSON lleva no es una descripción del cálculo,
> es el cálculo ya compilado a Excel.
>
> Aquí el punto de extensión es el protocolo, que está **cuatro fases más
> arriba**. El plano de libro vive dentro de una arquitectura concreta, por
> debajo del punto de extensión, y ninguna otra arquitectura lo toca.

Y hay una ventaja práctica que conviene no desaprovechar: **el plano es
comprobable sin generar archivos.** Se puede aseverar sobre el plano —qué celda
lleva qué fórmula, qué rango está protegido— en pruebas rápidas, y dejar el
round-trip por LibreOffice para la verificación de que las fórmulas evalúan. En
2026 el JSON era la interfaz y no estaba probado.

### 9.4 Qué reutiliza el materializador

**Corrección sobre lo que decía este documento.** La versión anterior afirmaba
que el materializador reutilizaba siete módulos de `comun/` del repositorio.
Eso resultó falso al implementarlo: `materializador/materializar.py` es
autónomo. Importa `json`, `sys`, `pathlib` y `openpyxl`, y nada más.

Lo que sí hace es **reimplementar las decisiones** que `comun/` aprendió contra
el usuario real —celdas bloqueadas salvo lo que el rol declara editable, aviso
no bloqueante en las validaciones, rango que se dimensiona con lo escrito,
leyenda que explica cada color— en unas doscientas líneas propias.

Por qué quedó así y por qué está bien: `comun/` conoce el dominio de los
generadores actuales (sabe qué es una hoja de grupo, una portada, una leyenda de
colisión). El materializador no puede conocer nada de eso: recibe un plano de
celdas y estilos. Importarlo habría metido dominio en la única pieza que tiene
que estar libre de él.

El materializador **no sabe nada del dominio**. No conoce profesores ni defensas:
conoce celdas, estilos y rangos. Eso es lo que impide que la frontera se corra.

---

## 10. Texto, web y SQL: por qué existen en el diseño

No son producto: son **instrumentos de falsación**, y por eso forman parte de la
arquitectura y no de la lista de deseos.

**Texto plano** es la primera y la más importante de las tres, aunque sea la
que menos parece. Unas 120 líneas: sin rejilla, sin fórmulas, sin color, sin
entrada, con las derivaciones congeladas por el evaluador de referencia.

Se elige precisamente porque **no puede cumplir casi nada**. Existe para que
haya dos arquitecturas desde el primer commit, que es la única salvaguarda real
contra el error de 2026 — un protocolo diseñado mirando un solo destino sale con
la forma de ese destino, se escriba cuando se escriba. Y como no cumple casi
nada, obliga a que la maquinaria de degradación exista desde el principio en vez
de ser un capítulo que se escribe al final: su primer informe de conformidad ya
trae un `degrada` (el recálculo) y un `rechaza` (la entrada).

Es barata de escribir y barata de mantener, y hace el mismo trabajo que el
experimento de refutación con la ventaja de que **queda**: el experimento se
tira, las pruebas no.

**Web** se elige por ser lo más distinto posible de Excel manteniendo el
recálculo vivo: no tiene rejilla, no tiene direcciones, no tiene capacidad
reservada. Si el protocolo estuviera formulado en términos de hoja de cálculo,
la web lo revienta de inmediato. Es el backend que obliga a que la representación
intermedia sea honesta.

**SQL** se elige por ser barato y por romper el modelo por el otro lado: cubre
datos y derivaciones pero **no** interacción, ni marcado visual, ni navegación.
Es el caso que obliga a que el mecanismo de degradación exista de verdad, en vez
de ser un párrafo. Y da la vuelta a dos capacidades: `cuantas-distintas` y
`las-filas-de`, que Excel tiene que emular con maquinaria, en SQL son una palabra.

Esa inversión es el mejor argumento disponible de que la jerarquía de capacidades
no es decorativa: **no hay una arquitectura que pueda más y otras que puedan
menos. Cada una puede cosas distintas.**

Se omite el móvil, y hay que decirlo en el documento: hace lo mismo que la web
con otra pantalla, así que aporta coste sin información sobre la pregunta que la
tesis investiga. Omitir por redundancia es defendible; omitir por falta de
tiempo, no.

Emacs no lo implementa Dayan: es el experimento (`01-PARA-ENTENDER.md`, 3.5).

---

## 11. Invariantes arquitectónicos verificables

Las afirmaciones de arquitectura son las que se caen en las defensas. Aquí se
convierten en pruebas. Viven en `pruebas/invariantes.lisp`.

**I1 — Léxico del núcleo y del protocolo (criterio C1).**
Recorre el código fuente de `situacion/nucleo` y `situacion/protocolo` buscando
una lista negra de direccionamiento: `letra-de-columna`, `coordenada`,
`numero-de-fila`, `celda`, `rango`, `hoja`, `libro`, `A1`, más los nombres de
funciones de Excel (`COUNTIF`, `VLOOKUP`, `SUMPRODUCT`, `OFFSET`, `COUNTA`,
`IFERROR`...), más `openpyxl` y `xlsx`. Falla si aparece alguna.

La lista es de **direccionamiento**, no de estructura: `fila`, `campo` y
`coleccion` son vocabulario del dominio y están permitidos. Esa distinción es lo
que hace que la prueba sirva de algo.

**I2 — Firma del protocolo (criterio C2).**
Recorre todas las funciones genéricas exportadas por `situacion/protocolo` y
comprueba que en su lista de parámetros especializados aparece `arquitectura` o
una subclase suya. **Es la detección automática del Hallazgo A de 2026**, y es la
prueba más valiosa del conjunto: si algún día alguien añade al protocolo una
función que no despacha sobre la arquitectura, salta.

**I3 — Grafo de dependencias (criterios C3 y C4).**
Lee las definiciones de sistema del `.asd` y comprueba las siete reglas de la
tabla 8.1. En particular: que ninguna arquitectura dependa de `situacion/lenguaje`
y que ninguna dependa de otra.

**I4 — Aislamiento del plano (criterio C5).**
Comprueba que ningún símbolo exportado por `excel/plano.lisp` se referencia
desde fuera de `situacion/excel`.

**I5 — Cobertura de conformidad.**
Comprueba que toda capacidad declarada en `protocolo/capacidades.lisp`
tiene al menos un caso en el juego de pruebas de conformidad. Impide que se
añadan capacidades sin prueba.

**I6 — Pureza de la representación intermedia.**
Serializa la situación resuelta de los tres libros del corpus y comprueba que en
esa serialización no aparece ninguna palabra de la lista negra de I1. Es I1
aplicado al dato en vez de al código, que es el sitio por donde 2026 se coló: su
árbol estaba limpio de nombre y su JSON venía lleno de `$G$4:$G$16`.

**I7 — Equivalencia con el corpus.**
Para cada uno de los tres libros: generar desde la descripción y comparar con lo
que produce hoy el generador Python. No byte a byte —el orden de escritura de
openpyxl no es estable— sino semánticamente: mismas celdas con mismos valores,
mismas fórmulas tras normalizar, mismos rangos nombrados, mismas validaciones,
mismas protecciones, mismas reglas de formato condicional.

**I8 — Las fórmulas evalúan.**
Round-trip por LibreOffice: generar, rellenar como lo haría un usuario, convertir
con `soffice --headless`, releer con `data_only=True` y comprobar los valores
calculados. Ya está resuelto en este proyecto
(dos guiones de la etapa de los generadores en Python) y cazó tres fallos que la batería
de pruebas daba por buenos.

De I1 a I6 son pruebas de **arquitectura**: comprueban el diseño. I7 e I8 son
pruebas de **producto**: comprueban el resultado. Las dos clases hacen falta y
ninguna sustituye a la otra.

---

## 12. El juego de pruebas de conformidad

Es lo que se le entrega a un tercero junto con el protocolo, y es lo que convierte
"mi arquitectura funciona" en algo comprobable.

**Qué es.** Un conjunto de descripciones mínimas en el DSL, una por capacidad,
cada una con las aserciones que cualquier arquitectura debe satisfacer para
declararse conforme a esa capacidad.

**Cómo está organizado.** Una descripción por capacidad, lo más pequeña posible:

| Caso | Qué ejercita | Qué se asevera |
|---|---|---|
| `datos-minimos` | una colección de campos fijos | el artefacto contiene los datos |
| `derivacion-simple` | un campo derivado aritmético | el valor calculado es el correcto |
| `derivacion-viva` | editar una entrada y recalcular | el derivado cambia |
| `entrada-con-dominio` | `:dominio` y `:al-violar` | el valor fuera de dominio se señala |
| `marca-visual` | una marca con severidad | la fila señalada es la correcta |
| `marca-textual` | la misma marca sin color | el estado aparece como texto |
| `busqueda-por-clave` | `la-fila-de` + `el ... de` | trae el valor correcto y el `:si-no` |
| `clave-compuesta` | `:donde` con dos igualdades | idem |
| `existencial` | `existe` + `comparten` | detecta la colisión y solo esa |
| `uno-a-muchos` | `las-filas-de` | aparecen todas las relacionadas, o se declara el límite |
| `conteo-de-distintos` | `cuantas-distintas` | el número es correcto |
| `orden-y-vecindad` | `anterior` / `siguiente` | el vecino es el del orden declarado |
| `crecimiento` | `:crece` | añadir una fila después de generar la incorpora |
| `navegacion` | vistas enlazadas | se puede llegar de una a otra |

**Cómo se ejecuta.** Una arquitectura declara qué capacidades cumple; el ejecutor
corre solo los casos correspondientes en modo estricto, y el resto en modo
permisivo para comprobar que **degrada o rechaza de forma declarada** en vez de
fallar en silencio. Una arquitectura es conforme si: pasa en estricto todo lo que
declara, y para lo que no declara emite una respuesta de las cuatro con su nota.

**Por qué importa que sea un artefacto y no una promesa.** Es la mitad de la
pregunta científica. Si Fernando implementa Emacs y pasa la suite sin tocar el
núcleo, el mecanismo funciona. Si no, el trabajo documenta exactamente dónde se
rompió, que es un resultado igual de publicable y mucho más honesto que afirmar
la extensibilidad sin probarla, que es lo que se hizo tres veces seguidas.

---

## 13. Registro de decisiones

Cada una con la alternativa que se descartó y por qué. Es lo que hay que poder
defender.

**D1 — El protocolo pasa un plan opaco, no parámetros de direccionamiento.**
*Alternativa descartada:* pasar explícitamente lo que necesita cada backend.
*Por qué:* es literalmente el error de 2026. Cualquier lista explícita de
parámetros se fija en la forma del primer backend que se implemente.
*Coste:* el núcleo no puede razonar sobre el direccionamiento, así que no puede
optimizarlo ni diagnosticarlo. Se asume: no es su trabajo.

**D2 — Planificación y emisión son dos fases separadas.**
*Alternativa descartada:* una sola pasada que decida y escriba a la vez, como
2026. *Por qué:* es lo que obliga a que la función de emisión reciba números de
fila, porque en el momento de escribir todavía no se sabe dónde va todo. Y es lo
que deja la degradación sin un sitio donde ocurrir. *Coste:* dos recorridos del
árbol en vez de uno. Irrelevante a esta escala.

**D3 — Capacidades por herencia múltiple, no por tabla de banderas.**
*Alternativa descartada:* que cada arquitectura tenga una lista de símbolos con
lo que sabe hacer. *Por qué:* con clases, los métodos pueden especializarse en la
capacidad, y dos arquitecturas comparten implementación sin conocerse (C4). Con
banderas habría que consultarlas a mano en cada sitio. Además recupera la idea de
ADOL\*, con genealogía dentro de la línea. *Coste:* la jerarquía hay que
diseñarla bien desde el principio; añadir una capacidad transversal más tarde
obliga a revisar las composiciones.

**D4 — La degradación se implementa con condiciones y reinicios.**
*Alternativa descartada:* que `planificar` devuelva un valor especial.
*Por qué:* con reinicios, la política de qué se acepta vive **fuera** del
backend, y se pueden compilar los mismos libros en modo estricto, permisivo y
solo-nativo para obtener una tabla de resultados. Con valor de retorno, la
política queda cableada en cada backend. *Coste:* exige entender el sistema de
condiciones de Common Lisp, que es la parte menos conocida del lenguaje. Hay que
documentarlo bien para el tercero.

**D5 — El `.xlsx` lo escribe un materializador en Python.**
*Alternativa descartada:* un emisor OOXML propio en Lisp.
*Por qué:* comprobado que no hay librería CL que escriba lo que hace falta;
hacerlo son semanas sin aporte científico, y se perderían 631 líneas de `comun/`
ya probadas contra el usuario real. *Coste:* dos lenguajes, y hay que explicar en
la defensa por qué la frontera aquí sí es legítima (sección 9.3).

**D6 — Las derivaciones son siempre vivas; el nivel de recálculo es capacidad.**
*Alternativa descartada:* decidir globalmente vivas o congeladas.
*Por qué:* cualquiera de las dos deja fuera arquitecturas legítimas. Como
capacidad, el PDF es una degradación declarada y no un agujero. *Coste:* el
lenguaje obliga a pensar siempre en términos de recálculo, aunque el destino no
lo tenga. Pendiente de confirmar con Fernando.

**D7 — La vecindad exige orden declarado.**
*Alternativa descartada:* permitir `anterior` sin más, como `previous-of` de 2026.
*Por qué:* sin orden declarado, "anterior" significa "la fila de arriba en la
rejilla", que es el modelo de Excel colándose en el lenguaje, y no tiene
traducción a SQL ni a web. *Coste:* hay descripciones que hoy son implícitas y
habrá que hacer explícitas. Es el coste bien pagado.

**D8 — La marca declara significado; el color es opción de arquitectura.**
*Alternativa descartada:* que la regla lleve color, como pide la definición 3.8
de 2026. *Por qué:* el color no sobrevive al cambio de arquitectura y el
significado sí; en blanco y negro tiene que ser texto. Y el corpus ya lo hace:
la hoja de cobertura escribe "Faltan 3 profesores" porque ahí el color no
alcanzaba. *Coste:* hace falta una paleta por arquitectura, que es un artefacto
más que mantener.

**D9 — El protocolo se escribe antes que el primer backend.**
*Alternativa descartada:* extraer el protocolo del backend de Excel una vez
escrito. *Por qué:* extraer una abstracción de un solo caso produce la
abstracción de ese caso. Es, otra vez, el error de 2026. *Coste:* el primer
protocolo estará mal y habrá que rehacerlo cuando el segundo backend lo falsee.
Se asume y se planifica: por eso la rebanada vertical lleva dos backends desde el
principio.

---

## 13 bis. Estado de implementación

Este documento se escribió antes que el código. Al implementarlo, varias cosas
resultaron distintas. **Donde discrepen, manda el código**, y esta sección dice
en qué.

### Lo que está implementado y funciona

Las seis fases salvo la matización de abajo; el evaluador de referencia; las
trece operaciones del protocolo, todas con método en al menos una arquitectura
(lo comprueba el invariante I6); las doce capacidades; el mecanismo de
degradación con sus cuatro respuestas y el informe de conformidad; tres
arquitecturas —texto, hoja de cálculo y web—; el materializador y las dos
verificaciones.

### Lo que el documento describe y el código no tiene

| Está en el diseño | Realidad |
|---|---|
| `las-filas-de` (relación uno a muchos) en el álgebra de §3.2 | **No implementado.** No existe en el lenguaje ni en el núcleo. La capacidad `con-relacion-uno-a-muchos` existe y nadie la pide |
| `origen (:una-fila-por X :de Y)` en §3.1 | El slot existe; **no hay sintaxis** para darle otro valor que `:declarada` |
| `enlaza-con` en el nodo de vista | **No existe.** La navegación se expresa hoy con `:entrada` y la lista de vistas |
| Fase 3 como pasada de resolución | **No es una pasada.** Los nombres siguen siendo símbolos y se resuelven al vuelo con `coleccion-llamada`, `campo-llamado` y `parametro-llamado`. La detección de ciclos usa una tabla local por colección, no un grafo global |
| Degradación con `restart-case` y reinicios | **Se implementó con `signal` más una genérica.** `requerir` señala una condición informativa y delega en `resolver-carencia`, que devuelve `(values respuesta nota)`. La política sigue viviendo fuera del backend, en la variable `*politica*`, que era el objetivo; los reinicios no hicieron falta |
| `planificar` devuelve `(values plan informe)` | Devuelve solo el plan. El informe lo arma `con-informe` dentro de `materializar` |
| La distribución de archivos de §8 | El núcleo es un `modelo.lisp` y no cinco archivos; `analisis` no tiene `resolucion` ni `dependencias`; el protocolo tiene además `operacion.lisp` y `requerimientos.lisp`; `excel` tiene cinco archivos y no diez; no hay sistema `conformidad` aparte —vive en `pruebas`— ni arquitectura SQL; y sí existe la arquitectura de texto, que el documento no listaba |

### Lo que se añadió y no estaba en el diseño

- **La arquitectura de texto plano.** Nació de la regla de tener dos
  arquitecturas desde el primer commit. Resultó ser la pieza que fuerza a que
  la degradación exista desde el principio.
- **El invariante I6.** Toda operación del protocolo tiene que tener método en
  alguna arquitectura. Nació de un hallazgo real: cuatro operaciones estaban
  declaradas y no las implementaba nadie, así que las marcas, la entrada y las
  vistas se materializaban con código interno de cada backend y **no pasaban
  por el punto de extensión**. El protocolo prometía más de lo que cumplía.
- **`verificar-web.js`.** Ejecuta el JavaScript emitido y lo compara con el
  evaluador de referencia, igual que el round-trip hace con LibreOffice.
- **La capacidad `con-crecimiento`.**
- **La opción `:en` de la marca**, para decir de qué colección son sus filas
  cuando dos colecciones tienen campos con el mismo nombre.

---

## 14. Riesgos arquitectónicos

**R1 — El álgebra de expresión crece sin control.**
Es la forma más común de que un trabajo así se hunda: cada construcción nueva
multiplica el trabajo por el número de arquitecturas.
*Mitigación:* la lista de la sección 3.2 está cerrada y justificada construcción
a construcción contra el corpus. Añadir una exige (a) enseñar dónde aparece en
los tres libros, (b) un caso de conformidad, y (c) decidir qué hace cada
arquitectura que no la cumple. Si no se cumplen las tres, no entra.

**R2 — El plan opaco se convierte en un vertedero.**
Como el núcleo no lo mira, nada impide que un backend meta ahí dentro lógica de
dominio y acabe reimplementando el análisis por su cuenta.
*Mitigación:* el plan solo se construye en la fase 5 y solo se lee en la fase 6;
las comprobaciones de dominio están todas en `situacion/analisis`, que es
anterior. Vigilar el tamaño de `plan.lisp` (criterio C6).

**R3 — La jerarquía de capacidades se queda corta o se pasa.**
Demasiadas capacidades y cada backend tiene que declarar veinte cosas; demasiado
pocas y la degradación es de trazo grueso.
*Mitigación:* las once de la sección 6 salen de las columnas de la tabla 2.2, que
a su vez salen del corpus. El experimento de refutación es lo que dirá si falta o
sobra alguna, y es barato cambiarlas antes de tener backends.

**R4 — El materializador se contamina de dominio.**
La tentación de "resolver esto rápido en Python" es real, y es exactamente cómo
2026 acabó con el cálculo del lado equivocado de la frontera.
*Mitigación:* el materializador no recibe la situación, solo el plano. No tiene
acceso a nada del dominio ni aunque quisiera.

**R5 — El corpus como oráculo resulta ser más rígido de lo previsto.**
Puede haber detalles de los libros actuales —decisiones de presentación tomadas
por iteración con el usuario— que el lenguaje no deba describir y que, sin
embargo, hagan fallar la comparación de I7.
*Mitigación:* la comparación es semántica, no byte a byte, y la lista de lo que
es opción de arquitectura está declarada de antemano. Si aparece algo nuevo, se
clasifica explícitamente antes de tocar el lenguaje.

**R6 — El DSL interno obliga al cliente a escribir paréntesis.**
Para Fernando es una ventaja; para "cualquier posible cliente" es una limitación
real. *Mitigación:* se enuncia como decisión de alcance con su justificación —sin
lexer ni parser, extensibilidad por macros y CLOS, homoiconicidad— y se apunta
como trabajo futuro una sintaxis externa que compile a las mismas formas. No se
finge que es gratis.

---

## 15. Correspondencia de vocabulario

Para poder leer las tres tesis anteriores y este diseño sin perderse, y para
citar correctamente en el documento de tesis.

| Aquí | 2026 | 2025 | 2017 |
|---|---|---|---|
| `coleccion` | `table` / `def-table` | `entidad` / `def-entidad` | — |
| `campo` | `col-def` (`name` / `header`) | atributo | — |
| `rol` de campo | — | — | — |
| `derivacion` | columna calculada | — | — |
| `marca` | `style-rule` / `conditional-rendering` | — | — |
| severidad | — | — | — |
| `existe` | `exists` / `expr-exists` | — | — |
| `la-fila-de` / `el ... de` | — | el elemento *consulta* | — |
| `cuantas`, `suma` | `expr-countif`, `expr-sum` | — | — |
| `cuantas-distintas` | — | — | — |
| `las-filas-de` | — | — | — |
| `vista` | `sheet` / `region` / `nav` | `pagina` | — |
| `crecimiento` | — | — | — |
| `ambito` | `fila`, `primera-fila`, `ultima-fila` | iteraciones | — |
| `plan` | `col-map` | — | — |
| `emitir-expresion` | `compile-excel-formula` | `generate-code` | `generate-code` |
| `emitir` estructura | `generate-code` | `generate-visual-code` | `generate-code` |
| `arquitectura` | `out` / *backend* | formato de salida | lenguaje de salida |
| jerarquía de capacidades | — | — | descrita, de ADOL\* |
| `defnodo` | `defclass*` | `defclass*` | `defnode` |
| informe de conformidad | — | — | — |
| juego de pruebas de conformidad | — | — | — |

Las once filas con guion en las tres columnas son lo que no existe en ninguna
tesis anterior. Cinco salen del corpus (rol de campo, búsqueda por clave con su
valor por defecto, conteo de distintos, relación uno a muchos, crecimiento); las
otras salen de tomarse en serio la pregunta que 2026 dejó abierta (severidad,
ámbito, plan, informe y juego de conformidad, y la jerarquía de capacidades
llevada de la prosa al código).
