;;;; Pruebas de que una coleccion que crece deja anadir filas.
;;;;
;;;; La auditoria del 2026-10-17 encontro que no se podia: en la hoja de
;;;; calculo los campos fijos de las filas de reserva estaban bloqueados (la
;;;; abreviatura y el nombre de una asignatura nueva no se podian escribir),
;;;; y en la pagina la fila nueva no tenia controles para ellos. En una
;;;; coleccion que crece, fijo quiere decir que lo escribe quien crea la fila
;;;; y despues no cambia.

(in-package #:situacion.pruebas)

(defun dentro-de-rango-p (celda rango)
  "Cierto si CELDA (\"A28\") cae dentro de RANGO (\"A27:A29\"), de una columna."
  (let* ((dos-puntos (position #\: rango))
         (desde (subseq rango 0 dos-puntos))
         (hasta (subseq rango (1+ dos-puntos)))
         (letra (string-right-trim "0123456789" celda))
         (numero (lambda (c) (parse-integer (string-left-trim "ABCDEFGHIJKLMNOPQRSTUVWXYZ" c)))))
    (and (string= letra (string-right-trim "0123456789" desde))
         (<= (funcall numero desde) (funcall numero celda) (funcall numero hasta)))))

(definir-prueba crecer-la-reserva-deja-escribir-los-fijos
    "Crecer: en la hoja de calculo los fijos de las filas de reserva se pueden escribir"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "PLAN-DEL-GRUPO")
                          situacion.corpus:datos-del-plan))
         (hoja (hoja-de-coleccion plano "asignaturas"))
         (editables (lista-del-plano (dato hoja "editables"))))
    ;; Seis asignaturas en las filas 4 a 9; la reserva empieza en la 10.
    (comprobar (some (lambda (r) (dentro-de-rango-p "A10" r)) editables)
               "la abreviatura de una asignatura nueva tiene que poder escribirse: ~s"
               editables)
    (comprobar (notany (lambda (r) (dentro-de-rango-p "A4" r)) editables)
               "la abreviatura de una asignatura que ya vino con los datos no se toca")))

(definir-prueba crecer-la-fila-nueva-de-la-pagina-tiene-controles
    "Crecer: en la pagina, una fila anadida tiene controles para sus campos fijos"
  (let ((html (materializar-en-cadena (situacion.web:hacer-web)
                                      (situacion.lenguaje:situacion-llamada "PLAN-DEL-GRUPO")
                                      situacion.corpus:datos-del-plan)))
    (comprobar (search "(c.rol === 'fijo' && fila.__nueva)" html)
               "un campo fijo de una fila nueva tiene que ser un control")))
