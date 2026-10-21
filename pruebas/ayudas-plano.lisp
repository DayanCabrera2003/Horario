;;;; Ayudas para mirar el plano de libro desde las pruebas.
;;;;
;;;; El plano es la estructura nativa que devuelve CONSTRUIR-PLANO, antes de
;;;; serializarla a JSON: listas asociativas con cadenas como claves. Estas
;;;; funciones lo recorren sin repetir el mismo ASSOC en cada prueba.

(in-package #:situacion.pruebas)

(defun dato (alista clave)
  "El valor de CLAVE en una lista asociativa del plano, o NIL."
  (cdr (assoc clave alista :test #'string=)))

(defun lista-del-plano (valor)
  "VALOR como lista: el plano marca con :LISTA-VACIA las listas sin elementos."
  (if (eq valor :lista-vacia) '() valor))

(defun plano-de (situacion datos &rest argumentos-de-excel)
  "El plano nativo de SITUACION con DATOS. ARGUMENTOS-DE-EXCEL se pasan a
   HACER-EXCEL tal cual."
  (let* ((a (apply #'situacion.excel:hacer-excel argumentos-de-excel))
         (plan (protocolo:planificar a situacion)))
    (setf (situacion.excel::entorno plan) (nucleo:hacer-entorno situacion datos))
    (protocolo:con-informe (a)
      (situacion.excel::construir-plano a plan))))

(defun hojas-del-plano (plano)
  (lista-del-plano (dato plano "hojas")))

(defun hoja-llamada (plano nombre)
  "La hoja del plano cuyo nombre es NOMBRE, o NIL."
  (find nombre (hojas-del-plano plano)
        :key (lambda (h) (dato h "nombre")) :test #'string=))

(defun hoja-de-coleccion (plano coleccion)
  "La hoja de datos de COLECCION (una cadena en minusculas), o NIL."
  (find coleccion (hojas-del-plano plano)
        :key (lambda (h) (dato h "coleccion")) :test #'equal))

(defun formula-de-celda (hoja celda)
  "La formula de CELDA en HOJA (una hoja del plano), o NIL."
  (let ((entrada (find celda (lista-del-plano (dato hoja "formulas"))
                       :key (lambda (f) (dato f "celda")) :test #'string=)))
    (and entrada (dato entrada "formula"))))

(defun celda-de-campo (hoja campo fila)
  "La celda de CAMPO (una cadena) en la fila FILA de HOJA (una hoja del
   plano), buscando su columna por el encabezado: asi una prueba no se rompe
   si la descripcion gana o pierde un campo antes que el."
  (let ((encabezado (find campo (lista-del-plano (dato hoja "encabezados"))
                          :key (lambda (e) (dato e "campo")) :test #'string=)))
    (and encabezado
         (format nil "~a~d" (remove-if #'digit-char-p (dato encabezado "celda")) fila))))

(defun texto-de-archivo (ruta)
  "El contenido entero de RUTA como cadena, leido en UTF-8."
  (with-open-file (f ruta :external-format :utf-8)
    (let ((s (make-string (file-length f))))
      (subseq s 0 (read-sequence s f)))))

;;; Planos y datos que comparten varios archivos de pruebas.

(defun datos-del-caso (nombre)
  "Los datos de un caso de pruebas/casos/, por el nombre de su variable."
  (symbol-value (find-symbol nombre '#:situacion.casos)))

(defun plano-de-notas ()
  "El plano del caso de las notas, que tiene un parametro de entrada y uno
   fijo, y una marca sin leyenda."
  (plano-de (situacion.lenguaje:situacion-llamada "CASO-NOTAS")
            (datos-del-caso "DATOS-DE-NOTAS")))

(defun plano-del-saul ()
  "El plano del horario del Saul con sus datos reales."
  (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
            situacion.corpus:datos-del-saul))
