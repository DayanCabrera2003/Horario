;;;; Las macros de declaracion.
;;;;
;;;; Una sola responsabilidad: convertir las formas de declaracion -
;;;; situacion, coleccion, campo, marca, vista, parametro - en nodos del
;;;; nucleo, en tiempo de expansion.
;;;;
;;;; Esto es el compilador del lenguaje. No hay otro: el analisis lexico y
;;;; sintactico lo hace el interprete de Lisp, que es el paso 5 de los seis
;;;; de Arcia Corcho (2017) desapareciendo por completo.

(in-package #:situacion.lenguaje)

(defvar *situaciones* (make-hash-table :test #'equal)
  "Las situaciones declaradas, por nombre. Permite que las pruebas y los
   backends encuentren una descripcion sin que el que la escribio tenga que
   exportar nada.")

(defun registrar-situacion (situacion)
  (setf (gethash (symbol-name (nucleo:nombre situacion)) *situaciones*) situacion))

(defun situacion-llamada (nombre)
  (gethash (if (symbolp nombre) (symbol-name nombre) nombre) *situaciones*))

(defun situaciones-declaradas ()
  (loop for s being the hash-values of *situaciones* collect s))

;;; ---------------------------------------------------------------------
;;; Utilidades de lectura de opciones
;;; ---------------------------------------------------------------------

(defun como-clave (simbolo)
  "Convierte ROL FIJO, TIPO ENTERO o SEVERIDAD ADVERTENCIA en :FIJO, :ENTERO
   y :ADVERTENCIA. El usuario escribe simbolos sueltos porque se leen mejor;
   el modelo guarda palabras clave porque se comparan mejor."
  (cond ((null simbolo) nil)
        ((keywordp simbolo) simbolo)
        ((symbolp simbolo) (intern (symbol-name simbolo) :keyword))
        (t simbolo)))

(defun partir-opciones (lista)
  "Separa LISTA en (VALUES OPCIONES RESTO).

   OPCIONES son los pares clave-valor; RESTO es todo lo demas, en orden. Un
   campo derivado lleva su expresion suelta al final, sin palabra clave,
   porque (campo faltan :rol derivado (- ...)) se lee mejor que
   (campo faltan :rol derivado :formula (- ...))."
  (let ((opciones '()) (resto '()))
    (loop while lista
          do (let ((x (pop lista)))
               (if (keywordp x)
                   (progn (push x opciones) (push (pop lista) opciones))
                   (push x resto))))
    (values (nreverse opciones) (nreverse resto))))

(defun opcion (opciones clave &optional por-defecto)
  (let ((p (position clave opciones)))
    (if p (nth (1+ p) opciones) por-defecto)))

(defun opcion-presente-p (opciones clave)
  (and (position clave opciones) t))

(defun cabeza-es (forma nombre)
  (and (consp forma) (es (first forma) nombre)))

;;; ---------------------------------------------------------------------
;;; Campos
;;; ---------------------------------------------------------------------

(defun compilar-campo (forma)
  "(campo NOMBRE :rol ... :tipo ... [:etiqueta ...] [:dominio ...]
                 [:al-violar ...] [:opcional t] [EXPRESION])"
  (destructuring-bind (cabeza nombre &rest cola) forma
    (declare (ignore cabeza))
    (multiple-value-bind (opciones resto) (partir-opciones cola)
      (let* ((rol (como-clave (opcion opciones :rol 'nucleo::fijo)))
             (dominio (opcion opciones :dominio))
             (expresion (first resto)))
        (when (and (eq rol :derivado) (null expresion))
          (error "El campo ~a es derivado y no dice como se calcula." nombre))
        (when (and (not (eq rol :derivado)) expresion)
          (error "El campo ~a no es derivado pero trae una expresion.~@
                  Si querias que se calculara, ponle :ROL DERIVADO." nombre))
        (when (and dominio (not (eq rol :entrada)))
          (error "El campo ~a tiene :DOMINIO pero su rol no es ENTRADA.~@
                  Un dominio dice que puede escribir el usuario; si nadie~@
                  escribe ahi, no significa nada." nombre))
        `(nucleo:hacer-campo
          :nombre ',(normalizar nombre)
          :etiqueta ,(opcion opciones :etiqueta (string-capitalize (symbol-name nombre)))
          :tipo ,(como-clave (opcion opciones :tipo 'nucleo::texto))
          :rol ,rol
          :opcional ,(opcion opciones :opcional nil)
          :dominio ,(when dominio (compilar-expresion dominio))
          :al-violar ,(como-clave (opcion opciones :al-violar 'nucleo::advertir))
          :expresion ,(when expresion (compilar-expresion expresion)))))))

;;; ---------------------------------------------------------------------
;;; Colecciones
;;; ---------------------------------------------------------------------

(defun compilar-coleccion (forma)
  "(coleccion NOMBRE (:etiqueta ...) (:clave ...) (:orden ...) (:crece)
              (:datos ((...) ...)) (campo ...) ...)"
  (destructuring-bind (cabeza nombre &rest cuerpo) forma
    (declare (ignore cabeza))
    (let ((etiqueta (string-capitalize (symbol-name nombre)))
          (clave '()) (orden nil) (crecimiento nil) (datos nil) (campos '())
          (origen :declarada))
      (dolist (f cuerpo)
        (cond
          ((cabeza-es f "CAMPO") (push (compilar-campo f) campos))
          ((eq (first f) :etiqueta) (setf etiqueta (second f)))
          ((eq (first f) :clave) (setf clave (normalizar-lista (rest f))))
          ((eq (first f) :orden)
           ;; Un solo campo. Antes se tomaba el primero y se tiraba el resto
           ;; en silencio, que es el mismo tipo de fallo que este trabajo le
           ;; reprocha a 2026: una descripcion que se lee como correcta y
           ;; significa otra cosa.
           (when (cddr f)
             (error "(:orden ~{~a~^ ~}) declara mas de un campo, y el orden~@
                     solo admite uno.~@
                     Si de verdad hace falta ordenar por varios, no es un~@
                     problema de sintaxis: es que al lenguaje le falta el~@
                     orden compuesto."
                    (rest f)))
           (setf orden (normalizar (second f))))
          ((eq (first f) :crece) (setf crecimiento :crece))
          ((eq (first f) :datos) (setf datos (second f)))
          ;; (:una-fila-por campo :de coleccion) y (:una-sola-fila)
          ((eq (first f) :una-fila-por)
           (setf origen (list :una-fila-por (normalizar (second f))
                              :de (normalizar (palabra-clave-de f :de)))))
          ((eq (first f) :una-sola-fila) (setf origen '(:una-sola-fila)))
          (t (error "No se como leer ~s dentro de la coleccion ~a" f nombre))))
      `(nucleo:hacer-coleccion
        :nombre ',(normalizar nombre)
        :etiqueta ,etiqueta
        :campos (list ,@(nreverse campos))
        :clave ',clave
        :orden ',orden
        :crecimiento ,crecimiento
        :origen ',origen
        :datos ',datos))))

;;; ---------------------------------------------------------------------
;;; Marcas
;;; ---------------------------------------------------------------------

(defun compilar-marca (forma)
  "(marca NOMBRE :cuando EXPR :sobre (campo ...) :severidad ... [:explica EXPR])"
  (destructuring-bind (cabeza nombre &rest opciones) forma
    (declare (ignore cabeza))
    (let ((cuando (opcion opciones :cuando))
          (sobre (opcion opciones :sobre))
          (en (opcion opciones :en))
          (explica (opcion opciones :explica)))
      (unless cuando (error "La marca ~a no dice :CUANDO se cumple." nombre))
      (unless sobre (error "La marca ~a no dice :SOBRE que campos senala." nombre))
      `(nucleo:hacer-marca
        :nombre ',(normalizar nombre)
        :coleccion ',(normalizar en)
        :condicion ,(compilar-expresion cuando)
        :alcance ',(normalizar-lista sobre)
        :severidad ,(como-clave (opcion opciones :severidad 'nucleo::advertencia))
        :explicacion ,(when explica (compilar-expresion explica))))))

;;; ---------------------------------------------------------------------
;;; Vistas y parametros
;;; ---------------------------------------------------------------------

(defun compilar-vista (forma)
  "(vista NOMBRE :de COLECCION [:etiqueta ...] [:entrada t]
                 [:secciones CAMPO] [:agrupada-por CAMPO] [:donde EXPRESION]
                 [:unica-salvo MARCA]
                 [:filas CAMPO :columnas CAMPO :muestra CAMPO])"
  (destructuring-bind (cabeza nombre &rest opciones) forma
    (declare (ignore cabeza))
    (let ((fuente (opcion opciones :de))
          (donde (opcion opciones :donde)))
      (unless fuente (error "La vista ~a no dice :DE que coleccion es." nombre))
      `(nucleo:hacer-vista
        :nombre ',(normalizar nombre)
        :etiqueta ,(opcion opciones :etiqueta (string-capitalize (symbol-name nombre)))
        :fuente ',(normalizar fuente)
        :secciones ',(normalizar (opcion opciones :secciones))
        :agrupacion ',(normalizar (opcion opciones :agrupada-por))
        :filtro ,(when donde (compilar-expresion donde))
        :conflicto ',(normalizar (opcion opciones :unica-salvo))
        :eje-de-filas ',(normalizar (opcion opciones :filas))
        :eje-de-columnas ',(normalizar (opcion opciones :columnas))
        :lo-que-se-muestra ',(normalizar (opcion opciones :muestra))
        :es-entrada ,(opcion opciones :entrada nil)))))

(defun compilar-parametro (forma)
  "(parametro NOMBRE :tipo ... :valor ... [:rol ...] [:etiqueta ...])"
  (destructuring-bind (cabeza nombre &rest opciones) forma
    (declare (ignore cabeza))
    `(nucleo:hacer-parametro
      :nombre ',(normalizar nombre)
      :etiqueta ,(opcion opciones :etiqueta (string-capitalize (symbol-name nombre)))
      :tipo ,(como-clave (opcion opciones :tipo 'nucleo::numero))
      :rol ,(como-clave (opcion opciones :rol 'nucleo::fijo))
      :valor ,(opcion opciones :valor))))

;;; ---------------------------------------------------------------------
;;; La macro principal
;;; ---------------------------------------------------------------------

(defmacro defsituacion (nombre opciones &body cuerpo)
  "Declara una situacion tabular.

   NOMBRE es un simbolo. OPCIONES es una lista de pares clave-valor, de
   momento solo :ETIQUETA. El cuerpo lleva parametros, colecciones, marcas y
   vistas, en el orden que quiera el autor.

   Define una variable con el nombre dado y registra la situacion para que se
   pueda encontrar por nombre desde cualquier sitio."
  (let ((parametros '()) (colecciones '()) (marcas '()) (vistas '()))
    (dolist (forma cuerpo)
      (cond
        ((cabeza-es forma "PARAMETRO") (push (compilar-parametro forma) parametros))
        ((cabeza-es forma "COLECCION") (push (compilar-coleccion forma) colecciones))
        ((cabeza-es forma "MARCA") (push (compilar-marca forma) marcas))
        ((cabeza-es forma "VISTA") (push (compilar-vista forma) vistas))
        (t (error "No se como leer ~s dentro de DEFSITUACION ~a."
                  (if (consp forma) (first forma) forma) nombre))))
    `(progn
       (defparameter ,nombre
         (nucleo:hacer-situacion
          :nombre ',(normalizar nombre)
          :etiqueta ,(opcion opciones :etiqueta (string-capitalize (symbol-name nombre)))
          :parametros (list ,@(nreverse parametros))
          :colecciones (list ,@(nreverse colecciones))
          :marcas (list ,@(nreverse marcas))
          :vistas (list ,@(nreverse vistas))))
       (registrar-situacion ,nombre)
       ',nombre)))
