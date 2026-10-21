;;;; Lo que se escribe a mano en la hoja de calculo: que celdas se
;;;; desbloquean y que desplegables llevan.
;;;;
;;;; Sale del rol de campo: los de entrada se editan en todas las filas, los
;;;; fijos de una coleccion que crece en las filas de reserva, y un campo con
;;;; dominio lleva su lista. Salio de excel/emision.lisp el 2026-10-21.

(in-package #:situacion.excel)

(defun rangos-editables (plan hoja)
  "Los rangos donde el usuario puede escribir.

   Salen del rol de campo. Los campos de entrada, en todas las filas. Los
   fijos de una coleccion que crece, en las filas de reserva: en una
   coleccion que crece, fijo quiere decir que lo escribe quien crea la fila
   y despues no cambia. Antes quedaban bloqueados, y no habia forma de
   anadir una fila sin desproteger la hoja. Todo lo demas queda bloqueado
   al proteger la hoja, que es lo que impide borrar una formula sin querer."
  (let ((coleccion (coleccion hoja)))
    (append
     (loop for campo in (nucleo:campos-de-rol coleccion :entrada)
           unless (rejilla-que-escribe plan hoja (nucleo:nombre campo))
           collect (format nil "~a~d:~a~d"
                           (columna-de hoja (nucleo:nombre campo)) (fila-primera hoja)
                           (columna-de hoja (nucleo:nombre campo)) (fila-ultima hoja)))
     (when (eq (nucleo:crecimiento coleccion) :crece)
       (let ((primera-de-reserva (+ (fila-primera hoja) (filas-reales plan hoja))))
         (when (<= primera-de-reserva (fila-ultima hoja))
           (loop for campo in (nucleo:campos-de-rol coleccion :fijo)
                 collect (format nil "~a~d:~a~d"
                                 (columna-de hoja (nucleo:nombre campo)) primera-de-reserva
                                 (columna-de hoja (nucleo:nombre campo)) (fila-ultima hoja)))))))))

(defun validaciones-de (a plan hoja)
  "El desplegable de cada campo de entrada con dominio.

   :AL-VIOLAR ADVERTIR se traduce a un aviso no bloqueante, que es lo que
   hacen los libros del corpus; :IMPEDIR, a uno que si bloquea. La diferencia
   la declara el lenguaje porque es del dominio: hay restricciones que
   invalidan y restricciones que solo advierten."
  (let ((ambito (ambito-de (coleccion hoja)))
        (*hoja* hoja))
    (loop for campo in (nucleo:campos-de-rol (coleccion hoja) :entrada)
          when (and (nucleo:dominio campo)
                    (not (rejilla-que-escribe plan hoja (nucleo:nombre campo))))
            collect (protocolo:emitir-entrada a campo ambito plan))))

(defmethod protocolo:emitir-entrada ((a excel) campo ambito plan)
  "Un campo de entrada con dominio es un desplegable.

   :AL-VIOLAR ADVERTIR se traduce a un aviso no bloqueante e :IMPEDIR a uno
   que si bloquea. La diferencia la declara el lenguaje porque es del dominio."
  (declare (ignore ambito))
  (let ((letra (columna-de *hoja* (nucleo:nombre campo))))
    (desplegable a plan campo (format nil "~a~d:~a~d" letra (fila-primera *hoja*)
                                      letra (fila-ultima *hoja*)))))

(defun desplegable (a plan campo rango)
  "La validacion de lista de CAMPO sobre RANGO. La usan la columna de la
   hoja de datos y la rejilla de entrada, que escribe el mismo campo en otro
   sitio (excel/rejilla-de-entrada.lisp)."
  (let ((valores (valores-del-dominio a plan campo)))
    (list (cons "rango" rango)
          (cons "tipo" "lista")
          ;; Los valores van a una hoja oculta y la validacion cita su rango:
          ;; escritos dentro de la validacion, una coma partia un valor en dos.
          (cons "lista" (if valores (registrar-lista plan valores) :false))
          (cons "valores" (lista (mapcar #'nucleo:como-texto valores)))
          (cons "bloquea" (if (eq (nucleo:al-violar campo) :impedir) t :false)))))

(defun valores-del-dominio (a plan campo)
  "Los valores admisibles, vengan de una coleccion o escritos a mano.

   Se evaluan con el evaluador de referencia del nucleo, que es quien sabe
   que significa un conjunto. El backend no tiene que distinguir entre
   (los x de y) y (uno-de \"a\" \"b\"): los dos son expresiones de conjunto."
  (declare (ignore a))
  ;; Los valores se dejan como son: un numero sigue siendo numero en la
  ;; lista, para que coincida con el numero que el usuario teclee.
  (handler-case
      (mapcar #'nucleo:normalizar-numero
              (nucleo:evaluar (nucleo:dominio campo) (nucleo:hacer-ambito)
                              (entorno plan) '()))
    (error () '())))
