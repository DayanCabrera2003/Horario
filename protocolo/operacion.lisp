;;;; Declaracion de operaciones del protocolo.
;;;;
;;;; Una sola responsabilidad: que no se pueda declarar una operacion del
;;;; protocolo que no reciba la arquitectura.
;;;;
;;;; POR QUE ESTE ARCHIVO EXISTE
;;;;
;;;; La tesis de 2026 (Morales Lazo) define dos operaciones de traduccion.
;;;; La de la estructura recibe el destino:
;;;;
;;;;     (defgeneric generate-code (nodo lang stream))
;;;;
;;;; y la de las expresiones -que es donde esta toda la sustancia del
;;;; lenguaje: columnas calculadas, comparaciones, conteos, el cuantificador
;;;; existencial- no:
;;;;
;;;;     (defgeneric compile-excel-formula
;;;;         (nodo col-map data-names fila primera-fila ultima-fila))
;;;;
;;;; Dos fallos, y los dos en la misma linea. No hay a donde enganchar una
;;;; segunda arquitectura, porque la operacion no despacha sobre ninguna. Y
;;;; sus parametros son de hoja de calculo: COL-MAP es un diccionario de
;;;; simbolo de columna a letra de Excel, y FILA, PRIMERA-FILA y ULTIMA-FILA
;;;; son numeros de fila. El punto de extension estaba formulado en terminos
;;;; del unico destino que existia.
;;;;
;;;; Aqui eso no se corrige con una convencion ni con una revision: se
;;;; corrige haciendo que el sistema no admita la forma incorrecta. Quien
;;;; intente anadir al protocolo una operacion sin arquitectura, no compila.

(in-package #:situacion.protocolo)

(eval-when (:compile-toplevel :load-toplevel :execute)

  (defvar *operaciones* '()
    "Registro de las operaciones del protocolo, en orden inverso de
     declaracion. Cada entrada es (NOMBRE . LAMBDA-LISTA).

     Se guarda la lambda-lista y no solo el nombre porque el invariante I2
     la comprueba, y leerla de aqui evita tener que usar el MOP, que no es
     Common Lisp estandar. El protocolo no debe depender de extensiones de
     una implementacion concreta: quien anada una arquitectura tiene que
     poder cargarlo con un SBCL recien instalado y nada mas.")

  (defun registrar-operacion (nombre lambda-lista)
    "Anota NOMBRE con su LAMBDA-LISTA en el registro de operaciones."
    (setf *operaciones*
          (cons (cons nombre lambda-lista)
                (remove nombre *operaciones* :key #'car)))
    nombre)

  (defun operaciones-registradas ()
    "Las operaciones del protocolo, en orden de declaracion.
     Devuelve una lista de (NOMBRE . LAMBDA-LISTA)."
    (reverse *operaciones*))

  (defun parametro-de-arquitectura-p (lambda-lista)
    "Cierto si LAMBDA-LISTA empieza por un parametro requerido llamado
     ARQUITECTURA.

     Se compara por nombre y no por identidad de simbolo a proposito: asi la
     comprobacion sigue valiendo si algun dia el protocolo se declara desde
     otro paquete."
    (let ((primero (first lambda-lista)))
      (and (symbolp primero)
           (not (null primero))
           (string= (symbol-name primero) (symbol-name '#:arquitectura))))))

(defmacro definir-operacion (nombre lambda-lista &body opciones)
  "Declara una operacion del protocolo.

   Identica a DEFGENERIC salvo por dos cosas:

     1. Exige que el primer parametro sea ARQUITECTURA. Si no lo es, senala
        un error en tiempo de expansion y el sistema no compila. Es el
        invariante I2, hecho cumplir por construccion en vez de vigilado.

     2. Registra la operacion, para que las pruebas puedan recorrer el
        protocolo entero y comprobar que no se ha colado ninguna por otra
        via."
  (unless (parametro-de-arquitectura-p lambda-lista)
    (error "La operacion ~s del protocolo no recibe la arquitectura.~@
            Su lambda-lista es ~s y tiene que empezar por ARQUITECTURA.~@
            ~@
            Una operacion que no despacha sobre la arquitectura no tiene~@
            donde enganchar una segunda: es el fallo que dejo sin cerrar la~@
            tesis de 2026 y que este trabajo se propone corregir. Ver~@
            documentacion/tesis/02-ARQUITECTURA.md, seccion 5.3."
           nombre lambda-lista))
  `(progn
     (eval-when (:compile-toplevel :load-toplevel :execute)
       (registrar-operacion ',nombre ',lambda-lista))
     (defgeneric ,nombre ,lambda-lista ,@opciones)))
