;;;; El horario semanal del preuniversitario Saul Delgado.
;;;;
;;;; Es el primer caso real del reparto con la otra tesis: aqui se DESCRIBE y
;;;; se VALIDA un horario ya hecho; encontrarlo es de la otra tesis. El
;;;; enunciado esta en descripcion-saul.md y las reglas se llaman como alli.
;;;;
;;;; LOS DATOS SON LOS DEL HORARIO REAL de 10-3 y 10-4, "ultima version" del
;;;; 14/09/26, con las correcciones hechas a mano en rojo. Se transcribieron
;;;; de la foto del horario impreso. Lo que la foto no dice va marcado como
;;;; SUPUESTO en cada sitio donde se usa, hasta que el centro lo confirme:
;;;;
;;;;   - Los profesores. La foto no los trae. Se supone uno distinto por
;;;;     asignatura y grupo, asi que hoy no puede haber choque de profesores.
;;;;   - Los locales. Se supone que cada grupo tiene su aula, salvo Educacion
;;;;     Fisica (terreno) e Informatica (laboratorio).
;;;;   - El dia de preparacion de cada asignatura: ninguno.
;;;;   - Los contratados y los que viven lejos: ninguno.
;;;;   - Que asignaturas admiten tarde: solo AL/AC, que es la unica que el
;;;;     horario real pone en el turno 7.
;;;;   - El nombre largo de algunas asignaturas.
;;;;
;;;; El dia, tal como lo usa el centro hoy: seis turnos de manana y uno de
;;;; tarde, despues del almuerzo. La descripcion habla de ocho turnos (cinco
;;;; y tres); la foto manda.

(in-package #:situacion.corpus)

(defsituacion horario-saul
    (:etiqueta "Horario docente de 10mo grado, preuniversitario Saul Delgado")

  ;; El plan del ano: cuantas veces recibe cada grupo cada asignatura. Las
  ;; frecuencias salen de contar la foto, y dan lo mismo en los dos grupos.
  (coleccion asignaturas
    (:etiqueta "Asignaturas")
    (:clave abrev)
    (campo abrev      :rol fijo :etiqueta "Abrev")
    (campo nombre     :rol fijo :etiqueta "Asignatura")
    (campo frecuencia :rol fijo :tipo entero :etiqueta "Frecuencia")
    ;; "Las asignaturas de frecuencia cinco son exactamente las que admiten
    ;; turno doble": se deriva, no se escribe dos veces.
    (campo turno-doble :rol derivado :etiqueta "Turno doble"
           (si (= (de fila frecuencia) 5) "si" "no"))
    (campo admite-tarde    :rol fijo :etiqueta "Admite tarde")      ; SUPUESTO
    (campo dia-preparacion :rol fijo :etiqueta "Dia de preparacion") ; SUPUESTO
    ;; Vacio: se da en el aula del grupo.
    (campo local           :rol fijo :etiqueta "Local")              ; SUPUESTO
    (:datos (("M" "Matematica" 5 "no" "" ""))))

  ;; Quien da cada asignatura a cada grupo. El enunciado dice que viene dado.
  ;; La CLAVE es grupo y asignatura juntos, escritos en un solo campo: la
  ;; hoja de calculo busca por una sola igualdad.
  (coleccion plan-por-grupo
    (:etiqueta "Plan por grupo")
    (:clave clave)
    (campo clave    :rol fijo :etiqueta "Clave")
    (campo grupo    :rol fijo :etiqueta "Grupo")
    (campo abrev    :rol fijo :etiqueta "Abrev")
    (campo profesor :rol fijo :etiqueta "Profesor")                   ; SUPUESTO
    (campo nombre :rol derivado :etiqueta "Asignatura"
           (el nombre de (la-fila-de asignaturas :donde (= abrev (de fila abrev)))
               :si-no ""))
    (campo frecuencia :rol derivado :tipo entero :etiqueta "Frecuencia"
           (el frecuencia de (la-fila-de asignaturas :donde (= abrev (de fila abrev)))
               :si-no 0))
    (campo asignadas :rol derivado :tipo entero :etiqueta "Asignadas"
           (cuantas casillas :donde (y (= grupo (de fila grupo))
                                       (= asignatura (de fila abrev)))))
    (campo faltan :rol derivado :tipo entero :etiqueta "Faltan"
           (- (de fila frecuencia) (de fila asignadas)))
    (:datos (("10-3#M" "10-3" "M" "Profesor de M en 10-3"))))

  ;; Las dos disposiciones sobre los profesores que usan las reglas.
  (coleccion profesores
    (:etiqueta "Profesores")
    (:clave nombre)
    (campo nombre     :rol fijo :etiqueta "Profesor")
    (campo contratado :rol fijo :etiqueta "Contratado")               ; SUPUESTO
    (campo vive-lejos :rol fijo :etiqueta "Vive lejos")               ; SUPUESTO
    (:datos (("Profesor de M en 10-3" "no" "no"))))

  ;; Que dias asiste cada profesor contratado, con la clave profesor#dia.
  ;; Hoy no hay contratados (SUPUESTO), asi que no hay filas.
  (coleccion disponibilidad
    (:etiqueta "Dias que asisten los contratados")
    (:clave clave)
    (campo clave    :rol fijo :etiqueta "Clave")
    (campo profesor :rol fijo :etiqueta "Profesor")
    (campo dia      :rol fijo :etiqueta "Dia")
    (campo asiste   :rol fijo :etiqueta "Asiste"))

  ;; LA REJILLA, una fila por casilla: grupo, dia y turno. Solo la
  ;; asignatura se escribe; lo demas se trae de las tablas de arriba.
  (coleccion casillas
    (:etiqueta "Casillas del horario")
    (:clave grupo dia turno)
    (:orden turno)
    (campo grupo :rol fijo :etiqueta "Grupo")
    (campo dia   :rol fijo :etiqueta "Dia")
    (campo turno :rol fijo :tipo entero :etiqueta "Turno")

    (campo asignatura :rol entrada :etiqueta "Asignatura"
           :dominio   (los abrev de asignaturas)
           :al-violar advertir)

    (campo nombre :rol derivado :etiqueta "Nombre"
           (el nombre de (la-fila-de asignaturas
                           :donde (= abrev (de fila asignatura)))
               :si-no ""))
    (campo clave-plan :rol derivado :etiqueta "Grupo#Asignatura"
           (texto (de fila grupo) "#" (de fila asignatura)))
    (campo profesor :rol derivado :etiqueta "Profesor"
           (el profesor de (la-fila-de plan-por-grupo
                             :donde (= clave (de fila clave-plan)))
               :si-no ""))
    (campo local :rol derivado :etiqueta "Local de la asignatura"
           (el local de (la-fila-de asignaturas
                          :donde (= abrev (de fila asignatura)))
               :si-no ""))
    (campo aula :rol derivado :etiqueta "Aula"
           (si (vacio? (de fila asignatura))
               ""
               (si (vacio? (de fila local))
                   (texto "Aula " (de fila grupo))
                   (de fila local))))
    (campo turno-doble :rol derivado :etiqueta "Turno doble"
           (el turno-doble de (la-fila-de asignaturas
                                :donde (= abrev (de fila asignatura)))
               :si-no "no"))
    (campo admite-tarde :rol derivado :etiqueta "Admite tarde"
           (el admite-tarde de (la-fila-de asignaturas
                                 :donde (= abrev (de fila asignatura)))
               :si-no "no"))
    (campo dia-preparacion :rol derivado :etiqueta "Dia de preparacion"
           (el dia-preparacion de (la-fila-de asignaturas
                                    :donde (= abrev (de fila asignatura)))
               :si-no ""))
    (campo profesor-contratado :rol derivado :etiqueta "Contratado"
           (el contratado de (la-fila-de profesores
                               :donde (= nombre (de fila profesor)))
               :si-no "no"))
    (campo profesor-vive-lejos :rol derivado :etiqueta "Vive lejos"
           (el vive-lejos de (la-fila-de profesores
                               :donde (= nombre (de fila profesor)))
               :si-no "no"))
    (campo clave-asistencia :rol derivado :etiqueta "Profesor#Dia"
           (texto (de fila profesor) "#" (de fila dia)))
    (campo profesor-asiste-hoy :rol derivado :etiqueta "Asiste hoy"
           (el asiste de (la-fila-de disponibilidad
                           :donde (= clave (de fila clave-asistencia)))
               :si-no "no"))

    ;; Reglas 3 y 4: la misma asignatura otra vez el mismo dia en el mismo
    ;; grupo, cuando no admite turno doble o no es en el turno de al lado.
    ;; Es un campo, y no solo la condicion de la marca, para que la
    ;; demostracion compruebe el valor en las tres arquitecturas.
    (campo repite-mal :rol derivado :etiqueta "Repite mal el dia"
           (si (y (no (vacio? (de fila asignatura)))
                  (existe otra :en casillas
                    :distinta-de fila
                    :donde (y (= (de otra grupo) (de fila grupo))
                              (= (de otra dia) (de fila dia))
                              (= (de otra asignatura) (de fila asignatura))
                              (o (= (de fila turno-doble) "no")
                                 (y (/= (de otra turno) (+ (de fila turno) 1))
                                    (/= (de otra turno) (- (de fila turno) 1)))))))
               "si"
               "no"))

    (:datos (("10-3" "L" 1))))

  ;; Cuantas sesiones da cada profesor cada dia, para la regla blanda del tope.
  (coleccion carga-diaria
    (:etiqueta "Carga diaria por profesor")
    (:clave profesor dia)
    (campo profesor :rol fijo :etiqueta "Profesor")
    (campo dia      :rol fijo :etiqueta "Dia")
    (campo sesiones :rol derivado :tipo entero :etiqueta "Sesiones"
           (cuantas casillas :donde (y (= profesor (de fila profesor))
                                       (= dia (de fila dia))
                                       (no (vacio? asignatura)))))
    (:datos (("Profesor de M en 10-3" "L"))))

  (parametro tope-diario :tipo entero :valor 3                         ; SUPUESTO
             :etiqueta "Tope de sesiones al dia por profesor")

  ;; ------------------------------------------------------------------
  ;; LAS RESTRICCIONES DURAS. Cada una senala el horario que no la cumple.
  ;; ------------------------------------------------------------------

  ;; "Un grupo no puede recibir dos sesiones en el mismo dia y el mismo
  ;; turno." No hace falta marca: la clave de CASILLAS es grupo, dia y
  ;; turno, y dos sesiones asi serian la misma fila.

  ;; "Un profesor no puede impartir dos sesiones en el mismo dia y turno."
  (marca profesor-colisiona
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (existe otra :en casillas
                    :distinta-de fila
                    :donde (y (= (de otra dia) (de fila dia))
                              (= (de otra turno) (de fila turno))
                              (= (de otra profesor) (de fila profesor)))))
    :sobre     (asignatura profesor)
    :severidad problema
    :explica   "Este profesor ya da clase a otro grupo en este mismo turno")

  ;; No esta en el enunciado, pero es lo que garantiza el horario por aula.
  (marca aula-ocupada
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (existe otra :en casillas
                    :distinta-de fila
                    :donde (y (= (de otra dia) (de fila dia))
                              (= (de otra turno) (de fila turno))
                              (= (de otra aula) (de fila aula)))))
    :sobre     (aula)
    :severidad problema
    :explica   "Ese local esta ocupado por otro grupo a esa hora")

  ;; "Una asignatura que no admite turno doble no puede tener dos sesiones
  ;; del mismo grupo el mismo dia" y "una que admite turno doble, solo en
  ;; turnos consecutivos".
  (marca sesion-repetida-mal
    :en casillas
    :cuando    (= (de fila repite-mal) "si")
    :sobre     (asignatura)
    :severidad problema
    :explica   (si (= (de fila turno-doble) "no")
                   "Esta asignatura no admite turno doble y repite el dia en este grupo"
                   "Esta asignatura repite el dia en este grupo sin ser en turnos seguidos"))

  ;; "Ninguna sesion cae en el dia de preparacion de su asignatura."
  (marca en-dia-de-preparacion
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (= (de fila dia) (de fila dia-preparacion)))
    :sobre     (asignatura)
    :severidad problema
    :explica   "Es el dia de preparacion de la asignatura")

  ;; "Ninguna sesion de educacion fisica cae despues del tercer turno."
  (marca ef-despues-del-tercer-turno
    :en casillas
    :cuando    (y (= (de fila asignatura) "EF") (> (de fila turno) 3))
    :sobre     (asignatura turno)
    :severidad problema
    :explica   "Educacion Fisica no puede caer despues del tercer turno")

  ;; "Ninguna sesion de una asignatura que no admite tarde cae en la tarde."
  ;; Con el dia del centro, la tarde es el turno 7.
  (marca en-la-tarde-sin-admitirla
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (= (de fila admite-tarde) "no")
                  (> (de fila turno) 6))
    :sobre     (asignatura turno)
    :severidad problema
    :explica   "Esta asignatura no admite turnos de tarde")

  ;; "Ningun profesor contratado imparte en un dia en que no asiste."
  (marca contratado-en-dia-que-no-asiste
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (= (de fila profesor-contratado) "si")
                  (= (de fila profesor-asiste-hoy) "no"))
    :sobre     (asignatura profesor)
    :severidad problema
    :explica   "Este profesor esta contratado y no asiste al centro este dia")

  ;; "Cada grupo recibe cada asignatura tantas veces como indica su
  ;; frecuencia."
  (marca frecuencia-incompleta
    :en plan-por-grupo
    :cuando    (> (de fila faltan) 0)
    :sobre     (asignadas faltan)
    :severidad problema
    :explica   (texto (plural (de fila faltan) "Falta" "Faltan") " "
                      (de fila faltan) " "
                      (plural (de fila faltan) "sesion" "sesiones")))

  (marca frecuencia-excedida
    :en plan-por-grupo
    :cuando    (< (de fila faltan) 0)
    :sobre     (asignadas faltan)
    :severidad problema
    :explica   (texto (plural (- 0 (de fila faltan)) "Sobra" "Sobran") " "
                      (- 0 (de fila faltan)) " "
                      (plural (- 0 (de fila faltan)) "sesion" "sesiones")))

  ;; ------------------------------------------------------------------
  ;; LAS RESTRICCIONES BLANDAS. Solo se senalan, como advertencia: elegir el
  ;; horario que mas las cumpla no es de este lenguaje.
  ;; ------------------------------------------------------------------

  (marca primer-turno-a-quien-vive-lejos
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (= (de fila profesor-vive-lejos) "si")
                  (= (de fila turno) 1))
    :sobre     (asignatura profesor)
    :severidad advertencia
    :explica   "Se preferiria no darle el primer turno a un profesor que vive lejos")

  (marca pasa-del-tope-diario
    :en carga-diaria
    :cuando    (> (de fila sesiones) (parametro tope-diario))
    :sobre     (sesiones)
    :severidad advertencia
    :explica   (texto "Da " (de fila sesiones) " sesiones ese dia"))

  (marca turno-libre
    :en casillas
    :cuando    (vacio? (de fila asignatura))
    :sobre     (asignatura)
    :severidad informativa
    :explica   "Turno sin asignar")

  ;; Las tres tablas que pidio el centro: la misma rejilla de turno por dia,
  ;; partida por grupo, por profesor y por aula. Las dos ultimas solo estan
  ;; bien definidas si nadie esta en dos sitios a la vez; si lo esta, la
  ;; casilla ensena el choque.
  (vista por-grupo :de casillas :entrada t :etiqueta "Horario del grupo"
                   :filas turno :columnas dia :muestra asignatura
                   :secciones grupo)
  (vista por-profesor :de casillas :etiqueta "Horario del profesor"
                      :filas turno :columnas dia :muestra grupo
                      :secciones profesor
                      :unica-salvo profesor-colisiona)
  (vista por-aula :de casillas :etiqueta "Horario del aula"
                  :filas turno :columnas dia :muestra grupo
                  :secciones aula
                  :unica-salvo aula-ocupada)
  (vista plan        :de asignaturas    :etiqueta "Asignaturas")
  (vista frecuencias :de plan-por-grupo :etiqueta "Frecuencias por grupo")
  (vista carga       :de carga-diaria   :etiqueta "Carga diaria"))

;;; ====================================================================
;;; LOS DATOS
;;; ====================================================================

(defparameter +dias-del-saul+ '("L" "M" "MI" "J" "V"))

;;; Las asignaturas: abreviatura, nombre, frecuencia, admite tarde y local.
;;; Los nombres entre parentesis estan por confirmar: la foto solo trae la
;;; abreviatura.
(defparameter +asignaturas-del-saul+
  '(("M"     "Matematica"                   5 "no" "")
    ("Lit-L" "Literatura y Lengua"          4 "no" "")
    ("F"     "Fisica"                       3 "no" "")
    ("I"     "Ingles"                       3 "no" "")
    ("H"     "Historia"                     3 "no" "")
    ("EF"    "Educacion Fisica"             2 "no" "Terreno")
    ("B"     "Biologia"                     2 "no" "")
    ("G"     "Geografia"                    2 "no" "")
    ("INF"   "Informatica"                  1 "no" "Laboratorio")
    ("Q"     "Quimica"                      1 "no" "")
    ("CP"    "(CP, por confirmar)"          1 "no" "")
    ("DC"    "(DC, por confirmar)"          1 "no" "")
    ("CA"    "(CA, por confirmar)"          1 "no" "")
    ("RD"    "(RD, por confirmar)"          1 "no" "")
    ("AL/AC" "(AL/AC, por confirmar)"       1 "si" "")))

;;; El horario real, por turno y de lunes a viernes. "" es un turno libre.
;;; Las correcciones en rojo de la foto ya estan aplicadas.
(defparameter +horario-10-3+
  '((1 "EF"    "H"     "EF"    "INF"   "F")
    (2 "I"     "B"     "M"     "F"     "DC")
    (3 "B"     "CP"    "M"     "Lit-L" "Q")
    (4 "Lit-L" "Lit-L" "H"     "Lit-L" "I")
    (5 "CA"    "G"     "G"     "I"     "M")
    (6 "M"     "RD"    "F"     "H"     "M")
    (7 ""      ""      "AL/AC" ""      "")))

(defparameter +horario-10-4+
  '((1 "M"     "Lit-L" "CP"    "F"     "Lit-L")
    (2 "M"     "I"     "EF"    "I"     "Lit-L")
    (3 "EF"    "B"     "M"     "M"     "F")
    (4 "CA"    "H"     "G"     "INF"   "I")
    (5 "RD"    "DC"    "F"     "H"     "Q")
    (6 "B"     "G"     "H"     "Lit-L" "M")
    (7 "AL/AC" ""      ""      ""      "")))

(defparameter +grupos-del-saul+
  (list (cons "10-3" +horario-10-3+) (cons "10-4" +horario-10-4+)))

(defun profesor-supuesto (grupo abrev)
  "SUPUESTO: un profesor distinto por asignatura y grupo."
  (format nil "Profesor de ~a en ~a" abrev grupo))

(defparameter datos-del-saul
  (let ((n (lambda (s) (nucleo:nombrar s))))
    (flet ((fila (&rest pares)
             (loop for (campo valor) on pares by #'cddr
                   collect (cons (funcall n campo) valor))))
      (let ((profesores
              (loop for (grupo . nil) in +grupos-del-saul+
                    append (loop for (abrev) in +asignaturas-del-saul+
                                 collect (profesor-supuesto grupo abrev)))))
        (list
         (cons (funcall n "asignaturas")
               (loop for (abrev nombre frecuencia tarde local) in +asignaturas-del-saul+
                     collect (fila "abrev" abrev "nombre" nombre
                                   "frecuencia" frecuencia "admite-tarde" tarde
                                   "dia-preparacion" "" "local" local)))
         (cons (funcall n "plan-por-grupo")
               (loop for (grupo . nil) in +grupos-del-saul+
                     append (loop for (abrev) in +asignaturas-del-saul+
                                  collect (fila "clave" (format nil "~a#~a" grupo abrev)
                                                "grupo" grupo "abrev" abrev
                                                "profesor" (profesor-supuesto grupo abrev)))))
         (cons (funcall n "profesores")
               (loop for p in profesores
                     collect (fila "nombre" p "contratado" "no" "vive-lejos" "no")))
         (cons (funcall n "disponibilidad") '())
         (cons (funcall n "casillas")
               (loop for (grupo . horario) in +grupos-del-saul+
                     append (loop for dia in +dias-del-saul+
                                  for columna from 1
                                  append (loop for renglon in horario
                                               collect (fila "grupo" grupo "dia" dia
                                                             "turno" (first renglon)
                                                             "asignatura" (nth columna renglon))))))
         (cons (funcall n "carga-diaria")
               (loop for p in profesores
                     append (loop for dia in +dias-del-saul+
                                  collect (fila "profesor" p "dia" dia))))))))
  "El horario real de 10-3 y 10-4, con los supuestos de la cabecera.")
