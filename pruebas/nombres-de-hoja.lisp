;;;; Pruebas de los nombres de hoja.
;;;;
;;;; El nombre de cada pestana lo decide la arquitectura de Excel una sola vez
;;;; (excel/nombres.lisp), y es el que citan las formulas y los rangos con
;;;; nombre. La auditoria del 2026-10-17 encontro tres formas de romperlo:
;;;; una etiqueta de mas de 31 caracteres (el materializador la recortaba y
;;;; las formulas seguian citando la larga), una etiqueta con guion y sin
;;;; espacios (se citaba sin comillas y se leia como una resta) y una con
;;;; apostrofo (se citaba sin duplicarlo).

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion nombres-dificiles (:etiqueta "Nombres dificiles")
  (coleccion articulos
    (:etiqueta "Catálogo d'artículos")
    (:clave codigo)
    (campo codigo :rol fijo :etiqueta "Codigo")
    (campo total :rol derivado :tipo entero :etiqueta "Total"
           (suma cantidad de compras :donde (= codigo (de fila codigo))))
    (campo norte :rol derivado :tipo entero :etiqueta "Norte"
           (suma unidades de norte :donde (= codigo (de fila codigo))))
    (campo raros :rol derivado :tipo entero :etiqueta "Raros"
           (cuantas raros :donde (= codigo (de fila codigo)))))
  (coleccion compras
    (:etiqueta "Compra-2026")
    (:clave numero)
    (campo numero :rol fijo :etiqueta "No.")
    (campo codigo :rol fijo :etiqueta "Codigo")
    (campo cantidad :rol fijo :tipo entero :etiqueta "Cantidad"))
  (coleccion central
    (:etiqueta "Existencias registradas en el almacén central")
    (:clave codigo)
    (campo codigo :rol fijo :etiqueta "Codigo")
    (campo nombre :rol derivado :etiqueta "Nombre"
           (el codigo de (la-fila-de articulos :donde (= codigo (de fila codigo)))
               :si-no "")))
  (coleccion norte
    (:etiqueta "Existencias registradas en el almacén norte")
    (:clave codigo)
    (campo codigo :rol fijo :etiqueta "Codigo")
    (campo unidades :rol fijo :tipo entero :etiqueta "Unidades"))
  (coleccion raros
    (:etiqueta "Signos [raros] / prohibidos: *?")
    (:clave codigo)
    (campo codigo :rol fijo :etiqueta "Codigo"))
  (vista v :de articulos :etiqueta "Articulos"))

(defparameter *datos-nombres-dificiles*
  (list (cons (nucleo:nombrar "articulos")
              (list (list (cons (nucleo:nombrar "codigo") "T-01"))))
        (cons (nucleo:nombrar "compras")
              (list (list (cons (nucleo:nombrar "numero") 1)
                          (cons (nucleo:nombrar "codigo") "T-01")
                          (cons (nucleo:nombrar "cantidad") 3))))
        (cons (nucleo:nombrar "central")
              (list (list (cons (nucleo:nombrar "codigo") "T-01"))))
        (cons (nucleo:nombrar "norte")
              (list (list (cons (nucleo:nombrar "codigo") "T-01")
                          (cons (nucleo:nombrar "unidades") 2))))
        (cons (nucleo:nombrar "raros")
              (list (list (cons (nucleo:nombrar "codigo") "T-01"))))))

(defun nombre-de-hoja-admisible-p (nombre)
  (and (plusp (length nombre))
       (<= (length nombre) 31)
       (not (find-if (lambda (c) (find c "[]:*?/\\")) nombre))
       (char/= (char nombre 0) #\')
       (char/= (char nombre (1- (length nombre))) #\')))

(defun hojas-citadas (formula)
  "Los nombres de hoja que cita FORMULA, leidos como los lee la hoja de
   calculo: entre apostrofos, con los apostrofos de dentro duplicados, y
   seguidos de un signo de admiracion."
  (let ((citadas '()) (i 0) (n (length formula)))
    (loop while (< i n)
          do (if (char= (char formula i) #\')
                 (let ((nombre (make-string-output-stream)) (j (1+ i)))
                   (loop while (< j n)
                         do (cond ((and (char= (char formula j) #\')
                                        (< (1+ j) n) (char= (char formula (1+ j)) #\'))
                                   (write-char #\' nombre) (incf j 2))
                                  ((char= (char formula j) #\') (return))
                                  (t (write-char (char formula j) nombre) (incf j))))
                   (when (and (< (1+ j) n) (char= (char formula (1+ j)) #\!))
                     (push (get-output-stream-string nombre) citadas))
                   (setf i (1+ j)))
                 (incf i)))
    citadas))

(definir-prueba nombres-de-hoja-validos-y-unicos
    "Nombres de hoja: todos admisibles y distintos, sin distinguir mayusculas"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "NOMBRES-DIFICILES")
                          *datos-nombres-dificiles*))
         (nombres (mapcar (lambda (h) (dato h "nombre")) (hojas-del-plano plano))))
    (dolist (nombre nombres)
      (comprobar (nombre-de-hoja-admisible-p nombre)
                 "el nombre de hoja ~s no lo admite el formato" nombre))
    (comprobar (= (length nombres)
                  (length (remove-duplicates nombres :test #'string-equal)))
               "hay nombres de hoja repetidos: ~s" nombres)))

(definir-prueba nombres-de-hoja-las-formulas-citan-hojas-que-existen
    "Nombres de hoja: cada hoja que cita una formula o un rango existe en el plano"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "NOMBRES-DIFICILES")
                          *datos-nombres-dificiles*))
         (nombres (mapcar (lambda (h) (dato h "nombre")) (hojas-del-plano plano))))
    (dolist (hoja (hojas-del-plano plano))
      (dolist (texto (append (mapcar (lambda (f) (dato f "formula"))
                                     (lista-del-plano (dato hoja "formulas")))
                             (mapcar (lambda (r) (dato r "referencia"))
                                     (lista-del-plano (dato hoja "rangos_nombrados")))))
        (dolist (citada (hojas-citadas texto))
          (comprobar (member citada nombres :test #'string=)
                     "~a cita la hoja ~s, que no existe" (dato hoja "nombre") citada))))))

(definir-prueba nombres-de-hoja-siempre-entre-apostrofos
    "Nombres de hoja: una referencia a otra hoja va entre apostrofos aunque no tenga espacios"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "NOMBRES-DIFICILES")
                          *datos-nombres-dificiles*))
         (formula (formula-de-celda (hoja-de-coleccion plano "articulos") "B4")))
    (comprobar (and formula (search "'Compra-2026'!" formula))
               "la suma de COMPRAS tiene que citar 'Compra-2026'!: ~a" formula)))

(definir-prueba nombres-de-hoja-una-vista-comparte-esquema
    "Nombres de hoja: las pestanas de una vista partida se nombran todas igual"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                          situacion.corpus:datos-del-saul))
         (de-profesor (remove-if-not
                       (lambda (h) (equal (dato (dato h "cruce") "vista") "por-profesor"))
                       (hojas-del-plano plano))))
    (comprobar (= 30 (length de-profesor)) "el Saul tiene 30 pestanas de profesor")
    (dolist (hoja de-profesor)
      (comprobar (eql 0 (search "HP - " (dato hoja "nombre")))
                 "la pestana ~s no sigue el esquema de su vista" (dato hoja "nombre"))
      (comprobar (search (dato (dato hoja "cruce") "seccion") (dato hoja "titulo"))
                 "el titulo de ~s tiene que llevar la seccion entera" (dato hoja "nombre")))))
