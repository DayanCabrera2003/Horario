;;;; Los booleanos del lenguaje.
;;;;
;;;; DECISION (plan aprobado PLAN-TIPOS-FECHA-HORA-BOOLEANO.md, seccion 3, y
;;;; robustez del 2026-10-17): un valor booleano se representa como la cadena
;;;; "si" o la cadena "no". No como T y NIL de Common Lisp -NIL ya significa
;;;; "sin escribir"-, ni como VERDADERO y FALSO de la hoja de calculo, ni como
;;;; true y false de JavaScript.
;;;;
;;;; Antes cada destino escribia su propia palabra: un campo derivado que era
;;;; una comparacion valia "" en el texto plano, FALSE en la hoja de calculo y
;;;; false en la pagina, que ademas lo ensenaba crudo, en ingles.
;;;;
;;;; Aqui viven las tres piezas que necesita cualquier arquitectura:
;;;;
;;;;   EXPRESION-BOOLEANA-P  si una expresion da, por su forma, verdadero o
;;;;                         falso: una comparacion, Y, O, NO, VACIO?, EXISTE,
;;;;                         COMPARTEN. Se sabe sin evaluar nada.
;;;;   CAMPO-BOOLEANO-P      si un campo derivado vale "si" o "no": porque su
;;;;                         expresion es booleana o porque declara :TIPO
;;;;                         BOOLEANO.
;;;;   VERDADERO-P           cuando un valor cuenta como verdadero en una
;;;;                         condicion: T, "si", o un numero distinto de cero.
;;;;                         Asi un campo que vale "no" es falso al usarlo en
;;;;                         un SI o en el :CUANDO de una marca.

(in-package #:situacion.nucleo)

(defparameter +operadores-booleanos+ '("=" "/=" "<" "<=" ">" ">=" "Y" "O" "NO")
  "Los operadores cuyo resultado es verdadero o falso, por nombre.")

(defun expresion-booleana-p (e)
  "Cierto si E, por su forma, da verdadero o falso."
  (typecase e
    (aplicacion (and (member (symbol-name (operador e)) +operadores-booleanos+
                             :test #'string=)
                     t))
    ((or sin-escribir existe comparten) t)
    (t nil)))

(defun campo-booleano-p (campo)
  "Cierto si CAMPO es derivado y vale \"si\" o \"no\"."
  (and (eq (rol campo) :derivado)
       (expresion campo)
       (or (eq (tipo campo) :booleano)
           (expresion-booleana-p (expresion campo)))))

(defun verdadero-p (valor)
  "Si VALOR cuenta como verdadero en una condicion."
  (cond ((null valor) nil)
        ((eq valor t) t)
        ((stringp valor) (string= valor "si"))
        ((realp valor) (/= valor 0))
        (t t)))

(defun como-booleano (valor)
  "VALOR como \"si\" o \"no\"."
  (if (verdadero-p valor) "si" "no"))
