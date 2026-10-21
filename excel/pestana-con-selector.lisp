;;;; La pestana con selector: una seccion que todavia no existe al generar.
;;;;
;;;; Una vista partida sale en la hoja de calculo como una pestana por
;;;; seccion, y las pestanas se fijan al generar: un profesor anadido despues
;;;; en el libro no tiene la suya hasta volver a generarlo. Asi se vio el
;;;; 2026-10-21, al usar el libro del Saul para llenar datos.
;;;;
;;;; Cuando las secciones pueden crecer, la vista lleva ademas una pestana
;;;; mas, "(elegir)": la misma rejilla, pero la seccion no va escrita en las
;;;; formulas sino en una celda con desplegable, y cada casilla busca con lo
;;;; que diga esa celda. El desplegable se alimenta de la columna de donde
;;;; salen las secciones, filas de reserva incluidas, asi que un valor nuevo
;;;; aparece en la lista en cuanto se escribe.
;;;;
;;;; Las secciones pueden crecer si su dominio es (los CAMPO de COLECCION) y
;;;; esa coleccion crece, o si no hay dominio y crece la coleccion de la
;;;; vista. Una enumeracion escrita a mano no crece.

(in-package #:situacion.excel)

(defparameter +fila-del-selector+ 2
  "La fila del selector: debajo del titulo y encima de la fila del eje de
   columnas. La etiqueta va en A y el valor en B.")

(defun celda-del-selector ()
  "La celda del valor del selector, como se cita en las formulas."
  (format nil "$B$~d" +fila-del-selector+))

(defun conjunto-de-las-secciones (vista)
  "El conjunto (los CAMPO de COLECCION) que da las secciones de VISTA, o NIL
   si su dominio es otra cosa o no tiene."
  (let ((dominio (nucleo:dominio-de-secciones vista)))
    (and (typep dominio 'nucleo:conjunto)
         (null (nucleo:condicion dominio))
         dominio)))

(defun secciones-pueden-crecer-p (plan vista)
  "Cierto si a VISTA le pueden aparecer secciones despues de generar."
  (flet ((crece-p (nombre)
           (let ((c (nucleo:coleccion-llamada (situacion plan) nombre)))
             (and c (eq (nucleo:crecimiento c) :crece)))))
    (let ((conjunto (conjunto-de-las-secciones vista)))
      (cond ((null (nucleo:secciones vista)) nil)
            (conjunto (crece-p (nucleo:coleccion conjunto)))
            ((null (nucleo:dominio-de-secciones vista)) (crece-p (nucleo:fuente vista)))
            (t nil)))))

(defun lleva-selector-p (a plan vista)
  "Cierto si VISTA lleva una pestana con selector ademas de las de sus
   secciones. Una rejilla de entrada no la lleva: tiene el dato y no busca.
   Una vista en archivos aparte tampoco: no se lee desde el libro."
  (and (secciones-pueden-crecer-p plan vista)
       (not (member (nucleo:nombre vista) (vistas-en-archivo a)))
       (not (and (nucleo:es-entrada vista)
                 (null (motivo-sin-rejilla-de-entrada a plan vista))))))

(defun rango-del-selector (plan vista)
  "El rango de donde salen los valores del desplegable del selector: la
   columna del conjunto de las secciones, o la de la propia vista si no
   tiene dominio, con sus filas de reserva."
  (let* ((conjunto (conjunto-de-las-secciones vista))
         (hoja (hoja-de plan (if conjunto (nucleo:coleccion conjunto) (nucleo:fuente vista))))
         (letra (columna-de hoja (if conjunto (nucleo:campo conjunto) (nucleo:secciones vista)))))
    (format nil "~a!$~a$~d:$~a$~d" (entrecomillar (nombre hoja))
            letra (fila-primera hoja) letra (fila-ultima hoja))))

(defun seccion-en-formula (cruce)
  "La seccion de CRUCE como se escribe en una formula: la celda del selector,
   el valor escrito si la pestana es de una seccion, o NIL si la vista no se
   parte."
  (cond ((selector cruce) (celda-del-selector))
        ((seccion cruce) (cadena-excel (nucleo:como-texto (seccion cruce))))))

(defun celdas-del-selector (plan cruce)
  "La etiqueta y el valor inicial del selector: la primera seccion."
  (let* ((vista (vista cruce))
         (coleccion (nucleo:coleccion-llamada (situacion plan) (nucleo:fuente vista)))
         (campo (nucleo:campo-llamado coleccion (nucleo:secciones vista))))
    (list (list (cons "celda" (format nil "A~d" +fila-del-selector+))
                (cons "valor" (format nil "~a:" (if campo
                                                    (nucleo:etiqueta campo)
                                                    (nucleo:como-texto (nucleo:secciones vista))))))
          (list (cons "celda" (format nil "B~d" +fila-del-selector+))
                (cons "valor" (seccion cruce))))))

(defun validacion-del-selector (plan cruce)
  "El desplegable del selector. Avisa y deja escribir: un valor que no esta
   en la lista solo deja la rejilla vacia."
  (list (cons "rango" (format nil "B~d" +fila-del-selector+))
        (cons "tipo" "lista")
        (cons "lista" (rango-del-selector plan (vista cruce)))
        (cons "valores" :lista-vacia)
        (cons "bloquea" :false)))

(defun anotar-selector (vista)
  "Lo que la pestana con selector cambia en la particion, dicho en el informe."
  (protocolo:rebajar-en-informe
   'protocolo:con-particion-de-vista (format nil "~a (elegir)" (nucleo:etiqueta vista)) :emula
   (format nil "la pestana ~a (elegir) ensena la seccion que se escoja en su~@
                desplegable, y una seccion anadida despues de generar se ve ahi~@
                sin regenerar. Limite: sin dominio declarado, el desplegable lista~@
                la columna de la vista tal cual, con sus repeticiones."
           (nucleo:etiqueta vista))))
