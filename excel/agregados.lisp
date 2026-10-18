;;;; Agregados: contar, sumar, minimo, maximo y valores distintos.
;;;;
;;;; Antes se traducian a CONTAR.SI y SUMAR.SI, que son las funciones de
;;;; criterio de la hoja de calculo. Tienen tres problemas que el evaluador de
;;;; referencia no tiene, y que la auditoria del 2026-10-17 midio con datos:
;;;; no distinguen mayusculas ("Lacteos" sumaba tambien "lacteos"), tratan
;;;; "*" y "?" como comodines ("Frutas*" sumaba tambien "Frutas") y no saben
;;;; contar los campos vacios de las filas que existen (contaban cero, o las
;;;; filas de reserva enteras).
;;;;
;;;; Ahora un agregado es una suma de productos sobre los mismos factores que
;;;; usa el cuantificador (existencia.lisp): la condicion significa lo mismo
;;;; en las dos construcciones, y significa lo que dice el evaluador. De paso,
;;;; el minimo y el maximo con condicion, que antes se rechazaban, tienen
;;;; traduccion.

(in-package #:situacion.excel)

(defun valores-numericos (hoja campo)
  "La columna CAMPO de HOJA convertida a numeros como el evaluador, como
   vector."
  (como-numero-excel (rango-de-columna hoja campo :con-hoja t)))

(defun producto-de (factores)
  "El vector producto de FACTORES, que vale 1 en las filas que cumplen."
  (format nil "(1~{*(~a)~})" factores))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:agregado) ambito plan)
  (let ((hoja-destino (hoja-de plan (nucleo:coleccion e))))
    (unless hoja-destino
      (error "No hay hoja planificada para ~(~a~)" (nucleo:coleccion e)))
    (if (eq (nucleo:operacion e) :distintas)
        (emitir-distintas a e hoja-destino)
        (let ((factores (factores-del-recorrido a (nucleo:variable e) (nucleo:condicion e)
                                                hoja-destino ambito plan)))
          (ecase (nucleo:operacion e)
            (:cuantas
             (if factores
                 (suma-de-productos factores)
                 ;; Sin condicion y sin filas de reserva: todas las filas.
                 (format nil "ROWS(~a)"
                         (rango-de-columna hoja-destino
                                           (first (campos-de-existencia
                                                   (coleccion hoja-destino)))
                                           :con-hoja t))))
            (:suma
             (suma-de-productos
              (append factores (list (valores-numericos hoja-destino (nucleo:campo e))))))
            ((:minimo :maximo)
             ;; Sin filas que cumplan, el evaluador da vacio. Con alguna, el
             ;; menor o el mayor de sus valores: las que no cumplen se apartan
             ;; sumando o restando un numero enorme, que es lo unico que MIN y
             ;; MAX entienden sin formula matricial.
             (let ((valores (valores-numericos hoja-destino (nucleo:campo e)))
                   (cumple (producto-de factores)))
               (format nil "IF(~a=0,\"\",SUMPRODUCT(~a(~a~a(1-~a)*1E+300)))"
                       (suma-de-productos factores)
                       (if (eq (nucleo:operacion e) :minimo) "MIN" "MAX")
                       valores
                       (if (eq (nucleo:operacion e) :minimo) "+" "-")
                       cumple))))))))

(defun emitir-distintas (a e hoja-destino)
  "Cuantos valores distintos toma un campo: la suma de la columna auxiliar
   que marca, en cada fila, si su valor aparece por primera vez.

   Con condicion no hay traduccion honesta: la columna auxiliar no sabe
   aplicarla. Se pide la capacidad y el mecanismo de carencias decide."
  (protocolo:requerir a 'protocolo:con-conteo-de-distintos e
                      :detalle (format nil "cuantos valores distintos toma ~(~a~)"
                                       (nucleo:campo e)))
  (let ((columna (columna-de-distintos-de hoja-destino (nucleo:campo e))))
    (format nil "SUM(~a!$~a$~d:$~a$~d)"
            (entrecomillar (nombre hoja-destino))
            (letra columna) (fila-primera hoja-destino)
            (letra columna) (fila-ultima hoja-destino))))

(defun formula-de-primera-aparicion (plan hoja columna fila)
  "Si el valor de la fila FILA aparece por primera vez en su columna: 1 o 0.

   Compara con EXACT contra las filas de arriba, asi que distingue mayusculas
   como el evaluador. Una fila que no existe o sin valor no cuenta."
  (let* ((campo (campo-de columna))
         (aqui (celda hoja campo fila))
         (existe (let ((*fila* fila))
                   (fila-existe-aqui plan hoja)))
         (condicion (format nil "AND(~a,~a<>\"\")" existe aqui)))
    (if (= fila (fila-primera hoja))
        (format nil "=IF(~a,1,0)" condicion)
        (let ((arriba (format nil "~a!$~a$~d:$~a$~d"
                              (entrecomillar (nombre hoja))
                              (columna-de hoja campo) (fila-primera hoja)
                              (columna-de hoja campo) (1- fila))))
          (format nil "=IF(~a,IF(SUMPRODUCT(1*EXACT(~a,~a))=0,1,0),0)"
                  condicion arriba aqui)))))

(defun fila-existe-aqui (plan hoja)
  "Si la fila *FILA* de HOJA existe, como condicion de formula. Ver
   FACTOR-DE-EXISTENCIA: es la misma regla, para una sola fila."
  (if (or (eq (nucleo:crecimiento (coleccion hoja)) :crece)
          (zerop (filas-reales plan hoja)))
      (format nil "OR(~{~a<>\"\"~^,~})"
              (mapcar (lambda (c) (celda hoja c *fila*))
                      (campos-de-existencia (coleccion hoja))))
      "TRUE"))

;;; ---------------------------------------------------------------------
;;; La relacion uno a muchos
;;; ---------------------------------------------------------------------

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:relacionadas) ambito plan)
  "Un conteo en vivo sobre la tabla cruda de la hoja auxiliar (H4,
   excel/relacion.lisp), no la lista entera: eso es lo que REQUERIR deja
   claro en el informe -se emula, con limite-.

   Cuenta las filas de la tabla cruda cuya clave numerada empieza EXACTAMENTE
   por la clave de esta fila seguida del separador. Antes era un CONTAR.SI
   con comodin, que confundia mayusculas y leia como comodin un \"*\" que
   estuviera en la clave."
  (declare (ignore ambito))
  (protocolo:requerir a 'protocolo:con-relacion-uno-a-muchos e
                      :detalle (format nil "todas las filas de ~(~a~) relacionadas"
                                       (nucleo:coleccion e)))
  (let* ((detalle (find e (auxiliares plan) :key (lambda (d) (nucleo:expresion (campo d)))))
         (tabla-cruda (tabla-cruda detalle))
         (rango-clave (rango-de-columna tabla-cruda "__clave__" :con-hoja t))
         (prefijo (format nil "(~a&CHAR(30))"
                          (formula-de-clave *hoja* *fila* (coleccion *hoja*)))))
    (format nil "SUMPRODUCT(1*EXACT(LEFT(~a,LEN(~a)),~a))"
            rango-clave prefijo prefijo)))
