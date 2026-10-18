;;;; Las hojas derivadas de las vistas de lista.
;;;;
;;;; Una coleccion tiene una sola hoja de datos: la de su vista de datos (la
;;;; de entrada, o la primera; nucleo/tablas.lisp). Cada OTRA vista de lista
;;;; sobre la misma coleccion sale como una hoja derivada: de solo lectura,
;;;; con cada celda apuntando a la celda de la hoja de datos que le
;;;; corresponde, y con las filas en el orden de su agrupacion y una
;;;; cabecera por grupo.
;;;;
;;;; Antes no existia: una coleccion era una hoja, y la segunda vista de
;;;; lista se perdia sin que el informe lo dijera.
;;;;
;;;; Es una emulacion, con su limite: el orden de las filas y las cabeceras
;;;; de grupo se fijan AL GENERAR. Si despues una fila cambia de grupo en la
;;;; hoja de datos, sus valores se ponen al dia en la derivada, pero no se
;;;; mueve de sitio. Es el mismo coste que el de las tablas cruzadas.

(in-package #:situacion.excel)

(defclass hoja-de-vista ()
  ((vista :accessor vista :initarg :vista)
   (hoja-origen :accessor hoja-origen :initarg :hoja-origen
                :documentation "La hoja de datos de la coleccion.")
   (orden :accessor orden-de-filas :initarg :orden
          :documentation
          "Las filas en el orden en que se presentan, como (INDICE . CABECERA):
           NUCLEO:FILAS-EN-ORDEN-DE-PRESENTACION.")
   (nombre :accessor nombre :initform nil)
   (titulo :accessor titulo :initform nil))
  (:documentation "Una vista de lista que no es la de datos de su coleccion."))

(defun vista-derivada-p (situacion vista)
  "Cierto si VISTA es de lista y no es la vista de datos de su coleccion."
  (and (not (nucleo:cruzada-p vista))
       (not (eq vista (nucleo:vista-de-datos situacion (nucleo:fuente vista))))))

(defun planificar-vistas-derivadas (plan)
  "Una hoja derivada por cada vista de lista que no es la de datos."
  (setf (vistas-derivadas plan)
        (loop for vista in (nucleo:vistas-de-lista (situacion plan))
              when (vista-derivada-p (situacion plan) vista)
                collect (make-instance 'hoja-de-vista
                                       :vista vista
                                       :hoja-origen (hoja-de plan (nucleo:fuente vista))
                                       :orden (nucleo:filas-en-orden-de-presentacion
                                               (entorno plan) (nucleo:fuente vista)
                                               (nucleo:agrupacion vista))))))

(defun referencia-a-origen (origen letra fila)
  "La celda LETRA,FILA de la hoja ORIGEN, como valor: en blanco si esta en
   blanco, y no 0, que es lo que da una referencia a una celda vacia."
  (let ((celda (format nil "~a!$~a$~d" (entrecomillar (nombre origen)) letra fila)))
    (format nil "=IF(ISBLANK(~a),\"\",~a)" celda celda)))

(defun plano-de-vista-derivada (derivada)
  "El plano de una hoja derivada: los encabezados de la hoja de datos, una
   linea por cabecera de grupo y una por fila, cada celda apuntando a la de
   la hoja de datos."
  (let* ((origen (hoja-origen derivada))
         (coleccion (coleccion origen))
         (campos (nucleo:campos coleccion))
         (fila-enc 3)
         (encabezados '()) (celdas '()) (formulas '()) (filas '()) (grupos '())
         (fila fila-enc))
    (setf encabezados
          (append
           (loop for campo in campos
                 for i from 0
                 collect (list (cons "celda" (format nil "~a~d" (letra-de-columna i) fila-enc))
                               (cons "campo" (string-downcase (symbol-name (nucleo:nombre campo))))
                               (cons "rol" "derivado")
                               (cons "texto" (nucleo:etiqueta campo))))
           (when (columna-de-estado origen)
             (list (list (cons "celda" (format nil "~a~d" (letra-de-columna (length campos))
                                               fila-enc))
                         (cons "campo" "__estado__")
                         (cons "rol" "derivado")
                         (cons "texto" (rotulo-de-estado coleccion)))))))
    (loop for (indice . cabecera) in (orden-de-filas derivada)
          for fila-origen = (+ (fila-primera origen) indice)
          do (when cabecera
               (incf fila)
               (push fila grupos)
               (push (list (cons "celda" (format nil "A~d" fila))
                           (cons "valor" (nucleo:como-texto cabecera)))
                     celdas))
             (incf fila)
             (push (list (cons "fila" fila) (cons "indice" indice)) filas)
             (loop for campo in campos
                   for i from 0
                   do (push (list (cons "celda" (format nil "~a~d" (letra-de-columna i) fila))
                                  (cons "formula"
                                        (referencia-a-origen
                                         origen (columna-de origen (nucleo:nombre campo))
                                         fila-origen)))
                            formulas))
             (when (columna-de-estado origen)
               (push (list (cons "celda" (format nil "~a~d" (letra-de-columna (length campos))
                                                 fila))
                           (cons "formula" (referencia-a-origen
                                            origen (columna-de-estado origen) fila-origen)))
                     formulas)))
    (list (cons "nombre" (nombre derivada))
          (cons "titulo" (titulo derivada))
          (cons "vista" (list (cons "vista" (string-downcase
                                             (symbol-name (nucleo:nombre (vista derivada)))))
                              (cons "coleccion" (nombre-de-coleccion coleccion))
                              (cons "estado" (if (columna-de-estado origen)
                                                 (letra-de-columna (length campos))
                                                 :false))
                              (cons "filas" (lista (nreverse filas)))))
          (cons "fila_encabezado" fila-enc)
          (cons "fila_primera" (1+ fila-enc))
          (cons "capacidad" (max 1 (- fila fila-enc)))
          (cons "color_pestana" "BDD7EE")
          (cons "encabezados" (lista encabezados))
          (cons "celdas" (lista (nreverse celdas)))
          (cons "formulas" (lista (nreverse formulas)))
          (cons "filas_de_grupo" (lista (nreverse grupos)))
          (cons "editables" :lista-vacia)
          (cons "validaciones" :lista-vacia)
          (cons "formatos_condicionales" :lista-vacia)
          (cons "rangos_nombrados" :lista-vacia)
          (cons "leyenda" :lista-vacia))))
