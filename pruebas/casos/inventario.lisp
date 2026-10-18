;;;; G4. Inventario por almacen con stock minimo y marca de reposicion.
;;;; Ejercita: dos colecciones relacionadas, busqueda por clave, relacion uno
;;;; a muchos, suma con :donde, marca de reposicion, minimo/maximo, etiquetas
;;;; de coleccion largas que solo difieren despues del caracter 31 y una
;;;; etiqueta con apostrofo. Las existencias tienen clave compuesta (almacen
;;;; y codigo); hasta el 2026-10-17 llevaban una columna CLAVE pegada a mano
;;;; con "#", que se escapo a la limpieza de C2 por estar en los datos.
(in-package #:situacion.casos)

(defsituacion caso-inventario (:etiqueta "Inventario de la ferretería")
  (coleccion articulos
    (:etiqueta "Catálogo d'artículos")
    (:clave codigo)
    (campo codigo :rol fijo :etiqueta "Código")
    (campo nombre :rol fijo :etiqueta "Artículo")
    (campo minimo :rol fijo :tipo entero :etiqueta "Stock mínimo")
    (campo total  :rol derivado :tipo entero :etiqueta "Total en almacenes"
           (suma cantidad de existencias :donde (= codigo (de fila codigo))))
    (campo donde  :rol derivado :etiqueta "Dónde hay"
           (las-filas-de existencias :donde (= codigo (de fila codigo))))
    (campo reponer :rol derivado :etiqueta "Reponer"
           (si (< (de fila total) (de fila minimo)) "sí" "no")))

  (coleccion existencias
    (:etiqueta "Existencias registradas en el almacén central")
    (:clave almacen codigo)
    (:crece)
    (campo almacen  :rol fijo :etiqueta "Almacén")
    (campo codigo   :rol entrada :etiqueta "Código"
           :dominio (los codigo de articulos) :al-violar impedir)
    (campo cantidad :rol entrada :tipo entero :etiqueta "Cantidad")
    (campo articulo :rol derivado :etiqueta "Artículo"
           (el nombre de (la-fila-de articulos :donde (= codigo (de fila codigo)))
               :si-no "(desconocido)")))

  (coleccion movimientos
    (:etiqueta "Existencias registradas en el almacén norte")
    (:clave numero)
    (:crece)
    (campo numero   :rol fijo :tipo entero :etiqueta "No.")
    (campo codigo   :rol entrada :etiqueta "Código")
    (campo unidades :rol entrada :tipo entero :etiqueta "Unidades")
    (campo articulo :rol derivado :etiqueta "Artículo"
           (el nombre de (la-fila-de articulos :donde (= codigo (de fila codigo)))
               :si-no "")))

  (coleccion resumen
    (:una-sola-fila)
    (:etiqueta "Resumen")
    (campo a-reponer :rol derivado :tipo entero :etiqueta "Artículos a reponer"
           (cuantas articulos :donde (= reponer "sí")))
    (campo mayor :rol derivado :tipo entero :etiqueta "Mayor existencia"
           (maximo cantidad de existencias))
    (campo menor :rol derivado :tipo entero :etiqueta "Menor existencia"
           (minimo cantidad de existencias)))

  (marca bajo-minimo
    :en articulos
    :cuando (= (de fila reponer) "sí")
    :sobre (total reponer)
    :severidad advertencia
    :explica (texto "Faltan " (- (de fila minimo) (de fila total)) " para el mínimo"))

  (vista cat :de articulos :etiqueta "Catálogo")
  (vista exi :de existencias :entrada t :etiqueta "Existencias" :agrupada-por almacen)
  (vista mov :de movimientos :etiqueta "Almacén norte")
  (vista res :de resumen :etiqueta "Resumen"))

(defparameter datos-de-inventario
  (datos (list "articulos"
               (fila "codigo" "T-01" "nombre" "Tornillo 3/8\"" "minimo" 100)
               (fila "codigo" "C-02" "nombre" "Cable eléctrico (m)" "minimo" 50)
               (fila "codigo" "P-03" "nombre" "Pintura blanca" "minimo" 5))
         (list "existencias"
               (fila "almacen" "Central" "codigo" "T-01" "cantidad" 40)
               (fila "almacen" "Norte" "codigo" "T-01" "cantidad" 30)
               (fila "almacen" "Central" "codigo" "C-02" "cantidad" 80)
               (fila "almacen" "Norte" "codigo" "P-03" "cantidad" 2)
               (fila "almacen" "Central" "codigo" "X-99" "cantidad" 7))
         (list "movimientos"
               (fila "numero" 1 "codigo" "T-01" "unidades" 10)
               (fila "numero" 2 "codigo" "P-03" "unidades" 1))
         (list "resumen" (fila))))

(registrar-caso "caso-inventario" caso-inventario datos-de-inventario)

;;; Variante B: la misma situacion con etiquetas cortas y sin apostrofo.

(defsituacion caso-inventario-b (:etiqueta "Inventario de la ferretería")
  (coleccion articulos
    (:etiqueta "Catálogo de artículos")
    (:clave codigo)
    (campo codigo :rol fijo :etiqueta "Código")
    (campo nombre :rol fijo :etiqueta "Artículo")
    (campo minimo :rol fijo :tipo entero :etiqueta "Stock mínimo")
    (campo total  :rol derivado :tipo entero :etiqueta "Total en almacenes"
           (suma cantidad de existencias :donde (= codigo (de fila codigo))))
    (campo donde  :rol derivado :etiqueta "Dónde hay"
           (las-filas-de existencias :donde (= codigo (de fila codigo))))
    (campo reponer :rol derivado :etiqueta "Reponer"
           (si (< (de fila total) (de fila minimo)) "sí" "no")))

  (coleccion existencias
    (:etiqueta "Existencias central")
    (:clave almacen codigo)
    (:crece)
    (campo almacen  :rol fijo :etiqueta "Almacén")
    (campo codigo   :rol entrada :etiqueta "Código"
           :dominio (los codigo de articulos) :al-violar impedir)
    (campo cantidad :rol entrada :tipo entero :etiqueta "Cantidad")
    (campo articulo :rol derivado :etiqueta "Artículo"
           (el nombre de (la-fila-de articulos :donde (= codigo (de fila codigo)))
               :si-no "(desconocido)")))

  (coleccion movimientos
    (:etiqueta "Existencias norte")
    (:clave numero)
    (:crece)
    (campo numero   :rol fijo :tipo entero :etiqueta "No.")
    (campo codigo   :rol entrada :etiqueta "Código")
    (campo unidades :rol entrada :tipo entero :etiqueta "Unidades")
    (campo articulo :rol derivado :etiqueta "Artículo"
           (el nombre de (la-fila-de articulos :donde (= codigo (de fila codigo)))
               :si-no "")))

  (coleccion resumen
    (:una-sola-fila)
    (:etiqueta "Resumen")
    (campo a-reponer :rol derivado :tipo entero :etiqueta "Artículos a reponer"
           (cuantas articulos :donde (= reponer "sí")))
    (campo mayor :rol derivado :tipo entero :etiqueta "Mayor existencia"
           (maximo cantidad de existencias))
    (campo menor :rol derivado :tipo entero :etiqueta "Menor existencia"
           (minimo cantidad de existencias)))

  (marca bajo-minimo
    :en articulos
    :cuando (= (de fila reponer) "sí")
    :sobre (total reponer)
    :severidad advertencia
    :explica (texto "Faltan " (- (de fila minimo) (de fila total)) " para el mínimo"))

  (vista cat :de articulos :etiqueta "Catálogo")
  (vista exi :de existencias :entrada t :etiqueta "Existencias" :agrupada-por almacen)
  (vista mov :de movimientos :etiqueta "Almacén norte")
  (vista res :de resumen :etiqueta "Resumen"))

(defparameter datos-de-inventario-b
  (datos (list "articulos"
               (fila "codigo" "T-01" "nombre" "Tornillo 3/8\"" "minimo" 100)
               (fila "codigo" "C-02" "nombre" "Cable eléctrico (m)" "minimo" 50)
               (fila "codigo" "P-03" "nombre" "Pintura blanca" "minimo" 5))
         (list "existencias"
               (fila "almacen" "Central" "codigo" "T-01" "cantidad" 40)
               (fila "almacen" "Norte" "codigo" "T-01" "cantidad" 30)
               (fila "almacen" "Central" "codigo" "C-02" "cantidad" 80)
               (fila "almacen" "Norte" "codigo" "P-03" "cantidad" 2)
               (fila "almacen" "Central" "codigo" "X-99" "cantidad" 7))
         (list "movimientos"
               (fila "numero" 1 "codigo" "T-01" "unidades" 10)
               (fila "numero" 2 "codigo" "P-03" "unidades" 1))
         (list "resumen" (fila))))

(registrar-caso "caso-inventario-b" caso-inventario-b datos-de-inventario-b)
