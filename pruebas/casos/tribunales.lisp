;;;; C7. Tribunales con marca por campo.
;;;; Ejercita: una marca :por-campo (fase 2, hueco C7) que pinta solo el
;;;; miembro del tribunal que esta en dos locales a la vez. A las 09:00 no
;;;; choca nadie; a las 10:00 choca uno (P1); a las 11:00 chocan dos (P1 y
;;;; P2, en puestos distintos de cada tribunal). Una marca normal, sin
;;;; estudiante, comprueba que las marcas de siempre se siguen pintando bien.
(in-package #:situacion.casos)

(defsituacion caso-tribunales (:etiqueta "Tribunales")
  (coleccion citaciones
    (:etiqueta "Citaciones")
    (:clave momento local)
    (campo momento    :rol fijo :tipo hora :etiqueta "Hora")
    (campo local      :rol fijo :etiqueta "Local")
    (campo estudiante :rol entrada :etiqueta "Estudiante")
    (campo tutor      :rol fijo :etiqueta "Tutor")
    (campo oponente   :rol fijo :etiqueta "Oponente")
    (campo presidente :rol fijo :etiqueta "Presidente"))

  (marca en-dos-locales
    :en citaciones
    :sobre     (tutor oponente presidente)
    :por-campo profesor
    :cuando (y (no (vacio? profesor))
               (existe otra :en citaciones
                 :distinta-de fila
                 :donde (y (= (de otra momento) (de fila momento))
                           (o (= (de otra tutor) profesor)
                              (= (de otra oponente) profesor)
                              (= (de otra presidente) profesor)))))
    :severidad problema
    :explica   (texto profesor " está en dos locales a la vez"))

  (marca sin-estudiante
    :en citaciones
    :cuando    (vacio? (de fila estudiante))
    :sobre     (estudiante)
    :severidad informativa
    :explica   "Hueco sin defensa")

  (vista dia :de citaciones :entrada t :etiqueta "Citaciones"))

(defparameter datos-de-tribunales
  (datos (list "citaciones"
               (fila "momento" "09:00" "local" "A" "estudiante" "Ana"
                     "tutor" "P1" "oponente" "P2" "presidente" "P3")
               (fila "momento" "09:00" "local" "B" "estudiante" "Beto"
                     "tutor" "P4" "oponente" "P5" "presidente" "P6")
               (fila "momento" "10:00" "local" "A" "estudiante" "Caro"
                     "tutor" "P1" "oponente" "P2" "presidente" "P3")
               (fila "momento" "10:00" "local" "B" "estudiante" "Dani"
                     "tutor" "P1" "oponente" "P7" "presidente" "P8")
               (fila "momento" "11:00" "local" "A" "estudiante" "Eva"
                     "tutor" "P1" "oponente" "P2" "presidente" "P9")
               (fila "momento" "11:00" "local" "B" "estudiante" ""
                     "tutor" "P2" "oponente" "P1" "presidente" "P10"))))

(registrar-caso "caso-tribunales" caso-tribunales datos-de-tribunales)
