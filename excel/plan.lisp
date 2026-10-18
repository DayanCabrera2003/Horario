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
  ((nombre :accessor nombre :initarg :nombre
           :documentation
           "El nombre de la pestana. El definitivo lo fija
            ASIGNAR-NOMBRES-DE-HOJA (excel/nombres.lisp) antes de emitir.")
   (titulo :accessor titulo :initarg :titulo :initform nil
           :documentation "El titulo completo, que va en la primera celda.")
   (coleccion :accessor coleccion :initarg :coleccion)
   (columnas :accessor columnas :initarg :columnas
             :documentation "Lista asociativa de nombre de campo a letra.")
   (fila-encabezado :accessor fila-encabezado :initarg :fila-encabezado)
   (fila-primera :accessor fila-primera :initarg :fila-primera)
   (capacidad :accessor capacidad :initarg :capacidad
              :documentation
              "Cuantas filas abarca la hoja: las que hay mas la reserva.")
   (rango-nombrado :accessor rango-nombrado :initarg :rango-nombrado)
   (claves :accessor claves :initform '()
           :documentation
           "Las columnas de clave compuesta que esta arquitectura anade a la
            hoja, en el orden en que se pidieron. Van detras de las columnas
            declaradas. Solo CLAVE-COMPUESTA-DE escribe aqui.")
   (distintos :accessor distintos :initform '()
              :documentation
              "Las columnas auxiliares que marcan la primera aparicion de cada
               valor de un campo, para contar valores distintos. Van detras
               de las de clave. Solo COLUMNA-DE-DISTINTOS-DE escribe aqui."))
  (:documentation "Donde cae cada cosa de una coleccion dentro del libro."))

(defclass clave-compuesta ()
  ((partes :accessor partes :initarg :partes
           :documentation
           "Los nombres de los campos que se concatenan, en orden.")
   (filtro :accessor filtro :initarg :filtro :initform nil
           :documentation
           "Expresion booleana por fila, o NIL. La fila que no la cumple
            tiene la clave vacia, y asi ninguna busqueda la encuentra.")
   (letra :accessor letra :initarg :letra
          :documentation "La columna de la hoja donde se escribe."))
  (:documentation
   "Una columna que concatena varios campos de una fila para poder buscarla
    por todos a la vez.

    Es maquinaria de esta arquitectura: una hoja de calculo busca por un solo
    criterio, y lo que el lenguaje pide -una casilla por seccion, fila y
    columna- son varios. El lenguaje no la nombra y las demas arquitecturas
    no la necesitan.

    Lo que la identifica es QUE contiene, no quien la pidio. Dos vistas que
    buscan por los mismos campos entre las mismas filas comparten columna;
    dos que difieren en los campos o en el filtro tienen cada una la suya."))

(defclass columna-de-distintos ()
  ((campo :accessor campo-de :initarg :campo
          :documentation "El campo cuyos valores distintos se cuentan.")
   (letra :accessor letra :initarg :letra
          :documentation "La columna de la hoja donde se escribe."))
  (:documentation
   "Una columna que vale 1 en la fila donde un valor aparece por primera vez.
    Sumarla da cuantos valores distintos hay. Es la emulacion del conteo de
    distintos: una hoja de calculo no lo tiene sin formulas matriciales."))

(defclass cruce ()
  ((vista :accessor vista :initarg :vista)
   (nombre :accessor nombre :initarg :nombre :initform nil
           :documentation "El nombre de su pestana, fijado por ASIGNAR-NOMBRES-DE-HOJA.")
   (titulo :accessor titulo :initarg :titulo :initform nil
           :documentation "El titulo completo de la pestana: vista y seccion.")
   (hoja-origen :accessor hoja-origen :initarg :hoja-origen)
   (seccion :accessor seccion :initarg :seccion :initform nil
            :documentation
            "Valor del campo de particion que le toca a esta pestana, o NIL si
             la vista no se parte. Una vista partida produce un cruce -y por
             tanto una pestana- por cada valor.")
   (valores-de-fila :accessor valores-de-fila :initarg :valores-de-fila)
   (valores-de-columna :accessor valores-de-columna :initarg :valores-de-columna)
   (clave :accessor clave :initarg :clave :initform nil
          :documentation
          "La clave compuesta de la hoja de origen por la que busca este
           cruce. Es la maquinaria de la emulacion: sin ella no hay forma
           portable de buscar por dos criterios. NIL si el cruce sale en su
           propio archivo, que lleva valores y no busquedas."))
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
                tiene. El lenguaje no las nombra nunca.")
   (archivos :accessor archivos :initarg :archivos :initform '()
             :documentation
             "Cruces de vistas en VISTAS-EN-ARCHIVO: uno por seccion, cada
              uno destinado a su propio .xlsx en vez de a una pestana del
              libro principal."))
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

(defun nombre-de-coleccion (coleccion)
  "El nombre interno de COLECCION tal como lo escribe el oraculo. Es la
   identidad con que el plano dice de que coleccion es una hoja."
  (string-downcase (symbol-name (nucleo:nombre coleccion))))

(defun columna-de (hoja nombre-de-campo)
  ;; :TEST #'EQUAL y no el EQL por defecto: la mayoria de las claves son
  ;; simbolos internados (donde EQUAL se comporta como EQ, sin cambiar nada),
  ;; pero la tabla cruda de una relacion uno-a-muchos (H4, excel/relacion.lisp)
  ;; usa la cadena literal "__clave__" como clave de columna, y dos cadenas
  ;; iguales de distinto archivo no tienen por que ser EQL.
  (or (cdr (assoc nombre-de-campo (columnas hoja) :test #'equal))
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

(defun siguiente-columna-libre (hoja)
  "La primera columna de HOJA que no ocupa ni un campo declarado ni una
   columna anadida por esta arquitectura."
  (letra-de-columna (+ (length (columnas hoja)) (length (claves hoja))
                       (length (distintos hoja)))))

(defun clave-compuesta-de (hoja partes &optional filtro)
  "La clave compuesta de HOJA que concatena PARTES en las filas que cumplen
   FILTRO, creandola si no existe.

   Es el unico sitio que reparte columnas detras de las declaradas. Quien
   necesite buscar por varios campos la pide aqui y recibe siempre una
   columna que contiene exactamente lo que pidio, haya las vistas que haya
   sobre la coleccion."
  (or (find-if (lambda (clave) (and (equal (partes clave) partes)
                                    (eq (filtro clave) filtro)))
               (claves hoja))
      (let ((nueva (make-instance 'clave-compuesta
                                  :partes partes
                                  :filtro filtro
                                  :letra (siguiente-columna-libre hoja))))
        (setf (claves hoja) (append (claves hoja) (list nueva)))
        nueva)))

(defun columna-de-distintos-de (hoja campo)
  "La columna de primera aparicion de CAMPO en HOJA, creandola si no existe."
  (or (find campo (distintos hoja) :key #'campo-de)
      (let ((nueva (make-instance 'columna-de-distintos
                                  :campo campo
                                  :letra (siguiente-columna-libre hoja))))
        (setf (distintos hoja) (append (distintos hoja) (list nueva)))
        nueva)))

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

   Se evalua AL GENERAR, y de aqui salen las secciones y los ejes: ese es el
   coste de emularlo. Lo que hay DENTRO de cada casilla no depende de esta
   lista: la clave compuesta vuelve a preguntar el filtro en la hoja (ver
   CLAVE-COMPUESTA). La coleccion no se toca, asi que los agregados y las
   marcas siguen viendo las filas escondidas."
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

(defun partes-de-la-clave (vista)
  "Los campos por los que una casilla de VISTA identifica su fila: la seccion
   si la vista se parte, el eje de filas y el eje de columnas.

   El orden importa: es el mismo en que FORMULA-DE-CASILLA arma la clave que
   busca."
  (remove nil (list (nucleo:secciones vista)
                    (nucleo:eje-de-filas vista)
                    (nucleo:eje-de-columnas vista))))

(defun planificar-cruces (a vista plan)
  "Resuelve una vista cruzada a geometria: un cruce por seccion.

   Sin particion sale uno solo, con SECCION en NIL. Con particion, uno por
   valor, y cada uno sera una pestana. Los valores se leen de los DATOS y se
   fijan aqui, al generar: ese es el coste de la emulacion y esta declarado
   en el informe.

   Si VISTA esta en (VISTAS-EN-ARCHIVO A) (H2), sus cruces no van a
   (CRUCES PLAN) sino a (ARCHIVOS PLAN): cada uno saldra en su propio .xlsx
   en vez de en una pestana del libro principal."
  (let ((hoja (hoja-de plan (nucleo:fuente vista)))
        (destino (if (member (nucleo:nombre vista) (vistas-en-archivo a))
                    'archivos 'cruces)))
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
        (let* ((filas (filas-de-la-seccion plan vista valor))
               (cruce (make-instance
                       'cruce
                       :vista vista
                       :hoja-origen hoja
                       :seccion valor
                       :valores-de-fila (valores-distintos-en-filas
                                         plan filas (nucleo:eje-de-filas vista))
                       :valores-de-columna (valores-distintos-en-filas
                                            plan filas (nucleo:eje-de-columnas vista))
                       ;; Todos los cruces de una vista buscan por la misma
                       ;; clave. Un cruce que sale en su propio archivo no
                       ;; busca nada, y no hace gastar una columna.
                       :clave (when (eq destino 'cruces)
                                (clave-compuesta-de
                                 hoja (partes-de-la-clave vista)
                                 (nucleo:filtro vista))))))
          ;; PUSH no sirve aqui: el lugar se elige en tiempo de ejecucion con
          ;; IF, y IF no tiene expansor SETF. De ahi el SETF/CONS explicito
          ;; en vez del PUSH que usaba esta funcion antes de H2.
          (if (eq destino 'archivos)
              (setf (archivos plan) (cons cruce (archivos plan)))
              (setf (cruces plan) (cons cruce (cruces plan)))))))))
