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

;;; ---------------------------------------------------------------------
;;; Que ninguna de las dos ranuras quede en silencio
;;;
;;; La regla de conformidad numero 3: lo que una arquitectura no cumple sale
;;; en el informe como emulado, degradado o rechazado. Callar no puede
;;; significar "algo saldra". Hasta hoy, :SECCIONES y :AGRUPADA-POR se
;;; aceptaban, se validaban y no las materializaba nadie, y el informe no
;;; decia ni una palabra.
;;; ---------------------------------------------------------------------

(definir-prueba vista-partida-se-pide-como-capacidad
    "Vistas: partir y agrupar aparecen en los requerimientos"
  (let ((pedidas (mapcar #'first (protocolo:requerimientos
                                  (situacion-de-dos-grupos)))))
    (comprobar (member 'protocolo:con-particion-de-vista pedidas)
               "una vista con :SECCIONES tiene que pedir CON-PARTICION-DE-VISTA"))
  (let ((pedidas (mapcar #'first (protocolo:requerimientos
                                  (situacion.lenguaje:situacion-llamada
                                   "DEFENSAS-DE-TESIS")))))
    (comprobar (member 'protocolo:con-agrupacion-en-vista pedidas)
               "la vista DIA de las defensas declara :AGRUPADA-POR desde que se~@
                escribio y nunca pidio nada")))

(definir-prueba vista-partida-no-se-materializa-en-falso
    "Vistas: mientras la particion no este implementada, se rechaza y se dice"
  ;; :RECHAZA senala CAPACIDAD-NO-DISPONIBLE y aborta -carencia.lisp:83-89-, y
  ;; es lo correcto: una rejilla que ignora la particion no es una version mas
  ;; pobre de la que se pidio, es una tabla que mezcla filas de secciones
  ;; distintas y ademas solo dibuja una de cada cruce.
  ;;
  ;; La prueba se vacia sola conforme cada arquitectura pase a cumplirla, y en
  ;; ese momento se borra. Mientras tanto, protege de que alguien "arregle" el
  ;; rechazo convirtiendolo en una degradacion que no degrada nada.
  (dolist (par (arquitecturas-disponibles))
    (unless (protocolo:cumple-p (cdr par) 'protocolo:con-particion-de-vista)
      (comprobar (handler-case
                     (progn (materializar-en-cadena (cdr par)
                                                    (situacion-de-dos-grupos)
                                                    *dos-grupos*)
                            nil)
                   (protocolo:capacidad-no-disponible () t))
                 "~a materializo una vista partida sin implementar la particion"
                 (car par)))))

(definir-prueba vista-agrupada-sale-en-el-informe
    "Vistas: agrupar sin implementarlo sale como degradacion, no como silencio"
  ;; Al reves que la particion: ignorar la agrupacion produce una tabla
  ;; correcta -las mismas filas- y solo menos legible. Eso si es degradar, y
  ;; por eso las defensas se siguen materializando.
  (dolist (par (arquitecturas-disponibles))
    (multiple-value-bind (salida informe)
        (materializar-en-cadena (cdr par)
                                (situacion.lenguaje:situacion-llamada
                                 "DEFENSAS-DE-TESIS")
                                situacion.corpus:datos-de-las-defensas)
      (declare (ignore salida))
      (comprobar (find 'protocolo:con-agrupacion-en-vista
                       (protocolo:entradas-del-informe informe)
                       :key #'protocolo:entrada-de-informe-capacidad)
                 "~a no dice nada sobre la agrupacion que pide la vista DIA"
                 (car par)))))

;;; ---------------------------------------------------------------------
;;; Que la particion se materialice de verdad
;;; ---------------------------------------------------------------------

(definir-prueba vista-partida-sale-una-tabla-por-seccion
    "Vistas: una vista con :SECCIONES produce una tabla por valor del campo"
  ;; Dos grupos, una casilla cada uno, en el MISMO dia y turno. Sin particion
  ;; la rejilla tiene una sola celda, y esa celda dice "MAT" o "ESP" segun cual
  ;; fila llegara primero. Las dos respuestas son falsas: ninguno de los dos
  ;; grupos tiene las dos asignaturas.
  ;;
  ;; Se mira SOLO la parte de la rejilla, no el documento entero: mas abajo va
  ;; la tabla plana de CASILLAS, donde los cuatro textos aparecen siempre y la
  ;; comprobacion pasaria sin significar nada. Comprobar sobre el documento
  ;; completo seria un verde falso dentro de la propia prueba.
  (let* ((salida (materializar-en-cadena (situacion.texto:hacer-texto)
                                         (situacion-de-dos-grupos)
                                         *dos-grupos*))
         (fin (or (search "Casillas" salida) (length salida)))
         (rejilla (subseq salida 0 fin)))
    (comprobar (search "10-A" rejilla)
               "la rejilla deberia tener una tabla rotulada 10-A")
    (comprobar (search "10-B" rejilla)
               "la rejilla deberia tener una tabla rotulada 10-B")
    (comprobar (search "MAT" rejilla) "en la rejilla de 10-A")
    (comprobar (search "ESP" rejilla) "en la rejilla de 10-B")))
