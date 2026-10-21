;;;; Pruebas de la rejilla de entrada en la hoja de calculo.
;;;;
;;;; Una vista cruzada de entrada en la que cada casilla es una fila lleva el
;;;; dato en la rejilla, editable, y la hoja de datos lo copia con una
;;;; formula (excel/rejilla-de-entrada.lisp). Si no se cumple, la rejilla
;;;; sigue siendo una busqueda de solo lectura.

(in-package #:situacion.pruebas)

(definir-prueba rejilla-de-entrada-lleva-el-dato
    "Rejilla de entrada: el horario del grupo del Saul lleva el dato y se edita"
  (let ((hoja (hoja-llamada (plano-del-saul) "Horario del grupo - 10-3")))
    (comprobar hoja "no hay pestana del horario del 10-3")
    (when hoja
      (comprobar (null (lista-del-plano (dato hoja "formulas")))
                 "la rejilla de entrada no puede llevar formulas: ~s"
                 (first (lista-del-plano (dato hoja "formulas"))))
      (comprobar (find-if (lambda (c) (and (string= (dato c "celda") "B4")
                                           (equal (dato c "valor") "EF")))
                          (lista-del-plano (dato hoja "celdas")))
                 "el lunes, turno 1, el 10-3 tiene EF escrito en B4")
      (comprobar (equal (lista-del-plano (dato hoja "editables")) '("B4:F10"))
                 "las casillas se editan: ~s" (dato hoja "editables"))
      (comprobar (lista-del-plano (dato hoja "validaciones"))
                 "las casillas tienen el desplegable de las asignaturas"))))

(definir-prueba rejilla-de-entrada-la-copia-la-hoja-de-datos
    "Rejilla de entrada: la columna de la hoja de datos lee su casilla y no se edita"
  (let* ((hoja (hoja-de-coleccion (plano-del-saul) "casillas"))
         (celda (celda-de-campo hoja "asignatura" 4))
         (formula (formula-de-celda hoja celda))
         (letra (remove-if #'digit-char-p celda)))
    (comprobar (and formula (search "'Horario del grupo - 10-3'!B4" formula))
               "la asignatura de la primera casilla tiene que leer B4 de la rejilla: ~a"
               formula)
    (comprobar (notany (lambda (r) (eql 0 (search letra r)))
                       (lista-del-plano (dato hoja "editables")))
               "la columna de la asignatura ya no se edita en la hoja de datos: ~s"
               (dato hoja "editables"))
    (comprobar (null (lista-del-plano (dato hoja "validaciones")))
               "la hoja de datos ya no lleva el desplegable de la asignatura")))

(definir-prueba rejilla-con-varias-filas-por-casilla-sigue-buscando
    "Rejilla de entrada: el horario por profesor, donde dos grupos pueden chocar, sigue buscando"
  (let ((hoja (hoja-llamada (plano-del-saul) "HP - Profesor de M en 10-3")))
    (comprobar hoja "no hay pestana del profesor de M en 10-3")
    (when hoja
      (comprobar (formula-de-celda hoja "B4")
                 "la casilla del horario del profesor tiene que seguir siendo formula")
      (comprobar (null (lista-del-plano (dato hoja "editables")))
                 "el horario del profesor no se edita"))))

(definir-prueba rejilla-de-coleccion-que-crece-sigue-buscando
    "Rejilla de entrada: si la coleccion crece, la rejilla sigue buscando"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "CASO-AGENDA")
                          (datos-del-caso "DATOS-DE-AGENDA")))
         (rejilla (find-if (lambda (h) (dato h "cruce")) (hojas-del-plano plano))))
    (comprobar (and rejilla (formula-de-celda rejilla "B4"))
               "la ocupacion de la agenda crece y su casilla tiene que ser formula")))
