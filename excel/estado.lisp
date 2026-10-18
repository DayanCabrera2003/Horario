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

(defun explicacion-en-formula (a marca ambito plan)
  "El texto de la explicacion de MARCA en esta fila, como formula. Sin
   explicacion, el nombre de la marca. Si la explicacion no tiene
   traduccion, tambien el nombre, y el informe lo dice de esa marca."
  (let ((explicacion (nucleo:explicacion marca)))
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
                collect (format nil "IF(~a,\"; \"&~a,\"\")"
                                (condicion-excel a (nucleo:condicion marca) ambito plan)
                                (explicacion-en-formula a marca ambito plan)))))

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
