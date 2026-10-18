;;;; G1. Lista de la compra con totales por categoria. Desde la fase 2
;;;; (hueco C6) el dinero se ve con dos decimales, y unas galletas de 2.675
;;;; CUP ponen a prueba el empate: tienen que verse 2.68 en las tres.
;;;; Ejercita: decimales, multiplicacion, suma con :donde, dominio (uno-de),
;;;; parametro, marcas, tildes, "|" "*" "?" en valores, etiquetas de
;;;; coleccion sin espacios pero con guion y con tilde.
(in-package #:situacion.casos)

(defsituacion caso-compras (:etiqueta "Lista de la compra")
  (parametro presupuesto :tipo numero :valor 50 :etiqueta "Presupuesto (CUP)")

  (coleccion categorias
    ;; Etiqueta con tilde y sin espacios: la hoja se referencia sin comillas.
    (:etiqueta "Categorías")
    (:clave nombre)
    (campo nombre :rol fijo :etiqueta "Categoría")
    (campo total :rol derivado :tipo numero :decimales 2 :etiqueta "Total"
           (suma subtotal de productos :donde (= categoria (de fila nombre))))
    (campo articulos :rol derivado :tipo entero :etiqueta "Artículos"
           (cuantas productos :donde (= categoria (de fila nombre)))))

  (coleccion productos
    ;; Etiqueta con guion y sin espacios.
    (:etiqueta "Compra-2026")
    (:clave producto)
    (:crece)
    (campo producto  :rol fijo :etiqueta "Producto")
    (campo categoria :rol entrada :etiqueta "Categoría"
           :dominio (los nombre de categorias) :al-violar impedir)
    (campo cantidad  :rol entrada :tipo entero :etiqueta "Cantidad")
    (campo precio    :rol fijo :tipo numero :decimales 2 :etiqueta "Precio")
    (campo comprado  :rol entrada :etiqueta "¿Comprado?"
           :dominio (uno-de "sí" "no"))
    (campo subtotal  :rol derivado :tipo numero :decimales 2 :etiqueta "Subtotal"
           (* (de fila cantidad) (de fila precio))))

  (coleccion resumen
    (:una-sola-fila)
    (:etiqueta "Resumen")
    (campo gastado :rol derivado :tipo numero :decimales 2 :etiqueta "Gastado"
           (suma subtotal de productos))
    (campo pendientes :rol derivado :tipo entero :etiqueta "Sin comprar"
           (cuantas productos :donde (= comprado "no")))
    (campo margen :rol derivado :tipo numero :decimales 2 :etiqueta "Margen"
           (- (parametro presupuesto) (de fila gastado))))

  (marca caro
    :en productos
    :cuando (> (de fila subtotal) 10)
    :sobre (subtotal)
    :severidad advertencia
    :explica (texto "Subtotal alto: " (de fila subtotal)))

  (marca sin-categoria
    :en productos
    :cuando (vacio? (de fila categoria))
    :sobre (categoria)
    :severidad problema
    :explica "Falta la categoría")

  (marca pasado
    :en resumen
    :cuando (< (de fila margen) 0)
    :sobre (margen)
    :severidad problema
    :explica "Se pasa del presupuesto")

  (vista lista :de productos :entrada t :etiqueta "Lista")
  (vista porcat :de categorias :etiqueta "Por categoría")
  (vista res :de resumen :etiqueta "Resumen"))

(defparameter datos-de-compras
  (datos (list "categorias"
               (fila "nombre" "Lácteos") (fila "nombre" "Panadería")
               (fila "nombre" "Limpieza|Hogar") (fila "nombre" "Frutas*"))
         (list "productos"
               (fila "producto" "Leche en polvo" "categoria" "Lácteos" "cantidad" 2 "precio" 4.75 "comprado" "sí")
               (fila "producto" "Yogur ¿natural?" "categoria" "Lácteos" "cantidad" 3 "precio" 1.2 "comprado" "no")
               (fila "producto" "Pan de molde" "categoria" "Panadería" "cantidad" 1 "precio" 2.5 "comprado" "no")
               (fila "producto" "Galletas" "categoria" "Panadería" "cantidad" 1 "precio" 2.675 "comprado" "no")
               (fila "producto" "Detergente" "categoria" "Limpieza|Hogar" "cantidad" 1 "precio" 12.99 "comprado" "no")
               (fila "producto" "Mangos" "categoria" "Frutas*" "cantidad" 6 "precio" 0.5 "comprado" "sí")
               (fila "producto" "Guayabas" "categoria" "" "cantidad" 4 "precio" 0.35 "comprado" "no"))
         (list "resumen" (fila))))

(registrar-caso "caso-compras" caso-compras datos-de-compras)

;;; Variante B: las etiquetas llevan espacios, y los valores ponen a prueba
;;; la comparacion exacta: "Frutas" y "Frutas*", "Lácteos" y "lácteos", y
;;; una categoria con coma, "Aseo, Hogar".

(defsituacion caso-compras-b (:etiqueta "Lista de la compra")
  (parametro presupuesto :tipo numero :valor 50 :etiqueta "Presupuesto (CUP)")

  (coleccion categorias
    ;; Etiqueta con tilde y sin espacios: la hoja se referencia sin comillas.
    (:etiqueta "Categorías")
    (:clave nombre)
    (campo nombre :rol fijo :etiqueta "Categoría")
    (campo total :rol derivado :tipo numero :etiqueta "Total"
           (suma subtotal de productos :donde (= categoria (de fila nombre))))
    (campo articulos :rol derivado :tipo entero :etiqueta "Artículos"
           (cuantas productos :donde (= categoria (de fila nombre)))))

  (coleccion productos
    ;; Etiqueta con guion y sin espacios.
    (:etiqueta "Compra de 2026")
    (:clave producto)
    (:crece)
    (campo producto  :rol fijo :etiqueta "Producto")
    (campo categoria :rol entrada :etiqueta "Categoría"
           :dominio (los nombre de categorias) :al-violar impedir)
    (campo cantidad  :rol entrada :tipo entero :etiqueta "Cantidad")
    (campo precio    :rol fijo :tipo numero :etiqueta "Precio")
    (campo comprado  :rol entrada :etiqueta "¿Comprado?"
           :dominio (uno-de "sí" "no"))
    (campo subtotal  :rol derivado :tipo numero :etiqueta "Subtotal"
           (* (de fila cantidad) (de fila precio))))

  (coleccion resumen
    (:una-sola-fila)
    (:etiqueta "Resumen")
    (campo gastado :rol derivado :tipo numero :etiqueta "Gastado"
           (suma subtotal de productos))
    (campo pendientes :rol derivado :tipo entero :etiqueta "Sin comprar"
           (cuantas productos :donde (= comprado "no")))
    (campo margen :rol derivado :tipo numero :etiqueta "Margen"
           (- (parametro presupuesto) (de fila gastado))))

  (marca caro
    :en productos
    :cuando (> (de fila subtotal) 10)
    :sobre (subtotal)
    :severidad advertencia
    :explica (texto "Subtotal alto: " (de fila subtotal)))

  (marca sin-categoria
    :en productos
    :cuando (vacio? (de fila categoria))
    :sobre (categoria)
    :severidad problema
    :explica "Falta la categoría")

  (marca pasado
    :en resumen
    :cuando (< (de fila margen) 0)
    :sobre (margen)
    :severidad problema
    :explica "Se pasa del presupuesto")

  (vista lista :de productos :entrada t :etiqueta "Lista")
  (vista porcat :de categorias :etiqueta "Por categoría")
  (vista res :de resumen :etiqueta "Resumen"))

(defparameter datos-de-compras-b
  (datos (list "categorias"
               (fila "nombre" "Lácteos") (fila "nombre" "Panadería")
               (fila "nombre" "Limpieza|Hogar") (fila "nombre" "Frutas*") (fila "nombre" "Frutas") (fila "nombre" "lácteos") (fila "nombre" "Aseo, Hogar"))
         (list "productos"
               (fila "producto" "Leche en polvo" "categoria" "Lácteos" "cantidad" 2 "precio" 4.75 "comprado" "sí")
               (fila "producto" "Yogur ¿natural?" "categoria" "Lácteos" "cantidad" 3 "precio" 1.2 "comprado" "no")
               (fila "producto" "Pan de molde" "categoria" "Panadería" "cantidad" 1 "precio" 2.5 "comprado" "no")
               (fila "producto" "Detergente" "categoria" "Limpieza|Hogar" "cantidad" 1 "precio" 12.99 "comprado" "no")
               (fila "producto" "Mangos" "categoria" "Frutas*" "cantidad" 6 "precio" 0.5 "comprado" "sí")
               (fila "producto" "Piña" "categoria" "Frutas" "cantidad" 1 "precio" 3 "comprado" "no")
               (fila "producto" "Queso" "categoria" "lácteos" "cantidad" 1 "precio" 7 "comprado" "no")
               (fila "producto" "Jabón" "categoria" "Aseo, Hogar" "cantidad" 2 "precio" 1 "comprado" "no")
               (fila "producto" "Guayabas" "categoria" "" "cantidad" 4 "precio" 0.35 "comprado" "no"))
         (list "resumen" (fila))))

(registrar-caso "caso-compras-b" caso-compras-b datos-de-compras-b)
