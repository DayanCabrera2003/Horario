;;;; La arquitectura web.
;;;;
;;;; Se elige por ser lo mas distinto posible de una hoja de calculo
;;;; manteniendo el recalculo vivo: no tiene rejilla, no tiene direcciones, no
;;;; tiene capacidad reservada. Si el protocolo estuviera formulado en
;;;; terminos de hoja de calculo, la web lo reventaria de inmediato. Es el
;;;; backend que obliga a que la representacion intermedia sea honesta.
;;;;
;;;; Y da la vuelta a dos capacidades: el crecimiento y el conteo de
;;;; distintos, que la hoja de calculo tiene que emular con maquinaria, aqui
;;;; son nativos. No hay una arquitectura que pueda mas y otras que puedan
;;;; menos: cada una puede cosas distintas.
;;;;
;;;; Nota sobre el alcance: esta arquitectura no pretende ser una aplicacion
;;;; web de produccion. Pretende demostrar que la misma descripcion, sin
;;;; tocar una linea, produce un artefacto con el mismo comportamiento vivo
;;;; en un destino que no comparte nada con el primero.

(defpackage #:situacion.web
  (:use #:common-lisp)
  (:documentation "Arquitectura de salida a pagina web con recalculo vivo.")
  (:export #:web #:hacer-web))

(in-package #:situacion.web)

(defclass web (protocolo:con-tabla-cruzada
               protocolo:con-derivacion-viva
                 protocolo:con-busqueda-por-clave
               protocolo:con-entrada
               protocolo:con-dominio-de-entrada
               protocolo:con-orden-declarado
               protocolo:con-crecimiento
               protocolo:con-relacion-uno-a-muchos
               protocolo:con-conteo-de-distintos
               protocolo:con-marcado-visual
               protocolo:con-marcado-textual
               protocolo:con-navegacion)
  ()
  (:documentation
   "Salida a una pagina autonoma con recalculo vivo.

    No hereda de CON-REJILLA porque no la tiene, y resulta que no le hace
    falta: ninguna descripcion pide una rejilla, porque la rejilla nunca fue
    un concepto del dominio."))

(defun hacer-web () (make-instance 'web))

(defmethod protocolo:resolver-carencia ((a web) capacidad nodo)
  (declare (ignore nodo))
  (case capacidad
    (protocolo:con-rejilla
     (values :degrada "se dibuja una tabla, pero sin direcciones ni coordenadas"))
    (protocolo:con-agrupacion
     (values :emula
             "las filas se calculan al generar y quedan fijas. Si despues
              aparece un valor nuevo en la coleccion de origen, no aparece
              una fila para el: hay que volver a generar."))

    (protocolo:con-particion-de-vista
     (values :rechaza
             "la vista se parte por un campo y esta arquitectura todavia no lo
              materializa. No se degrada a proposito: una rejilla que ignora la
              particion no es una version mas pobre de lo que se pidio, es una
              tabla que mezcla filas de secciones distintas y solo dibuja una
              de cada cruce. Decir que se emula seria el verde falso que este
              trabajo critica."))
    (protocolo:con-agrupacion-en-vista
     (values :degrada
             "las filas salen todas en una tabla, sin separar por el campo de
              agrupacion. La tabla es correcta -son las mismas filas- y solo
              pierde legibilidad, que es lo que distingue degradar de rechazar."))

    (protocolo:con-derivacion-por-consulta
     (values :degrada "las derivaciones son vivas, que es mas de lo que se pide"))
    (t (values :rechaza
               (format nil "la pagina no tiene ~(~a~)" capacidad)))))
