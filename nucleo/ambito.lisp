;;;; Ambitos de evaluacion.
;;;;
;;;; Un ambito dice que variables de fila hay ligadas y sobre que coleccion
;;;; recorre cada una. Nada mas. En particular, NO contiene ninguna
;;;; direccion.
;;;;
;;;; Es la pieza que sustituye a los parametros FILA, PRIMERA-FILA y
;;;; ULTIMA-FILA de COMPILE-EXCEL-FORMULA (Morales Lazo, 2026, listado 5.1).
;;;; Aquellos tres decian donde estaba la fila; este dice de que coleccion
;;;; es. La diferencia es que lo segundo significa algo en cualquier destino.
;;;;
;;;; Las reglas que hacen que la iteracion sea siempre explicita:
;;;;
;;;;   1. Toda derivacion se evalua en un ambito. No hay forma de escribir
;;;;      una expresion sin ambito, asi que no hay "fila actual" implicita.
;;;;   2. (DE V CAMPO) exige que V este ligada y que CAMPO pertenezca a su
;;;;      coleccion. Lo comprueba el analisis.
;;;;   3. EXISTE, BUSQUEDA y AGREGADO ligan una variable nueva y extienden el
;;;;      ambito para su condicion.
;;;;   4. VECINO exige que la coleccion de la variable declare orden.

(in-package #:situacion.nucleo)

(defclass ambito ()
  ((ligaduras :accessor ligaduras :initarg :ligaduras :initform '()
              :documentation
              "Lista asociativa de (SIMBOLO . COLECCION).")
   (actual :accessor actual :initarg :actual :initform nil
           :documentation
           "Cual de las variables ligadas es la fila que se esta evaluando."))
  (:documentation
   "Que variables de fila hay ligadas y sobre que coleccion recorre cada
    una."))

(defun hacer-ambito (&key ligaduras actual)
  (make-instance 'ambito :ligaduras ligaduras :actual actual))

(defun ambito-extendido (ambito variable coleccion)
  "Un ambito nuevo igual a AMBITO mas la ligadura de VARIABLE a COLECCION.

   Devuelve uno nuevo en vez de modificar el que recibe: un ambito se
   comparte entre las ramas de una expresion y no debe cambiar bajo los pies
   de nadie."
  (hacer-ambito :ligaduras (cons (cons variable coleccion) (ligaduras ambito))
                :actual (actual ambito)))

(defun variable-ligada-p (ambito variable)
  (and (assoc variable (ligaduras ambito)) t))

(defun coleccion-de-variable (ambito variable)
  "La coleccion sobre la que recorre VARIABLE, o NIL si no esta ligada."
  (cdr (assoc variable (ligaduras ambito))))
