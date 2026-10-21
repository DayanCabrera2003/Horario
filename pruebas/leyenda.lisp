;;;; Pruebas de la leyenda de las marcas en la hoja de calculo.
;;;;
;;;; Cuando la explicacion de una marca depende de la fila ("Tiene 3 brigadas
;;;; y otra tiene 1"), la leyenda no tenia frase que ensenar y ponia el nombre
;;;; interno, "instalacion desequilibrada". Ray no supo que significaba. Desde
;;;; el 2026-10-21 la marca puede declarar :LEYENDA, una frase fija.

(in-package #:situacion.pruebas)

(defun textos-de-leyenda (plano coleccion)
  "Los textos de la leyenda de la hoja de COLECCION."
  (mapcar (lambda (l) (dato l "texto"))
          (lista-del-plano (dato (hoja-de-coleccion plano coleccion) "leyenda"))))

(definir-prueba leyenda-usa-la-frase-declarada
    "Leyenda: una marca con :leyenda la ensena en vez de su nombre"
  (let ((textos (textos-de-leyenda (plano-de (situacion.lenguaje:situacion-llamada "SEDER")
                                             situacion.corpus:datos-del-seder)
                                   "instalaciones")))
    (comprobar (member "La instalacion tiene 2 brigadas o mas por encima de la que menos tiene"
                       textos :test #'equal)
               "la leyenda de las instalaciones tiene que decir que significa: ~s" textos)
    (comprobar (not (member "instalacion desequilibrada" textos :test #'equal))
               "la leyenda no puede ensenar el nombre interno: ~s" textos)))

(definir-prueba leyenda-sin-frase-sigue-con-el-nombre
    "Leyenda: una marca sin :leyenda ni explicacion fija sigue ensenando su nombre"
  (let ((textos (textos-de-leyenda (plano-de-notas) "estudiantes")))
    (comprobar (member "suspenso" textos :test #'equal)
               "el caso de notas no declara leyenda y tiene que seguir con el nombre: ~s"
               textos)))

(definir-prueba leyenda-tiene-que-ser-texto
    "Leyenda: :leyenda que no es un texto es un error que la nombra"
  (comprobar (handler-case
                 (progn (situacion.lenguaje::compilar-marca
                         '(marca m :sobre (a) :cuando (vacio? (de fila a)) :leyenda (texto "x")))
                        nil)
               (error (e) (search ":LEYENDA" (string-upcase (princ-to-string e)))))
             ":leyenda con una expresion tiene que ser un error que nombre :LEYENDA"))
