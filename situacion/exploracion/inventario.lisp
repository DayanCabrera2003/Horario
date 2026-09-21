;;;; Control de existencias de un almacen pequeno.
;;;;
;;;; Exploracion: se describe un dominio ajeno al corpus con el lenguaje tal
;;;; como esta, sin tocar ni una linea del sistema, para medir donde llega.
;;;;
;;;; Version A: la descripcion natural, escrita como se dice el problema.
;;;; Version B: la misma cosa deformada hasta que la hoja de calculo la
;;;;            admite, para saber cual es exactamente el precio.

(defpackage #:situacion.exploracion.inventario
  (:use #:common-lisp #:situacion.lenguaje))

(in-package #:situacion.exploracion.inventario)

;;; ---------------------------------------------------------------------
;;; VERSION A. La descripcion natural.
;;; ---------------------------------------------------------------------

(defsituacion inventario (:etiqueta "Control de existencias del almacen")

  ;; DEFORMACION 1. Los dos valores que puede tomar el tipo de movimiento son
  ;; una enumeracion literal del dominio: entrada o salida, y no hay mas. El
  ;; lenguaje solo sabe construir un dominio de entrada con (LOS campo DE
  ;; coleccion), asi que para poder decir "entrada o salida" hay que fabricar
  ;; una tabla de dos filas y una columna, que en el almacen no existe.
  (coleccion clases-de-movimiento
    (:etiqueta "Clases de movimiento")
    (:clave clase)
    (campo clase :rol fijo :etiqueta "Clase")
    (:datos (("entrada") ("salida"))))

  (coleccion articulos
    (:etiqueta "Articulos")
    (:clave codigo)
    (:crece)
    (campo codigo :rol fijo :etiqueta "Codigo")
    (campo nombre :rol fijo :etiqueta "Articulo")
    (campo unidad :rol fijo :etiqueta "Unidad")
    (campo minimo :rol fijo :tipo entero :etiqueta "Stock minimo")

    ;; "Las existencias son las entradas menos las salidas". Se dice con dos
    ;; agregados, cada uno con un filtro de dos condiciones: el articulo y la
    ;; clase de movimiento.
    (campo entradas :rol derivado :tipo entero :etiqueta "Entradas"
           (suma cantidad de movimientos
                 :donde (y (= articulo (de fila codigo))
                           (= tipo "entrada"))))
    (campo salidas :rol derivado :tipo entero :etiqueta "Salidas"
           (suma cantidad de movimientos
                 :donde (y (= articulo (de fila codigo))
                           (= tipo "salida"))))
    (campo existencias :rol derivado :tipo entero :etiqueta "Existencias"
           (- (de fila entradas) (de fila salidas)))

    (:datos (("T-01" "Tornillo 3mm" "caja"  10)
             ("C-02" "Cable UTP"    "metro" 50)
             ("P-03" "Papel A4"     "resma"  5)
             ("G-04" "Guantes"      "par"   10))))

  ;; El libro de movimientos. Todas sus columnas las escribe el operario, asi
  ;; que no hay ninguna de rol FIJO y (:datos ...) no puede llevar el
  ;; historico: solo transporta valores de campos fijos.
  (coleccion movimientos
    (:etiqueta "Movimientos")
    (:clave fecha articulo tipo)
    (:orden fecha)
    (:crece)
    (campo fecha :rol entrada :tipo fecha :etiqueta "Fecha")
    (campo articulo :rol entrada :etiqueta "Articulo"
           :dominio (los codigo de articulos)
           :al-violar advertir)
    (campo tipo :rol entrada :etiqueta "Tipo"
           :dominio (los clase de clases-de-movimiento)
           :al-violar advertir)
    (campo cantidad :rol entrada :tipo entero :etiqueta "Cantidad")
    (campo proveedor :rol entrada :etiqueta "Proveedor"
           :dominio (los proveedor de proveedores)
           :al-violar advertir)

    ;; Autocompletado por busqueda de clave, igual que el tribunal del corpus.
    (campo denominacion :rol derivado :etiqueta "Descripcion"
           (el nombre de (la-fila-de articulos
                           :donde (= codigo (de fila articulo)))
               :si-no ""))

    ;; Sonda: saldo corriente. Es el kardex del almacen, y aqui sale MAL a
    ;; proposito: VECINO recorre la coleccion entera ordenada por fecha, sin
    ;; partir por articulo, asi que esto acumula todos los articulos juntos.
    (campo firmado :rol derivado :tipo entero :etiqueta "Signo"
           (si (= (de fila tipo) "salida")
               (- 0 (de fila cantidad))
               (de fila cantidad)))
    (campo acumulado :rol derivado :tipo entero :etiqueta "Acumulado (todos)"
           (+ (de (anterior fila) acumulado) (de fila firmado))))

  ;; DEFORMACION 2. "Cuantos articulos distintos movio cada proveedor" es un
  ;; agrupamiento: una fila por proveedor que aparezca en los movimientos. El
  ;; lenguaje no sabe derivar una coleccion de otra, asi que hay que declarar
  ;; la tabla de proveedores a mano y mantenerla sincronizada con lo que el
  ;; operario escriba.
  (coleccion proveedores
    (:etiqueta "Proveedores")
    (:clave proveedor)
    (:crece)
    (campo proveedor :rol fijo :etiqueta "Proveedor")
    (campo articulos-movidos :rol derivado :tipo entero
           :etiqueta "Articulos distintos"
           (cuantas-distintas articulo de movimientos
                              :donde (= proveedor (de fila proveedor))))
    (:datos (("Ferreteria Sur") ("Cables SA") ("Papelera Centro"))))

  (marca bajo-minimo
    :en        articulos
    :cuando    (< (de fila existencias) (de fila minimo))
    :sobre     (nombre existencias minimo)
    :severidad advertencia
    :explica   (texto (plural (- (de fila minimo) (de fila existencias))
                              "Falta" "Faltan")
                      " " (- (de fila minimo) (de fila existencias))
                      " para llegar al minimo"))

  (marca agotado
    :en        articulos
    :cuando    (= (de fila existencias) 0)
    :sobre     (nombre existencias)
    :severidad problema
    :explica   "No queda ninguna existencia")

  (marca articulo-desconocido
    :en        movimientos
    :cuando    (vacio? (el codigo de (la-fila-de articulos
                                       :donde (= codigo (de fila articulo)))
                           :si-no ""))
    :sobre     (articulo denominacion)
    :severidad advertencia
    :explica   "Ese codigo no esta en el listado de articulos")

  (vista almacen :de articulos :entrada t :etiqueta "Existencias por articulo")
  (vista libro :de movimientos :etiqueta "Movimientos del almacen")
  (vista por-proveedor :de proveedores :etiqueta "Movimiento por proveedor"))

;;; ---------------------------------------------------------------------
;;; Los datos de prueba
;;; ---------------------------------------------------------------------

(defun n (s) (intern (string-upcase s) '#:situacion.nucleo))

(defun filas (campos tuplas)
  (loop for tupla in tuplas
        collect (loop for campo in campos
                      for valor in tupla
                      collect (cons (n campo) valor))))

(defparameter datos-del-almacen
  (list
   (cons (n "clases-de-movimiento")
         (filas '("clase") '(("entrada") ("salida"))))
   (cons (n "articulos")
         (filas '("codigo" "nombre" "unidad" "minimo")
                '(("T-01" "Tornillo 3mm" "caja"  10)
                  ("C-02" "Cable UTP"    "metro" 50)
                  ("P-03" "Papel A4"     "resma"  5)
                  ("G-04" "Guantes"      "par"   10))))
   (cons (n "movimientos")
         (filas '("fecha" "articulo" "tipo" "cantidad" "proveedor")
                '(("2026-03-01" "T-01" "entrada" 20 "Ferreteria Sur")
                  ("2026-03-02" "C-02" "entrada" 100 "Cables SA")
                  ("2026-03-03" "T-01" "salida"  15 "")
                  ("2026-03-04" "P-03" "entrada" 10 "Papelera Centro")
                  ("2026-03-05" "P-03" "salida"  10 "")
                  ("2026-03-06" "C-02" "salida"  60 "")
                  ("2026-03-07" "G-04" "entrada" 12 "Ferreteria Sur")
                  ("2026-03-08" "T-01" "entrada"  4 "Ferreteria Sur")
                  ("2026-03-09" "X-99" "salida"   1 ""))))
   (cons (n "proveedores")
         (filas '("proveedor")
                '(("Ferreteria Sur") ("Cables SA") ("Papelera Centro")))))
  "Nueve movimientos. El ultimo apunta a un codigo que no existe, a
   proposito, para ver disparar la marca de articulo desconocido.")

;;; ---------------------------------------------------------------------
;;; VERSION B. La misma situacion deformada para que quepa en la rejilla.
;;;
;;; Dos cambios, y solo dos:
;;;   - el filtro compuesto de los agregados se parte en una columna
;;;     derivada por clase de movimiento, para que quede un solo criterio
;;;     de igualdad;
;;;   - el conteo de articulos distintos por proveedor se deja igual, para
;;;     ver que responde la hoja de calculo cuando no puede filtrar.
;;; ---------------------------------------------------------------------

(defsituacion inventario-adaptado
    (:etiqueta "Control de existencias del almacen (adaptado a la rejilla)")

  (coleccion clases-de-movimiento
    (:etiqueta "Clases de movimiento")
    (:clave clase)
    (campo clase :rol fijo :etiqueta "Clase")
    (:datos (("entrada") ("salida"))))

  (coleccion articulos
    (:etiqueta "Articulos")
    (:clave codigo)
    (:crece)
    (campo codigo :rol fijo :etiqueta "Codigo")
    (campo nombre :rol fijo :etiqueta "Articulo")
    (campo unidad :rol fijo :etiqueta "Unidad")
    (campo minimo :rol fijo :tipo entero :etiqueta "Stock minimo")
    ;; Un solo agregado con un solo criterio de igualdad: el que la hoja de
    ;; calculo sabe traducir a SUMAR.SI.
    (campo existencias :rol derivado :tipo entero :etiqueta "Existencias"
           (suma firmada de movimientos :donde (= articulo (de fila codigo))))
    (:datos (("T-01" "Tornillo 3mm" "caja"  10)
             ("C-02" "Cable UTP"    "metro" 50)
             ("P-03" "Papel A4"     "resma"  5)
             ("G-04" "Guantes"      "par"   10))))

  (coleccion movimientos
    (:etiqueta "Movimientos")
    (:clave fecha articulo tipo)
    (:orden fecha)
    (:crece)
    (campo fecha :rol entrada :tipo fecha :etiqueta "Fecha")
    (campo articulo :rol entrada :etiqueta "Articulo"
           :dominio (los codigo de articulos)
           :al-violar advertir)
    (campo tipo :rol entrada :etiqueta "Tipo"
           :dominio (los clase de clases-de-movimiento)
           :al-violar advertir)
    (campo cantidad :rol entrada :tipo entero :etiqueta "Cantidad")
    (campo proveedor :rol entrada :etiqueta "Proveedor"
           :dominio (los proveedor de proveedores)
           :al-violar advertir)
    ;; La columna que existe solo para que el agregado tenga un unico
    ;; criterio. En el almacen nadie anota "cantidad con signo".
    (campo firmada :rol derivado :tipo entero :etiqueta "Cantidad con signo"
           (si (= (de fila tipo) "salida")
               (- 0 (de fila cantidad))
               (de fila cantidad)))
    (campo denominacion :rol derivado :etiqueta "Descripcion"
           (el nombre de (la-fila-de articulos
                           :donde (= codigo (de fila articulo)))
               :si-no "")))

  (coleccion proveedores
    (:etiqueta "Proveedores")
    (:clave proveedor)
    (:crece)
    (campo proveedor :rol fijo :etiqueta "Proveedor")
    (campo articulos-movidos :rol derivado :tipo entero
           :etiqueta "Articulos distintos"
           (cuantas-distintas articulo de movimientos
                              :donde (= proveedor (de fila proveedor))))
    (:datos (("Ferreteria Sur") ("Cables SA") ("Papelera Centro"))))

  (marca bajo-minimo
    :en        articulos
    :cuando    (< (de fila existencias) (de fila minimo))
    :sobre     (nombre existencias minimo)
    :severidad advertencia
    :explica   (texto (plural (- (de fila minimo) (de fila existencias))
                              "Falta" "Faltan")
                      " " (- (de fila minimo) (de fila existencias))
                      " para llegar al minimo"))

  (marca agotado
    :en        articulos
    :cuando    (= (de fila existencias) 0)
    :sobre     (nombre existencias)
    :severidad problema
    :explica   "No queda ninguna existencia")

  (vista almacen :de articulos :entrada t :etiqueta "Existencias por articulo")
  (vista libro :de movimientos :etiqueta "Movimientos del almacen")
  (vista por-proveedor :de proveedores :etiqueta "Movimiento por proveedor"))

;;; ---------------------------------------------------------------------
;;; Ejecucion
;;; ---------------------------------------------------------------------

(defparameter +salida+ #p"exploracion/salida/")

(defun titulo (texto)
  (format t "~&~%~a~%~a~%~a~%"
          (make-string 70 :initial-element #\=) texto
          (make-string 70 :initial-element #\=)))

(defun analizar (s)
  (let ((problemas (situacion.analisis:comprobar-situacion s)))
    (if problemas
        (format t "~&Analisis: ~d problema(s)~%~a~%" (length problemas)
                (situacion.analisis:informe-de-problemas problemas))
        (format t "~&Analisis: sin problemas.~%"))))

(defun evaluar-e-imprimir (s datos)
  (let ((entorno (nucleo:hacer-entorno s datos)))
    (dolist (coleccion (nucleo:colecciones s))
      (format t "~&~%  -- ~(~a~) --~%" (nucleo:nombre coleccion))
      (dolist (fila (nucleo:filas-de entorno (nucleo:nombre coleccion)))
        (format t "   ")
        (dolist (campo (nucleo:campos coleccion))
          (format t "~(~a~)=~a  " (nucleo:nombre campo)
                  (nucleo:valor-de-campo entorno fila (nucleo:nombre campo))))
        (let ((marcas (nucleo:marcas-que-disparan entorno fila)))
          (when marcas
            (format t "~%       MARCAS:")
            (dolist (m marcas)
              (format t " [~(~a~)/~(~a~)~@[: ~a~]]"
                      (nucleo:nombre m) (nucleo:severidad m)
                      (nucleo:explicacion-de-marca entorno fila m)))))
        (format t "~%")))))

(defun intentar (nombre arquitectura s datos destino)
  (handler-case
      (multiple-value-bind (d informe)
          (protocolo:materializar arquitectura s datos destino)
        (format t "~&~%[~a] materializa en ~a~%" nombre d)
        (protocolo:escribir-informe informe))
    (error (e)
      (format t "~&~%[~a] FALLA: ~a~%" nombre e))))

(defun correr (s datos prefijo)
  (ensure-directories-exist +salida+)
  (titulo (nucleo:etiqueta s))
  (analizar s)
  (format t "~&~%--- Valores segun el evaluador de referencia ---~%")
  (handler-case (evaluar-e-imprimir s datos)
    (error (e) (format t "~&El evaluador falla: ~a~%" e)))
  (format t "~&~%--- Las tres arquitecturas ---~%")
  (intentar "texto" (situacion.texto:hacer-texto) s datos
            (merge-pathnames (format nil "~a.txt" prefijo) +salida+))
  (intentar "excel" (situacion.excel:hacer-excel) s datos
            (merge-pathnames (format nil "~a-plano.json" prefijo) +salida+))
  (intentar "web" (situacion.web:hacer-web) s datos
            (merge-pathnames (format nil "~a.html" prefijo) +salida+)))

(correr inventario datos-del-almacen "inventario")
(correr inventario-adaptado datos-del-almacen "inventario-adaptado")

(format t "~&~%FIN~%")

;;; ---------------------------------------------------------------------
;;; SONDAS. Cada una intenta decir una cosa que el almacen pide y el corpus
;;; no pedia. Se ejecutan con EVAL para que el fallo de expansion se pueda
;;; observar en vez de abortar la carga.
;;; ---------------------------------------------------------------------

(defun probar (titulo pensamiento)
  (format t "~&~%. ~a~%" titulo)
  (handler-case (format t "   PASA -> ~a~%" (funcall pensamiento))
    (error (e) (format t "   NO PASA -> ~a~%" e))))

(titulo "Sondas")

(probar "1. Dominio como enumeracion literal: :dominio (\"entrada\" \"salida\")"
  (lambda ()
    (eval '(defsituacion sonda-1 (:etiqueta "s1")
            (coleccion c (:clave x)
              (campo x :rol entrada :dominio ("entrada" "salida")))
            (vista v :de c)))))

(probar "2. Concordancia con el sustantivo tomado de los datos: (plural n (de fila unidad) ...)"
  (lambda ()
    (eval '(defsituacion sonda-2 (:etiqueta "s2")
            (coleccion c (:clave x)
              (campo x :rol fijo)
              (campo unidad :rol fijo)
              (campo cuantos :rol fijo :tipo entero)
              (campo frase :rol derivado
                     (texto (de fila cuantos) " "
                            (plural (de fila cuantos)
                                    (de fila unidad) (de fila unidad)))))
            (vista v :de c)))))

(probar "3. La fila anterior DEL MISMO ARTICULO: (de (anterior fila :donde ...) x)"
  (lambda ()
    (eval '(defsituacion sonda-3 (:etiqueta "s3")
            (coleccion c (:clave x) (:orden x)
              (campo x :rol fijo :tipo entero)
              (campo grupo :rol fijo)
              (campo acum :rol derivado :tipo entero
                     (+ (de (anterior fila :donde (= grupo (de fila grupo))) acum)
                        (de fila x))))
            (vista v :de c)))
    (let* ((s (situacion-llamada "SONDA-3"))
           (c (first (nucleo:colecciones s)))
           (campo (nucleo:campo-llamado c (n "acum")))
           (expr (nucleo:expresion campo))
           (vecino (nucleo:sobre (first (nucleo:argumentos expr)))))
      (format nil "compila sin protestar; el nodo es ~(~a~) con direccion ~(~a~) y ~
                   variable ~(~a~): el :DONDE se descarto en silencio"
              (type-of vecino) (nucleo:direccion vecino) (nucleo:variable vecino)))))

(probar "4. Comparar fechas: (<= fecha \"2026-03-05\") dentro de un :donde"
  (lambda ()
    (eval '(defsituacion sonda-4 (:etiqueta "s4")
            (coleccion movs (:clave fecha)
              (campo fecha :rol fijo :tipo fecha)
              (campo cantidad :rol fijo :tipo entero))
            (coleccion resumen (:clave rotulo)
              (campo rotulo :rol fijo)
              (campo hasta-el-cinco :rol derivado :tipo entero
                     (suma cantidad de movs :donde (<= fecha "2026-03-05"))))
            (vista v :de resumen)))
    (nucleo:evaluar-situacion
     (situacion-llamada "SONDA-4")
     (list (cons (n "movs")
                 (filas '("fecha" "cantidad")
                        '(("2026-03-01" 5) ("2026-03-09" 7))))
           (cons (n "resumen") (filas '("rotulo") '(("total"))))))))

(probar "5. Lo mismo con la fecha escrita como numero de dia"
  (lambda ()
    (eval '(defsituacion sonda-5 (:etiqueta "s5")
            (coleccion movs (:clave dia)
              (campo dia :rol fijo :tipo entero)
              (campo cantidad :rol fijo :tipo entero))
            (coleccion resumen (:clave rotulo)
              (campo rotulo :rol fijo)
              (campo hasta-el-cinco :rol derivado :tipo entero
                     (suma cantidad de movs :donde (<= dia 5))))
            (vista v :de resumen)))
    (nucleo:evaluar-situacion
     (situacion-llamada "SONDA-5")
     (list (cons (n "movs") (filas '("dia" "cantidad") '((1 5) (9 7))))
           (cons (n "resumen") (filas '("rotulo") '(("total"))))))))

(probar "6. Existencias en el momento de cada movimiento (saldo por articulo y fecha)"
  (lambda ()
    (eval '(defsituacion sonda-6 (:etiqueta "s6")
            (coleccion movs (:clave dia articulo) (:orden dia)
              (campo dia :rol fijo :tipo entero)
              (campo articulo :rol fijo)
              (campo firmada :rol fijo :tipo entero)
              (campo saldo :rol derivado :tipo entero
                     (suma firmada de movs
                           :donde (y (= articulo (de fila articulo))
                                     (<= dia (de fila dia))))))
            (vista v :de movs)))
    (nucleo:evaluar-situacion
     (situacion-llamada "SONDA-6")
     (list (cons (n "movs")
                 (filas '("dia" "articulo" "firmada")
                        '((1 "T-01" 20) (3 "T-01" -15) (2 "C-02" 100)
                          (8 "T-01" 4))))))))

(probar "7. Una afirmacion sobre la coleccion entera, no sobre una fila"
  (lambda ()
    (eval '(defsituacion sonda-7 (:etiqueta "s7")
            (coleccion arts (:clave codigo)
              (campo codigo :rol fijo)
              (campo existencias :rol fijo :tipo entero))
            (marca almacen-vacio
              :cuando (= (suma existencias de arts) 0)
              :sobre (codigo)
              :severidad problema)
            (vista v :de arts)))
    (let ((problemas (situacion.analisis:comprobar-situacion
                      (situacion-llamada "SONDA-7"))))
      (if problemas
          (situacion.analisis:informe-de-problemas problemas)
          "el analisis la acepta, pero la marca se evalua fila a fila"))))

(format t "~&~%FIN DE LAS SONDAS~%")

;;; Sonda 8. La arquitectura de texto rechaza el documento ENTERO por una
;;; sola columna que cuenta distintos, aunque escribe valores ya calculados
;;; por el evaluador y no necesita contar nada. Se comprueba materializando
;;; en texto la misma clase de situacion sin esa columna.
(probar "8. Texto plano con una situacion sin conteo de distintos"
  (lambda ()
    (let ((flujo (make-string-output-stream)))
      (protocolo:materializar (situacion.texto:hacer-texto)
                              (situacion-llamada "SONDA-6")
                              (list (cons (n "movs")
                                          (filas '("dia" "articulo" "firmada")
                                                 '((1 "T-01" 20) (3 "T-01" -15)))))
                              flujo)
      (format nil "materializa ~d caracteres de texto"
              (length (get-output-stream-string flujo))))))
