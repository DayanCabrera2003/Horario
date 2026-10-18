;;;; C1. Cuadrante de guardias por sala, con el dominio de los ejes declarado.
;;;; Ejercita: ejes y secciones con :dominio (fase 2, hueco C1). Los datos
;;;; empiezan por un miercoles, para que el orden de aparicion no coincida con
;;;; el declarado; nadie hace guardia en el turno 4 ni en la sala Este, que
;;;; tienen que salir igual; y una guardia cae en sabado, fuera del dominio de
;;;; los dias, que tiene que verse y avisarse, nunca esconderse.
(in-package #:situacion.casos)

(defsituacion caso-guardias (:etiqueta "Guardias por sala")
  (coleccion salas
    (:etiqueta "Salas")
    (:clave nombre)
    (campo nombre :rol fijo :etiqueta "Sala"))

  (coleccion guardias
    (:etiqueta "Guardias")
    (:clave sala dia turno)
    (campo sala    :rol fijo :etiqueta "Sala")
    (campo dia     :rol fijo :etiqueta "Día")
    (campo turno   :rol fijo :tipo entero :etiqueta "Turno")
    (campo persona :rol entrada :etiqueta "Quién"))

  (marca sin-cubrir
    :en guardias
    :cuando (vacio? (de fila persona))
    :sobre (persona)
    :severidad informativa
    :explica "Guardia sin cubrir")

  ;; Las salas van en el orden de su coleccion (Norte, Sur, Este), no en el
  ;; alfabetico; los dias en el de la semana; los turnos del 1 al 4.
  (vista cuadrante :de guardias :entrada t :etiqueta "Cuadrante"
                   :filas     (turno :dominio (uno-de 1 2 3 4))
                   :columnas  (dia :dominio (uno-de "L" "M" "MI" "J" "V"))
                   :muestra persona
                   :secciones (sala :dominio (los nombre de salas)))
  (vista lista :de guardias :etiqueta "Todas las guardias"))

(defparameter datos-de-guardias
  (datos (list "salas"
               (fila "nombre" "Norte")
               (fila "nombre" "Sur")
               (fila "nombre" "Este"))
         (list "guardias"
               (fila "sala" "Sur"   "dia" "MI" "turno" 2 "persona" "Ana")
               (fila "sala" "Norte" "dia" "L"  "turno" 1 "persona" "Beto")
               (fila "sala" "Norte" "dia" "V"  "turno" 3 "persona" "")
               (fila "sala" "Sur"   "dia" "S"  "turno" 1 "persona" "Carla"))))

(registrar-caso "caso-guardias" caso-guardias datos-de-guardias)
