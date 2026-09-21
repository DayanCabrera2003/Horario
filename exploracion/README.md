# exploracion

**Esto no es parte del sistema.** Ninguno de estos archivos pertenece a un
sistema ASDF, ninguno se carga con `./demostrar.sh` ni con
`./ejecutar-pruebas.sh`, y ninguno cuenta como codigo del trabajo.

Son las descripciones que se escribieron el 2026-09-21 para el experimento de
alcance: cinco dominios ajenos al corpus, redactados en el lenguaje y
ejecutados de verdad para ver que se podia expresar y que no.

| Archivo | Dominio | Veredicto |
|---|---|---|
| `inventario.lisp` | Control de existencias de un almacen | CABE-FORZADO |
| `notas.lisp` | Evaluacion de un curso | CABE-A-MEDIAS |
| `presupuesto.lisp` | Presupuesto y ejecucion de un proyecto | CABE-A-MEDIAS |
| `torneo.lisp` | Torneo de eliminacion directa | CABE-A-MEDIAS |
| `turnos.lisp` | Cuadrante de turnos de guardia | CABE-A-MEDIAS |

Los informes completos, con lo que se pudo expresar, lo que no y por que, estan
en `documentacion/tesis/alcance/`.

**Se conservan a proposito.** Son la evidencia de un metodo de validacion
distinto de la bateria de pruebas: una bateria comprueba lo que ya se sabe;
describir un dominio nuevo comprueba lo que no. Encontro tres fallos que las
pruebas no habian encontrado.

Estan escritos contra el estado del sistema ANTES de los arreglos que ellos
mismos motivaron, asi que algunos ya no reproducen el problema que reportan.
