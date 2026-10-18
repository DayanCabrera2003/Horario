;;;; Los ejes y las secciones de una vista cruzada.
;;;;
;;;; DECISION (robustez, 2026-10-17): mientras el lenguaje no permita declarar
;;;; el orden y el dominio de los ejes (fase 2, hueco C1), todas las
;;;; secciones de una vista cruzada comparten los mismos valores de filas y
;;;; de columnas: los que toman los ejes en todas las filas que la vista
;;;; presenta, no solo en las de cada seccion. Antes cada seccion tenia los
;;;; suyos, en su propio orden de aparicion: en el Saul, la pestana de un
;;;; profesor era una rejilla de 1 x 2 y la de un aula tenia las columnas en
;;;; el orden M, V, L, MI, J.
;;;;
;;;; El orden de un eje es el :ORDEN de la coleccion si el eje es ese campo, y
;;;; si no el de primera aparicion. Las secciones se ordenan por su valor.
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

(defun valores-de-eje (entorno vista campo)
  "Los valores del eje CAMPO de VISTA, comunes a todas sus secciones."
  (let ((valores (valores-en-orden-de-aparicion entorno (filas-que-presenta entorno vista)
                                                campo))
        (coleccion (coleccion-llamada (situacion entorno) (fuente vista))))
    (if (and coleccion (eq (orden coleccion) campo))
        (stable-sort (copy-list valores) #'menor-p)
        valores)))

(defun secciones-de-vista (entorno vista)
  "Los valores de seccion de VISTA ordenados, o (NIL) si no se parte."
  (if (secciones vista)
      (stable-sort (valores-en-orden-de-aparicion entorno (filas-que-presenta entorno vista)
                                                  (secciones vista))
                   #'menor-p)
      (list nil)))
