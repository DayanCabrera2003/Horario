;;;; La hoja de los parametros que se editan.
;;;;
;;;; Un parametro :ROL ENTRADA es una constante que el usuario cambia en el
;;;; documento: el tope de sesiones al dia de un profesor, la nota para
;;;; aprobar. Hasta el 2026-10-21 la hoja de calculo copiaba su valor dentro
;;;; de cada formula que lo usaba, y el rol no servia de nada: para pasar el
;;;; tope del Saul de 3 a 5 habia que volver a generar el libro.
;;;;
;;;; Ahora cada parametro de entrada ocupa una fila de una hoja propia, con
;;;; su etiqueta y su valor, y las formulas citan la celda del valor, que es
;;;; lo unico que se desbloquea. Un parametro :ROL FIJO sigue copiandose en
;;;; la formula: es una constante del dominio y no hay nada que editar.
;;;;
;;;; La hoja no la nombra el lenguaje: es maquinaria de esta arquitectura,
;;;; como la de los desplegables.

(in-package #:situacion.excel)

(defparameter +fila-primera-de-parametros+ 4
  "Donde va el primer parametro. Por encima, el titulo y el encabezado.")

(defun parametros-de-entrada (situacion)
  "Los parametros de SITUACION que el usuario edita, en orden de declaracion."
  (remove-if-not (lambda (p) (eq (nucleo:rol p) :entrada))
                 (nucleo:parametros situacion)))

(defun necesita-parametros-p (plan)
  "Cierto si la situacion tiene algun parametro de entrada."
  (and (parametros-de-entrada (situacion plan)) t))

(defun fila-de-parametro (plan parametro)
  "La fila de la hoja de parametros donde esta PARAMETRO, o NIL si no es de
   entrada."
  (let ((posicion (position parametro (parametros-de-entrada (situacion plan)))))
    (and posicion (+ +fila-primera-de-parametros+ posicion))))

(defun celda-de-parametro (plan parametro)
  "La referencia absoluta a la celda del valor de PARAMETRO, con su hoja, o
   NIL si PARAMETRO no tiene celda: es fijo, o la hoja no se ha nombrado."
  (let ((fila (fila-de-parametro plan parametro)))
    (and fila (nombre-de-parametros plan)
         (format nil "~a!$B$~d" (entrecomillar (nombre-de-parametros plan)) fila))))

(defun plano-de-parametros (plan)
  "El plano de la hoja de parametros: etiqueta en A, valor editable en B."
  (let* ((parametros (parametros-de-entrada (situacion plan)))
         (ultima (+ +fila-primera-de-parametros+ (1- (length parametros)))))
    (list (cons "nombre" (nombre-de-parametros plan))
          (cons "titulo" "Parametros")
          ;; El verificador no compara sus celdas con el oraculo: no son de
          ;; ninguna coleccion. Lo que importa de ella, que las formulas la
          ;; citen y respondan al cambiarla, lo comprueba la sonda de
          ;; escritura de ./demostrar.sh.
          (cons "auxiliar" "parametros")
          (cons "fila_encabezado" (1- +fila-primera-de-parametros+))
          (cons "fila_primera" +fila-primera-de-parametros+)
          (cons "capacidad" (length parametros))
          ;; Azul, como toda hoja donde se escribe a mano.
          (cons "color_pestana" "4472C4")
          (cons "encabezados"
                (lista (list (list (cons "celda" (format nil "A~d" (1- +fila-primera-de-parametros+)))
                                   (cons "campo" "parametro")
                                   (cons "rol" "fijo")
                                   (cons "texto" "Parametro"))
                             (list (cons "celda" (format nil "B~d" (1- +fila-primera-de-parametros+)))
                                   (cons "campo" "valor")
                                   (cons "rol" "entrada")
                                   (cons "texto" "Valor")))))
          (cons "celdas"
                (lista (loop for p in parametros
                             for fila from +fila-primera-de-parametros+
                             collect (list (cons "celda" (format nil "A~d" fila))
                                           (cons "valor" (nucleo:etiqueta p)))
                             collect (list (cons "celda" (format nil "B~d" fila))
                                           (cons "valor" (nucleo:valor p))))))
          (cons "formulas" :lista-vacia)
          (cons "editables" (lista (list (format nil "B~d:B~d"
                                                 +fila-primera-de-parametros+ ultima))))
          (cons "validaciones" :lista-vacia)
          (cons "formatos_condicionales" :lista-vacia)
          (cons "rangos_nombrados" :lista-vacia)
          (cons "leyenda" :lista-vacia))))
