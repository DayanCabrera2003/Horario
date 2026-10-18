;;;; Pruebas del orden compuesto y del vecino dentro de un grupo (fase 2,
;;;; hueco C3).
;;;;
;;;; Hasta el 2026-10-17 una coleccion declaraba como mucho un campo de orden
;;;; y (anterior fila) recorria la coleccion entera: el acumulado de horas
;;;; "por persona" mezclaba personas (36, 66, 111, 151, 189). Ahora
;;;; (:orden persona semana) ordena por los dos y (anterior fila :mismo
;;;; persona) da la fila de al lado solo si es de la misma persona.

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion horas-por-persona (:etiqueta "Horas por persona")
  (coleccion registros
    (:etiqueta "Registros")
    (:clave persona semana)
    (:orden persona semana)
    (campo persona :rol fijo :etiqueta "Persona")
    (campo semana  :rol fijo :tipo entero :etiqueta "Semana")
    (campo horas   :rol entrada :tipo entero :etiqueta "Horas")
    (campo acumulado :rol derivado :tipo entero :etiqueta "Acumulado"
           (+ (de fila horas) (de (anterior fila :mismo persona) acumulado)))
    (campo previas :rol derivado :tipo entero :etiqueta "Semana anterior"
           (de (anterior fila :mismo persona) horas))
    (campo despues :rol derivado :tipo entero :etiqueta "Semana siguiente"
           (de (siguiente fila :mismo persona) horas)))
  (vista v :de registros :entrada t :etiqueta "Registros"))

(defparameter *datos-horas-por-persona*
  (situacion.casos::datos
   (list "registros"
         (situacion.casos::fila "persona" "Zoe" "semana" 10 "horas" 38)
         (situacion.casos::fila "persona" "Ana" "semana" 2 "horas" 45)
         (situacion.casos::fila "persona" "Zoe" "semana" 2 "horas" 40)
         (situacion.casos::fila "persona" "Ana" "semana" 1 "horas" 36)
         (situacion.casos::fila "persona" "Zoe" "semana" 1 "horas" 30))))

(situacion.lenguaje:defsituacion saldo-por-almacen (:etiqueta "Saldo por almacen")
  (coleccion movimientos
    (:etiqueta "Movimientos")
    (:clave almacen articulo dia)
    (:orden almacen articulo dia)
    (campo almacen  :rol fijo :etiqueta "Almacen")
    (campo articulo :rol fijo :etiqueta "Articulo")
    (campo dia      :rol fijo :tipo entero :etiqueta "Dia")
    (campo cantidad :rol fijo :tipo entero :etiqueta "Cantidad")
    (campo saldo :rol derivado :tipo entero :etiqueta "Saldo"
           (+ (de fila cantidad)
              (de (anterior fila :mismo (almacen articulo)) saldo))))
  (vista v :de movimientos :etiqueta "Movimientos"))

(defparameter *datos-saldo-por-almacen*
  (situacion.casos::datos
   (list "movimientos"
         (situacion.casos::fila "almacen" "N" "articulo" "A" "dia" 2 "cantidad" 5)
         (situacion.casos::fila "almacen" "N" "articulo" "A" "dia" 1 "cantidad" 3)
         (situacion.casos::fila "almacen" "N" "articulo" "B" "dia" 1 "cantidad" 4)
         (situacion.casos::fila "almacen" "S" "articulo" "A" "dia" 1 "cantidad" 7)
         (situacion.casos::fila "almacen" "N" "articulo" "A" "dia" 3 "cantidad" -2))))

(situacion.lenguaje:defsituacion mismo-sin-prefijo (:etiqueta "Mismo sin prefijo")
  (coleccion movimientos
    (:etiqueta "Movimientos")
    (:clave articulo fecha)
    (:orden fecha)
    (campo articulo :rol fijo :etiqueta "Articulo")
    (campo fecha    :rol fijo :tipo entero :etiqueta "Fecha")
    (campo cantidad :rol fijo :tipo entero :etiqueta "Cantidad")
    (campo saldo :rol derivado :tipo entero :etiqueta "Saldo"
           (+ (de fila cantidad) (de (anterior fila :mismo articulo) saldo))))
  (vista v :de movimientos :etiqueta "Movimientos"))

(situacion.lenguaje:defsituacion horas-que-crecen (:etiqueta "Horas que crecen")
  (coleccion registros
    (:etiqueta "Registros")
    (:clave persona semana)
    (:orden persona semana)
    (:crece)
    (campo persona :rol fijo :etiqueta "Persona")
    (campo semana  :rol fijo :tipo entero :etiqueta "Semana")
    (campo horas   :rol entrada :tipo entero :etiqueta "Horas")
    (campo acumulado :rol derivado :tipo entero :etiqueta "Acumulado"
           (+ (de fila horas) (de (anterior fila :mismo persona) acumulado))))
  (vista v :de registros :entrada t :etiqueta "Registros"))

(defun columna-evaluada (situacion datos coleccion campo)
  "Los valores de CAMPO en COLECCION, en el orden del evaluador."
  (mapcar (lambda (fila) (cdr (assoc (nucleo:nombrar campo) (car fila))))
          (cdr (assoc (nucleo:nombrar coleccion)
                      (nucleo:evaluar-situacion situacion datos)))))

(definir-prueba orden-compuesto-es-lexicografico
    "Orden compuesto: ordena por el primer campo y, a igualdad, por el segundo"
  (let ((s (situacion.lenguaje:situacion-llamada "HORAS-POR-PERSONA")))
    (comprobar (equal (columna-evaluada s *datos-horas-por-persona* "registros" "persona")
                      '("Ana" "Ana" "Zoe" "Zoe" "Zoe"))
               "las filas tienen que ir por persona")
    ;; La semana 10 va despues de la 2: se compara como numero.
    (comprobar (equal (columna-evaluada s *datos-horas-por-persona* "registros" "semana")
                      '(1 2 1 2 10))
               "dentro de cada persona, por semana: ~s"
               (columna-evaluada s *datos-horas-por-persona* "registros" "semana"))))

(definir-prueba orden-compuesto-es-estable
    "Orden compuesto: dos filas iguales en todos los campos del orden conservan su orden"
  (let ((filas (nucleo::ordenar-filas
                (list (nucleo::hacer-fila nil (nucleo::tabla-de-valores
                                               (list (cons 'a "x") (cons 'b 1) (cons 'c "p"))))
                      (nucleo::hacer-fila nil (nucleo::tabla-de-valores
                                               (list (cons 'a "x") (cons 'b 1) (cons 'c "q"))))
                      (nucleo::hacer-fila nil (nucleo::tabla-de-valores
                                               (list (cons 'a "w") (cons 'b 2) (cons 'c "r")))))
                '(a b))))
    (comprobar (equal (mapcar (lambda (f) (gethash 'c (nucleo:valores f))) filas)
                      '("r" "p" "q"))
               "p tiene que seguir antes que q")))

(definir-prueba mismo-con-un-campo
    "Vecino :mismo: el acumulado de cada persona no mezcla personas"
  (let ((s (situacion.lenguaje:situacion-llamada "HORAS-POR-PERSONA")))
    (comprobar (equal (columna-evaluada s *datos-horas-por-persona* "registros" "acumulado")
                      '(36 81 30 70 108))
               "el acumulado tiene que ser Ana 36/81 y Zoe 30/70/108: ~s"
               (columna-evaluada s *datos-horas-por-persona* "registros" "acumulado"))))

(definir-prueba mismo-en-el-borde-del-grupo
    "Vecino :mismo: en el borde del grupo no hay fila, y el acceso da vacio"
  (let* ((s (situacion.lenguaje:situacion-llamada "HORAS-POR-PERSONA"))
         (previas (columna-evaluada s *datos-horas-por-persona* "registros" "previas"))
         (despues (columna-evaluada s *datos-horas-por-persona* "registros" "despues")))
    (comprobar (and (nucleo:vacio-p (first previas)) (eql 36 (second previas))
                    (nucleo:vacio-p (third previas)) (eql 30 (fourth previas))
                    (eql 40 (fifth previas)))
               "la semana anterior tiene que ser vacio, 36, vacio, 30, 40: ~s" previas)
    (comprobar (and (eql 45 (first despues)) (nucleo:vacio-p (second despues))
                    (eql 40 (third despues)) (eql 38 (fourth despues))
                    (nucleo:vacio-p (fifth despues)))
               "la semana siguiente tiene que ser 45, vacio, 40, 38, vacio: ~s" despues)))

(definir-prueba mismo-con-dos-campos
    "Vecino :mismo: con dos campos, el saldo es de cada almacen y articulo"
  (comprobar (equal (columna-evaluada (situacion.lenguaje:situacion-llamada "SALDO-POR-ALMACEN")
                                      *datos-saldo-por-almacen* "movimientos" "saldo")
                    '(3 8 6 4 7))
             "el saldo tiene que ser 3 8 6 4 7: ~s"
             (columna-evaluada (situacion.lenguaje:situacion-llamada "SALDO-POR-ALMACEN")
                               *datos-saldo-por-almacen* "movimientos" "saldo")))

(definir-prueba mismo-tiene-que-ser-prefijo-del-orden
    "Vecino :mismo: si no es prefijo del orden, el analisis lo rechaza y dice como arreglarlo"
  (let ((errores (errores-de (situacion.lenguaje:situacion-llamada "MISMO-SIN-PREFIJO"))))
    (comprobar (some (lambda (p) (let ((texto (analisis:texto-de-problema p)))
                                   (and (search ":mismo" texto) (search "(:orden articulo" texto))))
                     errores)
               "el error tiene que sugerir (:orden articulo ...): ~a"
               (analisis:informe-de-problemas errores)))
  (comprobar (null (errores-de (situacion.lenguaje:situacion-llamada "HORAS-POR-PERSONA")))
             "un :mismo que es prefijo del orden no es error"))

(definir-prueba mismo-solo-admite-mismo
    "Vecino :mismo: cualquier otra clave en (anterior ...) es error de compilacion"
  (comprobar (handler-case
                 (progn (situacion.lenguaje::compilar-expresion
                         '(de (anterior fila :donde (= a 1)) x))
                        nil)
               (error (e) (search ":MISMO" (string-upcase (princ-to-string e)))))
             "(anterior fila :donde ...) tiene que ser error y nombrar :MISMO"))

(definir-prueba mismo-en-la-hoja-de-calculo
    "Vecino :mismo: la hoja de calculo mira la fila de arriba solo si es del mismo grupo"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORAS-POR-PERSONA")
                          *datos-horas-por-persona*))
         (hoja (hoja-de-coleccion plano "registros"))
         (formula (formula-de-celda hoja (celda-de-campo hoja "acumulado" 5)))
         (persona-arriba (celda-de-campo hoja "persona" 4))
         (persona-aqui (celda-de-campo hoja "persona" 5)))
    (comprobar (and formula (search "EXACT(" formula)
                    (search persona-arriba formula) (search persona-aqui formula))
               "el acumulado tiene que comparar con EXACT la persona de arriba (~a) y la de aqui (~a): ~a"
               persona-arriba persona-aqui formula)))

(definir-prueba mismo-en-la-pagina
    "Vecino :mismo: la pagina recibe los campos del grupo"
  (let ((html (materializar-en-cadena (situacion.web:hacer-web)
                                      (situacion.lenguaje:situacion-llamada "HORAS-POR-PERSONA")
                                      *datos-horas-por-persona*)))
    (comprobar (search ", -1, [\"persona\"])" html)
               "VECINO tiene que recibir [\"persona\"]")))

(definir-prueba orden-con-filas-anadidas-en-la-hoja-emula
    "Orden: en la hoja de calculo, una coleccion que crece con vecino emula y lo dice"
  (multiple-value-bind (salida informe)
      (materializar-en-cadena (situacion.excel:hacer-excel)
                              (situacion.lenguaje:situacion-llamada "HORAS-QUE-CRECEN")
                              *datos-horas-por-persona*)
    (declare (ignore salida))
    (let ((entrada (find-if (lambda (e)
                              (and (eq (protocolo:entrada-de-informe-capacidad e)
                                       'protocolo:con-orden-declarado)
                                   (eq (protocolo:entrada-de-informe-respuesta e) :emula)))
                            (protocolo:entradas-del-informe informe))))
      (comprobar (and entrada (eq (protocolo:entrada-de-informe-respuesta entrada) :emula)
                      (search "en su sitio" (protocolo:entrada-de-informe-nota entrada)))
                 "el informe tiene que decir emula y que hay que escribir las filas en su sitio"))))

(definir-prueba orden-la-pagina-reordena
    "Orden: la pagina vuelve a ordenar la coleccion al anadir una fila o cambiar el orden"
  (let ((html (materializar-en-cadena (situacion.web:hacer-web)
                                      (situacion.lenguaje:situacion-llamada "HORAS-QUE-CRECEN")
                                      *datos-horas-por-persona*)))
    (comprobar (search "ORDENES" html) "la pagina tiene que conocer el orden de cada coleccion")
    (comprobar (search "reordenar(" html) "la pagina tiene que poder reordenar")))
