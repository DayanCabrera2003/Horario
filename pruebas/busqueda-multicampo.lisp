;;;; Pruebas de la busqueda por varios campos (fase 2, hueco C2).
;;;;
;;;; Hasta el 2026-10-17 la hoja de calculo solo traducia una busqueda cuya
;;;; condicion fuese una igualdad sobre un campo: con dos, la casilla salia
;;;; con un marcador y el informe decia rechaza. El Saul llevaba por eso dos
;;;; claves pegadas a mano con "#". Ahora la posicion de la fila es un MATCH
;;;; sobre el producto de los mismos factores que usan CUANTAS y EXISTE
;;;; (excel/existencia.lisp), y una condicion significa lo mismo en los dos
;;;; sitios. El caso es pruebas/casos/pedidos.lisp.

(in-package #:situacion.pruebas)

(defun situacion-de-pedidos ()
  (situacion.lenguaje:situacion-llamada "CASO-PEDIDOS"))

(defun valores-de-pedidos (campo)
  "Los valores de CAMPO en los pedidos, segun el evaluador de referencia."
  (let ((evaluado (nucleo:evaluar-situacion (situacion-de-pedidos)
                                            (datos-del-caso "DATOS-DE-PEDIDOS"))))
    (mapcar (lambda (fila) (cdr (assoc (nucleo:nombrar campo) (car fila))))
            (cdr (assoc (nucleo:nombrar "pedidos") evaluado)))))

(definir-prueba busqueda-varias-cumplen-da-la-primera
    "Busqueda: si varias filas cumplen, la-fila-de da la primera de la coleccion"
  ;; L1 y L2 son los dos de Norte y A-1: tiene que salir L1.
  (comprobar (equal (first (valores-de-pedidos "lote")) "L1")
             "el pedido 1 tiene que servirlo L1, el primero: ~s"
             (first (valores-de-pedidos "lote"))))

(definir-prueba busqueda-casos-limite-en-el-evaluador
    "Busqueda: mayusculas, vacios, vacio? y :si-no en el evaluador"
  (comprobar (equal (valores-de-pedidos "lote")
                    '("L1" "sin existencias" "L4" "sin existencias" "L3"))
             "los lotes de los pedidos no son los esperados: ~s"
             (valores-de-pedidos "lote"))
  (comprobar (equal (valores-de-pedidos "hay") '(5 0 7 0 2))
             "las unidades de los pedidos no son las esperadas: ~s"
             (valores-de-pedidos "hay"))
  (comprobar (equal (valores-de-pedidos "suelto") '("" "" "L4" "L4" ""))
             "el lote sin almacen no es el esperado: ~s" (valores-de-pedidos "suelto")))

(definir-prueba busqueda-por-dos-campos-en-la-hoja
    "Busqueda: la hoja de calculo traduce dos condiciones con un producto de factores"
  (multiple-value-bind (salida informe)
      (materializar-en-cadena (situacion.excel:hacer-excel) (situacion-de-pedidos)
                              (datos-del-caso "DATOS-DE-PEDIDOS"))
    (declare (ignore salida))
    (comprobar (notany (lambda (e) (eq (protocolo:entrada-de-informe-respuesta e) :rechaza))
                       (protocolo:entradas-del-informe informe))
               "la hoja de calculo no puede rechazar una busqueda por dos campos"))
  (let* ((plano (plano-de (situacion-de-pedidos) (datos-del-caso "DATOS-DE-PEDIDOS")))
         (hoja (hoja-de-coleccion plano "pedidos"))
         (formula (formula-de-celda hoja "E4")))
    (comprobar (and formula (search "MATCH(1,INDEX(1*" formula) (search "EXACT(" formula))
               "la busqueda del lote tiene que ser un MATCH sobre un producto con EXACT: ~a"
               formula)))

(definir-prueba busqueda-simple-no-cambia
    "Busqueda: una igualdad sobre un campo sigue con la formula de antes"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                          situacion.corpus:datos-del-saul))
         (hoja (hoja-de-coleccion plano "plan-por-grupo"))
         (formula (formula-de-celda hoja (celda-de-campo hoja "nombre" 4))))
    (comprobar (and formula (search "MATCH(1,INDEX(EXACT(" formula))
               "el nombre de la asignatura tiene que seguir buscandose con EXACT: ~a"
               formula)))
