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

Y uno mas que no es ajeno al corpus: `saul.lisp`, el primer intento con el
horario del preuniversitario Saul Delgado, con datos inventados. Se conserva
como experimento. La descripcion que vale es `corpus/horario-saul.lisp`, con
el horario real del centro; sus resultados estan en
[`ejemplos/`](../ejemplos/README.md).

**Se generan y se verifican con `./explorar.sh`**, desde la raiz del
repositorio. Durante semanas dejaron de funcionar sin que nadie lo viera:
internaban los nombres de los datos en el paquete `situacion.nucleo`, que el
nucleo ya no usaba, y el evaluador tiraba esos datos en silencio, asi que
salian tablas vacias y la verificacion daba "ok" con cero celdas. Desde el
2026-10-17 los datos se nombran con `nucleo:nombrar`, el nucleo falla si los
datos traen algo que la situacion no declara, y `./explorar.sh` carga todos los
experimentos, falla si alguno no carga y verifica todo lo que generan contra el
evaluador de referencia.

**Se conservan a proposito.** Son la evidencia de un metodo de validacion
distinto de la bateria de pruebas: una bateria comprueba lo que ya se sabe;
describir un dominio nuevo comprueba lo que no. Encontro tres fallos que las
pruebas no habian encontrado.

Estan escritos contra el estado del sistema ANTES de los arreglos que ellos
mismos motivaron, asi que algunos ya no reproducen el problema que reportan.
Los cuatro fallos que seguian abiertos el 2026-10-17 (el acumulado con
`(anterior fila)` que daba `#VALUE!` en la hoja de calculo, la division que
daba `45/2`, el `:si-no` de la pagina con una fila que existe sin valor y el
emparejamiento de hojas del torneo B en el verificador) estan arreglados, y
`./explorar.sh` lo comprueba. La sonda del orden compuesto de `turnos.lisp`
usa desde la fase 2 (hueco C3) `(:orden dia turno)` y
`(anterior fila :mismo dia)`, y se materializa en las tres arquitecturas.
