;;;; Infraestructura de nodos del arbol.
;;;;
;;;; Una sola responsabilidad: la macro DEFNODO, que declara la clase de un
;;;; nodo y su funcion constructora de una vez.
;;;;
;;;; Es la descendiente directa de DEFNODE (Arcia Corcho, 2017) y de las dos
;;;; DEFCLASS* de 2025 y 2026. Se conserva la idea -declarar un concepto del
;;;; dominio cuesta una linea y no ocho- y se le anaden dos cosas que
;;;; ninguna de las tres tenia:
;;;;
;;;;   1. Una clase base comun, NODO. Las tres tesis anteriores declaran
;;;;      todos sus nodos con la lista de superclases vacia, y por eso no
;;;;      tienen donde colgar comportamiento compartido ni metodos
;;;;      auxiliares. Aqui hay raiz.
;;;;
;;;;   2. Los slots se declaran con su documentacion, y esa documentacion
;;;;      llega a la clase. Un nodo del arbol es la definicion operativa de
;;;;      un concepto del dominio; si no se puede explicar en una linea, el
;;;;      concepto esta mal levantado.

(in-package #:situacion.nucleo)

(defun nombrar (texto)
  "El simbolo con que se identifica algo que el usuario nombro.

   Todos los identificadores de una descripcion pasan por aqui, asi que el
   sistema puede compararlos por identidad sin que importe desde que paquete
   se escribio la descripcion."
  (intern (string-upcase (string texto)) '#:situacion.nombres))

(defclass nodo ()
  ()
  (:documentation
   "Raiz de todos los nodos del arbol.

    Existe para poder colgar de ella comportamiento comun y metodos
    auxiliares. Las tres tesis anteriores de la linea no la tienen: todas
    sus clases declaran superclases vacias, y eso las obliga a repetir en
    cada nodo lo que deberia estar escrito una vez."))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun nombre-constructor (nombre)
    (intern (concatenate 'string "HACER-" (symbol-name nombre))
            (symbol-package nombre)))

  (defun nombre-de-slot (spec)
    (if (consp spec) (first spec) spec))

  (defun documentacion-de-slot (spec)
    (if (consp spec) (second spec) nil)))

(defmacro defnodo (nombre superclases slots &optional documentacion)
  "Declara la clase de un nodo y su funcion constructora.

   SLOTS es una lista de entradas, cada una un simbolo o una lista
   (SIMBOLO DOCUMENTACION). Cada slot recibe accesor e initarg con su propio
   nombre, e INITFORM NIL.

   La funcion constructora se llama HACER-<NOMBRE> y toma argumentos por
   clave. Se separa del nombre de la clase a proposito: asi (CAMPO ...) puede
   seguir siendo un nombre de tipo y no se pisa con nada."
  (let* ((nombres (mapcar #'nombre-de-slot slots))
         (constructor (nombre-constructor nombre)))
    `(progn
       (defclass ,nombre ,(or superclases '(nodo))
         ,(mapcar (lambda (spec)
                    (let ((s (nombre-de-slot spec))
                          (doc (documentacion-de-slot spec)))
                      `(,s :accessor ,s
                           :initarg ,(intern (symbol-name s) :keyword)
                           :initform nil
                           ,@(when doc `(:documentation ,doc)))))
           slots)
         ,@(when documentacion `((:documentation ,documentacion))))
       (defun ,constructor (&key ,@nombres)
         ,(format nil "Construye un nodo ~(~a~)." nombre)
         (make-instance ',nombre
                        ,@(loop for s in nombres
                                append (list (intern (symbol-name s) :keyword) s))))
       ',nombre)))
