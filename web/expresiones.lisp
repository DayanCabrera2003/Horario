;;;; Emision de expresiones a JavaScript.
;;;;
;;;; El mismo arbol que el archivo de formulas de la hoja de calculo traduce a
;;;; notacion A1, aqui traduce a expresiones de JavaScript. Ni un archivo ve
;;;; al otro: los dos se cuelgan de EMITIR-EXPRESION especializando en su
;;;; propia arquitectura.
;;;;
;;;; Comparense las dos traducciones del mismo nodo de busqueda por clave:
;;;;
;;;;   hoja de calculo   IFERROR(VLOOKUP($B4,Tesis!$A$4:$F$23,2,FALSE),"")
;;;;   pagina            (T.find(c => c.estudiante === f.estudiante) ?? {}).tutor ?? ""
;;;;
;;;; La expresion del nucleo es la misma. Lo que cambia es todo lo demas, y
;;;; nada de lo que cambia subio nunca por encima del protocolo.

(in-package #:situacion.web)

(defvar *plan* nil "Plan en curso. Interno de esta arquitectura.")

(defun js-literal (valor)
  (cond ((null valor) "\"\"")
        ((eq valor t) "true")
        ((realp valor) (format nil "~a" valor))
        (t (format nil "~s" (princ-to-string valor)))))

(defun js-variable (simbolo)
  "El nombre de la variable de fila en JavaScript.

   FILA es f; cualquier otra variable ligada usa su propia inicial. No es
   direccionamiento: es como se llaman las cosas en el codigo que se emite, y
   vive enteramente dentro de esta arquitectura."
  (string-downcase (subseq (symbol-name simbolo) 0 1)))

(defun js-coleccion (nombre)
  (format nil "D[~s]" (string-downcase (symbol-name nombre))))

(defun js-campo (nombre)
  (format nil "[~s]" (string-downcase (symbol-name nombre))))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:literal) ambito plan)
  (declare (ignore ambito plan))
  (js-literal (nucleo:valor e)))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:ref-campo) ambito plan)
  (declare (ignore ambito plan))
  (format nil "V(~a~a)" (js-variable (nucleo:variable e)) (js-campo (nucleo:campo e))))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:ref-parametro) ambito plan)
  (declare (ignore ambito))
  (let ((p (nucleo:parametro-llamado (situacion plan) (nucleo:nombre e))))
    (js-literal (and p (nucleo:valor p)))))

(defparameter +operadores-js+
  '(("+" . "+") ("-" . "-") ("*" . "*") ("/" . "/")
    ("=" . "===") ("/=" . "!==") ("<" . "<") ("<=" . "<=") (">" . ">") (">=" . ">="))
  "De operador del lenguaje a operador de JavaScript.")

(defparameter +aritmeticos-js+ '("+" "-" "*" "/")
  "Los infijos que el evaluador de referencia acepta con cualquier numero de
   operandos (NUCLEO:APLICAR-OPERADOR, con REDUCE). Los de comparacion son
   binarios en todo el corpus y no se generalizan sin un uso real que lo pida.")

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:aplicacion) ambito plan)
  (let* ((op (symbol-name (nucleo:operador e)))
         (partes (mapcar (lambda (x) (protocolo:emitir-expresion a x ambito plan))
                         (nucleo:argumentos e)))
         (js (cdr (assoc op +operadores-js+ :test #'string=))))
    (cond
      ;; Con tres o mas operandos, un solo JS entre el primero y el segundo
      ;; dejaba fuera al resto en silencio: (+ a b c) emitia (N(a) + N(b)).
      ;; Cada operando se envuelve en N(...) por separado -no el acumulado-,
      ;; para no terminar coaccionando a numero una subcadena ya compuesta.
      ((member op +aritmeticos-js+ :test #'string=)
       (format nil "(~{N(~a)~^ ~a ~})"
               (loop for (parte . resto) on partes
                     collect parte
                     when resto collect js)))
      ;; Las comparaciones numericas van sobre numeros, no sobre texto: si no,
      ;; "10" seria menor que "9". Es la misma coercion que hace el evaluador
      ;; de referencia, y por eso los dos dan el mismo resultado.
      ((member op '("<" "<=" ">" ">=") :test #'string=)
       (format nil "(N(~a) ~a N(~a))" (first partes) js (second partes)))
      ((string= op "=") (format nil "IG(~a,~a)" (first partes) (second partes)))
      ((string= op "/=") (format nil "(!IG(~a,~a))" (first partes) (second partes)))
      ((string= op "Y") (format nil "(~{~a~^ && ~})" partes))
      ((string= op "O") (format nil "(~{~a~^ || ~})" partes))
      ((string= op "NO") (format nil "(!~a)" (first partes)))
      (t (error "Operador sin traduccion a JavaScript: ~a" op)))))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:condicional) ambito plan)
  (format nil "(~a ? ~a : ~a)"
          (protocolo:emitir-expresion a (nucleo:prueba e) ambito plan)
          (protocolo:emitir-expresion a (nucleo:entonces e) ambito plan)
          (protocolo:emitir-expresion a (nucleo:si-no e) ambito plan)))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:sin-escribir) ambito plan)
  (format nil "VACIO(~a)"
          (protocolo:emitir-expresion a (nucleo:argumento e) ambito plan)))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:concatenacion) ambito plan)
  (format nil "[~{~a~^, ~}].map(T).join(\"\")"
          (mapcar (lambda (x) (protocolo:emitir-expresion a x ambito plan))
                  (nucleo:partes e))))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:concordancia) ambito plan)
  (format nil "(N(~a) === 1 ? ~a : ~a)"
          (protocolo:emitir-expresion a (nucleo:cantidad e) ambito plan)
          (js-literal (nucleo:singular e))
          (js-literal (nucleo:plural e))))

(defun js-filtro (a expresion variable ambito plan)
  "El cuerpo de un filter sobre la coleccion recorrida."
  (if (null expresion)
      "true"
      (protocolo:emitir-expresion a expresion ambito plan)))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:conjunto) ambito plan)
  (format nil "[...new Set(~a.filter(~a => ~a).map(~a => V(~a~a)).filter(x => !VACIO(x)))]"
          (js-coleccion (nucleo:coleccion e))
          (js-variable (nucleo:variable e))
          (js-filtro a (nucleo:condicion e) (nucleo:variable e) ambito plan)
          (js-variable (nucleo:variable e))
          (js-variable (nucleo:variable e))
          (js-campo (nucleo:campo e))))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:agregado) ambito plan)
  (let* ((v (js-variable (nucleo:variable e)))
         (filtrado (format nil "~a.filter(~a => ~a)"
                           (js-coleccion (nucleo:coleccion e)) v
                           (js-filtro a (nucleo:condicion e) (nucleo:variable e)
                                      ambito plan)))
         (valores (when (nucleo:campo e)
                    (format nil "~a.map(~a => V(~a~a))" filtrado v v
                            (js-campo (nucleo:campo e))))))
    (ecase (nucleo:operacion e)
      (:cuantas (format nil "~a.length" filtrado))
      (:suma (format nil "~a.reduce((s,x) => s + N(x), 0)" valores))
      (:minimo (format nil "Math.min(...~a.map(N))" valores))
      (:maximo (format nil "Math.max(...~a.map(N))" valores))
      ;; Nativo. En la hoja de calculo esto exige una columna auxiliar.
      (:distintas (format nil "new Set(~a.filter(x => !VACIO(x))).size" valores)))))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:enumeracion) ambito plan)
  (declare (ignore ambito plan))
  (format nil "[~{~a~^, ~}]" (mapcar #'js-literal (nucleo:valores e))))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:relacionadas) ambito plan)
  "Nativa: un filtro. Sin limite de cuantas, sin maquinaria."
  (format nil "~a.filter(~a => ~a)"
          (js-coleccion (nucleo:coleccion e))
          (js-variable (nucleo:variable e))
          (js-filtro a (nucleo:condicion e) (nucleo:variable e) ambito plan)))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:busqueda) ambito plan)
  (format nil "(~a.find(~a => ~a) ?? null)"
          (js-coleccion (nucleo:coleccion e))
          (js-variable (nucleo:variable e))
          (js-filtro a (nucleo:condicion e) (nucleo:variable e) ambito plan)))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:proyeccion) ambito plan)
  (let ((fuente (nucleo:sobre e)))
    (format nil "PROY(~a, ~s, ~a)"
            (protocolo:emitir-expresion a fuente ambito plan)
            (string-downcase (symbol-name (nucleo:campo e)))
            (if (nucleo:por-defecto e)
                (protocolo:emitir-expresion a (nucleo:por-defecto e) ambito plan)
                "\"\""))))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:existe) ambito plan)
  (let ((v (js-variable (nucleo:variable e))))
    (format nil "~a.some(~a => ~a~a)"
            (js-coleccion (nucleo:coleccion e)) v
            (if (nucleo:distinta-de e)
                (format nil "~a !== ~a && " v (js-variable (nucleo:distinta-de e)))
                "")
            (protocolo:emitir-expresion a (nucleo:condicion e) ambito plan))))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:comparten) ambito plan)
  (declare (ignore ambito plan))
  (format nil "COMPARTEN(~a, ~a, [~{~s~^, ~}])"
          (js-variable (nucleo:variable-a e))
          (js-variable (nucleo:variable-b e))
          (mapcar (lambda (c) (string-downcase (symbol-name c))) (nucleo:campos e))))

(defmethod protocolo:emitir-expresion ((a web) (e nucleo:vecino) ambito plan)
  (declare (ignore plan))
  ;; La coleccion sale del ambito, que es quien sabe sobre que recorre cada
  ;; variable de fila. No hace falta ninguna direccion: en una pagina, la fila
  ;; anterior es el elemento anterior del arreglo ya ordenado.
  (let ((coleccion (nucleo:coleccion-de-variable ambito (nucleo:variable e))))
    (format nil "VECINO(~a, ~a, ~d)"
            (js-coleccion (nucleo:nombre coleccion))
            (js-variable (nucleo:variable e))
            (if (eq (nucleo:direccion e) :anterior) -1 1))))
