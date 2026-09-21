;;;; Que capacidades pide una descripcion.
;;;;
;;;; Una sola responsabilidad: leer una situacion y decir que necesita de la
;;;; arquitectura que la materialice. Es una funcion del dominio, no de
;;;; ningun destino, y por eso vive en el protocolo y no en cada backend: si
;;;; cada uno decidiera por su cuenta que le estan pidiendo, dos backends
;;;; darian informes distintos para la misma descripcion y el mecanismo no
;;;; significaria nada.

(in-package #:situacion.protocolo)

(defun requerimientos (situacion)
  "Las capacidades que SITUACION necesita, como lista de (CAPACIDAD NODO
   DETALLE), en orden de aparicion y sin repetir."
  (let ((pedidas '()))
    (flet ((pedir (capacidad nodo detalle)
             (unless (find capacidad pedidas :key #'first)
               (push (list capacidad nodo detalle) pedidas))))
      (dolist (coleccion (nucleo:colecciones situacion))
        (when (and (consp (nucleo:origen coleccion))
                   (eq (first (nucleo:origen coleccion)) :una-fila-por))
          (pedir 'con-agrupacion coleccion
                 (format nil "~(~a~) tiene una fila por cada ~(~a~) distinto de ~(~a~)"
                         (nucleo:nombre coleccion)
                         (second (nucleo:origen coleccion))
                         (fourth (nucleo:origen coleccion)))))
        (when (eq (nucleo:crecimiento coleccion) :crece)
          (pedir 'con-crecimiento coleccion
                 (format nil "~(~a~) sigue creciendo despues de generar"
                         (nucleo:nombre coleccion))))
        (when (nucleo:orden coleccion)
          (pedir 'con-orden-declarado coleccion
                 (format nil "~(~a~) se materializa ordenada por ~(~a~)"
                         (nucleo:nombre coleccion) (nucleo:orden coleccion))))
        (dolist (campo (nucleo:campos coleccion))
          (case (nucleo:rol campo)
            (:entrada
             (pedir 'con-entrada campo
                    (format nil "~(~a~) lo escribe el usuario"
                            (nucleo:nombre campo)))
             (when (nucleo:dominio campo)
               (pedir 'con-dominio-de-entrada campo
                      (format nil "~(~a~) solo admite ciertos valores"
                              (nucleo:nombre campo)))))
            (:derivado
             (pedir 'con-derivacion-viva campo
                    (format nil "~(~a~) se recalcula al editar"
                            (nucleo:nombre campo)))))
          ;; Lo que la expresion de un campo derivado exige por si misma.
          (when (nucleo:expresion campo)
            (nucleo:recorrer-expresion
             (nucleo:expresion campo)
             (lambda (e) (pedir-por-expresion e #'pedir))))))
      (dolist (marca (nucleo:marcas situacion))
        (pedir 'con-marcado-visual marca
               (format nil "la marca ~(~a~) senala un estado"
                       (nucleo:nombre marca)))
        (when (nucleo:explicacion marca)
          (pedir 'con-marcado-textual marca
                 (format nil "la marca ~(~a~) explica por que en palabras"
                         (nucleo:nombre marca))))
        (nucleo:recorrer-expresion
         (nucleo:condicion marca)
         (lambda (e) (pedir-por-expresion e #'pedir))))
      (dolist (vista (nucleo:vistas situacion))
        (when (nucleo:secciones vista)
          (pedir 'con-particion-de-vista vista
                 (format nil "~(~a~) se reparte en una tabla por cada ~(~a~)"
                         (nucleo:nombre vista) (nucleo:secciones vista))))
        (when (nucleo:agrupacion vista)
          (pedir 'con-agrupacion-en-vista vista
                 (format nil "las filas de ~(~a~) se separan por ~(~a~)"
                         (nucleo:nombre vista) (nucleo:agrupacion vista))))
        (when (nucleo:cruzada-p vista)
          (pedir 'con-tabla-cruzada vista
                 (format nil "~(~a~) se presenta con ~(~a~) en las filas y ~(~a~) en las columnas"
                         (nucleo:nombre vista) (nucleo:eje-de-filas vista)
                         (nucleo:eje-de-columnas vista)))))
      (when (rest (nucleo:vistas situacion))
        (pedir 'con-navegacion (first (nucleo:vistas situacion))
               (format nil "~d vistas enlazadas" (length (nucleo:vistas situacion))))))
    (nreverse pedidas)))

(defun pedir-por-expresion (e pedir)
  "Las capacidades que exige una expresion concreta."
  (typecase e
    (nucleo:agregado
     (when (eq (nucleo:operacion e) :distintas)
       (funcall pedir 'con-conteo-de-distintos e
                "hay que contar cuantos valores distintos toma un campo")))
    (nucleo:relacionadas
     (funcall pedir 'con-relacion-uno-a-muchos e
              (format nil "hay que mostrar todas las filas de ~(~a~) que se~@
                           relacionan con esta, sin limite fijo"
                      (nucleo:coleccion e))))
    (nucleo:busqueda
     (funcall pedir 'con-busqueda-por-clave e
              (format nil "hay que traer un dato de ~(~a~) a partir de una clave"
                      (nucleo:coleccion e))))
    (nucleo:vecino
     (funcall pedir 'con-orden-declarado e
              "se habla de la fila anterior o la siguiente"))))
