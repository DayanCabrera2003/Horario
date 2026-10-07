<!-- Informe generado por el experimento de alcance del 2026-09-21. -->

> **ESTADO PREVIO AL ARREGLO.** Este informe describe el sistema tal como estaba
> ANTES de los cambios que el propio experimento motivo. Varios de los defectos
> que reporta ya no se reproducen: se corrigieron esa misma noche. Se conserva
> sin tocar porque es la evidencia de lo que el metodo encontro, y reescribirlo
> borraria el rastro. Lo que se hizo con cada hueco esta en el capitulo 8 de la
> tesis y en `Horario/pruebas/alcance.lisp`.


## Presupuesto y ejecucion de un proyecto

**Veredicto:** CABE-A-MEDIAS

Archivo escrito y ejecutado: `/home/dayancc/Documents/Universidad/Tesis/Proyecto/Horario/exploracion/presupuesto.lisp`
Artefactos generados: `/home/dayancc/Documents/Universidad/Tesis/Proyecto/Horario/exploracion/salida/` (`presupuesto.txt`, `presupuesto-plano.json`, `presupuesto.xlsx`, `presupuesto.html`, `presupuesto-esperado.json`).

---

### Qué se pudo expresar

Lo que el corpus si pedia, entero y sin deformar:

- **Partidas y gastos como dos colecciones**, con clave, orden declarado y `(:crece)` en el libro de gastos.
- **Imputacion validada sin bloquear**: `(campo partida :rol entrada :dominio (los codigo de partidas) :al-violar advertir)`.
- **Gasto por partida** con un agregado condicionado: `(suma importe de gastos :donde (= partida (de fila codigo)))`.
- **Lo que queda** y **el porcentaje ejecutado**, este ultimo con guarda de division por cero via `(si (vacio? ...) 0 ...)`.
- **Trae el concepto de la partida** al libro de gastos con `la-fila-de` + `el ... de ... :si-no`.
- **Las dos marcas pedidas**, con severidad y explicacion en palabras, y el umbral como parametro del dominio:

```lisp
(marca al-limite
  :en        partidas
  :cuando    (y (>= (de fila ejecutado) (parametro umbral-aviso))
                (<= (de fila gastado) (de fila presupuestado)))
  :sobre     (ejecutado)
  :severidad advertencia
  :explica   (texto "Lleva ejecutado el " (de fila ejecutado) " por ciento"))
```

Y los dos extras, **con matices importantes**:

- **La jerarquia SI se expresa, y SI hace falta recursion.** Un campo derivado que se suma a si mismo en las filas hijas:

```lisp
(campo gastado :rol derivado :tipo numero :etiqueta "Gastado"
       (+ (de fila gasto-directo)
          (suma gastado de partidas :donde (= padre (de fila codigo)))))
```

  El analisis estatico lo acepta (`comprobar-ciclos` solo mira dependencias **dentro de la misma fila**, y esta pasa por un agregado), y el evaluador de referencia lo resuelve bien a tres niveles por memorizacion perezosa. **No hubo que anadir nada al lenguaje.** Esto es un resultado positivo y no lo esperaba.

- **El saldo acumulado del libro** con `(+ (de fila importe) (de (anterior fila) acumulado))`. Correcto en el evaluador de referencia.

- **El total general cabe, pero deformado**, de dos maneras, las dos malas (ver abajo).

---

### Qué NO se pudo, y por qué

#### 1. El valor que no pertenece a ninguna fila — NO ENCAJA EN EL MODELO (caro)

El modelo tiene exactamente tres sitios donde puede vivir un valor: un **campo** (que pertenece a una fila de una coleccion), un **parametro** (constante) y una **marca** (condicion por fila). Un total general no es ninguna de las tres cosas.

Probé las dos unicas salidas que el lenguaje deja, y las dos deforman el problema:

**(a) Repetirlo en cada fila.** Cabe, y se ve el destrozo en el artefacto: la columna "Gasto total (todas)" imprime `18600` seis veces, una por partida. En la hoja de calculo son seis formulas identicas. El lector no puede distinguir "propiedad de esta fila" de "propiedad de la situacion".

**(b) Fabricar una coleccion de una sola fila.** Hay que inventar un campo (`titulo`) que no significa nada solo para tener clave, y **hay que suministrar la fila inventada en los datos de ejecucion**:

```lisp
(cons (funcall n "resumen")
      (list (list (cons (funcall n "titulo") "Proyecto completo"))))
```

Si se olvida esa linea, `filas-de` devuelve `nil`, la coleccion queda vacia y **el total desaparece en silencio**, sin error ni aviso. Un dato de invencion del autor gobierna si un valor del dominio existe.

Consecuencia directa: **una marca sobre el total tampoco se puede decir.** `:sobre` es obligatorio y nombra campos (`"La marca SOBREGIRADO no dice :SOBRE que campos senala"`), y `marca-aplica-p` necesita una coleccion. "El proyecto entero se paso" solo se dice marcando la fila fantasma.

Y el parametro tampoco sirve de escape: `:valor` se emite como codigo Lisp literal, no como expresion del dominio. Probado:

```
(parametro total :valor (suma importe de gastos))  ->  RECHAZA: The variable IMPORTE is unbound.
```

**Qué haria falta:** un nodo estructural nuevo en el nucleo (`resumen` o `total`: nombre, etiqueta, expresion, y la posibilidad de llevar marca), un sitio en `vista` donde decir donde cae, y una operacion mas en el protocolo para que cada arquitectura lo emita (una fila de totales, un `<tfoot>`, un parrafo). Toca nucleo, protocolo y las tres arquitecturas. **Caro.**

#### 2. La jerarquia es un arbol y el lenguaje no sabe que lo es — NO ENCAJA EN EL MODELO (caro)

`padre` es un campo de texto como cualquier otro. Nada declara que apunte a `codigo` de su propia coleccion, nada prohibe un ciclo, y por lo tanto el analisis estatico no puede comprobarlo. Con datos ciclicos (1100 hija de 1110 y 1110 hija de 1100):

```
ANALISIS CON JERARQUIA CICLICA -> sin problemas
EVALUA -> El campo derivado PARTIDAS.GASTADO depende de si mismo
```

El error llega **en tiempo de evaluacion con datos reales**, que es el peor momento posible, y es justo lo que el analisis estatico existe para evitar. En Excel, el mismo dato produciria una referencia circular sin explicacion.

**Qué haria falta:** declarar la relacion (`(:jerarquia padre :hacia codigo)` o una referencia de campo a campo tipo clave foranea), para que el analisis pueda exigir aciclidad y para que las arquitecturas puedan planificar el orden de calculo. Es un hecho del dominio hoy indecible. **Caro** (nodo nuevo + regla de analisis), aunque mas barato que el punto 1.

#### 3. No hay orden de computo entre filas, y cada arquitectura se lo inventa — NO ENCAJA EN EL MODELO (caro)

Este es el hallazgo mas grave, porque **rompe la afirmacion central de la tesis**: la misma descripcion NO dio el mismo resultado en las tres arquitecturas.

- **Evaluador de referencia:** memoriza bajo demanda. Correcto para cualquier forma aciclica.
- **Excel/LibreOffice:** delega en el grafo de dependencias de celdas. Correcto aqui (ver abajo), pero por suerte, no por diseno.
- **Web:** `recalcularTodo()` hace **una sola pasada hacia delante** sobre el arreglo (`for (const nombre in D) D[nombre].forEach(f => calcular(nombre, f))`). Una fila que depende de una fila posterior lee `undefined`, que `V()` convierte en `''` y `N()` en `0`. Sin excepcion, sin aviso: **un cero plausible**.

Como las partidas van ordenadas por codigo, el padre `1000` se calcula antes que sus hijas y sale `0`. Verificado contra el oraculo:

```
FALLA  presupuesto.html: 102 comprobaciones, 6 discrepancias
   partidas[0].gastado    esperado 18600  obtenido 0
   partidas[0].queda      esperado 1400   obtenido 20000
   partidas[0].ejecutado  esperado 93     obtenido 0
   partidas[1].gastado    esperado 8400   obtenido 0
   partidas[1].queda      esperado -400   obtenido 8000
   partidas[1].ejecutado  esperado 105    obtenido 0
```

Y el informe de conformidad de la web dice **"8 nativas, 0 emuladas, 0 degradadas, 0 rechazadas"**. El mecanismo de capacidades no ve nada: `requerimientos` no mira si un agregado recorre la *misma* coleccion del campo que se deriva.

**Qué haria falta:** una capacidad nueva (`con-derivacion-entre-filas`) que `requerimientos` detecte cuando un campo derivado agrega sobre su propia coleccion o usa `vecino`, para que la web la declare emulada (iterando a punto fijo u ordenando topologicamente) en vez de dar un numero falso. La deteccion es barata; **que el lenguaje no tenga forma de expresar dependencia entre filas es lo caro**, y es estructural: el nucleo prohibe coordenadas a proposito, y "calcula las hijas primero" suena a coordenada aunque no lo sea.

#### 4. El redondeo no existe — FALTA UNA CONSTRUCCION (barato, pero obligatorio)

En el dominio, "% ejecutado" es un entero. El lenguaje no tiene como decirlo:

```
(redondear (/ 100 3))    -> RECHAZA: No se como leer la forma (REDONDEAR (/ 100 3)).
(entero-de (/ 100 3))    -> RECHAZA
(absoluto (- 0 5))       -> RECHAZA
(promedio importe de gastos) -> RECHAZA
```

**Tuve que retorcer los datos** para que todos los porcentajes salieran enteros. Con un gasto de 5900 sobre 6000 el evaluador devuelve una fraccion de Lisp:

```
PORCENTAJE NO EXACTO -> 295/3  (como texto: "295/3")
```

La hoja escribiria `98,333...` y JavaScript `98.33333333333333`. Es decir: **cualquier presupuesto realista rompe la conformidad entre las tres arquitecturas**, y la causa es la falta de un nodo unario. Barato de arreglar (`:operacion`-style o un nodo `redondeo` + tres emisores: `ROUND`, `Math.round`, `round`), pero hoy es un agujero real. Lo mismo `:promedio` en `agregado` (un valor mas en el `ecase`) y `absoluto`.

#### 5. Tres defectos de la arquitectura de hoja de calculo que este dominio destapa — BARATOS, pero silenciosos

**(a) Un agregado sin `:donde` emite COUNTA, sea cual sea la operacion.** `(suma importe de gastos)` produce:

```
I4 =COUNTA(Gastos!$A$4:$A$28)
```

Es decir, una **suma** emitida como un **conteo**. LibreOffice devuelve `5` donde el oraculo dice `18600`, y el error se propaga: `Disponible = 20000 - 5 = 19995`. La rama culpable de `excel/formula.lisp` ignora `(nucleo:operacion e)`:

```lisp
((null campo-criterio)
 (if (null (nucleo:condicion e))
     (format nil "COUNTA(~a)" ...)   ; <- vale para :cuantas, no para :suma
     (error ...)))
```

El corpus nunca escribe un agregado sin condicion, y por eso nadie lo habia visto. El informe de conformidad dice "cumple".

**(b) El valor por defecto de `vecino` se emite como `""` y se usa en aritmetica.** La primera fila del acumulado produce `=IF($A4="","",($C4+""))`, que en Calc es `#VALUE!`, y el error baja por toda la columna:

```
Gastos!E4  esperado 5800.0   obtenido '#VALUE!'
Gastos!E8  esperado 18600.0  obtenido '#VALUE!'
```

El evaluador de referencia hace `como-numero(nil) = 0` y la web hace `N('') = 0`; solo la hoja discrepa. `VECINO` esta en el algebra pero **ningun ejemplo del corpus lo usa**: es codigo que nunca se habia ejecutado de punta a punta.

**(c) Lo que Excel no sabe traducir sale como `error` de Lisp, no como linea "rechaza" del informe.** Un agregado con desigualdad —`(suma importe de apuntes :donde (> importe 1000))`, perfectamente legal en el lenguaje— da:

```
texto    -> emite
excel    -> FALLA: Esta hoja de calculo solo sabe agregar con un criterio de
            igualdad sobre un campo. La condicion de suma es mas complicada.
web      -> emite
```

El mensaje es excelente, pero **aborta la materializacion** en vez de registrarse como `:rechaza` en el informe de conformidad. La cuarta respuesta de las cuatro que el informe promete no tiene ningun camino que llegue a ella.

---

### Resultado de la ejecucion

**Analisis estatico:** `Sin problemas.`

**Evaluador de referencia** (correcto en todo, incluidos los tres niveles de jerarquia):

```
partidas
  codigo=1000  concepto=Proyecto completo  padre=  presupuestado=20000  gasto-directo=0     gastado=18600  queda=1400   ejecutado=93   total-del-proyecto=18600   [marcas: al-limite]
  codigo=1100  concepto=Equipamiento       padre=1000  presupuestado=8000   gasto-directo=0     gastado=8400   queda=-400   ejecutado=105  total-del-proyecto=18600   [marcas: sobrepasada]
  codigo=1110  concepto=Computadoras       padre=1100  presupuestado=6000   gasto-directo=6000  gastado=6000   queda=0      ejecutado=100  total-del-proyecto=18600   [marcas: al-limite]
  codigo=1120  concepto=Mobiliario         padre=1100  presupuestado=2000   gasto-directo=2400  gastado=2400   queda=-400   ejecutado=120  total-del-proyecto=18600   [marcas: sobrepasada]
  codigo=1200  concepto=Personal           padre=1000  presupuestado=10000  gasto-directo=9600  gastado=9600   queda=400    ejecutado=96   total-del-proyecto=18600   [marcas: al-limite]
  codigo=1300  concepto=Viajes             padre=1000  presupuestado=2000   gasto-directo=600   gastado=600    queda=1400   ejecutado=30   total-del-proyecto=18600

gastos
  fecha=2026-01-15  partida=1110  importe=5800  concepto=Computadoras  acumulado=5800
  ...
  fecha=2026-03-18  partida=1110  importe=200   concepto=Computadoras  acumulado=18600

resumen
  titulo=Proyecto completo  total-presupuestado=20000  total-gastado=18600  total-disponible=1400  cuantos-gastos=5
```

**Texto plano:** correcto al 100% (usa el evaluador de referencia). Las marcas degradan a palabras: `Se paso del presupuesto en 400`, `Lleva ejecutado el 93 por ciento`. Se ve el destrozo del total repetido: la columna "Gasto total (todas)" con `18600` en las seis filas.

**Hoja de calculo** (`materializar.py` + LibreOffice headless + relectura):

```
FALLA  presupuesto.xlsx: 84 celdas comprobadas, 13 discrepancias
   Partidas!I4..I9        esperado 18600.0  obtenido 5.0        (COUNTA en vez de SUM)
   Gastos!E4..E8          esperado 5800.0.. obtenido '#VALUE!'  (acumulado, "" + numero)
   Total del proyecto!C4  esperado 18600.0  obtenido 5.0
   Total del proyecto!D4  esperado 1400.0   obtenido 19995.0
```

**Pero la jerarquia recursiva SI funciono en la hoja.** La formula generada es

```
F4 =($E4+SUMIF(Partidas!$C$4:$C$9,$A4,Partidas!$F$4:$F$9))
```

—un `SUMIF` cuyo rango de suma **contiene la propia celda**— y LibreOffice la resuelve sin marcar referencia circular. Los valores releidos fueron `18600, 8400, 6000, 2400, 9600, 600`: todos correctos. Es un exito, pero un exito que depende de como Calc granula el grafo de dependencias. No esta declarado ni comprobado en ninguna parte, y no puedo afirmar que Excel de Microsoft se comporte igual.

Formatos condicionales emitidos correctamente, con el parametro ya resuelto:
`AND(($H4>=90),($F4<=$D4))` sobre `H4:H9`.

**Pagina web:** las 6 discrepancias del punto 3. El resto (acumulado, busquedas, totales, marcas, dominios) coincide.

**Informes de conformidad:** texto `2 nativas / 1 emulada / 5 degradadas`; excel `7 nativas / 1 emulada`; web `8 nativas / 0 degradadas`. **Ninguno de los tres menciona nada de lo que salio mal.**

---

### Lo que este dominio le pide al lenguaje y el corpus no le pedia

1. **Un valor de la situacion entera, no de una fila.** Los tres libros de la facultad son listados: todo lo que se calcula es por renglon. Un presupuesto tiene un fondo total, y ese numero es el que el jefe mira primero. El modelo no tiene donde ponerlo. Es la carencia mas clara y la mas cara de tapar, porque es un nodo estructural nuevo, no una funcion mas.

2. **Una relacion de una coleccion consigo misma.** El corpus relaciona coleccion con coleccion (citaciones -> tesis, asignacion -> profesores). Una partida que es subpartida de otra es una relacion **reflexiva**, y con ella aparecen tres cosas nuevas de golpe: profundidad indefinida, posibilidad de ciclo, y dependencia de calculo entre filas de la misma tabla. El lenguaje deja escribirla porque `padre` es un texto cualquiera, pero no la *sabe*, y por eso no puede ni comprobarla ni planificar el orden de calculo.

3. **Un orden de computo que no es el orden de lectura.** El corpus nunca lo necesita: cada fila se calcula con sus propios datos o con otra tabla ya escrita. En una jerarquia, las hijas tienen que calcularse antes que el padre, y eso no se puede decir. Es la tension mas interesante del diseno: el nucleo prohibio las coordenadas para no dejar entrar el modelo de la rejilla, y con ellas se fue tambien la nocion de *precedencia*, que no es una coordenada. La consecuencia medida es que **la misma descripcion dio tres resultados distintos**.

4. **Aritmetica de presentacion: redondeo.** El corpus cuenta turnos y profesores — enteros que salen enteros. Un presupuesto divide dinero, y ahi la fraccion exacta de Lisp, el decimal de IEEE de JavaScript y el formato de celda de Calc dejan de coincidir. Mientras no haya un nodo de redondeo, la conformidad entre arquitecturas solo se sostiene con datos elegidos a mano, como tuve que hacer aqui.

5. **Ejercitar las construcciones que el corpus declara pero no usa.** `VECINO` y el agregado sin condicion estan en el algebra, justificados en los comentarios, y ninguno de los dos ejemplos del corpus los ejecuta. Los dos fallan en cuanto se usan de verdad, y fallan **en silencio o con un `#VALUE!`**, no con un mensaje del sistema. Sugiere que el corpus, como oraculo, mide la cobertura de la *sintaxis declarada* mucho peor de lo que parece: hacen falta casos de prueba por construccion, no solo por documento.

6. **Que el informe de conformidad sepa mentir menos.** Hoy solo registra lo que `requerimientos` sabe pedir. Un dominio que pide algo que el mecanismo no nombra —derivacion entre filas— sale con todo en verde mientras produce numeros falsos. El informe es la evidencia que esta tesis presenta y que las anteriores no tienen; conviene que su silencio signifique algo.