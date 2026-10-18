;;;; Recorrer una coleccion con una condicion: el cuantificador existencial y
;;;; los factores que comparten con los agregados.
;;;;
;;;; Una hoja de calculo no tiene cuantificadores. Se emula con la suma de
;;;; productos de vectores, que es el idioma establecido y el que usa el
;;;; corpus: cada termino de la condicion es un vector de 0 y 1 sobre las
;;;; filas de la coleccion recorrida, y la fila cumple si el producto vale 1.
;;;; Los agregados (agregados.lisp) usan los mismos factores, asi que una
;;;; condicion significa lo mismo en un EXISTE que en un CUANTAS.
;;;;
;;;; LAS FILAS QUE NO EXISTEN
;;;;
;;;; En una coleccion que crece hay filas de reserva en blanco al final de la
;;;; hoja. Para el evaluador esas filas no existen; para un recorrido sobre la
;;;; columna entera, si, y son filas con todos sus campos vacios. Sin el
;;;; factor de existencia, "cuantas citaciones no tienen estudiante" contaba
;;;; tambien las veinte de reserva.

(in-package #:situacion.excel)

(defun filas-reales (plan hoja)
  "Cuantas filas de datos tiene de verdad la coleccion de HOJA."
  (length (nucleo:filas-de (entorno plan) (nucleo:nombre (coleccion hoja)))))

(defun factor-de-existencia (plan hoja)
  "El vector que vale 1 en las filas de HOJA que existen, como fragmento de
   formula, o NIL si existen todas.

   Una fila existe si tiene escrito algun campo de su clave. Una coleccion que
   no crece y tiene datos no tiene filas de reserva: ahi existen todas."
  (when (or (eq (nucleo:crecimiento (coleccion hoja)) :crece)
            (zerop (filas-reales plan hoja)))
    (format nil "((~{(~a<>\"\")~^+~})>0)"
            (mapcar (lambda (campo) (rango-de-columna hoja campo :con-hoja t))
                    (campos-de-existencia (coleccion hoja))))))

(defun campos-de-existencia (coleccion)
  "Los campos cuyo contenido dice que una fila existe: los de la clave, o el
   primero si la coleccion no declara clave."
  (or (nucleo:clave coleccion)
      (list (nucleo:nombre (first (nucleo:campos coleccion))))))

(defun factores-de-condicion (a condicion hoja-destino ambito plan)
  "Descompone CONDICION, que habla de la fila candidata de HOJA-DESTINO, en
   factores multiplicables. Quien llama tiene ligado *CANDIDATA*."
  (cond
    ;; Conjuncion: cada termino es un factor.
    ((and (typep condicion 'nucleo:aplicacion)
          (string= (symbol-name (nucleo:operador condicion)) "Y"))
     (loop for termino in (nucleo:argumentos condicion)
           append (factores-de-condicion a termino hoja-destino ambito plan)))

    ;; Disyuncion. OR() colapsaria el arreglo a un solo valor, asi que se
    ;; suman las ramas -cada una, producto de sus factores- y se pregunta si
    ;; alguna dio uno.
    ((and (typep condicion 'nucleo:aplicacion)
          (string= (symbol-name (nucleo:operador condicion)) "O"))
     (list (format nil "((~{(~{~a~^*~})~^+~})>0)"
                   (loop for rama in (nucleo:argumentos condicion)
                         collect (factores-de-condicion a rama hoja-destino
                                                        ambito plan)))))

    ;; Negacion, por la misma razon que la disyuncion: NOT() tampoco recorre.
    ((and (typep condicion 'nucleo:aplicacion)
          (string= (symbol-name (nucleo:operador condicion)) "NO"))
     (list (format nil "(1-(~{~a~^*~}))"
                   (factores-de-condicion a (first (nucleo:argumentos condicion))
                                          hoja-destino ambito plan))))

    ;; Comparacion: cada lado se traduce con la candidata ligada a su columna,
    ;; asi que un lado que la mencione es un arreglo, aunque lleve
    ;; aritmetica, y el otro una celda o un literal. EXACT y la coercion
    ;; numerica operan elemento a elemento.
    ((and (typep condicion 'nucleo:aplicacion)
          (member (symbol-name (nucleo:operador condicion))
                  '("=" "/=" "<" "<=" ">" ">=") :test #'string=))
     (list (format nil "(~a)" (protocolo:emitir-expresion a condicion ambito plan))))

    ;; Comparten: alguna de las columnas de la candidata coincide con alguna
    ;; de las de esta fila. Se despliega en una suma de productos.
    ;;
    ;; Cada termino exige ademas que ninguno de los dos lados este vacio: en
    ;; la hoja de calculo "" y "" son iguales, asi que sin esta guarda dos
    ;; campos sin escribir contarian como coincidencia. El evaluador de
    ;; referencia y la web ya filtran los vacios antes de comparar.
    ((typep condicion 'nucleo:comparten)
     (list (format nil "((~{~a~^+~})>0)"
                   (loop for campo-aqui in (nucleo:campos condicion)
                         append (loop for campo-alla in (nucleo:campos condicion)
                                      collect
                                      (let ((rango (rango-de-columna hoja-destino
                                                                     campo-alla
                                                                     :con-hoja t))
                                            (celda-aqui (celda *hoja* campo-aqui *fila*)))
                                        (format nil "((~a<>\"\")*(~a<>\"\")*EXACT(~a,~a))"
                                                rango celda-aqui rango celda-aqui)))))))

    ;; "Esta vacio": compara con la cadena vacia, elemento a elemento si
    ;; habla de la candidata.
    ((typep condicion 'nucleo:sin-escribir)
     (list (protocolo:emitir-expresion a condicion ambito plan)))

    ;; Cualquier otra cosa -un campo de la candidata que vale "si" o "no",
    ;; un numero- se juzga como el evaluador: cuenta si es "si" o un numero
    ;; distinto de cero. Elemento a elemento, sin OR(), que colapsaria el
    ;; arreglo.
    (t (let ((v (protocolo:emitir-expresion a condicion ambito plan)))
         (list (format nil "((EXACT(~a&\"\",\"si\")+ISNUMBER(~a)*(~a<>0))>0)"
                       v v v))))))

(defun factores-del-recorrido (a variable condicion hoja-destino ambito plan)
  "Los factores de un recorrido de HOJA-DESTINO con VARIABLE como fila
   candidata: los de la condicion, si la hay, mas el de existencia."
  (let ((factores (when condicion
                    (let ((*candidata* (cons variable hoja-destino)))
                      (factores-de-condicion a condicion hoja-destino ambito plan))))
        (existencia (factor-de-existencia plan hoja-destino)))
    (if existencia (cons existencia factores) factores)))

(defmethod protocolo:emitir-expresion ((a excel) (e nucleo:existe) ambito plan)
  (let* ((hoja-destino (hoja-de plan (nucleo:coleccion e)))
         (factores (factores-del-recorrido a (nucleo:variable e) (nucleo:condicion e)
                                           hoja-destino ambito plan)))
    (when (nucleo:distinta-de e)
      ;; Excluir la propia fila. En el corpus esto se hace comparando el
      ;; numero de fila; aqui sale de que :DISTINTA-DE lo diga el lenguaje en
      ;; vez de esconderse en la formula.
      (setf factores
            (append factores
                    (list (format nil "(ROW(~a)<>ROW(~a))"
                                  (rango-de-columna hoja-destino
                                                    (nucleo:nombre
                                                     (first (nucleo:campos
                                                             (coleccion hoja-destino))))
                                                    :con-hoja t)
                                  (celda *hoja* (nucleo:nombre
                                                 (first (nucleo:campos (coleccion *hoja*))))
                                         *fila*))))))
    (format nil "(~a>0)" (suma-de-productos factores))))

(defun suma-de-productos (factores)
  "SUMPRODUCT del producto de FACTORES. El 1 delante es necesario: un solo
   vector de VERDADERO y FALSO, sin multiplicar por nada, suma 0."
  (format nil "SUMPRODUCT(1~{*(~a)~})" factores))
