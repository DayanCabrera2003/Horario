;;;; Pruebas de la comparacion exacta en la hoja de calculo.
;;;;
;;;; La igualdad del lenguaje es literal: distingue mayusculas y no tiene
;;;; comodines. La hoja de calculo, por defecto, hace las dos cosas al reves
;;;; en COINCIDIR, CONTAR.SI, SUMAR.SI y BUSCARV. La auditoria del 2026-10-17
;;;; lo midio: "Frutas*" sumaba tambien "Frutas", "Lacteos" y "lacteos" se
;;;; confundian, y en una rejilla la columna "Sala*" ensenaba la reunion de
;;;; "Sala Azul".
;;;;
;;;; Estas pruebas miran las formulas del plano. Que ademas den el valor
;;;; correcto lo comprueba ./demostrar-robustez.sh con LibreOffice.

(in-package #:situacion.pruebas)

(defun formulas-de-la-hoja (hoja)
  "Todas las formulas de HOJA juntas, para buscar en ellas."
  (format nil "~{~a~%~}" (mapcar (lambda (f) (dato f "formula"))
                                 (lista-del-plano (dato hoja "formulas")))))

(defun plano-de-compras-b ()
  (plano-de (situacion.lenguaje:situacion-llamada "CASO-COMPRAS-B")
            (symbol-value (find-symbol "DATOS-DE-COMPRAS-B" '#:situacion.casos))))

(definir-prueba excel-agregado-con-condicion-es-exacto
    "Comparacion exacta: SUMA y CUANTAS con :DONDE no usan CONTAR.SI ni SUMAR.SI"
  (let* ((plano (plano-de-compras-b))
         (formulas (formulas-de-la-hoja (hoja-de-coleccion plano "categorias"))))
    (comprobar (search "EXACT(" formulas)
               "la suma por categoria tiene que comparar con EXACT: ~a" formulas)
    (dolist (funcion '("SUMIF" "COUNTIF"))
      (comprobar (not (search funcion formulas))
                 "~a no distingue mayusculas y lee comodines" funcion))))

(definir-prueba excel-busqueda-es-exacta-y-respeta-el-blanco
    "Comparacion exacta: LA-FILA-DE no usa BUSCARV y un campo en blanco da blanco"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                          situacion.corpus:datos-del-saul))
         (hoja (hoja-de-coleccion plano "casillas"))
         (formula (formula-de-celda hoja (celda-de-campo hoja "local" 4))))
    (comprobar formula "no hay formula en la columna del local de la asignatura")
    (when formula
      (comprobar (not (search "VLOOKUP" formula))
                 "BUSCARV no distingue mayusculas: ~a" formula)
      (comprobar (search "EXACT(" formula) "la busqueda tiene que ser exacta: ~a" formula)
      (comprobar (search "ISBLANK(" formula)
                 "la busqueda tiene que dar blanco, no 0, si el campo esta vacio: ~a"
                 formula))))

(definir-prueba excel-igualdad-es-exact
    "Comparacion exacta: (= a b) se compila a EXACT y (/= a b) a NOT(EXACT)"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                          situacion.corpus:datos-del-saul))
         ;; PROFESOR-ASISTE-HOY de las casillas es (si (= (de fila
         ;; profesor-contratado) "si") ...). Hasta el 2026-10-21 se miraba
         ;; TURNO-DOBLE del plan, que dejo de ser derivado. Se busca la
         ;; columna por el campo para no depender de donde cae.
         (hoja (hoja-de-coleccion plano "casillas"))
         (formula (formula-de-celda hoja (celda-de-campo hoja "profesor-asiste-hoy" 4))))
    (comprobar (and formula (search "EXACT(" formula))
               "la igualdad tiene que ser EXACT: ~a" formula)))

(definir-prueba excel-casilla-cruzada-es-exacta
    "Comparacion exacta: la casilla de una tabla cruzada no usa COINCIDIR a secas"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "CASO-AGENDA")
                          (symbol-value (find-symbol "DATOS-DE-AGENDA"
                                                     '#:situacion.casos))))
         (rejilla (find-if (lambda (h) (dato h "cruce")) (hojas-del-plano plano)))
         (formula (and rejilla (formula-de-celda rejilla "B4"))))
    (comprobar formula "la agenda no tiene rejilla con formula en B4")
    (when formula
      (comprobar (search "EXACT(" formula) "la casilla tiene que buscar con EXACT: ~a" formula)
      (comprobar (not (search "COUNTIF" formula))
                 "el conteo de la casilla no puede ser CONTAR.SI: ~a" formula))))
