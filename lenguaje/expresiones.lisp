;;;; De la forma escrita al nodo de expresion.
;;;;
;;;; Una sola responsabilidad: traducir lo que el usuario escribe a los nodos
;;;; del nucleo. Ocurre en tiempo de expansion de macro, asi que el
;;;; "compilador del lenguaje" es literalmente esta funcion mas las macros de
;;;; macros.lisp. No hay analizador lexico ni sintactico, que es la ventaja
;;;; del DSL interno que identifico Arcia Corcho en 2017.
;;;;
;;;; LA DECISION DE LECTURA MAS IMPORTANTE DE TODO EL LENGUAJE
;;;;
;;;; Dentro de un :DONDE, un simbolo suelto se refiere al campo de la fila
;;;; candidata; para hablar de la fila de fuera hay que decirlo con (DE FILA
;;;; ...). Eso hace que una busqueda por clave se lea asi:
;;;;
;;;;     (la-fila-de tesis :donde (= estudiante (de fila estudiante)))
;;;;
;;;; que en voz alta es "la fila de tesis cuyo estudiante es el estudiante de
;;;; esta fila". Es exactamente la frase del dominio, y es el criterio de
;;;; calidad heredado de LDMAG (2025): el tutor tiene que poder leer una
;;;; descripcion y decir si es correcta sin que se la expliquen.

(in-package #:situacion.lenguaje)

;;; NORMALIZACION DE SIMBOLOS
;;;
;;; Una descripcion se escribe desde el paquete que quiera su autor, asi que
;;; el simbolo FILA que el escribe no es el mismo objeto que el FILA del
;;; nucleo. Comparar por identidad fallaria en cuanto alguien describiera una
;;; situacion desde su propio paquete, que es lo normal.
;;;
;;; Se resuelve en un solo sitio: todo identificador que entra en el arbol se
;;; interna en el paquete del nucleo, y toda palabra del lenguaje se reconoce
;;; por su nombre y no por su identidad. Asi el DSL se puede usar desde
;;; cualquier paquete sin importar nada, que es como tiene que ser un
;;; lenguaje interno.

(defun normalizar (simbolo)
  "El simbolo equivalente en el paquete de los nombres de usuario."
  (if (symbolp simbolo)
      (if (null simbolo) nil (nucleo:nombrar (symbol-name simbolo)))
      simbolo))

(defun normalizar-lista (lista)
  (mapcar #'normalizar lista))

(defun es (simbolo nombre)
  "Cierto si SIMBOLO se llama NOMBRE, sea cual sea su paquete."
  (and (symbolp simbolo) (not (null simbolo))
       (string= (symbol-name simbolo) nombre)))

(defun es-alguno (simbolo &rest nombres)
  (some (lambda (n) (es simbolo n)) nombres))

(defparameter +operadores+
  '("+" "-" "*" "/" "=" "/=" "<" "<=" ">" ">=" "Y" "O" "NO")
  "Operadores que construyen un nodo de aplicacion.

   Van todos en un solo nodo con el operador como simbolo, en vez de una
   clase por operador. La tesis de 2026 tiene EXPR-GT, EXPR-GTE, EXPR-LT,
   EXPR-EQUALS, EXPR-ADD, EXPR-SUBTRACT y una mas por cada operacion; con ese
   diseno, cada arquitectura nueva tiene que escribir un metodo por clase.
   Aqui escribe uno y una tabla.")

(defparameter +variable-candidata+ (nucleo:nombrar "candidata")
  "Variable que se liga implicitamente a la fila candidata dentro de un
   :DONDE. Si hay busquedas anidadas, la interior la sombrea, que es la regla
   de alcance habitual.")

(defun forma-de-operador-p (forma)
  (and (consp forma)
       (symbolp (first forma))
       (member (symbol-name (first forma)) +operadores+ :test #'string=)))

(defun palabra-clave-de (lista clave &optional por-defecto)
  (let ((posicion (position clave lista)))
    (if posicion (nth (1+ posicion) lista) por-defecto)))

(defun compilar-expresion (forma &optional (en-donde nil))
  "Traduce FORMA a un nodo de expresion del nucleo.

   EN-DONDE indica si se esta dentro de un :DONDE, en cuyo caso un simbolo
   suelto se lee como campo de la fila candidata."
  (cond
    ;; Literales.
    ((or (numberp forma) (stringp forma)) `(nucleo:hacer-literal :valor ,forma))
    ((eq forma t) `(nucleo:hacer-literal :valor t))
    ((null forma) `(nucleo:hacer-literal :valor nil))

    ;; Un simbolo suelto dentro de un :DONDE es un campo de la candidata.
    ((symbolp forma)
     (if en-donde
         `(nucleo:hacer-ref-campo :variable ',+variable-candidata+
                                  :campo ',(normalizar forma))
         (error "Simbolo suelto fuera de un :DONDE: ~s.~@
                 Fuera de un :DONDE hay que decir de que fila se habla, con~@
                 (DE FILA ~:*~s) o (DE OTRA ~:*~s)." forma)))

    ((not (consp forma)) (error "No se como leer ~s" forma))

    (t (compilar-forma-compuesta forma en-donde))))

(defun compilar-forma-compuesta (forma en-donde)
  (let ((cabeza (first forma))
        (resto (rest forma)))
    (flet ((c (f) (compilar-expresion f en-donde))
           (c-fuera (f) (compilar-expresion f nil)))
      (cond
        ;; (de FILA campo) y (de (anterior FILA) campo)
        ((es cabeza "DE") (compilar-acceso resto))

        ;; (parametro nombre)
        ((es cabeza "PARAMETRO")
         `(nucleo:hacer-ref-parametro :nombre ',(normalizar (first resto))))

        ;; Aritmetica, comparacion y logica.
        ((forma-de-operador-p forma)
         `(nucleo:hacer-aplicacion
           :operador ',(normalizar cabeza)
           :argumentos (list ,@(mapcar #'c resto))))

        ;; (si prueba entonces si-no)
        ((es cabeza "SI")
         `(nucleo:hacer-condicional :prueba ,(c (first resto))
                                    :entonces ,(c (second resto))
                                    :si-no ,(c (third resto))))

        ;; (sin-escribir x)
        ((es-alguno cabeza "SIN-ESCRIBIR" "VACIO?")
         `(nucleo:hacer-sin-escribir :argumento ,(c (first resto))))

        ;; (texto a b c ...)
        ((es cabeza "TEXTO")
         `(nucleo:hacer-concatenacion :partes (list ,@(mapcar #'c resto))))

        ;; (plural cantidad "singular" "plural")
        ;; (plural cantidad singular plural) -- las dos ramas son expresiones,
        ;; asi que el sustantivo puede venir de los datos: "faltan 5 resmas".
        ((es cabeza "PLURAL")
         `(nucleo:hacer-concordancia :cantidad ,(c (first resto))
                                     :singular ,(c (second resto))
                                     :plural ,(c (third resto))))

        ;; (los campo de coleccion [:donde ...])
        ((es cabeza "LOS") (compilar-conjunto resto))

        ;; (uno-de "a" "b" "c") -- un conjunto escrito a mano
        ((es-alguno cabeza "UNO-DE" "ALGUNO-DE")
         `(nucleo:hacer-enumeracion :valores ',resto))

        ;; (las-filas-de coleccion :donde ...) -- relacion uno a muchos
        ((es cabeza "LAS-FILAS-DE") (compilar-relacionadas resto))

        ;; Agregados.
        ((es cabeza "CUANTAS") (compilar-agregado :cuantas nil resto))
        ((es cabeza "SUMA") (compilar-agregado-de-campo :suma resto))
        ((es cabeza "MINIMO") (compilar-agregado-de-campo :minimo resto))
        ((es cabeza "MAXIMO") (compilar-agregado-de-campo :maximo resto))
        ((es cabeza "CUANTAS-DISTINTAS")
         (compilar-agregado-de-campo :distintas resto))

        ;; (la-fila-de coleccion :donde ...)
        ((es cabeza "LA-FILA-DE") (compilar-busqueda resto))

        ;; (el campo de <busqueda> :si-no valor)
        ((es cabeza "EL") (compilar-proyeccion resto en-donde))

        ;; (existe V :en coleccion :donde ... [:distinta-de W])
        ((es cabeza "EXISTE") (compilar-existe resto))

        ;; (comparten a b (campo ...))
        ((es cabeza "COMPARTEN")
         `(nucleo:hacer-comparten :variable-a ',(normalizar (first resto))
                                  :variable-b ',(normalizar (second resto))
                                  :campos ',(normalizar-lista (third resto))))

        ;; (anterior V) / (siguiente V) sueltos: solo validos dentro de (de ...)
        ((es-alguno cabeza "ANTERIOR" "SIGUIENTE")
         (error "~s solo se puede usar dentro de un acceso: (DE (~(~a~) ~a) CAMPO)"
                forma cabeza (first resto)))

        (t (error "No se como leer la forma ~s.~@
                   Si querias un texto, ponlo entre comillas." forma))))))

(defun compilar-acceso (resto)
  "(de FILA campo) y (de (anterior FILA) campo)."
  (let ((origen (first resto))
        (campo (second resto)))
    ;; El vecino recorre la coleccion entera ordenada, sin particionar. Antes
    ;; se aceptaba (anterior fila :donde ...) y el :DONDE se descartaba sin
    ;; decir nada, con lo que la descripcion se leia como correcta y daba
    ;; numeros mal.
    (when (and (consp origen) (cddr origen))
      (error "~s lleva argumentos de mas.~@
              ANTERIOR y SIGUIENTE recorren la coleccion entera en el orden~@
              que declara, y no saben particionar por ningun campo. Si hace~@
              falta \"el anterior del mismo grupo\", al lenguaje le falta esa~@
              construccion; no es un problema de sintaxis."
             origen))
    (if (symbolp origen)
        `(nucleo:hacer-ref-campo :variable ',(normalizar origen)
                                 :campo ',(normalizar campo))
        ;; (de (anterior fila) campo): el vecino puede no existir, asi que se
        ;; envuelve en una proyeccion, que ya sabe devolver el valor por
        ;; defecto cuando no hay fila. Es el caso de la primera y la ultima.
        (let ((direccion (cond ((es (first origen) "ANTERIOR") :anterior)
                               ((es (first origen) "SIGUIENTE") :siguiente)
                               (t (error "No se como leer el acceso ~s" origen)))))
          `(nucleo:hacer-proyeccion
            :sobre (nucleo:hacer-vecino :direccion ,direccion
                                        :variable ',(normalizar (second origen)))
            :campo ',(normalizar campo)
            :por-defecto (nucleo:hacer-literal :valor nil))))))

(defun compilar-conjunto (resto)
  "(los campo de coleccion [:donde condicion])"
  (destructuring-bind (campo de coleccion &rest opciones) resto
    (declare (ignore de))
    (let ((donde (palabra-clave-de opciones :donde)))
      `(nucleo:hacer-conjunto
        :coleccion ',(normalizar coleccion) :campo ',(normalizar campo)
        :variable ',+variable-candidata+
        :condicion ,(when donde (compilar-expresion donde t))))))

(defun compilar-agregado (operacion campo resto)
  "(cuantas coleccion [:donde condicion])"
  (let* ((coleccion (first resto))
         (opciones (rest resto))
         (donde (palabra-clave-de opciones :donde)))
    `(nucleo:hacer-agregado
      :operacion ,operacion :coleccion ',(normalizar coleccion)
      :campo ',(normalizar campo)
      :variable ',+variable-candidata+
      :condicion ,(when donde (compilar-expresion donde t)))))

(defun compilar-agregado-de-campo (operacion resto)
  "(suma campo de coleccion [:donde condicion])"
  (destructuring-bind (campo de coleccion &rest opciones) resto
    (declare (ignore de))
    (let ((donde (palabra-clave-de opciones :donde)))
      `(nucleo:hacer-agregado
        :operacion ,operacion :coleccion ',(normalizar coleccion)
        :campo ',(normalizar campo)
        :variable ',+variable-candidata+
        :condicion ,(when donde (compilar-expresion donde t))))))

(defun compilar-relacionadas (resto)
  "(las-filas-de coleccion :donde condicion)"
  (let ((coleccion (first resto))
        (donde (palabra-clave-de (rest resto) :donde)))
    (unless donde
      (error "(LAS-FILAS-DE ~a ...) necesita un :DONDE que diga cuales.~@
              Sin condicion serian todas, y para eso esta la coleccion." coleccion))
    `(nucleo:hacer-relacionadas
      :coleccion ',(normalizar coleccion) :variable ',+variable-candidata+
      :condicion ,(compilar-expresion donde t))))

(defun compilar-busqueda (resto)
  "(la-fila-de coleccion :donde condicion)"
  (let ((coleccion (first resto))
        (donde (palabra-clave-de (rest resto) :donde)))
    (unless donde
      (error "(LA-FILA-DE ~a ...) necesita un :DONDE que diga cual." coleccion))
    `(nucleo:hacer-busqueda
      :coleccion ',(normalizar coleccion) :variable ',+variable-candidata+
      :condicion ,(compilar-expresion donde t))))

(defun compilar-proyeccion (resto en-donde)
  "(el campo de <expresion de fila> [:si-no valor])"
  (destructuring-bind (campo de fuente &rest opciones) resto
    (declare (ignore de))
    (let ((si-no (palabra-clave-de opciones :si-no "")))
      `(nucleo:hacer-proyeccion
        :sobre ,(compilar-expresion fuente en-donde)
        :campo ',(normalizar campo)
        :por-defecto ,(compilar-expresion si-no en-donde)))))

(defun compilar-existe (resto)
  "(existe V :en coleccion :donde condicion [:distinta-de W])"
  (let* ((variable (first resto))
         (opciones (rest resto))
         (coleccion (palabra-clave-de opciones :en))
         (donde (palabra-clave-de opciones :donde))
         (distinta (palabra-clave-de opciones :distinta-de)))
    (unless coleccion (error "(EXISTE ~a ...) necesita :EN <coleccion>." variable))
    (unless donde (error "(EXISTE ~a ...) necesita :DONDE <condicion>." variable))
    `(nucleo:hacer-existe
      :variable ',(normalizar variable) :coleccion ',(normalizar coleccion)
      :condicion ,(compilar-expresion donde nil)
      :distinta-de ',(normalizar distinta))))
