;;;; El evaluador de referencia.
;;;;
;;;; Dada una situacion y unos datos, calcula los valores derivados y dice
;;;; que marcas disparan.
;;;;
;;;; POR QUE ESTA PIEZA ES MAS IMPORTANTE DE LO QUE PARECE
;;;;
;;;; Su justificacion inmediata es mecanica: una arquitectura con derivaciones
;;;; congeladas -un documento impreso, una pagina estatica- necesita que
;;;; alguien evalue las expresiones antes de escribirlas, y ese alguien no
;;;; puede ser un backend, porque entonces cada uno tendria su propia
;;;; semantica.
;;;;
;;;; Pero trae otras tres cosas:
;;;;
;;;;   1. Es la definicion de que significa el lenguaje. La semantica deja de
;;;;      ser "lo que haga la hoja de calculo" y pasa a estar escrita en un
;;;;      sitio. Toda arquitectura tiene que coincidir con el, y eso es
;;;;      comprobable.
;;;;
;;;;   2. Es un oraculo que no depende de ningun destino. Se puede probar una
;;;;      busqueda por clave, un cuantificador o un conteo de distintos sin
;;;;      generar ningun archivo y sin tener ningun backend escrito. Eso
;;;;      permite desarrollar y probar el algebra de expresion entera antes
;;;;      de que exista la primera arquitectura, que es exactamente lo
;;;;      contrario de lo que hicieron las tres tesis anteriores.
;;;;
;;;;   3. Cierra el lazo de la verificacion desde el primer dia: el evaluador
;;;;      da el valor esperado y la suite de conformidad comprueba que cada
;;;;      arquitectura da el mismo.

(in-package #:situacion.nucleo)

(define-condition error-de-evaluacion (error)
  ((mensaje :initarg :mensaje :reader mensaje-de-error))
  (:report (lambda (c s) (format s "~a" (mensaje-de-error c)))))

(defun fallar (formato &rest argumentos)
  (error 'error-de-evaluacion :mensaje (apply #'format nil formato argumentos)))

;;; ---------------------------------------------------------------------
;;; Filas y entorno
;;; ---------------------------------------------------------------------

(defclass fila ()
  ((coleccion :accessor coleccion :initarg :coleccion)
   (valores :accessor valores :initarg :valores
            :documentation "Tabla de nombre de campo a valor.")
   (indice :accessor indice :initarg :indice :initform 0
           :documentation
           "Posicion dentro de la coleccion, ya ordenada si declara orden.
            Es interno del evaluador y no sale de aqui: sirve para VECINO y
            para nada mas."))
  (:documentation "Una fila con sus valores."))

(defun hacer-fila (coleccion valores &optional (indice 0))
  (make-instance 'fila :coleccion coleccion :valores valores :indice indice))

(defclass entorno ()
  ((situacion :accessor situacion :initarg :situacion)
   (tablas :accessor tablas :initarg :tablas
           :documentation "Tabla de nombre de coleccion a lista de filas.")
   (en-curso :accessor en-curso :initform '()
             :documentation
             "Derivaciones que se estan calculando, para detectar ciclos en
              tiempo de evaluacion. El analisis ya los detecta antes, pero
              una descripcion construida a mano puede saltarselo."))
  (:documentation "Los datos sobre los que se evalua una situacion."))

(defun filas-de (entorno nombre-de-coleccion)
  (gethash nombre-de-coleccion (tablas entorno)))

(defun hacer-entorno (situacion datos)
  "Construye el entorno. DATOS es una lista de (NOMBRE-COLECCION . FILAS),
   donde cada fila es una lista asociativa de campo a valor.

   Las colecciones que declaran orden se ordenan aqui, y es el unico sitio
   donde se hace: a partir de este punto, la fila siguiente es la siguiente
   de la lista, sin que nadie tenga que volver a pensar en el orden."
  (let ((tablas (make-hash-table :test #'eq))
        (entorno nil))
    (setf entorno (make-instance 'entorno :situacion situacion :tablas tablas))
    ;; Las colecciones declaradas primero: las derivadas salen de ellas.
    (dolist (coleccion (append (remove-if #'derivada-p (colecciones situacion))
                               (remove-if-not #'derivada-p (colecciones situacion))))
      (let* ((crudas (if (derivada-p coleccion)
                         (filas-derivadas coleccion entorno)
                         (cdr (assoc (nombre coleccion) datos))))
             (filas (loop for cruda in crudas
                          collect (hacer-fila coleccion (tabla-de-valores cruda)))))
        ;; ORDEN es el nombre del campo, no el objeto: se guarda asi porque
        ;; el lenguaje lo escribe como simbolo y resolverlo a objeto seria
        ;; trabajo del analisis, no del evaluador.
        (when (orden coleccion)
          (setf filas (ordenar-filas filas (orden coleccion))))
        (loop for f in filas for i from 0 do (setf (indice f) i))
        (setf (gethash (nombre coleccion) tablas) filas)))
    entorno))

(defun derivada-p (coleccion)
  "Cierto si las filas de COLECCION salen de otra coleccion en vez de
   declararse a mano."
  (and (consp (origen coleccion))
       (member (first (origen coleccion)) '(:una-fila-por :una-sola-fila))))

(defun filas-derivadas (coleccion entorno)
  "Las filas de una coleccion que se agrupa, o la unica de un resumen.

   (:UNA-FILA-POR campo :DE coleccion) produce una fila por cada valor
   distinto que toma ese campo, en el orden en que aparecen. Es la agrupacion
   que faltaba: \"una fila por proveedor\", \"una fila por partida\".

   (:UNA-SOLA-FILA) produce exactamente una, sin ningun campo escrito. Sirve
   para las afirmaciones que son de la situacion entera y no de ninguna fila:
   el total general, si el almacen esta vacio. Antes habia que inventarse una
   coleccion de una fila que en el problema no existe."
  (destructuring-bind (clase &rest resto) (origen coleccion)
    (ecase clase
      (:una-sola-fila (list '()))
      (:una-fila-por
       (destructuring-bind (campo de fuente) resto
         (declare (ignore de))
         (let* ((filas (gethash fuente (tablas entorno)))
                (valores (remove-duplicates
                          (remove-if #'vacio-p
                                     (mapcar (lambda (f) (gethash campo (valores f)))
                                             filas))
                          :test #'iguales-p :from-end t))
                ;; El campo que recibe el valor agrupado es el primero de la
                ;; coleccion derivada que se llame igual que el de origen; si
                ;; no hay ninguno, el primero a secas.
                (destino (or (and (campo-llamado coleccion campo) campo)
                             (nombre (first (campos coleccion))))))
           (mapcar (lambda (v) (list (cons destino v))) valores)))))))

(defun tabla-de-valores (alist)
  (let ((tabla (make-hash-table :test #'eq)))
    (loop for (campo . valor) in alist do (setf (gethash campo tabla) valor))
    tabla))

(defun ordenar-filas (filas campo)
  (stable-sort (copy-list filas)
               (lambda (a b) (menor-p (gethash campo (valores a))
                                      (gethash campo (valores b))))))

(defun menor-p (a b)
  (cond ((and (realp a) (realp b)) (< a b))
        ;; Las fechas y las horas se ordenan por su valor, no por su texto.
        ;; Da igual en ISO, pero no en cuanto alguien escriba \"9:00\".
        ((and (stringp a) (stringp b)
              (or (and (fecha-como-numero a) (fecha-como-numero b))
                  (and (hora-como-numero a) (hora-como-numero b))))
         (< (como-numero a) (como-numero b)))
        ((and (stringp a) (stringp b)) (string< a b))
        ((null a) (not (null b)))
        (t nil)))

;;; ---------------------------------------------------------------------
;;; Coercion
;;;
;;; Un campo sin rellenar vale NIL o cadena vacia. Se normaliza aqui y en un
;;; solo sitio, para que el resto del evaluador no tenga que acordarse.
;;; ---------------------------------------------------------------------

(defun vacio-p (valor)
  (or (null valor) (and (stringp valor) (string= valor ""))))

(defun como-numero (valor)
  "El valor como numero, para aritmetica y comparacion.

   Las fechas en ISO y las horas en HH:MM se convierten a un numero que
   respeta su orden. Sin esto, \"existencias a fecha de corte\" y \"turnos
   antes de las diez\" -las dos preguntas mas normales de media docena de
   dominios- no se pueden escribir, porque comparar sus cadenas revienta.

   Es coercion, no un tipo de fecha de verdad: no hay aritmetica de
   calendario. Sumar un dia a una fecha sigue sin poder decirse."
  (cond ((realp valor) valor)
        ((vacio-p valor) 0)
        ((stringp valor)
         (or (fecha-como-numero valor)
             (hora-como-numero valor)
             (let ((leido (ignore-errors (read-from-string valor))))
               (if (realp leido) leido 0))))
        (t 0)))

(defun digitos-p (cadena desde hasta)
  (and (<= hasta (length cadena))
       (loop for i from desde below hasta always (digit-char-p (char cadena i)))))

(defun fecha-como-numero (cadena)
  "AAAA-MM-DD como dias desde una epoca arbitraria, o NIL si no lo es.

   La epoca da igual: lo unico que importa es que el orden se respete y que
   la resta de dos fechas de dias."
  (when (and (= 10 (length cadena))
             (char= (char cadena 4) #\-) (char= (char cadena 7) #\-)
             (digitos-p cadena 0 4) (digitos-p cadena 5 7) (digitos-p cadena 8 10))
    (let ((anio (parse-integer cadena :start 0 :end 4))
          (mes (parse-integer cadena :start 5 :end 7))
          (dia (parse-integer cadena :start 8 :end 10)))
      (when (and (<= 1 mes 12) (<= 1 dia 31))
        ;; Formula de dia juliano, que ordena bien y resta bien sin necesitar
        ;; tablas de meses ni casos de bisiesto.
        (let* ((a (floor (- 14 mes) 12))
               (y (+ anio 4800 (- a)))
               (m (+ mes (* 12 a) -3)))
          (+ dia (floor (+ (* 153 m) 2) 5) (* 365 y) (floor y 4)
             (- (floor y 100)) (floor y 400) -32045))))))

(defun hora-como-numero (cadena)
  "HH:MM como minutos desde medianoche, o NIL si no lo es."
  (when (and (= 5 (length cadena)) (char= (char cadena 2) #\:)
             (digitos-p cadena 0 2) (digitos-p cadena 3 5))
    (let ((h (parse-integer cadena :start 0 :end 2))
          (m (parse-integer cadena :start 3 :end 5)))
      (when (and (<= 0 h 23) (<= 0 m 59)) (+ (* 60 h) m)))))

(defun como-texto (valor)
  (cond ((null valor) "")
        ((stringp valor) valor)
        ((integerp valor) (format nil "~d" valor))
        ((realp valor) (format nil "~a" valor))
        ((eq valor t) "si")
        (t (princ-to-string valor))))

(defun iguales-p (a b)
  (cond ((and (realp a) (realp b)) (= a b))
        ((and (vacio-p a) (vacio-p b)) t)
        ((or (vacio-p a) (vacio-p b)) nil)
        ((and (stringp a) (stringp b)) (string= a b))
        (t (equal a b))))

;;; ---------------------------------------------------------------------
;;; Valor de un campo, con memorizacion y deteccion de ciclos
;;; ---------------------------------------------------------------------

(defun valor-de-campo (entorno fila nombre-de-campo)
  "El valor de NOMBRE-DE-CAMPO en FILA, calculandolo si es derivado."
  (let* ((coleccion (coleccion fila))
         (campo (campo-llamado coleccion nombre-de-campo)))
    (unless campo
      (fallar "La coleccion ~a no tiene un campo llamado ~a"
              (nombre coleccion) nombre-de-campo))
    (multiple-value-bind (valor presente) (gethash nombre-de-campo (valores fila))
      (cond
        ;; Ya calculado o escrito.
        ((and presente (not (eq valor :calculando))) valor)
        ;; Ciclo.
        ((eq valor :calculando)
         (fallar "El campo derivado ~a.~a depende de si mismo"
                 (nombre coleccion) nombre-de-campo))
        ;; Derivado: se calcula y se memoriza.
        ((eq (rol campo) :derivado)
         (setf (gethash nombre-de-campo (valores fila)) :calculando)
         (let* ((ambito (hacer-ambito :ligaduras (list (cons (nombrar "fila") coleccion))
                                      :actual 'fila))
                (resultado (evaluar (expresion campo) ambito entorno
                                    (list (cons (nombrar "fila") fila)))))
           (setf (gethash nombre-de-campo (valores fila)) resultado)
           resultado))
        ;; Fijo o de entrada sin rellenar.
        (t nil)))))

;;; ---------------------------------------------------------------------
;;; Evaluacion de expresiones
;;; ---------------------------------------------------------------------

(defgeneric evaluar (expresion ambito entorno ligaduras)
  (:documentation
   "El valor de EXPRESION.

      AMBITO     que variables de fila hay ligadas y sobre que coleccion.
      ENTORNO    los datos.
      LIGADURAS  lista asociativa de variable a fila concreta.

    AMBITO dice de que coleccion es cada variable; LIGADURAS dice a que fila
    apunta ahora mismo. El primero es estatico y lo comparte con el analisis
    y con los backends; el segundo solo existe mientras se evalua."))

(defun fila-ligada (ligaduras variable)
  (or (cdr (assoc variable ligaduras))
      (fallar "La variable de fila ~a no esta ligada" variable)))

(defmethod evaluar ((e literal) ambito entorno ligaduras)
  (declare (ignore ambito entorno ligaduras))
  (valor e))

(defmethod evaluar ((e ref-parametro) ambito entorno ligaduras)
  (declare (ignore ambito ligaduras))
  (let ((p (parametro-llamado (situacion entorno) (nombre e))))
    (unless p (fallar "No hay ningun parametro llamado ~a" (nombre e)))
    (valor p)))

(defmethod evaluar ((e ref-campo) ambito entorno ligaduras)
  (declare (ignore ambito))
  (valor-de-campo entorno (fila-ligada ligaduras (variable e)) (campo e)))

(defmethod evaluar ((e aplicacion) ambito entorno ligaduras)
  (let ((valores (mapcar (lambda (a) (evaluar a ambito entorno ligaduras))
                         (argumentos e))))
    (aplicar-operador (operador e) valores)))

(defun aplicar-operador (operador valores)
  "Aplica un operador aritmetico, de comparacion o logico.

   Se compara por NOMBRE y no por identidad de simbolo. Los operadores los
   escribe quien redacta la descripcion, asi que viven en el paquete de los
   nombres de usuario; compararlos con los simbolos del nucleo fallaria en
   cuanto alguien describiera una situacion desde su propio paquete, que es
   justo lo que un lenguaje interno no debe exigir."
  (flet ((n (v) (como-numero v))
         (es (nombre) (string= (symbol-name operador) nombre)))
    (cond
      ((es "+") (reduce #'+ (mapcar #'n valores)))
      ((es "-") (if (rest valores)
                    (reduce #'- (mapcar #'n valores))
                    (- (n (first valores)))))
      ((es "*") (reduce #'* (mapcar #'n valores)))
      ((es "/") (let ((divisor (n (second valores))))
                  (if (zerop divisor) nil (/ (n (first valores)) divisor))))
      ((es "=") (iguales-p (first valores) (second valores)))
      ((es "/=") (not (iguales-p (first valores) (second valores))))
      ((es "<") (< (n (first valores)) (n (second valores))))
      ((es "<=") (<= (n (first valores)) (n (second valores))))
      ((es ">") (> (n (first valores)) (n (second valores))))
      ((es ">=") (>= (n (first valores)) (n (second valores))))
      ((es "Y") (every #'identity valores))
      ((es "O") (some #'identity valores))
      ((es "NO") (not (first valores)))
      (t (fallar "Operador desconocido: ~a" operador)))))

(defmethod evaluar ((e condicional) ambito entorno ligaduras)
  (if (evaluar (prueba e) ambito entorno ligaduras)
      (evaluar (entonces e) ambito entorno ligaduras)
      (evaluar (si-no e) ambito entorno ligaduras)))

(defmethod evaluar ((e sin-escribir) ambito entorno ligaduras)
  (vacio-p (evaluar (argumento e) ambito entorno ligaduras)))

(defmethod evaluar ((e concatenacion) ambito entorno ligaduras)
  (apply #'concatenate 'string
         (mapcar (lambda (p) (como-texto (evaluar p ambito entorno ligaduras)))
                 (partes e))))

(defmethod evaluar ((e concordancia) ambito entorno ligaduras)
  (let ((n (como-numero (evaluar (cantidad e) ambito entorno ligaduras))))
    (como-texto (evaluar (if (= n 1) (singular e) (plural e))
                         ambito entorno ligaduras))))

(defun filas-que-cumplen (e-coleccion e-variable e-condicion ambito entorno ligaduras)
  "Las filas de la coleccion que cumplen la condicion, con la variable ligada."
  (let* ((situacion (situacion entorno))
         (coleccion (coleccion-llamada situacion e-coleccion)))
    (unless coleccion (fallar "No hay ninguna coleccion llamada ~a" e-coleccion))
    (let ((interno (if e-variable
                       (ambito-extendido ambito e-variable coleccion)
                       ambito)))
      (remove-if-not
       (lambda (f)
         (or (null e-condicion)
             (evaluar e-condicion interno entorno
                      (cons (cons e-variable f) ligaduras))))
       (filas-de entorno e-coleccion)))))

(defmethod evaluar ((e conjunto) ambito entorno ligaduras)
  (let ((filas (filas-que-cumplen (coleccion e) (variable e) (condicion e)
                                  ambito entorno ligaduras)))
    (remove-duplicates
     (remove-if #'vacio-p
                (mapcar (lambda (f) (valor-de-campo entorno f (campo e))) filas))
     :test #'iguales-p :from-end t)))

(defmethod evaluar ((e enumeracion) ambito entorno ligaduras)
  (declare (ignore ambito entorno ligaduras))
  (valores e))

(defmethod evaluar ((e relacionadas) ambito entorno ligaduras)
  "Las filas relacionadas, en el orden en que esten.

   Devuelve filas, no valores: quien las quiera mostrar decide que campos
   saca. Es lo que permite que una pagina las liste enteras y una hoja de
   calculo saque solo las que le quepan."
  (filas-que-cumplen (coleccion e) (variable e) (condicion e)
                     ambito entorno ligaduras))

(defmethod evaluar ((e agregado) ambito entorno ligaduras)
  (let* ((filas (filas-que-cumplen (coleccion e) (variable e) (condicion e)
                                   ambito entorno ligaduras))
         (valores (when (campo e)
                    (mapcar (lambda (f) (valor-de-campo entorno f (campo e)))
                            filas))))
    (ecase (operacion e)
      (:cuantas (length filas))
      (:suma (reduce #'+ (mapcar #'como-numero valores) :initial-value 0))
      (:minimo (let ((n (mapcar #'como-numero valores)))
                 (if n (reduce #'min n) nil)))
      (:maximo (let ((n (mapcar #'como-numero valores)))
                 (if n (reduce #'max n) nil)))
      (:distintas (length (remove-duplicates (remove-if #'vacio-p valores)
                                             :test #'iguales-p))))))

(defmethod evaluar ((e busqueda) ambito entorno ligaduras)
  (first (filas-que-cumplen (coleccion e) (variable e) (condicion e)
                            ambito entorno ligaduras)))

(defmethod evaluar ((e proyeccion) ambito entorno ligaduras)
  (let ((f (evaluar (sobre e) ambito entorno ligaduras)))
    (if f
        (valor-de-campo entorno f (campo e))
        (if (por-defecto e)
            (evaluar (por-defecto e) ambito entorno ligaduras)
            nil))))

(defmethod evaluar ((e existe) ambito entorno ligaduras)
  (let* ((situacion (situacion entorno))
         (coleccion (coleccion-llamada situacion (coleccion e)))
         (interno (ambito-extendido ambito (variable e) coleccion))
         (excluida (when (distinta-de e) (fila-ligada ligaduras (distinta-de e)))))
    (unless coleccion (fallar "No hay ninguna coleccion llamada ~a" (coleccion e)))
    (some (lambda (f)
            (and (not (eq f excluida))
                 (evaluar (condicion e) interno entorno
                          (cons (cons (variable e) f) ligaduras))))
          (filas-de entorno (coleccion e)))))

(defmethod evaluar ((e comparten) ambito entorno ligaduras)
  (declare (ignore ambito))
  (let ((a (fila-ligada ligaduras (variable-a e)))
        (b (fila-ligada ligaduras (variable-b e))))
    (let ((valores-a (remove-if #'vacio-p
                                (mapcar (lambda (c) (valor-de-campo entorno a c))
                                        (campos e))))
          (valores-b (remove-if #'vacio-p
                                (mapcar (lambda (c) (valor-de-campo entorno b c))
                                        (campos e)))))
      (and (intersection valores-a valores-b :test #'iguales-p) t))))

(defmethod evaluar ((e vecino) ambito entorno ligaduras)
  (let* ((f (fila-ligada ligaduras (variable e)))
         (coleccion (coleccion f))
         (todas (filas-de entorno (nombre coleccion)))
         (i (indice f))
         (j (if (eq (direccion e) :anterior) (1- i) (1+ i))))
    (unless (orden coleccion)
      (fallar "No se puede hablar de la fila ~(~a~) de ~a: no declara orden"
              (direccion e) (nombre coleccion)))
    (when (and (>= j 0) (< j (length todas)))
      (nth j todas))))

;;; Una referencia a campo sobre una expresion VECINO se escribe como
;;; (DE (ANTERIOR FILA) CAMPO). El lenguaje lo traduce a una PROYECCION cuyo
;;; SOBRE es el nodo VECINO, asi que aqui no hace falta nada mas: PROYECCION
;;; ya sabe que hacer cuando la fila no existe, que es justo el caso de la
;;; primera y la ultima.

;;; ---------------------------------------------------------------------
;;; Marcas
;;; ---------------------------------------------------------------------

(defun marcas-que-disparan (entorno fila)
  "Las marcas de la situacion que se cumplen en FILA.

   Solo se evaluan las marcas cuyo alcance pertenece a la coleccion de la
   fila: una marca senala campos de una coleccion concreta."
  (let ((coleccion (coleccion fila))
        (resultado '()))
    (dolist (m (marcas (situacion entorno)) (nreverse resultado))
      (when (marca-aplica-p m coleccion)
        (let ((ambito (hacer-ambito :ligaduras (list (cons (nombrar "fila") coleccion))
                                    :actual 'fila)))
          (when (evaluar (condicion m) ambito entorno (list (cons (nombrar "fila") fila)))
            (push m resultado)))))))

(defun marca-aplica-p (marca coleccion)
  (if (coleccion marca)
      (eq (coleccion marca) (nombre coleccion))
      (every (lambda (c) (campo-llamado coleccion c)) (alcance marca))))

(defun evaluar-en-fila (entorno fila expresion)
  "El valor de EXPRESION con FILA ligada a la variable de fila.

   Es lo que hace falta para evaluar cualquier cosa que el autor escribio
   pensando en una fila concreta -la condicion de una marca, el filtro de una
   vista- sin que cada arquitectura tenga que rehacer el ambito por su cuenta.
   Que este aqui y no en cada backend es lo que garantiza que las tres
   pregunten lo mismo."
  (when expresion
    (let ((ambito (hacer-ambito :ligaduras (list (cons (nombrar "fila")
                                                       (coleccion fila)))
                                :actual 'fila)))
      (evaluar expresion ambito entorno (list (cons (nombrar "fila") fila))))))

(defun explicacion-de-marca (entorno fila marca)
  "El texto de la explicacion de MARCA en FILA, o NIL si no tiene."
  (when (explicacion marca)
    (let ((ambito (hacer-ambito :ligaduras (list (cons 'fila (coleccion fila)))
                                :actual 'fila)))
      (como-texto (evaluar (explicacion marca) ambito entorno
                           (list (cons (nombrar "fila") fila)))))))

;;; ---------------------------------------------------------------------
;;; Evaluacion completa
;;; ---------------------------------------------------------------------

(defun evaluar-situacion (situacion datos)
  "Calcula todo. Devuelve una lista de (NOMBRE-COLECCION FILAS...), donde
   cada fila es (VALORES . MARCAS): una lista asociativa de campo a valor ya
   calculado, y los nombres de las marcas que disparan.

   Es la forma en que una arquitectura con derivaciones congeladas obtiene lo
   que tiene que escribir, y es tambien lo que la suite de conformidad usa
   como valor esperado."
  (let ((entorno (hacer-entorno situacion datos)))
    (loop for coleccion in (colecciones situacion)
          collect
          (cons (nombre coleccion)
                (loop for fila in (filas-de entorno (nombre coleccion))
                      collect
                      (cons (loop for campo in (campos coleccion)
                                  collect (cons (nombre campo)
                                                (valor-de-campo entorno fila
                                                                (nombre campo))))
                            (mapcar #'nombre (marcas-que-disparan entorno fila))))))))
