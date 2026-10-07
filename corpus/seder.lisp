;;;; El horario de educacion fisica del SEDER.
;;;;
;;;; El enunciado esta en descripcion-seder.md y las reglas se llaman como
;;;; alli. Igual que el Saul Delgado, aqui se DESCRIBE y se VALIDA un reparto
;;;; ya hecho: a cada brigada se le escribe un horario y una instalacion, y
;;;; las marcas senalan que reglas no cumple. Encontrar el reparto no es de
;;;; este lenguaje.
;;;;
;;;; LOS DATOS SON DE EJEMPLO: no hay todavia datos reales del SEDER. Llevan
;;;; un problema puesto a proposito por cada regla, listados al final.
;;;;
;;;; La franja son seis casillas: tres horarios del unico dia de clase, en la
;;;; semana par y en la impar. Una brigada no elige la semana: la hereda de
;;;; su ano. Por eso la semana es un campo derivado de la brigada y no algo
;;;; que se escriba.

(in-package #:situacion.corpus)

(defsituacion seder (:etiqueta "Horario de educacion fisica del SEDER")

  (coleccion instalaciones
    (:etiqueta "Instalaciones")
    (:clave nombre)
    (campo nombre    :rol fijo :etiqueta "Instalacion")
    (campo capacidad :rol fijo :tipo entero :etiqueta "Capacidad")
    ;; Cuantas brigadas usan la instalacion en toda la franja.
    (campo brigadas :rol derivado :tipo entero :etiqueta "Brigadas"
           (cuantas brigadas :donde (= instalacion (de fila nombre))))
    (campo menos-cargada :rol derivado :tipo entero :etiqueta "La que menos tiene"
           (minimo brigadas de instalaciones))
    (:datos (("Pista 1" 40) ("Pista 2" 30) ("Gimnasio" 25) ("Piscina" 20))))

  ;; Cada ano de cada carrera declara en que semana recibe sus clases.
  (coleccion anos
    (:etiqueta "Anos de carrera")
    (:clave id)
    (campo id      :rol fijo :etiqueta "Ano")
    (campo carrera :rol fijo :etiqueta "Carrera")
    (campo semana  :rol fijo :etiqueta "Semana")
    (:datos (("CC-1" "Ciencia de la Computacion" "par"))))

  ;; Y que horarios tiene disponibles: uno, dos o los tres, una fila por
  ;; cada uno. La clave junta ano y horario en un solo campo porque la hoja
  ;; de calculo busca por una sola igualdad.
  (coleccion disponibles
    (:etiqueta "Horarios disponibles por ano")
    (:clave clave)
    (campo clave   :rol fijo :etiqueta "Clave")
    (campo ano     :rol fijo :etiqueta "Ano")
    (campo horario :rol fijo :etiqueta "Horario")
    (:datos (("CC-1#10 a.m." "CC-1" "10 a.m."))))

  ;; LAS BRIGADAS. Lo que se escribe a mano es el horario y la instalacion;
  ;; el profesor viene dado.
  (coleccion brigadas
    (:etiqueta "Brigadas")
    (:clave brigada)
    (campo brigada  :rol fijo :etiqueta "Brigada")
    (campo ano      :rol fijo :etiqueta "Ano")
    (campo personas :rol fijo :tipo entero :etiqueta "Personas")
    (campo profesor :rol fijo :etiqueta "Profesor")

    (campo horario :rol entrada :etiqueta "Horario"
           :dominio   (uno-de "10 a.m." "11 a.m." "3 p.m.")
           :al-violar advertir)
    (campo instalacion :rol entrada :etiqueta "Instalacion"
           :dominio   (los nombre de instalaciones)
           :al-violar advertir)

    (campo semana :rol derivado :etiqueta "Semana"
           (el semana de (la-fila-de anos :donde (= id (de fila ano)))
               :si-no ""))
    (campo capacidad :rol derivado :tipo entero :etiqueta "Capacidad"
           (el capacidad de (la-fila-de instalaciones
                              :donde (= nombre (de fila instalacion)))
               :si-no 0))
    (campo clave-disponible :rol derivado :etiqueta "Ano#Horario"
           (texto (de fila ano) "#" (de fila horario)))
    (campo disponible :rol derivado :etiqueta "Horario disponible"
           (si (vacio? (de fila horario))
               ""
               (si (= (el clave de (la-fila-de disponibles
                                     :donde (= clave (de fila clave-disponible)))
                          :si-no "")
                      "")
                   "no"
                   "si")))
    (:datos (("C111" "CC-1" 28 "Prof. Alvarez"))))

  ;; Las seis casillas de la franja, para ver cuantas brigadas cae en cada
  ;; una.
  (coleccion franja
    (:etiqueta "Franja")
    (:clave semana horario)
    (campo semana  :rol fijo :etiqueta "Semana")
    (campo horario :rol fijo :etiqueta "Horario")
    (campo brigadas :rol derivado :tipo entero :etiqueta "Brigadas"
           (cuantas brigadas :donde (y (= semana (de fila semana))
                                       (= horario (de fila horario)))))
    (campo menos-cargada :rol derivado :tipo entero :etiqueta "La que menos tiene"
           (minimo brigadas de franja))
    (:datos (("par" "10 a.m.") ("par" "11 a.m.") ("par" "3 p.m.")
             ("impar" "10 a.m.") ("impar" "11 a.m.") ("impar" "3 p.m."))))

  ;; ------------------------------------------------------------------
  ;; LAS RESTRICCIONES DURAS
  ;; ------------------------------------------------------------------

  ;; "Cada brigada recibe exactamente una clase a la semana." Mas de una no
  ;; puede: la clave es la brigada, y cada brigada tiene un solo horario.
  ;; Menos de una si: que le falte el horario o la instalacion.
  (marca sin-clase
    :en brigadas
    :cuando    (o (vacio? (de fila horario)) (vacio? (de fila instalacion)))
    :sobre     (horario instalacion)
    :severidad problema
    :explica   "Esta brigada todavia no tiene clase esta semana")

  ;; "Una brigada solo recibe clase en un horario que su ano tenga
  ;; disponible."
  (marca horario-no-disponible
    :en brigadas
    :cuando    (= (de fila disponible) "no")
    :sobre     (horario)
    :severidad problema
    :explica   "Su ano no tiene este horario disponible")

  ;; "Una brigada no puede recibir clase en una instalacion cuya capacidad
  ;; sea menor que su cantidad de personas."
  (marca instalacion-pequena
    :en brigadas
    :cuando    (y (no (vacio? (de fila instalacion)))
                  (< (de fila capacidad) (de fila personas)))
    :sobre     (instalacion personas capacidad)
    :severidad problema
    :explica   (texto "La instalacion es para " (de fila capacidad)
                      " personas y la brigada tiene " (de fila personas)))

  ;; "Dos brigadas no pueden usar la misma instalacion en el mismo horario
  ;; de la misma paridad."
  (marca instalacion-ocupada
    :en brigadas
    :cuando    (y (no (vacio? (de fila instalacion)))
                  (no (vacio? (de fila horario)))
                  (existe otra :en brigadas
                    :distinta-de fila
                    :donde (y (= (de otra semana) (de fila semana))
                              (= (de otra horario) (de fila horario))
                              (= (de otra instalacion) (de fila instalacion)))))
    :sobre     (instalacion)
    :severidad problema
    :explica   "Otra brigada usa esta instalacion en ese horario y esa semana")

  ;; "Un profesor no puede dar clase a dos brigadas en el mismo horario de
  ;; la misma paridad."
  (marca profesor-en-dos-brigadas
    :en brigadas
    :cuando    (y (no (vacio? (de fila horario)))
                  (existe otra :en brigadas
                    :distinta-de fila
                    :donde (y (= (de otra semana) (de fila semana))
                              (= (de otra horario) (de fila horario))
                              (= (de otra profesor) (de fila profesor)))))
    :sobre     (profesor horario)
    :severidad problema
    :explica   "Este profesor tiene otra brigada en ese horario y esa semana")

  ;; ------------------------------------------------------------------
  ;; LAS RESTRICCIONES BLANDAS. "Equilibrar" se lee aqui como: la que mas
  ;; tiene no supera en mas de una a la que menos tiene. Solo se senala.
  ;; ------------------------------------------------------------------

  (marca instalacion-desequilibrada
    :en instalaciones
    :cuando    (> (de fila brigadas) (+ (de fila menos-cargada) 1))
    :sobre     (brigadas)
    :severidad advertencia
    :explica   (texto "Tiene " (de fila brigadas) " brigadas y otra tiene "
                      (de fila menos-cargada)))

  (marca horario-desequilibrado
    :en franja
    :cuando    (> (de fila brigadas) (+ (de fila menos-cargada) 1))
    :sobre     (brigadas)
    :severidad advertencia
    :explica   (texto "Tiene " (de fila brigadas) " brigadas y otro horario tiene "
                      (de fila menos-cargada)))

  ;; Lo que dice el resultado: en un horario, el profesor de una brigada le
  ;; da clase en una instalacion. Visto por instalacion y por profesor.
  (vista reparto :de brigadas :entrada t :etiqueta "Reparto de brigadas")
  (vista ocupacion :de brigadas :etiqueta "Ocupacion de instalaciones"
                   :filas instalacion :columnas horario :muestra brigada
                   :secciones semana
                   :unica-salvo instalacion-ocupada)
  (vista por-profesor :de brigadas :etiqueta "Horario del profesor"
                      :filas horario :columnas semana :muestra brigada
                      :secciones profesor
                      :unica-salvo profesor-en-dos-brigadas)
  (vista locales :de instalaciones :etiqueta "Instalaciones")
  (vista casillas :de franja :etiqueta "Brigadas por horario")
  (vista declaraciones :de anos :etiqueta "Anos de carrera"))

;;; Datos de ejemplo. Los problemas puestos a proposito:
;;;
;;;   - C211 (22 personas) en la Piscina, que es para 20: instalacion pequena.
;;;   - M21 y C212 en la Pista 2, semana impar, 11 a.m.: instalacion ocupada.
;;;   - F11 a las 10 a.m., que su ano no tiene: horario no disponible. Y su
;;;     profesor, Alvarez, ya tiene a C111 a esa hora: profesor en dos
;;;     brigadas.
;;;   - F21 sin horario ni instalacion: sin clase.
;;;   - La Pista 2 tiene tres brigadas y el Gimnasio una; la semana par a las
;;;     10 a.m. tiene tres y la par a las 3 p.m., ninguna: desequilibrios.
(defparameter datos-del-seder
  (let ((n (lambda (s) (nucleo:nombrar s))))
    (flet ((fila (&rest pares)
             (loop for (campo valor) on pares by #'cddr
                   collect (cons (funcall n campo) valor))))
      (list
       (cons (funcall n "instalaciones")
             (loop for (nombre capacidad) in '(("Pista 1" 40) ("Pista 2" 30)
                                               ("Gimnasio" 25) ("Piscina" 20))
                   collect (fila "nombre" nombre "capacidad" capacidad)))
       (cons (funcall n "anos")
             (loop for (id carrera semana)
                     in '(("CC-1"  "Ciencia de la Computacion" "par")
                          ("CC-2"  "Ciencia de la Computacion" "impar")
                          ("MAT-1" "Matematica"                "par")
                          ("MAT-2" "Matematica"                "impar")
                          ("FIS-1" "Fisica"                    "par")
                          ("FIS-2" "Fisica"                    "par"))
                   collect (fila "id" id "carrera" carrera "semana" semana)))
       (cons (funcall n "disponibles")
             (loop for (ano . horarios)
                     in '(("CC-1"  "10 a.m." "11 a.m.")
                          ("CC-2"  "11 a.m." "3 p.m.")
                          ("MAT-1" "10 a.m.")
                          ("MAT-2" "10 a.m." "11 a.m." "3 p.m.")
                          ("FIS-1" "11 a.m." "3 p.m.")
                          ("FIS-2" "3 p.m."))
                   append (loop for horario in horarios
                                collect (fila "clave" (format nil "~a#~a" ano horario)
                                              "ano" ano "horario" horario))))
       (cons (funcall n "brigadas")
             (loop for (brigada ano personas profesor horario instalacion)
                     in '(("C111" "CC-1"  28 "Prof. Alvarez" "10 a.m." "Pista 1")
                          ("C112" "CC-1"  25 "Prof. Alvarez" "11 a.m." "Gimnasio")
                          ("C211" "CC-2"  22 "Prof. Benitez" "3 p.m."  "Piscina")
                          ("C212" "CC-2"  20 "Prof. Benitez" "11 a.m." "Pista 2")
                          ("M11"  "MAT-1" 30 "Prof. Castro"  "10 a.m." "Pista 2")
                          ("M21"  "MAT-2" 18 "Prof. Castro"  "11 a.m." "Pista 2")
                          ("F11"  "FIS-1" 15 "Prof. Alvarez" "10 a.m." "Piscina")
                          ("F21"  "FIS-2" 12 "Prof. Diaz"    ""        ""))
                   collect (fila "brigada" brigada "ano" ano "personas" personas
                                 "profesor" profesor "horario" horario
                                 "instalacion" instalacion)))
       (cons (funcall n "franja")
             (loop for semana in '("par" "impar")
                   append (loop for horario in '("10 a.m." "11 a.m." "3 p.m.")
                                collect (fila "semana" semana "horario" horario)))))))
  "Ocho brigadas de tres carreras, con un problema puesto por cada regla.")
