;;;; Un torneo de eliminacion directa: octavos, cuartos, semifinal y final.
;;;;
;;;; EXPLORACION. No forma parte del sistema. Se escribe para medir hasta
;;;; donde llega el lenguaje tal como esta, sin modificarlo.
;;;;
;;;; La forma del problema NO es una coleccion de filas homogeneas: es un
;;;; arbol. Cada partido de una ronda recibe a los ganadores de dos partidos
;;;; de la ronda anterior, asi que hay una dependencia entre filas que va
;;;; hacia adelante y en cascada, con tantos niveles como rondas.
;;;;
;;;; Se prueban dos formas de meterlo en el modelo:
;;;;
;;;;   VARIANTE A  una sola coleccion PARTIDOS, con dos campos fijos que
;;;;               dicen de que partido viene cada equipo, y una busqueda por
;;;;               clave SOBRE LA PROPIA COLECCION para traer el ganador.
;;;;               Es la traduccion natural del cuadro.
;;;;
;;;;   VARIANTE B  una coleccion por ronda. El arbol se desenrolla en cuatro
;;;;               niveles escritos a mano y cada nivel mira al anterior.
;;;;               Deja de ser recursivo, pero el numero de rondas queda
;;;;               cocido en la descripcion.

(defpackage #:situacion.exploracion.torneo
  (:use #:common-lisp #:situacion.lenguaje))

(in-package #:situacion.exploracion.torneo)

;;; ---------------------------------------------------------------------
;;; VARIANTE A. Una sola coleccion, con la busqueda sobre si misma.
;;; ---------------------------------------------------------------------

(defsituacion torneo (:etiqueta "Torneo de eliminacion directa")

  (coleccion partidos
    (:etiqueta "Partidos")
    (:clave id)
    (:orden id)
    (campo id         :rol fijo :tipo entero :etiqueta "#")
    (campo ronda      :rol fijo :etiqueta "Ronda")
    ;; De que partido viene cada equipo. 0 significa "de ninguno": es un
    ;; partido de la primera ronda y el equipo viene sembrado.
    (campo viene-a    :rol fijo :tipo entero :etiqueta "A viene de")
    (campo viene-b    :rol fijo :tipo entero :etiqueta "B viene de")
    (campo sembrado-a :rol fijo :etiqueta "Sembrado A")
    (campo sembrado-b :rol fijo :etiqueta "Sembrado B")

    ;; Lo unico que se escribe a mano.
    (campo goles-a :rol entrada :tipo entero :etiqueta "Goles A")
    (campo goles-b :rol entrada :tipo entero :etiqueta "Goles B")

    ;; El equipo que juega: o esta sembrado, o es el ganador del partido del
    ;; que viene. Esto es la arista del arbol, escrita como busqueda por
    ;; clave sobre la propia coleccion.
    (campo equipo-a :rol derivado :etiqueta "Equipo A"
           (si (= (de fila viene-a) 0)
               (de fila sembrado-a)
               (el ganador de (la-fila-de partidos
                                :donde (= id (de fila viene-a)))
                   :si-no "")))
    (campo equipo-b :rol derivado :etiqueta "Equipo B"
           (si (= (de fila viene-b) 0)
               (de fila sembrado-b)
               (el ganador de (la-fila-de partidos
                                :donde (= id (de fila viene-b)))
                   :si-no "")))

    ;; El ganador. Depende de los dos campos de arriba, que a su vez dependen
    ;; del ganador de otras filas: la cascada.
    (campo ganador :rol derivado :etiqueta "Ganador"
           (si (o (vacio? (de fila goles-a)) (vacio? (de fila goles-b)))
               ""
               (si (> (de fila goles-a) (de fila goles-b))
                   (de fila equipo-a)
                   (de fila equipo-b))))

    (:datos ((1  "octavos"   0 0 "Alemania"  "Escocia")
             (2  "octavos"   0 0 "Hungria"   "Suiza")
             (3  "octavos"   0 0 "Espana"    "Croacia")
             (4  "octavos"   0 0 "Italia"    "Albania")
             (5  "octavos"   0 0 "Polonia"   "Paises Bajos")
             (6  "octavos"   0 0 "Eslovenia" "Dinamarca")
             (7  "octavos"   0 0 "Serbia"    "Inglaterra")
             (8  "octavos"   0 0 "Rumania"   "Ucrania")
             (9  "cuartos"   1 2 "" "")
             (10 "cuartos"   3 4 "" "")
             (11 "cuartos"   5 6 "" "")
             (12 "cuartos"   7 8 "" "")
             (13 "semifinal" 9 10 "" "")
             (14 "semifinal" 11 12 "" "")
             (15 "final"     13 14 "" ""))))

  ;; En una eliminatoria el empate no es un resultado posible.
  (marca empate
    :en partidos
    :cuando    (y (no (vacio? (de fila goles-a)))
                  (no (vacio? (de fila goles-b)))
                  (= (de fila goles-a) (de fila goles-b)))
    :sobre     (goles-a goles-b)
    :severidad problema
    :explica   "En eliminatoria no puede haber empate")

  ;; Hay resultado escrito pero todavia no se sabe quien juega.
  (marca resultado-antes-de-tiempo
    :en partidos
    :cuando    (y (no (vacio? (de fila goles-a)))
                  (o (vacio? (de fila equipo-a)) (vacio? (de fila equipo-b))))
    :sobre     (equipo-a equipo-b goles-a goles-b)
    :severidad problema
    :explica   "Hay resultado escrito y todavia no se sabe quien juega")

  ;; Ya se sabe quien juega y falta el resultado.
  (marca pendiente
    :en partidos
    :cuando    (y (no (vacio? (de fila equipo-a)))
                  (no (vacio? (de fila equipo-b)))
                  (vacio? (de fila goles-a)))
    :sobre     (goles-a goles-b)
    :severidad informativa
    :explica   "Falta jugarlo")

  ;; Un equipo no puede aparecer dos veces en la misma ronda.
  (marca equipo-repetido-en-la-ronda
    :en partidos
    :cuando    (existe otro :en partidos
                 :distinta-de fila
                 :donde (y (= (de otro ronda) (de fila ronda))
                           (comparten otro fila (equipo-a equipo-b))))
    :sobre     (equipo-a equipo-b)
    :severidad problema
    :explica   "Este equipo ya esta en otro partido de la misma ronda")

  (vista cuadro :de partidos :entrada t
                :etiqueta "Cuadro del torneo"
                :agrupada-por ronda))

(defun n (s) (intern (string-upcase s) '#:situacion.nucleo))

(defparameter datos-del-torneo
  (list (cons (n "partidos")
              (loop for (id ronda va vb sa sb ga gb)
                      in '((1  "octavos"   0 0 "Alemania"  "Escocia"       2 0)
                           (2  "octavos"   0 0 "Hungria"   "Suiza"         1 3)
                           (3  "octavos"   0 0 "Espana"    "Croacia"       3 0)
                           (4  "octavos"   0 0 "Italia"    "Albania"       2 1)
                           (5  "octavos"   0 0 "Polonia"   "Paises Bajos"  1 2)
                           (6  "octavos"   0 0 "Eslovenia" "Dinamarca"     0 1)
                           (7  "octavos"   0 0 "Serbia"    "Inglaterra"    0 1)
                           (8  "octavos"   0 0 "Rumania"   "Ucrania"       3 0)
                           (9  "cuartos"   1 2  "" ""                      2 1)
                           (10 "cuartos"   3 4  "" ""                      2 1)
                           (11 "cuartos"   5 6  "" ""                      2 0)
                           (12 "cuartos"   7 8  "" ""                      1 0)
                           (13 "semifinal" 9 10 "" ""                      1 2)
                           (14 "semifinal" 11 12 "" ""                     2 1)
                           (15 "final"     13 14 "" ""                     nil nil))
                    collect (list (cons (n "id") id)
                                  (cons (n "ronda") ronda)
                                  (cons (n "viene-a") va)
                                  (cons (n "viene-b") vb)
                                  (cons (n "sembrado-a") sa)
                                  (cons (n "sembrado-b") sb)
                                  (cons (n "goles-a") ga)
                                  (cons (n "goles-b") gb)))))
  "Un cuadro de dieciseis con todo jugado menos la final.")

;;; ---------------------------------------------------------------------
;;; Informe de la exploracion
;;; ---------------------------------------------------------------------

(defun separador (titulo)
  (format t "~&~%~a~%~a~%~a~%"
          (make-string 70 :initial-element #\=) titulo
          (make-string 70 :initial-element #\=)))

(defun mostrar-analisis (situacion)
  (let ((problemas (situacion.analisis:comprobar-situacion situacion)))
    (if problemas
        (format t "~&Analisis: ~d problema(s)~%~a"
                (length problemas)
                (situacion.analisis:informe-de-problemas problemas))
        (format t "~&Analisis: sin problemas.~%"))
    problemas))

(defun mostrar-evaluacion (situacion datos campos)
  "Imprime, coleccion por coleccion, los CAMPOS pedidos y las marcas."
  (handler-case
      (let ((resultado (nucleo:evaluar-situacion situacion datos)))
        (loop for (coleccion . filas) in resultado
              do (format t "~&~%-- ~(~a~) --~%" coleccion)
                 (dolist (fila filas)
                   (format t "  ~{~a~^ | ~}~@[   [~{~(~a~)~^, ~}]~]~%"
                           (loop for c in campos
                                 for par = (assoc (n (string c)) (car fila))
                                 collect (format nil "~a=~a" (string-downcase c)
                                                 (cdr par)))
                           (cdr fila))))
        resultado)
    (error (e) (format t "~&ERROR AL EVALUAR: ~a~%" e) nil)))

(separador "VARIANTE A. Una coleccion, busqueda sobre si misma.")
(mostrar-analisis torneo)
(mostrar-evaluacion torneo datos-del-torneo
                    '("id" "ronda" "equipo-a" "equipo-b" "goles-a" "goles-b"
                      "ganador"))

(separador "VARIANTE A. Materializacion en las tres arquitecturas.")
(handler-case
    (situacion.demostracion:generar torneo datos-del-torneo "torneo-a")
  (error (e) (format t "~&ERROR AL MATERIALIZAR: ~a~%" e)))

;;; ---------------------------------------------------------------------
;;; VARIANTE A2. La misma descripcion, con el cuadro numerado como se numera
;;; un cuadro de verdad: la final es el 1, las semifinales la 2 y la 3, los
;;; cuartos del 4 al 7 y los octavos del 8 al 15.
;;;
;;; No cambia ni una linea de la descripcion. Cambia solo el orden en que las
;;; filas caen en el documento, y con el la direccion de las dependencias:
;;; ahora cada partido mira HACIA ABAJO en vez de hacia arriba.
;;; ---------------------------------------------------------------------

(defparameter datos-del-cuadro-numerado
  (list (cons (n "partidos")
              (loop for (id ronda va vb sa sb ga gb)
                      in '((1  "final"     2 3 "" ""                       nil nil)
                           (2  "semifinal" 4 5 "" ""                       1 2)
                           (3  "semifinal" 6 7 "" ""                       2 1)
                           (4  "cuartos"   8 9 "" ""                       2 1)
                           (5  "cuartos"   10 11 "" ""                     2 1)
                           (6  "cuartos"   12 13 "" ""                     2 0)
                           (7  "cuartos"   14 15 "" ""                     1 0)
                           (8  "octavos"   0 0 "Alemania"  "Escocia"       2 0)
                           (9  "octavos"   0 0 "Hungria"   "Suiza"         1 3)
                           (10 "octavos"   0 0 "Espana"    "Croacia"       3 0)
                           (11 "octavos"   0 0 "Italia"    "Albania"       2 1)
                           (12 "octavos"   0 0 "Polonia"   "Paises Bajos"  1 2)
                           (13 "octavos"   0 0 "Eslovenia" "Dinamarca"     0 1)
                           (14 "octavos"   0 0 "Serbia"    "Inglaterra"    0 1)
                           (15 "octavos"   0 0 "Rumania"   "Ucrania"       3 0))
                    collect (list (cons (n "id") id)
                                  (cons (n "ronda") ronda)
                                  (cons (n "viene-a") va)
                                  (cons (n "viene-b") vb)
                                  (cons (n "sembrado-a") sa)
                                  (cons (n "sembrado-b") sb)
                                  (cons (n "goles-a") ga)
                                  (cons (n "goles-b") gb)))))
  "El mismo torneo, con la numeracion canonica de un cuadro.")

(separador "VARIANTE A2. El mismo cuadro numerado al reves.")
(mostrar-evaluacion torneo datos-del-cuadro-numerado
                    '("id" "ronda" "equipo-a" "equipo-b" "ganador"))
(handler-case
    (situacion.demostracion:generar torneo datos-del-cuadro-numerado "torneo-a2")
  (error (e) (format t "~&ERROR AL MATERIALIZAR: ~a~%" e)))

;;; ---------------------------------------------------------------------
;;; PRUEBA 1. Se puede CALCULAR a que partido pasa el ganador?
;;;
;;; Con la numeracion canonica de un cuadro, el partido al que pasa el
;;; ganador del partido i es el i dividido entre dos, redondeando hacia
;;; abajo. Es la relacion que convierte el cuadro en un arbol de verdad:
;;; si se pudiera calcular, no haria falta escribir a mano de que partido
;;; viene cada equipo.
;;;
;;; El algebra tiene + - * / = /= < <= > >= Y O NO. No tiene parte entera,
;;; ni resto, ni redondeo. Se prueba que pasa.
;;; ---------------------------------------------------------------------

(defsituacion aritmetica-de-claves (:etiqueta "Se puede calcular el padre?")
  (coleccion nodos
    (:etiqueta "Nodos")
    (:clave id)
    (campo id     :rol fijo :tipo entero :etiqueta "#")
    (campo padre  :rol derivado :tipo entero :etiqueta "Padre = id/2"
           (/ (de fila id) 2))
    (:datos ((1) (2) (3))))
  (vista n :de nodos :entrada t))

(defparameter datos-aritmetica
  (list (cons (n "nodos")
              (loop for i in '(1 2 3 4 5 6 7)
                    collect (list (cons (n "id") i))))))

(separador "PRUEBA 1. Aritmetica sobre la clave: calcular el partido padre.")
(mostrar-analisis aritmetica-de-claves)
(mostrar-evaluacion aritmetica-de-claves datos-aritmetica '("id" "padre"))

;;; ---------------------------------------------------------------------
;;; PRUEBA 2. La marca de cuantificacion sobre campos DERIVADOS.
;;;
;;; "Este equipo ya esta en otro partido de la misma ronda" recorre la
;;; coleccion comparando equipo-a y equipo-b, que son derivados de una
;;; busqueda. Se fuerza el caso con un cuadro mal sembrado.
;;; ---------------------------------------------------------------------

(defparameter datos-con-equipo-repetido
  (list (cons (n "partidos")
              (loop for (id ronda va vb sa sb ga gb)
                      in '((1  "octavos"   0 0 "Alemania"  "Escocia"       2 0)
                           (2  "octavos"   0 0 "Hungria"   "Alemania"      1 3)
                           (3  "octavos"   0 0 "Espana"    "Croacia"       3 0)
                           (4  "octavos"   0 0 "Italia"    "Albania"       2 1)
                           (5  "octavos"   0 0 "Polonia"   "Paises Bajos"  1 2)
                           (6  "octavos"   0 0 "Eslovenia" "Dinamarca"     0 1)
                           (7  "octavos"   0 0 "Serbia"    "Inglaterra"    0 1)
                           (8  "octavos"   0 0 "Rumania"   "Ucrania"       3 0)
                           (9  "cuartos"   1 2  "" ""                      2 2)
                           (10 "cuartos"   3 4  "" ""                      2 1)
                           (11 "cuartos"   5 6  "" ""                      2 0)
                           (12 "cuartos"   7 8  "" ""                      1 0)
                           (13 "semifinal" 9 10 "" ""                      1 2)
                           (14 "semifinal" 11 12 "" ""                     2 1)
                           (15 "final"     13 14 "" ""                     3 0))
                    collect (list (cons (n "id") id)
                                  (cons (n "ronda") ronda)
                                  (cons (n "viene-a") va)
                                  (cons (n "viene-b") vb)
                                  (cons (n "sembrado-a") sa)
                                  (cons (n "sembrado-b") sb)
                                  (cons (n "goles-a") ga)
                                  (cons (n "goles-b") gb)))))
  "Alemania sembrada en dos octavos, y un empate en cuartos.")

(separador "PRUEBA 2. Marcas: equipo repetido, empate, resultado antes de tiempo.")
(mostrar-evaluacion torneo datos-con-equipo-repetido
                    '("id" "ronda" "equipo-a" "equipo-b" "goles-a" "goles-b"))
(handler-case
    (situacion.demostracion:generar torneo datos-con-equipo-repetido "torneo-marcas")
  (error (e) (format t "~&ERROR AL MATERIALIZAR: ~a~%" e)))

;;; ---------------------------------------------------------------------
;;; PRUEBA 3. El cuadro recien sorteado, sin ningun resultado.
;;;
;;; Es el estado en que se imprime el documento el primer dia. Todos los
;;; equipos de cuartos en adelante estan sin decidir, o sea vacios.
;;; ---------------------------------------------------------------------

(defparameter datos-sin-jugar
  (list (cons (n "partidos")
              (loop for (id ronda va vb sa sb)
                      in '((1  "octavos"   0 0 "Alemania"  "Escocia")
                           (2  "octavos"   0 0 "Hungria"   "Suiza")
                           (3  "octavos"   0 0 "Espana"    "Croacia")
                           (4  "octavos"   0 0 "Italia"    "Albania")
                           (5  "octavos"   0 0 "Polonia"   "Paises Bajos")
                           (6  "octavos"   0 0 "Eslovenia" "Dinamarca")
                           (7  "octavos"   0 0 "Serbia"    "Inglaterra")
                           (8  "octavos"   0 0 "Rumania"   "Ucrania")
                           (9  "cuartos"   1 2 "" "")
                           (10 "cuartos"   3 4 "" "")
                           (11 "cuartos"   5 6 "" "")
                           (12 "cuartos"   7 8 "" "")
                           (13 "semifinal" 9 10 "" "")
                           (14 "semifinal" 11 12 "" "")
                           (15 "final"     13 14 "" ""))
                    collect (list (cons (n "id") id)
                                  (cons (n "ronda") ronda)
                                  (cons (n "viene-a") va)
                                  (cons (n "viene-b") vb)
                                  (cons (n "sembrado-a") sa)
                                  (cons (n "sembrado-b") sb)))))
  "El cuadro tal como se imprime el primer dia: sorteado y sin jugar.")

(separador "PRUEBA 3. El cuadro sin jugar.")
(mostrar-evaluacion torneo datos-sin-jugar '("id" "ronda" "equipo-a" "equipo-b"))
(handler-case
    (situacion.demostracion:generar torneo datos-sin-jugar "torneo-sin-jugar")
  (error (e) (format t "~&ERROR AL MATERIALIZAR: ~a~%" e)))

;;; ---------------------------------------------------------------------
;;; PRUEBA 4. Una marca que vale para varias colecciones.
;;;
;;; En la variante B hay una coleccion por ronda, y "en eliminatoria no puede
;;; haber empate" es la misma regla en las cuatro. Se intenta escribirla una
;;; sola vez.
;;; ---------------------------------------------------------------------

(separador "PRUEBA 4. Una misma marca para varias colecciones.")
(handler-case
    (progn
      (eval (read-from-string "
        (situacion.lenguaje:defsituacion una-marca-para-varias (:etiqueta \"x\")
          (coleccion octavos (:clave id)
            (campo id :rol fijo :tipo entero)
            (campo goles-a :rol entrada :tipo entero)
            (campo goles-b :rol entrada :tipo entero))
          (coleccion cuartos (:clave id)
            (campo id :rol fijo :tipo entero)
            (campo goles-a :rol entrada :tipo entero)
            (campo goles-b :rol entrada :tipo entero))
          (marca empate
            :cuando    (= (de fila goles-a) (de fila goles-b))
            :sobre     (goles-a goles-b)
            :severidad problema)
          (vista v :de octavos :entrada t))"))
      (mostrar-analisis (situacion.lenguaje:situacion-llamada "UNA-MARCA-PARA-VARIAS")))
  (error (e) (format t "~&ERROR: ~a~%" e)))

;;; ---------------------------------------------------------------------
;;; VARIANTE B. Una coleccion por ronda.
;;;
;;; El arbol se desenrolla a mano: cuatro colecciones, cada una mirando a la
;;; anterior. Ya no hay busqueda sobre la propia coleccion, asi que cada
;;; dependencia cruza de una hoja a otra. A cambio:
;;;
;;;   - el numero de rondas queda cocido en la descripcion;
;;;   - la regla del empate hay que escribirla cuatro veces;
;;;   - y no hay forma de preguntar nada sobre "todos los partidos".
;;; ---------------------------------------------------------------------

(defsituacion torneo-por-rondas (:etiqueta "Torneo, una coleccion por ronda")

  (coleccion octavos
    (:etiqueta "Octavos") (:clave id) (:orden id)
    (campo id       :rol fijo :tipo entero :etiqueta "#")
    (campo equipo-a :rol fijo :etiqueta "Equipo A")
    (campo equipo-b :rol fijo :etiqueta "Equipo B")
    (campo goles-a  :rol entrada :tipo entero :etiqueta "Goles A")
    (campo goles-b  :rol entrada :tipo entero :etiqueta "Goles B")
    (campo ganador  :rol derivado :etiqueta "Ganador"
           (si (o (vacio? (de fila goles-a)) (vacio? (de fila goles-b))) ""
               (si (> (de fila goles-a) (de fila goles-b))
                   (de fila equipo-a) (de fila equipo-b))))
    (:datos ((1 "Alemania" "Escocia") (2 "Hungria" "Suiza")
             (3 "Espana" "Croacia")   (4 "Italia" "Albania")
             (5 "Polonia" "Paises Bajos") (6 "Eslovenia" "Dinamarca")
             (7 "Serbia" "Inglaterra") (8 "Rumania" "Ucrania"))))

  (coleccion cuartos
    (:etiqueta "Cuartos") (:clave id) (:orden id)
    (campo id      :rol fijo :tipo entero :etiqueta "#")
    (campo viene-a :rol fijo :tipo entero :etiqueta "A viene de")
    (campo viene-b :rol fijo :tipo entero :etiqueta "B viene de")
    (campo goles-a :rol entrada :tipo entero :etiqueta "Goles A")
    (campo goles-b :rol entrada :tipo entero :etiqueta "Goles B")
    (campo equipo-a :rol derivado :etiqueta "Equipo A"
           (el ganador de (la-fila-de octavos :donde (= id (de fila viene-a))) :si-no ""))
    (campo equipo-b :rol derivado :etiqueta "Equipo B"
           (el ganador de (la-fila-de octavos :donde (= id (de fila viene-b))) :si-no ""))
    (campo ganador :rol derivado :etiqueta "Ganador"
           (si (o (vacio? (de fila goles-a)) (vacio? (de fila goles-b))) ""
               (si (> (de fila goles-a) (de fila goles-b))
                   (de fila equipo-a) (de fila equipo-b))))
    (:datos ((1 1 2) (2 3 4) (3 5 6) (4 7 8))))

  (coleccion semifinales
    (:etiqueta "Semifinales") (:clave id) (:orden id)
    (campo id      :rol fijo :tipo entero :etiqueta "#")
    (campo viene-a :rol fijo :tipo entero :etiqueta "A viene de")
    (campo viene-b :rol fijo :tipo entero :etiqueta "B viene de")
    (campo goles-a :rol entrada :tipo entero :etiqueta "Goles A")
    (campo goles-b :rol entrada :tipo entero :etiqueta "Goles B")
    (campo equipo-a :rol derivado :etiqueta "Equipo A"
           (el ganador de (la-fila-de cuartos :donde (= id (de fila viene-a))) :si-no ""))
    (campo equipo-b :rol derivado :etiqueta "Equipo B"
           (el ganador de (la-fila-de cuartos :donde (= id (de fila viene-b))) :si-no ""))
    (campo ganador :rol derivado :etiqueta "Ganador"
           (si (o (vacio? (de fila goles-a)) (vacio? (de fila goles-b))) ""
               (si (> (de fila goles-a) (de fila goles-b))
                   (de fila equipo-a) (de fila equipo-b))))
    (:datos ((1 1 2) (2 3 4))))

  (coleccion finalisima
    (:etiqueta "Final") (:clave id) (:orden id)
    (campo id      :rol fijo :tipo entero :etiqueta "#")
    (campo viene-a :rol fijo :tipo entero :etiqueta "A viene de")
    (campo viene-b :rol fijo :tipo entero :etiqueta "B viene de")
    (campo goles-a :rol entrada :tipo entero :etiqueta "Goles A")
    (campo goles-b :rol entrada :tipo entero :etiqueta "Goles B")
    (campo equipo-a :rol derivado :etiqueta "Equipo A"
           (el ganador de (la-fila-de semifinales :donde (= id (de fila viene-a))) :si-no ""))
    (campo equipo-b :rol derivado :etiqueta "Equipo B"
           (el ganador de (la-fila-de semifinales :donde (= id (de fila viene-b))) :si-no ""))
    (campo ganador :rol derivado :etiqueta "Campeon"
           (si (o (vacio? (de fila goles-a)) (vacio? (de fila goles-b))) ""
               (si (> (de fila goles-a) (de fila goles-b))
                   (de fila equipo-a) (de fila equipo-b))))
    (:datos ((1 1 2))))

  ;; La misma regla, cuatro veces. No hay forma de escribirla una sola.
  (marca empate-en-octavos :en octavos
    :cuando (y (no (vacio? (de fila goles-a))) (= (de fila goles-a) (de fila goles-b)))
    :sobre (goles-a goles-b) :severidad problema
    :explica "En eliminatoria no puede haber empate")
  (marca empate-en-cuartos :en cuartos
    :cuando (y (no (vacio? (de fila goles-a))) (= (de fila goles-a) (de fila goles-b)))
    :sobre (goles-a goles-b) :severidad problema
    :explica "En eliminatoria no puede haber empate")
  (marca empate-en-semifinales :en semifinales
    :cuando (y (no (vacio? (de fila goles-a))) (= (de fila goles-a) (de fila goles-b)))
    :sobre (goles-a goles-b) :severidad problema
    :explica "En eliminatoria no puede haber empate")
  (marca empate-en-la-final :en finalisima
    :cuando (y (no (vacio? (de fila goles-a))) (= (de fila goles-a) (de fila goles-b)))
    :sobre (goles-a goles-b) :severidad problema
    :explica "En eliminatoria no puede haber empate")

  (vista llaves :de octavos :entrada t :etiqueta "Octavos de final")
  (vista c :de cuartos :etiqueta "Cuartos")
  (vista s :de semifinales :etiqueta "Semifinales")
  (vista f :de finalisima :etiqueta "Final"))

(defun rondas-datos (nombre filas campos)
  (cons (n nombre)
        (loop for valores in filas
              collect (loop for c in campos for v in valores
                            collect (cons (n c) v)))))

(defparameter datos-por-rondas
  (list (rondas-datos "octavos"
          '((1 "Alemania" "Escocia" 2 0) (2 "Hungria" "Suiza" 1 3)
            (3 "Espana" "Croacia" 3 0)   (4 "Italia" "Albania" 2 1)
            (5 "Polonia" "Paises Bajos" 1 2) (6 "Eslovenia" "Dinamarca" 0 1)
            (7 "Serbia" "Inglaterra" 0 1) (8 "Rumania" "Ucrania" 3 0))
          '("id" "equipo-a" "equipo-b" "goles-a" "goles-b"))
        (rondas-datos "cuartos"
          '((1 1 2 2 1) (2 3 4 2 1) (3 5 6 2 0) (4 7 8 1 0))
          '("id" "viene-a" "viene-b" "goles-a" "goles-b"))
        (rondas-datos "semifinales"
          '((1 1 2 1 2) (2 3 4 2 1))
          '("id" "viene-a" "viene-b" "goles-a" "goles-b"))
        (rondas-datos "finalisima"
          '((1 1 2 nil nil))
          '("id" "viene-a" "viene-b" "goles-a" "goles-b"))))

(separador "VARIANTE B. Una coleccion por ronda.")
(mostrar-analisis torneo-por-rondas)
(mostrar-evaluacion torneo-por-rondas datos-por-rondas
                    '("id" "equipo-a" "equipo-b" "goles-a" "goles-b" "ganador"))
(handler-case
    (situacion.demostracion:generar torneo-por-rondas datos-por-rondas "torneo-b")
  (error (e) (format t "~&ERROR AL MATERIALIZAR: ~a~%" e)))

;;; ---------------------------------------------------------------------
;;; PRUEBA 5. Cuantos niveles aguanta.
;;;
;;; Un cuadro de 64 equipos: 63 partidos y SEIS niveles de cascada. Misma
;;; descripcion que la variante A, solo que mas honda.
;;; ---------------------------------------------------------------------

(defparameter +comienzos+ '(1 33 49 57 61 63)
  "El id con que empieza cada una de las seis rondas.")

(defparameter +nombres-de-ronda+
  '("1-32avos" "2-16avos" "3-octavos" "4-cuartos" "5-semifinal" "6-final"))

(defun cuadro-de-64 ()
  "Las filas fijas: id, ronda, de que partido viene cada equipo y sembrados."
  (let ((filas '()))
    (loop for ronda from 1 to 6
          for comienzo in +comienzos+
          for nombre in +nombres-de-ronda+
          for cuantos = (expt 2 (- 6 ronda))
          do (loop for j from 0 below cuantos
                   for id = (+ comienzo j)
                   do (push (if (= ronda 1)
                                (list id nombre 0 0
                                      (format nil "E~2,'0d" (1+ (* 2 j)))
                                      (format nil "E~2,'0d" (+ 2 (* 2 j))))
                                (let ((anterior (nth (- ronda 2) +comienzos+)))
                                  (list id nombre
                                        (+ anterior (* 2 j)) (+ anterior (* 2 j) 1)
                                        "" "")))
                            filas)))
    (nreverse filas)))

(defsituacion torneo-de-64 (:etiqueta "Torneo de 64 equipos, seis rondas")
  (coleccion partidos
    (:etiqueta "Partidos") (:clave id) (:orden id)
    (campo id         :rol fijo :tipo entero :etiqueta "#")
    (campo ronda      :rol fijo :etiqueta "Ronda")
    (campo viene-a    :rol fijo :tipo entero :etiqueta "A viene de")
    (campo viene-b    :rol fijo :tipo entero :etiqueta "B viene de")
    (campo sembrado-a :rol fijo :etiqueta "Sembrado A")
    (campo sembrado-b :rol fijo :etiqueta "Sembrado B")
    (campo goles-a :rol entrada :tipo entero :etiqueta "Goles A")
    (campo goles-b :rol entrada :tipo entero :etiqueta "Goles B")
    (campo equipo-a :rol derivado :etiqueta "Equipo A"
           (si (= (de fila viene-a) 0) (de fila sembrado-a)
               (el ganador de (la-fila-de partidos :donde (= id (de fila viene-a)))
                   :si-no "")))
    (campo equipo-b :rol derivado :etiqueta "Equipo B"
           (si (= (de fila viene-b) 0) (de fila sembrado-b)
               (el ganador de (la-fila-de partidos :donde (= id (de fila viene-b)))
                   :si-no "")))
    (campo ganador :rol derivado :etiqueta "Ganador"
           (si (o (vacio? (de fila goles-a)) (vacio? (de fila goles-b))) ""
               (si (> (de fila goles-a) (de fila goles-b))
                   (de fila equipo-a) (de fila equipo-b))))
    (:datos #.(cuadro-de-64)))
  (marca pendiente :en partidos
    :cuando (y (no (vacio? (de fila equipo-a))) (vacio? (de fila goles-a)))
    :sobre (goles-a goles-b) :severidad informativa :explica "Falta jugarlo")
  (vista cuadro :de partidos :entrada t :etiqueta "Cuadro de 64"))

(defparameter datos-de-64
  (list (cons (n "partidos")
              (loop for (id ronda va vb sa sb) in (cuadro-de-64)
                    collect (list (cons (n "id") id) (cons (n "ronda") ronda)
                                  (cons (n "viene-a") va) (cons (n "viene-b") vb)
                                  (cons (n "sembrado-a") sa) (cons (n "sembrado-b") sb)
                                  ;; Gana siempre el equipo A: el campeon
                                  ;; tiene que salir E01 si la cascada de seis
                                  ;; niveles funciona.
                                  (cons (n "goles-a") 1) (cons (n "goles-b") 0))))))

(separador "PRUEBA 5. Cascada de seis niveles: 64 equipos, 63 partidos.")
(mostrar-analisis torneo-de-64)
(let ((r (nucleo:evaluar-situacion torneo-de-64 datos-de-64)))
  (dolist (fila (cdr (first r)))
    (let ((id (cdr (assoc (n "id") (car fila))))
          (ronda (cdr (assoc (n "ronda") (car fila))))
          (a (cdr (assoc (n "equipo-a") (car fila))))
          (b (cdr (assoc (n "equipo-b") (car fila))))
          (g (cdr (assoc (n "ganador") (car fila)))))
      (when (member id '(1 2 33 49 57 61 62 63))
        (format t "~&  id=~2d ~12a ~6a vs ~6a -> ~a~%" id ronda a b g)))))
(handler-case
    (situacion.demostracion:generar torneo-de-64 datos-de-64 "torneo-64")
  (error (e) (format t "~&ERROR AL MATERIALIZAR: ~a~%" e)))

;;; ---------------------------------------------------------------------
;;; PRUEBA 6. "El campeon es X".
;;;
;;; Es un valor UNICO de la situacion entera, no de una fila. El lenguaje no
;;; tiene valores derivados fuera de una coleccion: PARAMETRO lleva un valor
;;; literal, no una expresion. Se prueba a emularlo con una coleccion de una
;;; sola fila, y de paso se prueba un agregado con condicion no trivial.
;;; ---------------------------------------------------------------------

(defsituacion torneo-con-resumen (:etiqueta "Torneo con resumen")
  (coleccion partidos
    (:etiqueta "Partidos") (:clave id) (:orden id)
    (campo id         :rol fijo :tipo entero :etiqueta "#")
    (campo ronda      :rol fijo :etiqueta "Ronda")
    (campo viene-a    :rol fijo :tipo entero :etiqueta "A viene de")
    (campo viene-b    :rol fijo :tipo entero :etiqueta "B viene de")
    (campo sembrado-a :rol fijo :etiqueta "Sembrado A")
    (campo sembrado-b :rol fijo :etiqueta "Sembrado B")
    (campo goles-a :rol entrada :tipo entero :etiqueta "Goles A")
    (campo goles-b :rol entrada :tipo entero :etiqueta "Goles B")
    (campo equipo-a :rol derivado :etiqueta "Equipo A"
           (si (= (de fila viene-a) 0) (de fila sembrado-a)
               (el ganador de (la-fila-de partidos :donde (= id (de fila viene-a)))
                   :si-no "")))
    (campo equipo-b :rol derivado :etiqueta "Equipo B"
           (si (= (de fila viene-b) 0) (de fila sembrado-b)
               (el ganador de (la-fila-de partidos :donde (= id (de fila viene-b)))
                   :si-no "")))
    (campo ganador :rol derivado :etiqueta "Ganador"
           (si (o (vacio? (de fila goles-a)) (vacio? (de fila goles-b))) ""
               (si (> (de fila goles-a) (de fila goles-b))
                   (de fila equipo-a) (de fila equipo-b))))
    (:datos ((1  "octavos" 0 0 "a" "b"))))

  ;; Una coleccion de una sola fila haciendo de escalar.
  (coleccion resumen
    (:etiqueta "Resumen") (:clave que)
    (campo que     :rol fijo :etiqueta "Concepto")
    (campo campeon :rol derivado :etiqueta "Campeon"
           (el ganador de (la-fila-de partidos :donde (= ronda "final")) :si-no "todavia nadie"))
    (campo partidos-de-la-final :rol derivado :tipo entero :etiqueta "Partidos de la final"
           (cuantas partidos :donde (= ronda "final")))
    (campo partidos-jugados :rol derivado :tipo entero :etiqueta "Ya jugados"
           (cuantas partidos :donde (no (vacio? goles-a))))
    (:datos (("torneo"))))

  (vista cuadro :de partidos :entrada t :etiqueta "Cuadro")
  (vista r :de resumen :etiqueta "Resumen"))

(defparameter datos-con-resumen
  (append datos-del-torneo
          (list (cons (n "resumen") (list (list (cons (n "que") "torneo")))))))

(separador "PRUEBA 6. El campeon como valor unico de la situacion.")
(mostrar-analisis torneo-con-resumen)
(let ((r (nucleo:evaluar-situacion torneo-con-resumen datos-con-resumen)))
  (format t "~&resumen -> ~s~%" (car (second (assoc (n "resumen") r)))))
(format t "~&-- Y ahora el mismo resumen con el torneo terminado --~%")
(let ((r (nucleo:evaluar-situacion torneo-con-resumen
                                   (append datos-con-equipo-repetido
                                           (list (cons (n "resumen")
                                                       (list (list (cons (n "que") "torneo")))))))))
  (format t "~&resumen -> ~s~%" (car (second (assoc (n "resumen") r)))))
(format t "~&-- Materializacion --~%")
(handler-case
    (situacion.demostracion:generar torneo-con-resumen datos-con-resumen "torneo-resumen")
  (error (e) (format t "~&ERROR AL MATERIALIZAR: ~a~%" e)))

;;; ---------------------------------------------------------------------
;;; PRUEBA 7. Que significa :SI-NO cuando la fila existe pero su valor
;;; todavia no esta decidido.
;;;
;;; En un cuadro, la fila del partido SIEMPRE existe desde el sorteo; lo que
;;; no existe es su ganador. Se mira que contesta cada destino.
;;; ---------------------------------------------------------------------

(defsituacion fila-que-existe-sin-valor (:etiqueta "Fila que existe sin valor")
  (coleccion partidos
    (:etiqueta "Partidos") (:clave id) (:orden id)
    (campo id      :rol fijo :tipo entero :etiqueta "#")
    (campo goles-a :rol entrada :tipo entero :etiqueta "Goles A")
    (campo goles-b :rol entrada :tipo entero :etiqueta "Goles B")
    (campo ganador :rol derivado :etiqueta "Ganador"
           (si (vacio? (de fila goles-a)) "" "gano alguien"))
    (:datos ((1) (2))))
  (coleccion lectura
    (:etiqueta "Lectura") (:clave que)
    (campo que :rol fijo :etiqueta "Concepto")
    (campo mira-partido-1 :rol derivado :etiqueta "Ganador del 1"
           (el ganador de (la-fila-de partidos :donde (= id 1)) :si-no "TODAVIA NADIE"))
    (campo mira-partido-99 :rol derivado :etiqueta "Ganador del 99"
           (el ganador de (la-fila-de partidos :donde (= id 99)) :si-no "NO HAY TAL PARTIDO"))
    (:datos (("lectura"))))
  (vista p :de partidos :entrada t :etiqueta "Partidos")
  (vista l :de lectura :etiqueta "Lectura"))

(defparameter datos-fila-sin-valor
  (list (cons (n "partidos")
              (list (list (cons (n "id") 1) (cons (n "goles-a") nil) (cons (n "goles-b") nil))
                    (list (cons (n "id") 2) (cons (n "goles-a") 3) (cons (n "goles-b") 1))))
        (cons (n "lectura") (list (list (cons (n "que") "lectura"))))))

(separador "PRUEBA 7. La fila existe, el valor no.")
(mostrar-analisis fila-que-existe-sin-valor)
(mostrar-evaluacion fila-que-existe-sin-valor datos-fila-sin-valor
                    '("id" "que" "ganador" "mira-partido-1" "mira-partido-99"))
(handler-case
    (situacion.demostracion:generar fila-que-existe-sin-valor datos-fila-sin-valor
                                    "torneo-sinvalor")
  (error (e) (format t "~&ERROR AL MATERIALIZAR: ~a~%" e)))
