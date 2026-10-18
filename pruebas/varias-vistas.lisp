;;;; Pruebas de varias vistas de lista sobre la misma coleccion.
;;;;
;;;; Las tres arquitecturas dibujaban una tabla por coleccion, con la
;;;; agrupacion de la primera vista que agrupara: dos vistas sobre los mismos
;;;; prestamos, por lector y por sala, salian como una sola tabla por lector,
;;;; y el informe decia que se cumplian las dos.

(in-package #:situacion.pruebas)

(defun biblioteca () (situacion.lenguaje:situacion-llamada "CASO-BIBLIOTECA"))
(defun datos-de-biblioteca () (datos-del-caso "DATOS-DE-BIBLIOTECA"))

(definir-prueba varias-vistas-en-el-texto
    "Varias vistas: el texto escribe una tabla por vista, con su etiqueta"
  (let ((texto (materializar-en-cadena (situacion.texto:hacer-texto) (biblioteca)
                                       (datos-de-biblioteca))))
    (dolist (titulo '("Préstamos por lector" "Préstamos por sala"))
      (comprobar (search (format nil "~%~a~%" titulo) texto)
                 "el texto no tiene la tabla ~s" titulo))))

(definir-prueba varias-vistas-en-la-pagina
    "Varias vistas: la pagina dibuja una tabla por vista"
  (let ((html (materializar-en-cadena (situacion.web:hacer-web) (biblioteca)
                                      (datos-de-biblioteca))))
    (dolist (titulo '("Préstamos por lector" "Préstamos por sala"))
      (comprobar (search (format nil "titulo: \"~a\"" titulo) html)
                 "la pagina no tiene la tabla ~s" titulo))))

(definir-prueba varias-vistas-en-la-hoja-de-calculo
    "Varias vistas: la segunda vista sale como hoja derivada, agrupada por su campo"
  (let* ((plano (plano-de (biblioteca) (datos-de-biblioteca)))
         (derivada (find-if (lambda (h) (dato h "vista")) (hojas-del-plano plano))))
    (comprobar derivada "la vista por sala no tiene hoja")
    (when derivada
      (comprobar (equal (dato derivada "nombre") "Préstamos por sala")
                 "la hoja derivada tiene que llamarse como su vista: ~s"
                 (dato derivada "nombre"))
      ;; General (prestamo 1) primero, luego Infantil (prestamos 2 y 3).
      (comprobar (equal (mapcar (lambda (f) (dato f "indice"))
                                (lista-del-plano (dato (dato derivada "vista") "filas")))
                        '(0 1 2))
                 "las filas de la vista por sala no van agrupadas por sala"))))

(definir-prueba varias-vistas-el-informe-dice-la-verdad
    "Varias vistas: la hoja de calculo emula la vista derivada y degrada la de datos"
  (let* ((informe (nth-value 1 (materializar-en-cadena (situacion.excel:hacer-excel)
                                                       (biblioteca) (datos-de-biblioteca))))
         (entradas (remove 'protocolo:con-agrupacion-en-vista
                           (protocolo:entradas-del-informe informe)
                           :key #'protocolo:entrada-de-informe-capacidad :test-not #'eq)))
    (comprobar (equal (mapcar #'protocolo:entrada-de-informe-respuesta entradas)
                      '(:degrada :emula))
               "por lector se degrada (es la hoja de datos) y por sala se emula: ~s"
               (mapcar #'protocolo:entrada-de-informe-respuesta entradas))))
