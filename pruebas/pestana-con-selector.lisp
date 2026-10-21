;;;; Pruebas de la pestana con selector en la hoja de calculo.
;;;;
;;;; Una vista partida cuyas secciones pueden crecer lleva, ademas de una
;;;; pestana por seccion, una "(elegir)" en la que la seccion se escoge en un
;;;; desplegable (excel/pestana-con-selector.lisp). Asi un profesor anadido en
;;;; el libro tiene donde verse sin volver a generarlo.

(in-package #:situacion.pruebas)

(defun pestanas-con-selector (plano)
  "Las pestanas cruzadas del plano que llevan selector."
  (remove-if-not (lambda (h) (eq t (dato (dato h "cruce") "selector")))
                 (hojas-del-plano plano)))

(definir-prueba selector-en-el-horario-del-profesor
    "Selector: el horario del profesor del Saul tiene su pestana para elegir"
  (let* ((plano (plano-del-saul))
         (con-selector (pestanas-con-selector plano))
         (hoja (first con-selector)))
    (comprobar (= 1 (length con-selector))
               "el Saul tiene una sola vista que puede crecer y lleva selector: ~s"
               (mapcar (lambda (h) (dato h "nombre")) con-selector))
    (when hoja
      (comprobar (equal (dato hoja "nombre") "Horario del profesor (elegir)")
                 "la pestana se llama ~s" (dato hoja "nombre"))
      (comprobar (equal (lista-del-plano (dato hoja "editables")) '("B2"))
                 "solo se escribe el selector: ~s" (dato hoja "editables"))
      (let ((validacion (first (lista-del-plano (dato hoja "validaciones")))))
        (comprobar (and validacion
                        (equal (dato validacion "rango") "B2")
                        (search "'Profesores'!$A$4:$A$" (dato validacion "lista")))
                   "el desplegable sale de la columna de los profesores: ~s" validacion))
      (comprobar (search "$B$2&CHAR(31)" (formula-de-celda hoja "B4"))
                 "la casilla tiene que buscar con lo que diga el selector: ~a"
                 (formula-de-celda hoja "B4")))))

(definir-prueba selector-solo-si-las-secciones-crecen
    "Selector: las vistas cuyas secciones no crecen, y las de entrada, no lo llevan"
  (let ((vistas (mapcar (lambda (h) (dato (dato h "cruce") "vista"))
                        (pestanas-con-selector (plano-del-saul)))))
    (comprobar (not (member "por-aula" vistas :test #'equal))
               "las aulas salen de las casillas, que no crecen")
    (comprobar (not (member "por-grupo" vistas :test #'equal))
               "el horario del grupo es de entrada y no busca"))
  (let ((vistas (mapcar (lambda (h) (dato (dato h "cruce") "vista"))
                        (pestanas-con-selector
                         (plano-de (situacion.lenguaje:situacion-llamada "SEDER")
                                   situacion.corpus:datos-del-seder)))))
    (comprobar (member "por-profesor" vistas :test #'equal)
               "en el SEDER los profesores salen de las brigadas, que crecen: ~s" vistas)
    (comprobar (not (member "ocupacion" vistas :test #'equal))
               "las semanas son una enumeracion y no crecen: ~s" vistas)))
