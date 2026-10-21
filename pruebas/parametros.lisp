;;;; Pruebas de los parametros de entrada en la hoja de calculo.
;;;;
;;;; Hasta el 2026-10-21 la hoja de calculo copiaba el valor de todo
;;;; parametro dentro de las formulas, y :ROL ENTRADA no cambiaba nada: para
;;;; pasar el tope del Saul de 3 a 5 habia que volver a generar el libro.
;;;; Ahora un parametro de entrada tiene su celda en una hoja propia y las
;;;; formulas la citan; uno fijo se sigue copiando.

(in-package #:situacion.pruebas)

(defun plano-de-notas ()
  (plano-de (situacion.lenguaje:situacion-llamada "CASO-NOTAS")
            (datos-del-caso "DATOS-DE-NOTAS")))

(definir-prueba parametro-de-entrada-tiene-su-celda
    "Parametros: uno de entrada tiene su celda editable en la hoja de parametros"
  (let* ((hoja (hoja-llamada (plano-de-notas) "Parametros"))
         (celdas (and hoja (lista-del-plano (dato hoja "celdas")))))
    (comprobar hoja "el caso de notas no tiene hoja de parametros")
    (when hoja
      (comprobar (find-if (lambda (c) (and (string= (dato c "celda") "B4")
                                           (eql (dato c "valor") 60)))
                          celdas)
                 "la nota para aprobar tiene que estar en B4 con su valor: ~s" celdas)
      (comprobar (equal (lista-del-plano (dato hoja "editables")) '("B4:B4"))
                 "solo el valor del parametro se edita: ~s" (dato hoja "editables")))))

(definir-prueba parametro-de-entrada-se-cita-por-su-celda
    "Parametros: una formula cita la celda de uno de entrada, no su valor"
  (let* ((hoja (hoja-de-coleccion (plano-de-notas) "estudiantes"))
         (formula (formula-de-celda hoja (celda-de-campo hoja "resultado" 4))))
    (comprobar (and formula (search "'Parametros'!$B$4" formula))
               "el resultado tiene que citar la celda de la nota para aprobar: ~a"
               formula)))

(definir-prueba parametro-fijo-no-tiene-celda
    "Parametros: uno fijo no ocupa fila en la hoja de parametros"
  (let* ((hoja (hoja-llamada (plano-de-notas) "Parametros"))
         (celdas (and hoja (lista-del-plano (dato hoja "celdas")))))
    (comprobar (notany (lambda (c) (equal (dato c "valor") "Fecha de hoy")) celdas)
               "la fecha de hoy es fija y no tiene que estar en la hoja: ~s" celdas)))

(definir-prueba sin-parametros-de-entrada-no-hay-hoja
    "Parametros: una situacion sin parametros de entrada no tiene esa hoja"
  (let ((plano (plano-de (situacion.lenguaje:situacion-llamada "SEDER")
                         situacion.corpus:datos-del-seder)))
    (comprobar (null (hoja-llamada plano "Parametros"))
               "el SEDER no tiene parametros y no puede tener la hoja")))
