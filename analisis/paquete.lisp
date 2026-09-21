;;;; Paquete del analisis.
;;;;
;;;; Todo lo que se puede comprobar sin saber a donde se va a generar. Es la
;;;; fase 4 de la compilacion, y su salida -la situacion resuelta- es la
;;;; representacion intermedia: lo que la tesis afirma independiente del
;;;; destino.
;;;;
;;;; Atiende ademas una recomendacion explicita de Morales Lazo (2026), que
;;;; pedia "una herramienta de validacion estatica del AST que detecte
;;;; referencias a columnas inexistentes o rangos cruzados inconsistentes
;;;; antes de la fase de generacion, con el fin de reducir el ciclo de
;;;; depuracion".

(defpackage #:situacion.analisis
  (:use #:common-lisp)
  (:nicknames #:analisis)
  (:documentation
   "Resolucion de nombres y comprobaciones estaticas, independientes de
    cualquier arquitectura.")
  (:export #:analizar #:comprobar-situacion
           #:problema #:problemas #:texto-de-problema #:gravedad-de-problema
           #:situacion-invalida #:informe-de-problemas))
