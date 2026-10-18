;;;; La columna de estado: el marcado textual en la hoja de calculo.
;;;;
;;;; Una marca declara un significado, y en esta arquitectura se realiza dos
;;;; veces: como relleno de color (formato condicional, en emision.lisp) y
;;;; como texto, en una columna detras de los campos que dice, fila a fila,
;;;; la explicacion de cada marca que dispara. Es el mismo texto que escriben
;;;; la pagina y el texto plano (NUCLEO:TEXTO-DE-ESTADO).
;;;;
;;;; Hasta el 2026-10-17 el informe de conformidad decia que esta
;;;; arquitectura cumplia el marcado textual, y en el libro no habia ni una
;;;; explicacion: solo una leyenda con el nombre de cada marca.

(in-package #:situacion.excel)

(defun rotulo-de-estado (coleccion)
  "\"Estado\", o \"Avisos\" si ya hay un campo con esa etiqueta."
  (if (find "Estado" (nucleo:campos coleccion) :key #'nucleo:etiqueta :test #'string-equal)
      "Avisos"
      "Estado"))

(defun encabezado-de-estado (hoja)
  "El encabezado de la columna de estado de HOJA, si la tiene."
  (when (columna-de-estado hoja)
    (list (list (cons "celda" (format nil "~a~d" (columna-de-estado hoja)
                                      (fila-encabezado hoja)))
                (cons "campo" "__estado__")
                (cons "rol" "derivado")
                (cons "texto" (rotulo-de-estado (coleccion hoja)))))))

(defun explicacion-en-formula (a marca ambito plan &optional campo)
  "El texto de la explicacion de MARCA en esta fila, como formula. Sin
   explicacion, el nombre de la marca. Si la explicacion no tiene
   traduccion, tambien el nombre, y el informe lo dice de esa marca. Para
   una marca :POR-CAMPO, la de CAMPO."
  (let ((explicacion (nucleo:explicacion marca))
        (*valores-de-marca* (if (and campo (nucleo:por-campo marca))
                                (acons (nucleo:por-campo marca) (celda *hoja* campo *fila*)
                                       *valores-de-marca*)
                                *valores-de-marca*)))
    (cond
      ((null explicacion) (cadena-excel (nucleo:nombre-legible-de-marca marca)))
      ((and (literal-p explicacion) (stringp (nucleo:valor explicacion)))
       (cadena-excel (nucleo:valor explicacion)))
      (t (handler-case
             (texto-de-presentacion (protocolo:emitir-expresion a explicacion ambito plan))
           (error (e)
             (protocolo:rebajar-en-informe
              'protocolo:con-marcado-textual
              (string-downcase (symbol-name (nucleo:nombre marca)))
              :degrada
              (format nil "la explicacion de ~(~a~) no tiene traduccion a formula~@
                           (~a); la columna de estado escribe su nombre"
                      (nucleo:nombre marca) e))
             (cadena-excel (nucleo:nombre-legible-de-marca marca))))))))

(defun formula-de-estado (a plan hoja marcas ambito)
  "El estado de la fila *FILA*: las explicaciones de las MARCAS que
   disparan, separadas por punto y coma. Se concatenan todas con su
   separador delante y se quita el primero con EXTRAE."
  (format nil "MID(~{~a~^&~},3,32767)"
          (loop for marca in marcas
                ;; Una marca :POR-CAMPO da un termino por campo, en el orden de
                ;; su :SOBRE, como NUCLEO:TEXTO-DE-ESTADO (fase 2, hueco C7).
                append (loop for campo in (if (nucleo:por-campo marca)
                                              (nucleo:alcance marca)
                                              (list nil))
                             collect (format nil "IF(~a,\"; \"&~a,\"\")"
                                             (condicion-de-marca a marca ambito plan campo)
                                             (explicacion-en-formula a marca ambito plan
                                                                     campo))))))

(defun formulas-de-estado (a plan hoja)
  "La columna de estado de HOJA, fila por fila, incluidas las de reserva."
  (when (columna-de-estado hoja)
    (let* ((coleccion (coleccion hoja))
           (ambito (ambito-de coleccion))
           (marcas (remove-if-not (lambda (m) (marca-de-esta-hoja-p m coleccion))
                                  (nucleo:marcas (situacion plan)))))
      (loop for i from 0 below (capacidad hoja)
            collect (let ((*fila* (+ (fila-primera hoja) i))
                          (*hoja* hoja))
                      (list (cons "celda" (format nil "~a~d" (columna-de-estado hoja) *fila*))
                            (cons "formula"
                                  (format nil "=~a"
                                          (con-guarda-de-fila
                                           a coleccion hoja ambito plan
                                           (formula-de-estado a plan hoja marcas
                                                              ambito))))))))))

;;; ---------------------------------------------------------------------
;;; El nivel de cada fila, para las rejillas
;;; ---------------------------------------------------------------------

(defparameter +niveles+ '((:problema . 3) (:advertencia . 2) (:informativa . 1))
  "De severidad a numero, para quedarse con la mas grave.")

(defun formula-de-nivel (a plan marcas ambito)
  "La severidad mas alta de las MARCAS que disparan en la fila *FILA*, como
   numero: 3 problema, 2 advertencia, 1 informativa, 0 ninguna."
  (let ((ramas (loop for (severidad . numero) in +niveles+
                     for suyas = (remove severidad marcas :key #'nucleo:severidad
                                                          :test-not #'eq)
                     when suyas
                       collect (cons numero
                                     (format nil "OR(~{~a~^,~})"
                                             (mapcar (lambda (m)
                                                       (condicion-de-marca-en-fila
                                                        a m ambito plan))
                                                     suyas))))))
    (reduce (lambda (rama resto) (format nil "IF(~a,~d,~a)" (cdr rama) (car rama) resto))
            ramas :from-end t :initial-value "0")))

(defun encabezado-de-nivel (hoja)
  "El encabezado de la columna oculta de nivel de HOJA, si la tiene."
  (when (columna-de-nivel hoja)
    (list (list (cons "celda" (format nil "~a~d" (columna-de-nivel hoja)
                                      (fila-encabezado hoja)))
                (cons "campo" "__nivel__")
                (cons "rol" "derivado")
                (cons "texto" "(nivel de las marcas)")))))

(defun formulas-de-nivel (a plan hoja)
  "La columna oculta de nivel de HOJA, fila por fila."
  (when (columna-de-nivel hoja)
    (let* ((coleccion (coleccion hoja))
           (ambito (ambito-de coleccion))
           (marcas (remove-if-not (lambda (m) (marca-de-esta-hoja-p m coleccion))
                                  (nucleo:marcas (situacion plan)))))
      (loop for i from 0 below (capacidad hoja)
            collect (let ((*fila* (+ (fila-primera hoja) i))
                          (*hoja* hoja))
                      (list (cons "celda" (format nil "~a~d" (columna-de-nivel hoja) *fila*))
                            (cons "formula"
                                  (format nil "=~a"
                                          (handler-case (formula-de-nivel a plan marcas ambito)
                                            (error () "0"))))))))))
