;;;; El horario semanal de un grupo.
;;;;
;;;; ES LA PARTE DEL CORPUS QUE NO CABIA. La hoja de grupo del generador de
;;;; horarios -horarios/hoja_grupo.py- no es una lista de filas: es una
;;;; rejilla de dia por turno. Durante todo el analisis se clasifico como
;;;; "no encaja en el modelo", y por eso se dejo fuera.
;;;;
;;;; La salida fue darse cuenta de que LA MATRIZ NUNCA FUE UNA ESTRUCTURA DE
;;;; DATOS. Los datos son, y siempre fueron, una coleccion de filas: dia,
;;;; turno, asignatura, aula. Lo que es matriz es la PRESENTACION. Y la
;;;; presentacion es una vista.
;;;;
;;;; Esa distincion es la misma que el resto del lenguaje aplica en todas
;;;; partes -la intencion se declara, el mecanismo lo inventa cada
;;;; arquitectura- y es lo que baja el problema de "toca el nucleo" a "tres
;;;; ranuras en el nodo de vista".
;;;;
;;;; Lo que cada arquitectura hace con la misma declaracion:
;;;;
;;;;   texto   dibuja la rejilla alineada. Es lo unico que sabe hacer bien
;;;;   pagina  la dibuja recalculando los ejes al vuelo: si manana hay un
;;;;           turno mas, aparece una columna mas sola
;;;;   hoja    la EMULA: fija los dos ejes al generar y se inventa una
;;;;           columna de clave compuesta, porque BUSCARV busca por un
;;;;           criterio y un cruce necesita dos
;;;;
;;;; La tercera es la interesante, y esta declarada en el informe.

(in-package #:situacion.corpus)

(defsituacion horario-del-grupo (:etiqueta "Horario del grupo D111")

  ;; El plan de la carrera: cuantos turnos semanales lleva cada asignatura.
  (coleccion asignaturas
    (:etiqueta "Asignaturas")
    (:clave abrev)
    (campo abrev      :rol fijo :etiqueta "Abrev")
    (campo nombre     :rol fijo :etiqueta "Asignatura")
    (campo frecuencia :rol fijo :tipo entero :etiqueta "Frec")
    (:datos (("AL"  "Algebra Lineal"      3)
             ("L"   "Logica"              2)
             ("IP"  "Intro a la Programacion" 2)
             ("AM"  "Analisis Matematico" 2))))

  ;; Los locales disponibles.
  (coleccion aulas
    (:etiqueta "Aulas")
    (:clave aula)
    (campo aula :rol fijo :etiqueta "Aula")
    (:datos (("Aula 7") ("Aula 8") ("Lab 1"))))

  ;; LA REJILLA, COMO LO QUE ES: una fila por casilla.
  (coleccion casillas
    (:etiqueta "Casillas")
    (:clave dia turno)
    (:orden turno)
    (campo dia   :rol fijo :etiqueta "Dia")
    (campo turno :rol fijo :etiqueta "Turno")

    ;; Lo unico que se escribe a mano, y solo admite asignaturas del plan.
    (campo asignatura :rol entrada
           :etiqueta  "Asignatura"
           :dominio   (los abrev de asignaturas)
           :al-violar advertir)

    (campo aula :rol entrada
           :etiqueta  "Aula"
           :dominio   (los aula de aulas)
           :al-violar advertir)

    ;; El nombre largo se trae solo, para que la rejilla se lea.
    (campo nombre :rol derivado :etiqueta "Nombre"
           (el nombre de (la-fila-de asignaturas
                           :donde (= abrev (de fila asignatura)))
               :si-no ""))

    ;; Cuantos turnos lleva ya puestos esta asignatura en toda la semana.
    (campo puestos :rol derivado :tipo entero :etiqueta "Puestos"
           (cuantas casillas :donde (= asignatura (de fila asignatura))))

    (campo faltan :rol derivado :tipo entero :etiqueta "Faltan"
           (- (el frecuencia de (la-fila-de asignaturas
                                  :donde (= abrev (de fila asignatura)))
                  :si-no 0)
              (de fila puestos)))

    (:datos (("lunes"     "T1") ("lunes"     "T2") ("lunes"     "T3")
             ("martes"    "T1") ("martes"    "T2") ("martes"    "T3")
             ("miercoles" "T1") ("miercoles" "T2") ("miercoles" "T3"))))

  ;; El aula ocupada dos veces en el mismo turno del mismo dia.
  (marca aula-ocupada
    :en casillas
    :cuando (y (no (vacio? (de fila aula)))
               (existe otra :en casillas
                 :distinta-de fila
                 :donde (y (= (de otra dia) (de fila dia))
                           (= (de otra turno) (de fila turno))
                           (= (de otra aula) (de fila aula)))))
    :sobre     (aula)
    :severidad problema
    :explica   "Ese local esta ocupado por otro grupo a esa hora")

  (marca asignatura-excedida
    :en casillas
    :cuando    (< (de fila faltan) 0)
    :sobre     (asignatura nombre faltan)
    :severidad advertencia
    :explica   (texto (plural (- 0 (de fila faltan)) "Sobra" "Sobran") " "
                      (- 0 (de fila faltan)) " "
                      (plural (- 0 (de fila faltan)) "turno" "turnos")))

  (marca casilla-libre
    :en casillas
    :cuando    (vacio? (de fila asignatura))
    :sobre     (asignatura)
    :severidad informativa
    :explica   "Turno sin asignar")

  ;; LA VISTA CRUZADA. Aqui es donde la rejilla deja de ser una lista.
  (vista rejilla :de casillas :entrada t
                 :etiqueta "Horario semanal"
                 :filas turno :columnas dia :muestra asignatura)

  (vista detalle :de casillas :etiqueta "Casilla por casilla")
  (vista plan    :de asignaturas :etiqueta "Plan de la carrera"))

(defparameter datos-del-horario
  (let ((n (lambda (s) (nucleo:nombrar s))))
    (flet ((fila (pares)
             (loop for (c . v) in pares collect (cons (funcall n c) v))))
      (list
       (cons (funcall n "asignaturas")
             (loop for (a nom f) in '(("AL" "Algebra Lineal" 3)
                                      ("L"  "Logica" 2)
                                      ("IP" "Intro a la Programacion" 2)
                                      ("AM" "Analisis Matematico" 2))
                   collect (fila (list (cons "abrev" a)
                                       (cons "nombre" nom)
                                       (cons "frecuencia" f)))))
       (cons (funcall n "aulas")
             (loop for a in '("Aula 7" "Aula 8" "Lab 1")
                   collect (fila (list (cons "aula" a)))))
       ;; Un horario a medio llenar, con dos problemas puestos a proposito:
       ;; Algebra Lineal aparece cuatro veces y lleva tres turnos, y el lunes
       ;; a primera hora hay dos casillas que usan el Aula 8.
       (cons (funcall n "casillas")
             (loop for (dia turno asig aula)
                     in '(("lunes"     "T1" "AL" "Aula 8")
                          ("lunes"     "T2" "L"  "Aula 7")
                          ("lunes"     "T3" ""   "")
                          ("martes"    "T1" "AL" "Aula 8")
                          ("martes"    "T2" "IP" "Lab 1")
                          ("martes"    "T3" "AM" "Aula 7")
                          ("miercoles" "T1" "AL" "Aula 8")
                          ("miercoles" "T2" "AL" "Aula 7")
                          ("miercoles" "T3" ""   ""))
                   collect (fila (list (cons "dia" dia)
                                       (cons "turno" turno)
                                       (cons "asignatura" asig)
                                       (cons "aula" aula)))))))))
