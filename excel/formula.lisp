;;;; Emision de expresiones a notacion de hoja de calculo.
;;;;
;;;; Este archivo es el equivalente de COMPILE-EXCEL-FORMULA (Morales Lazo,
;;;; 2026), con dos diferencias que son el argumento entero de la tesis:
;;;;
;;;;   1. El metodo se especializa en EXCEL. Si manana entra otra
;;;;      arquitectura, escribe los suyos y este archivo no se toca. Alli la
;;;;      funcion no recibia el destino, asi que no habia donde enganchar un
;;;;      segundo.
;;;;
;;;;   2. Las direcciones no llegan por parametro: se piden al plan, que es
;;;;      de esta arquitectura. Alli llegaban COL-MAP, FILA, PRIMERA-FILA y
;;;;      ULTIMA-FILA por la firma, con lo que el punto de extension estaba
;;;;      formulado en terminos de hoja de calculo.
;;;;
;;;; La fila que se esta generando es estado interno del backend y viaja en
;;;; una variable especial de este paquete. Que no cruce el protocolo es
;;;; justamente lo que se buscaba.

(in-package #:situacion.excel)

(defvar *fila* nil
  "Numero de fila que se esta generando. Interno de esta arquitectura.")

(defvar *hoja* nil
  "Hoja cuya fila se esta generando.")

(defun texto-de-literal (valor)
  (cond ((null valor) "\"\"")
        ((eq valor t) "TRUE")
        ((realp valor) (format nil "~a" valor))
        ((stringp valor) (format nil "\"~a\"" valor))
        (t (format nil "\"~a\"" valor))))

(defparameter +infijos+
  '(("+" . "+") ("-" . "-") ("*" . "*") ("/" . "/")
    ("=" . "=") ("/=" . "<>") ("<" . "<") ("<=" . "<=") (">" . ">") (">=" . ">="))
  "Operadores que se escriben entre los operandos, por NOMBRE.

   Por nombre y no por simbolo: los operadores los escribe quien redacta la
   descripcion y viven en el paquete de los nombres de usuario, asi que
   compararlos por identidad con los del nucleo fallaria.")

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:literal) ambito plan)
  (declare (ignore ambito plan))
  (texto-de-literal (nucleo:valor e)))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:ref-campo) ambito plan)
  (declare (ignore ambito plan))
  ;; La columna va fijada y la fila relativa: asi la misma expresion vale
  ;; para todas las filas del rango, que es como funciona el motor de la hoja
  ;; de calculo. Ese comportamiento es propio de esta arquitectura y por eso
  ;; la decision se toma aqui y no en el nucleo.
  (celda *hoja* (nucleo:campo e) *fila*))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:ref-parametro) ambito plan)
  (declare (ignore ambito))
  (let ((p (nucleo:parametro-llamado (situacion plan) (nucleo:nombre e))))
    (texto-de-literal (and p (nucleo:valor p)))))

(defparameter +aritmeticos+ '("+" "-" "*" "/")
  "Los infijos que el evaluador de referencia acepta con cualquier numero de
   operandos (NUCLEO:APLICAR-OPERADOR, con REDUCE). Los de comparacion son
   binarios en todo el corpus y no se generalizan sin un uso real que lo pida.")

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:aplicacion) ambito plan)
  (let* ((partes (mapcar (lambda (x) (protocolo:emitir-expresion a x ambito plan))
                         (nucleo:argumentos e)))
         (op (symbol-name (nucleo:operador e)))
         (infijo (cdr (assoc op +infijos+ :test #'string=))))
    (cond
      ;; Con tres o mas operandos, un solo INFIJO entre el primero y el
      ;; segundo dejaba fuera al resto en silencio: (+ a b c) emitia (a+b).
      ((and infijo (member op +aritmeticos+ :test #'string=))
       (format nil "(~a)" (reduce (lambda (x y) (format nil "~a~a~a" x infijo y))
                                  partes)))
      (infijo
       (format nil "(~a~a~a)" (first partes) infijo
               (if (rest partes) (second partes) "")))
      ((string= op "Y") (format nil "AND(~{~a~^,~})" partes))
      ((string= op "O") (format nil "OR(~{~a~^,~})" partes))
      ((string= op "NO") (format nil "NOT(~a)" (first partes)))
      (t (error "Operador sin traduccion a hoja de calculo: ~a" op)))))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:condicional) ambito plan)
  (format nil "IF(~a,~a,~a)"
          (protocolo:emitir-expresion a (nucleo:prueba e) ambito plan)
          (protocolo:emitir-expresion a (nucleo:entonces e) ambito plan)
          (protocolo:emitir-expresion a (nucleo:si-no e) ambito plan)))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:sin-escribir) ambito plan)
  (format nil "(~a=\"\")"
          (protocolo:emitir-expresion a (nucleo:argumento e) ambito plan)))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:concatenacion) ambito plan)
  (format nil "(~{~a~^&~})"
          (mapcar (lambda (x) (protocolo:emitir-expresion a x ambito plan))
                  (nucleo:partes e))))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:concordancia) ambito plan)
  ;; Es la traduccion literal de lo que el corpus escribe a mano en
  ;; departamento/hoja_cobertura.py para no decir "Faltan 1 profesores".
  (format nil "IF(~a=1,~a,~a)"
          (protocolo:emitir-expresion a (nucleo:cantidad e) ambito plan)
          (protocolo:emitir-expresion a (nucleo:singular e) ambito plan)
          (protocolo:emitir-expresion a (nucleo:plural e) ambito plan)))

;;; ---------------------------------------------------------------------
;;; Agregados
;;;
;;; Una hoja de calculo no sabe recorrer con una condicion arbitraria: sabe
;;; contar y sumar sobre un rango con un criterio. Asi que se reconocen las
;;; formas que el corpus usa de verdad y, para lo que no encaje, se pide la
;;; capacidad y el mecanismo de carencias decide. Fallar con un mensaje claro
;;; es mejor que emitir una formula que parece correcta y no lo es.
;;; ---------------------------------------------------------------------

(defun igualdad-simple (condicion)
  "Si CONDICION es (= <campo de la candidata> <expresion de fuera>), devuelve
   (VALUES CAMPO EXPRESION). Si no, NIL."
  (when (and (typep condicion 'nucleo:aplicacion)
             (string= (symbol-name (nucleo:operador condicion)) "=")
             (= 2 (length (nucleo:argumentos condicion))))
    (let ((izq (first (nucleo:argumentos condicion)))
          (der (second (nucleo:argumentos condicion))))
      (when (typep izq 'nucleo:ref-campo)
        (values (nucleo:campo izq) der)))))

(defun criterios-de (condicion)
  "Descompone una condicion en pares (CAMPO . CRITERIO) para COUNTIFS.

   Reconoce las formas que el corpus usa de verdad:
     - una igualdad suelta sobre un campo de la fila candidata
     - una conjuncion de ellas
     - (no (vacio? campo)), que en la hoja de calculo es el criterio \"<>\"
     - (vacio? campo), que es el criterio \"\"

   Devuelve NIL si encuentra algo que no sabe traducir, y entonces quien
   llama falla con un mensaje claro en vez de emitir una formula que parece
   correcta. Era lo que pasaba antes: la condicion mas normal de todas -dos
   igualdades- tumbaba la materializacion entera."
  (labels ((uno (c)
             (cond
               ;; conjuncion: se concatenan los criterios de cada rama
               ((and (typep c 'nucleo:aplicacion)
                     (string= (symbol-name (nucleo:operador c)) "Y"))
                (let ((partes (mapcar #'uno (nucleo:argumentos c))))
                  (when (every #'identity partes) (apply #'append partes))))
               ;; (no (vacio? campo))  ->  campo <> ""
               ((and (typep c 'nucleo:aplicacion)
                     (string= (symbol-name (nucleo:operador c)) "NO")
                     (typep (first (nucleo:argumentos c)) 'nucleo:sin-escribir)
                     (typep (nucleo:argumento (first (nucleo:argumentos c)))
                            'nucleo:ref-campo))
                (list (cons (nucleo:campo (nucleo:argumento
                                           (first (nucleo:argumentos c))))
                            :no-vacio)))
               ;; (vacio? campo)  ->  campo = ""
               ((and (typep c 'nucleo:sin-escribir)
                     (typep (nucleo:argumento c) 'nucleo:ref-campo))
                (list (cons (nucleo:campo (nucleo:argumento c)) :vacio)))
               ;; igualdad
               (t (multiple-value-bind (campo expresion) (igualdad-simple c)
                    (when campo (list (cons campo expresion))))))))
    (uno condicion)))

(defun texto-de-criterio (a criterio ambito plan)
  (case criterio
    (:no-vacio "\"<>\"")
    (:vacio "\"\"")
    (t (protocolo:emitir-expresion a criterio ambito plan))))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:enumeracion) ambito plan)
  (declare (ignore ambito plan))
  ;; Dentro de una formula, un conjunto literal solo tiene sentido como lista
  ;; de un desplegable, y eso lo consume VALORES-DEL-DOMINIO sin pasar por
  ;; aqui. Si alguien lo usa en una expresion de verdad, que lo diga claro.
  (error "Un conjunto escrito a mano solo vale como dominio de entrada; en~@
          una formula no significa nada."))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:relacionadas) ambito plan)
  "Un conteo en vivo sobre la tabla cruda de la hoja auxiliar (H4,
   excel/relacion.lisp), no la lista entera: eso es lo que REQUERIR deja
   claro en el informe -se emula, con limite- y lo que esta formula tiene
   que seguir siendo cierto incluso despues de que REQUERIR deje de
   senalar error.

   COUNTIF con comodin sobre __clave__ es portable entre Excel y LibreOffice
   Calc, a diferencia de una formula matricial. \"Rosa#*\" cuenta todas las
   filas de la tabla cruda cuya clave numerada empieza por la clave de esta
   fila, que es exactamente cuantas relacionadas tiene ahora mismo."
  (declare (ignore ambito))
  (protocolo:requerir a 'protocolo:con-relacion-uno-a-muchos e
                      :detalle (format nil "todas las filas de ~(~a~) relacionadas"
                                       (nucleo:coleccion e)))
  (let* ((detalle (find e (auxiliares plan) :key (lambda (d) (nucleo:expresion (campo d)))))
         (tabla-cruda (tabla-cruda detalle))
         (rango-clave (rango-de-columna tabla-cruda "__clave__" :con-hoja t))
         ;; La clave ENTERA de esta fila, no solo su primer campo: con una
         ;; clave compuesta, dos filas padre pueden compartir el primer
         ;; campo y diferir en el segundo (FORMULA-DE-CLAVE, excel/relacion.
         ;; lisp), y el COUNTIF tiene que buscar por el mismo prefijo que
         ;; CLAVE-DE-FILA escribio en la tabla cruda.
         (clave-de-esta-fila (formula-de-clave *hoja* *fila* (coleccion *hoja*))))
    (format nil "COUNTIF(~a,~a&\"#*\")" rango-clave clave-de-esta-fila)))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:agregado) ambito plan)
  "Contar y sumar sobre un rango con criterios.

   Con un solo criterio sale CONTAR.SI o SUMAR.SI; con varios, sus variantes
   en plural, que es lo que usa departamento/hoja_cobertura.py. Antes solo se
   reconocia el criterio suelto, y la condicion mas normal de todas -dos
   igualdades- tumbaba la materializacion entera."
  (let ((hoja-destino (hoja-de plan (nucleo:coleccion e))))
    (unless hoja-destino
      (error "No hay hoja planificada para ~(~a~)" (nucleo:coleccion e)))
    (cond
      ;; Contar valores distintos: no existe, se emula.
      ((eq (nucleo:operacion e) :distintas)
       (protocolo:requerir a 'protocolo:con-conteo-de-distintos e
                           :detalle (format nil "cuantos valores distintos toma ~(~a~)"
                                            (nucleo:campo e)))
       (let ((rango (rango-de-columna hoja-destino (nucleo:campo e) :con-hoja t)))
         (format nil "SUMPRODUCT((~a<>\"\")/COUNTIF(~a,~a&\"\"))" rango rango rango)))

      ;; Sin condicion: cuantas filas hay escritas.
      ((null (nucleo:condicion e))
       (let ((primera (nucleo:nombre (first (nucleo:campos (coleccion hoja-destino))))))
         (ecase (nucleo:operacion e)
           (:cuantas (format nil "COUNTA(~a)"
                             (rango-de-columna hoja-destino primera :con-hoja t)))
           (:suma (format nil "SUM(~a)"
                          (rango-de-columna hoja-destino (nucleo:campo e) :con-hoja t)))
           (:minimo (format nil "MIN(~a)"
                            (rango-de-columna hoja-destino (nucleo:campo e) :con-hoja t)))
           (:maximo (format nil "MAX(~a)"
                            (rango-de-columna hoja-destino (nucleo:campo e) :con-hoja t))))))

      (t
       (let ((criterios (criterios-de (nucleo:condicion e))))
         (unless criterios
           (error "Esta hoja de calculo sabe agregar con igualdades sobre campos~@
                   y con \"esta escrito\" o \"esta vacio\", combinados con Y.~@
                   La condicion de ~(~a~) tiene algo que no encaja en eso.~@
                   No se emite nada antes que emitir una formula que parezca~@
                   correcta y no lo sea."
                  (nucleo:operacion e)))
         (let ((pares (loop for (campo . criterio) in criterios
                            append (list (rango-de-columna hoja-destino campo
                                                           :con-hoja t)
                                         (texto-de-criterio a criterio ambito plan)))))
           (ecase (nucleo:operacion e)
             (:cuantas
              (if (= 1 (length criterios))
                  (format nil "COUNTIF(~{~a~^,~})" pares)
                  (format nil "COUNTIFS(~{~a~^,~})" pares)))
             (:suma
              (let ((rango-suma (rango-de-columna hoja-destino (nucleo:campo e)
                                                  :con-hoja t)))
                (if (= 1 (length criterios))
                    (format nil "SUMIF(~a,~a,~a)" (first pares) (second pares)
                            rango-suma)
                    (format nil "SUMIFS(~a,~{~a~^,~})" rango-suma pares))))
             ((:minimo :maximo)
              (error "MIN y MAX con criterio no tienen forma portable entre~@
                      Excel y LibreOffice Calc sin formula matricial.")))))))))

;;; ---------------------------------------------------------------------
;;; Busqueda por clave
;;; ---------------------------------------------------------------------

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:proyeccion) ambito plan)
  (let ((fuente (nucleo:sobre e)))
    (cond
      ((typep fuente 'nucleo:busqueda) (emitir-busqueda a e fuente ambito plan))
      ((typep fuente 'nucleo:vecino) (emitir-vecino a e fuente ambito plan))
      (t (error "No se como proyectar ~(~a~) sobre ~a"
                (nucleo:campo e) (type-of fuente))))))

(defun emitir-busqueda (a proyeccion busqueda ambito plan)
  "Una busqueda por clave es BUSCARV, con su guarda de ausencia.

   La guarda no es un adorno: las once busquedas del corpus van envueltas en
   una, porque el usuario escribe la clave antes de que exista la fila
   relacionada. El valor por defecto es la mitad del concepto."
  (let ((hoja-destino (hoja-de plan (nucleo:coleccion busqueda))))
    (unless hoja-destino
      (error "No hay hoja planificada para ~(~a~)" (nucleo:coleccion busqueda)))
    (multiple-value-bind (campo-clave expresion) (igualdad-simple (nucleo:condicion busqueda))
      (unless campo-clave
        (error "Esta hoja de calculo busca por una igualdad sobre un campo.~@
                La condicion de la busqueda en ~(~a~) es mas complicada."
               (nucleo:coleccion busqueda)))
      (let* ((campos (nucleo:campos (coleccion hoja-destino)))
             (pos-clave (position campo-clave campos :key #'nucleo:nombre))
             (pos-valor (position (nucleo:campo proyeccion) campos :key #'nucleo:nombre)))
        (when (< pos-valor pos-clave)
          (error "BUSCARV solo mira a la derecha de la clave, y ~(~a~) esta a~@
                  la izquierda de ~(~a~) en ~(~a~)."
                 (nucleo:campo proyeccion) campo-clave (nucleo:coleccion busqueda)))
        (format nil "IFERROR(VLOOKUP(~a,~a,~d,FALSE),~a)"
                (protocolo:emitir-expresion a expresion ambito plan)
                (rango-de-tabla hoja-destino pos-clave)
                (1+ (- pos-valor pos-clave))
                (protocolo:emitir-expresion a (nucleo:por-defecto proyeccion)
                                            ambito plan))))))

(defun rango-de-tabla (hoja desde-columna)
  "El rectangulo que BUSCARV necesita: desde la columna de la clave hasta la
   ultima, por todas las filas de la capacidad."
  (let* ((campos (nucleo:campos (coleccion hoja)))
         (primera (letra-de-columna desde-columna))
         (ultima (letra-de-columna (1- (length campos)))))
    (format nil "~a!$~a$~d:$~a$~d"
            (entrecomillar (nombre hoja))
            primera (fila-primera hoja) ultima (fila-ultima hoja))))

(defun emitir-vecino (a proyeccion vecino ambito plan)
  "La fila anterior o la siguiente, que en una rejilla es una fila mas arriba
   o mas abajo.

   Es legal solo porque la coleccion declara orden y porque el plan se ha
   comprometido a escribir las filas en ese orden. Sin esa declaracion, esto
   seria el modelo de la hoja de calculo colandose en el lenguaje."
  (declare (ignore ambito plan))
  (let* ((desplazamiento (if (eq (nucleo:direccion vecino) :anterior) -1 1))
         (fila (+ *fila* desplazamiento)))
    (if (or (< fila (fila-primera *hoja*)) (> fila (fila-ultima *hoja*)))
        (texto-de-literal nil)
        (celda *hoja* (nucleo:campo proyeccion) fila))))

;;; ---------------------------------------------------------------------
;;; Cuantificador existencial
;;;
;;; Una hoja de calculo no tiene cuantificadores. Se emula con la suma de
;;; productos de vectores booleanos, que es el idioma establecido y el que
;;; usa el corpus. Se reconocen las conjunciones de igualdades entre filas y
;;; el "comparten", que es lo que aparece de verdad en los tres libros.
;;; ---------------------------------------------------------------------

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:existe) ambito plan)
  (let* ((hoja-destino (hoja-de plan (nucleo:coleccion e)))
         (factores (factores-de-existencia a e (nucleo:condicion e) hoja-destino
                                           ambito plan)))
    (when (nucleo:distinta-de e)
      ;; Excluir la propia fila. En el corpus esto se hace comparando el
      ;; numero de fila; aqui sale de que :DISTINTA-DE lo diga el lenguaje en
      ;; vez de esconderse en la formula.
      (push (format nil "(ROW(~a)<>ROW(~a))"
                    (rango-de-columna hoja-destino
                                      (nucleo:nombre (first (nucleo:campos
                                                             (coleccion hoja-destino))))
                                      :con-hoja t)
                    (celda *hoja* (nucleo:nombre (first (nucleo:campos (coleccion *hoja*))))
                           *fila*))
            factores))
    (format nil "(SUMPRODUCT(~{~a~^*~})>0)" (reverse factores))))

(defun factores-de-existencia (a existe condicion hoja-destino ambito plan)
  "Descompone la condicion de un cuantificador en factores multiplicables."
  (cond
    ;; Conjuncion: cada termino es un factor.
    ((and (typep condicion 'nucleo:aplicacion)
          (string= (symbol-name (nucleo:operador condicion)) "Y"))
     (loop for termino in (nucleo:argumentos condicion)
           append (factores-de-existencia a existe termino hoja-destino ambito plan)))

    ;; Igualdad entre un campo de la candidata y una expresion de fuera.
    ((and (typep condicion 'nucleo:aplicacion)
          (string= (symbol-name (nucleo:operador condicion)) "=")
          (typep (first (nucleo:argumentos condicion)) 'nucleo:ref-campo)
          (eq (nucleo:variable (first (nucleo:argumentos condicion)))
              (nucleo:variable existe)))
     (list (format nil "(~a=~a)"
                   (rango-de-columna hoja-destino
                                     (nucleo:campo (first (nucleo:argumentos condicion)))
                                     :con-hoja t)
                   (protocolo:emitir-expresion a (second (nucleo:argumentos condicion))
                                               ambito plan))))

    ;; Comparten: alguna de las columnas de la candidata coincide con alguna
    ;; de las de esta fila. Se despliega en una suma de productos.
    ((typep condicion 'nucleo:comparten)
     (list (format nil "((~{~a~^+~})>0)"
                   (loop for campo-aqui in (nucleo:campos condicion)
                         append (loop for campo-alla in (nucleo:campos condicion)
                                      collect (format nil "(~a=~a)"
                                                      (rango-de-columna hoja-destino
                                                                        campo-alla
                                                                        :con-hoja t)
                                                      (celda *hoja* campo-aqui *fila*)))))))

    (t (error "Esta hoja de calculo no sabe traducir esta condicion de~@
               existencia. Solo entiende conjunciones de igualdades entre~@
               filas y COMPARTEN."))))
