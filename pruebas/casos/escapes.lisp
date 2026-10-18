;;;; Textos con signos que cada destino tiene que escapar.
;;;;
;;;; Un salto de linea dejaba la pagina en blanco (la cadena de JavaScript se
;;;; cortaba), una etiqueta con "<" se colaba en el HTML como una etiqueta de
;;;; verdad, y un dato que empezaba por "=" se escribia en la hoja de calculo
;;;; como formula. Las comillas, la barra invertida y "</script>" son las
;;;; otras formas conocidas de romper una cadena dentro de un programa.

(in-package #:situacion.casos)

(defsituacion caso-escapes (:etiqueta "Precios <IVA> & descuentos")
  (coleccion items
    (:etiqueta "Items")
    (:clave cod)
    (campo cod :rol fijo :etiqueta "Código")
    (campo desc :rol fijo :etiqueta "Descripción")
    (campo nota :rol derivado :etiqueta "Nota" (texto "«" (de fila desc) "»")))
  (vista v :de items :etiqueta "Items"))

(defparameter datos-de-escapes
  (datos (list "items"
               (fila "cod" "A" "desc" (format nil "Dos~%líneas"))
               (fila "cod" "B" "desc" "barra \\ invertida y </script> dentro")
               (fila "cod" "C" "desc" "=1+1")
               (fila "cod" "D" "desc" "con \"comillas\" dobles")
               (fila "cod" "E" "desc" "+34 555")
               (fila "cod" "F" "desc" "-3 grados")
               (fila "cod" "G" "desc" "@usuario"))))

(registrar-caso "caso-escapes" caso-escapes datos-de-escapes)
