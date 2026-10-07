# Alcance del lenguaje: cinco dominios ajenos al corpus

Experimento del 2026-09-21. La pregunta: **¿el lenguaje está limitado al corpus,
o describe una clase más amplia de problemas?**

El método no fue razonar, fue intentarlo. Cinco dominios que no tienen nada que
ver con la planificación académica, descritos en el lenguaje y **ejecutados de
verdad** contra el sistema: análisis estático, evaluador de referencia y
materialización en las tres arquitecturas.

Dos de los cinco se eligieron esperando que se rompieran: el torneo es un árbol
y el cuadrante es una matriz, que es la forma de la hoja de grupo del corpus.

## Veredictos

| Dominio | Veredicto |
|---|---|
| Control de inventario de un almacén | CABE-FORZADO |
| Evaluación de un curso | CABE-A-MEDIAS |
| Presupuesto y ejecución de un proyecto | CABE-A-MEDIAS |
| Torneo con eliminatorias | CABE-A-MEDIAS |
| Cuadrante de turnos | CABE-A-MEDIAS |

Ninguno dio NO-CABE, y ninguno dio CABE limpio. **El lenguaje describe más de lo
que se diseñó para describir, y menos de lo que haría falta para decir que
describe "cualquier situación tabular".** Esa es la respuesta medida.

## Lo que el experimento cambió en el código, esa misma noche

Tres fallos reales, encontrados por intentar describir cosas nuevas:

1. **La página web recalculaba en una sola pasada.** Con derivaciones que
   dependen de otras filas de la misma colección —el ganador de un partido pasa
   al siguiente—, cada render hacía converger exactamente un nivel, y la página
   enseñaba valores incompletos sin avisar. Peor: el informe de conformidad
   decía "5 nativas, 0 degradadas". **Un verde falso**, que es la clase de fallo
   que este trabajo le reprocha a la tesis de 2026. Corregido: se recalcula
   hasta punto fijo, y si no converge la página lo dice.
2. **`(:orden dia turno)` descartaba el segundo campo en silencio.**
3. **`(de (anterior fila :donde ...) campo)` descartaba el `:donde` en
   silencio**, y daba números mal en una descripción que se leía como correcta.

Las dos últimas son del mismo género: una descripción que parece correcta y
significa otra cosa. Ahora las tres formas se rechazan con un mensaje que
explica si falta una construcción o si no encaja en el modelo.

## Los informes

Uno por dominio, con lo que se pudo expresar, lo que no, por qué, y la salida
real de la ejecución.

- [`inventario.md`](inventario.md) — Control de inventario de un almacen. **CABE-FORZADO**
- [`notas.md`](notas.md) — Evaluacion de un curso. **CABE-A-MEDIAS**
- [`presupuesto.md`](presupuesto.md) — Presupuesto y ejecucion de un proyecto. **CABE-A-MEDIAS**
- [`torneo.md`](torneo.md) — Un torneo con eliminatorias. **CABE-A-MEDIAS**
- [`turnos.md`](turnos.md) — Cuadrante de turnos de un equipo. **CABE-A-MEDIAS**
