;;;; Pruebas de lo que el plano le dice al verificador.
;;;;
;;;; La auditoria del 2026-10-17 encontro que materializador/verificar.py
;;;; emparejaba las hojas con el oraculo por el conjunto de nombres de campo.
;;;; Toda hoja con una columna anadida por la arquitectura -las de clave de
;;;; las tablas cruzadas- dejaba de encajar y se saltaba en silencio: la hoja
;;;; principal del horario del Saul no se habia comparado nunca.
;;;;
;;;; El arreglo es que cada hoja del plano diga que es. El verificador
;;;; empareja por eso y falla si una hoja no tiene con que compararse.

(in-package #:situacion.pruebas)

(defparameter +identidades-de-hoja+ '("coleccion" "cruce" "relacion" "vista" "auxiliar")
  "Las claves con que una hoja del plano dice que es. Cada hoja lleva
   exactamente una.")

(defun identidades-de (hoja)
  (remove-if-not (lambda (clave) (assoc clave hoja :test #'string=))
                 +identidades-de-hoja+))

(definir-prueba plano-cada-hoja-dice-que-es
    "Verificacion: cada hoja del plano lleva una sola identidad"
  (let ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                         situacion.corpus:datos-del-saul)))
    (dolist (hoja (hojas-del-plano plano))
      (comprobar (= 1 (length (identidades-de hoja)))
                 "la hoja ~s lleva ~d identidades (~{~a~^, ~}); tiene que llevar una"
                 (dato hoja "nombre") (length (identidades-de hoja))
                 (identidades-de hoja)))))

(definir-prueba plano-la-hoja-de-datos-nombra-su-coleccion
    "Verificacion: la hoja de datos nombra su coleccion, tenga o no columnas de clave"
  ;; CASILLAS tiene tres tablas cruzadas encima y por tanto tres columnas de
  ;; clave compuesta: es exactamente la hoja que el verificador se saltaba.
  (let ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                         situacion.corpus:datos-del-saul)))
    (dolist (coleccion '("casillas" "asignaturas" "plan-por-grupo" "profesores"
                         "disponibilidad" "carga-diaria"))
      (comprobar (hoja-de-coleccion plano coleccion)
                 "no hay ninguna hoja que diga ser de la coleccion ~a" coleccion))))

(definir-prueba plano-la-hoja-de-relacion-dice-de-quien-es
    "Verificacion: la hoja auxiliar de una relacion dice su campo y sus bloques"
  (let* ((plano (plano-de (situacion-de-carga) *datos-de-carga*))
         (hoja (find-if (lambda (h) (dato h "relacion")) (hojas-del-plano plano)))
         (relacion (and hoja (dato hoja "relacion"))))
    (comprobar hoja "la relacion de CARGA-DE-PROFESORES no tiene hoja auxiliar")
    (when relacion
      (comprobar (equal (dato relacion "coleccion") "profesores")
                 "la relacion tiene que nombrar la coleccion padre")
      (comprobar (equal (dato relacion "campo") "asignaciones")
                 "la relacion tiene que nombrar su campo")
      (comprobar (= 3 (length (lista-del-plano (dato relacion "bloques"))))
                 "tiene que haber un bloque por profesor"))))
