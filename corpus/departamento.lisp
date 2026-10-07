;;;; La gestion del departamento: que profesor imparte que.
;;;;
;;;; Es el libro del generador de departamento del sistema anterior
;;;; (departamento/, retirado en 30878a9), en su forma editable del
;;;; 2026-09-07. El pedido original del tutor, del 8 de agosto: un documento
;;;; para decidir que profesor imparte que asignatura, y leer de esa decision
;;;; la carga de cada profesor y como va cubierta cada asignatura.
;;;;
;;;; La decision vive en el documento, no en los datos. Se escribe a mano la
;;;; asignatura, el tipo, el grupo y el profesor de cada fila de carga; todo lo
;;;; demas se calcula:
;;;;
;;;;   - por profesor, las horas que lleva, cuantas asignaturas DISTINTAS da y
;;;;     el detalle de lo que imparte. La Conf y dos grupos de CP de la misma
;;;;     asignatura cuentan como una asignatura, no como tres.
;;;;   - por asignatura, si las filas de carga creadas cubren las horas que
;;;;     declara el plan y si a alguna le falta profesor.
;;;;
;;;; Las tres reglas de la version de Python se conservan con su significado:
;;;; rojo en el profesor que pasa de su tope, amarillo en la fila sin profesor,
;;;; verde o naranja en la cobertura. Aqui ninguna dice de que color es.
;;;;
;;;; LEASE EN VOZ ALTA. Si hay que explicarla, el vocabulario esta mal.

(in-package #:situacion.corpus)

(defsituacion departamento (:etiqueta "Departamento de Matematica Aplicada")

  ;; El claustro. Cada profesor con su tope de horas del semestre.
  (coleccion profesores
    (:etiqueta "Profesores")
    (:clave id)
    (:crece)
    (campo id     :rol fijo :etiqueta "Id")
    (campo nombre :rol fijo :etiqueta "Nombre")
    (campo grado  :rol fijo :etiqueta "Grado")
    (campo tope   :rol fijo :tipo entero :etiqueta "Tope")

    ;; Las horas que lleva repartidas hasta ahora.
    (campo horas :rol derivado :tipo entero :etiqueta "Horas"
           (suma horas de asignacion :donde (= profesor (de fila id))))

    ;; Cuantas asignaturas distintas da. Se cuenta solo la primera fila de
    ;; cada par profesor-asignatura: ver el campo PRIMERA de la asignacion.
    (campo asignaturas :rol derivado :tipo entero :etiqueta "Asignaturas"
           (suma primera de asignacion :donde (= profesor (de fila id))))

    ;; Lo que imparte, fila por fila.
    (campo imparte :rol derivado :etiqueta "Lo que imparte"
           (las-filas-de asignacion :donde (= profesor (de fila id))))

    (:datos (("PIAD" "Pedro I. Alonso Diaz" "Dr."  160)
             ("MARA" "Maria Ramirez"        "MSc."  80)
             ("LUGO" "Luis Gomez"           "Lic." 160)
             ("ROTO" "Rosa Torres"          "Dra." 160))))

  ;; El plan del semestre: cuantas horas lleva cada asignatura.
  (coleccion asignaturas
    (:etiqueta "Asignaturas")
    (:clave id)
    (:crece)
    (campo id         :rol fijo :etiqueta "Id")
    (campo nombre     :rol fijo :etiqueta "Asignatura")
    (campo carrera    :rol fijo :etiqueta "Carrera")
    (campo horas-conf :rol fijo :tipo entero :etiqueta "Horas Conf")
    (campo horas-cp   :rol fijo :tipo entero :etiqueta "Horas CP")
    (campo grupos-cp  :rol fijo :tipo entero :etiqueta "Grupos CP")

    ;; Las horas de CP son por grupo: dos grupos de 32 son 64.
    (campo planificadas :rol derivado :tipo entero :etiqueta "Horas planificadas"
           (+ (de fila horas-conf) (* (de fila horas-cp) (de fila grupos-cp))))

    (campo filas :rol derivado :tipo entero :etiqueta "Filas de carga"
           (cuantas asignacion :donde (= asignatura (de fila id))))

    (campo creadas :rol derivado :tipo entero :etiqueta "Horas en filas"
           (suma horas de asignacion :donde (= asignatura (de fila id))))

    (campo asignadas :rol derivado :tipo entero :etiqueta "Horas asignadas"
           (suma horas de asignacion :donde (y (= asignatura (de fila id))
                                              (no (vacio? profesor)))))

    (campo sin-profesor :rol derivado :tipo entero :etiqueta "Sin profesor"
           (cuantas asignacion :donde (y (= asignatura (de fila id))
                                         (vacio? profesor))))

    ;; Lo que falta, dicho con texto para no tener que interpretar un color.
    ;; Primero lo que hay que crear, despues a quien hay que asignar.
    (campo estado :rol derivado :etiqueta "Cobertura"
           (si (= (de fila filas) 0)
               "Sin filas de carga"
               (si (< (de fila creadas) (de fila planificadas))
                   (texto (plural (- (de fila planificadas) (de fila creadas))
                                  "Falta" "Faltan")
                          " " (- (de fila planificadas) (de fila creadas))
                          " horas de carga")
                   (si (> (de fila sin-profesor) 0)
                       (texto (plural (de fila sin-profesor) "Falta" "Faltan")
                              " " (de fila sin-profesor) " "
                              (plural (de fila sin-profesor) "profesor" "profesores"))
                       "Completa"))))

    (:datos (("EST-CC"  "Estadistica (CC)"        "Ciencia de la Computacion" 32 32 2)
             ("EST-MAT" "Estadistica (Mat)"       "Matematica"                32 32 1)
             ("PROB"    "Probabilidades"          "Matematica"                48 32 2)
             ("MNUM"    "Metodos Numericos"       "Ciencia de la Computacion" 32 48 1))))

  ;; LA ASIGNACION. Una fila por fila de carga: la Conf de una asignatura, o
  ;; uno de sus grupos de CP. Cada una la imparte exactamente un profesor.
  (coleccion asignacion
    (:etiqueta "Asignacion")
    (:clave linea)
    (:crece)
    (campo linea :rol fijo :tipo entero :etiqueta "No.")

    (campo asignatura :rol entrada :etiqueta "Id"
           :dominio   (los id de asignaturas)
           :al-violar advertir)
    (campo tipo :rol entrada :etiqueta "Tipo"
           :dominio   (uno-de "Conf" "CP")
           :al-violar advertir)
    (campo grupo :rol entrada :etiqueta "Grupo")
    (campo profesor :rol entrada :etiqueta "Profesor"
           :dominio   (los id de profesores)
           :al-violar advertir)

    (campo nombre :rol derivado :etiqueta "Asignatura"
           (el nombre de (la-fila-de asignaturas
                           :donde (= id (de fila asignatura)))
               :si-no ""))

    ;; Las horas salen del plan, segun sea la Conf o un grupo de CP. Corregir
    ;; las horas en el plan corrige todas sus filas.
    (campo horas :rol derivado :tipo entero :etiqueta "Horas"
           (si (= (de fila tipo) "Conf")
               (el horas-conf de (la-fila-de asignaturas
                                   :donde (= id (de fila asignatura)))
                   :si-no 0)
               (el horas-cp de (la-fila-de asignaturas
                                 :donde (= id (de fila asignatura)))
                   :si-no 0)))

    (campo nombre-profesor :rol derivado :etiqueta "Nombre"
           (el nombre de (la-fila-de profesores
                           :donde (= id (de fila profesor)))
               :si-no ""))

    ;; Para contar asignaturas distintas por profesor. El conteo de distintos
    ;; con filtro no tiene formula portable en una hoja de calculo, asi que
    ;; se dice de otra forma que todas las arquitecturas entienden: cada par
    ;; profesor-asignatura cuenta una vez, en la primera fila donde aparece.
    ;;
    ;; El CODIGO va declarado despues del PAR a proposito: la hoja de calculo
    ;; busca con BUSCARV, que solo devuelve columnas a la derecha de la que
    ;; compara. Es el unico sitio de la descripcion donde el orden de los
    ;; campos importa, y es una limitacion conocida de esa arquitectura.
    (campo par :rol derivado :etiqueta "Par"
           (si (o (vacio? (de fila profesor)) (vacio? (de fila asignatura)))
               ""
               (texto (de fila profesor) "|" (de fila asignatura))))
    (campo codigo :rol derivado :etiqueta "Codigo"
           (texto (de fila asignatura) " " (de fila tipo) " " (de fila grupo)))
    (campo primera-del-par :rol derivado :etiqueta "Primera del par"
           (si (= (de fila par) "")
               ""
               (el codigo de (la-fila-de asignacion :donde (= par (de fila par)))
                   :si-no "")))
    (campo primera :rol derivado :tipo entero :etiqueta "Cuenta"
           (si (y (no (= (de fila par) ""))
                  (= (de fila primera-del-par) (de fila codigo)))
               1
               0))

    (:datos ((1) (2) (3) (4) (5) (6) (7) (8) (9) (10) (11))))

  ;; Una fila de carga con asignatura y sin profesor: hay trabajo por hacer.
  (marca falta-profesor
    :en asignacion
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (vacio? (de fila profesor)))
    :sobre     (profesor)
    :severidad advertencia
    :explica   "Esta fila de carga todavia no tiene profesor")

  ;; El profesor pasa de su tope de horas.
  (marca sobrecarga
    :en profesores
    :cuando    (> (de fila horas) (de fila tope))
    :sobre     (horas tope)
    :severidad problema
    :explica   (texto "Pasa del tope en " (- (de fila horas) (de fila tope))
                      " horas"))

  ;; Las dos marcas de cobertura exigen que la fila tenga asignatura: una
  ;; fila libre al final de la lista no esta incompleta, esta sin usar.
  (marca cobertura-incompleta
    :en asignaturas
    :cuando    (y (no (vacio? (de fila id)))
                  (no (= (de fila estado) "Completa")))
    :sobre     (nombre estado)
    :severidad advertencia
    :explica   (de fila estado))

  (marca cobertura-completa
    :en asignaturas
    :cuando    (y (no (vacio? (de fila id)))
                  (= (de fila estado) "Completa"))
    :sobre     (nombre estado)
    :severidad informativa)

  (vista asignacion :de asignacion :entrada t :etiqueta "Asignacion")
  (vista claustro   :de profesores :etiqueta "Carga por profesor")
  (vista cobertura  :de asignaturas :etiqueta "Cobertura por asignatura"))

;;; Un reparto a medio hacer, con los cuatro avisos puestos a proposito:
;;;
;;;   - Maria Ramirez tiene tope 80 y lleva 112 horas: sobrecarga.
;;;   - Al grupo 2 de CP de PROB le falta profesor.
;;;   - A MNUM le falta crear su fila de CP: 48 horas de carga.
;;;   - EST-MAT esta completa.
;;;
;;; Y el caso de las asignaturas distintas: Pedro da la Conf y los dos grupos
;;; de CP de EST-CC mas la Conf de EST-MAT. Son cuatro filas y 128 horas, pero
;;; dos asignaturas.
(defparameter datos-del-departamento
  (let ((n (lambda (s) (nucleo:nombrar s))))
    (flet ((fila (pares)
             (loop for (c . v) in pares collect (cons (funcall n c) v))))
      (list
       (cons (funcall n "profesores")
             (loop for (id nombre grado tope)
                     in '(("PIAD" "Pedro I. Alonso Diaz" "Dr."  160)
                          ("MARA" "Maria Ramirez"        "MSc."  80)
                          ("LUGO" "Luis Gomez"           "Lic." 160)
                          ("ROTO" "Rosa Torres"          "Dra." 160))
                   collect (fila (list (cons "id" id) (cons "nombre" nombre)
                                       (cons "grado" grado) (cons "tope" tope)))))
       (cons (funcall n "asignaturas")
             (loop for (id nombre carrera conf cp grupos)
                     in '(("EST-CC"  "Estadistica (CC)"  "Ciencia de la Computacion" 32 32 2)
                          ("EST-MAT" "Estadistica (Mat)" "Matematica"                32 32 1)
                          ("PROB"    "Probabilidades"    "Matematica"                48 32 2)
                          ("MNUM"    "Metodos Numericos" "Ciencia de la Computacion" 32 48 1))
                   collect (fila (list (cons "id" id) (cons "nombre" nombre)
                                       (cons "carrera" carrera)
                                       (cons "horas-conf" conf) (cons "horas-cp" cp)
                                       (cons "grupos-cp" grupos)))))
       (cons (funcall n "asignacion")
             (loop for (linea asignatura tipo grupo profesor)
                     in '((1  "EST-CC"  "Conf" ""  "PIAD")
                          (2  "EST-CC"  "CP"   "1" "PIAD")
                          (3  "EST-CC"  "CP"   "2" "PIAD")
                          (4  "EST-MAT" "Conf" ""  "PIAD")
                          (5  "EST-MAT" "CP"   "1" "LUGO")
                          (6  "PROB"    "Conf" ""  "MARA")
                          (7  "PROB"    "CP"   "1" "MARA")
                          (8  "PROB"    "CP"   "2" "")
                          (9  "MNUM"    "Conf" ""  "MARA")
                          (10 ""        ""     ""  "")
                          (11 ""        ""     ""  ""))
                   collect (fila (list (cons "linea" linea)
                                       (cons "asignatura" asignatura)
                                       (cons "tipo" tipo) (cons "grupo" grupo)
                                       (cons "profesor" profesor)))))))))
