<!-- Informe generado por el experimento de alcance del 2026-09-21. -->

> **ESTADO PREVIO AL ARREGLO.** Este informe describe el sistema tal como estaba
> ANTES de los cambios que el propio experimento motivo. Varios de los defectos
> que reporta ya no se reproducen: se corrigieron esa misma noche. Se conserva
> sin tocar porque es la evidencia de lo que el metodo encontro, y reescribirlo
> borraria el rastro. Lo que se hizo con cada hueco esta en el capitulo 8 de la
> tesis y en `Horario/pruebas/alcance.lisp`.


## Cuadrante de turnos de un equipo

**Veredicto:** CABE-A-MEDIAS

Las tres reglas del dominio se expresan, y se expresan bien, en las dos representaciones. Lo que no cabe es la **forma**: el cuadrante como rejilla día × turno no existe en el lenguaje. (b) parece una matriz sólo porque uno escribe tres columnas a mano; en cuanto los turnos dejan de ser tres fijos, deja de haber cuadrante. Y en (b) la regla más importante del dominio se materializa **silenciosamente mal** en la hoja de cálculo.

Archivo: `/home/dayancc/Documents/Universidad/Tesis/Proyecto/Horario/exploracion/turnos.lisp`
Artefactos: `/home/dayancc/Documents/Universidad/Tesis/Proyecto/Horario/exploracion/salida/`
Corre entero con el patrón indicado. No se tocó ningún archivo del sistema.

---

### Qué se pudo expresar

**Las dos representaciones, completas, y pasando el análisis sin un solo problema.**

| | (a) una fila por celda | (b) una fila por día |
|---|---|---|
| noche + mañana siguiente | `existe` con `dia + 1` | `(de (anterior fila) noche)` |
| contar turnos del mes | un `cuantas` | suma de tres `cuantas` |
| turno sin cubrir (celda) | `(vacio? (de fila persona))` | no se puede señalar la celda |
| día sin cubrir (día) | `cuantas` con dos criterios | `(o (vacio? ...) ...)`, natural |
| doblete el mismo día | `existe :distinta-de fila` | tres comparaciones de la propia fila |
| tope mensual | `(> turnos (parametro tope-mensual))` | igual |
| dominio de entrada | uno | repetido tres veces |

**La pregunta directa: ¿funciona con `(anterior fila)` / `(siguiente fila)`, y con qué representación?**

Con **(b), y sólo con (b)** — y sólo en el evaluador, el texto y la web. En (b) la frase se lee en voz alta y es exactamente la del dominio:

```lisp
(marca encadena-noche-y-manana
  :en dias
  :cuando (y (no (vacio? (de fila manana)))
             (= (de fila manana) (de (anterior fila) noche)))
  :sobre (manana) :severidad problema)
```

En **(a) `anterior` no sirve, y es importante entender por qué no**: la colección aplanada está ordenada por `(dia, turno)`, y `(:orden ...)` sólo admite **un** campo. Con `(:orden dia)` la fila siguiente de una noche es la mañana del día siguiente *por accidente del orden en que estén escritos los datos*, no porque el lenguaje lo diga. Es justo el `PREVIOUS-OF` posicional de 2026 que el análisis existe para impedir — y aquí el análisis **no lo impide**, porque sólo comprueba que haya orden declarado, no que "anterior" signifique algo.

Pero (a) no lo necesita. El día siguiente se dice sumando uno al día, que es lo que significa:

```lisp
(existe otra :en asignaciones
  :donde (y (= (de otra turno) "manana")
            (= (de otra dia) (+ (de fila dia) 1))
            (= (de otra persona) (de fila persona))))
```

Y eso **sí sobrevive a las tres arquitecturas**. La hoja de cálculo emite:

```
AND(($B4="noche"),NOT(($C4="")),
    (SUMPRODUCT((Asignaciones!$C$4:$C$24=$C4)
               *(Asignaciones!$A$4:$A$24=($A4+1))
               *(Asignaciones!$B$4:$B$24="manana"))>0))
```

Correcta, fila a fila. **El resultado interesante es que la representación que NO usa `vecino` es la que funciona en las tres.**

**Contar los turnos de una persona en el mes: sale natural en (a).** Un solo agregado, `COUNTIF(Asignaciones!$C$4:$C$24,$A4)`. En (b) hay que sumar tres agregados porque los turnos son columnas y `cuantas` recorre filas.

**Cuál se materializa mejor dónde.** (b) en las dos: es literalmente el cuadrante (ver `turnos-matriz.txt`). (a) en ninguna: sale una lista de 21 renglones. Pero (b) se materializa **rota** en la hoja de cálculo (abajo).

---

### Qué NO se pudo, y por qué

#### No encaja en el modelo (caro — toca el núcleo o el protocolo)

**1. No hay eje. Los valores de un campo no pueden ir en el eje de columnas.**
Para que (a) se vea como cuadrante hace falta una tabulación cruzada: filas por `dia`, columnas por los valores de `turno`, celda `persona`. `vista` tiene `secciones` y `agrupacion`, y yo declaré `:agrupada-por dia` — **el análisis lo aceptó y ninguna arquitectura lo leyó**. `grep -rn "agrupacion\|secciones" excel web texto` da cero usos: las dos ranuras están declaradas en `nucleo/modelo.lisp` y muertas. Lo caro no es leerlas: es que `excel/plan.lisp` construye `columnas` como *una letra por campo*. Un eje que sale de los datos hace que el número de columnas dependa del contenido, y eso mueve el plan, el direccionamiento, los rangos de todo agregado y el `rango-de-alcance` de toda marca. Es el hallazgo central.

**2. Nada cuantifica sobre campos.** `existe`, `cuantas`, `los` y `la-fila-de` recorren **filas**. No hay binder de columnas. Por eso en (b) cada regla se escribe una vez por turno y el conteo es una suma de tres. `comparten` es lo único que recibe una lista de campos, y es fija en tiempo de escritura. Añadir "para cada campo de esta lista" es un ligador nuevo en el álgebra: toca `nucleo/expresion.lisp`, el ámbito, el análisis y los tres emisores.

**3. Una marca no puede decir a qué celda apunta.** `alcance` es una lista estática de nombres. En (b), `dia-incompleto` pinta las tres columnas porque no puede pintar la vacía. En (a) el problema desaparece — la celda *es* una fila — y ésa es la ventaja real de (a), no la forma.

**4. No hay relación declarada entre colecciones.** `dias` y `asignaciones` en (a) sólo se juntan repitiendo `(= dia (de fila dia))` dentro de cada expresión. Sin un `:pertenece-a`, ninguna arquitectura puede saber que `asignaciones` es la sub-tabla de `dias` y anidarlas. Es lo que le faltaría a un backend de rejilla para ver el cuadrante en (a).

#### Falta una construcción (barato)

**5. `(:orden dia turno)` se descarta en silencio.** `compilar-coleccion` hace `(setf orden (normalizar (second f)))`: el segundo campo se pierde sin error ni aviso. Comprobado: escribí `(:orden dia turno)`, quedó guardado `dia`.

**6. No se puede generar el esqueleto de la rejilla.** 31 días × 3 turnos = 93 filas que hay que enumerar a mano en `:datos`. El modelo documenta `origen (:una-fila-por campo :de coleccion)` en `nucleo/modelo.lisp`, pero **no existe sintaxis**: `compilar-coleccion` siempre escribe `:origen :declarada`. Y aunque existiera, es un eje; el producto cartesiano `dias × turnos` no está ni en el modelo.

**7. Hoja de cálculo: agregado con más de un criterio → falla la materialización entera.** `(cuantas asignaciones :donde (y (= dia (de fila dia)) (no (vacio? persona))))` — la forma natural de preguntar algo de un **día** en la representación (a). `igualdad-simple` sólo reconoce una igualdad suelta. `COUNTIFS` existe en la hoja; el backend no lo emite. Consecuencia medida (SONDA 4): **(a) sólo se materializa en Excel si se renuncia a toda pregunta de nivel día.**

**8. Hoja de cálculo: búsqueda por clave compuesta → falla.** La celda del cuadrante se identifica por `(dia, turno)`. `nucleo/expresion.lisp` afirma que "la clave compuesta sale sin sintaxis adicional"; `emitir-busqueda` la rechaza. Texto y web la resuelven; Excel no (SONDA 1). El corpus ya lo emula a mano con la clave `"<grupo>#<asig>"` en `horarios/hoja_grupo.py:291`, así que el mecanismo es conocido — falta emitirlo.

**9. La aritmética n-aria se trunca a binaria, en silencio, en las DOS arquitecturas.** El evaluador hace `reduce`; `excel/formula.lisp` y `web/expresiones.lisp` toman `(first partes)` y `(second partes)` y **tiran el resto**. `(+ a b c)` produce `(a+b)`. No es un error de compilación: es un número equivocado.

**10. `vecino` dentro de una marca sale mal en la hoja de cálculo.** El peor de todos, abajo.

---

### Resultado de la ejecución

Se ejecutó entero. Análisis limpio en las cuatro situaciones.

**(a) evaluador de referencia** — correcto:

```
personas
  nombre=Ana  turnos=7  margen=-1   >> se-pasa-del-tope
  nombre=Bruno  turnos=6  margen=0
  nombre=Carla  turnos=4  margen=2
  nombre=Diego  turnos=3  margen=3
dias
  dia=5  cubiertos=2   >> dia-incompleto

Marcas en las asignaciones:
  dia 2 noche -> Bruno   >> noche-y-manana-siguiente
  dia 4 manana -> Ana    >> doble-turno-el-mismo-dia
  dia 4 noche -> Ana     >> noche-y-manana-siguiente, doble-turno-el-mismo-dia
  dia 5 noche -> (vacio) >> sin-cubrir
```

Materialización de (a): **texto OK, web OK (8 nativas), excel FALLA**:

```
[excel] FALLA: Esta hoja de calculo solo sabe agregar con un criterio de
igualdad sobre un campo. La condicion de cuantas es mas complicada.
```

**(b) evaluador de referencia** — correcto, y el texto es el cuadrante:

```
Dia  Manana  Tarde  Noche  Cubiertos  Estado
1    Ana     Bruno  Carla  3
2    Diego   Ana    Bruno  3
3    Bruno   Carla  Diego  3          Hizo la noche de ayer y entra de manana
4    Ana     Bruno  Ana    3          Alguien repite turno el mismo dia
5    Ana     Carla         2          Hizo la noche de ayer y entra de manana; Faltan 1 turno
6    Bruno   Ana    Carla  3
7    Diego   Ana    Bruno  3
```

Las tres arquitecturas de (b) materializan. **Y las dos que emiten código están mal.**

**Fallo A — la suma de tres se queda en dos.** `personas.turnos` (3-ario) contra `turnos-anidado` (el mismo cálculo, en binario a mano):

```
turnos          =IF($A4="","",(COUNTIF(Dias!$B$4:$B$10,$A4)+COUNTIF(Dias!$C$4:$C$10,$A4)))
turnos-anidado  =IF($A4="","",(COUNTIF(Dias!$B$4:$B$10,$A4)+(COUNTIF(Dias!$C$4:$C$10,$A4)+COUNTIF(Dias!$D$4:$D$10,$A4))))
```

Falta la columna `D`, la de noche. El oráculo dice Ana = 7; la hoja diría 6. Idéntico en la web:

```js
"turnos": (f) => (N(D["dias"].filter(c => IG(V(c["manana"]),V(f["nombre"]))).length)
                + N(D["dias"].filter(c => IG(V(c["tarde"]),V(f["nombre"]))).length)),
```

Este sí lo cazaría `materializador/verificar.py`, que compara valores contra el oráculo.

**Fallo B — la regla principal del dominio nunca dispara en la hoja de cálculo.** El formato condicional emitido para `encadena-noche-y-manana`:

```json
{"rango": "B4:B10", "estado": "encadena-noche-y-manana",
 "formula": "AND(NOT(($B4=\"\")),($B4=\"\"))"}
```

`AND(NOT(X), X)` es **siempre falsa**. Causa exacta: `excel/emision.lisp:229` emite la marca una sola vez con `*fila*` ligada a `fila-primera`; `emitir-vecino` calcula `4-1 = 3`, ve que cae fuera del rango y emite el literal `""`. El `(de (anterior fila) noche)` se evapora. En el libro no se pinta ni una celda roja, y el informe de conformidad da un parte impecable: **7 nativas, 1 emulada, 0 degradadas, 0 rechazadas**. `verificar.py` no compara formatos condicionales, sólo valores, así que la cadena de verificación tampoco lo ve. Es exactamente el fallo de la figura 6.2 de 2026 — colores que no significan lo que la regla dice — reaparecido por otra puerta.

**SONDA 1** (clave compuesta): evaluador da `dia=1 → Bruno`, `dia=2 → ""` (correcto); texto y web OK; `[excel] FALLA: Esta hoja de calculo busca por una igualdad sobre un campo.`
**SONDA 2**: escrito `(:orden dia turno)`, guardado `(:orden dia)`, sin aviso.
**SONDA 4**: (a) sin la colección `dias` materializa en Excel sin problemas — 6 nativas, 1 emulada — con el SUMPRODUCT correcto citado arriba.

---

### Lo que este dominio le pide al lenguaje y el corpus no le pedía

1. **Un eje que sea dato.** `plan-del-grupo` y `defensas-de-tesis` son las dos listas de filas. Ninguna tiene una tabulación cruzada, y por eso `secciones` y `agrupacion` pudieron nacer muertas sin que nadie lo notara. Es lo primero que hay que resolver antes de tocar la hoja de grupo.

2. **Aritmética sobre la clave para alcanzar una fila vecina.** `(= (de otra dia) (+ (de fila dia) 1))`. El corpus sólo busca por igualdad contra una clave que ya existe. Esta forma es la que hace innecesario a `vecino` en (a), y es la que salva la regla en las tres arquitecturas.

3. **`vecino` dentro de una MARCA, no dentro de un campo derivado.** `grep -rn "anterior\|siguiente" corpus/` da cero: **`vecino` es la única construcción del álgebra sin ni un caso en el corpus**, y es exactamente la que sale rota. Es la lección arquitectónica del encargo: la justificación "cada construcción de aquí está en el corpus" de `nucleo/expresion.lisp` no se cumple para `vecino` (se justifica con "la parrilla de televisión de 2026"), y el precio se cobró aquí.

4. **Una regla universal sobre un conjunto de columnas.** "Ningún turno del día puede quedar vacío" es una sola frase del dominio y hoy son tres. El corpus nunca tuvo columnas intercambiables entre sí: `tutor`, `oponente`, `presidente`, `secretario` son un grupo, y por eso hizo falta `comparten` — pero `comparten` es la versión congelada, no el cuantificador.

5. **Sumas de más de dos términos.** Ningún archivo del corpus tiene un `+` de tres argumentos: todo es `(- frecuencia asignadas)`. Por eso el truncado sobrevivió hasta hoy en dos emisores a la vez.

6. **Generar la rejilla.** El corpus enumera media docena de filas; un mes de guardia son 93. Enumerar 93 filas en `:datos` es escribir a mano lo que el documento debería producir.

7. **Marcas que apuntan a una celda calculada,** no a una lista de campos escrita de antemano.

8. **Agregados con más de un criterio,** que `nucleo/expresion.lisp` atribuye a `departamento/hoja_cobertura.py` pero que ningún archivo del corpus ejercita — y que Excel rechaza.

**La respuesta a la pregunta que decide el encargo.** La hoja de grupo, tal como está hoy (días × un número fijo de turnos), se puede describir con la representación (b): el lenguaje la expresa entera y con naturalidad, incluida la regla de encadenamiento. Con dos condiciones: que los turnos sean pocos y fijos, porque son esquema y no datos; y que antes se arregle `emitir-vecino` en los formatos condicionales, porque hoy la hoja saldría muda precisamente en lo que importa. Si se quiere que el eje de turnos salga de los datos — o que la misma descripción sirva para un cuadrante de 3 turnos y para uno de 5 — eso no es una construcción que falte: es un eje que el modelo de vistas no tiene y que el plan de la hoja de cálculo asume que no existe.