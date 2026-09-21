;;;; Pruebas de las vistas.
;;;;
;;;; Una vista dice COMO se presenta lo que hay. Este archivo comprueba las
;;;; cosas que puede decir -partir en secciones, agrupar filas y filtrar- y,
;;;; sobre todo, que ninguna de ellas pueda declararse y quedar en nada sin
;;;; que el informe de conformidad lo diga.
;;;;
;;;; La primera prueba es la que motivo el resto. Una rejilla de turno por dia
;;;; sobre una coleccion con DOS grupos dibujaba la clase del primero que
;;;; apareciera, en silencio: los dos ejes no determinan la fila, porque la
;;;; clave es (grupo dia turno) y grupo no esta en ninguno de los dos. Es el
;;;; mismo genero de fallo que los tres que encontro el experimento de
;;;; alcance -una descripcion que se lee como correcta y significa otra cosa-
;;;; y por eso el arreglo no es materializar mejor: es no aceptarla.

(in-package #:situacion.pruebas)

;;; La misma coleccion descrita dos veces: una sin decir por que campo se
;;; parte -que es la descripcion ambigua- y otra diciendolo. Se repiten
;;; enteras a proposito: una prueba que comparte fixture con otra deja de
;;; decir cual de las dos cambio cuando falla.

(situacion.lenguaje:defsituacion rejilla-ambigua (:etiqueta "Rejilla ambigua")
  (coleccion casillas
    (:clave grupo dia turno)
    (campo grupo      :rol fijo)
    (campo dia        :rol fijo)
    (campo turno      :rol fijo)
    (campo asignatura :rol entrada :dominio (uno-de "MAT" "ESP")
                      :al-violar advertir))
  (vista rejilla :de casillas :entrada t :etiqueta "Horario"
                 :filas turno :columnas dia :muestra asignatura))

(situacion.lenguaje:defsituacion dos-grupos (:etiqueta "Dos grupos")
  (coleccion casillas
    (:clave grupo dia turno)
    (campo grupo      :rol fijo)
    (campo dia        :rol fijo)
    (campo turno      :rol fijo)
    (campo asignatura :rol entrada :dominio (uno-de "MAT" "ESP")
                      :al-violar advertir))
  (vista rejilla :de casillas :entrada t :etiqueta "Horario"
                 :filas turno :columnas dia :muestra asignatura
                 :secciones grupo))

(defparameter *dos-grupos*
  (list (cons (nucleo:nombrar "casillas")
              (loop for (g d tu a) in '(("10-A" "lunes" "T1" "MAT")
                                        ("10-B" "lunes" "T1" "ESP"))
                    collect (list (cons (nucleo:nombrar "grupo") g)
                                  (cons (nucleo:nombrar "dia") d)
                                  (cons (nucleo:nombrar "turno") tu)
                                  (cons (nucleo:nombrar "asignatura") a))))))

(defun situacion-de-dos-grupos ()
  (situacion.lenguaje:situacion-llamada "DOS-GRUPOS"))

(defun errores-de (situacion)
  "Los problemas de gravedad :ERROR que el analisis encuentra en SITUACION."
  (remove-if-not (lambda (p) (eq (analisis:gravedad-de-problema p) :error))
                 (analisis:comprobar-situacion situacion)))

(definir-prueba vista-cruzada-ambigua-se-rechaza
    "Vistas: una rejilla cuyos ejes no determinan la fila no se acepta"
  ;; La clave de CASILLAS es (grupo dia turno) y los ejes son (turno dia):
  ;; dos filas distintas caen en la misma casilla y solo se dibujaria una, la
  ;; primera que apareciera. Eso depende del orden en que esten escritos los
  ;; datos y no de lo que dice la descripcion, que es exactamente lo que el
  ;; analisis existe para impedir.
  ;;
  ;; Se sabe sin mirar los datos y sin saber a donde se genera, asi que es del
  ;; analisis y no de ninguna arquitectura. Decir :SECCIONES GRUPO es lo que
  ;; completa la clave.
  (comprobar (errores-de (situacion.lenguaje:situacion-llamada "REJILLA-AMBIGUA"))
             "una rejilla ambigua tiene que dar error")
  (comprobar (null (errores-de (situacion-de-dos-grupos)))
             "la misma rejilla con :SECCIONES GRUPO si es legal"))

;;; La prueba de que la particion se materializa de verdad entra en la
;;; tarea 4, cuando hay una arquitectura que la cumple. Aqui solo se rechaza
;;; lo ambiguo.
