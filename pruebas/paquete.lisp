;;;; Paquete de pruebas.
;;;;
;;;; Las pruebas alcanzan los interiores de los paquetes que comprueban: usan
;;;; el doble dos puntos a proposito donde hace falta. Un invariante
;;;; arquitectonico tiene que poder mirar dentro.

(defpackage #:situacion.pruebas
  (:use #:common-lisp)
  (:documentation
   "Pruebas del sistema. Incluye los invariantes arquitectonicos, que son
    los que convierten las afirmaciones de diseno en algo que falla solo si
    alguien las incumple.")
  (:export #:definir-prueba
           #:comprobar
           #:ejecutar
           #:ejecutar-y-salir))
