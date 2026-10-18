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
| Horario docente de 10mo grado del preuniversitario Saúl Delgado: el horario real de 10-3 y 10-4, por grupo, por profesor y por aula, con las reglas del enunciado | [`corpus/horario-saul.lisp`](../corpus/horario-saul.lisp) | [xlsx](resultados/horario-saul.xlsx) · [html](resultados/horario-saul.html) · [txt](resultados/horario-saul.txt) |
| Horario de educación física del SEDER: horario e instalación de cada brigada | [`corpus/seder.lisp`](../corpus/seder.lisp) | [xlsx](resultados/seder.xlsx) · [html](resultados/seder.html) · [txt](resultados/seder.txt) |

Las páginas `.html` son editables: se escribe en una casilla y lo calculado y
las marcas se actualizan solos. Los `.xlsx` igual, con desplegables y
fórmulas vivas. Los `.txt` son la misma situación sin nada vivo, para ver en
la terminal.

Los datos del Saúl Delgado son reales. Los de las demás son de ejemplo, con
problemas puestos a propósito para que se vea cada marca:

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
- **SEDER** — una brigada en una instalación más pequeña que ella, dos
  brigadas en la misma instalación a la vez, una brigada en un horario que
  su año no tiene y con un profesor que ya está en otra, una brigada sin
  clase, y el reparto desequilibrado entre instalaciones y entre horarios.

### El Saúl Delgado, con su horario real

Los datos son el horario de 10-3 y 10-4, "última versión" del 14/09/26,
transcrito de la hoja impresa con las correcciones hechas a mano. El día es
el que usa el centro: seis turnos de mañana y uno de tarde (la descripción
hablaba de ocho). Las frecuencias se contaron del propio horario y dan lo
mismo en los dos grupos, 31 sesiones cada uno.

**Lo que el horario no dice está puesto como supuesto**, marcado en el
archivo donde se usa, hasta que el centro lo dé:

- los profesores: se supone uno distinto por asignatura y grupo, así que
  hoy no puede salir ningún choque de profesores;
- los locales: el aula del grupo, salvo Educación Física (terreno) e
  Informática (laboratorio);
- los días de preparación, los contratados y los que viven lejos: ninguno;
- qué asignaturas admiten tarde: solo AL/AC, la única que el horario pone
  en el turno 7;
- el nombre de CP, DC, CA, RD y AL/AC.

Contra ese horario, **el modelo señala una sola cosa**: Lit-L tiene dos
sesiones seguidas el mismo día en los dos grupos (10-3 el jueves, turnos 3 y
4; 10-4 el viernes, turnos 1 y 2). Según la descripción, solo admiten turno
doble las asignaturas de frecuencia cinco, y Lit-L tiene cuatro. O el
horario incumple la regla, o la regla tiene una excepción que la
descripción no recoge.

## Lo que está verificado y lo que no

Las seis las comprueba `./demostrar.sh` en cada ejecución, y desde el
2026-10-17 se compara todo lo que producen, no solo los valores calculados:

- **el libro**: LibreOffice lo recalcula y se compara cada hoja, la de datos,
  las tablas cruzadas casilla por casilla, la columna de estado con la
  explicación de las marcas, las hojas auxiliares de las relaciones y las de
  las vistas derivadas; cualquier celda con un error de fórmula es un fallo;
- **el texto plano**: se leen sus tablas y rejillas por columnas;
- **la página**: Node ejecuta su cálculo y Chromium la abre para comparar lo
  que dibuja;
- **el uso**: se escribe en la página sin perder el foco y en el libro una
  fila nueva.

Hoy coinciden todos; solo el Saúl Delgado son 3 585 celdas en LibreOffice,
3 630 en el texto, 3 210 valores en Node y 3 639 celdas dibujadas. Hasta el
2026-10-17 la hoja principal del Saúl, "Casillas del horario", no se
comparaba, y allí 118 celdas enseñaban un 0 donde iba un blanco.

En las tablas cruzadas, todas las pestañas de una vista tienen los mismos
ejes: cada horario por profesor o por aula es de siete turnos por cinco días,
en el orden de la descripción (los turnos van por su `:orden`, los días en el
orden en que aparecen en los datos). Las casillas se pintan con las marcas de
su fila. Lo que todavía no se puede es declarar el orden de un eje que no es
el campo de orden de la colección: en el SEDER, la semana impar sigue
poniendo "3 p.m." antes que "11 a.m." porque así aparecen en los datos.

Encontrar el horario —que cumpla todas las reglas a la vez— no es parte de
este lenguaje, por decisión: el lenguaje describe y muestra una situación ya
decidida, y señala dónde no cumple. La sección 12 de la guía lo explica.

## Experimentos de alcance

`exploracion/` tiene cinco descripciones de dominios ajenos a la
facultad, escritas para medir qué se puede describir y qué no. No son
ejemplos terminados: algunas partes sondean límites a propósito. Se generan y
se verifican con `./explorar.sh`. Las descripciones nuevas de la auditoría del
2026-10-17 (compras, notas, agenda, inventario, horas, préstamos, textos con
signos raros) están en `pruebas/casos/` y las verifica `./demostrar.sh`.

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

Ejecuta `./demostrar.sh`, que se detiene si algún valor no coincide, y
copia los resultados de las seis descripciones. Necesita SBCL, Python con
openpyxl, LibreOffice, Node y Chromium, igual que la demostración.
