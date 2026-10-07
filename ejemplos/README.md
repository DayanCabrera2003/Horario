# Ejemplos

Las situaciones que se fueron pidiendo, escritas en el lenguaje, cada una
junto a lo que produce. Los resultados ya están generados en
[`resultados/`](resultados/): se pueden abrir sin instalar nada.

Para leer una descripción no hace falta más que el archivo `.lisp`. La
sintaxis completa está en la sección 5 de
[`../docs/GUIA-DEL-LENGUAJE.md`](../docs/GUIA-DEL-LENGUAJE.md).

## Las descripciones

| Situación | Descripción | Resultados |
|---|---|---|
| Plan de asignaturas de un grupo: turnos que faltan o sobran por asignatura | [`corpus/plan-del-grupo.lisp`](../corpus/plan-del-grupo.lisp) | [xlsx](resultados/plan-del-grupo.xlsx) · [html](resultados/plan-del-grupo.html) · [txt](resultados/plan-del-grupo.txt) |
| Horario semanal de un grupo, como rejilla día por turno | [`corpus/horario-del-grupo.lisp`](../corpus/horario-del-grupo.lisp) | [xlsx](resultados/horario-del-grupo.xlsx) · [html](resultados/horario-del-grupo.html) · [txt](resultados/horario-del-grupo.txt) |
| Defensas de tesis: citaciones de un día con el tribunal traído solo | [`corpus/defensas-de-tesis.lisp`](../corpus/defensas-de-tesis.lisp) | [xlsx](resultados/defensas-de-tesis.xlsx) · [html](resultados/defensas-de-tesis.html) · [txt](resultados/defensas-de-tesis.txt) |
| Gestión del departamento: qué profesor imparte qué, su carga y la cobertura de cada asignatura | [`corpus/departamento.lisp`](../corpus/departamento.lisp) | [xlsx](resultados/departamento.xlsx) · [html](resultados/departamento.html) · [txt](resultados/departamento.txt) |
| Horario del preuniversitario Saúl Delgado: dos grupos, por grupo, por profesor y por aula, con las reglas del enunciado | [`exploracion/saul.lisp`](../exploracion/saul.lisp) | [html](resultados/saul.html) · [txt](resultados/saul.txt) · sin xlsx, ver abajo |

Las páginas `.html` son editables: se escribe en una casilla y lo calculado y
las marcas se actualizan solos. Los `.xlsx` igual, con desplegables y
fórmulas vivas. Los `.txt` son la misma situación sin nada vivo, para ver en
la terminal.

Los datos de cada descripción son de ejemplo, con problemas puestos a
propósito para que se vea cada marca:

- **Plan del grupo** — Análisis Matemático tiene un turno de más; Ciencia de
  Datos y Física, uno de menos.
- **Horario del grupo** — Álgebra Lineal puesta cuatro veces cuando lleva
  tres; dos turnos sin asignar.
- **Defensas de tesis** — A. Suárez citado como secretario en dos locales el
  lunes a las nueve; un hueco a las diez todavía sin defensa.
- **Departamento** — María Ramírez pasa de su tope en 32 horas; al grupo 2 de
  CP de Probabilidades le falta profesor; a Métodos Numéricos le faltan 48
  horas de carga por crear. Pedro Alonso da cuatro filas de carga pero dos
  asignaturas distintas, que es como lo cuenta el panel.
- **Saúl Delgado** — un horario escrito a mano que incumple varias de las
  reglas: profesores en dos grupos a la vez, aulas ocupadas dos veces, una
  sesión en el día de preparación de su asignatura, un profesor contratado
  citado un día que no viene.

## Lo que está verificado y lo que no

Las cuatro del `corpus/` las comprueba `./demostrar.sh` en cada ejecución:
LibreOffice recalcula el `.xlsx` y Node ejecuta el JavaScript de la página, y
cada valor calculado tiene que coincidir con el del evaluador de referencia
del núcleo. Hoy coinciden todos.

El **Saúl Delgado** no está en esa batería. Vive en `exploracion/` porque se
escribió como experimento, para medir el lenguaje contra un caso real. Produce
texto y página web. **La hoja de cálculo todavía no**: la regla de "una
asignatura no repite el mismo día salvo en turnos consecutivos" usa un `o` y
comparaciones aritméticas dentro de un `existe`, y la arquitectura de Excel
todavía no sabe traducir eso a fórmula. Falla con un error claro en vez de
emitir una fórmula equivocada.

Encontrar el horario —que cumpla todas las reglas a la vez— no es parte de
este lenguaje, por decisión: el lenguaje describe y muestra una situación ya
decidida, y señala dónde no cumple. La sección 12 de la guía lo explica.

## Experimentos de alcance

`exploracion/` tiene además cinco descripciones de dominios ajenos a la
facultad, escritas para medir qué se puede describir y qué no. No son
ejemplos terminados: algunas partes fallan a propósito, porque buscaban
límites.

| Dominio | Descripción | Veredicto | Informe |
|---|---|---|---|
| Control de existencias de un almacén | [`exploracion/inventario.lisp`](../exploracion/inventario.lisp) | cabe forzado | [informe](../docs/alcance/inventario.md) |
| Evaluación de un curso | [`exploracion/notas.lisp`](../exploracion/notas.lisp) | cabe a medias | [informe](../docs/alcance/notas.md) |
| Presupuesto y ejecución de un proyecto | [`exploracion/presupuesto.lisp`](../exploracion/presupuesto.lisp) | cabe a medias | [informe](../docs/alcance/presupuesto.md) |
| Torneo de eliminación directa | [`exploracion/torneo.lisp`](../exploracion/torneo.lisp) | cabe a medias | [informe](../docs/alcance/torneo.md) |
| Cuadrante de turnos de guardia | [`exploracion/turnos.lisp`](../exploracion/turnos.lisp) | cabe a medias | [informe](../docs/alcance/turnos.md) |

## Regenerar los resultados

```sh
./ejemplos/actualizar.sh
```

Ejecuta `./demostrar.sh` (que se detiene si algún valor no coincide), copia
los resultados de las cuatro descripciones del corpus, ejecuta la del Saúl
Delgado y copia los suyos. Necesita SBCL, Python con openpyxl, LibreOffice y
Node, igual que la demostración.
