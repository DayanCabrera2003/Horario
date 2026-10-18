;;;; G5. Registro de horas trabajadas.
;;;; Ejercita: coleccion derivada (:una-fila-por), tabla cruzada con un eje
;;;; numerico, orden compuesto y saldo acumulado de cada persona con
;;;; (anterior fila :mismo persona) (fase 2, hueco C3), una coleccion :crece
;;;; que llega vacia, y cuantas-distintas. La sonda de orden le anade a Ana la
;;;; semana 3, que tiene que quedar entre su semana 2 y la 1 de Zoe.
(in-package #:situacion.casos)

(defsituacion caso-horas (:etiqueta "Horas trabajadas")
  (parametro tope :tipo numero :valor 40 :etiqueta "Tope semanal")

  (coleccion registros
    (:etiqueta "Registros")
    (:clave persona semana)
    (:orden persona semana)
    (:crece)
    (campo persona :rol fijo :etiqueta "Persona")
    (campo semana  :rol fijo :tipo entero :etiqueta "Semana")
    (campo horas   :rol entrada :tipo entero :etiqueta "Horas")
    ;; Hasta el 2026-10-17 solo se podia acumular todas las filas seguidas,
    ;; mezclando personas, y la etiqueta decia "(todas)".
    (campo acumulado :rol derivado :tipo entero :etiqueta "Acumulado de la persona"
           (+ (de fila horas) (de (anterior fila :mismo persona) acumulado))))

  (coleccion personas
    (:una-fila-por persona :de registros)
    (:etiqueta "Personas")
    (campo persona :rol fijo :etiqueta "Persona")
    (campo total :rol derivado :tipo entero :etiqueta "Total"
           (suma horas de registros :donde (= persona (de fila persona))))
    (campo semanas :rol derivado :tipo entero :etiqueta "Semanas"
           (cuantas registros :donde (= persona (de fila persona)))))

  (coleccion incidencias
    (:etiqueta "Incidencias")
    (:clave numero)
    (:crece)
    (campo numero :rol fijo :tipo entero :etiqueta "No.")
    (campo persona :rol entrada :etiqueta "Persona")
    (campo nota :rol entrada :etiqueta "Nota"))

  (coleccion resumen
    (:una-sola-fila)
    (:etiqueta "Resumen")
    (campo gente :rol derivado :tipo entero :etiqueta "Personas distintas"
           (cuantas-distintas persona de registros))
    (campo incid :rol derivado :tipo entero :etiqueta "Incidencias"
           (cuantas incidencias)))

  (marca exceso
    :en registros
    :cuando (> (de fila horas) (parametro tope))
    :sobre (horas)
    :severidad problema
    :explica (texto "Pasa del tope por " (- (de fila horas) (parametro tope)) " h"))

  (vista rejilla :de registros :entrada t :etiqueta "Horas por semana"
                 :filas persona :columnas semana :muestra horas)
  (vista gente :de personas :etiqueta "Por persona")
  (vista inc :de incidencias :etiqueta "Incidencias")
  (vista res :de resumen :etiqueta "Resumen"))

(defparameter datos-de-horas
  (datos (list "registros"
               (fila "persona" "Zoe" "semana" 10 "horas" 38)
               (fila "persona" "Ana" "semana" 2 "horas" 45)
               (fila "persona" "Zoe" "semana" 2 "horas" 40)
               (fila "persona" "Ana" "semana" 1 "horas" 36)
               (fila "persona" "Zoe" "semana" 1 "horas" 30))
         (list "incidencias")
         (list "resumen" (fila))))

(registrar-caso "caso-horas" caso-horas datos-de-horas
                :fila-nueva (cons "registros" (fila "persona" "Ana" "semana" 3 "horas" 10)))
