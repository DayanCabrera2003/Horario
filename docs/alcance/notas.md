<!-- Informe generado por el experimento de alcance del 2026-09-21. -->

> **ESTADO PREVIO AL ARREGLO.** Este informe describe el sistema tal como estaba
> ANTES de los cambios que el propio experimento motivo. Varios de los defectos
> que reporta ya no se reproducen: se corrigieron esa misma noche. Se conserva
> sin tocar porque es la evidencia de lo que el metodo encontro, y reescribirlo
> borraria el rastro. Lo que se hizo con cada hueco esta en el capitulo 8 de la
> tesis y en `Horario/pruebas/alcance.lisp`.


## Evaluacion de un curso

**Veredicto:** CABE-A-MEDIAS

---

### Qué se pudo expresar

Todo lo que sigue se escribió, pasó el análisis sin un solo problema, y se materializó en las tres arquitecturas:

- **Las tres colecciones y su cruce.** `evaluaciones` (nombre, peso), `calificaciones` (clave compuesta `(:clave estudiante evaluacion)`) y `estudiantes` (nombre, grupo). La clave compuesta se *declara* sin problema.
- **El peso traído por clave desde otra colección**, con su guarda de ausencia: `(el peso de (la-fila-de evaluaciones :donde (= nombre (de fila evaluacion))) :si-no 0)`. Se traduce a `IFERROR(VLOOKUP(...),0)` en la hoja y a `PROY(...)` en la página.
- **La media ponderada**, pero partida en dos columnas (ver más abajo). Funciona de verdad: LibreOffice recalculó el libro y dio 88, 52.75, 63.5, 53.5, exactamente lo que dice el evaluador de referencia y lo que calcula el JavaScript de la página.
- **El umbral como `(parametro umbral :tipo entero :rol entrada :valor 60)`**, referenciado con `(parametro umbral)` desde una derivación y desde una marca. Compila, pasa el análisis y el evaluador de referencia lo resuelve bien.
- **Aprobado/suspenso** como campo derivado con `si`.
- **La marca de suspenso con explicación en palabras**, incluida concordancia de número: `"Le faltan 7 puntos para aprobar"` / `"Le falta 1 punto"`.
- **La marca de evaluación sin calificar** (`vacio?` sobre un campo de entrada).
- **Cuatro vistas**, una por colección, con punto de entrada y agrupación por estudiante.
- **El conteo de aprobados**, pero metido en una colección inventada de una fila (ver más abajo).

---

### Qué NO se pudo, y por qué

#### 1. El parámetro editable NO existe en ningún destino. (No encaja en el modelo. Caro.)

Esto es lo más grave del informe, porque el lenguaje **acepta la declaración y después ninguna arquitectura la honra**. `:rol entrada` en un parámetro no significa nada hoy.

Las dos arquitecturas resuelven `ref-parametro` incrustando el literal:

```lisp
;; excel/formula.lisp:52  y  web/expresiones.lisp:48, identicos
(let ((p (nucleo:parametro-llamado (situacion plan) (nucleo:nombre e))))
  (texto-de-literal (and p (nucleo:valor p))))
```

Lo que sale de verdad:

```
hoja:    =IF($A4="","",IF(($C4>=60),"Aprobado","Suspenso"))
pagina:  "estado": (f) => ((N(V(f["final"])) >= N(60)) ? "Aprobado" : "Suspenso")
```

No hay celda para el umbral, no hay control en la página, no aparece ni una línea en el texto plano. Para cambiar 60 por 70 hay que regenerar el documento, que es justo lo que el dominio pedía evitar.

Además, `protocolo:requerimientos` no recorre `(nucleo:parametros situacion)` en absoluto: ninguna arquitectura llega a declarar si puede o no ofrecer un parámetro editable, así que el informe de conformidad sale limpio mientras la promesa se incumple en silencio. Es el mismo patrón que la tesis critica de 2026 (el color que se lo ponía el backend), invertido: aquí el lenguaje declara una intención y el backend la descarta.

**Qué haría falta:** un `con-parametro-editable` en la jerarquía de capacidades; que `requerimientos` pida esa capacidad por cada parámetro de rol `:entrada`; y que `emitir-expresion` de `ref-parametro` emita una *dirección* (una celda de una hoja de parámetros, un `<input>` con su `id`) en vez de un literal. Es caro porque toca protocolo, las tres arquitecturas y el plan de Excel — pero es estructural: mientras no exista, `parametro ... :rol entrada` es una declaración vacía.

#### 2. No se puede sumar una EXPRESIÓN, solo un CAMPO. (Falta una construcción. Barato-medio.)

La media ponderada es, literalmente, sumar `nota * peso` cruzando dos claves. Eso no se puede escribir. El nodo `agregado` guarda `campo` como *nombre de campo*, no como expresión, y el evaluador hace `(valor-de-campo entorno f (campo e))`.

Escribirlo como se piensa produce un error desconcertante — la macro lo acepta y revienta el análisis:

```
(suma (* (de candidata nota) (el peso de (la-fila-de evaluaciones ...))) de calificaciones ...)
  -> error: El campo estudiantes.final: la coleccion calificaciones no tiene un campo (* (de candidata nota) ...)
```

**Deformación aplicada:** materializar el producto como columna derivada en `calificaciones`:

```lisp
(campo peso   :rol derivado (el peso de (la-fila-de evaluaciones :donde (= nombre (de fila evaluacion))) :si-no 0))
(campo aporte :rol derivado (/ (* (de fila nota) (de fila peso)) 100))
;; y entonces si:
(campo final  :rol derivado (suma aporte de calificaciones :donde (= estudiante (de fila nombre))))
```

Cabe, y cabe bien (la hoja emite `SUMIF` sobre una columna de fórmulas y acierta). Pero el documento ahora tiene dos columnas que el profesor no pidió y que sólo existen por una limitación del álgebra. **Qué haría falta:** que `agregado` admita una expresión con la variable candidata ligada — `(suma (* nota peso) de calificaciones :donde ...)`. El evaluador ya tendría todo (`filas-que-cumplen` liga la variable); el coste real está en Excel, donde `SUMIF` no suma expresiones y habría que emitir `SUMPRODUCT` o declararlo como capacidad emulada.

#### 3. Agregar con dos claves a la vez: el núcleo sí, la hoja de cálculo no. (No encaja en una arquitectura.)

Probado directamente:

```
(suma aporte de calificaciones :donde (y (= estudiante (de fila nombre)) (= evaluacion "Final")))
  evaluador: 70 (correcto)
  -> ERROR: Esta hoja de calculo solo sabe agregar con un criterio de igualdad sobre un campo.
```

Y lo mismo con la **búsqueda por clave compuesta**, que es el caso central de este dominio:

```
(el nota de (la-fila-de calificaciones :donde (y (= estudiante (de fila nombre)) (= evaluacion "Final"))) :si-no 0)
  evaluador: 70 (correcto)
  -> ERROR: Esta hoja de calculo busca por una igualdad sobre un campo.
```

Esto **contradice un comentario de diseño del propio núcleo**. `nucleo/expresion.lisp`, nodo `busqueda`, dice: *"Su condicion puede mencionar varios campos, con lo que la clave compuesta sale sin sintaxis adicional"*. Es cierto en el núcleo, en el evaluador y en la web; es falso en la arquitectura de Excel, que exige `igualdad-simple`. Merece corrección antes de citarse en el documento de tesis.

**Qué haría falta:** en Excel, una columna auxiliar de clave concatenada (`estudiante&"#"&evaluacion`) — que es exactamente lo que hace el corpus en `horarios/hoja_grupo.py:291` — declarada como emulación de una capacidad `con-clave-compuesta`. Es barato en esfuerzo y además *ya está en el corpus*; lo que falta es el mecanismo de carencia que lo registre.

#### 4. No hay dónde poner un valor del curso entero. (No encaja en el modelo. Medio.)

"Cuántos estudiantes aprobaron" no es un valor de ninguna fila. El lenguaje sólo sabe colocar valores en filas de colecciones: `parametro` tiene `:valor` literal (no expresión) y no hay nada parecido a un campo derivado global.

**Deformación aplicada:** una colección `resumen` con una sola fila y clave `asignatura`, cuyos campos derivados son los escalares del curso. Se lee mal: en la hoja sale una pestaña "Resumen del curso" con una tabla de una fila y cuatro columnas, y en el texto plano lo mismo. **Qué haría falta:** o bien un parámetro derivado (`(parametro aprobados :rol derivado (cuantas ...))`), o bien un tipo de vista escalar. Lo primero es más barato y encaja con el modelo actual: el parámetro ya existe, sólo le falta poder llevar expresión en vez de literal.

#### 5. Contar con un umbral obliga a materializar el estado como texto. (Falta una construcción. Barato.)

La forma natural:

```
(cuantas estudiantes :donde (>= final (parametro umbral)))
  evaluador: 1 (correcto)
  -> ERROR: Esta hoja de calculo solo sabe agregar con un criterio de igualdad sobre un campo.
```

`COUNTIF` acepta perfectamente el criterio `">=60"`; es el backend el que sólo reconoce igualdad. **Deformación aplicada:** derivar un campo de texto `estado` y contar por igualdad, `(cuantas estudiantes :donde (= estado "Aprobado"))`. Funciona, pero acopla el conteo a una cadena literal: si mañana alguien traduce "Aprobado" a "Apto", el conteo se va a cero sin avisar.

#### 6. Dos resultados MAL, silenciosamente, en la hoja de cálculo. (Defecto verificado, no limitación del lenguaje.)

Un agregado **sin `:donde`** emite siempre `COUNTA`, sea cual sea la operación. Probado aislado, con `evaluaciones` de dos filas y pesos 40 y 60:

```
evaluador de referencia: PESO-TOTAL = 100, MAYOR-PESO = 60, CUANTAS = 2
formulas emitidas:       =COUNTA(Evaluaciones!$A$4:$A$5)   <- peso-total
                         =COUNTA(Evaluaciones!$A$4:$A$5)   <- mayor-peso
                         =COUNTA(Evaluaciones!$A$4:$A$5)   <- cuantas
```

La causa es una rama que decide antes de mirar la operación, en `excel/formula.lisp`:

```lisp
((null campo-criterio)
 (if (null (nucleo:condicion e))
     (format nil "COUNTA(~a)" ...)   ; <- no consulta (nucleo:operacion e)
     (error ...)))
```

Consecuencia medida en mi caso: la página dice `peso-total = 100` y el libro recalculado por LibreOffice dice **4**; y como la marca `pesos-mal-repartidos` es `(/= (de fila peso-total) 100)`, la hoja pinta un aviso amarillo de "los pesos no suman 100" que en la página no aparece. Dos arquitecturas discrepan sobre la misma descripción. Esto es exactamente el fallo que la tesis reprocha a 2026: una fórmula que parece correcta y no lo es.

#### 7. La división produce racionales exactos, y eso rompe el oráculo. (No encaja en el modelo. Medio.)

El corpus no divide nunca. En cuanto se divide, `aplicar-operador` devuelve un racional de Common Lisp y `como-texto` lo imprime como fracción. El acta en texto plano sale así:

```
  Beto Nunez  111    211/4       Suspenso  Le faltan 29/4 puntos para aprobar
```

Peor: `escribir-json` trata el racional como `realp` y escribe `"final": 211/4`, que **no es JSON válido**. La cadena de verificación se cae antes de empezar:

```
$ python3 materializador/verificar.py salida/notas-plano.json salida/notas-esperado.json salida/notas.xlsx
json.decoder.JSONDecodeError: Expecting ',' delimiter: line 44 column 21
```

Es decir: para este dominio el oráculo de conformidad no funciona, y por eso el defecto (6) no salta solo. **Qué haría falta:** decidir la semántica numérica del lenguaje — `:tipo numero` debería implicar coma flotante (o decimal con precisión declarada) en el evaluador, no racional exacto — y que el serializador nunca emita fracciones.

---

### Resultado de la ejecución

Sí se ejecutó, completo, incluido el paso por LibreOffice y por Node.

Archivo: `/home/dayancc/Documents/Universidad/Tesis/Proyecto/Horario/exploracion/notas.lisp`
Artefactos: `salida/notas.txt`, `salida/notas-plano.json`, `salida/notas.xlsx`, `salida/notas.html`, `salida/notas-esperado.json`

**Análisis estático:** `Sin problemas.`

**Evaluador de referencia:**

```
estudiantes
  nombre=Ana Robles  grupo=111  final=88     estado=Aprobado
  nombre=Beto Nunez  grupo=111  final=211/4  estado=Suspenso   MARCAS: no-aprueba
  nombre=Carla Diaz  grupo=112  final=127/2  estado=Aprobado
  nombre=Dario Mena  grupo=112  final=107/2  estado=Suspenso   MARCAS: no-aprueba

calificaciones
  ... Dario Mena  Proyecto  nota=  peso=20  aporte=0   MARCAS: sin-calificar

resumen
  asignatura=Programacion I  matriculados=4  aprobados=2  peso-total=100
```

**Hoja de cálculo, recalculada por LibreOffice y releída con openpyxl:**

```
Estudiantes  fila 4: ['Ana Robles', '111', 88,    'Aprobado']
             fila 5: ['Beto Nunez', '111', 52.75, 'Suspenso']
             fila 6: ['Carla Diaz', '112', 63.5,  'Aprobado']
             fila 7: ['Dario Mena', '112', 53.5,  'Suspenso']
Resumen      fila 4: ['Programacion I', 4, 2, 4]     <- peso-total deberia ser 100
Calificaciones fila 5: ['Ana Robles','Parcial 2', 90, 25, 22.5]
```

**Página web, ejecutando su propio JavaScript en Node:**

```
estudiantes: final 88 / 52.75 / 63.5 / 53.5, estado Aprobado/Suspenso/Aprobado/Suspenso
resumen: {"matriculados":4,"aprobados":2,"peso-total":100}
marca no-aprueba en estudiantes: filas [1,3]
marca sin-calificar en calificaciones: filas [14]
marca pesos-mal-repartidos en resumen: filas []
```

**Informes de conformidad:** texto `1 nativas, 1 emuladas, 4 degradadas, 0 rechazadas`; excel `5 nativas, 1 emuladas, 0 degradadas, 0 rechazadas`; web `6 nativas, 0 emuladas, 0 degradadas, 0 rechazadas`. Ningún informe menciona el parámetro.

Detalle menor pero real: en el texto plano la colección `estudiantes` sale con **dos columnas tituladas "Estado"**, la mía y la que el backend de texto añade siempre para las marcas. El nombre de esa columna está fijo en `texto/emision.lisp` y colisiona con cualquier campo que el usuario llame igual.

---

### Lo que este dominio le pide al lenguaje y el corpus no le pedía

1. **Aritmética sobre una colección ajena, dentro del agregado.** El corpus sólo resta dos campos de la misma fila y cuenta filas. Aquí la operación central del dominio es `SUMAPRODUCTO`, y el álgebra no tiene forma de expresarla: el agregado reduce un *campo*, nunca una *expresión*. La media ponderada es el caso más común de todos los documentos académicos, y hoy sólo cabe pre-calculando una columna. Este es el hueco más importante y el más barato de cerrar.

2. **Cruzar dos claves de una vez.** El corpus busca por una clave (`estudiante`) o concatena a mano (`"<grupo>#<asig>"`). Aquí la relación es genuinamente de dos claves, porque una calificación *es* el par (estudiante, evaluación). El núcleo lo soporta; la hoja de cálculo lo rechaza; el comentario de `nucleo/expresion.lisp` que dice lo contrario hay que corregirlo o hay que implementar la clave concatenada como emulación declarada.

3. **Un parámetro que el usuario pueda tocar.** En el corpus todas las constantes se fijan al generar (la reserva de filas, los topes). Aquí el umbral de aprobado es una *decisión que cambia durante la vida del documento*: el consejo de la facultad baja el corte y el acta entera tiene que recalcularse. El modelo ya tiene el concepto (`parametro` con `rol`), pero ninguna arquitectura lo materializa, así que hoy el concepto es decorativo. Es la diferencia entre "constante del dominio" y "perilla del documento", y el lenguaje declara la segunda y produce la primera.

4. **Escalares que no pertenecen a ninguna fila.** "Cuántos aprobaron", "la media del grupo", "el peso total". El corpus es puramente tabular: todo lo que se muestra es una fila. Cualquier documento con un pie de resumen pide esto, y hoy obliga a inventar una colección de una sola fila — un rodeo que se ve en el artefacto final, no sólo en la descripción.

5. **Números que no son enteros.** El corpus cuenta turnos y profesores: enteros, siempre. Este dominio divide, y al dividir aparecen racionales exactos que se imprimen como `211/4` en el acta y rompen el JSON del oráculo. El lenguaje todavía no ha decidido qué significa `:tipo numero`; el corpus nunca le obligó a decidirlo.

6. **Agregar por comparación y no por igualdad.** Contar "los que están por encima de X" es la pregunta natural de este dominio, y el mecanismo que hay (criterio de igualdad) obliga a fabricar un campo de texto intermedio para poder contarlo. Como efecto secundario, el conteo pasa a depender de una cadena literal escrita en dos sitios.

7. **Una advertencia de método, no de dominio.** Este caso destapó un valor mal calculado en la hoja (`COUNTA` por `suma`) que el juego de conformidad no pudo detectar porque el oráculo era JSON inválido. Merece la pena que la suite falle ruidosamente cuando el oráculo no se puede serializar, en vez de sólo cuando los valores no coinciden: aquí las dos arquitecturas discrepaban entre sí y nada lo dijo.