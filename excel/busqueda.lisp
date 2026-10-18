;;;; Traer un dato de otra fila: la busqueda por clave y la fila contigua.
;;;;
;;;; LA BUSQUEDA ERA BUSCARV, Y YA NO
;;;;
;;;; BUSCARV tiene tres defectos frente al evaluador de referencia, y los tres
;;;; los encontro la auditoria del 2026-10-17 con datos reales:
;;;;
;;;;   - compara sin distinguir mayusculas y trata "*" y "?" como comodines;
;;;;   - si encuentra la fila pero el campo esta en blanco, devuelve 0 y no
;;;;     blanco: el horario del Saul ensenaba 0 en 118 celdas;
;;;;   - solo mira a la derecha de la clave.
;;;;
;;;; La traduccion nueva es INDICE sobre la columna del campo y COINCIDIR
;;;; sobre un vector de EXACT, envuelto en INDICE(...;0) para que no haga
;;;; falta entrada matricial. Probado en LibreOffice Calc; en Excel de
;;;; Microsoft es la forma documentada de COINCIDIR con criterio calculado.

(in-package #:situacion.excel)

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:proyeccion) ambito plan)
  (let ((fuente (nucleo:sobre e)))
    (cond
      ((typep fuente 'nucleo:busqueda) (emitir-busqueda a e fuente ambito plan))
      ((typep fuente 'nucleo:vecino) (emitir-vecino a e fuente ambito plan))
      (t (error "No se como proyectar ~(~a~) sobre ~a"
                (nucleo:campo e) (type-of fuente))))))

(defun igualdad-simple (condicion)
  "Si CONDICION es (= <campo de la candidata> <expresion de fuera>), devuelve
   (VALUES CAMPO EXPRESION). Si no, NIL, y la busqueda se traduce con el
   producto de factores."
  (when (and (typep condicion 'nucleo:aplicacion)
             (string= (symbol-name (nucleo:operador condicion)) "=")
             (= 2 (length (nucleo:argumentos condicion))))
    (let ((izq (first (nucleo:argumentos condicion)))
          (der (second (nucleo:argumentos condicion))))
      (when (typep izq 'nucleo:ref-campo)
        (values (nucleo:campo izq) der)))))

(defun posicion-de-la-fila (a busqueda hoja-destino ambito plan)
  "La formula que da en que posicion de HOJA-DESTINO esta la primera fila
   que cumple la condicion de BUSQUEDA, o #N/A si no hay ninguna.

   Si varias filas cumplen, MATCH da la primera en orden de hoja, que es la
   misma que da el evaluador: las filas se escriben en el orden de
   NUCLEO:FILAS-DE y el evaluador devuelve la primera de ese orden.

   Una igualdad sobre un campo, el caso de casi todo el corpus, conserva su
   formula de siempre: un vector de EXACT sobre la columna de la clave. Toda
   otra condicion -dos campos, VACIO?, una comparacion- es un MATCH sobre el
   producto de los factores de la condicion, los mismos que usan CUANTAS y
   EXISTE (existencia.lisp): asi una condicion significa lo mismo en una
   busqueda que en un agregado (fase 2, hueco C2)."
  (multiple-value-bind (campo-clave expresion) (igualdad-simple (nucleo:condicion busqueda))
    (if campo-clave
        (let* ((rango-clave (rango-de-columna hoja-destino campo-clave :con-hoja t))
               (valor (operando-de-igualdad a expresion ambito plan))
               (existencia (factor-de-existencia plan hoja-destino)))
          (format nil "MATCH(1,INDEX(EXACT(~a,~a)*1~@[*~a~],0),0)"
                  rango-clave valor existencia))
        (format nil "MATCH(1,INDEX(1~{*~a~},0),0)"
                (factores-del-recorrido a (nucleo:variable busqueda)
                                        (nucleo:condicion busqueda)
                                        hoja-destino ambito plan)))))

(defun emitir-busqueda (a proyeccion busqueda ambito plan)
  "Una busqueda por clave, con su valor por defecto.

   El valor por defecto es la mitad del concepto: las busquedas del corpus
   van todas con uno, porque el usuario escribe la clave antes de que exista
   la fila relacionada. Si la fila existe y el campo esta en blanco, el
   resultado es blanco, no el valor por defecto: es lo que dice el
   evaluador."
  (let ((hoja-destino (hoja-de plan (nucleo:coleccion busqueda))))
    (unless hoja-destino
      (error "No hay hoja planificada para ~(~a~)" (nucleo:coleccion busqueda)))
    (let* ((posicion (posicion-de-la-fila a busqueda hoja-destino ambito plan))
           (columna (rango-de-columna hoja-destino (nucleo:campo proyeccion) :con-hoja t))
           (en-la-fila (format nil "INDEX(~a,~a)" columna posicion)))
      (format nil "IF(ISNA(~a),~a,IF(ISBLANK(~a),\"\",~a))"
              posicion
              (if (nucleo:por-defecto proyeccion)
                  (protocolo:emitir-expresion a (nucleo:por-defecto proyeccion) ambito plan)
                  "\"\"")
              en-la-fila en-la-fila))))

(defun emitir-vecino (a proyeccion vecino ambito plan)
  "La fila anterior o la siguiente, que en una rejilla es una fila mas arriba
   o mas abajo.

   Es legal solo porque la coleccion declara orden y porque el plan se ha
   comprometido a escribir las filas en ese orden. Sin esa declaracion, esto
   seria el modelo de la hoja de calculo colandose en el lenguaje.

   Fuera de la hoja no hay fila: el resultado es el vacio, que en aritmetica
   vale 0 porque cada operando pasa por la coercion numerica.

   Con :MISMO (fase 2, hueco C3) la fila de al lado solo cuenta si tiene los
   mismos valores en esos campos, comparados con EXACT como cualquier
   igualdad. Como :MISMO es un prefijo del orden, el grupo esta contiguo y
   no hace falta buscar."
  (declare (ignore a ambito plan))
  (let* ((desplazamiento (if (eq (nucleo:direccion vecino) :anterior) -1 1))
         (fila (+ *fila* desplazamiento)))
    (if (or (< fila (fila-primera *hoja*)) (> fila (fila-ultima *hoja*)))
        (texto-de-literal nil)
        (let ((valor (celda *hoja* (nucleo:campo proyeccion) fila)))
          (if (null (nucleo:mismos vecino))
              valor
              (format nil "IF(AND(~{~a~^,~}),~a,\"\")"
                      (loop for campo in (nucleo:mismos vecino)
                            collect (format nil "EXACT(~a&\"\",~a&\"\")"
                                            (celda *hoja* campo fila)
                                            (celda *hoja* campo *fila*)))
                      valor))))))
