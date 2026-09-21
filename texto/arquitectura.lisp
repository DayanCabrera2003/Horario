;;;; La arquitectura de texto plano.
;;;;
;;;; POR QUE EXISTE ESTA ARQUITECTURA
;;;;
;;;; No para producir documentos. Existe para que haya DOS arquitecturas
;;;; desde el primer dia, que es la unica salvaguarda real contra el error de
;;;; 2026: un protocolo disenado mirando un solo destino sale con la forma de
;;;; ese destino, se escriba cuando se escriba.
;;;;
;;;; Y se elige texto plano precisamente porque NO PUEDE CASI NADA. No tiene
;;;; rejilla, ni formulas, ni color, ni entrada. Eso obliga a que la
;;;; maquinaria de degradacion exista desde el principio en vez de ser un
;;;; capitulo que se escribe al final: su primer informe de conformidad ya
;;;; trae degradaciones de verdad.
;;;;
;;;; Solo declara CON-MARCADO-TEXTUAL. Todo lo demas lo degrada, y cada
;;;; degradacion dice en que consiste.

(defpackage #:situacion.texto
  (:use #:common-lisp)
  (:documentation "Arquitectura de salida a texto plano.")
  (:export #:texto #:hacer-texto))

(in-package #:situacion.texto)

(defclass texto (protocolo:con-tabla-cruzada
                 protocolo:con-particion-de-vista
                 protocolo:con-agrupacion-en-vista
                 protocolo:con-filtro-de-vista
                 protocolo:con-casilla-en-conflicto
                 protocolo:con-marcado-textual
                 protocolo:con-busqueda-por-clave
                 protocolo:con-orden-declarado)
  ()
  (:documentation
   "Salida a texto plano: una tabla alineada por coleccion, con los valores
    ya calculados y el estado escrito en palabras."))

(defun hacer-texto () (make-instance 'texto))

;;; ---------------------------------------------------------------------
;;; Que hace cuando le piden algo que no tiene
;;;
;;; Notese que casi todo se DEGRADA y casi nada se RECHAZA. La frontera es
;;; la que se declara en el protocolo: se degrada cuando el resultado sigue
;;; cumpliendo el proposito por otra via; se rechaza cuando pareceria
;;; correcto y no lo seria.
;;; ---------------------------------------------------------------------

(defmethod protocolo:resolver-carencia ((a texto) capacidad nodo)
  (declare (ignore nodo))
  (case capacidad
    (protocolo:con-derivacion-viva
     (values :degrada "los valores se calculan al generar y no se recalculan"))
    (protocolo:con-entrada
     (values :degrada "se escribe el valor actual; el documento no es editable"))
    (protocolo:con-dominio-de-entrada
     (values :degrada "los valores admisibles se listan al pie de la tabla"))
    (protocolo:con-marcado-visual
     (values :degrada "el estado se escribe en una columna, sin color"))
    (protocolo:con-navegacion
     (values :emula "las vistas se apilan con un indice al principio"))
    (protocolo:con-crecimiento
     (values :degrada "se escribe lo que hay; para anadir filas hay que regenerar"))
    (protocolo:con-agrupacion
     (values :emula
             "las filas se calculan al generar y quedan fijas. Si despues
              aparece un valor nuevo en la coleccion de origen, no aparece
              una fila para el: hay que volver a generar."))

    (protocolo:con-relacion-uno-a-muchos
     (values :cumple "las filas relacionadas se escriben separadas por comas"))
    (t (values :rechaza
               (format nil "texto plano no tiene nada parecido a ~(~a~)"
                       capacidad)))))
