;;;; Descripciones del corpus.
;;;;
;;;; Estas descripciones son la prueba de fuego del lenguaje: no son ejemplos
;;;; inventados, son los documentos que la facultad usa de verdad, escritos en
;;;; el lenguaje en vez de en Python.
;;;;
;;;; El criterio de calidad, heredado de LDMAG (2025): el tutor tiene que
;;;; poder leer una de estas y decir si es correcta sin que se la expliquen.
;;;; Si hay que explicarla, el vocabulario esta mal elegido.

(defpackage #:situacion.corpus
  (:use #:common-lisp #:situacion.lenguaje)
  (:documentation "Los libros de la facultad, descritos en el lenguaje.")
  (:export #:plan-del-grupo #:defensas-de-tesis #:horario-del-grupo
           #:datos-del-plan #:datos-de-las-defensas #:datos-del-horario))
