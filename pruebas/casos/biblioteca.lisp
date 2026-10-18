;;;; Dos vistas de lista sobre la misma coleccion, agrupadas distinto.
;;;;
;;;; Las tres arquitecturas dibujaban una sola tabla, con la agrupacion de la
;;;; primera vista, y el informe de conformidad decia que las dos se
;;;; cumplian.

(in-package #:situacion.casos)

(defsituacion caso-biblioteca (:etiqueta "Préstamos de la biblioteca")
  (coleccion prestamos
    (:etiqueta "Préstamos")
    (:clave numero)
    (campo numero :rol fijo :tipo entero :etiqueta "No.")
    (campo lector :rol fijo :etiqueta "Lector")
    (campo sala   :rol fijo :etiqueta "Sala")
    (campo libro  :rol fijo :etiqueta "Libro"))
  (vista por-lector :de prestamos :etiqueta "Préstamos por lector" :agrupada-por lector)
  (vista por-sala   :de prestamos :etiqueta "Préstamos por sala"   :agrupada-por sala))

(defparameter datos-de-biblioteca
  (datos (list "prestamos"
               (fila "numero" 1 "lector" "Ana" "sala" "General" "libro" "Cien años de soledad")
               (fila "numero" 2 "lector" "Luis" "sala" "Infantil" "libro" "El principito")
               (fila "numero" 3 "lector" "Ana" "sala" "Infantil" "libro" "Matilda"))))

(registrar-caso "caso-biblioteca" caso-biblioteca datos-de-biblioteca)
