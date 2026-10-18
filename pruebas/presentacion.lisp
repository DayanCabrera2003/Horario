;;;; Pruebas de la presentacion del libro.
;;;;
;;;; La auditoria del 2026-10-17 encontro columnas medidas sobre el texto de
;;;; sus formulas (todas a 42 aunque valieran "no"), un horario impreso con un
;;;; dia por pagina, siete marcas con el mismo color, columnas de clave a la
;;;; vista y rejillas sin pintar.

(in-package #:situacion.pruebas)

(defun plano-del-saul ()
  (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
            situacion.corpus:datos-del-saul))

(definir-prueba presentacion-anchos-medidos-sobre-valores
    "Presentacion: el ancho de una columna se mide sobre lo que ensena, no sobre la formula"
  (let* ((plano (plano-del-saul))
         (rejilla (hoja-llamada plano "Horario del grupo - 10-3"))
         (casillas (hoja-de-coleccion plano "casillas")))
    ;; Los dias de una rejilla ensenan abreviaturas de pocas letras.
    (comprobar (<= (dato (dato rejilla "anchos") "B") 10)
               "la columna del lunes de la rejilla tiene ancho ~a"
               (dato (dato rejilla "anchos") "B"))
    ;; TURNO-DOBLE vale "si" o "no", y su etiqueta es "Turno doble".
    (comprobar (<= (dato (dato casillas "anchos") "J") 14)
               "la columna de turno doble tiene ancho ~a" (dato (dato casillas "anchos") "J"))))

(definir-prueba presentacion-rejilla-cabe-en-una-pagina
    "Presentacion: una rejilla se imprime apaisada y ajustada a una pagina de ancho"
  (let ((impresion (dato (hoja-llamada (plano-del-saul) "Horario del grupo - 10-3")
                         "impresion")))
    (comprobar (and (eq (dato impresion "horizontal") t)
                    (eq (dato impresion "ajustar_ancho") t))
               "la rejilla tiene que imprimirse apaisada y en una pagina de ancho")))

(definir-prueba presentacion-columnas-auxiliares-ocultas
    "Presentacion: las columnas de clave y de nivel no se ven"
  (let* ((casillas (hoja-de-coleccion (plano-del-saul) "casillas"))
         (ocultas (lista-del-plano (dato casillas "columnas_ocultas")))
         (auxiliares (remove-if-not (lambda (e) (and (eql 0 (search "__" (dato e "campo")))
                                                     (not (equal (dato e "campo") "__estado__"))))
                                    (lista-del-plano (dato casillas "encabezados")))))
    (comprobar (= 4 (length auxiliares)) "Casillas tiene nivel y tres claves")
    (dolist (e auxiliares)
      (comprobar (member (string-right-trim "0123456789" (dato e "celda")) ocultas
                         :test #'string=)
                 "la columna ~a (~a) tiene que ir oculta" (dato e "celda") (dato e "texto")))))

(definir-prueba presentacion-cada-marca-su-tono
    "Presentacion: dos marcas de la misma severidad no comparten color en la leyenda"
  (let* ((casillas (hoja-de-coleccion (plano-del-saul) "casillas"))
         (leyenda (lista-del-plano (dato casillas "leyenda")))
         (rellenos (mapcar (lambda (l) (dato l "relleno")) leyenda)))
    (comprobar (= (length rellenos) (length (remove-duplicates rellenos :test #'string=)))
               "hay marcas con el mismo color: ~s" rellenos)
    (comprobar (find "Turno sin asignar" leyenda :key (lambda (l) (dato l "texto"))
                     :test #'string=)
               "la leyenda tiene que decir la explicacion de la marca, no su nombre")))

(definir-prueba presentacion-las-marcas-pintan-las-rejillas
    "Presentacion: las casillas de una rejilla se pintan con las marcas de su fila"
  (let ((rejilla (hoja-llamada (plano-del-saul) "Horario del grupo - 10-3")))
    (comprobar (= 3 (length (lista-del-plano (dato rejilla "formatos_condicionales"))))
               "la rejilla tiene que llevar una regla por severidad")))
