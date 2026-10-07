<!-- Informe generado por el experimento de alcance del 2026-09-21. -->

> **ESTADO PREVIO AL ARREGLO.** Este informe describe el sistema tal como estaba
> ANTES de los cambios que el propio experimento motivo. Varios de los defectos
> que reporta ya no se reproducen: se corrigieron esa misma noche. Se conserva
> sin tocar porque es la evidencia de lo que el metodo encontro, y reescribirlo
> borraria el rastro. Lo que se hizo con cada hueco esta en el capitulo 8 de la
> tesis y en `Horario/pruebas/alcance.lisp`.


## Control de inventario de un almacén

**Veredicto:** CABE-FORZADO

---

**Qué se pudo expresar.**

Todo esto pasó el análisis, lo calculó el evaluador de referencia y se materializó en la arquitectura web de forma 100% nativa (9 capacidades, 0 emuladas):

- Artículos con código, nombre, unidad y stock mínimo, como colección con `(:clave codigo)` y `(:crece)`.
- Movimientos con fecha, artículo, tipo, cantidad y proveedor, ordenados por fecha con `(:orden fecha)`.
- Existencias por artículo como resta de dos agregados con filtro compuesto — correcto en el evaluador:
  ```lisp
  (campo entradas :rol derivado :tipo entero
         (suma cantidad de movimientos
               :donde (y (= articulo (de fila codigo)) (= tipo "entrada"))))
  ```
- Las dos marcas pedidas (`bajo-minimo`, `agotado`), con severidad distinta y concordancia de plural: "Falta 1 para llegar al mínimo" / "Faltan 10 para llegar al mínimo". Ambas disparan a la vez en el artículo agotado, que es lo correcto.
- Anotar movimientos nuevos eligiendo el artículo de una lista: `:rol entrada` + `:dominio (los codigo de articulos)` + `:al-violar advertir`. Nativo en web, desplegable en Excel, nota al pie en texto.
- Autocompletado de la descripción del artículo por búsqueda de clave (idéntico al tribunal del corpus) y marca de código inexistente:
  ```lisp
  (campo denominacion :rol derivado
         (el nombre de (la-fila-de articulos :donde (= codigo (de fila articulo))) :si-no ""))
  ```
- **Sorpresa positiva:** el saldo por artículo en el momento de cada movimiento (el kardex, la pregunta central de un almacén) **sí es expresable**, con un agregado auto-referente sobre la misma colección — siempre que la fecha sea un número (sonda 6, verificada: 20, 5, 9 para T-01):
  ```lisp
  (campo saldo :rol derivado
         (suma firmada de movs :donde (y (= articulo (de fila articulo))
                                         (<= dia (de fila dia)))))
  ```

---

**Qué NO se pudo, y por qué.**

**1. Agrupar: "una fila por proveedor". NO ENCAJA EN EL MODELO (caro).**
"Cuántos artículos distintos movió cada proveedor" pide una colección cuyas filas *son* los valores distintos de una columna de otra colección. El lenguaje sabe calcular un valor por fila, pero no sabe de dónde salen las filas: toda colección es `:origen :declarada`. Hay que declarar `proveedores` a mano y mantenerla sincronizada con lo que el operario escriba — es decir, el documento puede quedar en un estado donde un proveedor existe en los movimientos y no tiene fila. Lo llamativo: `nucleo/modelo.lisp` **ya documenta la forma que falta** — `(origen ":DECLARADA, o (:UNA-FILA-POR campo :DE coleccion)...")` — pero `compilar-coleccion` escribe siempre `:origen :declarada`, así que no existe en el lenguaje. Haría falta una forma `(coleccion proveedores (:una-fila-por proveedor :de movimientos) ...)`, y eso toca núcleo, análisis, evaluador y las tres arquitecturas.

**2. La enumeración literal. FALTA UNA CONSTRUCCIÓN (barato).**
"Entrada o salida" son dos palabras del dominio, no una tabla. El único constructor de dominio es `(los campo de coleccion)`. Verificado (sonda 1):
```
:dominio ("entrada" "salida")  ->  No se como leer la forma ("entrada" "salida").
```
Hubo que inventar la colección `clases-de-movimiento` de una columna y dos filas, que en el almacén no existe y que aparece como una pestaña más en el libro generado. Bastaría con admitir `(uno-de "entrada" "salida")` como expresión de conjunto.

**3. El rol es de la columna, no de la celda. NO ENCAJA EN EL MODELO (caro).**
Un libro de movimientos es un registro de sólo-añadir: lo ya anotado no se toca, lo nuevo se escribe. El lenguaje sólo sabe decir `:fijo` (se escribe al generar, se bloquea) o `:entrada` (lo escribe el usuario) **por columna**, y `:crece` no modifica el rol. Consecuencia concreta: como todas las columnas de `movimientos` son `:entrada`, no hay ninguna `:fijo`, y `(:datos ...)` — que sólo transporta valores de campos fijos — no puede llevar el histórico; en Excel el histórico se escribe pero queda desbloqueado y editable. El corpus nunca lo pidió porque sus colecciones que crecen tienen un esqueleto fijo pregenerado (día/momento/local) y una sola columna editable.

**4. La fecha es decorativa. FALTA UNA CONSTRUCCIÓN, pero en el núcleo (medio).**
Existe `:tipo fecha`, y ordenar por fecha funciona (`menor-p` compara cadenas). Comparar fechas en una expresión, no (sonda 4):
```
(suma cantidad de movs :donde (<= fecha "2026-03-05"))
  ->  The value |2026-03-01| is not of type REAL
```
`como-numero` hace `read-from-string` sobre la cadena y devuelve un símbolo, que luego entra en `<`. Así que "existencias a fecha de corte" y "movimientos del último mes" — las dos preguntas más normales de un almacén — no se pueden escribir salvo codificando la fecha como entero. El tipo `:FECHA` está declarado en el modelo y no tiene semántica en ninguna parte.

**5. `anterior` no sabe particionar, y lo peor es que no protesta. FALTA UNA CONSTRUCCIÓN (barato) + un agujero de análisis.**
El saldo corriente de un kardex es "lo del renglón anterior *del mismo artículo*". `VECINO` recorre la colección entera ordenada. Intenté decirlo y (sonda 3):
```
(de (anterior fila :donde (= grupo (de fila grupo))) acum)
  ->  compila sin protestar; el nodo es vecino con direccion anterior y
      variable fila: el :DONDE se descarto en silencio
```
`compilar-acceso` lee `(first origen)` y `(second origen)` y tira el resto. El resultado es una descripción que se lee como correcta, pasa el análisis y da números mal. Es exactamente el fallo que la tesis le reprocha a 2026 (la figura 6.2 con los colores corridos), reaparecido en otro sitio. Lo barato es rechazarlo; lo bueno sería `(:particionado-por campo)` en el orden de la colección.

**6. Una afirmación sobre la colección entera. FALTA UNA CONSTRUCCIÓN (medio).**
"El almacén está vacío", "el valor total supera el tope" no son marcas de fila. Una marca siempre se evalúa fila a fila sobre una colección (sonda 7: el análisis la acepta y luego la repite en cada fila). La salida es inventar una colección `resumen` de una sola fila, que es otra tabla que no existe en el almacén.

**7. La concordancia sólo sabe palabras escritas a mano. FALTA UNA CONSTRUCCIÓN (barato).**
En el plan del grupo el sustantivo siempre es "turno". En un almacén el sustantivo está en los datos: caja, metro, resma, par. `hacer-concordancia` recibe `:singular ,(second resto)` sin compilar, así que (sonda 2):
```
(plural (de fila cuantos) (de fila unidad) (de fila unidad))
  ->  The variable FILA is unbound.
```
No se puede escribir "Faltan 5 resmas". `singular`/`plural` deberían ser expresiones, como `cantidad`.

---

**Resultado de la ejecución.**

Archivo: `/home/dayancc/Documents/Universidad/Tesis/Proyecto/Horario/exploracion/inventario.lisp` (no se tocó ningún archivo del sistema). Salidas en `.../exploracion/salida/`.

Versión A, la natural. `Analisis: sin problemas.` Evaluador:
```
  -- articulos --
   codigo=T-01  ... minimo=10  entradas=24  salidas=15  existencias=9
       MARCAS: [bajo-minimo/advertencia: Falta 1 para llegar al minimo]
   codigo=C-02  ... minimo=50  entradas=100 salidas=60  existencias=40
       MARCAS: [bajo-minimo/advertencia: Faltan 10 para llegar al minimo]
   codigo=P-03  ... minimo=5   entradas=10  salidas=10  existencias=0
       MARCAS: [bajo-minimo/advertencia: Faltan 5 para llegar al minimo]
               [agotado/problema: No queda ninguna existencia]
   codigo=G-04  ... minimo=10  entradas=12  salidas=0   existencias=12
  -- movimientos --
   ... fecha=2026-03-09 articulo=X-99 ... denominacion=  firmado=-1  acumulado=60
       MARCAS: [articulo-desconocido/advertencia: Ese codigo no esta en el listado de articulos]
  -- proveedores --
   proveedor=Ferreteria Sur   articulos-movidos=2
   proveedor=Cables SA        articulos-movidos=1
   proveedor=Papelera Centro  articulos-movidos=1
```
Las tres arquitecturas, versión A:
```
[texto] FALLA: La arquitectura texto no puede con con-conteo-de-distintos.
  texto plano no tiene nada parecido a con-conteo-de-distintos

[excel] FALLA: Esta hoja de calculo solo sabe agregar con un criterio de
igualdad sobre un campo. La condicion de suma es mas complicada.

[web] materializa en exploracion/salida/inventario.html
  9 nativas, 0 emuladas, 0 degradadas, 0 rechazadas
```
Dos cosas que importan de ahí:

- El fallo de Excel es un `error` crudo de `excel/formula.lisp`, **no pasa por el mecanismo de carencias**: no hay informe, no hay `:rechaza` con nota, no hay capacidad que nombrar. El propio comentario del núcleo dice que las variantes de `SUMAR.SI` con varios criterios están en el corpus (`departamento/hoja_cobertura.py`), pero el emisor sólo implementa `igualdad-simple`. El lenguaje admite un filtro que su arquitectura estrella no sabe traducir, y se entera al final y a golpe de excepción.
- Texto rechaza el documento **entero** por una sola columna, aunque texto congela valores ya calculados por el evaluador y no necesita contar distintos nada. Comprobado (sonda 8): la misma clase de situación sin esa columna materializa sin problema. `requerimientos` pide la capacidad por la *forma de la descripción*, no por lo que la arquitectura va a hacer de verdad.

Versión B (deformada: se sustituyen los dos agregados por una columna `firmada` con el signo metido dentro, para que quede un solo criterio de igualdad). Excel ya materializa: `7 nativas, 25 emuladas`. Y la fórmula de existencias sale bien:
```
E4 =IF($A4="","",SUMIF(Movimientos!$B$4:$B$24,$A4,Movimientos!$F$4:$F$24))
```
Pero la de proveedores es **la misma en todas las filas** y no menciona al proveedor por ninguna parte:
```
B4 =IF($A4="","",SUMPRODUCT((Movimientos!$B$4:$B$24<>"")/COUNTIF(Movimientos!$B$4:$B$24,Movimientos!$B$4:$B$24&"")))
B5 =IF($A5="","",SUMPRODUCT((Movimientos!$B$4:$B$24<>"")/COUNTIF(...)))
```
La rama `:distintas` de `excel/formula.lisp` calcula `campo-criterio` y **lo descarta**. El oráculo dice 2, 1, 1; esa fórmula da 5 (los cinco códigos distintos del libro) en las tres filas. Y el informe de conformidad lo declara `emula` con una nota larga y tranquilizadora. Es el caso que el propio `protocolo/carencia.lisp` define como el que hay que rechazar y no degradar: *"se rechaza cuando el resultado PARECERIA correcto y no lo seria"*. Aquí no lo rechaza: miente. El juego de conformidad no lo caza porque compara informes y capacidades, no valores de fórmula contra el evaluador.

---

**Lo que este dominio le pide al lenguaje y el corpus no le pedía.**

1. **Que las filas se deriven, no sólo los valores.** Los tres libros de la facultad tienen todas sus tablas dadas de antemano: los grupos, las asignaturas, las tesis, los locales. Un almacén tiene una tabla dada (artículos) y una que crece sin forma conocida (movimientos), y las preguntas interesantes son *agrupamientos de la que crece*: por proveedor, por mes, por artículo. Es la diferencia entre un lenguaje de **documentos** y un lenguaje de **registros**. Ahora mismo el álgebra sabe ir de muchas filas a un valor (`agregado`) y de muchas a una (`busqueda`), pero no de muchas a muchas-menos. Es el hueco de forma más grande que encontré, y el modelo ya lo tiene previsto en la ranura `origen`.

2. **Tiempo.** El corpus es un horario: tiene momentos, pero son etiquetas de una rejilla fija ("09:00", "lunes"), nunca cantidades que se comparen. Un almacén es una serie temporal: el saldo *en un instante*, el corte de mes, el último movimiento. El álgebra aguanta la pregunta (sonda 6 lo demuestra), pero la coerción numérica no tiene nada para fechas y el tipo `:FECHA` no significa nada en ningún sitio. Es barato de arreglar y desbloquea media clase de dominios.

3. **Antigüedad de la fila.** En la facultad, una fila o está pregenerada o la escribe el usuario, y eso no cambia. En un registro, la misma columna es histórico intocable arriba y captura abajo. El rol de campo — que es la mejor idea del modelo y lo que ninguna tesis anterior tenía — está dimensionado por columna y aquí se queda corto por una dimensión.

4. **El plural con sustantivo variable.** La unidad de medida es un dato, no una palabra del programador. `concordancia` nació de "Falta 1 profesor" y se quedó con los sustantivos fijados en la descripción.

5. **Y un aviso metodológico para la tesis, más que para el lenguaje:** el corpus está tan bien cubierto que el emisor de Excel implementa exactamente las formas del corpus y ni una más — un solo criterio de igualdad en los agregados, `:distintas` sin filtro. Al salir del corpus, la arquitectura de rejilla falla de las dos maneras que el propio diseño declara inaceptables: **excepción cruda fuera del mecanismo de carencias** (agregado con dos criterios) y **degradación silenciosa a un valor incorrecto presentada como emulación** (conteo de distintos con filtro). Ninguna de las dos la detecta el juego de conformidad actual, porque compara informes y no compara los valores que las fórmulas producirían contra el oráculo del evaluador. Una prueba de conformidad que evaluara las fórmulas emitidas —aunque fuera sólo para las formas que el backend dice cubrir— habría cazado las dos.