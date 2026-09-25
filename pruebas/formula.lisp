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

;;; ---------------------------------------------------------------------
;;; COMPARTEN y los valores vacios en Excel (punto 7): la emulacion con
;;; SUMPRODUCT contaba dos vacios como coincidencia.
;;; ---------------------------------------------------------------------

(situacion.lenguaje:defsituacion colision-de-vacios (:etiqueta "Colision")
  (coleccion filas
    (:clave id)
    (campo id :rol fijo :etiqueta "Id")
    (campo m1 :rol fijo :etiqueta "M1")
    (campo m2 :rol fijo :etiqueta "M2"))
  (marca choca :en filas :sobre (m1 m2) :severidad problema
    :cuando (existe otra :en filas :distinta-de fila
                    :donde (comparten otra fila (m1 m2)))))

(defparameter *datos-colision-de-vacios*
  (list (cons (nucleo:nombrar "filas")
              (list (list (cons (nucleo:nombrar "id") "F1"))
                    (list (cons (nucleo:nombrar "id") "F2"))))))

(definir-prueba excel-comparten-exige-no-vacios
    "Excel: COMPARTEN no cuenta dos vacios como coincidencia"
  ;; F1 y F2 no escribieron ni M1 ni M2: el evaluador de referencia y la web
  ;; ya no los consideran en colision (filtran los vacios antes de comparar,
  ;; nucleo/evaluador.lisp COMPARTEN); la formula de Excel tiene que exigir
  ;; lo mismo, no solo la igualdad, o dos celdas en blanco cuentan como
  ;; coincidencia (en Excel, "" = "" es VERDADERO).
  (let* ((s (situacion.lenguaje:situacion-llamada "COLISION-DE-VACIOS"))
         (texto (materializar-en-cadena (situacion.excel:hacer-excel)
                                        s *datos-colision-de-vacios*)))
    (comprobar (search "<>\\\"\\\"" texto)
               "la formula de COMPARTEN en Excel tiene que exigir explicitamente~@
                que los dos lados no esten vacios, no solo que sean iguales")))

;;; ---------------------------------------------------------------------
;;; CUANTAS-DISTINTAS con :DONDE en Excel (punto 8b): la emulacion ignoraba
;;; el filtro y devolvia un numero que no es el que pide la descripcion.
;;; Rechazar, no fingir.
;;; ---------------------------------------------------------------------

(situacion.lenguaje:defsituacion inventario-distintos (:etiqueta "Inventario")
  (coleccion movimientos
    (:clave id)
    (campo id :rol fijo :etiqueta "Id")
    (campo proveedor :rol fijo :etiqueta "Proveedor")
    (campo articulo :rol fijo :etiqueta "Articulo"))
  (coleccion resumen
    (:una-sola-fila)
    (campo distintos-de-acme :rol derivado :tipo entero
           (cuantas-distintas articulo de movimientos :donde (= proveedor "Acme")))))

(defparameter *datos-inventario-distintos*
  (list (cons (nucleo:nombrar "movimientos")
              (loop for (id prov art) in '(("M1" "Acme" "caja") ("M2" "Acme" "resma")
                                            ("M3" "Borja" "caja"))
                    collect (list (cons (nucleo:nombrar "id") id)
                                  (cons (nucleo:nombrar "proveedor") prov)
                                  (cons (nucleo:nombrar "articulo") art))))))

(definir-prueba excel-distintas-con-filtro-se-rechaza
    "Excel: CUANTAS-DISTINTAS con :DONDE se rechaza, no emite un numero equivocado"
  ;; Sin este rechazo, Excel emitiria un SUMPRODUCT sobre TODA la columna,
  ;; ignorando el :DONDE por completo -da igual que el numero resultante
  ;; coincida o no con el correcto en este caso concreto: lo que se prueba
  ;; aqui es que Excel se niegue en vez de fingir que aplico el filtro.
  (let ((s (situacion.lenguaje:situacion-llamada "INVENTARIO-DISTINTOS")))
    (handler-case
        (progn
          (materializar-en-cadena (situacion.excel:hacer-excel)
                                  s *datos-inventario-distintos*)
          (comprobar nil
                     "Excel materializo CUANTAS-DISTINTAS con :DONDE sin quejarse;~@
                      tenia que rechazar: no hay formula portable que aplique el~@
                      filtro, y fingir una da un numero que no es el que se pide"))
      (protocolo:capacidad-no-disponible () (comprobar t)))))
