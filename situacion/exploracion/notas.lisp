;;;; La evaluacion de una asignatura.
;;;;
;;;; EXPLORACION. No es corpus: es un dominio de fuera, escrito para medir
;;;; hasta donde llega el lenguaje tal como esta.
;;;;
;;;; Lo que este caso pide y el corpus no pedia:
;;;;
;;;;   1. Una media PONDERADA. Hay que multiplicar y sumar sobre otra
;;;;      coleccion cruzando dos claves (estudiante y evaluacion). El
;;;;      agregado del lenguaje suma un CAMPO, no una EXPRESION, asi que el
;;;;      producto no cabe dentro de la suma y hay que materializarlo antes
;;;;      en una columna derivada (APORTE). Es la primera deformacion.
;;;;
;;;;   2. Un umbral EDITABLE. Se declara como (parametro umbral ... :rol
;;;;      entrada), que es lo que el modelo ofrece para eso.
;;;;
;;;;   3. Un valor de resumen que no es de ninguna fila: cuantos aprobaron.
;;;;      El lenguaje solo sabe poner valores en filas de colecciones, asi
;;;;      que hace falta inventarse una coleccion de una sola fila. Es la
;;;;      segunda deformacion.

(defpackage #:situacion.exploracion.notas
  (:use #:common-lisp #:situacion.lenguaje)
  (:export #:notas #:datos-de-notas))

(in-package #:situacion.exploracion.notas)

(defsituacion notas (:etiqueta "Evaluacion de Programacion I")

  ;; El umbral de aprobado. Se quiere poder cambiarlo en el documento.
  (parametro umbral :tipo entero :rol entrada :valor 60
             :etiqueta "Umbral de aprobado")

  ;; ---------------------------------------------------------------
  ;; Las evaluaciones y su peso.
  ;; ---------------------------------------------------------------
  (coleccion evaluaciones
    (:etiqueta "Evaluaciones")
    (:clave nombre)
    (campo nombre :rol fijo :etiqueta "Evaluacion")
    (campo peso   :rol fijo :tipo entero :etiqueta "Peso (%)")
    (:datos (("Parcial 1" 25) ("Parcial 2" 25)
             ("Proyecto" 20)  ("Examen final" 30))))

  ;; ---------------------------------------------------------------
  ;; Las calificaciones: una por par de estudiante y evaluacion.
  ;; ---------------------------------------------------------------
  (coleccion calificaciones
    (:etiqueta "Calificaciones")
    (:clave estudiante evaluacion)
    (:crece)
    (campo estudiante :rol fijo :etiqueta "Estudiante")
    (campo evaluacion :rol fijo :etiqueta "Evaluacion")
    (campo nota :rol entrada :tipo entero :etiqueta "Nota")

    ;; DEFORMACION 1a. El peso vive en otra coleccion y aqui se trae por
    ;; clave. Esto si se lee bien; el problema es POR QUE hace falta: no se
    ;; puede mirar el peso desde dentro de la suma.
    (campo peso :rol derivado :tipo entero :etiqueta "Peso (%)"
           (el peso de (la-fila-de evaluaciones
                         :donde (= nombre (de fila evaluacion)))
               :si-no 0))

    ;; DEFORMACION 1b. El producto de la media ponderada, materializado como
    ;; columna porque (suma <expresion> de ...) no existe.
    (campo aporte :rol derivado :tipo numero :etiqueta "Aporte"
           (/ (* (de fila nota) (de fila peso)) 100))

    (:datos (("Ana Robles" "Parcial 1") ("Ana Robles" "Parcial 2")
             ("Ana Robles" "Proyecto")  ("Ana Robles" "Examen final")
             ("Beto Nunez" "Parcial 1") ("Beto Nunez" "Parcial 2")
             ("Beto Nunez" "Proyecto")  ("Beto Nunez" "Examen final")
             ("Carla Diaz" "Parcial 1") ("Carla Diaz" "Parcial 2")
             ("Carla Diaz" "Proyecto")  ("Carla Diaz" "Examen final")
             ("Dario Mena" "Parcial 1") ("Dario Mena" "Parcial 2")
             ("Dario Mena" "Proyecto")  ("Dario Mena" "Examen final"))))

  ;; ---------------------------------------------------------------
  ;; Los estudiantes y su nota final.
  ;; ---------------------------------------------------------------
  (coleccion estudiantes
    (:etiqueta "Estudiantes")
    (:clave nombre)
    (:crece)
    (campo nombre :rol fijo :etiqueta "Estudiante")
    (campo grupo  :rol fijo :etiqueta "Grupo")

    ;; La media ponderada, ya reducida a una suma de un campo.
    (campo final :rol derivado :tipo numero :etiqueta "Nota final"
           (suma aporte de calificaciones
                 :donde (= estudiante (de fila nombre))))

    ;; DEFORMACION 3. El estado se materializa como texto porque contar
    ;; aprobados exige un criterio de IGUALDAD sobre un campo: la hoja de
    ;; calculo no sabe agregar con (>= final (parametro umbral)).
    (campo estado :rol derivado :etiqueta "Estado"
           (si (>= (de fila final) (parametro umbral)) "Aprobado" "Suspenso"))

    (:datos (("Ana Robles" "111") ("Beto Nunez" "111")
             ("Carla Diaz" "112") ("Dario Mena" "112"))))

  ;; ---------------------------------------------------------------
  ;; DEFORMACION 2. Los valores del curso entero, que no son de ninguna
  ;; fila, metidos en una coleccion de una sola fila porque el lenguaje no
  ;; tiene donde poner un escalar derivado.
  ;; ---------------------------------------------------------------
  (coleccion resumen
    (:etiqueta "Resumen del curso")
    (:clave asignatura)
    (campo asignatura :rol fijo :etiqueta "Asignatura")
    (campo matriculados :rol derivado :tipo entero :etiqueta "Matriculados"
           (cuantas estudiantes))
    (campo aprobados :rol derivado :tipo entero :etiqueta "Aprobados"
           (cuantas estudiantes :donde (= estado "Aprobado")))
    (campo peso-total :rol derivado :tipo entero :etiqueta "Peso total"
           (suma peso de evaluaciones))
    (:datos (("Programacion I"))))

  ;; ---------------------------------------------------------------
  ;; Las marcas.
  ;; ---------------------------------------------------------------
  (marca no-aprueba
    :en        estudiantes
    :cuando    (y (no (vacio? (de fila nombre)))
                  (< (de fila final) (parametro umbral)))
    :sobre     (nombre final estado)
    :severidad problema
    :explica   (texto "Le faltan " (- (parametro umbral) (de fila final))
                      " " (plural (- (parametro umbral) (de fila final))
                                  "punto" "puntos")
                      " para aprobar"))

  (marca sin-calificar
    :en        calificaciones
    :cuando    (y (no (vacio? (de fila estudiante))) (vacio? (de fila nota)))
    :sobre     (nota)
    :severidad informativa
    :explica   "Esta evaluacion todavia no tiene nota")

  (marca pesos-mal-repartidos
    :en        resumen
    :cuando    (/= (de fila peso-total) 100)
    :sobre     (peso-total)
    :severidad advertencia
    :explica   "Los pesos de las evaluaciones no suman 100")

  ;; ---------------------------------------------------------------
  ;; Las vistas.
  ;; ---------------------------------------------------------------
  (vista acta :de estudiantes :entrada t :etiqueta "Acta: nota final por estudiante")
  (vista libreta :de calificaciones :etiqueta "Libreta de calificaciones"
                 :agrupada-por estudiante)
  (vista plan :de evaluaciones :etiqueta "Evaluaciones y pesos")
  (vista curso :de resumen :etiqueta "Resumen del curso"))

;;; ---------------------------------------------------------------------
;;; Los datos.
;;; ---------------------------------------------------------------------

(defparameter datos-de-notas
  (let ((n (lambda (s) (intern (string-upcase s) '#:situacion.nucleo))))
    (list
     (cons (funcall n "evaluaciones")
           (loop for (nombre peso) in '(("Parcial 1" 25) ("Parcial 2" 25)
                                        ("Proyecto" 20)  ("Examen final" 30))
                 collect (list (cons (funcall n "nombre") nombre)
                               (cons (funcall n "peso") peso))))
     (cons (funcall n "estudiantes")
           (loop for (nombre grupo) in '(("Ana Robles" "111") ("Beto Nunez" "111")
                                         ("Carla Diaz" "112") ("Dario Mena" "112"))
                 collect (list (cons (funcall n "nombre") nombre)
                               (cons (funcall n "grupo") grupo))))
     ;; Beto suspende. A Dario le falta la nota del proyecto.
     (cons (funcall n "calificaciones")
           (loop for (est eva nota)
                   in '(("Ana Robles" "Parcial 1" 80) ("Ana Robles" "Parcial 2" 90)
                        ("Ana Robles" "Proyecto" 100) ("Ana Robles" "Examen final" 85)
                        ("Beto Nunez" "Parcial 1" 55) ("Beto Nunez" "Parcial 2" 40)
                        ("Beto Nunez" "Proyecto" 70)  ("Beto Nunez" "Examen final" 50)
                        ("Carla Diaz" "Parcial 1" 60) ("Carla Diaz" "Parcial 2" 68)
                        ("Carla Diaz" "Proyecto" 75)  ("Carla Diaz" "Examen final" 55)
                        ("Dario Mena" "Parcial 1" 90) ("Dario Mena" "Parcial 2" 70)
                        ("Dario Mena" "Proyecto" nil) ("Dario Mena" "Examen final" 45))
                 collect (list (cons (funcall n "estudiante") est)
                               (cons (funcall n "evaluacion") eva)
                               (cons (funcall n "nota") nota))))
     (cons (funcall n "resumen")
           (list (list (cons (funcall n "asignatura") "Programacion I"))))))
  "Cuatro estudiantes, cuatro evaluaciones, una nota sin poner.")

;;; ---------------------------------------------------------------------
;;; Ejecucion
;;; ---------------------------------------------------------------------

(format t "~%~a~%ANALISIS~%~a~%" (make-string 70 :initial-element #\=)
        (make-string 70 :initial-element #\=))
(let ((problemas (situacion.analisis:comprobar-situacion notas)))
  (if problemas
      (format t "~d problema(s):~%~a" (length problemas)
              (situacion.analisis:informe-de-problemas problemas))
      (format t "Sin problemas.~%")))

(format t "~%~a~%EVALUADOR DE REFERENCIA~%~a~%" (make-string 70 :initial-element #\=)
        (make-string 70 :initial-element #\=))
(dolist (par (nucleo:evaluar-situacion notas datos-de-notas))
  (format t "~%~a~%" (string-downcase (symbol-name (car par))))
  (dolist (fila (cdr par))
    (format t "  ~{~(~a~)=~a~^  ~}~@[   MARCAS: ~{~(~a~)~^, ~}~]~%"
            (loop for (campo . valor) in (car fila)
                  append (list campo (nucleo:como-texto valor)))
            (cdr fila))))

(format t "~%~a~%LAS TRES ARQUITECTURAS~%~a~%" (make-string 70 :initial-element #\=)
        (make-string 70 :initial-element #\=))
(situacion.demostracion:generar notas datos-de-notas "notas")

;;; ---------------------------------------------------------------------
;;; LO QUE SE MIDIO AL EJECUTAR ESTO (21-09-2026)
;;;
;;;   1. La media ponderada SALE, y sale bien en los tres destinos, pero solo
;;;      despues de partirla en dos columnas derivadas (PESO y APORTE). El
;;;      agregado suma un CAMPO, no una EXPRESION.
;;;      Comprobado con LibreOffice: Estudiantes!C4..C7 = 88, 52.75, 63.5,
;;;      53.5, que es lo mismo que dice el evaluador de referencia.
;;;
;;;   2. El PARAMETRO UMBRAL no es editable en ningun destino. Las dos
;;;      arquitecturas lo meten en la formula como el literal 60:
;;;        hoja:    =IF($A4="","",IF(($C4>=60),"Aprobado","Suspenso"))
;;;        pagina:  (N(V(f["final"])) >= N(60)) ? "Aprobado" : "Suspenso"
;;;      No hay celda, ni control, ni linea de texto que lo muestre, y
;;;      PROTOCOLO:REQUERIMIENTOS no pide ninguna capacidad por el. :ROL
;;;      ENTRADA en un parametro no significa nada todavia.
;;;
;;;   3. (suma peso de evaluaciones), un agregado SIN :donde, emite
;;;      =COUNTA(Evaluaciones!$A$4:$A$7). La hoja calcula 4 donde el evaluador
;;;      y la pagina calculan 100, y por eso el formato condicional de
;;;      PESOS-MAL-REPARTIDOS se dispara en el libro y no en la pagina.
;;;      Causa: excel/formula.lisp, rama ((null campo-criterio) ...), que no
;;;      mira (nucleo:operacion e).
;;;
;;;   4. La division da racionales exactos: el acta dice "211/4" y "Le faltan
;;;      29/4 puntos". Peor: salida/notas-esperado.json sale con "final":
;;;      211/4, que no es JSON valido, y materializador/verificar.py no puede
;;;      ni leerlo. El corpus no divide nunca, asi que esto no habia salido.
;;; ---------------------------------------------------------------------
