;;;; Que tablas se dibujan, y en que orden van sus filas.
;;;;
;;;; DECISION (robustez, 2026-10-17): cada vista de lista se dibuja, con su
;;;; etiqueta y su agrupacion. Antes las tres arquitecturas dibujaban una
;;;; tabla por COLECCION, con la etiqueta de la coleccion y la agrupacion de
;;;; la primera vista que agrupara: dos vistas de lista sobre los mismos
;;;; prestamos, una por lector y otra por sala, salian como una sola tabla
;;;; por lector, y el informe de conformidad decia que se cumplian las dos.
;;;;
;;;; Una coleccion que no tiene ninguna vista de lista se sigue dibujando,
;;;; con su etiqueta: es donde estan sus datos (las casillas de un horario que
;;;; solo se ve en rejillas, por ejemplo).
;;;;
;;;; Agrupar es solo el orden en que se presentan las filas, con una cabecera
;;;; por grupo; los datos no se mueven. Los grupos salen en orden de primera
;;;; aparicion, y dentro de cada uno las filas conservan el suyo.

(in-package #:situacion.nucleo)

(defun vistas-de-lista (situacion)
  "Las vistas de SITUACION que no son cruzadas, en el orden declarado."
  (remove-if #'cruzada-p (vistas situacion)))

(defun vistas-de-lista-de (situacion coleccion)
  "Las vistas de lista cuya fuente es COLECCION (un nombre)."
  (remove-if-not (lambda (v) (eq (fuente v) coleccion)) (vistas-de-lista situacion)))

(defun vista-de-datos (situacion coleccion)
  "La vista de lista que presenta la tabla de datos de COLECCION: la de
   entrada si la hay, y si no la primera. NIL si no tiene ninguna."
  (let ((suyas (vistas-de-lista-de situacion coleccion)))
    (or (find-if #'es-entrada suyas) (first suyas))))

(defun colecciones-sin-vista-de-lista (situacion)
  "Las colecciones de SITUACION que ninguna vista de lista presenta."
  (remove-if (lambda (c) (vistas-de-lista-de situacion (nombre c)))
             (colecciones situacion)))

(defun filas-en-orden-de-presentacion (entorno coleccion agrupacion)
  "Las filas de COLECCION (un nombre) en el orden en que se presentan, como
   lista de (INDICE . CABECERA): INDICE es la posicion de la fila en la
   coleccion y CABECERA el valor de su grupo si la fila abre uno, o NIL.
   Sin AGRUPACION es el orden de la coleccion, sin cabeceras."
  (let* ((filas (filas-de entorno coleccion))
         (pares (loop for f in filas for i from 0 collect (cons i f))))
    (if (null agrupacion)
        (mapcar (lambda (par) (cons (car par) nil)) pares)
        (let ((grupos '()))
          (dolist (par pares)
            (let* ((valor (valor-de-campo entorno (cdr par) agrupacion))
                   (grupo (assoc valor grupos :test #'iguales-p)))
              (if grupo
                  (push (car par) (cdr grupo))
                  (push (list valor (car par)) grupos))))
          (loop for (valor . indices) in (nreverse grupos)
                append (loop for indice in (reverse indices)
                             for primera = t then nil
                             collect (cons indice (and primera
                                                       (if (vacio-p valor) "" valor)))))))))
