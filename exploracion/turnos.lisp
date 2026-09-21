;;;; Cuadrante de turnos de un equipo de guardia.
;;;;
;;;; ENCARGO DE EXPLORACION. No forma parte del sistema: no lo modifica, solo
;;;; lo usa. Mide el lenguaje tal como esta.
;;;;
;;;; El caso: personas, dias del mes y, para cada dia, quien hace manana,
;;;; quien tarde y quien noche. Se quiere avisar de tres cosas:
;;;;
;;;;   1. alguien hace noche y a la manana siguiente entra de manana;
;;;;   2. alguien pasa de cierto numero de turnos al mes;
;;;;   3. algun turno de algun dia queda sin cubrir.
;;;;
;;;; Se escriben las DOS representaciones y se comparan:
;;;;
;;;;   (a) CUADRANTE-PLANO   una coleccion de asignaciones (dia, turno, quien):
;;;;                         una fila por celda del cuadrante.
;;;;   (b) CUADRANTE-MATRIZ  una coleccion de dias con un campo por turno:
;;;;                         una fila por dia, tres columnas.
;;;;
;;;; Los mismos datos, las mismas tres reglas, escritas de las dos maneras.

(defpackage #:exploracion.turnos
  (:use #:common-lisp #:situacion.lenguaje)
  (:export #:informe))

(in-package #:exploracion.turnos)

;;; ====================================================================
;;; (a) UNA FILA POR CELDA DEL CUADRANTE
;;; ====================================================================

(defsituacion cuadrante-plano
    (:etiqueta "Cuadrante de guardia (una fila por celda)")

  (parametro tope-mensual :tipo entero :valor 6
             :etiqueta "Tope de turnos al mes")

  (coleccion personas
    (:etiqueta "Personas")
    (:clave nombre)
    (:crece)
    (campo nombre :rol fijo :etiqueta "Persona")
    ;; AQUI SALE NATURAL: contar los turnos de una persona en el mes es
    ;; contar filas de una sola coleccion con un solo criterio de igualdad.
    (campo turnos :rol derivado :tipo entero :etiqueta "Turnos"
           (cuantas asignaciones :donde (= persona (de fila nombre))))
    (campo margen :rol derivado :tipo entero :etiqueta "Margen"
           (- (parametro tope-mensual) (de fila turnos)))
    (:datos (("Ana") ("Bruno") ("Carla") ("Diego"))))

  (coleccion asignaciones
    (:etiqueta "Asignaciones")
    (:clave dia turno)
    ;; Solo se puede declarar UN campo de orden. El orden real del cuadrante
    ;; plano es (dia, turno); aqui se declara dia y el desempate queda al
    ;; orden en que esten escritos los datos.
    (:orden dia)
    (campo dia     :rol fijo :tipo entero :etiqueta "Dia")
    (campo turno   :rol fijo :etiqueta "Turno")
    (campo persona :rol entrada :etiqueta "Quien"
           :dominio   (los nombre de personas)
           :al-violar advertir)
    (:datos ((1 "manana") (1 "tarde") (1 "noche")
             (2 "manana") (2 "tarde") (2 "noche")
             (3 "manana") (3 "tarde") (3 "noche")
             (4 "manana") (4 "tarde") (4 "noche")
             (5 "manana") (5 "tarde") (5 "noche")
             (6 "manana") (6 "tarde") (6 "noche")
             (7 "manana") (7 "tarde") (7 "noche"))))

  ;; Los dias, solo para poder decir algo del DIA y no de la celda.
  (coleccion dias
    (:etiqueta "Dias")
    (:clave dia)
    (:orden dia)
    (campo dia :rol fijo :tipo entero :etiqueta "Dia")
    ;; Dos criterios a la vez: el dia y que este escrito.
    (campo cubiertos :rol derivado :tipo entero :etiqueta "Cubiertos"
           (cuantas asignaciones :donde (y (= dia (de fila dia))
                                           (no (vacio? persona)))))
    (:datos ((1) (2) (3) (4) (5) (6) (7))))

  ;; REGLA 1. Noche y manana siguiente.
  ;; No hace falta ningun vecino: el dia siguiente se dice sumando uno al dia,
  ;; que es lo que significa en el dominio.
  (marca noche-y-manana-siguiente
    :en asignaciones
    :cuando (y (= (de fila turno) "noche")
               (no (vacio? (de fila persona)))
               (existe otra :en asignaciones
                 :donde (y (= (de otra turno) "manana")
                           (= (de otra dia) (+ (de fila dia) 1))
                           (= (de otra persona) (de fila persona)))))
    :sobre     (persona)
    :severidad problema
    :explica   "Sale de noche y entra a la manana siguiente")

  ;; REGLA 3, a nivel de celda.
  (marca sin-cubrir
    :en asignaciones
    :cuando    (vacio? (de fila persona))
    :sobre     (persona)
    :severidad advertencia
    :explica   "Este turno no tiene quien lo haga")

  ;; Doblete el mismo dia, que es la colision clasica del corpus.
  (marca doble-turno-el-mismo-dia
    :en asignaciones
    :cuando (y (no (vacio? (de fila persona)))
               (existe otra :en asignaciones
                 :distinta-de fila
                 :donde (y (= (de otra dia) (de fila dia))
                           (= (de otra persona) (de fila persona)))))
    :sobre     (persona)
    :severidad problema
    :explica   "Esta persona ya tiene otro turno ese dia")

  ;; REGLA 2.
  (marca se-pasa-del-tope
    :en personas
    :cuando    (> (de fila turnos) (parametro tope-mensual))
    :sobre     (nombre turnos margen)
    :severidad problema
    :explica   (texto "Lleva " (de fila turnos) " "
                      (plural (de fila turnos) "turno" "turnos")
                      ", " (- 0 (de fila margen)) " por encima del tope"))

  ;; REGLA 3, a nivel de dia.
  (marca dia-incompleto
    :en dias
    :cuando    (< (de fila cubiertos) 3)
    :sobre     (dia cubiertos)
    :severidad problema
    :explica   (texto "Faltan " (- 3 (de fila cubiertos)) " "
                      (plural (- 3 (de fila cubiertos)) "turno" "turnos")))

  (vista cuadrante :de asignaciones :entrada t :etiqueta "Cuadrante"
                   :agrupada-por dia)
  (vista carga     :de personas :etiqueta "Carga de cada persona")
  (vista cobertura :de dias     :etiqueta "Cobertura por dia"))


;;; ====================================================================
;;; (b) UNA FILA POR DIA, UN CAMPO POR TURNO
;;; ====================================================================

(defsituacion cuadrante-matriz
    (:etiqueta "Cuadrante de guardia (una fila por dia)")

  (parametro tope-mensual :tipo entero :valor 6
             :etiqueta "Tope de turnos al mes")

  (coleccion personas
    (:etiqueta "Personas")
    (:clave nombre)
    (:crece)
    (campo nombre :rol fijo :etiqueta "Persona")
    ;; AQUI NO SALE NATURAL: hay que sumar un conteo por cada turno, porque
    ;; los turnos son columnas y el agregado recorre filas.
    (campo turnos :rol derivado :tipo entero :etiqueta "Turnos"
           (+ (cuantas dias :donde (= manana (de fila nombre)))
              (cuantas dias :donde (= tarde  (de fila nombre)))
              (cuantas dias :donde (= noche  (de fila nombre)))))
    ;; La misma cuenta, escrita en binario a mano.
    (campo turnos-anidado :rol derivado :tipo entero :etiqueta "Turnos (anidado)"
           (+ (cuantas dias :donde (= manana (de fila nombre)))
              (+ (cuantas dias :donde (= tarde (de fila nombre)))
                 (cuantas dias :donde (= noche (de fila nombre))))))
    (:datos (("Ana") ("Bruno") ("Carla") ("Diego"))))

  (coleccion dias
    (:etiqueta "Dias")
    (:clave dia)
    (:orden dia)
    (campo dia :rol fijo :tipo entero :etiqueta "Dia")
    (campo manana :rol entrada :etiqueta "Manana"
           :dominio (los nombre de personas) :al-violar advertir)
    (campo tarde  :rol entrada :etiqueta "Tarde"
           :dominio (los nombre de personas) :al-violar advertir)
    (campo noche  :rol entrada :etiqueta "Noche"
           :dominio (los nombre de personas) :al-violar advertir)
    ;; Contar lo cubierto del dia: aqui si sale de una pieza, pero a costa de
    ;; nombrar los tres turnos uno a uno.
    (campo cubiertos :rol derivado :tipo entero :etiqueta "Cubiertos"
           (+ (si (vacio? (de fila manana)) 0 1)
              (+ (si (vacio? (de fila tarde)) 0 1)
                 (si (vacio? (de fila noche)) 0 1))))
    (:datos ((1) (2) (3) (4) (5) (6) (7))))

  ;; REGLA 1. Aqui si es la fila de al lado: "la noche de la fila anterior".
  (marca encadena-noche-y-manana
    :en dias
    :cuando (y (no (vacio? (de fila manana)))
               (= (de fila manana) (de (anterior fila) noche)))
    :sobre     (manana)
    :severidad problema
    :explica   "Hizo la noche de ayer y entra de manana")

  ;; REGLA 3. Un solo enunciado por dia: aqui es donde la matriz gana.
  (marca dia-incompleto
    :en dias
    :cuando    (o (vacio? (de fila manana))
                  (vacio? (de fila tarde))
                  (vacio? (de fila noche)))
    :sobre     (manana tarde noche)
    :severidad problema
    :explica   (texto "Faltan " (- 3 (de fila cubiertos)) " "
                      (plural (- 3 (de fila cubiertos)) "turno" "turnos")))

  ;; Doblete el mismo dia: aqui es aritmetica de la propia fila, sin cuantificar.
  (marca doble-turno-el-mismo-dia
    :en dias
    :cuando (o (y (no (vacio? (de fila manana))) (= (de fila manana) (de fila tarde)))
               (y (no (vacio? (de fila tarde)))  (= (de fila tarde)  (de fila noche)))
               (y (no (vacio? (de fila manana))) (= (de fila manana) (de fila noche))))
    :sobre     (manana tarde noche)
    :severidad problema
    :explica   "Alguien repite turno el mismo dia")

  ;; REGLA 2.
  (marca se-pasa-del-tope
    :en personas
    :cuando    (> (de fila turnos-anidado) (parametro tope-mensual))
    :sobre     (nombre turnos turnos-anidado)
    :severidad problema
    :explica   (texto "Lleva " (de fila turnos-anidado) " turnos"))

  (vista cuadrante :de dias :entrada t :etiqueta "Cuadrante")
  (vista carga     :de personas :etiqueta "Carga de cada persona"))


;;; ====================================================================
;;; SONDAS. Cosas que se quieren medir, aisladas.
;;; ====================================================================

;;; SONDA 1. La celda del cuadrante identificada por su clave compuesta.
;;; "quien hace la manana del dia siguiente" es una busqueda por (dia, turno).
(defsituacion sonda-clave-compuesta
    (:etiqueta "Sonda: busqueda por clave compuesta")
  (coleccion asignaciones
    (:etiqueta "Asignaciones")
    (:clave dia turno)
    (:orden dia)
    (campo dia     :rol fijo :tipo entero)
    (campo turno   :rol fijo)
    (campo persona :rol entrada)
    (:datos ((1 "manana") (1 "noche") (2 "manana") (2 "noche"))))
  (coleccion dias
    (:etiqueta "Dias")
    (:clave dia)
    (:orden dia)
    (campo dia :rol fijo :tipo entero)
    (campo quien-manana-siguiente :rol derivado :etiqueta "Manana de manana"
           (el persona de (la-fila-de asignaciones
                            :donde (y (= dia (+ (de fila dia) 1))
                                      (= turno "manana")))
               :si-no ""))
    (:datos ((1) (2))))
  (vista v :de dias :entrada t))

;;; SONDA 2. Orden compuesto: se escribe, se lee solo el primero.
(defsituacion sonda-orden-compuesto
    (:etiqueta "Sonda: orden compuesto")
  (coleccion asignaciones
    (:clave dia turno)
    (:orden dia turno)
    (campo dia   :rol fijo :tipo entero)
    (campo turno :rol fijo)
    (campo quien :rol entrada)
    (:datos ((1 "manana"))))
  (vista v :de asignaciones :entrada t))


;;; ====================================================================
;;; LOS DATOS. Los mismos hechos, escritos de las dos maneras.
;;; ====================================================================
;;;
;;;   dia  manana  tarde   noche
;;;    1   Ana     Bruno   Carla
;;;    2   Diego   Ana     Bruno
;;;    3   Bruno   Carla   Diego    <- Bruno hizo la noche del 2
;;;    4   Ana     Bruno   Ana
;;;    5   Ana     Carla   ---      <- Ana hizo la noche del 4; y falta la noche
;;;    6   Bruno   Ana     Carla
;;;    7   Diego   Ana     Bruno
;;;
;;; Cuentas: Ana 7, Bruno 6, Carla 4, Diego 3. Tope 6, asi que solo Ana pasa.

(defparameter +cuadrante+
  '((1 "Ana"   "Bruno" "Carla")
    (2 "Diego" "Ana"   "Bruno")
    (3 "Bruno" "Carla" "Diego")
    (4 "Ana"   "Bruno" "Ana")
    (5 "Ana"   "Carla" "")
    (6 "Bruno" "Ana"   "Carla")
    (7 "Diego" "Ana"   "Bruno")))

(defparameter +gente+ '("Ana" "Bruno" "Carla" "Diego"))

(defun n (s) (intern (string-upcase s) '#:situacion.nucleo))

(defun fila (&rest pares)
  (loop for (campo valor) on pares by #'cddr collect (cons (n campo) valor)))

(defparameter datos-plano
  (list
   (cons (n "personas") (loop for p in +gente+ collect (fila "nombre" p)))
   (cons (n "asignaciones")
         (loop for (dia m tr nc) in +cuadrante+
               append (list (fila "dia" dia "turno" "manana" "persona" m)
                            (fila "dia" dia "turno" "tarde"  "persona" tr)
                            (fila "dia" dia "turno" "noche"  "persona" nc))))
   (cons (n "dias") (loop for (dia) in +cuadrante+ collect (fila "dia" dia)))))

(defparameter datos-matriz
  (list
   (cons (n "personas") (loop for p in +gente+ collect (fila "nombre" p)))
   (cons (n "dias")
         (loop for (dia m tr nc) in +cuadrante+
               collect (fila "dia" dia "manana" m "tarde" tr "noche" nc)))))

(defparameter datos-sonda-clave
  (list (cons (n "asignaciones")
              (list (fila "dia" 1 "turno" "manana" "persona" "Ana")
                    (fila "dia" 1 "turno" "noche"  "persona" "Bruno")
                    (fila "dia" 2 "turno" "manana" "persona" "Bruno")
                    (fila "dia" 2 "turno" "noche"  "persona" "Carla")))
        (cons (n "dias") (list (fila "dia" 1) (fila "dia" 2)))))


;;; ====================================================================
;;; EL BANCO DE PRUEBAS
;;; ====================================================================

(defparameter +salida+ #p"exploracion/salida/")

(defun titulo (texto)
  (format t "~&~%~a~%~a~%~a~%"
          (make-string 70 :initial-element #\=) texto
          (make-string 70 :initial-element #\=)))

(defun subtitulo (texto)
  (format t "~&~%--- ~a ~a~%" texto
          (make-string (max 1 (- 62 (length texto))) :initial-element #\-)))

(defun analizar-y-contar (situacion)
  (let ((problemas (analisis:comprobar-situacion situacion)))
    (if problemas
        (format t "~&ANALISIS: ~d problema(s)~%~a"
                (length problemas) (analisis:informe-de-problemas problemas))
        (format t "~&ANALISIS: sin problemas.~%"))
    problemas))

(defun mostrar-evaluacion (situacion datos &key (solo nil))
  "Imprime lo que el evaluador de referencia calcula, coleccion por coleccion."
  (dolist (par (nucleo:evaluar-situacion situacion datos))
    (destructuring-bind (coleccion . filas) par
      (when (or (null solo) (member (symbol-name coleccion) solo :test #'string-equal))
        (format t "~&  ~a~%" (string-downcase (symbol-name coleccion)))
        (dolist (f filas)
          (format t "    ~{~(~a~)=~a~^  ~}~@[   >> ~{~(~a~)~^, ~}~]~%"
                  (loop for (campo . valor) in (car f)
                        append (list campo (if (null valor) "-" valor)))
                  (cdr f)))))))

(defun materializar-en (arquitectura etiqueta situacion datos nombre)
  "Materializa y captura el fallo si lo hay, en vez de abortar."
  (ensure-directories-exist +salida+)
  (handler-case
      (multiple-value-bind (destino informe)
          (protocolo:materializar arquitectura situacion datos
                                  (merge-pathnames nombre +salida+))
        (format t "~&[~a] generado ~a~%" etiqueta destino)
        (protocolo:escribir-informe informe)
        t)
    (error (e)
      (format t "~&[~a] FALLA: ~a~%" etiqueta e)
      nil)))

(defun tres-arquitecturas (situacion datos prefijo)
  (materializar-en (situacion.texto:hacer-texto) "texto" situacion datos
                   (format nil "~a.txt" prefijo))
  (materializar-en (situacion.excel:hacer-excel) "excel" situacion datos
                   (format nil "~a-plano.json" prefijo))
  (materializar-en (situacion.web:hacer-web) "web" situacion datos
                   (format nil "~a.html" prefijo)))


;;; SONDA 4. La misma representacion (a) pero sin ninguna pregunta de
;;; nivel dia, para aislar que es exactamente lo que rompe la hoja de calculo.

;; (a) sin la coleccion DIAS: se renuncia a toda pregunta de nivel dia.
(defsituacion plano-sin-dias (:etiqueta "Plano sin preguntas de dia")
  (parametro tope-mensual :tipo entero :valor 6)
  (coleccion personas
    (:clave nombre) (:crece)
    (campo nombre :rol fijo)
    (campo turnos :rol derivado :tipo entero
           (cuantas asignaciones :donde (= persona (de fila nombre))))
    (:datos (("Ana") ("Bruno") ("Carla") ("Diego"))))
  (coleccion asignaciones
    (:clave dia turno) (:orden dia)
    (campo dia :rol fijo :tipo entero)
    (campo turno :rol fijo)
    (campo persona :rol entrada :dominio (los nombre de personas))
    (:datos ((1 "manana") (1 "tarde") (1 "noche") (2 "manana") (2 "tarde") (2 "noche")
             (3 "manana") (3 "tarde") (3 "noche") (4 "manana") (4 "tarde") (4 "noche")
             (5 "manana") (5 "tarde") (5 "noche") (6 "manana") (6 "tarde") (6 "noche")
             (7 "manana") (7 "tarde") (7 "noche"))))
  (marca noche-y-manana-siguiente
    :en asignaciones
    :cuando (y (= (de fila turno) "noche")
               (no (vacio? (de fila persona)))
               (existe otra :en asignaciones
                 :donde (y (= (de otra turno) "manana")
                           (= (de otra dia) (+ (de fila dia) 1))
                           (= (de otra persona) (de fila persona)))))
    :sobre (persona) :severidad problema
    :explica "Sale de noche y entra a la manana siguiente")
  (marca se-pasa-del-tope
    :en personas
    :cuando (> (de fila turnos) (parametro tope-mensual))
    :sobre (nombre turnos) :severidad problema)
  (vista cuadrante :de asignaciones :entrada t))

(defparameter datos-sin-dias
  (list (cons (n "personas") (loop for p in +gente+ collect (fila "nombre" p)))
        (cons (n "asignaciones")
              (loop for (dia m tr nc) in +cuadrante+
                    append (list (fila "dia" dia "turno" "manana" "persona" m)
                                 (fila "dia" dia "turno" "tarde"  "persona" tr)
                                 (fila "dia" dia "turno" "noche"  "persona" nc))))))


;;; ====================================================================

(defun informe ()

  ;; ------------------------------------------------------------------
  (titulo "(a) CUADRANTE PLANO: una fila por celda")
  (analizar-y-contar cuadrante-plano)
  (subtitulo "Evaluador de referencia")
  (mostrar-evaluacion cuadrante-plano datos-plano :solo '("personas" "dias"))
  (subtitulo "Marcas que disparan en las asignaciones")
  (dolist (par (nucleo:evaluar-situacion cuadrante-plano datos-plano))
    (when (string-equal (symbol-name (car par)) "asignaciones")
      (dolist (f (cdr par))
        (when (cdr f)
          (format t "    dia ~a ~(~a~) -> ~a   >> ~{~(~a~)~^, ~}~%"
                  (cdr (assoc (n "dia") (car f)))
                  (cdr (assoc (n "turno") (car f)))
                  (let ((p (cdr (assoc (n "persona") (car f)))))
                    (if (or (null p) (string= p "")) "(vacio)" p))
                  (cdr f))))))
  (subtitulo "Materializacion")
  (tres-arquitecturas cuadrante-plano datos-plano "turnos-plano")

  ;; ------------------------------------------------------------------
  (titulo "(b) CUADRANTE MATRIZ: una fila por dia, un campo por turno")
  (analizar-y-contar cuadrante-matriz)
  (subtitulo "Evaluador de referencia")
  (mostrar-evaluacion cuadrante-matriz datos-matriz)
  (subtitulo "Materializacion")
  (tres-arquitecturas cuadrante-matriz datos-matriz "turnos-matriz")

  ;; ------------------------------------------------------------------
  (titulo "SONDA 1: busqueda por clave compuesta (dia, turno)")
  (analizar-y-contar sonda-clave-compuesta)
  (subtitulo "Evaluador de referencia")
  (mostrar-evaluacion sonda-clave-compuesta datos-sonda-clave :solo '("dias"))
  (subtitulo "Materializacion")
  (tres-arquitecturas sonda-clave-compuesta datos-sonda-clave "sonda-clave")

  ;; ------------------------------------------------------------------
  (titulo "SONDA 2: (:orden dia turno)")
  (format t "~&Escrito:  (:orden dia turno)~%")
  (format t "Guardado: (:orden ~(~a~))~%"
          (nucleo:orden (nucleo:coleccion-llamada sonda-orden-compuesto
                                                  (n "asignaciones"))))
  (format t "Sin error ni aviso: el segundo campo se descarta en silencio.~%")

  ;; ------------------------------------------------------------------
  (titulo "SONDA 3: aritmetica n-aria")
  (format t "~&El evaluador reduce; los dos emisores toman solo dos operandos.~%")
  (format t "Ver en la salida de (b): personas.turnos frente a~%")
  (format t "personas.turnos-anidado, y las formulas emitidas.~%")

  ;; ------------------------------------------------------------------
  (titulo "SONDA 4: (a) sin la coleccion DIAS, en hoja de calculo")
  (analizar-y-contar plano-sin-dias)
  (materializar-en (situacion.excel:hacer-excel) "excel" plano-sin-dias datos-sin-dias
                   "sonda-plano-sin-dias.json")

  (format t "~&~%Artefactos en ~a~%" (truename +salida+))
  t)

(informe)
