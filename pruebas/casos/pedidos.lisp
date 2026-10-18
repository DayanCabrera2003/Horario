;;;; G4c. Pedidos contra existencias por almacen y codigo.
;;;; Ejercita: la-fila-de con dos condiciones (fase 2, hueco C2), en una
;;;; coleccion que crece (filas de reserva en la hoja). Los datos tienen
;;;; dos lotes que cumplen la misma busqueda -tiene que salir el primero en
;;;; el orden de la coleccion-, un almacen escrito con otra mayuscula -no
;;;; coincide-, un pedido sin almacen contra un lote sin almacen -vacio con
;;;; vacio si coincide-, una busqueda con (vacio? ...) y un pedido sin
;;;; ninguna existencia, que cae en el :si-no.
(in-package #:situacion.casos)

(defsituacion caso-pedidos (:etiqueta "Pedidos y existencias")
  (coleccion existencias
    (:etiqueta "Existencias")
    (:clave lote)
    (:crece)
    (campo lote     :rol fijo :etiqueta "Lote")
    (campo almacen  :rol fijo :etiqueta "Almacén")
    (campo codigo   :rol fijo :etiqueta "Código")
    (campo unidades :rol fijo :tipo entero :etiqueta "Unidades"))

  (coleccion pedidos
    (:etiqueta "Pedidos")
    (:clave numero)
    (campo numero   :rol fijo :tipo entero :etiqueta "No.")
    (campo almacen  :rol fijo :etiqueta "Almacén")
    (campo codigo   :rol fijo :etiqueta "Código")
    (campo cantidad :rol entrada :tipo entero :etiqueta "Cantidad")
    ;; El lote que sirve el pedido: el primero de ese almacen y ese codigo.
    (campo lote :rol derivado :etiqueta "Lote"
           (el lote de (la-fila-de existencias
                         :donde (y (= almacen (de fila almacen))
                                   (= codigo (de fila codigo))))
               :si-no "sin existencias"))
    (campo hay :rol derivado :tipo entero :etiqueta "Hay"
           (el unidades de (la-fila-de existencias
                             :donde (y (= almacen (de fila almacen))
                                       (= codigo (de fila codigo))))
               :si-no 0))
    ;; Lo que queda sin almacen asignado para ese codigo.
    (campo suelto :rol derivado :etiqueta "Lote sin almacén"
           (el lote de (la-fila-de existencias
                         :donde (y (vacio? almacen)
                                   (= codigo (de fila codigo))))
               :si-no "")))

  (marca no-alcanza
    :en pedidos
    :cuando (> (de fila cantidad) (de fila hay))
    :sobre (cantidad)
    :severidad problema
    :explica (texto "Faltan " (- (de fila cantidad) (de fila hay))))

  (vista lista :de pedidos :entrada t :etiqueta "Pedidos")
  (vista stock :de existencias :etiqueta "Existencias"))

(defparameter datos-de-pedidos
  (datos (list "existencias"
               (fila "lote" "L1" "almacen" "Norte" "codigo" "A-1" "unidades" 5)
               (fila "lote" "L2" "almacen" "Norte" "codigo" "A-1" "unidades" 9)
               (fila "lote" "L3" "almacen" "Sur"   "codigo" "A-1" "unidades" 2)
               (fila "lote" "L4" "almacen" ""      "codigo" "B-2" "unidades" 7))
         (list "pedidos"
               (fila "numero" 1 "almacen" "Norte" "codigo" "A-1" "cantidad" 6)
               (fila "numero" 2 "almacen" "norte" "codigo" "A-1" "cantidad" 1)
               (fila "numero" 3 "almacen" ""      "codigo" "B-2" "cantidad" 3)
               (fila "numero" 4 "almacen" "Sur"   "codigo" "B-2" "cantidad" 1)
               (fila "numero" 5 "almacen" "Sur"   "codigo" "A-1" "cantidad" 2))))

(registrar-caso "caso-pedidos" caso-pedidos datos-de-pedidos)
