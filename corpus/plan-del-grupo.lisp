;;;; El plan de asignaturas de un grupo.
;;;;
;;;; Es la tabla de estadisticas de la hoja de grupo del generador de
;;;; horarios: horarios/hoja_grupo.py, columnas I a M.
;;;;
;;;; SE ELIGE ESTE CASO A PROPOSITO. Es tambien el ejemplo de la tesis de 2026
;;;; cuya figura 6.2 sale con los colores corridos: alli la fila con
;;;; frecuencia 2 y tres turnos asignados aparece pintada de rojo, cuando la
;;;; regla roja es "asignadas menor que frecuencia", que con 3 y 2 es falsa;
;;;; y las dos filas que si cumplen esa regla salen de un azul que la tesis no
;;;; declara en ninguna parte.
;;;;
;;;; La razon del fallo es que alli la regla de marcado no lleva significado:
;;;; las tres reglas del caso se distinguen unicamente por comentarios y por
;;;; el orden en que estan escritas, y el color se lo pone el backend. Aqui
;;;; cada marca declara un nombre y una severidad, y el color lo decide cada
;;;; arquitectura a partir de eso. La misma descripcion produce en la hoja de
;;;; calculo un relleno, en la pagina una clase de CSS y en texto plano una
;;;; palabra.

(in-package #:situacion.corpus)

(defsituacion plan-del-grupo (:etiqueta "Plan de asignaturas del grupo D111")

  (coleccion asignaturas
    (:etiqueta "Asignaturas")
    (:clave abrev)
    ;; El listado sigue creciendo despues de generar: en la practica siempre
    ;; aparece una asignatura mas a mitad de semestre. Esto es un hecho del
    ;; dominio, no una instruccion sobre filas en blanco.
    (:crece)
    (campo abrev      :rol fijo     :etiqueta "Abrev")
    (campo nombre     :rol fijo     :etiqueta "Asignatura")
    (campo frecuencia :rol fijo     :tipo entero :etiqueta "Frec")
    (campo asignadas  :rol entrada  :tipo entero :etiqueta "Asignadas")
    (campo faltan     :rol derivado :tipo entero :etiqueta "Faltan"
           (- (de fila frecuencia) (de fila asignadas)))
    (:datos (("AL"   "Algebra Lineal"       3)
             ("L"    "Logica"               2)
             ("IP"   "Introduccion a la Programacion" 2)
             ("AM"   "Analisis Matematico"  2)
             ("ICD"  "Introduccion a Ciencia de Datos" 2)
             ("F"    "Fisica"               2))))

  ;; Las tres marcas. Cada una declara QUE SIGNIFICA, no de que color se ve.
  (marca insuficiente
    :cuando    (< (de fila asignadas) (de fila frecuencia))
    :sobre     (nombre asignadas faltan)
    :severidad advertencia
    :explica   (texto (plural (de fila faltan) "Falta" "Faltan") " "
                      (de fila faltan) " "
                      (plural (de fila faltan) "turno" "turnos")))

  (marca excedida
    :cuando    (> (de fila asignadas) (de fila frecuencia))
    :sobre     (nombre asignadas faltan)
    :severidad problema
    :explica   (texto (plural (- (de fila asignadas) (de fila frecuencia))
                              "Sobra" "Sobran")
                      " " (- (de fila asignadas) (de fila frecuencia)) " "
                      (plural (- (de fila asignadas) (de fila frecuencia))
                              "turno" "turnos")))

  (marca completa
    :cuando    (y (= (de fila asignadas) (de fila frecuencia))
                  (no (vacio? (de fila asignadas))))
    :sobre     (nombre)
    :severidad informativa)

  (vista plan :de asignaturas :entrada t :etiqueta "Plan del grupo"))

;;; Los datos con los que se rellena. En el flujo real vienen del YAML de la
;;; facultad; aqui van escritos para que la demostracion sea reproducible.
;;;
;;; Se eligen a proposito los mismos valores de la figura 6.2 de 2026, para
;;; que la comparacion sea directa.
(defparameter datos-del-plan
  (let ((n (lambda (s) (nucleo:nombrar s))))
    (list (cons (funcall n "asignaturas")
                (loop for (abrev nombre frec asignadas)
                        in '(("AL"  "Algebra Lineal"                  3 3)
                             ("L"   "Logica"                          2 2)
                             ("IP"  "Introduccion a la Programacion"  2 2)
                             ("AM"  "Analisis Matematico"             2 3)
                             ("ICD" "Introduccion a Ciencia de Datos" 2 1)
                             ("F"   "Fisica"                          2 1))
                      collect (list (cons (funcall n "abrev") abrev)
                                    (cons (funcall n "nombre") nombre)
                                    (cons (funcall n "frecuencia") frec)
                                    (cons (funcall n "asignadas") asignadas))))))
  "Los seis renglones de la figura 6.2 de la tesis de 2026.")
