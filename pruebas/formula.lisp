;;;; Pruebas de fidelidad de la traduccion a formula, para divergencias
;;;; confirmadas contra el evaluador de referencia (GUIA-DEL-LENGUAJE.md,
;;;; seccion 11.2).

(in-package #:situacion.pruebas)

;;; ---------------------------------------------------------------------
;;; Aritmetica N-aria (punto 5): (+ a b c) con tres o mas operandos se
;;; truncaba a dos, en Excel y en la web.
;;; ---------------------------------------------------------------------

(defun suma-de-tres-literales ()
  (nucleo:hacer-aplicacion
   :operador '+
   :argumentos (list (nucleo:hacer-literal :valor 1)
                      (nucleo:hacer-literal :valor 2)
                      (nucleo:hacer-literal :valor 3))))

(definir-prueba excel-suma-n-aria
    "Excel: (+ a b c) con tres operandos no trunca al tercero"
  (let ((formula (protocolo:emitir-expresion (situacion.excel:hacer-excel)
                                             (suma-de-tres-literales) nil nil)))
    (comprobar (search "3" formula)
               "la formula ~s deberia mencionar los tres operandos, no solo dos"
               formula)))

(definir-prueba web-suma-n-aria
    "Web: (+ a b c) con tres operandos no trunca al tercero"
  (let ((js (protocolo:emitir-expresion (situacion.web:hacer-web)
                                        (suma-de-tres-literales) nil nil)))
    (comprobar (search "3" js)
               "la expresion ~s deberia mencionar los tres operandos, no solo dos"
               js)))
