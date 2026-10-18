;;;; Pruebas de que una carencia no detiene la generacion.
;;;;
;;;; Hasta el 2026-10-17, una sola construccion que una arquitectura no sabia
;;;; traducir se llevaba el documento entero: el texto plano abortaba con un
;;;; conteo de valores distintos, la hoja de calculo con una busqueda por dos
;;;; campos. Ahora el informe dice RECHAZA con el motivo y el artefacto sale,
;;;; con la pieza ausente senalada en su sitio.

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion pedidos-por-almacen (:etiqueta "Pedidos por almacen")
  (coleccion existencias
    (:etiqueta "Existencias")
    (:clave almacen codigo)
    (campo almacen  :rol fijo :etiqueta "Almacen")
    (campo codigo   :rol fijo :etiqueta "Codigo")
    (campo cantidad :rol fijo :tipo entero :etiqueta "Cantidad"))
  (coleccion pedidos
    (:etiqueta "Pedidos")
    (:clave numero)
    (campo numero  :rol fijo :tipo entero :etiqueta "No.")
    (campo almacen :rol fijo :etiqueta "Almacen")
    (campo codigo  :rol fijo :etiqueta "Codigo")
    (campo hay     :rol derivado :tipo entero :etiqueta "Hay"
           (el cantidad de (la-fila-de existencias
                             :donde (y (= almacen (de fila almacen))
                                       (= codigo (de fila codigo))))
               :si-no 0)))
  (vista p :de pedidos :etiqueta "Pedidos"))

(defparameter *datos-pedidos-por-almacen*
  (list (cons (nucleo:nombrar "existencias")
              (list (list (cons (nucleo:nombrar "almacen") "Norte")
                          (cons (nucleo:nombrar "codigo") "T-01")
                          (cons (nucleo:nombrar "cantidad") 30))))
        (cons (nucleo:nombrar "pedidos")
              (list (list (cons (nucleo:nombrar "numero") 1)
                          (cons (nucleo:nombrar "almacen") "Norte")
                          (cons (nucleo:nombrar "codigo") "T-01"))))))

(definir-prueba carencia-la-hoja-de-calculo-sale-con-la-pieza-ausente
    "Carencias: una busqueda por dos campos no detiene la hoja de calculo"
  (multiple-value-bind (plano informe)
      (handler-case (materializar-en-cadena (situacion.excel:hacer-excel)
                                            (situacion.lenguaje:situacion-llamada
                                             "PEDIDOS-POR-ALMACEN")
                                            *datos-pedidos-por-almacen*)
        (error (e) (values nil (format nil "~a" e))))
    (comprobar plano "la hoja de calculo no se genero: ~a" informe)
    (when plano
      (comprobar (search protocolo:+pieza-ausente+ plano)
                 "la celda de HAY tiene que decir que no esta disponible")
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
