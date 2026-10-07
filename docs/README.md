# Documentación

Lo que hay que leer para entender el lenguaje, en orden. Si se prefiere ver
primero los resultados, las descripciones reales de la facultad y lo que
producen están en [`../ejemplos/`](../ejemplos/README.md).

| | Documento | Qué es |
|---|---|---|
| 1 | [`GUIA-DEL-LENGUAJE.md`](GUIA-DEL-LENGUAJE.md) | **El manual.** La sintaxis entera con ejemplos sacados del corpus, el protocolo para añadir una arquitectura, y qué se puede describir hoy y qué no, con la evidencia. Es el más al día |
| 2 | [`01-PARA-ENTENDER.md`](01-PARA-ENTENDER.md) | El porqué: qué se pidió, qué se hereda de cada tesis anterior y qué se construye. No exige saber Common Lisp |
| 3 | [`02-ARQUITECTURA.md`](02-ARQUITECTURA.md) | El diseño del sistema: fases de compilación, protocolo de extensión, capacidades, degradación e invariantes |
| 4 | [`tesis.pdf`](tesis.pdf) | El documento de tesis, en borrador |
| — | [`alcance/`](alcance/README.md) | El experimento de describir cinco dominios ajenos a la facultad, con el veredicto de cada uno |

## Fechas y estado

Ninguno de estos documentos se reescribe cuando cambia el código. Si alguno
discrepa del código, manda el código.

- **`GUIA-DEL-LENGUAJE.md`** — 2026-09-24, actualizada el 2026-10-07.
- **`01-PARA-ENTENDER.md`** — 2026-09-20, antes de escribir el sistema.
- **`02-ARQUITECTURA.md`** — 2026-09-20. Se escribió como propuesta y el
  sistema la implementó después; por eso todavía dice "sin implementar".
- **`tesis.pdf`** — 2026-09-21. Los capítulos 5, 6 y 7 se escribieron contra
  una versión anterior del sistema y se dejaron así a propósito, para no
  borrar cómo se llegó aquí. Las erratas están en el apéndice final
  ("El sistema después del experimento de alcance").
- **`alcance/`** — 2026-09-21. Los fallos que encontró se corrigieron esa
  misma noche o en los días siguientes; cada informe lo dice.

Estos archivos son una copia publicada de la documentación de trabajo, que
vive fuera del repositorio.
