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
;;;;
;;;; LA SEMANTICA ES LA DEL EVALUADOR, NO LA DE LA HOJA DE CALCULO
;;;;
;;;; Una hoja de calculo compara textos sin distinguir mayusculas, trata "*"
;;;; y "?" como comodines en sus funciones de criterio, y no sabe sumar una
;;;; celda que vale "". El evaluador de referencia hace otra cosa en los tres
;;;; casos, y es el que define el lenguaje. Por eso aqui:
;;;;
;;;;   - la igualdad se compila a EXACT, que distingue mayusculas y no tiene
;;;;     comodines;
;;;;   - cada operando de una comparacion de orden o de una operacion
;;;;     aritmetica pasa por COMO-NUMERO-EXCEL, que da lo mismo que
;;;;     NUCLEO:COMO-NUMERO: una celda vacia o un "" valen 0, un texto ISO de
;;;;     fecha u hora vale su numero, y una fecha tecleada de verdad tambien;
;;;;   - un numero que entra en un texto se escribe con la misma regla de
;;;;     presentacion que el evaluador (NUCLEO:TEXTO-DE-NUMERO).
;;;;
;;;; Los agregados, las busquedas y el cuantificador viven en sus propios
;;;; archivos (agregados.lisp, busqueda.lisp, existencia.lisp).

(in-package #:situacion.excel)

(defvar *fila* nil
  "Numero de fila que se esta generando. Interno de esta arquitectura.")

(defvar *hoja* nil
  "Hoja cuya fila se esta generando.")

(defvar *valores-de-marca* '()
  "Lista asociativa de (VARIABLE . CELDA) para la variable de una marca
   :POR-CAMPO mientras se traduce su condicion para un campo: la variable es
   la celda de ese campo en la fila *FILA* (fase 2, hueco C7).")

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:ref-valor) ambito plan)
  (declare (ignore ambito plan))
  (or (cdr (assoc (nucleo:nombre e) *valores-de-marca*))
      (error "La variable ~(~a~) no esta ligada en esta formula." (nucleo:nombre e))))

(defun condicion-de-marca (a marca ambito plan &optional campo)
  "La condicion de MARCA en la fila *FILA*, como formula. Para una marca
   :POR-CAMPO, la de CAMPO: su variable es la celda de ese campo."
  (let ((*valores-de-marca* (if (and campo (nucleo:por-campo marca))
                                (acons (nucleo:por-campo marca) (celda *hoja* campo *fila*)
                                       *valores-de-marca*)
                                *valores-de-marca*)))
    (condicion-excel a (nucleo:condicion marca) ambito plan)))

(defun condicion-de-marca-en-fila (a marca ambito plan)
  "Si MARCA se cumple en la fila *FILA*: su condicion, o para una marca
   :POR-CAMPO, que se cumpla en alguno de sus campos."
  (if (nucleo:por-campo marca)
      (format nil "OR(~{~a~^,~})"
              (mapcar (lambda (campo) (condicion-de-marca a marca ambito plan campo))
                      (nucleo:alcance marca)))
      (condicion-de-marca a marca ambito plan)))

(defvar *candidata* nil
  "Mientras se traduce la condicion de un recorrido (EXISTE, un agregado),
   (VARIABLE . HOJA) de la fila candidata. Una referencia a esa variable no
   es una celda de esta fila: es la columna entera de la hoja recorrida, como
   rango.")

;;; ---------------------------------------------------------------------
;;; Literales
;;; ---------------------------------------------------------------------

(defun cadena-excel (texto)
  "TEXTO como literal de cadena de una formula: entre comillas dobles y con
   las comillas de dentro duplicadas, que es como las escapa la hoja de
   calculo. Sin esto, un valor con comillas rompia la formula entera."
  (with-output-to-string (s)
    (write-char #\" s)
    (loop for c across texto
          do (when (char= c #\") (write-char #\" s))
             (write-char c s))
    (write-char #\" s)))

(defun texto-de-literal (valor)
  (cond ((null valor) "\"\"")
        ((eq valor t) "TRUE")
        ((realp valor) (nucleo:escritura-de-numero valor))
        ((stringp valor) (cadena-excel valor))
        (t (cadena-excel (princ-to-string valor)))))

(defun literal-p (expresion)
  "Cierto si EXPRESION es un literal del lenguaje."
  (typep expresion 'nucleo:literal))

(defun como-numero-excel (fragmento)
  "FRAGMENTO de formula convertido a numero como lo convierte el evaluador.

   VALUE sobre el texto del valor reconoce numeros, fechas ISO y horas HH:MM;
   lo que no reconoce -la cadena vacia, un texto cualquiera- vale 0, que es
   lo que hace NUCLEO:COMO-NUMERO. Concatenar con \"\" antes es lo que hace
   que una fecha tecleada de verdad (un numero de serie) y una fecha escrita
   como texto den el mismo numero."
  (format nil "IFERROR(VALUE(~a&\"\"),0)" fragmento))

(defun operando-numerico (a expresion ambito plan)
  "EXPRESION traducida como operando de aritmetica o de comparacion de orden.
   Un literal numerico va tal cual; todo lo demas pasa por la coercion."
  (if (and (literal-p expresion) (realp (nucleo:valor expresion)))
      (texto-de-literal (nucleo:valor expresion))
      (como-numero-excel (protocolo:emitir-expresion a expresion ambito plan))))

(defun operando-de-igualdad (a expresion ambito plan)
  "EXPRESION traducida como operando de una igualdad. El literal T es el
   booleano verdadero, que el lenguaje representa como la cadena \"si\"."
  (if (and (literal-p expresion) (eq (nucleo:valor expresion) t))
      (cadena-excel "si")
      (protocolo:emitir-expresion a expresion ambito plan)))

(defun texto-de-presentacion (fragmento)
  "FRAGMENTO de formula convertido a texto para concatenarlo, con la regla de
   presentacion del evaluador: un numero se redondea a 10 cifras
   significativas antes de convertirlo, asi que 52.333333333333336 se lee
   52.33333333 en la hoja igual que en el texto plano y en la pagina."
  (format nil "IF(ISNUMBER(~a),IF(~a=0,\"0\",ROUND(~a,9-INT(LOG10(ABS(~a))))&\"\"),~a&\"\")"
          fragmento fragmento fragmento fragmento fragmento))

(defun condicion-excel (a expresion ambito plan)
  "EXPRESION traducida para usarla como condicion de un SI, de Y, O o NO, o
   de una regla de formato. Si por su forma ya es verdadero o falso, tal
   cual. Si no -un campo que vale \"si\" o \"no\", un numero-, se juzga
   como el evaluador (NUCLEO:VERDADERO-P): verdadero si es \"si\", VERDADERO
   o un numero distinto de cero."
  (let ((formula (protocolo:emitir-expresion a expresion ambito plan)))
    (if (nucleo:expresion-booleana-p expresion)
        formula
        (format nil "OR(EXACT(~a&\"\",\"si\"),EXACT(~a&\"\",\"TRUE\"),IFERROR(1*~a<>0,FALSE))"
                formula formula formula))))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:literal) ambito plan)
  (declare (ignore ambito plan))
  (texto-de-literal (nucleo:valor e)))

;;; ---------------------------------------------------------------------
;;; Referencias
;;; ---------------------------------------------------------------------

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:ref-campo) ambito plan)
  (declare (ignore ambito plan))
  (if (and *candidata* (eq (nucleo:variable e) (car *candidata*)))
      ;; La fila candidata de un recorrido: se recorre la columna entera.
      (rango-de-columna (cdr *candidata*) (nucleo:campo e) :con-hoja t)
      ;; La columna va fijada y la fila relativa: asi la misma expresion vale
      ;; para todas las filas del rango, que es como funciona el motor de la
      ;; hoja de calculo. Ese comportamiento es propio de esta arquitectura y
      ;; por eso la decision se toma aqui y no en el nucleo.
      (celda *hoja* (nucleo:campo e) *fila*)))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:ref-parametro) ambito plan)
  "Un parametro de entrada se cita por su celda de la hoja de parametros,
   para que cambiarlo ahi cambie todo lo que depende de el. Uno fijo se
   copia en la formula (excel/parametros.lisp)."
  (declare (ignore ambito))
  (let ((p (nucleo:parametro-llamado (situacion plan) (nucleo:nombre e))))
    (or (and p (celda-de-parametro plan p))
        (texto-de-literal (and p (nucleo:valor p))))))

;;; ---------------------------------------------------------------------
;;; Operadores
;;; ---------------------------------------------------------------------

(defparameter +aritmeticos+ '(("+" . "+") ("-" . "-") ("*" . "*") ("/" . "/"))
  "Los operadores aritmeticos, por NOMBRE. El evaluador de referencia los
   acepta con cualquier numero de operandos (NUCLEO:APLICAR-OPERADOR, con
   REDUCE), y aqui tambien.

   Por nombre y no por simbolo: los operadores los escribe quien redacta la
   descripcion y viven en el paquete de los nombres de usuario, asi que
   compararlos por identidad con los del nucleo fallaria.")

(defparameter +de-orden+ '(("<" . "<") ("<=" . "<=") (">" . ">") (">=" . ">="))
  "Las comparaciones de orden. Comparan numeros, como el evaluador.")

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:aplicacion) ambito plan)
  (let* ((op (symbol-name (nucleo:operador e)))
         (argumentos (nucleo:argumentos e))
         (aritmetico (cdr (assoc op +aritmeticos+ :test #'string=)))
         (de-orden (cdr (assoc op +de-orden+ :test #'string=))))
    (flet ((numericos ()
             (mapcar (lambda (x) (operando-numerico a x ambito plan)) argumentos))
           (condiciones ()
             (mapcar (lambda (x) (condicion-excel a x ambito plan)) argumentos)))
      (cond
        ;; La division por cero da vacio en el evaluador, no un error.
        ((string= op "/")
         (let ((partes (numericos)))
           (format nil "IFERROR(~a,\"\")"
                   (format nil "(~a)" (reduce (lambda (x y) (format nil "~a/~a" x y))
                                              partes)))))
        ;; El menos de un solo operando es el cambio de signo.
        ((and (string= op "-") (null (rest argumentos)))
         (format nil "(-~a)" (first (numericos))))
        (aritmetico
         (format nil "(~a)" (reduce (lambda (x y) (format nil "~a~a~a" x aritmetico y))
                                    (numericos))))
        (de-orden
         (let ((partes (numericos)))
           (format nil "(~a~a~a)" (first partes) de-orden (second partes))))
        ;; Igualdad literal: distingue mayusculas y no tiene comodines.
        ((string= op "=")
         (format nil "EXACT(~a,~a)"
                 (operando-de-igualdad a (first argumentos) ambito plan)
                 (operando-de-igualdad a (second argumentos) ambito plan)))
        ((string= op "/=")
         (format nil "NOT(EXACT(~a,~a))"
                 (operando-de-igualdad a (first argumentos) ambito plan)
                 (operando-de-igualdad a (second argumentos) ambito plan)))
        ;; (redondear E N): ROUND redondea igual que el evaluador, con el
        ;; empate alejandose de cero. Un vacio sigue vacio.
        ((string= op "REDONDEAR")
         (let ((valor (protocolo:emitir-expresion a (first argumentos) ambito plan)))
           (format nil "IF(LEN(~a&\"\")=0,\"\",ROUND(~a,~d))"
                   valor (como-numero-excel valor) (nucleo:valor (second argumentos)))))
        ((string= op "Y") (format nil "AND(~{~a~^,~})" (condiciones)))
        ((string= op "O") (format nil "OR(~{~a~^,~})" (condiciones)))
        ((string= op "NO") (format nil "NOT(~a)" (first (condiciones))))
        (t (error "Operador sin traduccion a hoja de calculo: ~a" op))))))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:condicional) ambito plan)
  (format nil "IF(~a,~a,~a)"
          (condicion-excel a (nucleo:prueba e) ambito plan)
          (protocolo:emitir-expresion a (nucleo:entonces e) ambito plan)
          (protocolo:emitir-expresion a (nucleo:si-no e) ambito plan)))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:sin-escribir) ambito plan)
  (format nil "(~a=\"\")"
          (protocolo:emitir-expresion a (nucleo:argumento e) ambito plan)))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:concatenacion) ambito plan)
  ;; Las partes que son texto escrito en la descripcion van tal cual; las
  ;; demas pasan por la regla de presentacion, porque pueden ser numeros.
  (format nil "(~{~a~^&~})"
          (mapcar (lambda (x)
                    (if (and (literal-p x) (not (realp (nucleo:valor x))))
                        (protocolo:emitir-expresion a x ambito plan)
                        (texto-de-presentacion
                         (protocolo:emitir-expresion a x ambito plan))))
                  (nucleo:partes e))))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:concordancia) ambito plan)
  ;; Es la traduccion literal de lo que el corpus escribe a mano en
  ;; departamento/hoja_cobertura.py para no decir "Faltan 1 profesores".
  (format nil "IF(~a=1,~a,~a)"
          (operando-numerico a (nucleo:cantidad e) ambito plan)
          (protocolo:emitir-expresion a (nucleo:singular e) ambito plan)
          (protocolo:emitir-expresion a (nucleo:plural e) ambito plan)))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:forma-invalida) ambito plan)
  (declare (ignore ambito plan))
  ;; Plan aprobado de tipos, seccion 4.2: se degrada, y el informe lo dice.
  (protocolo:requerir a 'protocolo:con-validacion-de-forma e
                      :detalle (format nil "la forma de ~(~a~)" (nucleo:campo e)))
  "FALSE()")

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:enumeracion) ambito plan)
  (declare (ignore ambito plan))
  ;; Dentro de una formula, un conjunto literal solo tiene sentido como lista
  ;; de un desplegable, y eso lo consume VALORES-DEL-DOMINIO sin pasar por
  ;; aqui. Si alguien lo usa en una expresion de verdad, que lo diga claro.
  (error "Un conjunto escrito a mano solo vale como dominio de entrada; en~@
          una formula no significa nada."))
