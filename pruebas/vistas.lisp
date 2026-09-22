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

(definir-prueba vista-partida-tiene-respuesta-en-las-tres
    "Vistas: las tres arquitecturas dicen que hacen con la particion"
  ;; Aqui hubo una prueba que exigia que las tres RECHAZARAN, porque ninguna
  ;; la implementaba todavia. Ya no: texto y la pagina la cumplen y la hoja de
  ;; calculo la emula fijando las pestanas al generar. Lo que se conserva es
  ;; lo unico que no depende de quien la implemente: que ninguna se la calle.
  (dolist (par (arquitecturas-disponibles))
    (multiple-value-bind (salida informe)
        (materializar-en-cadena (cdr par) (situacion-de-dos-grupos) *dos-grupos*)
      (declare (ignore salida))
      (let ((entrada (find 'protocolo:con-particion-de-vista
                           (protocolo:entradas-del-informe informe)
                           :key #'protocolo:entrada-de-informe-capacidad)))
        (comprobar entrada "~a no dice nada sobre la particion" (car par))
        (when entrada
          (comprobar (member (protocolo:entrada-de-informe-respuesta entrada)
                             '(:cumple :emula))
                     "~a deberia cumplirla o emularla, y responde ~(~a~)"
                     (car par)
                     (protocolo:entrada-de-informe-respuesta entrada)))))))

(definir-prueba vista-agrupada-sale-en-el-informe
    "Vistas: las tres arquitecturas dicen que hacen con la agrupacion"
  ;; Texto y la pagina la cumplen; la hoja de calculo degrada, porque alli la
  ;; posicion de la fila es el dato. Lo que esta prueba vigila no es cual de
  ;; las tres respuestas da cada una, sino que ninguna se la calle: la vista
  ;; DIA de las defensas la declaro desde el primer dia y el informe no decia
  ;; ni una palabra.
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
;;; La casilla en conflicto
;;;
;;; El horario por profesor es una rejilla de turno por dia partida por
;;; profesor, sobre una coleccion cuya clave es (grupo dia turno). Los ejes
;;; mas la particion dejan GRUPO fuera, asi que dos filas pueden caer en la
;;; misma casilla. Y eso, en el dominio, tiene nombre: el profesor esta
;;; citado en dos grupos a la vez.
;;;
;;; La vista esta bien definida SOLO SI el horario es valido, y el analisis
;;; no mira los datos. La salida no es afinar la comprobacion: es que la
;;; descripcion diga que marca garantiza la casilla, y que se vea el
;;; conflicto cuando la garantia falle.
;;; ---------------------------------------------------------------------

(situacion.lenguaje:defsituacion agenda-del-profesor (:etiqueta "Agenda")
  (coleccion casillas
    (:clave grupo dia turno)
    (campo grupo    :rol fijo)
    (campo dia      :rol fijo)
    (campo turno    :rol fijo)
    (campo profesor :rol fijo))
  (marca profesor-colisiona
    :en casillas
    :cuando (existe otra :en casillas
              :distinta-de fila
              :donde (y (= (de otra dia) (de fila dia))
                        (= (de otra turno) (de fila turno))
                        (= (de otra profesor) (de fila profesor))))
    :sobre     (profesor)
    :severidad problema
    :explica   "Este profesor da clase a otro grupo en este mismo turno")
  (vista agenda :de casillas :entrada t :etiqueta "Agenda"
                :filas turno :columnas dia :muestra grupo
                :secciones profesor
                :unica-salvo profesor-colisiona))

(defparameter *dos-grupos-un-profesor*
  (list (cons (nucleo:nombrar "casillas")
              (loop for (g d tu p) in '(("10-A" "lunes" "T1" "Rosa")
                                        ("10-B" "lunes" "T1" "Rosa"))
                    collect (list (cons (nucleo:nombrar "grupo") g)
                                  (cons (nucleo:nombrar "dia") d)
                                  (cons (nucleo:nombrar "turno") tu)
                                  (cons (nucleo:nombrar "profesor") p))))))

(definir-prueba vista-con-guarda-se-acepta
    "Vistas: una rejilla ambigua se acepta si dice que marca la garantiza"
  (comprobar (null (errores-de (situacion.lenguaje:situacion-llamada
                                "AGENDA-DEL-PROFESOR")))
             "declarar :UNICA-SALVO deberia hacer legal la vista"))

(definir-prueba casilla-en-conflicto-se-ve
    "Vistas: cuando dos filas caen en una casilla, se ven las dos"
  ;; Lo contrario de lo que hace hoy cualquiera de las tres: elegir la
  ;; primera que aparezca y no decir nada. Rosa da clase a 10-A y a 10-B el
  ;; lunes a primera hora: su agenda tiene que ensenar el choque, no uno de
  ;; los dos grupos.
  (let* ((salida (materializar-en-cadena
                  (situacion.texto:hacer-texto)
                  (situacion.lenguaje:situacion-llamada "AGENDA-DEL-PROFESOR")
                  *dos-grupos-un-profesor*))
         (fin (or (search "Casillas" salida) (length salida)))
         (rejilla (subseq salida 0 fin)))
    (comprobar (search "10-A" rejilla) "la casilla tiene que nombrar 10-A")
    (comprobar (search "10-B" rejilla) "y tambien 10-B, que es el conflicto")))

;;; ---------------------------------------------------------------------
;;; El filtro
;;;
;;; Lo que pidio el tutor: ver la ocupacion DE LOS PROFESORES QUE LE DAN
;;; CLASE A ESE GRUPO, no la de los ciento y pico del centro. Partir da una
;;; tabla por profesor; filtrar dice cuales.
;;; ---------------------------------------------------------------------

(situacion.lenguaje:defsituacion un-grupo-de-dos (:etiqueta "Filtrada")
  (coleccion casillas
    (:clave grupo dia turno)
    (campo grupo      :rol fijo)
    (campo dia        :rol fijo)
    (campo turno      :rol fijo)
    (campo asignatura :rol entrada :dominio (uno-de "MAT" "ESP")
                      :al-violar advertir)
    ;; Cuenta sobre la coleccion ENTERA. Si el filtro de la vista tocara los
    ;; datos, este numero cambiaria, y no debe.
    (campo cuantas-hay :rol derivado :tipo entero
           (cuantas casillas)))
  (vista rejilla :de casillas :entrada t :etiqueta "Horario"
                 :filas turno :columnas dia :muestra asignatura
                 :secciones grupo
                 :donde (= (de fila grupo) "10-A")))

(definir-prueba vista-filtrada-deja-fuera-lo-que-no-cumple
    "Vistas: :DONDE presenta solo las filas que lo cumplen"
  (let* ((salida (materializar-en-cadena
                  (situacion.texto:hacer-texto)
                  (situacion.lenguaje:situacion-llamada "UN-GRUPO-DE-DOS")
                  *dos-grupos*))
         (fin (or (search "Casillas" salida) (length salida)))
         (rejilla (subseq salida 0 fin)))
    (comprobar (search "10-A" rejilla) "la seccion de 10-A tiene que estar")
    (comprobar (not (search "10-B" rejilla))
               "10-B no cumple el filtro y no deberia tener tabla")))

(definir-prueba vista-filtrada-no-cambia-los-datos
    "Vistas: el filtro es de la presentacion, no de la situacion"
  ;; Si filtrar tocara los datos, CUANTAS-HAY valdria 1 en vez de 2 y las
  ;; marcas dejarian de ver las filas escondidas. Un detector de colisiones
  ;; que solo mira lo que se dibuja no detecta nada: el horario de Rosa no
  ;; ensena las clases de Julia, y aun asi tiene que saber que chocan.
  (let* ((s (situacion.lenguaje:situacion-llamada "UN-GRUPO-DE-DOS"))
         (e (nucleo:hacer-entorno s *dos-grupos*))
         (fila (first (nucleo:filas-de e (nucleo:nombrar "casillas")))))
    (comprobar (= 2 (nucleo:valor-de-campo e fila (nucleo:nombrar "cuantas-hay")))
               "el filtro de la vista no puede cambiar lo que cuenta un agregado")))

(definir-prueba vista-agrupada-separa-las-filas
    "Vistas: :AGRUPADA-POR separa las filas por el valor del campo"
  ;; La vista DIA de las defensas declara :AGRUPADA-POR LOCAL desde que se
  ;; escribio la descripcion, y hasta hoy no agrupaba nada: las cuatro
  ;; citaciones salian en orden de declaracion -Postgrado, Decanato,
  ;; Postgrado, Decanato-, que es justo lo contrario de agrupar.
  (let* ((salida (materializar-en-cadena (situacion.texto:hacer-texto)
                                         (situacion.lenguaje:situacion-llamada
                                          "DEFENSAS-DE-TESIS")
                                         situacion.corpus:datos-de-las-defensas))
         (primera (search "Postgrado" salida))
         (ultima (search "Postgrado" salida :from-end t))
         (decanato (search "Decanato" salida)))
    (comprobar (and primera ultima decanato)
               "la salida deberia nombrar los dos locales")
    ;; Agrupadas, las de Postgrado estan juntas: o todas antes de cualquier
    ;; Decanato, o todas despues.
    (when (and primera ultima decanato)
      (comprobar (or (< ultima decanato) (> primera decanato))
                 "las citaciones de Postgrado salen partidas por las de~@
                  Decanato: la vista declara :AGRUPADA-POR LOCAL y no agrupa"))))

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

(definir-prueba vista-partida-llega-a-la-pagina
    "Vistas: la pagina recibe el campo por el que se parte la vista"
  ;; LO QUE ESTA PRUEBA NO HACE: comprobar que la pagina DIBUJE dos tablas.
  ;; El verificador de la web ejecuta el JavaScript emitido pero corta antes
  ;; del dibujo -materializador/verificar-web.js- porque eso necesitaria un
  ;; DOM, y el proyecto prefiere decir que no lo verifica a darlo por bueno.
  ;;
  ;; Lo que si comprueba es que el dato llegue: si alguien deja de emitir el
  ;; campo de particion, la pagina dibujaria una sola tabla y el informe
  ;; seguiria diciendo "cumple". Eso es lo que aqui se impide.
  (let ((salida (materializar-en-cadena (situacion.web:hacer-web)
                                        (situacion-de-dos-grupos)
                                        *dos-grupos*)))
    (comprobar (search "secciones: \"grupo\"" salida)
               "la pagina no recibe el campo de particion")))

;;; ---------------------------------------------------------------------
;;; Dos vistas particionadas no pueden pisarse en el informe
;;; ---------------------------------------------------------------------

(situacion.lenguaje:defsituacion dos-particiones (:etiqueta "Dos particiones")
  (coleccion casillas
    (:clave grupo dia turno)
    (campo grupo      :rol fijo)
    (campo dia        :rol fijo)
    (campo turno      :rol fijo)
    (campo asignatura :rol entrada :dominio (uno-de "MAT" "ESP")
                      :al-violar advertir))
  (vista por-grupo :de casillas :entrada t :etiqueta "Por grupo"
                   :filas turno :columnas dia :muestra asignatura
                   :secciones grupo)
  (vista por-dia   :de casillas :etiqueta "Por dia"
                   :filas turno :columnas grupo :muestra asignatura
                   :secciones dia))

(definir-prueba requerimientos-no-deduplica-por-capacidad-sola
    "Requerimientos: dos vistas que piden la misma capacidad dejan dos hallazgos"
  (let* ((situacion (situacion.lenguaje:situacion-llamada "DOS-PARTICIONES"))
         (pedidos (remove 'protocolo:con-particion-de-vista
                          (protocolo:requerimientos situacion)
                          :key #'first :test-not #'eq)))
    (comprobar (= (length pedidos) 2)
               "dos vistas con :SECCIONES tienen que dejar DOS hallazgos de~@
                CON-PARTICION-DE-VISTA, uno por vista; hoy la segunda se~@
                descarta en silencio (encontrados: ~d)" (length pedidos))
    (comprobar (= (length (remove-duplicates (mapcar #'second pedidos)))
                  2)
               "los dos hallazgos tienen que apuntar a nodos (vistas)~@
                distintos, no al mismo")))
