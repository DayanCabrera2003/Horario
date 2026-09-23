;;;; La relacion uno a muchos (H4): emulada con una hoja auxiliar de clave
;;;; numerada.
;;;;
;;;; Por que una hoja aparte y no una columna mas en la hoja de origen: la
;;;; hoja de origen es una tabla, una fila por fila padre (un profesor, un
;;;; articulo de almacen). Una relacion uno-a-muchos no cabe en una celda de
;;;; esa tabla sin romper su forma rectangular. La respuesta -documentada ya
;;;; en departamento/hoja_carga.py del sistema anterior- es un detalle
;;;; aparte: una hoja con un bloque de filas reservadas por cada fila padre,
;;;; que busca sus relacionadas por una clave numerada (Rosa#1, Rosa#2, ...).
;;;;
;;;; LA HOJA AUXILIAR TIENE DOS PARTES, LADO A LADO
;;;;
;;;;   La tabla cruda   columnas __clave__ + los campos de la coleccion
;;;;                     relacionada, una fila por cada par (padre,
;;;;                     relacionada). Es una instancia normal de HOJA -la
;;;;                     misma clase de excel/plan.lisp- para que
;;;;                     COLUMNA-DE, CELDA, RANGO-DE-COLUMNA y ENTRECOMILLAR
;;;;                     funcionen igual que en cualquier otro sitio. Es lo
;;;;                     que BUSCARV y COUNTIF consultan.
;;;;
;;;;   El bloque legible   por cada fila padre, una linea de cabecera con su
;;;;                       clave y CAPACIDAD-DE-DETALLE lineas reservadas con
;;;;                       BUSCARV sobre la clave numerada. Si hay mas
;;;;                       relacionadas que reserva, la ultima linea escribe
;;;;                       un aviso en vez de una busqueda mas. Los bloques
;;;;                       se apilan verticalmente, en el orden de la hoja
;;;;                       padre.
;;;;
;;;; La celda de ASIGNACIONES en la hoja de origen no intenta mostrar la
;;;; lista -no le cabe-: muestra un conteo en vivo con COUNTIF sobre la
;;;; columna __clave__ de la tabla cruda (ver excel/formula.lisp), que apunta
;;;; a que el detalle esta aqui.

(in-package #:situacion.excel)

(defun campo-de-relacion-p (campo)
  "Cierto si CAMPO es derivado con una expresion RELACIONADAS."
  (and (eq (nucleo:rol campo) :derivado)
       (nucleo:expresion campo)
       (typep (nucleo:expresion campo) 'nucleo:relacionadas)))

(defun campos-de-relacion (coleccion)
  (remove-if-not #'campo-de-relacion-p (nucleo:campos coleccion)))

(defclass hoja-de-detalle ()
  ((campo :accessor campo :initarg :campo)
   (hoja-objetivo :accessor hoja-objetivo :initarg :hoja-objetivo
                  :documentation "La hoja de la coleccion RELACIONADA, si tiene.")
   (tabla-cruda :accessor tabla-cruda :initarg :tabla-cruda
                :documentation
                "La tabla cruda de clave numerada, como una instancia normal
                 de HOJA: mismas columnas, filas y direccionamiento que
                 cualquier otra hoja del libro. Columna A es __CLAVE__ (el
                 texto \"Rosa#1\", \"Rosa#2\", ...); el resto son los campos
                 de la coleccion objetivo, en su orden de declaracion.")
   (bloques :accessor bloques :initarg :bloques
            :documentation
            "Lista de (CLAVE-PADRE . FILAS), una entrada por fila padre, en
             el mismo orden que la hoja padre. FILAS son las filas del
             nucleo ya evaluadas -EVALUAR-EN-FILA sobre la expresion
             RELACIONADAS-, no valores: de ahi se leen los campos objetivo
             al escribir la tabla cruda."))
  (:documentation "Geometria de una relacion uno-a-muchos, ya resuelta."))

(defun clave-de-fila (coleccion entorno fila)
  "El valor de la clave de FILA, como texto. Junta con '#' si es compuesta."
  (format nil "~{~a~^#~}"
          (mapcar (lambda (c) (nucleo:como-texto (nucleo:valor-de-campo entorno fila c)))
                  (nucleo:clave coleccion))))

(defun formula-de-clave (hoja fila coleccion)
  "La clave de FILA (un numero de fila de HOJA), como fragmento de formula:
   cada campo de (NUCLEO:CLAVE COLECCION) por su referencia de celda, unidos
   con '&\"#\"&'. Es el mismo separador y los mismos campos que CLAVE-DE-FILA
   usa para escribir la clave numerada en la tabla cruda -tienen que
   coincidir campo a campo, o el COUNTIF de EMITIR-EXPRESION sobre
   RELACIONADAS (excel/formula.lisp) busca con un prefijo mas corto que la
   clave real y, con una clave compuesta, cuenta las relacionadas de OTRA
   fila padre que comparta solo el primer campo.

   Analogo a CLAVES-COMPUESTAS (excel/emision.lisp), que hace lo mismo para
   los dos ejes de una tabla cruzada."
  (format nil "~{~a~^&\"#\"&~}"
          (mapcar (lambda (c) (celda hoja c fila)) (nucleo:clave coleccion))))

(defun nombre-de-hoja-de-detalle (campo)
  "El nombre de la pestana auxiliar de una relacion.

   Excel no admite nombres de hoja de mas de 31 caracteres; es la misma
   restriccion de formato que NOMBRE-DE-PESTANA resuelve para los cruces."
  (let ((completo (format nil "Detalle - ~a" (nucleo:etiqueta campo))))
    (if (> (length completo) 31) (subseq completo 0 31) completo)))

(defun construir-tabla-cruda (campo hoja-objetivo bloques)
  "La tabla cruda: __clave__ mas los campos de la coleccion objetivo, una
   fila por cada par (padre, relacionada), en el mismo orden que BLOQUES."
  (let* ((coleccion-objetivo (coleccion hoja-objetivo))
         (campos-objetivo (nucleo:campos coleccion-objetivo))
         (columnas (cons (cons "__clave__" (letra-de-columna 0))
                         (loop for campo-obj in campos-objetivo
                               for i from 1
                               collect (cons (nucleo:nombre campo-obj) (letra-de-columna i)))))
         (total-filas (reduce #'+ (mapcar (lambda (b) (length (cdr b))) bloques)
                              :initial-value 0)))
    (make-instance
     'hoja
     :nombre (nombre-de-hoja-de-detalle campo)
     :coleccion coleccion-objetivo
     :columnas columnas
     :fila-encabezado 3
     :fila-primera 4
     :capacidad (max 1 total-filas)
     :rango-nombrado nil)))

(defun planificar-detalle (a plan hoja-padre campo)
  "Arma la geometria de una relacion uno-a-muchos: un bloque de filas por
   cada fila de HOJA-PADRE, mas la tabla cruda de clave numerada que las
   alimenta."
  (declare (ignore a))
  (let* ((expr (nucleo:expresion campo))
         (coleccion-padre (coleccion hoja-padre))
         (filas-padre (nucleo:filas-de (entorno plan) (nucleo:nombre coleccion-padre)))
         (hoja-objetivo (hoja-de plan (nucleo:coleccion expr))))
    (unless hoja-objetivo
      (error "No hay hoja planificada para ~(~a~), la coleccion relacionada de ~(~a~)"
             (nucleo:coleccion expr) (nucleo:nombre campo)))
    (let ((bloques (loop for fila-padre in filas-padre
                         collect (cons (clave-de-fila coleccion-padre (entorno plan) fila-padre)
                                       (nucleo:evaluar-en-fila (entorno plan) fila-padre expr)))))
      (make-instance
       'hoja-de-detalle
       :campo campo
       :hoja-objetivo hoja-objetivo
       :tabla-cruda (construir-tabla-cruda campo hoja-objetivo bloques)
       :bloques bloques))))

(defun capacidad-de-detalle (a detalle)
  (declare (ignore detalle))
  (reserva-de-relacion a))

;;; ---------------------------------------------------------------------
;;; Direccionamiento propio de la tabla cruda
;;; ---------------------------------------------------------------------

(defun rango-de-tabla-cruda (tabla-cruda desde-columna)
  "El rectangulo que BUSCARV necesita dentro de la tabla cruda: desde
   DESDE-COLUMNA (indice de columna, empezando en cero) hasta la ultima de
   sus COLUMNAS, por todas sus filas.

   Analogo a RANGO-DE-TABLA (excel/formula.lisp), pero sobre las columnas
   propias de la tabla cruda en vez de los campos de una coleccion del
   nucleo: esta hoja no corresponde a ninguna coleccion declarada, es
   maquinaria que esta arquitectura se inventa."
  (let* ((primera (letra-de-columna desde-columna))
         (ultima (letra-de-columna (1- (length (columnas tabla-cruda))))))
    (format nil "~a!$~a$~d:$~a$~d"
            (entrecomillar (nombre tabla-cruda))
            primera (fila-primera tabla-cruda)
            ultima (fila-ultima tabla-cruda))))

(defun formula-de-detalle (tabla-cruda clave-numerada indice-objetivo)
  "BUSCARV con guarda de ausencia, sobre la clave numerada de la tabla
   cruda. INDICE-OBJETIVO es la posicion del campo (desde cero) dentro de
   los campos de la coleccion objetivo; en la tabla cruda va una columna mas
   a la derecha, porque la primera es __clave__."
  (format nil "IFERROR(VLOOKUP(~s,~a,~d,FALSE),\"\")"
          clave-numerada
          (rango-de-tabla-cruda tabla-cruda 0)
          (+ indice-objetivo 2)))

;;; ---------------------------------------------------------------------
;;; El bloque legible
;;; ---------------------------------------------------------------------

(defun filas-de-bloques-legibles (bloques capacidad fila-primera)
  "Geometria vertical de los bloques legibles: uno por fila padre, apilados
   sin hueco. Cada entrada es (CLAVE FILA-CABECERA . FILAS), donde
   FILA-CABECERA es la fila que lleva el texto de la clave y las
   CAPACIDAD lineas de busqueda empiezan justo debajo."
  (let ((fila fila-primera))
    (loop for (clave . filas) in bloques
          collect (prog1 (list* clave fila filas)
                    (incf fila (1+ capacidad))))))

(defun encabezados-de-tabla-cruda (tabla-cruda campos-objetivo fila-encabezado)
  (cons (list (cons "celda" (format nil "~a~d" (columna-de tabla-cruda "__clave__")
                                    fila-encabezado))
              (cons "campo" "__clave__")
              (cons "rol" "derivado")
              (cons "texto" "(clave)"))
        (loop for campo-obj in campos-objetivo
              collect (list (cons "celda" (format nil "~a~d"
                                                  (columna-de tabla-cruda (nucleo:nombre campo-obj))
                                                  fila-encabezado))
                            (cons "campo" (string-downcase (symbol-name (nucleo:nombre campo-obj))))
                            (cons "rol" "derivado")
                            (cons "texto" (nucleo:etiqueta campo-obj))))))

(defun encabezados-legibles (campos-objetivo col-legible fila-encabezado)
  (loop for campo-obj in campos-objetivo
        for i from col-legible
        collect (list (cons "celda" (format nil "~a~d" (letra-de-columna i) fila-encabezado))
                      (cons "campo" (string-downcase (symbol-name (nucleo:nombre campo-obj))))
                      (cons "rol" "derivado")
                      (cons "texto" (nucleo:etiqueta campo-obj)))))

(defun celdas-de-tabla-cruda (plan detalle campos-objetivo)
  "Los valores literales de la tabla cruda: una fila por cada par (padre,
   relacionada), con su clave numerada, en el mismo orden que los bloques."
  (let ((entorno (entorno plan))
        (tabla-cruda (tabla-cruda detalle))
        (resultado '())
        (fila (fila-primera (tabla-cruda detalle))))
    (dolist (bloque (bloques detalle))
      (destructuring-bind (clave-padre . filas-relacionadas) bloque
        (loop for fila-rel in filas-relacionadas
              for i from 1
              do (push (list (cons "celda" (format nil "~a~d"
                                                    (columna-de tabla-cruda "__clave__") fila))
                            (cons "valor" (format nil "~a#~d" clave-padre i)))
                       resultado)
                 (dolist (campo-obj campos-objetivo)
                   (push (list (cons "celda" (format nil "~a~d"
                                                     (columna-de tabla-cruda (nucleo:nombre campo-obj))
                                                     fila))
                              (cons "valor" (nucleo:valor-de-campo entorno fila-rel
                                                                   (nucleo:nombre campo-obj))))
                         resultado))
                 (incf fila))))
    (nreverse resultado)))

(defun celdas-de-cabeceras-legibles (bloques-legibles col-legible)
  "El texto de la clave del padre, en la cabecera de cada bloque legible."
  (loop for (clave fila-cabecera) in bloques-legibles
        collect (list (cons "celda" (format nil "~a~d" (letra-de-columna col-legible)
                                            fila-cabecera))
                      (cons "valor" clave))))

(defun celdas-de-avisos-legibles (bloques-legibles capacidad col-legible)
  "El aviso '(+N mas)' en la ultima linea reservada de un bloque que
   desborda la capacidad, en vez de una busqueda mas."
  (loop for (clave fila-cabecera . filas) in bloques-legibles
        when (> (length filas) capacidad)
          collect (list (cons "celda" (format nil "~a~d" (letra-de-columna col-legible)
                                              (+ fila-cabecera capacidad)))
                        (cons "valor" (format nil "(+~d mas)"
                                              (- (length filas) (1- capacidad)))))))

(defun formulas-legibles (tabla-cruda bloques-legibles capacidad col-legible campos-objetivo)
  "Las formulas BUSCARV de cada linea reservada del bloque legible, salvo la
   ultima cuando desborda: esa lleva el aviso de CELDAS-DE-AVISOS-LEGIBLES,
   no una busqueda mas."
  (loop for (clave fila-cabecera . filas) in bloques-legibles
        append (loop for i from 1 to capacidad
                     unless (and (= i capacidad) (> (length filas) capacidad))
                       append (loop for campo-obj in campos-objetivo
                                    for indice from 0
                                    for col from col-legible
                                    collect
                                    (list (cons "celda" (format nil "~a~d" (letra-de-columna col)
                                                                (+ fila-cabecera i)))
                                          (cons "formula"
                                                (format nil "=~a"
                                                        (formula-de-detalle
                                                         tabla-cruda
                                                         (format nil "~a#~d" clave i)
                                                         indice))))))))

(defun plano-de-detalle (a plan detalle)
  "El plano de la hoja auxiliar de una relacion: la tabla cruda de clave
   numerada y, junto a ella, un bloque legible apilado por cada fila padre.

   Analoga a PLANO-DE-HOJA, pero no la reutiliza: la tabla cruda no es una
   coleccion del lenguaje -es maquinaria que esta arquitectura se inventa- y
   el bloque legible no tiene equivalente en ninguna otra hoja del libro."
  (let* ((tabla-cruda (tabla-cruda detalle))
         (campos-objetivo (nucleo:campos (coleccion (hoja-objetivo detalle))))
         (n-objetivo (length campos-objetivo))
         ;; Columnas 0..n-objetivo son la tabla cruda (__clave__ + campos);
         ;; la columna n-objetivo+1 queda en blanco, como calle entre las dos
         ;; partes de la hoja; el bloque legible empieza en la siguiente.
         (col-legible (+ n-objetivo 2))
         (capacidad (capacidad-de-detalle a detalle))
         (fila-encabezado (fila-encabezado tabla-cruda))
         (fila-primera (fila-primera tabla-cruda))
         (bloques-legibles (filas-de-bloques-legibles (bloques detalle) capacidad fila-primera))
         (fila-final-legible (if bloques-legibles
                                 (+ (second (car (last bloques-legibles))) capacidad)
                                 (1- fila-primera)))
         (encabezados (append (encabezados-de-tabla-cruda tabla-cruda campos-objetivo fila-encabezado)
                              (encabezados-legibles campos-objetivo col-legible fila-encabezado)))
         (celdas (append (celdas-de-tabla-cruda plan detalle campos-objetivo)
                         (celdas-de-cabeceras-legibles bloques-legibles col-legible)
                         (celdas-de-avisos-legibles bloques-legibles capacidad col-legible)))
         (formulas (formulas-legibles tabla-cruda bloques-legibles capacidad
                                      col-legible campos-objetivo)))
    (list (cons "nombre" (nombre tabla-cruda))
          (cons "fila_encabezado" fila-encabezado)
          (cons "fila_primera" fila-primera)
          (cons "capacidad" (max (capacidad tabla-cruda) (1+ (- fila-final-legible fila-primera))))
          (cons "color_pestana" "A9D18E")
          (cons "encabezados" (lista encabezados))
          (cons "celdas" (lista celdas))
          (cons "formulas" (lista formulas))
          (cons "editables" :lista-vacia)
          (cons "validaciones" :lista-vacia)
          (cons "formatos_condicionales" :lista-vacia)
          (cons "rangos_nombrados" :lista-vacia)
          (cons "leyenda" :lista-vacia))))
