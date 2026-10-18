;;;; Pruebas de los ejes de las vistas cruzadas.
;;;;
;;;; Antes cada seccion de una vista partida tenia sus propios ejes, en su
;;;; propio orden de aparicion: en el Saul, la pestana de un profesor era una
;;;; rejilla de 1 x 2 y la de un aula tenia las columnas M, V, L, MI, J.
;;;; Ahora todas las secciones comparten los ejes de la vista entera, y si el
;;;; eje es el campo de orden de la coleccion, van en ese orden
;;;; (nucleo/ejes.lisp).

(in-package #:situacion.pruebas)

(defun rejillas-de-vista (plano vista)
  "Las pestanas cruzadas del plano que son de VISTA (una cadena)."
  (remove-if-not (lambda (h) (equal (dato (dato h "cruce") "vista") vista))
                 (hojas-del-plano plano)))

(defun ejes-de-rejilla (hoja)
  "(VALUES FILAS COLUMNAS) de una pestana cruzada del plano."
  (values (mapcar (lambda (c) (dato c "valor"))
                  (remove-if-not (lambda (c) (char= #\A (char (dato c "celda") 0)))
                                 (lista-del-plano (dato hoja "celdas"))))
          (mapcar (lambda (e) (dato e "texto"))
                  (remove "__eje__" (lista-del-plano (dato hoja "encabezados"))
                          :key (lambda (e) (dato e "campo")) :test #'equal))))

(definir-prueba ejes-comunes-a-todas-las-secciones
    "Ejes: todas las pestanas de una vista partida tienen las mismas filas y columnas"
  (let ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                         situacion.corpus:datos-del-saul)))
    (dolist (vista '("por-grupo" "por-profesor" "por-aula"))
      (let ((rejillas (rejillas-de-vista plano vista)))
        (multiple-value-bind (filas columnas) (ejes-de-rejilla (first rejillas))
          (comprobar (equal filas '(1 2 3 4 5 6 7))
                     "~a: las filas tienen que ser los siete turnos en orden: ~s" vista filas)
          (comprobar (equal columnas '("L" "M" "MI" "J" "V"))
                     "~a: las columnas tienen que ser los cinco dias en orden: ~s"
                     vista columnas)
          (dolist (otra (rest rejillas))
            (multiple-value-bind (f c) (ejes-de-rejilla otra)
              (comprobar (and (equal f filas) (equal c columnas))
                         "~a: la pestana ~s tiene otros ejes" vista (dato otra "nombre")))))))))

(definir-prueba ejes-las-secciones-van-ordenadas
    "Ejes: las secciones de una vista partida van ordenadas por su valor"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                          situacion.corpus:datos-del-saul))
         (secciones (mapcar (lambda (h) (dato (dato h "cruce") "seccion"))
                            (rejillas-de-vista plano "por-aula"))))
    (comprobar (equal secciones (sort (copy-list secciones) #'string<))
               "las aulas tienen que ir ordenadas: ~s" secciones)))
