;;;; La demostracion.
;;;;
;;;; Toma las descripciones del corpus y, sin tocar ni una linea de ellas,
;;;; produce tres artefactos distintos mas el informe de conformidad de cada
;;;; arquitectura.
;;;;
;;;; Lo que hay que mirar no es que los tres salgan bonitos. Es que:
;;;;
;;;;   - La descripcion es la misma para los tres.
;;;;   - El evaluador de referencia y las tres arquitecturas coinciden en los
;;;;     valores. Eso es lo que hace que "independiente del destino" signifique
;;;;     algo comprobable.
;;;;   - El informe dice, capacidad por capacidad, que cumplio cada una, que
;;;;     emulo y que degrado. Ninguna de las tres tesis anteriores tiene nada
;;;;     equivalente.

(defpackage #:situacion.demostracion
  (:use #:common-lisp)
  (:export #:generar #:generar-todo))

(in-package #:situacion.demostracion)

(defparameter +salida+ #p"salida/"
  "Donde caen los artefactos.")

(defun ruta (nombre) (merge-pathnames nombre +salida+))

(defun generar (situacion datos prefijo)
  "Genera los tres artefactos de una situacion y devuelve los informes."
  (ensure-directories-exist +salida+)
  (format t "~&~%~a~%" (make-string 70 :initial-element #\=))
  (format t "~a~%" (nucleo:etiqueta situacion))
  (format t "~a~%" (make-string 70 :initial-element #\=))

  ;; Fase 4: comprobaciones estaticas, sin saber a donde se va a generar.
  (multiple-value-bind (s problemas) (analisis:analizar situacion)
    (declare (ignore s))
    (if problemas
        (format t "~&Analisis: ~d aviso(s)~%~a" (length problemas)
                (analisis:informe-de-problemas problemas))
        (format t "~&Analisis: sin problemas.~%")))

  (let ((informes '()))
    ;; --- texto plano ---
    (multiple-value-bind (destino informe)
        (protocolo:materializar (situacion.texto:hacer-texto) situacion datos
                                (ruta (format nil "~a.txt" prefijo)))
      (format t "~&~%Generado ~a~%" destino)
      (push (cons "texto" informe) informes))

    ;; --- hoja de calculo (el plano que consume el materializador) ---
    (multiple-value-bind (destino informe)
        (protocolo:materializar (situacion.excel:hacer-excel) situacion datos
                                (ruta (format nil "~a-plano.json" prefijo)))
      (format t "Generado ~a~%" destino)
      (push (cons "excel" informe) informes))

    ;; --- los valores esperados, segun el evaluador de referencia ---
    ;; No es un artefacto de salida: es el oraculo. Lo que diga aqui el
    ;; nucleo es lo que tiene que dar la hoja de calculo cuando LibreOffice
    ;; evalue sus formulas, y lo que tiene que dar la pagina al abrirse.
    (escribir-esperado situacion datos (ruta (format nil "~a-esperado.json" prefijo)))
    (format t "Generado salida/~a-esperado.json  (oraculo del evaluador)~%" prefijo)

    ;; --- pagina web ---
    (multiple-value-bind (destino informe)
        (protocolo:materializar (situacion.web:hacer-web) situacion datos
                                (ruta (format nil "~a.html" prefijo)))
      (format t "Generado ~a~%" destino)
      (push (cons "web" informe) informes))

    (format t "~%")
    (dolist (par (reverse informes))
      (protocolo:escribir-informe (cdr par))
      (format t "~%"))
    (reverse informes)))

(defun escribir-esperado (situacion datos destino)
  "Los valores que el evaluador de referencia calcula, por coleccion y fila.

   Se reutiliza el serializador de la arquitectura de Excel porque es el que
   hay; no es una dependencia del nucleo, solo una comodidad de esta
   demostracion."
  (let ((evaluado (nucleo:evaluar-situacion situacion datos)))
    (situacion.excel::escribir-plano
     (loop for (coleccion . filas) in evaluado
           collect (cons (string-downcase (symbol-name coleccion))
                         (or (loop for fila in filas
                                   collect (cons (loop for (campo . valor) in (car fila)
                                                       collect (cons (string-downcase
                                                                      (symbol-name campo))
                                                                     valor))
                                                 nil))
                             :lista-vacia)))
     destino)))

(defun generar-todo ()
  (generar situacion.corpus:plan-del-grupo
           situacion.corpus:datos-del-plan
           "plan-del-grupo")
  (generar situacion.corpus:defensas-de-tesis
           situacion.corpus:datos-de-las-defensas
           "defensas-de-tesis")
  (generar situacion.corpus:horario-del-grupo
           situacion.corpus:datos-del-horario
           "horario-del-grupo")
  (format t "~&~%Todo en ~a~%" (truename +salida+))
  t)
