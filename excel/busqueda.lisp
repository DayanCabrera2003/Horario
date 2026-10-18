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
   (VALUES CAMPO EXPRESION). Si no, NIL."
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

   La condicion de una busqueda es una igualdad sobre un campo; las demas
   formas se rechazan con un mensaje claro (la busqueda por varios campos es
   un hueco conocido, ver GUIA-DEL-LENGUAJE 11.2)."
  (multiple-value-bind (campo-clave expresion) (igualdad-simple (nucleo:condicion busqueda))
    (unless campo-clave
      (error "Esta hoja de calculo busca por una igualdad sobre un campo.~@
              La condicion de la busqueda en ~(~a~) es mas complicada."
             (nucleo:coleccion busqueda)))
    (let* ((rango-clave (rango-de-columna hoja-destino campo-clave :con-hoja t))
           (valor (operando-de-igualdad a expresion ambito plan))
           (existencia (factor-de-existencia plan hoja-destino)))
      (format nil "MATCH(1,INDEX(EXACT(~a,~a)*1~@[*~a~],0),0)"
              rango-clave valor existencia))))

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
   vale 0 porque cada operando pasa por la coercion numerica."
  (declare (ignore a ambito plan))
  (let* ((desplazamiento (if (eq (nucleo:direccion vecino) :anterior) -1 1))
         (fila (+ *fila* desplazamiento)))
    (if (or (< fila (fila-primera *hoja*)) (> fila (fila-ultima *hoja*)))
        (texto-de-literal nil)
        (celda *hoja* (nucleo:campo proyeccion) fila))))
