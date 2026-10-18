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
             (tipo (como-clave (opcion opciones :tipo 'nucleo::texto)))
             (dominio (or (opcion opciones :dominio)
                          ;; Plan aprobado de tipos, seccion 3: un booleano
                          ;; que escribe el usuario solo admite "si" o "no",
                          ;; como cualquier otro campo con dominio.
                          (when (and (eq rol :entrada) (eq tipo :booleano))
                            '(uno-de "si" "no"))))
             (expresion (first resto)))
        (when (and (eq rol :derivado) (null expresion))
          (error "El campo ~a es derivado y no dice como se calcula." nombre))
        (when (and (not (eq rol :derivado)) expresion)
          (error "El campo ~a no es derivado pero trae una expresion.~@
                  Si querias que se calculara, ponle :ROL DERIVADO." nombre))
        (let ((decimales (opcion opciones :decimales)))
          (when (and (opcion-presente-p opciones :decimales)
                     (not (and (eq tipo :numero) (integerp decimales) (<= 0 decimales 10))))
            (error "El campo ~a tiene :DECIMALES ~s.~@
                    :DECIMALES solo vale en un campo :TIPO NUMERO, con un entero~@
                    de 0 a 10: es cuantos decimales se escriben (el valor no cambia;~@
                    para cambiarlo esta (REDONDEAR EXPRESION N))."
                   nombre decimales)))
        (when (and dominio (not (eq rol :entrada)))
          (error "El campo ~a tiene :DOMINIO pero su rol no es ENTRADA.~@
                  Un dominio dice que puede escribir el usuario; si nadie~@
                  escribe ahi, no significa nada." nombre))
        `(nucleo:hacer-campo
          :nombre ',(normalizar nombre)
          :etiqueta ,(opcion opciones :etiqueta (string-capitalize (symbol-name nombre)))
          :tipo ,tipo
          :rol ,rol
          :decimales ,(opcion opciones :decimales)
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
           ;; Uno o varios campos: por el primero y, a igualdad, por el
           ;; siguiente (fase 2, hueco C3). Hasta el 2026-10-17 solo se
           ;; admitia uno; antes aun, el resto se tiraba en silencio.
           (setf orden (normalizar-lista (rest f))))
          ((eq (first f) :crece) (setf crecimiento :crece))
          ((eq (first f) :datos) (setf datos (second f)))
          ;; (:una-fila-por campo :de coleccion) y (:una-sola-fila)
          ((eq (first f) :una-fila-por)
           (setf origen (list :una-fila-por (normalizar (second f))
                              :de (normalizar (palabra-clave-de f :de)))))
          ((eq (first f) :una-sola-fila) (setf origen '(:una-sola-fila)))
          (t (error "No se como leer ~s dentro de la coleccion ~a" f nombre))))
      (values
       `(nucleo:hacer-coleccion
         :nombre ',(normalizar nombre)
         :etiqueta ,etiqueta
         :campos (list ,@(nreverse campos))
         :clave ',clave
         :orden ',orden
         :crecimiento ,crecimiento
         :origen ',origen
         :datos ',datos)
       (marcas-de-forma nombre cuerpo)))))

(defun marcas-de-forma (coleccion cuerpo)
  "Las marcas sinteticas de forma invalida para los campos :TIPO FECHA y
   :TIPO HORA del CUERPO de COLECCION, como formas fuente de MARCA.

   Plan aprobado de tipos, seccion 4.2: senalan el valor escrito que no
   tiene la forma AAAA-MM-DD o HH:MM. Advierten, o son un problema si el
   campo declara :AL-VIOLAR IMPEDIR. Llevan :EN explicito para no chocar con
   otra coleccion que tenga un campo del mismo nombre."
  (loop for f in cuerpo
        when (cabeza-es f "CAMPO")
          append (multiple-value-bind (opciones) (partir-opciones (cddr f))
                   (let ((tipo (como-clave (opcion opciones :tipo 'nucleo::texto)))
                         (campo (second f)))
                     (when (member tipo '(:fecha :hora))
                       (list
                        `(marca ,(intern (format nil "~a-FORMA-INVALIDA" (symbol-name campo)))
                                :en ,coleccion
                                :sobre (,campo)
                                :cuando (y (no (vacio? (de fila ,campo)))
                                           (forma-invalida ,campo))
                                :severidad ,(if (eq (como-clave (opcion opciones :al-violar
                                                                        'nucleo::advertir))
                                                    :impedir)
                                                'problema 'advertencia)
                                :explica ,(if (eq tipo :fecha)
                                              "La fecha no tiene la forma AAAA-MM-DD"
                                              "La hora no tiene la forma HH:MM"))))))))

;;; ---------------------------------------------------------------------
;;; Marcas
;;; ---------------------------------------------------------------------

(defun compilar-marca (forma)
  "(marca NOMBRE :cuando EXPR :sobre (campo ...) :severidad ... [:explica EXPR]
                 [:por-campo VARIABLE])

   Con :POR-CAMPO, la condicion y la explicacion se evaluan una vez por cada
   campo de :SOBRE, con VARIABLE ligada al valor de ese campo, y solo se
   senalan los campos donde se cumple (fase 2, hueco C7)."
  (destructuring-bind (cabeza nombre &rest opciones) forma
    (declare (ignore cabeza))
    (let ((cuando (opcion opciones :cuando))
          (sobre (opcion opciones :sobre))
          (en (opcion opciones :en))
          (explica (opcion opciones :explica))
          (por-campo (opcion opciones :por-campo)))
      (unless cuando (error "La marca ~a no dice :CUANDO se cumple." nombre))
      (unless sobre (error "La marca ~a no dice :SOBRE que campos senala." nombre))
      (when (and (opcion-presente-p opciones :por-campo)
                 (not (and por-campo (symbolp por-campo) (not (keywordp por-campo)))))
        (error "La marca ~a tiene :POR-CAMPO ~s.~@
                :POR-CAMPO lleva el nombre de una variable, que en cada campo de~@
                :SOBRE vale lo que hay en ese campo: (:por-campo profesor)."
               nombre por-campo))
      (let ((*variables-de-valor* (if por-campo
                                      (cons por-campo *variables-de-valor*)
                                      *variables-de-valor*)))
        `(nucleo:hacer-marca
          :nombre ',(normalizar nombre)
          :coleccion ',(normalizar en)
          :condicion ,(compilar-expresion cuando)
          :alcance ',(normalizar-lista sobre)
          :severidad ,(como-clave (opcion opciones :severidad 'nucleo::advertencia))
          :explicacion ,(when explica (compilar-expresion explica))
          :por-campo ',(normalizar por-campo))))))

;;; ---------------------------------------------------------------------
;;; Vistas y parametros
;;; ---------------------------------------------------------------------

(defun conjunto-escrito-p (expresion)
  "Cierto si EXPRESION es un conjunto de los que admite un :DOMINIO:
   (UNO-DE ...), (ALGUNO-DE ...) o (LOS CAMPO DE COLECCION ...)."
  (and (consp expresion) (symbolp (first expresion))
       (member (symbol-name (first expresion)) '("UNO-DE" "ALGUNO-DE" "LOS")
               :test #'string=)))

(defun partir-eje (vista clave eje)
  "Separa lo escrito en la opcion CLAVE de VISTA en (VALUES CAMPO DOMINIO).

   Un eje se escribe como el nombre del campo, y entonces sus valores salen
   de los datos, o como (CAMPO :DOMINIO EXPRESION), y entonces son los de la
   expresion, en su orden (fase 2, hueco C1; ver nucleo/ejes.lisp). La
   expresion es la misma que la del :DOMINIO de un campo de entrada; no hay
   vocabulario nuevo."
  (cond ((or (null eje) (symbolp eje)) (values eje nil))
        ((and (consp eje) (symbolp (first eje)) (= 3 (length eje))
              (eq (second eje) :dominio) (conjunto-escrito-p (third eje)))
         (values (first eje) (third eje)))
        (t (error "En la vista ~a, ~s ~s no se entiende.~@
                   Un eje es el nombre de un campo, o (CAMPO :DOMINIO CONJUNTO)~@
                   con CONJUNTO escrito (uno-de ...) o (los CAMPO de COLECCION)."
                  vista clave eje))))

(defun compilar-vista (forma)
  "(vista NOMBRE :de COLECCION [:etiqueta ...] [:entrada t]
                 [:secciones EJE] [:agrupada-por CAMPO] [:donde EXPRESION]
                 [:unica-salvo MARCA]
                 [:filas EJE :columnas EJE :muestra CAMPO])

   EJE es CAMPO o (CAMPO :dominio CONJUNTO)."
  (destructuring-bind (cabeza nombre &rest opciones) forma
    (declare (ignore cabeza))
    (let ((fuente (opcion opciones :de))
          (donde (opcion opciones :donde)))
      (unless fuente (error "La vista ~a no dice :DE que coleccion es." nombre))
      (multiple-value-bind (filas dominio-de-filas)
          (partir-eje nombre :filas (opcion opciones :filas))
        (multiple-value-bind (columnas dominio-de-columnas)
            (partir-eje nombre :columnas (opcion opciones :columnas))
          (multiple-value-bind (secciones dominio-de-secciones)
              (partir-eje nombre :secciones (opcion opciones :secciones))
            `(nucleo:hacer-vista
              :nombre ',(normalizar nombre)
              :etiqueta ,(opcion opciones :etiqueta (string-capitalize (symbol-name nombre)))
              :fuente ',(normalizar fuente)
              :secciones ',(normalizar secciones)
              :agrupacion ',(normalizar (opcion opciones :agrupada-por))
              :filtro ,(when donde (compilar-expresion donde))
              :conflicto ',(normalizar (opcion opciones :unica-salvo))
              :eje-de-filas ',(normalizar filas)
              :eje-de-columnas ',(normalizar columnas)
              :lo-que-se-muestra ',(normalizar (opcion opciones :muestra))
              :dominio-de-filas ,(when dominio-de-filas
                                   (compilar-expresion dominio-de-filas))
              :dominio-de-columnas ,(when dominio-de-columnas
                                      (compilar-expresion dominio-de-columnas))
              :dominio-de-secciones ,(when dominio-de-secciones
                                       (compilar-expresion dominio-de-secciones))
              :es-entrada ,(opcion opciones :entrada nil))))))))

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
        ((cabeza-es forma "COLECCION")
         (multiple-value-bind (coleccion sinteticas) (compilar-coleccion forma)
           (push coleccion colecciones)
           (dolist (m sinteticas) (push (compilar-marca m) marcas))))
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
