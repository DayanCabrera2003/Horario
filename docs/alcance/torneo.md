<!-- Informe generado por el experimento de alcance del 2026-09-21. -->

> **ESTADO PREVIO AL ARREGLO.** Este informe describe el sistema tal como estaba
> ANTES de los cambios que el propio experimento motivo. Varios de los defectos
> que reporta ya no se reproducen: se corrigieron esa misma noche. Se conserva
> sin tocar porque es la evidencia de lo que el metodo encontro, y reescribirlo
> borraria el rastro. Lo que se hizo con cada hueco esta en el capitulo 8 de la
> tesis y en `Horario/pruebas/alcance.lisp`.


## Un torneo con eliminatorias

**Veredicto:** CABE-A-MEDIAS

---

### Qué se pudo expresar

Todo esto está escrito, analizado, evaluado y materializado en las tres arquitecturas, y verificado contra el oráculo. El archivo es `/home/dayancc/Documents/Universidad/Tesis/Proyecto/Horario/exploracion/torneo.lisp` (731 líneas, corre entero de arriba abajo con `exit=0`).

1. **El cuadro como una colección de partidos con un campo que dice de qué partido viene cada equipo.** Sí, y se lee bien:

```lisp
(campo equipo-a :rol derivado :etiqueta "Equipo A"
       (si (= (de fila viene-a) 0)
           (de fila sembrado-a)
           (el ganador de (la-fila-de partidos
                            :donde (= id (de fila viene-a)))
               :si-no "")))
```

   "el ganador del partido del que viene A, y si no lo hay, nada". La arista del árbol es un campo fijo (`viene-a`, `viene-b`) y la búsqueda es la que ya existía para el VLOOKUP del corpus.

2. **"El ganador del partido 3" como búsqueda por clave sobre la misma colección.** Funciona. `comprobar-ciclos` no la rechaza (solo mira `ref-campo` con variable `FILA`; dentro del `:donde` la variable es `CANDIDATA`, así que la dependencia entre filas es invisible para el análisis). El evaluador la resuelve porque `valor-de-campo` es perezoso y memoriza por (fila, campo), con centinela `:calculando` por fila, no por columna.

3. **La cascada completa de cuatro niveles** (octavos → cuartos → semifinal → final): campeón correcto, 15 partidos.

4. **La cascada de seis niveles**: cuadro de 64 equipos, 63 partidos. Sin degradación.

5. **Marcas del dominio**, todas disparando donde debían: `empate` (imposible en eliminatoria), `resultado-antes-de-tiempo` (hay marcador y aún no se sabe quién juega), `pendiente`, y una de cuantificación sobre campos *derivados*:

```lisp
(marca equipo-repetido-en-la-ronda :en partidos
  :cuando (existe otro :en partidos :distinta-de fila
            :donde (y (= (de otro ronda) (de fila ronda))
                      (comparten otro fila (equipo-a equipo-b)))))
```

6. **La variante B** (una colección por ronda, sin búsqueda sobre sí misma): también funciona, y en Excel produce VLOOKUP entre hojas en vez de sobre la propia.

7. **"El campeón es X"** emulado como colección de una sola fila.

---

### Qué NO se pudo, y por qué

#### 1. El orden de evaluación no existe en el lenguaje, y una arquitectura da valores falsos por eso. (NO ENCAJA EN EL MODELO — caro)

Es el hallazgo importante. **La misma descripción, sin cambiar una línea**, con el cuadro numerado como se numera un cuadro de verdad (la final es el 1, las semifinales la 2 y la 3, los octavos del 8 al 15):

```
torneo-a    (ids en orden topológico)   excel: ok 165   web: ok 225
torneo-a2   (numeración canónica)       excel: ok 165   web: FALLA 20/225
```

La página no avisa de nada: devuelve cadena vacía donde debería ir un equipo. La causa está en `web/recursos.lisp`:

```js
function recalcularTodo(){
  for (const nombre in D) D[nombre].forEach(f => calcular(nombre, f));
}
```

Una sola pasada, en el orden del arreglo, con los derivados calculados con avidez. Medido, **converge exactamente un nivel del árbol por pasada**:

```
pasada 1: 1:-/-  2:-/-  3:-/-  4:-/-  ...  8:Alemania/Escocia ...
pasada 2: 1:-/-  2:-/-  3:-/-  4:Alemania/Suiza  5:Espana/Italia ...
pasada 3: 1:-/-  2:Alemania/Espana  3:Paises Bajos/Inglaterra ...
pasada 4: 1:Espana/Paises Bajos  2:Alemania/Espana  ...   (converge)
```

Un render = una pasada. Hacen falta tantas pulsaciones como rondas tenga el cuadro para que la página diga la verdad.

**Respuesta directa a "cuántos niveles aguanta":**
- Evaluador de referencia: sin límite estructural (perezoso + memorizado). Probado a 6.
- Hoja de cálculo: sin límite estructural. Probado a 6 (693 celdas evaluadas por LibreOffice, 0 discrepancias). Y — contra mi hipótesis inicial — la referencia circular **no se produce**: el VLOOKUP emitido abarca la propia celda (`I4 = ...VLOOKUP($C4,Partidos!$A$4:$K$18,11,...)`, e `I4` está dentro de `$A$4:$K$18`) y Calc la resuelve igual, porque detecta ciclos por reentrada en tiempo de evaluación, no por solape estático de rangos. Esto no lo he podido probar con Excel de Microsoft; es un riesgo abierto, no un fallo medido.
- Página web: **un nivel por render**, siempre. Funciona solo cuando las filas caen, por casualidad, en orden topológico.

Lo que impide arreglarlo barato: el lenguaje declara `:orden` como criterio de *presentación* (`(:orden id)`), no como garantía de que la derivación se evalúe en ese orden, y no tiene ninguna forma de decir "este campo derivado depende de otras filas de esta misma colección". El análisis tampoco puede detectarlo: `comprobar-ciclos` está escrito explícitamente para *ignorar* las dependencias que pasan por una búsqueda ("no forman ciclo de fila, porque van a otra fila"). Y el informe de conformidad de la web dice, en el caso que falla, **"5 nativas, 0 emuladas, 0 degradadas, 0 rechazadas"**: un verde falso.

Haría falta: que el núcleo declare el grafo de dependencias *entre filas* (no solo entre campos de una fila), que el análisis lo compute, y que `con-derivacion-viva` se parta en dos capacidades — "recalcula hasta punto fijo" frente a "recalcula en una pasada". Eso toca el núcleo, el protocolo y el análisis.

#### 2. La forma del árbol no se puede calcular, solo tabular. (FALTA UNA CONSTRUCCIÓN — barato)

"El ganador del partido *i* pasa al partido que le corresponde" es, con la numeración canónica, `padre = parte entera de i/2`. El álgebra tiene `+ - * / = /= < <= > >= Y O NO` y nada más:

```
-- nodos --   (campo derivado: (/ (de fila id) 2))
  id=1 | padre=1/2
  id=3 | padre=3/2
  id=5 | padre=5/2
```

No hay parte entera, ni resto, ni redondeo. Consecuencia: **cada arista del árbol hay que escribirla a mano como dato**. 30 números para 16 equipos, 126 para 64. El lenguaje no puede decir cómo es el cuadro; solo puede listarlo. Añadir `parte-entera` y `resto` es un nodo nuevo y un método por arquitectura: barato. Pero nótese que aun con ellos, "la ronda siguiente" seguiría sin ser expresable, porque las rondas son cadenas sin orden (habría que numerarlas, y entonces `ronda + 1` sí saldría).

#### 3. El cuadro sale como una lista, nunca como un cuadro. (NO ENCAJA EN EL MODELO — caro)

`(vista cuadro :de partidos :agrupada-por ronda)` se declara, se analiza, se valida... y **ninguna arquitectura la usa**:

```
$ grep -rn "agrupacion\|secciones" texto/ web/ excel/
(sin resultados)
```

La salida de texto son 15 filas seguidas con una columna "Ronda". La hoja de cálculo, una pestaña. La página, una tabla. Un árbol de eliminatorias es sobre todo una *figura*: lo que se lee de un cuadro es qué partido alimenta a cuál, y eso aquí no se ve en ninguno de los tres destinos. La parte barata (honrar `:agrupada-por`) es un método por arquitectura. La parte cara es que el modelo de vista solo sabe partir y agrupar filas; no tiene forma de expresar que dos filas están *conectadas*, que es lo único que hace legible un cuadro.

#### 4. Una regla del dominio hay que escribirla una vez por colección. (NO ENCAJA EN EL MODELO — caro)

En la variante B, "en eliminatoria no puede haber empate" es la misma regla en las cuatro rondas. No se puede escribir una sola vez; el análisis lo prohíbe expresamente:

```
error: La marca empate senala campos (goles-a, goles-b) que existen en mas de
una coleccion (octavos, cuartos). Anade :EN <coleccion>
para decir de cual se trata.
```

El código de `coleccion-de-la-marca` dice por qué: adivinar entre varias sería "un acierto que depende de cómo estén escritas las cosas". La decisión es buena, pero deja sin salida el caso de "esta regla vale para todas estas colecciones". En la variante B acabé con cuatro marcas `empate-en-*` idénticas. Para un cuadro de 64 serían seis. Haría falta que `:en` admitiera varias colecciones, o una noción de colecciones con la misma forma.

#### 5. "El campeón" no es un valor de la situación. (FALTA UNA CONSTRUCCIÓN — barato)

No hay derivados fuera de una colección: `parametro` lleva `:valor` literal (en `compilar-parametro`, `:valor ,(opcion opciones :valor)`, sin pasar por `compilar-expresion`). Lo emulé con una colección `resumen` de una fila:

```
resumen -> ((QUE . "torneo") (CAMPEON . "Espana")
            (PARTIDOS-DE-LA-FINAL . 1) (PARTIDOS-JUGADOS . 15))
```

Cabe, pero deformado: el documento acaba con una hoja "Resumen" de una sola fila cuya única razón de existir es que no hay dónde poner un escalar.

#### 6. La hoja de cálculo rechaza los agregados con condición que no sea una igualdad, y lo hace por la vía mala. (FALTA UNA CONSTRUCCIÓN — barato, pero el mecanismo está mal)

`(cuantas partidos :donde (no (vacio? goles-a)))` — "cuántos se han jugado ya" — evalúa bien en el núcleo (14, y 15 con la final jugada) y bien en la web. En Excel:

```
Generado salida/torneo-resumen.txt
ERROR AL MATERIALIZAR: Esta hoja de calculo solo sabe agregar con un criterio de
igualdad sobre un campo. La condicion de cuantas es mas complicada.
```

Lo importante no es que falte `COUNTIFS` con criterio compuesto (eso es barato). Es que esto **no pasa por el mecanismo de carencias**: no hay `requerir`, no hay CUMPLE/EMULA/DEGRADA/RECHAZA, no aparece en ningún informe. Es un `error` de Lisp que aborta la materialización después de haber escrito ya el `.txt`. El mecanismo de degradación, que es una de las aportaciones del trabajo, tiene un agujero justo donde más se necesita.

#### 7. `:si-no` significa tres cosas distintas cuando la fila existe pero su valor no. (NO ENCAJA EN EL MODELO — caro)

En un cuadro, la fila del partido existe **desde el sorteo**; lo que no existe es su ganador. Reducido a 11 valores:

```lisp
(campo mira-partido-1 :rol derivado
       (el ganador de (la-fila-de partidos :donde (= id 1)) :si-no "TODAVIA NADIE"))
```

```
torneo-sinvalor.xlsx:  ok    11 celdas
torneo-sinvalor.html:  FALLA 11 comprobaciones, 1 discrepancias
   lectura[0].mira-partido-1  esperado ""  obtenido "TODAVIA NADIE"
```

El núcleo (`nucleo/evaluador.lisp`, método `proyeccion`) aplica el valor por defecto **solo si no hay fila**; la web (`PROY` en `web/recursos.lisp`) lo aplica también **si el valor está vacío**. Dos lecturas de la misma frase. Ninguna de las dos es obviamente la correcta: el lenguaje simplemente no distingue "no existe la fila" de "la fila existe y el dato aún no está decidido", y el dominio de un torneo vive permanentemente en el segundo estado.

#### 8. `comparten` en la hoja de cálculo cuenta dos vacíos como un valor compartido. (FALTA UNA CONSTRUCCIÓN — barato, pero el síntoma es grave)

En el cuadro recién sorteado —el estado en que se *imprime* el documento el primer día— la fórmula emitida para `equipo-repetido-en-la-ronda` dispara en seis partidos cuyos equipos simplemente aún no se saben:

```
fila  id  ronda      equipoA  equipoB  |  dispara?
   4   1  octavos    'Alemania' 'Escocia'   |  False
  12   9  cuartos    None      None         |  True    <-- falso positivo
  13  10  cuartos    None      None         |  True
  ...
  17  14  semifinal  None      None         |  True
  18  15  final      None      None         |  False   (es el unico de su ronda)
```

(Hecho poniendo la fórmula condicional emitida, literalmente, en una columna libre del libro generado y dejando que LibreOffice la evalúe.)

El núcleo y la web filtran los vacíos antes de intersecar; el desarrollo a SUMPRODUCT de `excel/formula.lisp` no:

```
(SUMPRODUCT((((Partidos!$I$4:$I$18=$I4)+(Partidos!$J$4:$J$18=$I4)+...)>0)
            *(Partidos!$B$4:$B$18=$B4)*(ROW(...)<>ROW($A4)))>0)
```

El corpus no lo nota porque en `defensas-de-tesis` los campos del tribunal se rellenan todos a la vez. Un cuadro es lo contrario: la mitad de las celdas derivadas están vacías casi todo el tiempo. **Y la suite de conformidad no lo caza, porque compara valores y no marcas.**

#### 9. El verificador no sabe emparejar hojas cuando dos colecciones tienen los mismos campos

La variante B da `FALLA torneo-b.xlsx: 144 celdas comprobadas, 52 discrepancias`. **El libro está bien**: emparejando las hojas a mano, 104 celdas y 0 discrepancias. El fallo está en `_clave_de_coleccion` de `materializador/verificar.py`, que empareja por el conjunto de nombres de campo; `cuartos`, `semifinales` y `finalisima` lo tienen idéntico y las tres se comparan contra la primera. Es una limitación del arnés, no del sistema, pero significa que **la variante B no es verificable con las herramientas que hay**.

---

### Resultado de la ejecución

Todo ejecutado de verdad. Comando del encargo, `exit=0`, 409 líneas de salida.

**Evaluador de referencia, variante A (cascada de 4 niveles):**

```
-- partidos --
  id=1 | ronda=octavos | equipo-a=Alemania | equipo-b=Escocia | goles-a=2 | goles-b=0 | ganador=Alemania
  id=9 | ronda=cuartos | equipo-a=Alemania | equipo-b=Suiza | goles-a=2 | goles-b=1 | ganador=Alemania
  id=10 | ronda=cuartos | equipo-a=Espana | equipo-b=Italia | goles-a=2 | goles-b=1 | ganador=Espana
  id=13 | ronda=semifinal | equipo-a=Alemania | equipo-b=Espana | goles-a=1 | goles-b=2 | ganador=Espana
  id=14 | ronda=semifinal | equipo-a=Paises Bajos | equipo-b=Inglaterra | goles-a=2 | goles-b=1 | ganador=Paises Bajos
  id=15 | ronda=final | equipo-a=Espana | equipo-b=Paises Bajos | goles-a=NIL | goles-b=NIL | ganador=   [pendiente]
```

**Cascada de 6 niveles (64 equipos, gana siempre el equipo A):**

```
Analisis: sin problemas.
  id= 1 1-32avos     E01    vs E02    -> E01
  id=33 2-16avos     E01    vs E03    -> E01
  id=49 3-octavos    E01    vs E05    -> E01
  id=57 4-cuartos    E01    vs E09    -> E01
  id=61 5-semifinal  E01    vs E17    -> E01
  id=63 6-final      E01    vs E33    -> E01
```

**Marcas que dispararon** (cuadro con Alemania sembrada en dos octavos y un empate en cuartos):

```
  id=1 | ronda=octavos | equipo-a=Alemania | equipo-b=Escocia   [equipo-repetido-en-la-ronda]
  id=2 | ronda=octavos | equipo-a=Hungria | equipo-b=Alemania   [equipo-repetido-en-la-ronda]
  id=9 | ronda=cuartos | equipo-a=Alemania | equipo-b=Alemania | goles-a=2 | goles-b=2   [empate]
```

(De paso: la marca **no** caza que Alemania juegue contra sí misma en el partido 9. `comparten` compara esta fila con *otras*; "el mismo equipo en los dos lados del mismo partido" es otra marca, y esa sí es expresable.)

**Informes de conformidad** — idénticos en las cinco materializaciones de la variante A:

```
Informe de conformidad        Arquitectura: excel
  cumple   con-orden-declarado    partidos se materializa ordenada por id
  cumple   con-entrada            goles-a lo escribe el usuario
  cumple   con-derivacion-viva    equipo-a se recalcula al editar
  cumple   con-marcado-visual     la marca empate senala un estado
  cumple   con-marcado-textual    la marca empate explica por que en palabras
  5 nativas, 0 emuladas, 0 degradadas, 0 rechazadas

Informe de conformidad        Arquitectura: texto
  degrada  con-entrada / con-derivacion-viva / con-marcado-visual
  2 nativas, 0 emuladas, 3 degradadas, 0 rechazadas
```

En la variante B, texto añade `emula con-navegacion  las vistas se apilan con un indice al principio`, y el `.txt` sale con índice de las cuatro rondas.

**Verificación contra el oráculo, artefacto por artefacto:**

```
torneo-a           excel: ok   165 celdas          web: ok    225 valores
torneo-a2          excel: ok   165 celdas          web: FALLA 20/225
torneo-marcas      excel: ok   165 celdas          web: ok    225 valores
torneo-sin-jugar   excel: ok   165 celdas          web: ok    225 valores
torneo-b           excel: (arnes no empareja)      web: ok    119 valores
                   a mano: 104 celdas, 0 discrepancias
torneo-64          excel: ok   693 celdas          web: ok    756 valores
torneo-sinvalor    excel: ok    11 celdas          web: FALLA 1/11
torneo-resumen     excel: ABORTA (agregado no traducible)
```

No se tocó ningún archivo existente: solo se creó `exploracion/torneo.lisp` y artefactos nuevos con prefijo `torneo-*` en `salida/`.

---

### Lo que este dominio le pide al lenguaje y el corpus no le pedía

**1. Que una fila dependa de otra fila de su propia colección, y que eso tenga una semántica declarada.** El corpus solo tiene dependencias *entre* colecciones (citaciones → tesis) y siempre de una sola profundidad. Aquí la dependencia es intra-colección, transitiva y de profundidad arbitraria. El lenguaje la *acepta* sin decir una palabra: el análisis la ignora por diseño, el informe de conformidad la da por nativa, y dos de las tres arquitecturas coinciden por suerte. Esto es una capacidad no nombrada, y todo lo que este trabajo dice sobre carencias y degradación depende de que las capacidades estén nombradas. Si de este encargo sale una sola cosa para la tesis, es ésta: **hace falta una capacidad `con-derivacion-en-cascada` (o `con-recalculo-hasta-punto-fijo`) y un análisis que detecte cuándo una descripción la pide.** Sin ella, "la descripción es independiente de la arquitectura" es falso para esta descripción, y falso en silencio.

**2. Que el dato esté por decidir, no ausente.** En el corpus, un hueco es un hueco: la citación de las diez no tiene estudiante y ya. Aquí la fila del partido existe desde el sorteo y su ganador *va a existir*. `vacio?` y `:si-no` colapsan los dos estados en uno, y por eso el núcleo y la web contestan cosas distintas a la misma pregunta. El corpus nunca llega a ese estado porque sus filas se rellenan completas.

**3. Que la estructura tenga forma propia, no solo filas.** El plan del grupo es una lista y las defensas son una rejilla de huecos; las dos son de verdad tablas. Un cuadro de eliminatorias es un árbol que se dibuja, y `:agrupada-por` —la única construcción del lenguaje que apunta en esa dirección— no la implementa ningún backend. Esto le pone un límite honesto al alcance: el lenguaje describe *situaciones tabulares*, y eso no es una limitación de la implementación sino la frontera del dominio. Merece decirse en la tesis como frontera declarada, no descubrirse como fallo.

**4. Que una regla valga para muchas colecciones a la vez.** El corpus tiene dos o tres colecciones con campos distintos, así que deducir la colección de una marca por su alcance funciona siempre. Con cuatro rondas homogéneas el mecanismo se da la vuelta: lo que era comodidad se convierte en prohibición, y la misma frase del dominio hay que escribirla N veces.

**5. Aritmética sobre las claves.** El corpus construye claves compuestas por concatenación (`"<grupo>#<asig>"`), nunca las *calcula*. Un árbol numerado tiene la relación padre-hijo en la aritmética de la clave, y sin parte entera esa relación hay que tabularla a mano. Es la diferencia entre describir una estructura y transcribirla.

**6. Un número grande de filas derivadas vacías al mismo tiempo.** Es el caso que rompió `comparten` en Excel y el que hace visible el problema del `:si-no`. El corpus nunca lo alcanza; cualquier documento que se imprima *antes* de rellenarse sí. Vale la pena añadir al juego de conformidad un caso "documento recién generado, todo lo derivado vacío" — y, sobre todo, **que la suite de conformidad compare también las marcas, no solo los valores.** Hoy dos arquitecturas pueden pintar cosas distintas y pasar todas las pruebas.