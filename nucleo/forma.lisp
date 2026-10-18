;;;; La forma de una fecha o una hora.
;;;;
;;;; Plan aprobado PLAN-TIPOS-FECHA-HORA-BOOLEANO.md, seccion 4.2. Por cada
;;;; campo :TIPO FECHA o :TIPO HORA, el lenguaje anade a la situacion una
;;;; marca que el autor no escribio y que senala el valor que no tiene la
;;;; forma esperada: AAAA-MM-DD para una fecha, HH:MM para una hora. La
;;;; condicion de esa marca es este nodo.
;;;;
;;;; No es vocabulario del lenguaje -ningun libro del corpus lo necesita-,
;;;; sino infraestructura del compilador: por eso vive aqui y no en
;;;; expresion.lisp, cuyas construcciones salen todas de un uso real.
;;;;
;;;; Que predicado aplicar no lo guarda el nodo: sale del :TIPO del campo en
;;;; su coleccion. Asi no puede quedar desincronizado si el campo cambia de
;;;; tipo.

(in-package #:situacion.nucleo)

(defnodo forma-invalida (expresion)
  ((variable "Variable de la fila cuyo campo se mira.")
   (campo "Nombre del campo :TIPO FECHA o :TIPO HORA."))
  "Cierto si el campo tiene un valor que no es una fecha AAAA-MM-DD o una
   hora HH:MM, segun su tipo.")

(defun tipo-de-forma (coleccion campo)
  "El tipo, :FECHA o :HORA, del campo CAMPO de COLECCION, o NIL."
  (let ((c (campo-llamado coleccion campo)))
    (and c (member (tipo c) '(:fecha :hora)) (tipo c))))

(defun forma-valida-p (tipo valor)
  "Si VALOR tiene la forma que pide TIPO. Un valor vacio no se juzga aqui:
   la marca sintetica ya exige que haya algo escrito."
  (and (stringp valor)
       (ecase tipo
         (:fecha (and (fecha-como-numero valor) t))
         (:hora (and (hora-como-numero valor) t)))))

(defmethod evaluar ((e forma-invalida) ambito entorno ligaduras)
  (declare (ignore ambito))
  (let* ((fila (fila-ligada ligaduras (variable e)))
         (tipo (tipo-de-forma (coleccion fila) (campo e))))
    (and tipo
         (not (forma-valida-p tipo (valor-de-campo entorno fila (campo e)))))))
