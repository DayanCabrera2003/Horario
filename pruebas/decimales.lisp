;;;; Pruebas del formato numerico (fase 2, hueco C6).
;;;;
;;;; Dos piezas separadas. :DECIMALES N en un campo :TIPO NUMERO es solo
;;;; presentacion: el valor no cambia y se escribe con N decimales fijos.
;;;; (REDONDEAR E N) cambia el valor. Las dos redondean al mas cercano y, en
;;;; caso de empate, alejandose de cero, como el formato y ROUND de Excel y
;;;; LibreOffice, y sobre la escritura decimal del numero, no sobre el doble
;;;; binario: 2.675 tiene que dar 2.68 y 1.005, 1.01.

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion con-decimales (:etiqueta "Con decimales")
  (coleccion notas
    (:etiqueta "Notas")
    (:clave nombre)
    (campo nombre :rol fijo :etiqueta "Nombre")
    (campo n1 :rol fijo :tipo entero :etiqueta "N1")
    (campo n2 :rol fijo :tipo entero :etiqueta "N2")
    (campo n3 :rol fijo :tipo entero :etiqueta "N3")
    (campo precio :rol fijo :tipo numero :decimales 2 :etiqueta "Precio")
    (campo promedio :rol derivado :tipo numero :decimales 2 :etiqueta "Promedio"
           (/ (+ (de fila n1) (de fila n2) (de fila n3)) 3))
    (campo nota :rol derivado :tipo entero :etiqueta "Nota"
           (redondear (de fila promedio) 0))
    (campo decima :rol derivado :tipo numero :etiqueta "A la decima"
           (redondear (de fila precio) 1)))
  (vista v :de notas :etiqueta "Notas"))

(defparameter *datos-con-decimales*
  (situacion.casos::datos
   (list "notas"
         (situacion.casos::fila "nombre" "Lia" "n1" 50 "n2" 52 "n3" 55 "precio" 2.675d0)
         (situacion.casos::fila "nombre" "Leo" "n1" 60 "n2" 60 "n3" 61 "precio" ""))))

(defun valores-con-decimales (campo)
  (columna-evaluada (situacion.lenguaje:situacion-llamada "CON-DECIMALES")
                    *datos-con-decimales* "notas" campo))

(definir-prueba decimales-redondeo-con-empate
    "Decimales: el redondeo va al mas cercano y en el empate se aleja de cero"
  (loop for (valor n esperado)
          in '((2.675d0 2 2.68d0) (1.005d0 2 1.01d0) (-1.005d0 2 -1.01d0)
               (2.5d0 0 3) (-2.5d0 0 -3) (0.125d0 2 0.13d0) (52.333333333333336d0 2 52.33d0)
               (3 0 3) (7 2 7) (2.4d0 0 2))
        do (let ((real (nucleo:redondear-a-decimales valor n)))
             (comprobar (and (realp real) (= real esperado)
                             (or (plusp n) (integerp real)))
                        "~s a ~d decimales tiene que dar ~s y da ~s" valor n esperado real)))
  (comprobar (nucleo:vacio-p (nucleo:redondear-a-decimales nil 2))
             "redondear un vacio tiene que dar vacio")
  (comprobar (nucleo:vacio-p (nucleo:redondear-a-decimales "" 2))
             "redondear una cadena vacia tiene que dar vacio"))

(definir-prueba decimales-texto-fijo
    "Decimales: un numero se escribe con exactamente N decimales"
  (loop for (valor n esperado)
          in '((52.333333333333336d0 2 "52.33") (2.5d0 2 "2.50") (12 2 "12.00")
               (0 2 "0.00") (-0.001d0 2 "0.00") (2.675d0 2 "2.68") (2.5d0 0 "3")
               (-2.5d0 0 "-3") (1234.5d0 1 "1234.5"))
        do (comprobar (string= (nucleo:texto-con-decimales valor n) esperado)
                      "~s con ~d decimales tiene que escribirse ~s y se escribe ~s"
                      valor n esperado (nucleo:texto-con-decimales valor n))))

(definir-prueba decimales-no-cambian-el-valor
    "Decimales: el valor del campo sigue completo; solo cambia como se escribe"
  (let ((promedio (first (valores-con-decimales "promedio"))))
    (comprobar (and (realp promedio) (< (abs (- promedio 157/3)) 1d-9))
               "el promedio tiene que seguir valiendo 52.333...: ~s" promedio))
  (let ((texto (materializar-en-cadena (situacion.texto:hacer-texto)
                                       (situacion.lenguaje:situacion-llamada "CON-DECIMALES")
                                       *datos-con-decimales*)))
    (comprobar (search "52.33 " texto) "el texto tiene que escribir el promedio como 52.33")
    (comprobar (not (search "52.33333333" texto)) "el texto no puede escribir todas las cifras")
    (comprobar (search "2.68 " texto) "el precio 2.675 con 2 decimales se escribe 2.68")))

(definir-prueba redondear-en-el-evaluador
    "Redondear: cambia el valor, y un vacio sigue vacio"
  (comprobar (equal (valores-con-decimales "nota") '(52 60))
             "la nota tiene que ser el promedio redondeado: ~s" (valores-con-decimales "nota"))
  (let ((decimas (valores-con-decimales "decima")))
    (comprobar (and (realp (first decimas)) (= (first decimas) 2.7d0)
                    (nucleo:vacio-p (second decimas)))
               "2.675 a la decima es 2.7 y un precio vacio da vacio: ~s" decimas)))

(definir-prueba decimales-errores-de-compilacion
    "Decimales: solo en un campo numero y con un entero de 0 a 10"
  (dolist (campo '((campo nombre :rol fijo :decimales 2)
                   (campo x :rol fijo :tipo entero :decimales 2)
                   (campo x :rol fijo :tipo numero :decimales -1)
                   (campo x :rol fijo :tipo numero :decimales 2.5)
                   (campo x :rol fijo :tipo numero :decimales 11)))
    (comprobar (handler-case (progn (situacion.lenguaje::compilar-campo campo) nil)
                 (error (e) (search ":DECIMALES" (string-upcase (princ-to-string e)))))
               "~s tendria que ser un error que nombre :DECIMALES" campo)))

(definir-prueba decimales-en-la-hoja-de-calculo
    "Decimales: la hoja guarda el valor y da formato a la columna; redondear es ROUND"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "CON-DECIMALES")
                          *datos-con-decimales*))
         (hoja (hoja-de-coleccion plano "notas"))
         (letra (remove-if #'digit-char-p (celda-de-campo hoja "promedio" 4)))
         (formato (find-if (lambda (f) (eql 0 (search letra (dato f "rango"))))
                           (lista-del-plano (dato hoja "formatos_de_celda")))))
    (comprobar (and formato (equal (dato formato "formato") "decimales")
                    (eql (dato formato "decimales") 2))
               "la columna del promedio tiene que llevar formato de 2 decimales: ~s" formato)
    (comprobar (search "ROUND(" (formula-de-celda hoja (celda-de-campo hoja "nota" 4)))
               "redondear tiene que ser ROUND")))

(definir-prueba decimales-en-la-pagina
    "Decimales: la pagina conoce los decimales de cada campo y sabe redondear"
  (let ((html (materializar-en-cadena (situacion.web:hacer-web)
                                      (situacion.lenguaje:situacion-llamada "CON-DECIMALES")
                                      *datos-con-decimales*)))
    (comprobar (search "dec: 2" html) "el campo del promedio tiene que llevar dec: 2")
    (comprobar (search "REDONDEAR(" html) "redondear tiene que traducirse a REDONDEAR")))

(definir-prueba decimales-en-el-oraculo-de-tablas
    "Decimales: el oraculo de las tablas dice los decimales de cada campo"
  (let ((destino (merge-pathnames "situacion-vistas-decimales.json" (uiop:temporary-directory))))
    (situacion.demostracion::escribir-vistas-esperadas
     (situacion.lenguaje:situacion-llamada "CON-DECIMALES") *datos-con-decimales* destino)
    (comprobar (search "\"decimales\": 2" (texto-de-archivo destino))
               "el oraculo tiene que llevar los decimales del promedio")
    (delete-file destino)))
