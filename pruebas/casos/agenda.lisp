;;;; G3. Agenda de reuniones por sala y hora (tabla cruzada).
;;;; Ejercita: tabla cruzada con secciones, vista cruzada filtrada (:donde),
;;;; :unica-salvo con su marca, horas HH:MM fuera de orden en los datos,
;;;; comparacion de horas, valores que solo difieren en mayusculas y un valor
;;;; con "*" en un eje.
(in-package #:situacion.casos)

(defsituacion caso-agenda (:etiqueta "Agenda de salas")
  (coleccion reuniones
    (:etiqueta "Reuniones")
    (:clave dia hora sala)
    (:orden hora)
    (:crece)
    (campo dia     :rol fijo :etiqueta "Día")
    (campo hora    :rol fijo :tipo hora :etiqueta "Hora")
    (campo sala    :rol fijo :etiqueta "Sala")
    (campo asunto  :rol entrada :etiqueta "Asunto")
    (campo jefe    :rol entrada :etiqueta "Convoca")
    (campo temprano :rol derivado :etiqueta "Antes de las 9:30"
           (si (< (de fila hora) "09:30") "sí" "no")))

  (marca jefe-en-dos-salas
    :en reuniones
    :cuando (y (no (vacio? (de fila jefe)))
               (existe otra :en reuniones :distinta-de fila
                 :donde (y (= (de otra dia) (de fila dia))
                           (= (de otra hora) (de fila hora))
                           (= (de otra jefe) (de fila jefe)))))
    :sobre (jefe)
    :severidad problema
    :explica "Convoca dos reuniones a la vez")

  (marca libre
    :en reuniones
    :cuando (vacio? (de fila asunto))
    :sobre (asunto)
    :severidad informativa
    :explica "Sala libre")

  ;; Rejilla: hora por sala, una por dia.
  (vista por-sala :de reuniones :entrada t :etiqueta "Ocupación"
                  :filas hora :columnas sala :muestra asunto
                  :secciones dia)
  ;; Rejilla por jefe: hora por dia, filtrada a las reuniones con asunto.
  (vista por-jefe :de reuniones :etiqueta "Agenda de quien convoca"
                  :filas hora :columnas dia :muestra sala
                  :secciones jefe
                  :donde (no (vacio? (de fila asunto)))
                  :unica-salvo jefe-en-dos-salas)
  (vista lista :de reuniones :etiqueta "Todas las reuniones"))

(defparameter datos-de-agenda
  (datos (list "reuniones"
               (fila "dia" "lunes" "hora" "10:00" "sala" "Sala Azul" "asunto" "Presupuesto" "jefe" "Marta")
               (fila "dia" "lunes" "hora" "09:00" "sala" "Sala Azul" "asunto" "Inicio de semana" "jefe" "Raúl")
               (fila "dia" "lunes" "hora" "09:30" "sala" "sala azul" "asunto" "Entrevista" "jefe" "Raúl")
               (fila "dia" "lunes" "hora" "09:00" "sala" "Sala*" "asunto" "Café" "jefe" "Marta")
               (fila "dia" "lunes" "hora" "09:00" "sala" "Sala Verde" "asunto" "" "jefe" "")
               (fila "dia" "martes" "hora" "11:00" "sala" "Sala Verde" "asunto" "Retro" "jefe" "Raúl")
               (fila "dia" "martes" "hora" "08:30" "sala" "Sala Azul" "asunto" "Seguridad" "jefe" "Marta")
               (fila "dia" "martes" "hora" "11:00" "sala" "Sala Azul" "asunto" "Clientes" "jefe" "Raúl"))))

(registrar-caso "caso-agenda" caso-agenda datos-de-agenda)
