;;;; La planificacion de las defensas de tesis.
;;;;
;;;; Es la hoja de un dia del generador de tribunales: tribunales/hoja_dia.py.
;;;; Se elige porque tiene a la vez las tres cosas interesantes del corpus, y
;;;; ninguna tesis anterior puede describir las tres:
;;;;
;;;;   1. Autocompletado por busqueda de clave. Se escribe el estudiante y el
;;;;      tribunal entero aparece solo. Es el VLOOKUP de la linea 42 del
;;;;      generador. LDMAG (2025) lo llamo "consulta" pero no tenia tablas;
;;;;      el DSL de 2026 tenia tablas pero no busqueda.
;;;;
;;;;   2. Entrada validada que avisa sin bloquear. El desplegable del corpus
;;;;      se genera con aviso no bloqueante, y eso es una decision del
;;;;      dominio: hay restricciones que invalidan y restricciones que solo
;;;;      advierten.
;;;;
;;;;   3. Deteccion de colision por cuantificacion. Un profesor citado en dos
;;;;      locales a la misma hora. Es el cuantificador existencial de 2026,
;;;;      con la diferencia de que aqui la condicion es una expresion
;;;;      cualquiera en vez de dos listas de columnas.
;;;;
;;;; LEASE EN VOZ ALTA. Si hay que explicarla, el vocabulario esta mal.

(in-package #:situacion.corpus)

(defsituacion defensas-de-tesis (:etiqueta "Defensas de tesis")

  ;; Lo que ya se sabe y no se toca: cada tesis con su tribunal.
  (coleccion tesis
    (:etiqueta "Tesis")
    (:clave estudiante)
    (campo estudiante :rol fijo :etiqueta "Estudiante")
    (campo tutor      :rol fijo :etiqueta "Tutor")
    (campo oponente   :rol fijo :etiqueta "Oponente")
    (campo presidente :rol fijo :etiqueta "Presidente")
    (campo secretario :rol fijo :etiqueta "Secretario")
    (:datos (("Juan Perez"      "P. Alonso"  "M. Ramirez" "L. Gomez"   "A. Suarez")
             ("Laura Fernandez" "R. Torres"  "L. Gomez"   "P. Alonso"  "A. Suarez")
             ("Mario Gomez"     "M. Ramirez" "R. Torres"  "P. Alonso"  "L. Gomez")
             ("Ana Valdes"      "A. Suarez"  "P. Alonso"  "R. Torres"  "M. Ramirez"))))

  ;; Lo que se planifica a mano.
  (coleccion citaciones
    (:etiqueta "Citaciones")
    (:clave dia momento local)
    (:orden momento)
    (:crece)
    (campo dia     :rol fijo :etiqueta "Dia")
    (campo momento :rol fijo :etiqueta "Momento")
    (campo local   :rol fijo :etiqueta "Local")

    ;; Lo unico que se escribe a mano. Avisa si el estudiante no existe, pero
    ;; no bloquea: asi se puede anotar un caso antes de darlo de alta.
    (campo estudiante :rol entrada
           :etiqueta  "Estudiante"
           :dominio   (los estudiante de tesis)
           :al-violar advertir)

    ;; El tribunal no se escribe: se trae solo de la tesis del estudiante.
    (campo tutor :rol derivado :etiqueta "Tutor"
           (el tutor de (la-fila-de tesis
                          :donde (= estudiante (de fila estudiante)))
               :si-no ""))
    (campo oponente :rol derivado :etiqueta "Oponente"
           (el oponente de (la-fila-de tesis
                             :donde (= estudiante (de fila estudiante)))
               :si-no ""))
    (campo presidente :rol derivado :etiqueta "Presidente"
           (el presidente de (la-fila-de tesis
                               :donde (= estudiante (de fila estudiante)))
               :si-no ""))
    (campo secretario :rol derivado :etiqueta "Secretario"
           (el secretario de (la-fila-de tesis
                               :donde (= estudiante (de fila estudiante)))
               :si-no ""))

    (:datos (("lunes" "09:00" "Postgrado")
             ("lunes" "09:00" "Decanato")
             ("lunes" "10:00" "Postgrado")
             ("lunes" "10:00" "Decanato"))))

  ;; La razon de ser del documento: avisar de que un profesor esta citado en
  ;; dos sitios a la vez.
  (marca profesor-citado-dos-veces
    :en citaciones
    :cuando (existe otra :en citaciones
              :distinta-de fila
              :donde (y (= (de otra dia) (de fila dia))
                        (= (de otra momento) (de fila momento))
                        (comparten otra fila
                                   (tutor oponente presidente secretario))))
    :sobre     (tutor oponente presidente secretario)
    :severidad problema
    :explica   "Este profesor esta citado en dos locales a la vez")

  (marca sin-asignar
    :en citaciones
    :cuando    (vacio? (de fila estudiante))
    :sobre     (estudiante)
    :severidad informativa
    :explica   "Este hueco todavia no tiene defensa")

  (vista dia :de citaciones :entrada t :etiqueta "Citaciones del dia"
             :agrupada-por local)
  (vista tribunal :de tesis :etiqueta "Tesis y sus tribunales"))

(defparameter datos-de-las-defensas
  (let ((n (lambda (s) (nucleo:nombrar s))))
    (list
     (cons (funcall n "tesis")
           (loop for (est tut opo pre sec)
                   in '(("Juan Perez"      "P. Alonso"  "M. Ramirez" "L. Gomez"  "A. Suarez")
                        ("Laura Fernandez" "R. Torres"  "L. Gomez"   "P. Alonso" "A. Suarez")
                        ("Mario Gomez"     "M. Ramirez" "R. Torres"  "P. Alonso" "L. Gomez")
                        ("Ana Valdes"      "A. Suarez"  "P. Alonso"  "R. Torres" "M. Ramirez"))
                 collect (list (cons (funcall n "estudiante") est)
                               (cons (funcall n "tutor") tut)
                               (cons (funcall n "oponente") opo)
                               (cons (funcall n "presidente") pre)
                               (cons (funcall n "secretario") sec))))
     ;; Las dos primeras citaciones colisionan a proposito: Juan Perez y
     ;; Laura Fernandez comparten a A. Suarez como secretario, y estan las dos
     ;; el lunes a las nueve en locales distintos.
     (cons (funcall n "citaciones")
           (loop for (dia momento local estudiante)
                   in '(("lunes" "09:00" "Postgrado" "Juan Perez")
                        ("lunes" "09:00" "Decanato"  "Laura Fernandez")
                        ("lunes" "10:00" "Postgrado" "Mario Gomez")
                        ("lunes" "10:00" "Decanato"  ""))
                 collect (list (cons (funcall n "dia") dia)
                               (cons (funcall n "momento") momento)
                               (cons (funcall n "local") local)
                               (cons (funcall n "estudiante") estudiante))))))
  "Cuatro huecos del lunes, con una colision de secretario a las nueve y un
   hueco todavia sin asignar a las diez.")
