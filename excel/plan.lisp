;;;; El plan de la hoja de calculo.
;;;;
;;;; AQUI VIVE EL DIRECCIONAMIENTO, Y SOLO AQUI.
;;;;
;;;; El COL-MAP de la tesis de 2026 -el diccionario de simbolo de columna a
;;;; letra de Excel- no ha desaparecido: esta en este archivo. Lo que ha
;;;; cambiado es que ya no esta en la firma del punto de extension, sino
;;;; dentro del plan de una arquitectura concreta, que es donde tiene
;;;; sentido. El nucleo no lo ve, el protocolo no lo nombra, y ninguna otra
;;;; arquitectura sabe que existe.
;;;;
;;;; Esa es, en una frase, la diferencia entre este trabajo y el anterior.

(in-package #:situacion.excel)

(defclass hoja ()
  ((nombre :accessor nombre :initarg :nombre)
   (coleccion :accessor coleccion :initarg :coleccion)
   (columnas :accessor columnas :initarg :columnas
             :documentation "Lista asociativa de nombre de campo a letra.")
   (fila-encabezado :accessor fila-encabezado :initarg :fila-encabezado)
   (fila-primera :accessor fila-primera :initarg :fila-primera)
   (capacidad :accessor capacidad :initarg :capacidad
              :documentation
              "Cuantas filas abarca la hoja: las que hay mas la reserva.")
   (rango-nombrado :accessor rango-nombrado :initarg :rango-nombrado))
  (:documentation "Donde cae cada cosa de una coleccion dentro del libro."))

(defclass cruce ()
  ((vista :accessor vista :initarg :vista)
   (hoja-origen :accessor hoja-origen :initarg :hoja-origen)
   (seccion :accessor seccion :initarg :seccion :initform nil
            :documentation
            "Valor del campo de particion que le toca a esta pestana, o NIL si
             la vista no se parte. Una vista partida produce un cruce -y por
             tanto una pestana- por cada valor.")
   (valores-de-fila :accessor valores-de-fila :initarg :valores-de-fila)
   (valores-de-columna :accessor valores-de-columna :initarg :valores-de-columna)
   (columna-auxiliar :accessor columna-auxiliar :initarg :columna-auxiliar
                     :documentation
                     "Letra de la columna de clave compuesta que se anade a la
                      hoja de origen. Es la maquinaria de la emulacion: sin
                      ella no hay forma portable de buscar por dos criterios."))
  (:documentation
   "Una vista cruzada, ya resuelta a geometria.

    Los dos ejes se fijan AL GENERAR, leyendo los valores que hay. Ese es el
    coste de la emulacion y esta declarado en el informe: si manana aparece un
    turno nuevo, no aparece una columna nueva; hay que volver a generar."))

(defclass plan-de-excel ()
  ((situacion :accessor situacion :initarg :situacion)
   (hojas :accessor hojas :initarg :hojas :initform '())
   (cruces :accessor cruces :initarg :cruces :initform '())
   (entorno :accessor entorno :initarg :entorno :initform nil)
   (auxiliares :accessor auxiliares :initarg :auxiliares :initform '()
               :documentation
               "Hojas que la arquitectura se inventa para emular lo que no
                tiene. El lenguaje no las nombra nunca."))
  (:documentation "Plan de la hoja de calculo. Opaco para el nucleo."))

;;; ---------------------------------------------------------------------
;;; Direccionamiento
;;; ---------------------------------------------------------------------

(defun letra-de-columna (indice)
  "A, B, ... Z, AA, AB, ... para el indice dado, empezando en cero."
  (let ((letras '()))
    (loop do (multiple-value-bind (cociente resto) (floor indice 26)
               (push (code-char (+ (char-code #\A) resto)) letras)
               (setf indice (1- cociente)))
          while (>= indice 0))
    (coerce letras 'string)))

(defun hoja-de (plan nombre-de-coleccion)
  (find nombre-de-coleccion (hojas plan) :key (lambda (h) (nucleo:nombre (coleccion h)))))

(defun columna-de (hoja nombre-de-campo)
  (or (cdr (assoc nombre-de-campo (columnas hoja)))
      (error "El plan no tiene columna para ~(~a~)" nombre-de-campo)))

(defun celda (hoja campo fila &key (absoluta-columna t) (absoluta-fila nil))
  (format nil "~:[~;$~]~a~:[~;$~]~d"
          absoluta-columna (columna-de hoja campo) absoluta-fila fila))

(defun rango-de-columna (hoja campo &key (con-hoja nil))
  "El rango absoluto de una columna, desde la primera fila de datos hasta el
   final de la capacidad reservada."
  (let ((letra (columna-de hoja campo)))
    (format nil "~@[~a!~]$~a$~d:$~a$~d"
            (when con-hoja (entrecomillar (nombre hoja)))
            letra (fila-primera hoja)
            letra (fila-ultima hoja))))

(defun fila-ultima (hoja)
  (+ (fila-primera hoja) (capacidad hoja) -1))

(defun entrecomillar (nombre)
  (if (find #\Space nombre) (format nil "'~a'" nombre) nombre))

;;; ---------------------------------------------------------------------
;;; Planificacion (fase 5)
;;; ---------------------------------------------------------------------

(defmethod protocolo:planificar ((a excel) situacion)
  (let ((plan (make-instance 'plan-de-excel :situacion situacion)))
    (dolist (coleccion (nucleo:colecciones situacion))
      (push (protocolo:planificar-coleccion a coleccion plan) (hojas plan)))
    (setf (hojas plan) (nreverse (hojas plan)))
    plan))

(defun capacidad-para (a coleccion n-filas)
  "Cuantas filas abarca la hoja de COLECCION si lleva N-FILAS de datos.

   Una coleccion que crece se lleva ademas su reserva en blanco. Esta escrito
   una sola vez porque se aplica dos veces: al planificar, con las filas
   declaradas, y al emitir, con las que de verdad se van a escribir."
  (let ((n (max 1 n-filas)))
    (if (eq (nucleo:crecimiento coleccion) :crece)
        (+ n (max (reserva-minima a) (floor n 2)))
        n)))

(defun ajustar-capacidades (a plan)
  "Redimensiona las hojas con las filas que de verdad se van a escribir.

   AL PLANIFICAR NO SE SABEN. La fase 5 solo tiene la descripcion, donde las
   filas son las declaradas en (:DATOS ...); las que se materializan llegan
   con el entorno, en la fase 6, y pueden ser muchas mas: una descripcion
   declara dos casillas de ejemplo y se genera con ochenta.

   Sin esto, CELDAS-DE escribe las ochenta -toma los valores del entorno- y
   todo lo que se dimensiona con la capacidad -los rangos, la columna de
   clave compuesta, las validaciones, los formatos- cubre solo dos. El libro
   sale con datos fuera de rango y celdas vacias donde deberia haber
   busquedas, sin un solo error a la vista."
  (dolist (hoja (hojas plan))
    (let ((reales (length (nucleo:filas-de (entorno plan)
                                           (nucleo:nombre (coleccion hoja))))))
      (setf (capacidad hoja)
            (max (capacidad hoja) (capacidad-para a (coleccion hoja) reales))))))

(defmethod protocolo:planificar-coleccion ((a excel) coleccion plan)
  "Decide la geometria de una coleccion: que columna ocupa cada campo, donde
   empiezan los datos y cuantas filas se reservan."
  (let* ((campos (nucleo:campos coleccion))
         (columnas (loop for campo in campos
                         for i from 0
                         collect (cons (nucleo:nombre campo) (letra-de-columna i))))
         (capacidad (capacidad-para a coleccion (length (nucleo:datos coleccion))))
         (hoja (make-instance 'hoja
                              :nombre (nucleo:etiqueta coleccion)
                              :coleccion coleccion
                              :columnas columnas
                              :fila-encabezado 3
                              :fila-primera 4
                              :capacidad capacidad
                              :rango-nombrado (nombre-de-rango coleccion))))
    (dolist (campo campos)
      (protocolo:planificar-campo a campo coleccion plan))
    hoja))

(defun nombre-de-rango (coleccion)
  "Un nombre valido para el rango nombrado de una coleccion.

   Los rangos nombrados no admiten guiones ni espacios, asi que se
   normalizan. Es una restriccion del formato de salida y por eso se resuelve
   aqui y no en el lenguaje."
  (remove-if-not #'alphanumericp
                 (string-capitalize (substitute #\Space #\- (symbol-name
                                                             (nucleo:nombre coleccion))))))

;;; Regla transversal, escrita una vez para toda arquitectura con entrada:
;;; lo derivado queda de solo lectura. Es la idea de los metodos auxiliares
;;; de ADOL*, aplicada aqui.
(defmethod protocolo:planificar-campo :after ((a protocolo:con-entrada)
                                              campo coleccion plan)
  (declare (ignore coleccion plan))
  (when (eq (nucleo:rol campo) :derivado)
    ;; Nada que hacer aqui todavia mas que dejar constancia: el bloqueo real
    ;; lo aplica la emision, que es quien conoce las celdas. Lo que importa es
    ;; que la regla este en un solo sitio y valga para Excel, para la web y
    ;; para cualquier arquitectura con entrada que llegue despues.
    t))

(defmethod protocolo:planificar-campo ((a excel) campo coleccion plan)
  (declare (ignore campo coleccion plan))
  t)

;;; ---------------------------------------------------------------------
;;; Tablas cruzadas
;;;
;;; Una hoja de calculo tiene rejilla, asi que dibujar un cuadrante deberia
;;; ser lo suyo. Y no lo es, por una razon que solo se ve al intentarlo: el
;;; numero de columnas depende del CONTENIDO -cuantos dias distintos haya- y
;;; no de la declaracion. Todo el direccionamiento de esta arquitectura parte
;;; de que cada campo tiene su letra, fijada al planificar.
;;;
;;; La emulacion consiste en fijar los dos ejes al generar, leyendo los datos.
;;; Su coste esta declarado en el informe de conformidad: si manana aparece un
;;; turno nuevo, no aparece una columna nueva.
;;; ---------------------------------------------------------------------

(defun valores-distintos-en-filas (plan filas campo)
  "Los valores que toma CAMPO en FILAS, sin repetir y en orden de aparicion."
  (let ((vistos '()))
    (dolist (f filas (nreverse vistos))
      (let ((v (nucleo:valor-de-campo (entorno plan) f campo)))
        (unless (or (nucleo:vacio-p v) (member v vistos :test #'nucleo:iguales-p))
          (push v vistos))))))

(defun valores-distintos-en (plan nombre-coleccion campo)
  "Los valores que toma un campo en la coleccion entera."
  (valores-distintos-en-filas
   plan (nucleo:filas-de (entorno plan) nombre-coleccion) campo))

(defun filas-presentables (plan vista)
  "Las filas que VISTA presenta: las de su coleccion que pasan su filtro.

   Se evalua AL GENERAR, que es el coste de emularlo aqui: si manana una fila
   deja de cumplir el filtro, sigue en su pestana hasta que se regenere el
   libro. La coleccion no se toca, asi que los agregados y las marcas siguen
   viendo las filas escondidas."
  (let ((filas (nucleo:filas-de (entorno plan) (nucleo:fuente vista))))
    (if (null (nucleo:filtro vista))
        filas
        (remove-if-not
         (lambda (f) (nucleo:evaluar-en-fila (entorno plan) f
                                             (nucleo:filtro vista)))
         filas))))

(defun filas-de-la-seccion (plan vista valor)
  "Las filas de VISTA que caen en la seccion VALOR.

   Con VALOR en NIL son todas las presentables: es el caso de la vista que no
   se parte."
  (let ((filas (filas-presentables plan vista)))
    (if (null valor)
        filas
        (remove-if-not
         (lambda (f) (nucleo:iguales-p
                      valor (nucleo:valor-de-campo (entorno plan) f
                                                   (nucleo:secciones vista))))
         filas))))

(defun planificar-cruces (a vista plan)
  "Resuelve una vista cruzada a geometria: un cruce por seccion.

   Sin particion sale uno solo, con SECCION en NIL. Con particion, uno por
   valor, y cada uno sera una pestana. Los valores se leen de los DATOS y se
   fijan aqui, al generar: ese es el coste de la emulacion y esta declarado
   en el informe."
  (declare (ignore a))
  (let ((hoja (hoja-de plan (nucleo:fuente vista))))
    ;; La capacidad ya la pidio PROTOCOLO:REQUERIMIENTOS al empezar a
    ;; materializar: pedirla otra vez aqui duplicaba el renglon del informe.
    ;; Un informe que repite cosas se lee peor y, sobre todo, deja de poder
    ;; contarse.
    (when hoja
      (dolist (valor (if (nucleo:secciones vista)
                         ;; Las secciones salen de las filas presentables: si
                         ;; el filtro deja fuera a un profesor entero, no se
                         ;; le fabrica una pestana vacia.
                         (valores-distintos-en-filas
                          plan (filas-presentables plan vista)
                          (nucleo:secciones vista))
                         (list nil)))
        (let ((filas (filas-de-la-seccion plan vista valor)))
          (push (make-instance
                 'cruce
                 :vista vista
                 :hoja-origen hoja
                 :seccion valor
                 :valores-de-fila (valores-distintos-en-filas
                                   plan filas (nucleo:eje-de-filas vista))
                 :valores-de-columna (valores-distintos-en-filas
                                      plan filas (nucleo:eje-de-columnas vista))
                 ;; La columna de clave compuesta va detras de las declaradas.
                 ;; Es la misma para todos los cruces de la misma vista: la
                 ;; escribe la hoja de origen una sola vez.
                 :columna-auxiliar (letra-de-columna
                                    (length (nucleo:campos (coleccion hoja)))))
                (cruces plan)))))))
