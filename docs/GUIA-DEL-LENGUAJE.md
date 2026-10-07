# Guía del lenguaje `situacion`

Referencia completa y de uso práctico: qué hay, con qué tecnologías está hecho,
cómo se escribe una descripción de principio a fin, y —la parte que no está en
ningún otro documento de esta forma— qué se puede describir con el lenguaje tal
como existe hoy y qué no, con evidencia real de código, no de intención.

No sustituye a `01-PARA-ENTENDER.md` (el porqué del proyecto) ni a
`02-ARQUITECTURA.md` (el diseño). Es el manual de uso: si quieres escribir una
situación nueva, o saber si una idea entra en el lenguaje antes de intentarla,
empieza aquí.

**Fecha de esta guía: 2026-09-24, actualizada el 2026-10-07** (la
descripción del departamento, dos errores de emisión corregidos y el estado
del caso Saúl Delgado en Excel). Las citas de código son literales, con
`archivo:línea`, verificadas contra el estado del repositorio en esa fecha.
Donde una afirmación viene de un experimento hecho el 2026-09-21 (antes de
varios arreglos posteriores) o del 2026-09-22 (cuando se cerraron dos huecos
más), se dice explícitamente. Si en algún momento esta guía y el código
discrepan, manda el código — es la misma regla que rige el resto de la
documentación del proyecto.

---

## Índice

1. [Qué es esto, en una frase](#1-qué-es-esto-en-una-frase)
2. [Tecnologías](#2-tecnologías)
3. [Cómo se ejecuta](#3-cómo-se-ejecuta)
4. [La forma del sistema](#4-la-forma-del-sistema)
5. [El lenguaje: referencia completa](#5-el-lenguaje-referencia-completa)
6. [Lo que el compilador rechaza antes de que exista un destino](#6-lo-que-el-compilador-rechaza-antes-de-que-exista-un-destino)
7. [El protocolo de extensión](#7-el-protocolo-de-extensión)
8. [Las tres arquitecturas](#8-las-tres-arquitecturas)
9. [Ejemplo completo, línea a línea](#9-ejemplo-completo-línea-a-línea)
10. [Qué SÍ puede describir hoy](#10-qué-sí-puede-describir-hoy)
11. [Qué NO puede describir, o hace a medias](#11-qué-no-puede-describir-o-hace-a-medias)
12. [La frontera con "resolver"](#12-la-frontera-con-resolver)
13. [Glosario rápido](#13-glosario-rápido)
14. [Dónde seguir](#14-dónde-seguir)

---

## 1. Qué es esto, en una frase

`situacion` es un lenguaje interno en Common Lisp para describir **una vez**
una situación tabular —datos, cómo se derivan unos de otros, qué significa
cada estado, y qué puede escribir el usuario— y producir, de esa misma
descripción, tres artefactos distintos (un libro de cálculo, una página web
con recálculo vivo, un informe en texto plano) sin que ninguno de los tres
sepa que los otros existen. No resuelve nada: describe y muestra, igual que
hace hoy un libro de Excel con datos ya decididos por una persona.

## 2. Tecnologías

| Pieza | Tecnología | Para qué |
|---|---|---|
| Núcleo, lenguaje, protocolo, análisis, las tres arquitecturas | **Common Lisp**, compilado y ejecutado con **SBCL** | Todo el sistema. Arranca con un SBCL recién instalado, sin Quicklisp: `situacion.asd` declara los sistemas y `asdf:initialize-source-registry` apunta al directorio actual |
| Declaración de sistemas y su grafo de dependencias | **ASDF** (`situacion.asd`) | El grafo de dependencias es en sí mismo una prueba de diseño: cada arquitectura depende solo de `protocolo`, nunca de `lenguaje` ni entre sí |
| El "plano" de la hoja de cálculo → archivo real | **Python + openpyxl** (`materializador/materializar.py`) | Convierte el JSON que emite la arquitectura de Excel (celdas, fórmulas, formatos condicionales, validaciones, protección, rangos nombrados) en un `.xlsx` real. No hay versión de Python ni de openpyxl fijada en el repositorio |
| Verificación de la hoja de cálculo | **LibreOffice**, pilotado desde `materializador/verificar.py` | Abre el `.xlsx` generado, deja que recalcule, y compara cada celda contra el evaluador de referencia del núcleo |
| La arquitectura web | **JavaScript**, emitido como código fuente (no hay build ni framework) | `web/recursos.lisp` emite una página con una función `render()` que reevalúa toda la situación en cada evento de entrada — recálculo vivo, pero por reevaluación completa, no por grafo de dependencias incremental |
| Verificación de la página web | **Node**, vía `materializador/verificar-web.js` | Ejecuta el JavaScript emitido de verdad y compara los valores contra el evaluador de referencia |
| El texto plano | Common Lisp puro, sin dependencia externa | Existe para forzar que haya dos arquitecturas desde el primer commit — ver [sección 8](#8-las-tres-arquitecturas) |

**Tamaño real** (conteo por archivo, 2026-09-24): `excel/` 1922 líneas en 7
archivos, `web/` 953 líneas en 4 archivos, `texto/` 434 líneas en 2 archivos.
El núcleo, el lenguaje, el protocolo y el análisis no dependen de nada
externo — es a propósito: es lo que tiene que poder hacer quien reciba el
protocolo para añadir su propia arquitectura (la de Emacs, por ejemplo).

## 3. Cómo se ejecuta

Desde `Horario/`:

| Comando | Qué hace, paso a paso |
|---|---|
| `./demostrar.sh` | (1) Carga `situacion/demostracion` en SBCL y genera los artefactos de las situaciones del corpus. (2) Convierte cada `*-plano.json` a `.xlsx` con `materializador/materializar.py`. (3) Verifica cada `.xlsx` abriéndolo con LibreOffice y comparando contra el evaluador de referencia. (4) Verifica cada página ejecutando su JavaScript con Node. Termina imprimiendo ok/fallo por artefacto |
| `./ejecutar-pruebas.sh` | `sbcl --non-interactive --noinform --disable-debugger --no-userinit`, carga `situacion/pruebas` y llama a `ejecutar-y-salir`. 63 pruebas y 558 comprobaciones el 2026-10-07 |
| `./generar-demostracion.sh` | Solo el paso de generación, sin materializar ni verificar |
| `python3 materializador/materializar.py <plano.json> <salida.xlsx>` | El paso de materialización a mano, sobre un plano ya generado |

Ninguno necesita Quicklisp.

## 4. La forma del sistema

### Las capas y su grafo de dependencias

```
nucleo/       sin dependencias. El modelo semántico y el evaluador de referencia
lenguaje/     depende solo de nucleo. Las macros — la sintaxis
analisis/     depende solo de nucleo. Comprobaciones estáticas, sin arquitectura
protocolo/    depende solo de nucleo. El contrato de extensión
texto/        depende solo de protocolo
excel/        depende solo de protocolo
web/          depende solo de protocolo
corpus/       depende de lenguaje (usa las macros para describir situaciones reales)
pruebas/      depende de todo — es el único sistema que "mira dentro" de los demás
```

Esto no es una convención documental: `situacion.asd` lo declara arista por
arista, y una prueba de invariantes recorre el `.asd` real para comprobarlo.
Ninguna arquitectura depende de otra ni del lenguaje.

### Las tres reglas que el sistema hace cumplir

1. **El núcleo no depende de nada.**
2. **El protocolo no ve el lenguaje.** Una arquitectura no puede usar las
   macros ni por descuido: el sistema no compila si lo intenta.
3. **Ninguna arquitectura ve a otra.** Lo que dos arquitecturas necesiten
   compartir sube a una clase de capacidad, no se copia entre ellas.

### El invariante que da nombre al trabajo

En `protocolo/operacion.lisp`, la macro `definir-operacion` rechaza **en
tiempo de expansión** cualquier operación del protocolo cuyo primer parámetro
no se llame `arquitectura`:

```lisp
(definir-operacion compilar-formula
  (nodo mapa-de-columnas fila primera-fila ultima-fila))

;; => La operacion COMPILAR-FORMULA del protocolo no recibe la arquitectura.
```

Esa firma es, literalmente, la de `compile-excel-formula` de la tesis de 2026
(no recibía el destino y llevaba la rejilla de Excel en la propia firma).
Aquí no es una convención que alguien pueda olvidar: quien la escriba así, no
compila.

### Las seis fases de la compilación

```
  descripción escrita en el lenguaje
        |
   (1) LECTURA          las macros expanden a constructores
   (2) CONSTRUCCION     el árbol de nodos
   (3) RESOLUCION       los símbolos pasan a ser referencias
   (4) COMPROBACION     estática, sin arquitectura       <- sección 6
        |
  == SITUACION RESUELTA ==   la representación intermedia
        |
   (5) PLANIFICACION    por arquitectura                 <- sección 7
   (6) EMISION          por arquitectura. Sale el artefacto
```

### La inversión de capacidades

Del informe de conformidad real del horario de un grupo (`horario-del-grupo.lisp`):

| | texto | excel | web |
|---|---|---|---|
| nativas | 4 | 8 | **9** |
| emuladas | 1 | 1 | 0 |
| degradadas | 4 | 0 | 0 |

La hoja de cálculo, que parece la más capaz, **emula** la tabla cruzada —fija
los dos ejes al generar e inventa una columna de clave compuesta con
`INDICE`+`COINCIDIR`— mientras que la página la cumple de forma nativa y
recalcula los ejes al dibujar. No hay una arquitectura que pueda más y otras
que puedan menos: cada una puede cosas distintas. Esto es evidencia de
diseño, no una curiosidad — es el argumento central de la tesis frente a
2026, donde la independencia del backend se afirmaba pero no se demostraba.

---

## 5. El lenguaje: referencia completa

Convención de lectura, y la decisión de diseño más importante del lenguaje
(`lenguaje/expresiones.lisp:9-20`): dentro de un `:cuando` o un `:donde`, un
símbolo suelto se refiere al campo de la **fila candidata** que se está
evaluando. Para hablar de la fila de fuera hay que decirlo explícitamente:
`(de fila ...)` o `(de otra ...)`. Fuera de ese contexto, un símbolo suelto
es **error**: *"fuera de un `:donde` hay que decir de qué fila se habla, con
`(de fila x)` o `(de otra x)`"*.

### 5.1 `defsituacion`

```lisp
(defsituacion NOMBRE (:etiqueta "...")
  CUERPO...)   ; parametro, coleccion, marca, vista, en cualquier orden
```

Por ahora la única opción de cabecera es `:etiqueta` (el propio código lo dice
así: "de momento solo :ETIQUETA"). Define un `defparameter` con ese nombre y
lo registra por nombre en `*situaciones*`.

Ejemplo real, `corpus/plan-del-grupo.lisp:23`:

```lisp
(defsituacion plan-del-grupo (:etiqueta "Plan de asignaturas del grupo D111")
  (coleccion asignaturas ...)
  (marca insuficiente ...)
  (vista plan :de asignaturas :entrada t :etiqueta "Plan del grupo"))
```

### 5.2 `parametro`

```lisp
(parametro NOMBRE :tipo numero|... :valor ... [:rol fijo|entrada] [:etiqueta "..."])
```

*"Una constante con nombre. Un tope de carga docente se edita en el
documento; una constante del dominio, no."* Con `:rol fijo` (por defecto) se
establece al generar; con `:rol entrada` la edita el usuario. Se lee dentro de
una expresión con `(parametro nombre)`.

**Aviso de uso:** ningún archivo del corpus real lo usa todavía, y el
experimento de "notas" (sección 11) encontró que `:rol entrada` en un
parámetro **no se materializa como editable en ninguna arquitectura** —tanto
Excel como la web incrustan el valor literal en vez de una referencia. Es un
hueco real, no una limitación teórica: si necesitas un parámetro que el
usuario pueda cambiar, verifica primero contra el código actual si esto se
corrigió.

### 5.3 `coleccion`

```lisp
(coleccion NOMBRE
  (:etiqueta "...")
  (:clave campo1 [campo2 ...])   ; simple o compuesta, sin sintaxis especial
  (:orden campo)                 ; UN SOLO campo — ver más abajo
  (:crece)                       ; opcional, sin argumentos
  (:datos ((...) (...) ...))
  (campo ...) (campo ...) ...)
```

- **`:clave`** identifica una fila. Puede ser compuesta (varios símbolos)
  sin ninguna sintaxis adicional.
- **`:orden`** acepta exactamente un campo. Poner más de uno es error
  explícito en tiempo de macroexpansión: *"si de verdad hace falta ordenar
  por varios, no es un problema de sintaxis: es que al lenguaje le falta el
  orden compuesto"*. Sin `:orden` declarado, cualquier uso de `anterior` o
  `siguiente` sobre esa colección es rechazado por el análisis estático
  citando esta misma regla de diseño — es la comprobación que el proyecto
  señala como la más importante de todas: sin orden declarado, "anterior"
  solo podría significar "la fila de arriba", que es una propiedad del
  dibujo, no del problema.
- **`:crece`** declara la intención de que la colección no está cerrada
  ("El listado sigue creciendo... esto es un hecho del dominio, no una
  instrucción sobre filas en blanco"). No dice el mecanismo: cada
  arquitectura decide cómo (filas de reserva en Excel, botón "añadir fila" en
  la web).
- **`:datos`** es una lista de listas de valores, en el orden de los campos
  de rol `:fijo`.
- Existen en la sintaxis y en el análisis dos orígenes especiales,
  `(:una-fila-por campo :de coleccion)` y `(:una-sola-fila)`, para una
  colección que se agrupa o proyecta de otra. **No hay ningún uso real
  ejecutado** de ninguno de los dos ni en el corpus ni en las exploraciones —
  existen como forma, no como práctica probada.

Ejemplo real con clave compuesta, orden y crecimiento,
`corpus/defensas-de-tesis.lisp:43-50`:

```lisp
(coleccion citaciones
  (:etiqueta "Citaciones")
  (:clave dia momento local)
  (:orden momento)
  (:crece)
  (campo dia :rol fijo :etiqueta "Dia")
  ...)
```

### 5.4 `campo`

```lisp
(campo NOMBRE :rol fijo|entrada|derivado
              [:tipo texto|entero|numero|hora|fecha|booleano]
              [:etiqueta "..."]
              [:dominio EXPRESION-DE-CONJUNTO]     ; solo con :rol entrada
              [:al-violar advertir|impedir]        ; por defecto advertir
              [:opcional t]
              [EXPRESION])                         ; solo con :rol derivado
```

Tres roles, con semántica exacta y comprobada en tiempo de macroexpansión:

- **`:fijo`** — se escribe al generar.
- **`:entrada`** — lo escribe el usuario en el documento producido.
- **`:derivado`** — se calcula; exige una expresión, y es error ponerla en
  cualquier otro rol.

Declarar `:dominio` en un campo que no sea `:rol entrada` es error: *"un
dominio dice que puede escribir el usuario; si nadie escribe ahí, no
significa nada"*. Declarar `:rol entrada` con `:al-violar impedir` pero sin
`:dominio` es aviso, no error: *"dice AL-VIOLAR IMPEDIR pero no tiene dominio
que violar"*.

**Aviso de uso sobre tipos:** el sistema de tipos declara seis
(`texto entero numero hora fecha booleano`), pero en todo el corpus real solo
se ejercitan `texto` (por defecto) y `entero`. No hay evidencia de que
`hora`, `fecha` o `booleano` estén implementados de verdad en las tres
arquitecturas — verifica antes de depender de ellos para algo con fechas u
horas (justo lo que necesitaría, por ejemplo, cualquier situación de
horarios con fecha calendario en vez de solo "lunes"/"martes").

**Verificado contra el código el 2026-09-25, y el resultado es más tajante
que "no hay evidencia":**

- `:tipo` no se valida en absoluto. `compilar-campo` y `compilar-parametro`
  aceptan cualquier palabra clave — no hay ningún `member` ni chequeo contra
  la lista de seis (`lenguaje/macros.lisp:90` y `:201`, vía `como-clave`, que
  solo normaliza mayúsculas). Esto ya está dicho con precisión en
  el capítulo 4 de la tesis (`tesis.pdf`).
- De los seis, **solo `entero` y `numero` tienen algún efecto observable, y
  solo en un sitio**: `web/emision.lisp:253` pasa el tipo del campo a la
  página, y `web/recursos.lisp:357` y `:362` lo usan para poner
  `input type="number"` y coaccionar el valor a número. `hora`, `fecha` y
  `booleano` caen todos por el mismo `else` implícito que `texto`: un
  `<input>` de texto plano, sin selector de fecha, sin validación de
  formato, sin nada.
- **El backend de Excel no lee `tipo` en ningún caso.** No hay una sola
  referencia a `nucleo:tipo` en ningún archivo de `excel/` (verificado por
  grep). Da igual qué tipo declares: el backend de Excel lo ignora por
  completo, para los seis valores por igual.
- **`booleano` tiene cero usos en todo el repositorio** — ni en el corpus,
  ni en las pruebas, ni en las exploraciones. No es solo que no esté
  implementado: nadie lo ha usado nunca, ni siquiera para probarlo.
- `hora` y `fecha` sí aparecen, pero nunca en el corpus real: solo en
  material exploratorio (`pruebas/alcance.lisp:19-20`,
  `exploracion/inventario.lisp:68,223,398`), nunca en `corpus/`. Y ojo con
  la trampa: declarar `:tipo fecha` en un campo **no activa nada por sí
  mismo**. El orden correcto de fechas ISO (`AAAA-MM-DD`) y horas
  (`HH:MM`) que sí funciona en comparaciones (`<`, `>=`, orden de filas) sale
  de `fecha-como-numero` y `hora-como-numero`
  (`nucleo/evaluador.lisp:191-217`), que reconocen el **valor** por su forma
  de cadena — no consultan el `:tipo` del campo en ningún momento (no hay
  ninguna llamada a `nucleo:tipo` en `nucleo/evaluador.lisp`). Un campo
  declarado `:tipo texto` con esos mismos valores de cadena ordena
  exactamente igual. Es coerción sobre el valor, no un tipo de dato: no hay
  aritmética de calendario (sumar un día, restar horas) ni validación de que
  la cadena tenga esa forma.

Ejemplo con los tres roles, dominio validado y valor de reemplazo,
`corpus/defensas-de-tesis.lisp:54-75`:

```lisp
(campo estudiante :rol entrada
       :etiqueta  "Estudiante"
       :dominio   (los estudiante de tesis)
       :al-violar advertir)

(campo tutor :rol derivado :etiqueta "Tutor"
       (el tutor de (la-fila-de tesis
                      :donde (= estudiante (de fila estudiante)))
           :si-no ""))
```

Ejemplo con `:tipo entero` y aritmética entre campos,
`corpus/plan-del-grupo.lisp:34-37`:

```lisp
(campo frecuencia :rol fijo     :tipo entero :etiqueta "Frec")
(campo asignadas  :rol entrada  :tipo entero :etiqueta "Asignadas")
(campo faltan     :rol derivado :tipo entero :etiqueta "Faltan"
       (- (de fila frecuencia) (de fila asignadas)))
```

### 5.5 El álgebra de expresiones

Todo lo que puede aparecer dentro de un campo derivado, una condición de
marca, un dominio o un filtro de vista:

| Forma | Qué hace |
|---|---|
| `(de fila campo)` | Accede a un campo de una variable de fila ligada |
| `(de (anterior fila) campo)` / `(de (siguiente fila) campo)` | Fila contigua según el `:orden` declarado. Ilegal sin orden declarado |
| `(parametro nombre)` | Valor de un parámetro |
| `(+ - * / = /= < <= > >= y o no ...)` | Aritmética, comparación y lógica — un solo nodo del núcleo, no una clase por operador |
| `(si prueba entonces si-no)` | Condicional de tres ramas |
| `(vacio? x)` | Cierto si el campo aún no fue rellenado por el usuario — un hecho del dominio, no "la celda está vacía" |
| `(texto a b c...)` | Concatenación de texto |
| `(plural cantidad singular plural)` | Concordancia de número ("Falta"/"Faltan") |
| `(los campo de coleccion [:donde ...])` | Los valores que toma un campo en una colección — alimenta `:dominio` |
| `(uno-de "a" "b" "c")` | Conjunto escrito a mano, sin tabla, para dos o tres valores del dominio |
| `(las-filas-de coleccion :donde ...)` | La relación uno a muchos — ver [5.8](#58-relación-uno-a-muchos) |
| `(cuantas coleccion [:donde ...])` | Conteo de filas |
| `(suma campo de coleccion [:donde ...])` | Suma de un campo — **solo un campo, no una expresión**, ver sección 11 |
| `(minimo campo de coleccion [:donde ...])` / `(maximo ...)` | Mínimo / máximo |
| `(cuantas-distintas campo de coleccion [:donde ...])` | Conteo de valores distintos de un campo |
| `(la-fila-de coleccion :donde ...)` | Búsqueda de una fila. La condición puede mencionar varios campos a la vez: la clave compuesta sale sin sintaxis adicional — en el núcleo. En Excel no siempre, ver sección 11 |
| `(el campo de <búsqueda> [:si-no valor])` | Proyecta un campo de la fila encontrada; `:si-no` por defecto es `""` y no es un adorno: es la mitad del concepto |
| `(existe v :en coleccion :donde ... [:distinta-de w])` | Cuantificador existencial; `:distinta-de` excluye explícitamente la propia fila |
| `(comparten a b (campo1 campo2 ...))` | Cierto si dos filas comparten algún valor en esos campos — azúcar sobre una disyunción de igualdades |

Literales admitidos: números, cadenas, `t`, `nil`. Cualquier otra forma es
error explícito citando la forma exacta que no supo leer.

### 5.6 `marca`

```lisp
(marca NOMBRE [:en COLECCION]
              :cuando EXPRESION-BOOLEANA
              :sobre (campo1 campo2 ...)
              [:severidad informativa|advertencia|problema]   ; por defecto advertencia
              [:explica EXPRESION-DE-TEXTO])
```

`:cuando` y `:sobre` son obligatorios. `:en` es opcional: si no se declara,
el análisis intenta deducir la colección por los campos de `:sobre`; si hay
ambigüedad entre colecciones, error explícito pidiendo `:en`.

*"La marca declara significado, no color... en una hoja de cálculo es un
relleno, en una página un color con un icono, en un editor un estilo de
texto, y en una impresión en blanco y negro tiene que ser texto o no se ve
nada."* Esta es la razón por la que una marca sobrevive al cambio de
arquitectura y un color puesto a mano no.

Ejemplo — la marca que detecta un profesor citado dos veces a la vez,
precedente directo para cualquier restricción de "no puede estar en dos
sitios al mismo tiempo" (`corpus/defensas-de-tesis.lisp:84-94`):

```lisp
(marca profesor-citado-dos-veces
  :en citaciones
  :cuando (existe otra :en citaciones
            :distinta-de fila
            :donde (y (= (de otra dia) (de fila dia))
                      (= (de otra momento) (de fila momento))
                      (comparten otra fila
                                 (tutor oponente presidente secretario))))
  :sobre     (tutor oponente presidente secretario)
  :severidad problema
  :explica   "Este profesor esta citado en dos locales a la vez")
```

Ejemplo con concordancia numérica en la explicación,
`corpus/plan-del-grupo.lisp:46-52`:

```lisp
(marca insuficiente
  :cuando    (< (de fila asignadas) (de fila frecuencia))
  :sobre     (nombre asignadas faltan)
  :severidad advertencia
  :explica   (texto (plural (de fila faltan) "Falta" "Faltan") " "
                    (de fila faltan) " "
                    (plural (de fila faltan) "turno" "turnos")))
```

### 5.7 `vista`

```lisp
(vista NOMBRE :de COLECCION
              [:etiqueta "..."]
              [:entrada t]
              [:secciones CAMPO]
              [:agrupada-por CAMPO]
              [:donde EXPRESION-BOOLEANA]          ; filtro de presentación
              [:unica-salvo NOMBRE-DE-MARCA]
              [:filas CAMPO :columnas CAMPO :muestra CAMPO])   ; tabla cruzada
```

`:de` es obligatorio. Nota de nombres: la palabra clave que se escribe es
`:donde` (no `:filtro`) y `:unica-salvo` (no `:conflicto`) — esos son los
nombres de los slots internos del modelo, no lo que escribe el autor.

- **`:secciones`** parte la vista en secciones por el valor de un campo (el
  horario por instalación, por profesor, por grupo...).
- **`:agrupada-por`** agrupa las filas dentro de una sección, con una
  cabecera por grupo. Ejemplo real, `corpus/defensas-de-tesis.lisp:103-104`:
  ```lisp
  (vista dia :de citaciones :entrada t :etiqueta "Citaciones del dia"
             :agrupada-por local)
  ```
- **`:unica-salvo <marca>`** es la garantía declarada de que cada casilla de
  una tabla cruzada tiene una sola fila, cuando los ejes por sí solos no
  bastan para asegurarlo. El ejemplo canónico, tomado del propio docstring
  del modelo: el horario de un grupo se cruza por turno y día y ahí cada
  casilla es una sola fila; el horario de un profesor no —dos grupos pueden
  caer en la misma casilla, y eso ya tiene nombre en el dominio ("el
  profesor está citado dos veces") y ya tiene una marca que lo detecta. Esa
  marca es lo que se declara aquí. El caso real que lo ejercita es el
  horario de Saúl Delgado por profesor (sección 11.6):
  ```lisp
  (vista por-profesor :de casillas :filas turno :columnas dia :muestra grupo
                      :secciones profesor
                      :unica-salvo profesor-colisiona)
  ```
  Declararlo sin que haga falta es solo aviso; que sobre parte de la clave sin
  cubrir por los ejes y no esté declarado es error, con un mensaje que
  sugiere las tres salidas posibles: añadir `:secciones`, cambiar los ejes, o
  declarar `:unica-salvo`.
- **`:donde`** filtra la presentación sin tocar los datos: *"una fila que el
  filtro deja fuera sigue contando para los agregados y para las marcas — el
  horario de un profesor no enseña las clases de otro, y aun así tiene que
  saber que chocan"*. Se rechaza declarar `:donde` en una vista que no sea
  cruzada.
- **`:filas` / `:columnas` / `:muestra`** son la tabla cruzada. Hay que
  declarar las tres o ninguna — declarar solo alguna es error ("tabla
  cruzada a medias"). Es la construcción que resolvió el caso que durante
  todo el análisis se creyó que no cabía en el modelo: una rejilla de día por
  turno no es una lista de filas, hasta que se entiende que **la matriz
  nunca fue una estructura de datos** — los datos siguen siendo una fila por
  casilla, y lo que cambia es solo cómo se presentan.

Ejemplo real, la vista de tabla cruzada del corpus
(`corpus/horario-del-grupo.lisp`):

```lisp
(vista rejilla :de casillas :entrada t
               :etiqueta "Horario semanal"
               :filas turno :columnas dia :muestra asignatura)
```

**Aviso de uso importante:** `:muestra` solo admite **un campo**, nunca una
expresión. Si necesitas que la celda muestre dos datos a la vez (por
ejemplo, brigada y carrera en una misma casilla), la solución probada es
crear un campo `:rol derivado` que concatene ambos con `(texto ...)`, y
mostrar ese campo derivado — no intentar poner la expresión directamente en
`:muestra`.

### 5.8 Relación uno a muchos

```lisp
(las-filas-de COLECCION :donde CONDICION)
```

`:donde` es obligatorio: *"sin condición serían todas, y para eso está la
colección"*. Es *"el detalle de carga de un profesor, los movimientos de un
artículo, los gastos de una partida"* — gratis en una página web y en una
base de datos; en una hoja de cálculo hay que emularla (ver sección 8).

El corpus lo usa en `corpus/departamento.lisp`, para lo que imparte cada
profesor:

```lisp
(campo imparte :rol derivado :etiqueta "Lo que imparte"
       (las-filas-de asignacion :donde (= profesor (de fila id))))
```

Cada arquitectura lo presenta a su manera: el texto escribe las filas por su
clave separadas por comas, la página las tiene como lista, y la hoja de
cálculo pone en la celda cuántas son (`COUNTIF` en vivo) y el detalle en una
hoja aparte. Lo que coincide en las tres, y lo que la demostración compara
contra el evaluador, es cuántas filas trae.

El ejemplo mínimo, de la prueba que cerró este hueco en Excel el 2026-09-22:

```lisp
(coleccion profesores
  (:clave nombre)
  (campo nombre :rol fijo :etiqueta "Profesor")
  (campo asignaciones :rol derivado :etiqueta "Asignaturas que imparte"
         (las-filas-de asignacion :donde (= profesor (de fila nombre))))
  (:datos (("Rosa") ("Julia") ("Pedro"))))

(coleccion asignacion
  (:clave profesor grupo abrev)
  (campo profesor :rol fijo :etiqueta "Profesor")
  (campo grupo    :rol fijo :etiqueta "Grupo")
  (campo abrev    :rol fijo :etiqueta "Asignatura")
  (:datos (("Rosa" "10-A" "MAT") ("Rosa" "10-B" "MAT") ("Rosa" "10-A" "ING") ...)))
```

---

## 6. Lo que el compilador rechaza antes de que exista un destino

El análisis estático (`analisis/comprobacion.lisp`) no consulta ninguna
arquitectura: *"el error sale antes de que exista un destino"*. Lo que
rechaza en tiempo de análisis, como **error duro** (bloquea la compilación):

- Variable de fila no ligada (en `(de fila ...)`, `anterior`/`siguiente`,
  `comparten`, `:distinta-de` de `existe`).
- Campo o parámetro referenciado que no existe.
- `anterior`/`siguiente` sobre una colección sin `:orden` declarado — la
  comprobación que el propio proyecto señala como la más importante de
  todas.
- Colección referenciada que no existe, en cualquier construcción que la
  mencione.
- Campo de colección duplicado; campo mencionado en `:clave` o `:orden` que
  no existe.
- Marca sin `:sobre`, o cuya colección no se puede deducir sin ambigüedad, o
  con una severidad que no sea una de las tres válidas.
- Vista cuya colección no existe; tabla cruzada a medias (algunos de
  `:filas`/`:columnas`/`:muestra` sin los otros); casilla de tabla cruzada
  no determinada por los ejes y sin `:unica-salvo`; `:unica-salvo` con una
  marca inexistente o de otra colección; `:donde` en una vista que no es
  cruzada; cualquier campo de vista que no sea campo real de la colección.
- Ciclo de dependencia entre campos derivados de la misma fila.
- Una situación sin ninguna colección.

Solo **aviso**, no bloquea: colección derivada sin campo propio para el
agrupador (usa el primero); campo `:entrada` con `:al-violar impedir` sin
`:dominio`; `:unica-salvo` declarado donde no hacía falta.

Y una regla léxica del núcleo, verificable con una prueba: **ningún símbolo
del núcleo puede nombrar una dirección, columna, celda o función de hoja de
cálculo.** Es la comprobación de diseño más citable para explicar por qué el
núcleo "no sabe" que existe Excel — si en el árbol apareciera una letra de
columna o una coordenada, el diseño estaría mal por definición, no por
descuido.

---

## 7. El protocolo de extensión

### Las 13 operaciones

Todas declaradas con `definir-operacion` (por eso todas reciben la
arquitectura como primer parámetro — ver sección 4):

| Fase | Operación | Propósito |
|---|---|---|
| Declaración | `capacidades (arquitectura)` | Qué capacidades cumple de forma nativa |
| Declaración | `nivel-de-recalculo (arquitectura)` | `:viva`, `:bajo-demanda` o `:congelada` |
| Planificación | `planificar (arquitectura situacion)` | Punto de entrada de la fase 5 |
| Planificación | `planificar-coleccion` / `planificar-campo` / `planificar-vista` | Planificación por nodo |
| Emisión | `materializar (arquitectura situacion datos destino)` | Punto de entrada alto nivel de la fase 6 |
| Emisión | `emitir (arquitectura plan destino)` | Emisión general |
| Emisión | `emitir-expresion` | La operación que en 2026 se llamaba `compile-excel-formula` y no recibía la arquitectura |
| Emisión | `emitir-marca` / `emitir-entrada` / `emitir-vista` | Emisión por tipo de nodo |
| Carencias | `resolver-carencia (arquitectura capacidad nodo)` | Decide `:emula`, `:degrada` o `:rechaza` cuando falta una capacidad nativa |

### Las capacidades componibles

El código actual (2026-09-24) declara **19** capacidades. Eran 15
hasta que la vista particionada añadió cuatro más el 2026-09-22:

`con-rejilla`, `con-derivacion-viva`, `con-derivacion-por-consulta`,
`con-entrada`, `con-dominio-de-entrada`, `con-orden-declarado`,
`con-busqueda-por-clave`, `con-relacion-uno-a-muchos`, `con-tabla-cruzada`,
`con-agrupacion`, `con-conteo-de-distintos`, `con-crecimiento`,
`con-marcado-visual`, `con-marcado-textual`, `con-particion-de-vista`,
`con-casilla-en-conflicto`, `con-filtro-de-vista`, `con-agrupacion-en-vista`,
`con-navegacion`.

Las cuatro últimas en incorporarse: `con-particion-de-vista` (repetir una
vista una vez por valor de un campo), `con-casilla-en-conflicto`
(contrapartida de `:unica-salvo`), `con-filtro-de-vista` (el `:donde` de una
vista) y `con-agrupacion-en-vista` (el `:agrupada-por`).

### El mecanismo cumple / emula / degrada / rechaza

Una variable especial, `*politica*`, decide qué tan estricta es una
compilación —`:permisiva` (por defecto, acepta emulación y degradación),
`:estricta` (cualquier carencia es error), `:solo-nativo` (ni emular se
permite)— y vive **fuera** de cada backend: la misma descripción se puede
compilar en los tres modos contra la misma arquitectura.

Cuando una arquitectura pide una capacidad con `requerir`, si la cumple de
forma nativa se anota `:cumple`; si no, se llama a `resolver-carencia`, que
responde `:emula`, `:degrada` o `:rechaza`. El valor por defecto de
`resolver-carencia`, sobre la clase raíz, es **`:rechaza`**: *"callar no
puede significar 'algo saldrá'"*.

La distinción entre emular y degradar, tal como la documenta el propio
código: **se degrada cuando el resultado sigue cumpliendo el propósito por
otra vía; se rechaza cuando el resultado parecería correcto y no lo sería.**
Esta frase es también el criterio para juzgar un bug real: en la sección 11
hay un caso (el conteo de valores distintos en Excel) donde el sistema dice
`:emula` sobre un resultado que en realidad miente — es exactamente el caso
que esta misma regla dice que hay que rechazar.

### El informe de conformidad

Se acumula durante toda la compilación y se imprime al final de cada
ejecución de `./demostrar.sh`: una tabla con respuesta / capacidad / nota por
cada punto donde una arquitectura pidió algo, y un resumen final del tipo
`"N nativas, N emuladas, N degradadas, N rechazadas"`. Es, según la propia
documentación del proyecto, la evidencia que ninguna tesis anterior de esta
línea tiene: no solo dice que algo funciona, dice **cómo** lo consiguió cada
arquitectura.

---

## 8. Las tres arquitecturas

| | Texto | Excel | Web |
|---|---|---|---|
| Propósito | Forzar que haya dos arquitecturas desde el primer commit — la única salvaguarda real contra diseñar el protocolo mirando un solo destino | Documento de uso real, el que hoy ya usa Fernando | Demostrar que la misma descripción produce un artefacto con comportamiento vivo en un destino que no comparte nada con el primero — no pretende ser una aplicación de producción |
| Capacidades nativas | 8 | 9 | 15 de 19 |
| Lo más capaz que hace de forma nativa | Tabla cruzada, partición de vista, agrupación en vista, filtro de vista, casilla en conflicto, marcado textual, búsqueda por clave, orden declarado | Rejilla real, búsqueda por clave, derivación viva, entrada validada, dominio de entrada, orden declarado, marcado visual y textual, navegación | Todo lo de Excel salvo la rejilla, más tabla cruzada nativa, crecimiento, relación uno a muchos, partición de vista, agrupación y filtro de vista, casilla en conflicto y conteo de distintos |
| Lo que NO tiene, deliberadamente | Rejilla, derivación viva/por consulta, entrada, dominio de entrada, marcado visual, crecimiento, agrupación (se degradan o emulan) | — | Rejilla (*"nunca fue un concepto del dominio"*), agrupación (emulada, fija al generar), derivación por consulta (degradada) |

### Lo interesante de cada una

**Texto.** Existe precisamente porque no puede casi nada: es la prueba de
que el protocolo no se diseñó mirando solo a Excel o solo a la web.

**Excel.** Cada emulación tiene un truco concreto, documentado en el propio
código:

- **Tabla cruzada** — se fijan los dos ejes al generar, y se añade una
  columna de clave compuesta resuelta con `INDICE`+`COINCIDIR` (portable
  entre Excel y Calc, a diferencia de una fórmula matricial).
- **Relación uno a muchos** (`excel/relacion.lisp`) — una hoja auxiliar de
  clave numerada (`Rosa#1`, `Rosa#2`...) más un bloque legible por fila
  padre con un número fijo de líneas reservadas (`reserva-de-relacion`,
  por defecto 5) y aviso si se desborda. La celda de origen lleva un
  `COUNTIF` en vivo, no la lista completa.
- **Vista particionada como archivo aparte** (`excel/particion-en-archivo.lisp`,
  parámetro `:vistas-en-archivo`) — un `.xlsx` congelado por sección, sin
  pestaña en el libro principal. Congelado a propósito: nunca es `:entrada t`,
  es una copia de consulta.
- **Casilla en conflicto** — pregunta cuántas filas cumplen la clave; si hay
  más de una, escribe la primera y anota `(+1)`, `(+2)`... nunca finge que
  hay solo una.
- **Crecimiento** — N filas de reserva más un rango dimensionado. No admite
  huecos en medio.
- **Conteo de valores distintos** — columna auxiliar de "primera aparición",
  porque `COUNTIF` no sabe contar únicos.
- **Agrupación en vista** — se **degrada**, no se emula: sin cabecera por
  grupo, porque en una rejilla la posición de la fila es el dato.

**Web.** El "recálculo vivo" real: la función `render()` se dispara en cada
evento de entrada (`addEventListener('input', ...)`, `addEventListener('click', ...)`)
y reevalúa la situación entera, no un grafo de dependencias incremental como
en Excel — mismo resultado observable, mecanismo distinto. Comparación real
del mismo nodo de búsqueda por clave, emitido a los dos destinos
(`web/expresiones.lisp:1-13`):

```
hoja de cálculo   IFERROR(VLOOKUP($B4,Tesis!$A$4:$F$23,2,FALSE),"")
página            (T.find(c => c.estudiante === f.estudiante) ?? {}).tutor ?? ""
```

*"La expresión del núcleo es la misma. Lo que cambia es todo lo demás, y
nada de lo que cambia subió nunca por encima del protocolo."*

---

## 9. Ejemplo completo, línea a línea

`corpus/horario-del-grupo.lisp` es el ejemplo de referencia para cualquier
situación con forma de rejilla (día × turno, instalación × horario, lo que
sea). Su idea central, en sus propias palabras:

> *"La hoja de grupo... no es una lista de filas: es una rejilla de día por
> turno... La salida fue darse cuenta de que LA MATRIZ NUNCA FUE UNA
> ESTRUCTURA DE DATOS. Los datos son, y siempre fueron, una colección de
> filas: día, turno, asignatura, aula. Lo que es matriz es la presentación.
> Y la presentación es una vista."*

Estructura completa (resumida; el archivo real tiene comentarios en cada
bloque explicando el porqué):

```lisp
(defsituacion horario-del-grupo (:etiqueta "Horario del grupo D111")

  ;; El plan: cuántos turnos semanales lleva cada asignatura.
  (coleccion asignaturas
    (:etiqueta "Asignaturas")
    (:clave abrev)
    (campo abrev      :rol fijo :etiqueta "Abrev")
    (campo nombre     :rol fijo :etiqueta "Asignatura")
    (campo frecuencia :rol fijo :tipo entero :etiqueta "Frec")
    (:datos (("AL" "Algebra Lineal" 3) ("L" "Logica" 2) ...)))

  (coleccion aulas
    (:etiqueta "Aulas") (:clave aula)
    (campo aula :rol fijo :etiqueta "Aula")
    (:datos (("Aula 7") ("Aula 8") ("Lab 1"))))

  ;; LA REJILLA, COMO LO QUE ES: una fila por casilla.
  (coleccion casillas
    (:etiqueta "Casillas")
    (:clave dia turno)
    (:orden turno)
    (campo dia   :rol fijo :etiqueta "Dia")
    (campo turno :rol fijo :etiqueta "Turno")
    (campo asignatura :rol entrada :etiqueta "Asignatura"
           :dominio (los abrev de asignaturas) :al-violar advertir)
    (campo aula :rol entrada :etiqueta "Aula"
           :dominio (los aula de aulas) :al-violar advertir)
    (campo nombre :rol derivado :etiqueta "Nombre"
           (el nombre de (la-fila-de asignaturas
                           :donde (= abrev (de fila asignatura)))
               :si-no ""))
    (campo puestos :rol derivado :tipo entero :etiqueta "Puestos"
           (cuantas casillas :donde (= asignatura (de fila asignatura))))
    (campo faltan :rol derivado :tipo entero :etiqueta "Faltan"
           (- (el frecuencia de (la-fila-de asignaturas
                                  :donde (= abrev (de fila asignatura)))
                  :si-no 0)
              (de fila puestos)))
    (:datos (("lunes" "T1") ("lunes" "T2") ("lunes" "T3") ...)))

  ;; El aula ocupada dos veces en el mismo turno del mismo día.
  (marca aula-ocupada
    :en casillas
    :cuando (y (no (vacio? (de fila aula)))
               (existe otra :en casillas
                 :distinta-de fila
                 :donde (y (= (de otra dia) (de fila dia))
                           (= (de otra turno) (de fila turno))
                           (= (de otra aula) (de fila aula)))))
    :sobre     (aula)
    :severidad problema
    :explica   "Ese local esta ocupado por otro grupo a esa hora")

  ;; LA VISTA CRUZADA. Aquí es donde la rejilla deja de ser una lista.
  (vista rejilla :de casillas :entrada t
                 :etiqueta "Horario semanal"
                 :filas turno :columnas dia :muestra asignatura)
  (vista detalle :de casillas :etiqueta "Casilla por casilla")
  (vista plan    :de asignaturas :etiqueta "Plan de la carrera"))
```

Cinco ideas que este ejemplo enseña de una vez: (1) una rejilla es una
colección plana con clave compuesta, nunca una matriz declarada como tal;
(2) un campo `:entrada` con `:dominio` es un desplegable validado; (3) un
campo `:derivado` puede recorrer otra colección con `la-fila-de`/`el...de`
para traer un dato ajeno; (4) una marca de colisión sigue siempre el mismo
patrón — `existe otra :distinta-de fila :donde (mismas coordenadas)`; (5) la
tabla se pide con `vista ... :filas :columnas :muestra`, nunca dibujando
nada a mano.

---

## 10. Qué SÍ puede describir hoy

Con evidencia de que ya se ejecutó de verdad, contra las tres arquitecturas,
con LibreOffice y Node comprobando cada valor contra el evaluador de
referencia:

- **Un plan con déficit derivado y aviso con concordancia numérica** —
  `plan-del-grupo.lisp`: cuánto falta de cada asignatura, con "Falta 1
  turno" / "Faltan 2 turnos" según corresponda.
- **Una agenda con colisión de personas y campos traídos por búsqueda
  compuesta** — `defensas-de-tesis.lisp`: quién tutora, opone, preside y
  secretea cada defensa, avisando si alguien está citado dos veces a la vez,
  con desplegable validado y vista agrupada por local.
- **Una rejilla día × turno con ocupación validada** —
  `horario-del-grupo.lisp`: la tabla cruzada, el desplegable de asignatura y
  de aula, el conteo de turnos puestos y el aviso de exceso.
- **El reparto de la carga docente de un departamento** —
  `departamento.lisp` (2026-10-07): qué profesor imparte qué, las horas de
  cada uno contra su tope, cuántas asignaturas distintas da, lo que imparte
  fila por fila (relación uno a muchos), y si cada asignatura está cubierta,
  dicho con texto ("Falta 1 profesor", "Faltan 48 horas de carga").
  Verificado con LibreOffice (208 celdas) y Node (231 valores).
- **Jerarquías recursivas que se suman a sí mismas** (partida de presupuesto
  que incluye a sus hijas) — funcionan sin tocar el lenguaje, con memoria
  perezosa a varios niveles, confirmado en el experimento de presupuesto.
- **Cascadas de eliminatorias de varios niveles** (64 equipos, 63 partidos)
  sin degradación, confirmado en el experimento de torneo.
- **Validar y mostrar un horario ya decidido, con reglas duras y blandas
  como marcas** — el caso Saúl Delgado (sección 12): nueve reglas duras
  compiladas y evaluadas de verdad contra un horario escrito a mano, en
  texto y en la página web. **En la hoja de cálculo todavía no**: verificado
  el 2026-10-07, la marca `sesion-repetida-mal` pone un `o` y comparaciones
  aritméticas (`/=`, `(+ turno 1)`) dentro de un `existe`, y la traducción a
  `SUMPRODUCT` de `excel/formula.lisp` (`factores-de-existencia`) solo
  entiende conjunciones de igualdades y `comparten`. Falla con un error
  claro, no con una fórmula equivocada.
- **Relación uno a muchos** (qué asignaturas da cada profesor, listadas)
  materializada incluso en Excel, con hoja auxiliar y `COUNTIF` en vivo
  (cerrado el 2026-09-22).
- **Una vista particionada como archivo de consulta aparte**, por ejemplo un
  `.xlsx` por profesor (cerrado el 2026-09-22).

---

## 11. Qué NO puede describir, o hace a medias

Esta sección viene de un experimento deliberado del propio proyecto: el
2026-09-21 se escribieron seis descripciones de dominios **ajenos al
corpus** (control de inventario, evaluación de un curso, presupuesto de
proyecto, torneo de eliminatorias, cuadrante de turnos, y el horario de un
preuniversitario) y se ejecutaron de verdad contra el lenguaje tal como
estaba ese día, para medir qué se podía expresar y qué no — no razonando
sobre el lenguaje, sino usándolo. Encontraron tres fallos que la batería de
47 pruebas no había encontrado. **Viven en `Horario/exploracion/`, no
forman parte del sistema ni se cargan con `./demostrar.sh`.**

Aviso importante de fecha: lo que sigue describe el estado del **2026-09-21**.
Tres fallos se corrigieron esa misma noche (recálculo web hasta punto fijo,
rechazo explícito de `(:orden campo1 campo2)`, y un tercero relacionado con
`(anterior fila :donde ...)`). Dos huecos estructurales más se cerraron el
**2026-09-22** (relación uno a muchos en Excel, vista particionada como
archivo). Los ocho puntos de la sección 11.2 se verificaron contra el
código el **2026-09-25**: cuatro ya estaban resueltos, tres eran bugs reales
que se corrigieron ese mismo día, y uno sigue siendo una construcción que
falta de verdad. El detalle está en cada punto.

### 11.1 Veredictos

| Dominio | Veredicto | Lo más importante que encontró |
|---|---|---|
| Control de inventario | `CABE-FORZADO` | No hay agrupación real, ni enumeración literal de dominio, ni tipo fecha operable; `anterior` con `:donde` se descarta en silencio |
| Evaluación de un curso | `CABE-A-MEDIAS` | `parametro :rol entrada` no se materializa en ningún destino; no se puede sumar una expresión, solo un campo; búsqueda por clave compuesta falla en Excel pese a que el núcleo la promete |
| Presupuesto de proyecto | `CABE-A-MEDIAS` | No hay un sitio para "el total general"; sin orden de cómputo declarado, el recálculo de una sola pasada de la web (ya corregido) daba resultados falsos con el informe en verde |
| Torneo de eliminatorias | `CABE-A-MEDIAS` | Mismo problema de orden de cómputo, más grave (20 de 225 valores falsos con solo reordenar el cuadro); una regla no se puede escribir una vez para varias colecciones; falta aritmética entera |
| Cuadrante de turnos | `CABE-A-MEDIAS` | No hay eje: los valores de un campo no pueden ir en columnas (resuelto después por la partición de vista); `vecino` dentro de una marca emite una condición siempre falsa en Excel |
| Horario de Saúl Delgado | *(no es CABE/NO CABE, es una distinción más fina)* | Describir y validar una asignación ya hecha: sí. Encontrar esa asignación: fuera de alcance por decisión, no por límite técnico — ver sección 12 |

### 11.2 Los límites que se repetían entre dominios, verificados contra el código el 2026-09-25

Esta lista se escribió el 2026-09-21 y decía explícitamente "verifica contra
el código actual antes de citar cualquiera de estos puntos". Esa
verificación se hizo el 2026-09-25: cuatro de los ocho ya estaban resueltos
(el texto había quedado desactualizado, no el código), tres eran bugs reales
y ya se corrigieron ese mismo día, y solo uno sigue siendo una construcción
que de verdad falta.

**Ya resueltos — no son limitación vigente:**

1. ~~No hay un sitio para un valor que sea de toda la situación, no de una
   fila.~~ **Resuelto desde el propio 2026-09-21.** `(:una-sola-fila)` es un
   origen de colección que el evaluador sintetiza solo
   (`nucleo/evaluador.lisp:100-119`, `filas-derivadas`): ya no hace falta
   fingir una fila a mano, así que ya no hay fila que "olvidar". Ver el
   ejemplo de `resumen` en la sección 10.

4. ~~Sin orden de cómputo declarado, el evaluador de referencia y Excel lo
   resolvían por casualidad y la web podía no converger.~~ **Resuelto, y más
   robusto de lo que decía este punto.** La web itera a punto fijo (tope de
   32 pasadas) y avisa explícitamente si no converge
   (`web/recursos.lisp:97-131`); el evaluador de referencia no resuelve "por
   casualidad" sino con memorización por campo y detección real de ciclos,
   con error claro ante una autorreferencia genuina
   (`nucleo/evaluador.lisp:238-263`); Excel usa su propio motor de
   dependencias, que es nativo. Si vas a describir dependencias en cadena
   entre filas, sigue siendo buena práctica correr `./ejecutar-pruebas.sh`
   después de escribirlas, pero no por falta de garantía — por costumbre.

6. ~~Una marca no puede señalar campos que existen en más de una colección a
   la vez sin declarar `:en`.~~ **Esto nunca fue un hueco: es diseño
   intencional**, a propósito distinto del error de 2026 que coloreaba por
   orden de aparición (`analisis/comprobacion.lisp:273-284`). Nadie ha
   pedido nunca una regla "aplica a toda colección que tenga estos campos".

8a. ~~Un agregado sin `:donde` emitía `COUNTA` sin mirar la operación
   pedida.~~ **Resuelto.** `excel/formula.lisp` despacha por operación de
   verdad (`ecase`) también en el caso sin condición.

**Bugs reales, confirmados y corregidos el 2026-09-25** (con su prueba en
`pruebas/formula.lisp`):

5. **`(+ a b c)` con tres o más operandos se emitía truncado a dos, en Excel
   y en la web** — confirmado y corregido. El evaluador de referencia ya era
   N-ario (`nucleo/evaluador.lisp`, `aplicar-operador`, con `reduce`); Excel
   (`excel/formula.lisp`) y la web (`web/expresiones.lisp`) solo usaban el
   primer y segundo operando y descartaban el resto en silencio — aritmética
   incorrecta sin avisar. Los dos backends ahora pliegan (`reduce`) sobre
   todos los operandos, igual que el núcleo. Las comparaciones (`< <= > >=`)
   se dejaron binarias a propósito: no hay ningún uso real de una
   comparación N-aria en el corpus ni en las exploraciones.

   Aparte, y esto sigue sin cambiar: `(redondear ...)`, `(entero-de ...)`,
   `(absoluto ...)` y `(promedio ...)` siguen sin existir, y **correctamente
   fuera de alcance**: no tienen ningún uso real, solo sondas exploratorias
   en `exploracion/presupuesto.lisp` que probaban justamente que faltaban.
   Por la propia regla de `nucleo/expresion.lisp` ("no hay ninguna
   construcción por si acaso"), no se agregan sin un dominio real que las
   necesite.

7. **`comparten` contaba dos valores vacíos como coincidencia en la
   emulación de Excel con `SUMPRODUCT`** — confirmado y corregido. El
   núcleo y la web ya filtraban los vacíos antes de comparar; la fórmula de
   Excel no, y en Excel dos celdas vacías comparadas con `=` dan
   `VERDADERO`. Cada término de la fórmula ahora exige explícitamente que
   los dos lados no estén vacíos, además de ser iguales.

8b. **`cuantas-distintas ... :donde ...` ignoraba el filtro en Excel** —
   confirmado, y no era hipotético: `exploracion/inventario.lisp` ya lo usa,
   y antes de esta corrección habría dado un número incorrecto en Excel
   (cuenta distintos de toda la columna, no solo de lo filtrado). Corregido
   por la vía que el propio protocolo prescribe para este caso exacto: en
   vez de fingir un `SUMPRODUCT` que ignora el `:DONDE`, Excel ahora
   **rechaza** explícitamente `cuantas-distintas` con filtro, con la nota de
   por qué (`excel/arquitectura.lisp`, `resolver-carencia`). Sin filtro
   sigue emulándose igual que antes.

   Cómo se vive con eso: el departamento necesita "cuántas asignaturas
   distintas da cada profesor", que es exactamente un conteo de distintos
   con filtro. `corpus/departamento.lisp` lo dice de otra forma que las tres
   arquitecturas entienden: cada par profesor-asignatura cuenta 1 en la
   primera fila donde aparece, y se suma esa columna por profesor.

**Encontrados al describir el departamento, corregidos el 2026-10-07**
(con su prueba):

9. **`plural` en la página web imprimía objetos del núcleo.** La web
   escribía el singular y el plural como literales de JavaScript sin
   traducirlos, y la página mostraba `#<LITERAL ...>` donde tenía que decir
   "Falta" o "Faltan". Afectaba también a las explicaciones de las marcas
   del corpus; no se había visto porque la verificación con Node solo
   compara campos. Prueba en `pruebas/formula.lisp`.

10. **La relación uno a muchos salía como objetos en texto plano.** El
   informe de la arquitectura de texto promete "las filas relacionadas se
   escriben separadas por comas", pero la celda imprimía la lista de filas
   del evaluador tal cual. Ahora cada fila se escribe por su clave. Prueba en
   `pruebas/relacion.lisp`.

**Lo único que de verdad falta — requiere una construcción nueva, no un
arreglo:**

2. **Los agregados (`suma`, `cuantas`, etc.) toman un campo, nunca una
   expresión.** `(suma (* nota peso) de calificaciones ...)` sigue sin
   compilar — confirmado: el slot `campo` de `agregado`
   (`nucleo/expresion.lisp`) espera un nombre, no una expresión compilada, y
   el compilador de superficie lo pasa directo a `normalizar`. Hay que
   precalcular una columna auxiliar con el producto y sumar esa columna.
   Cerrar esto de verdad exigiría que el evaluador de `agregado` ligara la
   variable de fila y evaluara una expresión arbitraria por fila, en vez de
   buscar un campo en la tabla — diseño nuevo, no un bug de una línea.

**Ya seguro, aunque sigue siendo manual:**

3. **El núcleo promete más de lo que Excel cumple en las claves
   compuestas** — sigue siendo cierto (`BUSCARV`/`VLOOKUP` solo admite una
   igualdad), pero **ya falla de forma segura**: una condición de búsqueda
   que no sea una sola igualdad da un error claro de compilación
   (`excel/formula.lisp`, `emitir-busqueda`), no una fórmula rota en
   silencio — cumple el estándar que el protocolo se exige a sí mismo. La
   técnica de repuesto (clave concatenada a mano, `campo1 + "#" + campo2`,
   ya usada en `horarios/hoja_grupo.py:291` y en `excel/relacion.lisp` para
   las relaciones uno-a-muchos) sigue siendo manual: automatizarla sería una
   comodidad del compilador, no una corrección.

### 11.3 Lo que sí resultó ser una sorpresa positiva

- La jerarquía recursiva de presupuesto (una partida que se suma a sí misma
  en sus hijas) funciona sin tocar el lenguaje.
- La regla "un grupo no puede recibir dos sesiones en el mismo día y turno"
  del caso Saúl **no necesitó ninguna marca**: la garantiza la propia forma
  de la `:clave` compuesta — dos sesiones así serían la misma fila, y el
  sistema ya lo impide estructuralmente.
- La representación "una fila por celda" de un cuadrante de turnos no
  necesita `vecino` en absoluto: basta aritmética sobre la propia clave
  (`(= (de otra dia) (+ (de fila dia) 1))`), y eso sobrevive intacto a las
  tres arquitecturas.

---

## 12. La frontera con "resolver"

Esta es la pregunta que más se repite al proponer un dominio nuevo con
restricciones (un horario, un reparto, una asignación de recursos), y tiene
una respuesta fija, documentada en dos sitios distintos con la misma
conclusión.

El caso Saúl Delgado (`exploracion/saul.lisp`) separa explícitamente dos
preguntas que un enunciado de horario suele mezclar en una sola frase:

> *"(A) Cómo ES una asignación válida... Esto ES una situación tabular:
> datos, derivaciones, marcado.*
>
> *(B) ENCONTRAR una asignación que cumpla las reglas duras a la vez y que
> además prefiera las blandas. Esto es un problema de satisfacción de
> restricciones... El lenguaje no tiene motor de búsqueda ni optimizador, y
> no es un descuido: es la decisión 1 de `00-CONTEXTO.md`, tomada por el
> tutor el 2026-09-09 —'la web y el móvil solo visualizan la situación, no
> la resuelven'— aplicada aquí sin excepción, porque no hay ninguna
> excepción escrita para 'restricción dura' en vez de 'blanda'."*

Y sobre las restricciones blandas en concreto:

> *"Esto es lo que NO se puede pedirle al lenguaje: elegir el horario que
> más las cumpla. Lo único que se puede hacer —y es lo que hacen estas dos
> marcas— es SEÑALAR cuando el horario que alguien ya escribió no las
> cumple."*

El análisis de la conversación del 2026-09-21 que deslindó esta tesis de
la de Ray/Bullet (que sí construye un motor de restricciones) lo confirma
sin ambigüedad:

> *"¿La idea es que Bullet cree el motor que resuelve las restricciones y yo
> me encargue de que el lenguaje pueda expresar las restricciones? La
> respuesta... es no. Expresar las restricciones es de Ray, y no solo el
> motor: el lenguaje de restricciones también es suyo. Lo de Dayan es el
> lenguaje del que sale la interfaz —qué tablas hay, cómo se recorren, qué
> se resalta y por qué—."*

Con la equivalencia exacta entre los dos lenguajes:

> *"`marca` con condición por fila ↔ Restricción dura o blanda. La misma
> condición. Una señala lo que pasó; la otra impide que pase... la
> diferencia entre las dos tesis no está en el lenguaje de la condición,
> sino en qué se hace con ella —mostrarla o satisfacerla—."*

**En la práctica, esto significa:** si un dominio nuevo trae reglas duras y
blandas y pide que el sistema *encuentre* el reparto (un horario, una
asignación de recursos, un cuadrante), la parte de encontrarlo no es de este
lenguaje — tiene que venir ya resuelta (a mano, o de otro sistema, como el
de Ray). Lo que sí es de este lenguaje es todo lo demás: los datos, cada
regla dura y blanda expresada como `marca` (para señalar si el reparto que
llegó las cumple o no), y las vistas que lo muestran — exactamente el mismo
patrón que ya se ejecutó de verdad con Saúl Delgado.

---

## 13. Glosario rápido

| Término | Qué es |
|---|---|
| **Situación** | Una descripción completa: colecciones, marcas, vistas, parámetros |
| **Colección** | Una tabla de filas con una clave |
| **Campo fijo / entrada / derivado** | Se escribe al generar / lo escribe el usuario / se calcula |
| **Marca** | Una condición con nombre y severidad que señala un estado — nunca un color a secas |
| **Vista** | Cómo se recorre y presenta una colección: lista, tabla cruzada, particionada, agrupada, filtrada |
| **Tabla cruzada** | Una vista con `:filas`/`:columnas`/`:muestra` — la rejilla, presentada, nunca almacenada como matriz |
| **Capacidad** | Una clase componible que una arquitectura puede o no cumplir de forma nativa |
| **Cumple / emula / degrada / rechaza** | Los cuatro grados con que una arquitectura responde a algo que la descripción pidió |
| **Informe de conformidad** | El reporte, por cada ejecución, de qué pidió la descripción y cómo lo resolvió cada arquitectura |
| **Arquitectura** | Un destino de salida (texto, Excel, web...) — nunca sabe que existen las otras |
| **Protocolo** | El contrato de 13 operaciones y 19 capacidades que separa el núcleo de cualquier arquitectura |

---

## 14. Dónde seguir

Todo lo que sigue está en el repositorio.

- [`../ejemplos/README.md`](../ejemplos/README.md) — las descripciones
  reales de la facultad, cada una junto a su archivo `.lisp` y a los
  resultados ya generados (Excel, página web, texto), para abrirlos sin
  instalar nada.
- [`01-PARA-ENTENDER.md`](01-PARA-ENTENDER.md) — el porqué, sin exigir
  Common Lisp.
- [`02-ARQUITECTURA.md`](02-ARQUITECTURA.md) — el diseño completo del
  sistema.
- [`tesis.pdf`](tesis.pdf) — el documento de tesis.
- [`alcance/`](alcance/) y `../exploracion/*.lisp` — los experimentos de la
  sección 11, con el código y el informe completo de cada uno.
- [`../README.md`](../README.md) — los comandos, la estructura de
  directorios, la inversión de capacidades.
