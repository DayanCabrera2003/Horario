;;;; Paquete del lenguaje.
;;;;
;;;; Aqui estan las macros con las que se escribe una descripcion. Es la
;;;; unica capa que el usuario del lenguaje toca.
;;;;
;;;; Ninguna arquitectura depende de este paquete, y eso lo comprueba el
;;;; invariante I3. El contrato de extension se define contra el dominio, no
;;;; contra la sintaxis: un backend recibe nodos del arbol, no formas del
;;;; lenguaje, y por eso cambiar la sintaxis no rompe ningun backend.

(defpackage #:situacion.lenguaje
  (:use #:common-lisp)
  (:nicknames #:lenguaje)
  (:documentation
   "Sintaxis del lenguaje: las macros que construyen el arbol en tiempo de
    expansion.")
  (:export #:defsituacion
           #:compilar-expresion
           #:situacion-llamada #:situaciones-declaradas))
