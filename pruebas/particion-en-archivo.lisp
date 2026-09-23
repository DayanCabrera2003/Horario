;;;; Pruebas de la particion de vista en archivos independientes (H2).

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion horario-con-profesores (:etiqueta "Horario con profesores")
  (coleccion casillas
    (:clave grupo dia turno)
    (campo grupo      :rol fijo)
    (campo dia        :rol fijo)
    (campo turno      :rol fijo :tipo entero)
    (campo profesor   :rol fijo)
    (campo asignatura :rol entrada :dominio (uno-de "MAT" "ESP")
                      :al-violar advertir))
  (vista por-grupo    :de casillas :entrada t :etiqueta "Horario del grupo"
                      :filas turno :columnas dia :muestra asignatura
                      :secciones grupo)
  (vista por-profesor :de casillas :etiqueta "Horario del profesor"
                      :filas turno :columnas dia :muestra grupo
                      :secciones profesor))

(defun situacion-con-profesores ()
  (situacion.lenguaje:situacion-llamada "HORARIO-CON-PROFESORES"))

(defparameter *datos-con-profesores*
  (list (cons (nucleo:nombrar "casillas")
              (loop for (g d tu p a) in '(("10-A" "lunes" 1 "Rosa" "MAT")
                                          ("10-A" "lunes" 2 "Julia" "ESP")
                                          ("10-B" "lunes" 1 "Julia" "ESP"))
                    collect (list (cons (nucleo:nombrar "grupo") g)
                                  (cons (nucleo:nombrar "dia") d)
                                  (cons (nucleo:nombrar "turno") tu)
                                  (cons (nucleo:nombrar "profesor") p)
                                  (cons (nucleo:nombrar "asignatura") a))))))

(definir-prueba vista-en-archivo-no-deja-pestana-en-el-libro-principal
    "H2: una vista en VISTAS-EN-ARCHIVO no tiene pestana en el libro principal"
  (let* ((a (situacion.excel:hacer-excel :vistas-en-archivo '(por-profesor)))
         (destino "/tmp/horario-con-profesores-plano.json"))
    (protocolo:materializar a (situacion-con-profesores) *datos-con-profesores* destino)
    (let ((contenido (with-open-file (f destino)
                       (let ((s (make-string (file-length f))))
                         (read-sequence s f) s))))
      ;; Comprobacion textual simple: el nombre de pestana de POR-PROFESOR no
      ;; debe aparecer en el JSON del libro principal.
      (comprobar (not (search "Horario del profesor" contenido))
                 "la vista en VISTAS-EN-ARCHIVO no puede tener pestana en el~@
                  libro principal"))))
