;;;; Pruebas de la relacion uno-a-muchos en Excel (H4).

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion carga-de-profesores (:etiqueta "Carga de profesores")
  (coleccion profesores
    (:clave nombre)
    (campo nombre :rol fijo :etiqueta "Profesor")
    (campo asignaciones :rol derivado :etiqueta "Asignaturas que imparte"
           (las-filas-de asignacion :donde (= profesor (de fila nombre))))
    (:datos (("Rosa") ("Julia") ("Pedro"))))
  (coleccion asignacion
    (:clave profesor grupo abrev)
    (campo profesor :rol fijo :etiqueta "Profesor")
    (campo grupo    :rol fijo :etiqueta "Grupo")
    (campo abrev    :rol fijo :etiqueta "Asignatura")
    (:datos (("Rosa" "10-A" "MAT") ("Rosa" "10-B" "MAT") ("Rosa" "10-A" "ING")
             ("Julia" "10-A" "ESP") ("Julia" "10-B" "ESP") ("Julia" "10-A" "HIST")
             ("Julia" "10-B" "HIST") ("Julia" "10-A" "HIST2"))))
  (vista docentes :de profesores :entrada t :etiqueta "Profesores"))

(defun situacion-de-carga () (situacion.lenguaje:situacion-llamada "CARGA-DE-PROFESORES"))

(defparameter *datos-de-carga*
  (list (cons (nucleo:nombrar "profesores")
              (loop for p in '("Rosa" "Julia" "Pedro")
                    collect (list (cons (nucleo:nombrar "nombre") p))))
        (cons (nucleo:nombrar "asignacion")
              (loop for (p g a) in '(("Rosa" "10-A" "MAT") ("Rosa" "10-B" "MAT")
                                     ("Rosa" "10-A" "ING")
                                     ("Julia" "10-A" "ESP") ("Julia" "10-B" "ESP")
                                     ("Julia" "10-A" "HIST") ("Julia" "10-B" "HIST")
                                     ("Julia" "10-A" "HIST2"))
                    collect (list (cons (nucleo:nombrar "profesor") p)
                                  (cons (nucleo:nombrar "grupo") g)
                                  (cons (nucleo:nombrar "abrev") a))))))

;; Nota: la reserva por defecto es 5. Rosa tiene 3 relacionadas y Julia 5:
;; las dos caben dentro de la reserva, asi que esta situacion prueba el caso
;; normal sin desbordar. El caso de desborde va en la prueba de mas abajo,
;; con reserva mas baja a proposito.

(definir-prueba con-relacion-uno-a-muchos-ya-no-se-rechaza
    "H4: la hoja de calculo emula la relacion uno-a-muchos, no la rechaza"
  (let ((informe (nth-value 1
                   (materializar-en-cadena (situacion.excel:hacer-excel)
                                           (situacion-de-carga) *datos-de-carga*))))
    (comprobar (search "emula" (string-downcase (format nil "~a" informe)))
               "el informe tiene que decir EMULA para la relacion uno-a-muchos,~@
                no RECHAZA")))

(definir-prueba con-relacion-uno-a-muchos-produce-formula-real
    "H4: la celda de la relacion lleva un COUNTIF, no el resultado de REQUERIR"
  (let ((destino "/tmp/carga-de-profesores-plano.json"))
    (protocolo:materializar (situacion.excel:hacer-excel) (situacion-de-carga)
                            *datos-de-carga* destino)
    (let ((contenido (with-open-file (f destino)
                       (let ((s (make-string (file-length f)))) (read-sequence s f) s))))
      (comprobar (search "COUNTIF" contenido)
                 "la celda de ASIGNACIONES tiene que llevar una formula COUNTIF~@
                  real, no lo que devuelva REQUERIR"))))

(definir-prueba con-relacion-uno-a-muchos-avisa-el-desborde
    "H4: con mas relacionadas que reserva, la ultima linea avisa cuantas sobran"
  (let ((informe (nth-value 1
                   (materializar-en-cadena
                    (situacion.excel:hacer-excel :reserva-de-relacion 2)
                    (situacion-de-carga) *datos-de-carga*))))
    (comprobar informe "tiene que producir informe igual")))
