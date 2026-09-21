;;;; Punto de entrada de las pruebas.
;;;;
;;;; Se deja en su propio archivo para que cargar el sistema de pruebas no
;;;; ejecute nada: quien quiera correrlas desde el REPL llama a EJECUTAR, y
;;;; el script llama a EJECUTAR-Y-SALIR.

(in-package #:situacion.pruebas)

;;; Nada que hacer aqui todavia. EJECUTAR y EJECUTAR-Y-SALIR estan en
;;; marco.lisp; este archivo existe para colgar de el la carga de suites
;;; adicionales cuando las haya (conformidad, y las de cada arquitectura).
