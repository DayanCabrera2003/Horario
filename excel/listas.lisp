;;;; La hoja oculta de los desplegables.
;;;;
;;;; Un desplegable de hoja de calculo puede llevar su lista escrita dentro de
;;;; la validacion, como "a,b,c", o apuntar a un rango. La lista escrita se
;;;; parte por las comas y no admite comillas: la categoria "Aseo, Hogar" se
;;;; convertia en dos opciones, y con :AL-VIOLAR IMPEDIR el valor legitimo
;;;; quedaba rechazado. Tambien tiene un tope de 255 caracteres.
;;;;
;;;; Por eso los valores de cada desplegable se escriben en una columna de una
;;;; hoja auxiliar oculta, y la validacion apunta a ese rango. La hoja no la
;;;; nombra el lenguaje: es maquinaria de esta arquitectura.

(in-package #:situacion.excel)

(defparameter +fila-primera-de-listas+ 4
  "Donde empieza cada lista. Por encima va el titulo de la hoja.")

(defun necesita-listas-p (plan)
  "Cierto si alguna coleccion tiene un campo de entrada con dominio."
  (some (lambda (coleccion)
          (some #'nucleo:dominio (nucleo:campos-de-rol coleccion :entrada)))
        (nucleo:colecciones (situacion plan))))

(defun registrar-lista (plan valores)
  "Reserva una columna de la hoja de listas para VALORES y devuelve el rango
   absoluto que la validacion tiene que citar. Dos desplegables con los
   mismos valores comparten columna."
  (let ((existente (assoc valores (listas plan) :test #'equal)))
    (unless existente
      (setf existente (cons valores (letra-de-columna (length (listas plan)))))
      (setf (listas plan) (append (listas plan) (list existente))))
    (let ((letra (cdr existente)))
      (format nil "~a!$~a$~d:$~a$~d"
              (entrecomillar (nombre-de-listas plan))
              letra +fila-primera-de-listas+
              letra (+ +fila-primera-de-listas+ (max 0 (1- (length valores))))))))

(defun plano-de-listas (plan)
  "El plano de la hoja de listas: una columna por desplegable, oculta."
  (list (cons "nombre" (nombre-de-listas plan))
        (cons "titulo" "Listas de los desplegables")
        (cons "auxiliar" "listas")
        (cons "oculta" t)
        (cons "fila_encabezado" (1- +fila-primera-de-listas+))
        (cons "fila_primera" +fila-primera-de-listas+)
        (cons "capacidad" (max 1 (reduce #'max (mapcar (lambda (l) (length (car l)))
                                                       (listas plan))
                                         :initial-value 0)))
        (cons "color_pestana" "BFBFBF")
        (cons "encabezados" :lista-vacia)
        (cons "celdas" (lista (loop for (valores . letra) in (listas plan)
                                    append (loop for v in valores
                                                 for f from +fila-primera-de-listas+
                                                 collect (list (cons "celda"
                                                                     (format nil "~a~d" letra f))
                                                               (cons "valor" v))))))
        (cons "formulas" :lista-vacia)
        (cons "editables" :lista-vacia)
        (cons "validaciones" :lista-vacia)
        (cons "formatos_condicionales" :lista-vacia)
        (cons "rangos_nombrados" :lista-vacia)
        (cons "leyenda" :lista-vacia)))
