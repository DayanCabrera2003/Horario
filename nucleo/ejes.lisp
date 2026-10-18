;;;; Los ejes y las secciones de una vista cruzada.
;;;;
;;;; DOS REGLAS, SEGUN SE DECLARE O NO EL DOMINIO.
;;;;
;;;; Sin dominio (el eje escrito solo con el nombre del campo), los valores
;;;; salen de los datos: los que toma el eje en todas las filas que la vista
;;;; presenta, comunes a todas las secciones. Su orden es el :ORDEN de la
;;;; coleccion si el eje es ese campo, y si no el de primera aparicion. Las
;;;; secciones se ordenan por su valor. Antes de la fase 1 de robustez
;;;; (2026-10-17) cada seccion tenia sus propios ejes: en el Saul la pestana
;;;; de un profesor era una rejilla de 1 x 2 y la de un aula tenia las
;;;; columnas en el orden M, V, L, MI, J.
;;;;
;;;; Con dominio (fase 2, hueco C1: el eje escrito (CAMPO :DOMINIO
;;;; EXPRESION)), los valores son los del dominio, todos y en su orden,
;;;; aparezcan o no en los datos. Asi existe la columna de un horario que
;;;; nadie ha escrito todavia, que en una hoja de calculo -donde la rejilla se
;;;; fija al generar- era informacion perdida. Un valor de los datos que no
;;;; este en el dominio no se esconde: se anade al final (en orden de
;;;; aparicion en un eje, ordenado en las secciones) y
;;;; AVISO-FUERA-DE-DOMINIO lo dice, para que cada arquitectura lo ensene.
;;;;
;;;; Esta aqui, en el nucleo, porque es la misma regla para las tres
;;;; arquitecturas (la pagina la repite en JavaScript con la misma
;;;; comparacion): lo que se dibuja en una rejilla no puede depender del
;;;; destino.

(in-package #:situacion.nucleo)

(defun filas-que-presenta (entorno vista)
  "Las filas de la coleccion de VISTA que pasan su filtro, en su orden."
  (let ((filas (filas-de entorno (fuente vista))))
    (if (null (filtro vista))
        filas
        (remove-if-not (lambda (f) (cumple-en-fila entorno f (filtro vista))) filas))))

(defun valores-en-orden-de-aparicion (entorno filas campo)
  "Los valores que toma CAMPO en FILAS, sin repetir, en orden de aparicion."
  (let ((vistos '()))
    (dolist (f filas (nreverse vistos))
      (let ((v (valor-de-campo entorno f campo)))
        (unless (or (vacio-p v) (member v vistos :test #'iguales-p))
          (push v vistos))))))

(defun valores-del-dominio (entorno dominio)
  "Los valores de la expresion de conjunto DOMINIO, normalizados y sin
   repetir, en su orden. Se evalua fuera de toda fila: un dominio de eje es
   de la vista entera."
  (remove-duplicates (mapcar #'normalizar-valor
                             (evaluar dominio (hacer-ambito) entorno '()))
                     :test #'iguales-p :from-end t))

(defun ajenos-al-dominio (valores declarados)
  "Los elementos de VALORES que no estan en DECLARADOS, en su orden."
  (remove-if (lambda (v) (member v declarados :test #'iguales-p)) valores))

(defun dominio-del-eje (vista campo)
  "La expresion de dominio que VISTA declara para su eje CAMPO, o NIL."
  (cond ((eq campo (eje-de-filas vista)) (dominio-de-filas vista))
        ((eq campo (eje-de-columnas vista)) (dominio-de-columnas vista))))

(defun valores-de-eje-segun-los-datos (entorno vista campo)
  "Los valores del eje CAMPO sacados de los datos: la regla sin dominio."
  (let ((valores (valores-en-orden-de-aparicion entorno (filas-que-presenta entorno vista)
                                                campo))
        (coleccion (coleccion-llamada (situacion entorno) (fuente vista))))
    (if (and coleccion (eq (orden coleccion) campo))
        (stable-sort (copy-list valores) #'menor-p)
        valores)))

(defun valores-de-eje (entorno vista campo)
  "Los valores del eje CAMPO de VISTA, comunes a todas sus secciones."
  (let ((de-los-datos (valores-de-eje-segun-los-datos entorno vista campo))
        (dominio (dominio-del-eje vista campo)))
    (if (null dominio)
        de-los-datos
        (let ((declarados (valores-del-dominio entorno dominio)))
          (append declarados (ajenos-al-dominio de-los-datos declarados))))))

(defun secciones-segun-los-datos (entorno vista)
  "Los valores de seccion de VISTA sacados de los datos, ordenados."
  (stable-sort (valores-en-orden-de-aparicion entorno (filas-que-presenta entorno vista)
                                              (secciones vista))
               #'menor-p))

(defun secciones-de-vista (entorno vista)
  "Los valores de seccion de VISTA en su orden, o (NIL) si no se parte."
  (cond ((null (secciones vista)) (list nil))
        ((null (dominio-de-secciones vista)) (secciones-segun-los-datos entorno vista))
        (t (let ((declarados (valores-del-dominio entorno (dominio-de-secciones vista))))
             (append declarados
                     (ajenos-al-dominio (secciones-segun-los-datos entorno vista)
                                        declarados))))))

;;; ---------------------------------------------------------------------
;;; El aviso de los valores fuera del dominio
;;; ---------------------------------------------------------------------

(defun valores-fuera-de-dominio (entorno vista)
  "Para cada eje o secciones de VISTA con dominio declarado, los valores de
   los datos que no estan en el. Lista de (CAMPO . VALORES), solo con los
   que tienen alguno."
  (loop for (campo dominio de-los-datos)
          in (list (list (eje-de-filas vista) (dominio-de-filas vista)
                         (lambda () (valores-de-eje-segun-los-datos
                                     entorno vista (eje-de-filas vista))))
                   (list (eje-de-columnas vista) (dominio-de-columnas vista)
                         (lambda () (valores-de-eje-segun-los-datos
                                     entorno vista (eje-de-columnas vista))))
                   (list (secciones vista) (dominio-de-secciones vista)
                         (lambda () (secciones-segun-los-datos entorno vista))))
        for ajenos = (and campo dominio
                          (ajenos-al-dominio (funcall de-los-datos)
                                             (valores-del-dominio entorno dominio)))
        when ajenos collect (cons campo ajenos)))

(defun aviso-fuera-de-dominio (entorno vista)
  "El texto que avisa de los valores de VISTA fuera de su dominio declarado,
   o NIL si no hay ninguno. Es el mismo en todas las arquitecturas: lo
   escriben el texto y la pagina debajo de la vista, y el informe de
   conformidad de cada una."
  (let ((fuera (valores-fuera-de-dominio entorno vista)))
    (when fuera
      (let ((coleccion (coleccion-llamada (situacion entorno) (fuente vista))))
        (format nil "Valores fuera del dominio declarado en ~a: ~{~a~^; ~}."
                (etiqueta vista)
                (loop for (campo . valores) in fuera
                      for declarado = (and coleccion (campo-llamado coleccion campo))
                      collect (format nil "~a: ~{~a~^, ~}"
                                      (if declarado (etiqueta declarado)
                                          (string-downcase (symbol-name campo)))
                                      (mapcar #'como-texto valores))))))))
