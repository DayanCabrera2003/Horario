;;;; Pruebas de que una carencia no detiene la generacion.
;;;;
;;;; Hasta el 2026-10-17, una sola construccion que una arquitectura no sabia
;;;; traducir se llevaba el documento entero: el texto plano abortaba con un
;;;; conteo de valores distintos, la hoja de calculo con una busqueda por dos
;;;; campos (que desde la fase 2 ya traduce; el ejemplo es ahora un conteo de
;;;; distintos con :DONDE). Ahora el informe dice RECHAZA con el motivo y el artefacto sale,
;;;; con la pieza ausente senalada en su sitio.

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion clientes-por-zona (:etiqueta "Clientes por zona")
  ;; Contar valores distintos CON :DONDE es, desde el 2026-10-17, lo que la
  ;; hoja de calculo sigue sin saber traducir (la busqueda por dos campos,
  ;; que era el ejemplo de antes, ya la traduce: fase 2, hueco C2).
  (coleccion visitas
    (:etiqueta "Visitas")
    (:clave numero)
    (campo numero  :rol fijo :tipo entero :etiqueta "No.")
    (campo zona    :rol fijo :etiqueta "Zona")
    (campo cliente :rol fijo :etiqueta "Cliente"))
  (coleccion zonas
    (:etiqueta "Zonas")
    (:clave nombre)
    (campo nombre :rol fijo :etiqueta "Zona")
    (campo clientes :rol derivado :tipo entero :etiqueta "Clientes"
           (cuantas-distintas cliente de visitas :donde (= zona (de fila nombre)))))
  (vista z :de zonas :etiqueta "Zonas"))

(defparameter *datos-clientes-por-zona*
  (list (cons (nucleo:nombrar "visitas")
              (list (list (cons (nucleo:nombrar "numero") 1)
                          (cons (nucleo:nombrar "zona") "Norte")
                          (cons (nucleo:nombrar "cliente") "Ana"))))
        (cons (nucleo:nombrar "zonas")
              (list (list (cons (nucleo:nombrar "nombre") "Norte"))))))

(definir-prueba carencia-la-hoja-de-calculo-sale-con-la-pieza-ausente
    "Carencias: un conteo de distintos con :donde no detiene la hoja de calculo"
  (multiple-value-bind (plano informe)
      (handler-case (materializar-en-cadena (situacion.excel:hacer-excel)
                                            (situacion.lenguaje:situacion-llamada
                                             "CLIENTES-POR-ZONA")
                                            *datos-clientes-por-zona*)
        (error (e) (values nil (format nil "~a" e))))
    (comprobar plano "la hoja de calculo no se genero: ~a" informe)
    (when plano
      (comprobar (search protocolo:+pieza-ausente+ plano)
                 "la celda de CLIENTES tiene que decir que no esta disponible")
      (comprobar (find :rechaza (protocolo:entradas-del-informe informe)
                       :key #'protocolo:entrada-de-informe-respuesta)
                 "el informe tiene que decir RECHAZA"))))

(definir-prueba carencia-el-texto-cuenta-distintos
    "Carencias: el texto plano cuenta valores distintos, que calcula el evaluador"
  (let ((texto (handler-case (materializar-en-cadena (situacion.texto:hacer-texto)
                                                     (situacion.lenguaje:situacion-llamada
                                                      "CASO-HORAS")
                                                     (datos-del-caso "DATOS-DE-HORAS"))
                 (error (e) (format nil "FALLO ~a" e)))))
    (comprobar (not (search "FALLO" texto)) "el texto no se genero: ~a" texto)
    (comprobar (search "Personas distintas" texto)
               "el texto tiene que escribir el conteo de personas distintas")))

;;; ---------------------------------------------------------------------
;;; La politica estricta solo para ante una carencia de verdad
;;;
;;; Hasta el 2026-10-18 REQUERIR senalaba error con :ESTRICTA en cuanto la
;;; arquitectura no heredaba la capacidad, aunque su RESOLVER-CARENCIA
;;; respondiera :CUMPLE. El texto plano lo sufria con la relacion uno a
;;; muchos, que cumple escribiendo las filas separadas por comas.
;;; ---------------------------------------------------------------------

(defclass arquitectura-que-cumple-sin-heredar (protocolo:arquitectura) ()
  (:documentation
   "Arquitectura minima de prueba: no hereda ninguna capacidad, pero dice
    que cumple la tabla cruzada. Solo existe para estas pruebas."))

(defmethod protocolo:resolver-carencia
    ((a arquitectura-que-cumple-sin-heredar) capacidad nodo)
  (declare (ignore nodo))
  (if (eq capacidad 'protocolo:con-tabla-cruzada)
      (values :cumple "la dibuja a su manera")
      (values :degrada "lo hace peor")))

(definir-prueba carencia-estricta-acepta-lo-que-se-cumple
    "Carencias: con politica estricta, un :cumple de resolver-carencia no es error"
  (let ((a (make-instance 'arquitectura-que-cumple-sin-heredar))
        (protocolo:*politica* :estricta))
    (let ((respuesta (handler-case
                         (protocolo:con-informe (a)
                           (protocolo:requerir a 'protocolo:con-tabla-cruzada nil))
                       (protocolo:capacidad-no-disponible () :error))))
      (comprobar (not (eq respuesta :error))
                 "un :cumple no puede ser error con la politica estricta"))
    ;; Y una carencia de verdad sigue parando: es para lo que existe.
    (comprobar (eq :error
                   (handler-case
                       (protocolo:con-informe (a)
                         (protocolo:requerir a 'protocolo:con-entrada nil))
                     (protocolo:capacidad-no-disponible () :error)))
               "un :degrada tiene que seguir siendo error con la politica estricta")))

(definir-prueba carencia-el-texto-hereda-lo-que-cumple
    "Carencias: el texto plano hereda la relacion uno a muchos que dice cumplir"
  (let ((texto (situacion.texto:hacer-texto)))
    (comprobar (member 'protocolo:con-relacion-uno-a-muchos
                       (protocolo:capacidades texto))
               "las capacidades del texto tienen que listar la relacion uno a muchos")
    (comprobar (not (eq :error
                        (let ((protocolo:*politica* :estricta))
                          (handler-case
                              (protocolo:con-informe (texto)
                                (protocolo:requerir texto
                                                    'protocolo:con-relacion-uno-a-muchos
                                                    nil))
                            (protocolo:capacidad-no-disponible () :error)))))
               "el texto no puede rechazar en modo estricto la relacion que cumple")))
