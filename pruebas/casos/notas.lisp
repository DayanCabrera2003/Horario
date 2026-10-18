;;;; G2. Notas de estudiantes: promedio, aprobado/suspenso, booleano y fecha.
;;;; Ejercita: division, parametro, si anidado, :tipo booleano y :tipo fecha,
;;;; comparacion de fechas, una coleccion resumen de una sola fila, vista
;;;; agrupada, valores con tilde y enie.
(in-package #:situacion.casos)

(defsituacion caso-notas (:etiqueta "Notas de Álgebra")
  (parametro aprobado :tipo numero :valor 60 :rol entrada :etiqueta "Nota para aprobar")
  (parametro hoy :tipo fecha :valor "2026-10-17" :etiqueta "Fecha de hoy")

  (coleccion estudiantes
    (:etiqueta "Estudiantes")
    (:clave carne)
    (:orden carne)
    (:crece)
    (campo carne   :rol fijo :etiqueta "Carné")
    (campo nombre  :rol fijo :etiqueta "Nombre")
    (campo grupo   :rol fijo :etiqueta "Grupo")
    (campo becado  :rol fijo :tipo booleano :etiqueta "Becado")
    (campo n1      :rol entrada :tipo entero :etiqueta "Parcial 1")
    (campo n2      :rol entrada :tipo entero :etiqueta "Parcial 2")
    (campo n3      :rol entrada :tipo entero :etiqueta "Final")
    (campo entrega :rol entrada :tipo fecha :etiqueta "Entrega del proyecto")
    (campo promedio :rol derivado :tipo numero :etiqueta "Promedio"
           (/ (+ (de fila n1) (de fila n2) (de fila n3)) 3))
    (campo resultado :rol derivado :etiqueta "Resultado"
           (si (o (vacio? (de fila n1)) (vacio? (de fila n2)) (vacio? (de fila n3)))
               "Incompleto"
               (si (>= (de fila promedio) (parametro aprobado)) "Aprobado" "Suspenso")))
    (campo tarde :rol derivado :tipo booleano :etiqueta "Entregó tarde"
           (y (no (vacio? (de fila entrega))) (> (de fila entrega) "2026-10-10"))))

  (coleccion resumen
    (:una-sola-fila)
    (:etiqueta "Resumen del curso")
    (campo matriculados :rol derivado :tipo entero :etiqueta "Matriculados"
           (cuantas estudiantes))
    (campo aprobados :rol derivado :tipo entero :etiqueta "Aprobados"
           (cuantas estudiantes :donde (= resultado "Aprobado")))
    (campo porcentaje :rol derivado :tipo numero :etiqueta "% aprobados"
           (/ (* 100 (de fila aprobados)) (de fila matriculados)))
    (campo mejor :rol derivado :tipo numero :etiqueta "Mejor promedio"
           (maximo promedio de estudiantes))
    (campo becados :rol derivado :tipo entero :etiqueta "Becados"
           (cuantas estudiantes :donde (= becado t))))

  (marca suspenso
    :en estudiantes
    :cuando (= (de fila resultado) "Suspenso")
    :sobre (promedio resultado)
    :severidad problema
    :explica (texto "Promedio " (de fila promedio) " por debajo de " (parametro aprobado)))

  (marca becado-en-riesgo
    :en estudiantes
    :cuando (y (= (de fila becado) t) (no (= (de fila resultado) "Aprobado")))
    :sobre (nombre becado)
    :severidad advertencia
    :explica "Becado que todavía no aprueba")

  (marca entrega-tardia
    :en estudiantes
    :cuando (= (de fila tarde) t)
    :sobre (entrega)
    :severidad advertencia
    :explica "Entregó después del 10 de octubre")

  (vista acta :de estudiantes :entrada t :etiqueta "Acta" :agrupada-por grupo)
  (vista res :de resumen :etiqueta "Resumen"))

(defparameter datos-de-notas
  (datos (list "estudiantes"
               (fila "carne" "A03" "nombre" "Íñigo Muñoz" "grupo" "C-11" "becado" t
                     "n1" 70 "n2" 65 "n3" 81 "entrega" "2026-10-09")
               (fila "carne" "A01" "nombre" "Lía Pérez" "grupo" "C-12" "becado" nil
                     "n1" 50 "n2" 55 "n3" 52 "entrega" "2026-10-12")
               (fila "carne" "A02" "nombre" "Ana Núñez" "grupo" "C-11" "becado" t
                     "n1" 90 "n2" nil "n3" 77 "entrega" nil)
               (fila "carne" "A04" "nombre" "José Ávila" "grupo" "C-12" "becado" nil
                     "n1" 61 "n2" 60 "n3" 60 "entrega" "2026-10-10"))
         (list "resumen" (fila))))

(registrar-caso "caso-notas" caso-notas datos-de-notas)
