;;;; El oraculo de las tablas cruzadas.
;;;;
;;;; El oraculo de valores (ESCRIBIR-ESPERADO) dice que vale cada campo de
;;;; cada fila. No dice nada de las vistas, y una tabla cruzada es justo lo
;;;; que una arquitectura puede dibujar mal con todos los valores bien: en la
;;;; hoja de calculo, las pestanas por profesor del Saul Delgado salian vacias
;;;; y la demostracion no tenia con que compararlas.
;;;;
;;;; Este archivo calcula, para cada vista cruzada, que filas caen en cada
;;;; casilla. Lo hace solo con el nucleo -sin mirar ninguna arquitectura- y
;;;; por eso sirve de referencia para todas.

(in-package #:situacion.demostracion)

(defun agrupar-por (entorno filas campo)
  "FILAS repartidas por el valor de CAMPO, como lista de (VALOR . FILAS) en
   orden de aparicion. Las filas sin valor en CAMPO no entran en ningun
   grupo."
  (let ((grupos '()))
    (dolist (f filas (nreverse (mapcar (lambda (g) (cons (car g) (reverse (cdr g))))
                                       grupos)))
      (let ((valor (nucleo:valor-de-campo entorno f campo)))
        (unless (nucleo:vacio-p valor)
          (let ((grupo (assoc valor grupos :test #'nucleo:iguales-p)))
            (if grupo
                (push f (cdr grupo))
                (push (list valor f) grupos))))))))

(defun casillas-de (entorno vista filas)
  "Las casillas ocupadas de un cuadrante: para cada par de valores de los dos
   ejes, lo que muestran las filas que caen ahi, en orden."
  (loop for (valor-fila . en-la-fila)
          in (agrupar-por entorno filas (nucleo:eje-de-filas vista))
        append (loop for (valor-columna . en-la-casilla)
                       in (agrupar-por entorno en-la-fila
                                       (nucleo:eje-de-columnas vista))
                     collect (list (cons "fila" valor-fila)
                                   (cons "columna" valor-columna)
                                   (cons "valores"
                                         (loop for f in en-la-casilla
                                               collect (nucleo:valor-de-campo
                                                        entorno f
                                                        (nucleo:lo-que-se-muestra
                                                         vista))))))))

(defun cuadrantes-de (entorno vista)
  "Un cuadrante por seccion de VISTA, o uno solo si no se parte."
  (let ((filas (nucleo:filas-que-presenta entorno vista)))
    (if (nucleo:secciones vista)
        (loop for (seccion . suyas)
                in (agrupar-por entorno filas (nucleo:secciones vista))
              collect (list (cons "seccion" (nucleo:como-texto seccion))
                            (cons "titulo" (format nil "~a - ~a" (nucleo:etiqueta vista)
                                                   (nucleo:como-texto seccion)))
                            (cons "casillas"
                                  (situacion.excel::lista
                                   (casillas-de entorno vista suyas)))))
        (list (list (cons "seccion" "")
                    (cons "titulo" (nucleo:etiqueta vista))
                    (cons "casillas"
                          (situacion.excel::lista
                           (casillas-de entorno vista filas))))))))

(defun escribir-cruces-esperados (situacion datos destino)
  "Lo que tiene que haber en cada casilla de cada vista cruzada, segun el
   nucleo.

   Una casilla lleva la LISTA de lo que muestran sus filas. Casi siempre es
   un solo valor; son varios cuando la vista declaro (:UNICA-SALVO <marca>)
   y el conflicto existe, y como ensenarlos es cosa de cada arquitectura.

   Se reutiliza el serializador de la arquitectura de Excel por la misma
   razon que en ESCRIBIR-ESPERADO: es el que hay."
  (let ((entorno (nucleo:hacer-entorno situacion datos)))
    (situacion.excel::escribir-plano
     (situacion.excel::lista
      (loop for vista in (nucleo:vistas situacion)
            when (nucleo:cruzada-p vista)
              collect (list (cons "vista" (string-downcase
                                           (symbol-name (nucleo:nombre vista))))
                            (cons "cuadrantes"
                                  (situacion.excel::lista
                                   (cuadrantes-de entorno vista))))))
     destino)))
