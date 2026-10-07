# Para entender de qué va la tesis

Documento de lectura, no de consulta. Está escrito para leerse entero y de
corrido, antes de tomar ninguna decisión técnica. Explica tres cosas:

1. Qué quiere conseguir Fernando.
2. Qué nos llevamos de cada tesis anterior, con ejemplos.
3. Qué voy a hacer, a grandes rasgos.

Si algo de aquí no se entiende, está mal escrito y hay que arreglarlo.

Fecha: 2026-09-20. Fuentes: los tres PDF de `../Tesis anteriores (contexto)/`
leídos íntegros, el repositorio `Horario` recontado hoy, y la conversación con el
tutor del 2026-09-09. Todo lo que se afirma aquí
sobre las tesis anteriores está comprobado contra el PDF; donde algo es
interpretación mía y no cita, lo digo.

---

## Ocho palabras que hacen falta

No hace falta saber Common Lisp para leer esto, pero sí estas ocho palabras.
Están aquí arriba para no tener que interrumpir la lectura más adelante.

**DSL** — *domain specific language*, lenguaje de dominio específico. Un
lenguaje pequeño que solo sabe hablar de un tema. SQL es un DSL de bases de
datos; las fórmulas de Excel son un DSL de hojas de cálculo.

**DSL interno** — un DSL que no tiene sintaxis propia: se escribe con la sintaxis
del lenguaje anfitrión. Como se escribe en Lisp, se escribe con paréntesis. La
ventaja enorme: **no hay que escribir un analizador**, porque el intérprete de
Lisp ya sabe leer paréntesis.

**Macro** — un programa que escribe programa. Le das una forma corta y la
convierte, antes de ejecutar nada, en la forma larga equivalente. En un DSL
interno, las macros son el compilador del lenguaje: son las que traducen lo que
tú escribes a las estructuras reales.

**Nodo y árbol** — cuando un programa lee una descripción, no se queda con el
texto: lo convierte en una estructura de cajitas que se contienen unas a otras.
Cada cajita es un **nodo** y el conjunto es un **árbol**. La descripción
`(+ 5 (* y 2))` se convierte en un nodo "suma" que contiene un 5 y un nodo
"multiplicación", que a su vez contiene `y` y 2. Ese árbol es lo que después se
recorre para producir la salida. En la literatura se llama AST (*abstract syntax
tree*).

**Arquitectura** — cada destino en el que se puede materializar una situación:
Excel, una página web, Emacs, SQL, un PDF. Es la palabra que usa Fernando y es
la única que voy a usar. (En las tesis anteriores esto se llama *backend* o
*lenguaje de salida*; son lo mismo.)

**Función genérica y método** — la forma que tiene Lisp de hacer que una misma
operación se comporte distinto según con qué se la llame. La **función genérica**
es el nombre y la forma de la operación: *"traducir un nodo a una arquitectura"*.
Los **métodos** son las respuestas concretas: *"traducir un nodo de suma a
Excel"*, *"traducir un nodo de suma a la web"*. Lo importante es que **los
métodos se pueden añadir desde fuera, sin tocar la función genérica ni los
métodos que ya existen**. Ahí está toda la extensibilidad de este trabajo: si la
función genérica está bien planteada, añadir Emacs es escribir métodos nuevos y
nada más.

**Protocolo** — la lista de funciones genéricas que alguien tiene que rellenar
para que su arquitectura funcione, con el contrato de cada una. Es el contrato de
extensión: lo que Fernando recibiría para poder hacer Emacs por su cuenta.

**Derivación** — un valor que no se escribe, se calcula a partir de otros. La
columna "Faltan" de una tabla es una derivación. Si se recalcula sola cuando
cambias algo, es una derivación **viva**.

---

## Parte 1 — Qué quiere conseguir Fernando

### 1.1 Lo que pasa hoy

El ciclo de los últimos meses ha sido siempre el mismo:

1. Fernando describe una situación en lenguaje natural. *"Necesito organizar las
   defensas de tesis: cada tesis tiene un tribunal, hay que colocarlas en días,
   horas y locales, y avisar si un profesor queda citado en dos sitios a la vez."*
2. Dayan escribe un programa en Python, a medida, para esa situación.
3. Sale un libro de Excel.
4. Se refina con el usuario real hasta que sirve.

Eso ha funcionado tres veces: horarios, tribunales y gestión del departamento.
Son unas 4 400 líneas de generadores, 5 800 de pruebas y 1 000 de importadores.

### 1.2 Dónde está el problema

El problema no es el Excel. El problema es que en ese programa Python están
mezcladas dos cosas que no tienen nada que ver:

- **La lógica del problema.** Quién tiene conflicto de horario. Cuántas defensas
  acumula un profesor. A qué asignatura le faltan turnos.
- **La mecánica del destino.** Que la columna del tutor es la C, que la primera
  fila de datos es la 4, que el conflicto se detecta con la cadena de texto
  `COUNTIF($D$4:$H$16,K5)`.

Un ejemplo real del repositorio, `tribunales/hoja_dia.py:40-43`:

```python
ws[f"{col}{f}"] = (
    f'=IF(${L.COL_ESTUDIANTE}{f}="","",'
    f'IFERROR(VLOOKUP(${L.COL_ESTUDIANTE}{f},TesisTribunal,{idx},FALSE),""))'
)
```

Lo que esa línea *quiere decir* son tres frases del dominio, muy simples:

> Si esta fila todavía no tiene estudiante, no muestres nada.
> Si lo tiene, trae de la tabla de tesis el profesor que ocupa este rol.
> Y si ese estudiante no aparece en la tabla de tesis, tampoco muestres nada.

(El primer caso es el `IF(...="","",...)`; el segundo es el `VLOOKUP`; el tercero
es el `IFERROR`, que atrapa el fallo cuando la búsqueda no encuentra nada.)

Lo que esa línea *dice* es Excel puro: comillas, `$`, índices de columna, el
nombre de un rango, `FALSE`. Si mañana hay que hacer lo mismo en una página web,
esa línea no sirve para nada y hay que volver a pensarlo todo desde cero, aunque
las tres frases del dominio sean exactamente las mismas.

Eso es lo que impide reutilizar el trabajo cuando cambia el destino.

### 1.3 Lo que pide Fernando

Textual, de la conversación del 2026-09-09:

> Lo interesante, para liberar tiempo [...] sería desarrollar un lenguajito en
> el que yo pueda describir «cualquier» situación más o menos parecida a esas
> que te he ido comentando, y a partir de mi descripción en ese lenguaje se
> genera «el producto» en cualquiera de las arquitecturas solicitadas. Una
> arquitectura sería excel, otra sería web, otra teléfono, otra Emacs.

Una analogía que ayuda a medias: **Markdown**. Escribes el documento una vez, en
texto plano, y de ahí sale HTML, PDF, Word, una presentación. Nadie reescribe el
documento para cada formato. Y lo más importante: cualquiera puede escribir un
exportador nuevo sin pedirle permiso al que inventó Markdown, y de golpe todos
los documentos que ya existen se pueden sacar en ese formato nuevo.

**Dónde se rompe la analogía, y conviene tenerlo claro desde el principio:** un
documento Markdown es texto muerto. No hace nada. Lo que hay que reproducir aquí
son documentos que *sí* hacen cosas — calculan, avisan, validan — y eso es
bastante más difícil. Lo explico en 1.5.

### 1.4 Las tres cosas que ya decidió y no hay que volver a preguntar

**Primera: la web y el móvil solo visualizan, no resuelven.** Dayan preguntó si
la web tendría que *resolver* la situación (repartir las defensas por sí sola) y
la respuesta fue: *"no, no... solo que la visualice... exactamente lo mismo que
estamos haciendo ahora con los excel"*.

Esto separa el trabajo de otra línea de investigación de la facultad, larga y
poblada (Portela, Travieso, Chang, Fernández Llanos, Seguí, Tomás, Quintero,
Nardo), que lleva años en la generación *automática* de horarios: dado el
conjunto de restricciones, calcular una solución válida. Aquélla es la línea de
**resolver**; ésta es la de **representar**. Queda fuera cualquier solver u
optimizador, y conviene decirlo en la tesis para que nadie confunda las dos.

**Segunda: lo interesante no es la pila de arquitecturas.** Textual: *"no vale
la pena hacer el simulacro de pedirte las páginas web ni las aplicaciones
móviles... eso es relativamente sencillo, en comparación con lo otro"*. Lo
interesante desde el punto de vista de computación es: diseñar el lenguaje,
garantizar que sea extensible, y **definir el mecanismo por el que otros
incorporen sus propias arquitecturas**.

**Tercera: se implementa como DSL interno en Common Lisp.** Textual: *"podemos
diseñar ese lenguaje que nos sirva para obtener los productos en varias
arquitecturas sin tener que hacer parser y lexer. La forma de lograrlo es usando
common lisp"*.

Esa decisión tiene un coste que hay que asumir y no disimular: **el cliente
escribe paréntesis de Lisp**. Para Fernando es ideal —usa Emacs y quiere hacer el
backend de Emacs— pero para "cualquier posible cliente" es una limitación real.
Se enuncia como decisión de alcance, con su justificación, y se deja apuntada
como trabajo futuro una sintaxis externa que compile a las mismas formas.

### 1.5 El matiz que más se subestima

Los Excel que se entregan hoy **no son fotos de una situación: son programas
pequeños y vivos**.

En el libro de tribunales, si escribes el nombre de un estudiante en una celda,
las cinco celdas de al lado se rellenan solas con su tribunal. Si dos defensas
caen a la misma hora y comparten profesor, las celdas se ponen rojas **mientras
escribes**. Si escribes un estudiante que no está en la lista, sale un aviso. Las
celdas calculadas están bloqueadas para que nadie borre una fórmula sin querer.

Un detalle de ese aviso que importa más de lo que parece: el desplegable de
estudiantes se genera con `errorStyle="information"`, es decir **avisa pero no
bloquea**. Puedes escribir lo que quieras; el libro te lo señala y sigue
adelante. Eso no es una elección de Excel: es una decisión del dominio. Hay
restricciones que invalidan y restricciones que solo advierten, y el lenguaje
tiene que saber decir cuál es cuál.

Esto significa que "hacer lo mismo en una web" no es dibujar una tabla HTML: es
reproducir ese comportamiento. Y significa que el lenguaje tiene que saber
describir cuatro cosas, no una:

| Qué | Ejemplo en el libro de tribunales |
|---|---|
| **Datos** | La lista de profesores, estudiantes, locales y tesis |
| **Derivaciones vivas** | El tribunal que se autocompleta al elegir estudiante |
| **Marcado con significado** | El rojo del conflicto de horario |
| **Entrada validada** | El desplegable de estudiantes, que avisa si escribes uno que no existe |

### 1.6 Cómo se vería eso escrito en el lenguaje

Esto todavía no existe: es una propuesta, y va a cambiar. Pero sirve para que
veas de qué estamos hablando exactamente. Es la hoja de un día del libro de
tribunales, la misma que hoy produce `tribunales/hoja_dia.py`:

```lisp
(situacion defensas-de-tesis

  ;; ---- lo que ya se sabe: no se toca ----
  (coleccion tesis
    (campo estudiante :rol fijo :clave)
    (campo tutor      :rol fijo)
    (campo oponente   :rol fijo)
    (campo presidente :rol fijo)
    (campo secretario :rol fijo)
    (campo vocal      :rol fijo :opcional))

  ;; ---- lo que se planifica a mano ----
  (coleccion citaciones
    :crece-despues-de-generar
    (campo dia     :rol fijo)
    (campo local   :rol fijo)
    (campo momento :rol fijo)

    (campo estudiante :rol entrada
                      :dominio    (los estudiante de tesis)
                      :al-violar  advertir)

    ;; el tribunal no se escribe: se trae solo
    (campo tutor :rol derivado
      (el tutor de (la-fila-de tesis
                     :donde (= estudiante (de fila estudiante)))
          :si-no ""))
    ;; ... oponente, presidente, secretario y vocal, igual
    )

  ;; ---- lo que hay que vigilar ----
  (marca profesor-citado-dos-veces
    :cuando (existe otra :en citaciones
              :distinta-de fila
              :donde (y (= (de otra dia)     (de fila dia))
                        (= (de otra momento) (de fila momento))
                        (comparten otra fila
                                   (tutor oponente presidente secretario vocal))))
    :sobre     (tutor oponente presidente secretario vocal)
    :severidad problema
    :explica   "Este profesor está citado en dos locales a la vez")

  ;; ---- cómo se presenta ----
  (vista por-dia
    :una-seccion-por dia :de citaciones
    :agrupada-por    local
    :punto-de-entrada portada))
```

Dos cosas que mirar en ese texto:

- **No aparece ni una letra de columna, ni un número de fila, ni un nombre de
  función de Excel.** Ése es el criterio de diseño, y es verificable: si en el
  lenguaje aparece `celda`, `columna B`, `rango` o `COUNTIF`, algo está mal.
- **Fernando debería poder leerlo y decir si está bien sin que se lo expliquen.**
  Si hay que explicárselo, el vocabulario está mal elegido. Ése es el criterio de
  calidad, y lo robo de la mejor idea de la tesis de 2025.

Y lo que cada arquitectura hace con la misma descripción:

| La descripción dice | Excel | Web | SQL | Emacs |
|---|---|---|---|---|
| `:rol entrada` | celda desbloqueada, pestaña azul | `<input>` | columna de tabla | el cursor entra ahí |
| `:rol derivado` | fórmula + celda bloqueada | valor computado | columna de una vista | texto de solo lectura |
| `:dominio ... :al-violar advertir` | desplegable que avisa | `<select>` con aviso | `CHECK` (que *sí* bloquea) | completado |
| `marca ... :severidad problema` | relleno rojo | color más icono | columna con el estado en texto | una *face* |
| `:crece-despues-de-generar` | filas de reserva + rango que crece | botón "añadir" | no hace falta | no hace falta |

Esa última fila es la más instructiva: **lo que en Excel cuesta una maquinaria
entera, en la web es gratis.** Ahí es donde se ve por qué hace falta un mecanismo
de capacidades y no basta con "cada quien que lo haga como pueda".

---

## Parte 2 — Qué nos llevamos de las tesis anteriores

Hay tres tesis previas en esta misma línea en la facultad. Fernando las mandó
expresamente *"para aprender de los errores anteriores"* y resumió el resultado
de las dos últimas como: **"se puede hacer, pero esto todavía no está listo para
usarse"**.

Las he leído las tres enteras. Esto es lo que hay.

Las tres comparten el mismo esqueleto —DSL interno en Lisp, árbol de nodos con
clases, generación por funciones genéricas— y las tres se diferencian en qué
dominio describen y hasta dónde llegaron.

---

### 2.1 — 2017, Yasmany Arcia Corcho: la herramienta MGA

*MGA = Multi-languages Generators Automation.*

#### Qué hizo

Una herramienta para construir lo que él llama **Generadores Multilenguajes**:
programas que definen un lenguajito y permiten sacar lo escrito en él en varios
formatos. No tiene dominio propio: es cimiento, no competencia. Su ejemplo de
juguete son operaciones aritméticas.

#### Lo que nos llevamos

**(a) La metodología de los seis pasos.** Es el esqueleto correcto y conviene
citarla como marco. Los seis, literales:

1. Determinar el dominio que se quiere representar en el DSL.
2. Identificar los elementos que se desean representar en el DSL.
3. Diseñar el lenguaje del DSL.
4. Implementar una jerarquía de clases que represente cada elemento como nodo de
   un árbol.
5. Construir el analizador lexicográfico y el sintáctico.
6. Implementar la generación de código de cada nodo, en cada lenguaje de salida.

Y observa algo que es la razón de toda la decisión de usar Lisp: **si el DSL es
interno en Common Lisp, el paso 5 desaparece** —lo hace el intérprete— **el paso
3 se reduce a elegir bien los nombres de los constructores, y los pasos 4 y 6 se
pueden automatizar con macros**. De seis pasos quedan tres, y dos de ellos
mecanizados.

**(b) La macro `defnode`.** Es un atajo para no escribir código repetido.

Sin la macro, declarar un nodo "suma" con dos operandos cuesta esto:

```lisp
(defclass sum-node ()
  ((left-hand  :accessor left-hand  :initarg :left-hand)
   (right-hand :accessor right-hand :initarg :right-hand)))

(defun sum-node (left-hand right-hand)
  (make-instance 'sum-node :left-hand left-hand :right-hand right-hand))
```

No hace falta entender esas líneas. Lo único que dicen es: *"existe un tipo de
nodo llamado suma; tiene dos huecos, uno izquierdo y otro derecho; y ésta es la
forma de fabricar uno"*. Con la macro cuesta esto:

```lisp
(defnode sum-node () (left-hand right-hand))
```

Y la macro escribe el bloque anterior por ti. Eso es todo lo que es: código que
escribe código, para que declarar un concepto nuevo del dominio cueste una línea
en vez de siete. Las tesis de 2025 y 2026 usan una macro equivalente, que ambas
llaman `defclass*`. *(Ninguna de las dos cita a Arcia, así que no puedo afirmar
que la hayan tomado de él: solo que hacen lo mismo.)*

**(c) La macro `gcode` y la función `recognize-pattern`.** La segunda mitad de su
aporte, y la que sostiene la extensibilidad.

`gcode` encapsula el patrón repetido de "escribir cómo se traduce este nodo a
este lenguaje". En vez de un método entero, una línea:

```lisp
(gcode sum-node csharp "~a+~a" left-hand right-hand)
```

que se lee: *"un nodo suma, en C#, se escribe como el izquierdo, un más, y el
derecho"*. Y `recognize-pattern` permite registrar símbolos que `gcode` sustituye
por código en todas las traducciones futuras: así es como se automatiza la
indentación de Python sin tocar ninguna regla ya escrita.

Su propia tesis es honesta sobre el límite: *"El uso de `gcode` deja de ser
factible cuando la generación del código de un nodo no cumple exactamente el
patrón anterior"*. Hay una válvula de escape: escribir el método a mano.

**(d) La idea grande: la jerarquía de lenguajes por herencia múltiple.**

Esta es la idea más valiosa de toda la línea de investigación, y es la que voy a
explotar. Va así.

La forma ingenua de soportar cinco lenguajes de salida es escribir, para cada
concepto, cinco reglas: una para C#, otra para Java, otra para Python, otra para
R, otra para Common Lisp. Son cinco veces el trabajo, y cada concepto nuevo
multiplica por cinco.

La forma buena es darse cuenta de que los lenguajes **comparten propiedades**.
Entonces, en vez de nombrar lenguajes, nombras propiedades:

- *lenguaje-con-notación-infija*: escribe `2 + 3`, no `(+ 2 3)`.
- *lenguaje-con-indentación*: los bloques se marcan con espacios.
- *lenguaje-separado-por-símbolo*: las instrucciones acaban en `;`.
- *lenguaje-con-operaciones-básicas*: usa `+`, `*`, `/`, `<`, `>`.

Y entonces declaras: **C-like = infijo + indentado + separado por símbolo +
operaciones básicas**. Y **Java hereda de C-like**. Y **C# también**. Añadir C#
no es escribir todas las reglas otra vez: es decir de qué hereda, y escribir
solo lo que C# hace distinto.

Traducido a nuestro problema, que es donde se pone interesante:

- *arquitectura-con-rejilla*: tiene filas y columnas de verdad.
- *arquitectura-con-recálculo-vivo*: recalcula sola cuando el usuario edita.
- *arquitectura-con-entrada*: el usuario puede escribir en el documento.
- *arquitectura-con-navegación*: tiene secciones y forma de saltar entre ellas.

Y entonces: **Excel = rejilla + recálculo vivo + entrada + navegación**. **Web =
recálculo vivo + entrada + navegación, pero sin rejilla**. De ahí sale **casi
gratis** lo que Fernando pide: un mecanismo por el que otro declare su
arquitectura, diga qué sabe hacer, y el sistema sepa qué puede pedirle y qué no.
Y sale con genealogía dentro de la propia facultad, que es un buen argumento
ante el tribunal.

#### Dos precisiones de atribución, importantes para la defensa

**La idea no es de Arcia.** Su tesis la atribuye expresamente a **ADOL\* y
GEMURAL**, dos trabajos anteriores de la facultad. La frase literal es: *"Un
subconjunto de las propiedades sintácticas de los lenguajes se representa **en
ADOL\*** con las siguientes clases..."*. Hay que citarla como de ADOL\*. Si en
la defensa se cita mal, es un regalo para el tribunal.

**Y no muestra el código de la composición.** En toda la tesis no aparece ni una
clase de lenguaje con varias superclases: ni `C-like`, ni `Infix-Language`, ni
`Basic-Operation-Language`. Están en prosa y en una figura. Lo que sí implementa
es **una** de esas propiedades por separado, la indentación:
`(defnode indentable-language () (indentation indent-increment))`, más la macro
`mark-node-as-indentable` y un método auxiliar. Es decir: enseña cómo automatizar
una propiedad, no cómo componerlas por herencia múltiple. **Esa composición está
sin demostrar en toda la línea, y es una de las cosas que vamos a demostrar.**

---

### 2.2 — 2025, Ricardo Cápiro Colomar: LDMAG

*LDMAG = Lenguaje para el Diseño de Microaplicaciones de Gestión.*

#### Qué hizo

Un lenguaje para describir **microaplicaciones de gestión**: aplicaciones cuyos
datos caben en pocas tablas. Exporta a tres sitios: consola de Python, web con
Django, y MySQL. Se apoya en cinco procesos de ejemplo; tres son de la facultad
(alumnos ayudantes, defensas de tesis, asignación de docencia) y dos son de
ámbito general (efemérides y notas de libros).

#### Lo que nos llevamos

**(a) El elemento consulta.** Fernando lo señaló como el mérito principal del
trabajo: *"el mayor mérito de esta tesis fue darnos cuenta de que íbamos a
necesitar el «elemento» consulta... que fue lo que más trabajo nos costó
hacer"*.

Qué significa, en llano: **un documento de gestión no es un volcado de datos.
Son los datos más las preguntas sobre esos datos.** "¿Cuántas defensas tiene
asignado este profesor?" no es algo que se consulte aparte: es parte del
documento, tan parte como la lista de defensas. Si el lenguaje solo sabe
describir la lista, describe medio documento.

**(b) La macro `def-entidad`, y por qué importa más de lo que parece.**

Escribes esto:

```lisp
(def-entidad defensa (estudiante tutor oponente))
```

Y la macro genera automáticamente funciones para llegar a cada campo. Pero no
genera una por campo: genera **dos**, y ahí está la gracia:

```lisp
(estudiante-del-defensa  d)
(estudiante-de-la-defensa d)
```

Genera las dos variantes gramaticales para que el lenguaje **se lea como
español**. Y además sabe pluralizar el nombre de la entidad él solo.

*(Nota: como "defensa" es femenino, la primera de las dos formas —"del defensa"—
está mal escrita. La macro genera las dos a ciegas, sin saber el género. Es un
descuido, pero el propósito está bien visto y es lo que heredo: la forma correcta
existe y es la que se usa.)*

Esto parece un capricho cosmético y no lo es. Es lo que decide si Fernando puede
leer una descripción y decir si está bien **sin que se la expliquen**. Si hay que
explicársela, el lenguaje está mal. Ése es el criterio de calidad que heredo, y
es el mismo que apliqué al ejemplo de 1.6.

**(c) Sinónimos de constructor.** El mismo concepto se puede escribir de varias
formas: `se-cumple-simultaneamente` y `al-mismo-tiempo` construyen lo mismo. En
un DSL interno es gratis y mejora mucho la lectura.

#### Lo que NO nos llevamos, y la lección

**El modelo visual no tiene tabla.** Sus elementos visuales son `pagina`,
`titulo`, `texto`, `lista`, `item`, `input`. No hay tabla. Para un lenguaje de
microaplicaciones de gestión cuyos cinco ejemplos del capítulo 2 **son todos
tablas**, eso no es un olvido: es un hueco estructural.

**El lenguaje no puede expresar sus propios ejemplos.** Esto es lo más
instructivo de todo el trabajo. Su capítulo 2 plantea, literalmente, estas
preguntas como objetivo:

> ¿Cuántos alumnos ayudantes tiene asignados un profesor determinado?

> ¿Cuántas defensas tiene asignado un profesor como miembro del tribunal?

Y el lenguaje del capítulo 3 tiene exactamente estos operadores: igual, distinto,
y, o, no, e iteración sobre entidades. **No hay contar. No hay sumar. No hay
agrupar.** (A eso último se le llama *agregación*: producir un solo valor a
partir de muchas filas. Es justo lo que falta.) Ninguna de las dos preguntas se
puede escribir. El requisito está en el capítulo 2, el lenguaje del capítulo 3 no
lo cumple, y nadie lo señala en el documento.

**El nudo central quedó sin atar.** El trabajo identifica tres componentes —
datos, consultas, vistas — y nunca conecta los dos últimos. Las páginas de
resultados están así en la tesis (cito la página entera, sin quitar nada):

```lisp
(page mostrar-estudiantes
    (title "Listado de estudiantes y sus grupos")
    (text "A continuación se muestran todos los estudiantes junto a
           su grupo.")
    (lista
        ;; Aquí se mostraría el resultado de la consulta
        ;; mostrar-estudiantes
        ))
```

No existe ninguna forma en el lenguaje de decir *"esta lista se llena con el
resultado de esta consulta"*.

**Y no hay capítulo de validación.** El índice va del capítulo 5 directo a
Conclusiones. Las conclusiones afirman *"se comprobó su utilidad práctica
mediante la generación automática de aplicaciones en distintos formatos"* sin
presentar ninguna comprobación: ni un caso completo, ni una captura, ni una
métrica. Sus propias recomendaciones piden *"realizar una validación práctica del
lenguaje"*.

**La lección, que es la que más me condiciona:** el lenguaje se diseñó contra
ejemplos escritos en prosa, no contra artefactos reales. Sin un caso real
completo que obligue a cerrar cada cabo, el diseño se detiene justo antes de la
parte difícil. El antídoto que tenemos y ellos no tuvieron: **los tres libros del
repositorio `Horario`, en uso, como banco de pruebas desde el primer día.**

---

### 2.3 — 2026, José Ernesto Morales Lazo: el DSL tabular

Es el antecesor directo y, con diferencia, el más sólido de los tres. Conviene
decirlo claramente antes de criticarlo, porque es cierto y porque da credibilidad
a la crítica.

#### Qué hizo

Una taxonomía de conceptos del dominio tabular, un árbol de nodos con clases de
Lisp, tres casos de uso reales (horario docente, parrilla de televisión, defensas
de tesis) y una arquitectura de salida: Excel.

**Cómo está montado, que hace falta para entender lo que viene después.** Son dos
fases: un generador en Lisp recorre el árbol y **escribe un archivo JSON**; un
módulo en Python (`hoja_con_formulas.py`) lee ese JSON y llama a openpyxl para
fabricar el `.xlsx`. Retén el JSON: es donde está el problema.

#### Lo que nos llevamos

**(a) La taxonomía del dominio.** Tabla, plantilla, fila, columna, celda, columna
calculada, referencia cruzada, parámetro, regla de marcado, cuantificador
existencial, hoja, libro. Es un buen punto de partida: se hereda y se amplía, no
se reinventa.

*(Un detalle de rigor: las conclusiones dicen "17 conceptos", pero en el capítulo
3 hay 13 definiciones numeradas y 4 descritos en prosa. Si citamos el número, hay
que decir cómo se cuenta.)*

**(b) El cuantificador existencial. Esto es lo mejor de las tres tesis.**

La regla vive sobre una tabla de profesores, y lo que quiere decir es: *"marca a
este profesor si está citado en dos defensas a la vez"*. Escrito en Excel es
esto (la propia tesis lo abrevia con puntos suspensivos):

```
SUMPRODUCT( (($D$4:$D$16=$K5)+...+($H$4:$H$16=$K5))
          * ((COUNTIFS($G$4:$G$16,$G$4:$G$16,
                       $H$4:$H$16,$H$4:$H$16,
                       $D$4:$D$16,$K5) + ...) > 1) ) > 0
```

Y escrito en su lenguaje es esto:

```lisp
(def-table profesores-table
  ((nombre "") (defensas ""))
  :render
    (conditional-rendering
      :condition
        (exists (r :rows-of defensas-table)
          :self-in  (tutor presidente secretario vocal oponente)
          :matching (dia hora))
      :target-columns (nombre)))
```

La parte de `exists` se lee: *"existe una fila de la tabla de defensas en la que
el nombre de esta fila —la del profesor— aparece en alguno de esos cinco roles, y
que coincide en día y hora con otra"*. **Y no menciona Excel por ningún lado.**
Así es como debería verse todo el lenguaje. Ése es el listón.

*(La tesis tiene dos variantes del cuantificador: ésta, que mira otra tabla, y
otra que mira la misma tabla y genera una fórmula distinta.)*

**(c) La plantilla instanciable.** Declaras la estructura una vez y la instancias
con datos distintos: una hoja por grupo, una tabla por día. Es lo que evita
repetir diecisiete veces la misma declaración.

**(d) Separar el identificador interno de la etiqueta visual.** La columna se
llama `tutor` por dentro y muestra `"Tutor"` por fuera. Correcto y necesario.

#### Lo que hay que rehacer, y por qué

Aquí está el argumento que justifica que ésta sea una tesis nueva y no una
continuación. Primero la analogía, después el código real.

**La analogía.** Imagina una oficina de paquetería que anuncia que envía a
cualquier país. Tiene dos ventanillas:

- Por la **ventanilla 1** entran los datos del bulto: peso, tamaño, frágil o no.
  Esa ventanilla sirve para cualquier destino, y para añadir Japón basta con dar
  de alta Japón.
- Por la **ventanilla 2** entra la dirección, que es lo que decide de verdad a
  dónde llega el paquete. Pero ese formulario tiene tres casillas fijas:
  *"Estado"*, *"condado"* y *"ZIP de cinco cifras"*.

Una dirección japonesa no cabe ahí. Y el problema no es que nadie haya dado de
alta Japón: es que **el formulario solo tiene casillas norteamericanas**. Para
añadir Japón hay que rediseñar el formulario, y al hacerlo se invalidan todas las
etiquetas ya impresas.

**El código real.** La tesis define dos operaciones de traducción. Ésta es la de
la estructura (libros, hojas, tablas):

```lisp
(defgeneric generate-code (nodo lang stream))
```

Recuerda del glosario: una *función genérica* es el nombre y la forma de una
operación, y los *métodos* son las respuestas concretas que se le añaden desde
fuera. Aquí `nodo` es qué se traduce, `stream` es dónde se escribe, y **`lang` es
a qué arquitectura**. Ese `lang` es lo que permite tener varias: cada arquitectura
nueva añade sus métodos y nadie toca nada.

Y ésta es la de las expresiones, que es donde está toda la sustancia del lenguaje
—columnas calculadas, comparaciones, conteos, el cuantificador existencial:

```lisp
(defgeneric compile-excel-formula
    (nodo col-map data-names fila primera-fila ultima-fila))
```

Dos cosas, las dos graves:

1. **No recibe `lang`.** No hay a dónde enganchar una segunda arquitectura: la
   operación se llama "compilar fórmula de Excel" y solo puede haber una.
2. **Sus parámetros son de hoja de cálculo.** `col-map` es un diccionario de
   símbolo de columna a **letra de Excel**; `fila`, `primera-fila` y `ultima-fila`
   son números de fila. **El punto de extensión está formulado en términos de
   Excel.** Una web no tiene letras de columna ni números de fila.

Esa segunda es la ventanilla 2 con las casillas de ZIP.

La tesis afirma, sobre su arquitectura de generación, que añadir otra salida sería
*"definiendo una nueva clase y nuevos métodos especializados en ella, sin
modificar los existentes"*. Para la estructura, es cierto. Para las expresiones,
no: habría que cambiar la forma de esa función, y eso obliga a tocar todo lo ya
escrito. Es exactamente lo que la arquitectura prometía evitar.

Eso convierte el diagnóstico de la tesis —que la independencia de arquitectura se
afirmó pero no se puso a prueba— en algo más fuerte: **está demostrablemente mal
puesta**. Y ésa es una base mucho más firme para justificar el trabajo nuevo.

**Y hay más.** Comprobado leyendo el PDF entero:

- **El árbol no tiene jerarquía.** Todas sus clases declaran superclases vacías.
  No hay clase base común. La idea de ADOL\* —la herencia múltiple que hace
  barato añadir destinos— no se usa en absoluto, ni para los nodos ni para las
  arquitecturas.
- **La clase que supuestamente identifica la arquitectura nunca se define.** Se
  describe en prosa y se instancia una vez, y ya.
- **Hay un solo método concreto en toda la tesis**, y es precisamente el de
  buscar la letra de columna en el diccionario y pegarle el número de fila.
- **El JSON de traspaso ya es Excel.** Lo que el generador Lisp entrega a Python
  no es una descripción del cálculo: es el cálculo ya compilado, con rangos
  absolutos y sintaxis de fórmula. Y sin embargo la tesis afirma que *"si se
  quisiera generar tablas HTML en lugar de hojas de cálculo, bastaría escribir un
  nuevo módulo que leyera el mismo JSON"*. Eso es cierto para los encabezados y
  falso para todo lo que tiene cálculo o marcado, que es lo único interesante.

**El color que se perdió por el camino.** La tesis define que una regla de
marcado tiene dos partes: la condición y **un color de fondo**. Pero el nodo del
árbol no tiene color, y el macro tampoco. En el caso real del horario, las tres
reglas se distinguen solo por comentarios:

```lisp
(conditional-rendering :condition (gt (col asignadas) (col frec))
                       :target-columns (asig))    ; excedida -> naranja
(conditional-rendering :condition (equals (col asignadas) (col frec))
                       :target-columns (asig))    ; exacta   -> verde
(conditional-rendering :condition (lt (col asignadas) (col frec))
                       :target-columns (asig))    ; falta    -> rojo
```

El color solo aparece más abajo, dentro del JSON que produce el generador
(`"style": {"font_color": "#FF0000"}`), y la tesis **no documenta en ningún sitio
de dónde sale ese color ni cómo se asocia a cada regla**.

Y aquí viene el dato que más me gustó encontrar: **la propia captura de
validación de la tesis enseña el fallo ocurriendo.** En su figura 6.2 la
asignación de colores está corrida entera:

- La fila `AM I` (`Frec 2`, `Asignadas 3`, `Faltan −1`) sale **roja**, cuando la
  regla roja es `asignadas < frec`, que con 3 y 2 es falsa. Debería ser naranja.
- Las filas `ICD` y `F` (`Frec 2`, `Asignadas 1`, `Faltan 1`), que sí cumplen la
  regla roja, salen **azules** — un color que no aparece en ninguna de las tres
  reglas.
- Solo el verde cae donde debe.

Es decir: los colores parecen aplicarse **en el orden de las reglas** (primera →
rojo, segunda → verde, tercera → azul), no según el significado que los
comentarios les atribuyen. *Esto último es lectura mía de la imagen, no una
afirmación de la tesis, y hay que confirmarlo contra el código antes de citarlo.*

Y eso sugiere el diseño correcto, que es mejor que el de 2026 y mejor incluso que
el de nuestros libros actuales: **la regla no declara un color, declara un
significado.**

```lisp
(marca :cuando (< (col asignadas) (col frecuencia))
       :estado insuficiente)
```

Y que cada arquitectura decida cómo se ve: en Excel un relleno, en web un color
más un icono, en Emacs una *face* (que es como Emacs llama a un estilo de texto),
en una impresión en blanco y negro **tiene que ser texto o no se ve nada**. El
color no sobrevive al cambio de arquitectura; el significado sí.

Y esto ya está latente en nuestro propio corpus: la hoja de cobertura del
departamento no pinta el estado, lo **escribe**, y encima con concordancia de
plural — "Falta 1 profesor" frente a "Faltan 3 profesores". Es exactamente el
mismo estado, degradado a texto porque ahí el color no alcanzaba.

#### La pregunta que dejó abierta

La pregunta científica de 2026 era, textual:

> ¿Es posible, mediante el diseño de un lenguaje de dominio específico, separar
> la descripción semántica de una estructura tabular del mecanismo concreto de su
> generación, de modo que el mismo programa declarativo permanezca válido con
> independencia del backend de salida?

Se implementó **una** arquitectura. El experimento que respondería esa pregunta no
se ejecutó nunca. Y por lo que acabo de describir, de haberse ejecutado la
respuesta habría sido que no.

Eso no desmerece el trabajo. Es un buen trabajo que dejó abierta exactamente la
pregunta que ahora hay que cerrar. Y sus propias recomendaciones piden
arquitecturas de HTML y SQL: hay continuidad explícita, no ruptura.

---

### 2.4 — Resumen de la Parte 2

| De dónde | Qué nos llevamos | Qué dejamos |
|---|---|---|
| ADOL\*, vía 2017 | **La jerarquía por herencia múltiple**, que será el mecanismo de capacidades — pero sin código que copiar: está por demostrar | — |
| 2017 | Los 6 pasos; `defnode`; `gcode` y `recognize-pattern` para las reglas transversales | Nada; es cimiento |
| 2025 | **El elemento consulta**; `def-entidad` y su lectura en español; los sinónimos | El modelo visual, que no tiene tabla |
| 2026 | La taxonomía; **el cuantificador existencial**; la plantilla instanciable; identificador interno frente a etiqueta visual | Los nodos de colocación en rejilla (`region`, `nav`, `anchor`, alto y ancho de celda); `counta`, que cuenta "celdas no vacías" y eso es noción de hoja de cálculo, no del dominio — en el dominio la pregunta es cuántas filas hay; la regla sin color; **y sobre todo `compile-excel-formula`** |
| **El corpus propio** | **Cinco construcciones que ninguna tesis tiene**: búsqueda por clave, entrada validada, rol de campo, capacidad de crecimiento y navegación. Más dos que encontré esta semana: relación uno a muchos y conteo de distintos | — |

Esa última fila es la ventaja principal de este trabajo y conviene no perderla de
vista: las tres tesis anteriores diseñaron su lenguaje contra ejemplos escritos
en prosa. Nosotros tenemos **tres documentos reales, en uso, refinados por
iteración con el usuario final**, y de ahí sale vocabulario que nadie había visto.

Y una observación que conviene poner en la introducción de la tesis: **2025 tiene
consultas sin tablas ni agregación; 2026 tiene tablas y agregación sin consultas.
Cada una tiene la mitad de lo que hace falta, y nadie las juntó.**

### 2.5 — En qué me aparto del dossier

El dossier es el análisis largo, escrito el 2026-09-09 (un documento de
trabajo que no se publica). Leyendo los PDF
enteros esta semana encontré cuatro cosas en las que hay que corregirlo. Las
anoto aquí para que, si lees los dos documentos, sepas a qué atenerte:

1. **La jerarquía por herencia múltiple.** El dossier la llama "la joya olvidada"
   de la tesis de 2017. Es una joya, pero de ADOL\*: Arcia la atribuye y no la
   implementa.
2. **Los 17 conceptos de 2026.** El dossier los da por buenos. Son 13 numerados y
   4 en prosa.
3. **"Ninguna tesis presenta evidencia de que sus fórmulas se evalúen."** Es
   demasiado fuerte. 2026 sí afirma en conclusiones que los `.xlsx` *"se evalúan
   correctamente en Excel y LibreOffice Calc"* y lo respalda con capturas de
   valores ya calculados. Lo que no hay en ninguna de las tres es **verificación
   reproducible y automatizada**: un procedimiento que cualquiera pueda volver a
   ejecutar y que falle solo si algo se rompe. Eso sí lo tenemos nosotros.
4. **Los conteos de funciones de Excel del corpus.** Los del dossier mezclan
   generadores con pruebas y cuentan por subcadena (el `IF(` de `COUNTIF(`
   contaba como un `IF`). Recontado hoy solo sobre los generadores: `IF` 45,
   `COUNTIF` 13, `VLOOKUP` 11, `IFERROR` 9, `DataValidation` 9, `DefinedName` 24.
   Si van a la tesis, hay que declarar el método de conteo.

---

## Parte 3 — Qué voy a hacer, a grandes rasgos

### 3.1 La pregunta que hay que responder

La de 2026 tenía una mitad. Ésta tiene dos, y las dos se pueden refutar:

> ¿Es posible definir una representación intermedia de las situaciones tabulares
> que sea independiente del sistema que las materializa, **y un protocolo que
> permita a un tercero incorporar una arquitectura de salida nueva sin modificar
> el núcleo del lenguaje**?

La primera mitad es la de 2026, ahora con más de una arquitectura para ponerla a
prueba. La segunda es lo que Fernando señaló como lo interesante, y no la ha
planteado nadie.

### 3.2 Qué significa "ser una arquitectura válida"

Ninguna de las tres tesis define esto, y es justo lo que hace falta para que
"cualquier arquitectura" signifique algo preciso en vez de ser un deseo.

Excel tiene un modelo de evaluación muy concreto: cada celda es una expresión
sobre otras celdas; un motor de dependencias las recalcula cuando algo cambia; y
una sola fórmula con referencias relativas se aplica a todas las filas de un
rango, ajustándose fila a fila. **Las tres tesis se apoyaron en ese
comportamiento sin declararlo, y por eso se les fue metiendo Excel en el árbol
sin darse cuenta.**

Si el modelo se declara arriba —**valores con nombre, valores derivados,
recálculo ante cambios**— entonces se puede clasificar honestamente qué cumple
cada destino:

| Arquitectura | Rejilla | Recálculo | Entrada | Dominio de entrada | Navegación |
|---|---|---|---|---|---|
| Excel / Calc | sí | vivo (motor de dependencias) | sí | sí, y avisa | pestañas y enlaces |
| Web | no | vivo (reactividad) | sí | sí (`<select>`) | rutas |
| Emacs (`org-table`) | sí | bajo demanda (al recalcular) | sí | sí (completado) | buffers |
| SQL | no | al consultar (vistas) | parcial | parcial (`CHECK`, clave foránea) | no |
| PDF / HTML estático | no | **congelado** | **no** | **no** | enlaces |

Esa tabla, bien construida y defendida, es una contribución teórica del trabajo.
Y de ella sale directamente el mecanismo de degradación que ninguna de las tres
tiene.

**Una decisión que resuelvo aquí y que el dossier dejaba abierta.** El dossier
pregunta si las derivaciones deben ser vivas (se recalculan al editar) o
congeladas (se calculan al generar), y recomienda vivas. Mi propuesta es no
elegir: **el lenguaje siempre describe derivaciones vivas, y el nivel de
recálculo es una capacidad que cada arquitectura declara.** Así el PDF no es un
caso que el diseño no contempla, sino una degradación declarada honestamente.
Es estrictamente mejor que elegir una de las dos, pero hay que confirmarlo con
Fernando porque es su decisión.

### 3.3 Las capas

```
  descripción escrita por Fernando
        |
  [ NÚCLEO ]  las macros construyen un modelo de la situación
        |     (no sabe que existe Excel, ni web, ni nada)
        |
  === PROTOCOLO ===  <- el punto de extensión: la lista de funciones
        |               genéricas que hay que rellenar
   +----+-----+------+------+
 Excel  web   SQL   Emacs      <- cada uno añade sus métodos
```

Todo lo que está por encima del protocolo es el problema. Todo lo que está por
debajo es el destino. Ninguna coordenada, ninguna letra de columna y ningún
nombre de función de Excel cruzan esa línea hacia arriba.

### 3.4 Las decisiones de diseño, en llano

**Una. El contrato de extensión no pide coordenadas: pide una maleta que el
núcleo transporta y no abre.**

Éste es el arreglo directo del error de 2026 (la ventanilla 2 con las casillas de
ZIP). En vez de que el protocolo pida *"el mapa de columna a letra, el número de
fila, la primera fila y la última"*, pide un **contexto**: un objeto que el
propio backend fabrica, llena y abre, y que el núcleo se limita a llevar de una
función a otra sin mirar dentro. El de Excel guarda ahí sus letras y sus filas;
el de web guarda los nombres de sus variables de JavaScript; el de Emacs guarda
lo que necesite.

Y cada función del protocolo recibe la arquitectura como parámetro, que es
exactamente lo que le falta a `compile-excel-formula`. Así, añadir una
arquitectura nueva es de verdad lo que 2026 prometía y no cumplía: una clase
nueva y unos métodos nuevos, sin tocar una línea de lo existente.

**Dos. Cada arquitectura declara lo que sabe hacer, y el sistema lo respeta.**

Es la idea de ADOL\* (la de 2.1(d): componer por propiedades en vez de enumerar
destinos) aplicada al cuadro de 3.2. Excel tiene rejilla; la web no. La web hace
listas de largo variable sin esfuerzo; Excel necesita inventarse filas de
reserva. SQL cuenta valores distintos con una palabra; Excel necesita una columna
auxiliar de apoyo.

En vez de fingir que todas pueden todo, cada una **declara** lo que cumple. Y
cuando la descripción pide algo que una arquitectura no tiene, esa arquitectura
—no el núcleo, y no el usuario— decide cuál de estas cuatro respuestas da:

| | Cuándo se usa | Ejemplo |
|---|---|---|
| **cumple** | Lo hace de forma nativa | Web mostrando una lista de largo variable |
| **emula** | No lo tiene, pero puede fabricarlo. Declara a qué coste | Excel: hoja auxiliar, filas reservadas y aviso "(+3 más)" cuando se desbordan |
| **degrada** | Hay una versión más pobre que sigue sirviendo para lo mismo | SQL sin colores: saca una columna con el nombre del estado en texto |
| **rechaza** | No hay versión honesta, y fingirla sería mentir | Un PDF al que se le pide entrada validada: no hay dónde escribir |

La diferencia entre *degrada* y *rechaza* es la clave: se degrada cuando el
resultado sigue cumpliendo el propósito de otra manera; se rechaza cuando el
resultado parecería correcto y no lo sería.

Y al compilar sale un **informe de conformidad**: para cada cosa que pedía la
descripción, cuál de las cuatro pasó y por qué. Ese informe es la prueba de que
el mecanismo funciona, y es justo lo que 2026 no tenía.

**Tres. Nunca hay "la fila de arriba".**

Éste es el problema técnico más profundo del trabajo, y quiero atacarlo desde el
diseño. Excel tiene una trampa: escribes `J4>=$B$1` una vez y el motor evalúa
`J5>=$B$1` en la fila siguiente, ajustando las referencias solo. HTML, elisp y
SQL no tienen ese modelo: ahí hay que escribir el bucle, o no existe la noción de
"fila anterior".

Así que la regla será: **la iteración es siempre explícita**. No existe "la celda
de arriba". Se puede hablar de la fila anterior **solo si la colección declara
por qué campo está ordenada**, y entonces "anterior" significa lo mismo en los
cuatro destinos: en SQL es una función de ventana (una operación que mira las
filas vecinas dentro de un orden), en JavaScript es el índice anterior del
arreglo ordenado, en Excel es una referencia relativa.

**Cuatro. El Excel se compila entero en Lisp; solo escribir el archivo se
delega.**

Comprobado esta semana: no existe ninguna librería de Common Lisp capaz de
*escribir* xlsx con fórmulas, formato condicional, validación de datos, rangos
nombrados y protección de celdas. Escribir ese emisor desde cero son semanas de
trabajo que no aportan nada a la tesis.

Así que la arquitectura de Excel hace **todo** el trabajo semántico en Lisp y
entrega un plano puramente mecánico —celdas, fórmulas ya hechas, estilos— a un
programita Python que solo llama a openpyxl y reutiliza el código de `comun/` que
ya está probado contra el usuario real.

Por fuera se parece a lo que hacía 2026, así que hay que decir con precisión por
qué no es lo mismo, porque el tribunal lo va a preguntar. En 2026, **el JSON con
fórmulas de Excel *era* el punto de extensión**: era el sitio por donde,
supuestamente, iba a entrar HTML. Aquí el plano vive **dentro** de la
arquitectura de Excel, por debajo del punto de extensión; ningún otro destino lo
ve, y el núcleo no lo ve nunca. Web, SQL y Emacs no necesitan ningún
intermediario: emiten texto directamente. Es decir, solo Excel necesita ayuda, y
la necesita porque xlsx es un contenedor binario comprimido — un hecho mecánico,
no semántico.

**Cinco. La arquitectura se comprueba sola.**

Las afirmaciones del tipo "el núcleo es independiente de la arquitectura" son las
que se caen en las defensas. Así que se convierten en pruebas automáticas:

- Ninguna palabra de hoja de cálculo puede aparecer en el núcleo ni en el
  protocolo. Una prueba las busca en el código fuente y falla si aparecen.
- Toda función del protocolo tiene que recibir la arquitectura como parámetro.
  Una prueba las recorre y lo verifica. **Eso es exactamente el fallo de 2026,
  detectado automáticamente.**
- El código se organiza en módulos que declaran de quién dependen. Se declara que
  las arquitecturas dependen del protocolo y **no** del lenguaje, de modo que un
  backend no puede ni ver las macros: si alguien intenta usarlas, el programa no
  compila. La independencia deja de ser una promesa y pasa a ser algo que la
  herramienta impide violar.

### 3.5 Cómo sabremos que funciona

Tres cosas, en orden de dureza:

1. **Contra el corpus.** El criterio no es "sale un `.xlsx`", sino **"el `.xlsx`
   generado desde la descripción es equivalente al que hoy produce el código
   Python"**. Los tres libros y sus 5 800 líneas de pruebas son el juez.
2. **Que las fórmulas se evalúen de verdad, y que se pueda volver a comprobar.**
   Se genera el libro, se rellena como lo haría un usuario, se pasa por
   LibreOffice en modo headless y se releen los valores calculados. Ya está
   resuelto en este proyecto y cazó tres fallos que las pruebas daban por buenos.
   2026 afirma que sus fórmulas se evalúan y lo respalda con capturas; **lo que
   no hay en ninguna de las tres tesis es un procedimiento reproducible que
   cualquiera pueda volver a ejecutar.**
3. **La prueba de verdad: que Fernando implemente la arquitectura de Emacs él
   solo**, con el protocolo y un juego de pruebas de conformidad en la mano, sin
   ayuda y sin tocar el núcleo. Esto tiene una propiedad poco común: **los dos
   resultados son publicables.** Si lo logra, el mecanismo funciona. Si no lo
   logra, el trabajo documenta por qué, que es un resultado igual de valioso y
   mucho más honesto que afirmar la extensibilidad sin probarla, que es lo que se
   hizo tres veces seguidas.

*(Dos nombres parecidos que conviene no confundir: el **informe de conformidad**
sale cada vez que compilas y dice qué se cumplió, se emuló, se degradó o se
rechazó. El **juego de pruebas de conformidad** es un conjunto de descripciones
con sus resultados esperados, que una arquitectura nueva tiene que pasar para
declararse conforme. Lo primero es un diagnóstico; lo segundo es un examen.)*

### 3.6 Por dónde empiezo

No por el compilador. Lo que puede matar la tesis es (a) que el tribunal no vea
la diferencia con 2026 y (b) repetir el error de 2026, que fue diseñar una
representación "independiente de la arquitectura" teniendo una sola arquitectura
delante. Ninguna de las dos se arregla escribiendo macros.

Así que el primer paso, y el de más valor por esfuerzo, es un **experimento de
refutación**: coger un caso pequeño y real —la hoja de un día del libro de
tribunales, que ya tiene las tres cosas interesantes— y **escribir a mano, sin
generador de por medio, dos materializaciones**: el `.xlsx` que ya existe, y una
página web con el mismo comportamiento vivo (al elegir estudiante se rellena el
tribunal; si dos defensas comparten profesor a la misma hora se marcan). Y una
tercera en papel: cómo sería en Emacs.

No se genera nada. Se escriben a mano y se comparan.

**Para qué sirve:** lo que el lenguaje debe expresar es exactamente **la
intersección** de esas tres cosas; lo que las tres hacen de forma distinta es
exactamente lo que debe quedar del lado de la arquitectura. Esa frontera es la
que 2026 puso mal, y no se puede adivinar en el escritorio: se descubre haciendo
dos veces la misma cosa de dos maneras. La lista de lo que *no* se pudo hacer
igual es la semilla del mecanismo de degradación.

Y ahí va a aparecer solo, sin buscarlo, el problema de la fila actual (3.4, punto
tres), que es el más difícil del trabajo. Mejor que aparezca en un experimento de
dos días que en abril con el compilador entero encima.

### 3.7 Lo que NO voy a hacer, dicho por adelantado

El riesgo más común de un trabajo así es que el lenguaje crezca sin control: cada
concepto nuevo multiplica el trabajo por el número de arquitecturas, y no se
termina ninguna. Así que queda fuera del lenguaje, por escrito y de antemano:

- Anchos de columna, altos de fila, congelado de paneles, colores de pestaña,
  configuración de impresión, autofiltro, colocación absoluta de bloques. Todo
  eso son **opciones de arquitectura**, declaradas aparte.
- Los colores concretos. El lenguaje dice `insuficiente`; una **paleta**, que es
  opción de arquitectura, dice de qué color se pinta eso en Excel.
- **Los mecanismos, no las intenciones.** Esta distinción es fina y conviene
  fijarla bien, porque es fácil pasarse de frenada:
  - *"Esta lista crece después de generar"* **sí** está en el lenguaje: es un
    hecho del dominio, y es lo que nos dice que el documento sigue vivo.
  - *"Reserva veinte filas en blanco y define un rango con `OFFSET` y `COUNTA`"*
    **no**: eso es lo que Excel se inventa para cumplir la intención anterior. La
    web, para la misma intención, pone un botón.
  - Lo mismo con la navegación: *"el documento tiene secciones y un punto de
    entrada"* **sí**; el nodo `nav` de 2026, que coloca un elemento contando
    filas desde el final de una columna, **no**.
  - Y lo mismo con las hojas auxiliares y las columnas de apoyo: **se las inventa
    la arquitectura**. El lenguaje no las nombra jamás.
- El móvil. Hace exactamente lo mismo que la web con otra pantalla, así que
  implementarlo cuesta trabajo y no enseña nada nuevo sobre el problema que la
  tesis investiga. Se omite **por redundancia**, y eso se dice en el documento:
  omitir por redundancia es defendible, omitir por falta de tiempo no lo es.
- Cualquier solver u optimizador (1.4).

---

## Qué falta por decidir

Nada de esto lo decido yo:

1. **Cómo se llama el lenguaje.** No hay nombre todavía.
2. **Si las derivaciones son vivas, congeladas, o una capacidad declarada** como
   propongo en 3.2. Mi propuesta es la tercera, pero la decisión es de Fernando.
3. **Qué arquitecturas hace Dayan y cuál queda para Fernando.** La propuesta
   razonada es: Excel y web por Dayan, SQL como arquitectura barata que ilustra
   la degradación, Emacs por Fernando.
4. **Si el alcance incluye la entrada o solo la visualización.** Fernando dijo
   "solo que la visualice", pero los libros que ya se entregan son instrumentos
   de captura: tienen desplegables, validación y celdas protegidas. Mi lectura es
   que **"hacer lo mismo que hacemos ahora con los Excel" ya incluye la entrada**,
   y que sin ella el lenguaje no puede describir ni uno solo de los tres libros
   existentes, con lo que se perdería el banco de pruebas que es nuestra mayor
   ventaja. Conviene plantearlo en esos términos, no como ampliación de alcance.

## Dos preguntas que el tribunal va a hacer, y hay que traer preparadas

**"¿Por qué no Xtext, EMF, JHipster, Airtable?"** Son herramientas de ingeniería
dirigida por modelos y de low-code, con generación a varios destinos. No
citarlas se lee como desconocimiento del campo. Las diferencias defendibles: un
DSL interno no necesita metamodelo, gramática ni tooling —añadir un concepto es
una macro, no una regeneración—; el dominio aquí no es CRUD sino la situación
tabular con derivaciones vivas; y el mecanismo de extensión por terceros, con
protocolo publicado y juego de pruebas, es lo genuinamente nuevo.

**"¿Por qué un DSL y no un modelo de lenguaje?"** Es la pregunta con más filo,
porque el flujo que describe Fernando —"te mando la situación y me das el Excel"—
es literalmente lo que ya está ocurriendo. Los argumentos: la misma descripción
produce siempre el mismo producto y un modelo no; la descripción es un artefacto
que se versiona, se revisa y sobrevive al modelo que la escribió; regenerar los
diecisiete grupos cada semestre cuesta cero. Y el argumento fuerte, que además es
verdad: **un modelo de lenguaje es muy bueno escribiendo la descripción en el
DSL; no la sustituye.** Son complementarios. Conviene decirlo en el documento
antes de que lo pregunten.

## Lo que hay que pedir y verificar

**Los repositorios de código de las tesis de 2025 y 2026.** Todo el análisis
anterior está hecho sobre los PDF. Antes de citar nada en el documento de tesis
hay que comprobarlo contra el código, y muy especialmente estas cuatro cosas, que
son las que más caro saldría que se cayeran en la defensa:

1. La firma real de `compile-excel-formula` y que no recibe la arquitectura. Es
   el argumento central.
2. Que el árbol de 2026 no tiene jerarquía de clases.
3. Que la clase que identifica la arquitectura nunca se define.
4. **La lectura de la figura 6.2.** Es la más frágil de todas, porque es
   interpretación de una imagen. Si el código confirma que los colores se asignan
   por orden de regla, el argumento es demoledor; si no, hay que retirarlo.

## Nota práctica

En esta máquina no hay instalado ningún Common Lisp (ni SBCL ni Quicklisp) y
tampoco Emacs. LibreOffice sí está, que es lo que hace falta para verificar que
las fórmulas se evalúan. Habrá que instalar SBCL y Quicklisp antes de escribir la
primera línea.
