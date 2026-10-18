;;;; Los nombres de las pestanas y como se citan en una formula.
;;;;
;;;; UN SOLO SITIO DECIDE EL NOMBRE DE CADA PESTANA, Y UNA SOLA VEZ
;;;;
;;;; Excel no admite nombres de hoja de mas de 31 caracteres, ni con los signos
;;;; [ ] : * ? / \, ni que empiecen o acaben por apostrofo, ni dos iguales sin
;;;; distinguir mayusculas. Antes esto se resolvia en dos sitios: aqui, para
;;;; las pestanas de las tablas cruzadas, y en el materializador de Python,
;;;; que recortaba los demas nombres al crear el archivo. Las formulas y los
;;;; rangos con nombre seguian citando el nombre largo, y una pestana del
;;;; Saul Delgado ("Dias que asisten los contratados", 32 caracteres) dejaba
;;;; todas sus busquedas apuntando a una hoja que no existia, tapadas por un
;;;; SI.ERROR.
;;;;
;;;; Ahora ASIGNAR-NOMBRES-DE-HOJA fija el nombre definitivo de cada hoja del
;;;; libro antes de emitir ninguna formula, y ese es el nombre que llevan el
;;;; plano, las formulas y los rangos. El materializador no renombra nada.
;;;;
;;;; ESQUEMA DE LAS PESTANAS DE UNA VISTA PARTIDA
;;;;
;;;; Todas las pestanas de una misma vista se nombran igual, para que se lean
;;;; como una familia. Se elige la primera forma en que caben TODAS:
;;;;
;;;;   1. "<etiqueta de la vista> - <seccion>"      Horario del grupo - 10-3
;;;;   2. "<iniciales de la vista> - <seccion>"     HP - Profesor de M en 10-3
;;;;   3. "<seccion>"                               Profesor de Matematica en 10-3
;;;;   4. la seccion recortada, y " (2)" si se repite.
;;;;
;;;; El titulo completo va siempre en la primera celda de la hoja.

(in-package #:situacion.excel)

(defconstant +largo-de-pestana+ 31
  "Excel no admite nombres de hoja de mas de 31 caracteres.")

(defparameter +palabras-vacias+
  '("de" "del" "la" "las" "el" "los" "y" "e" "en" "por" "a" "al" "para" "con")
  "Palabras que no cuentan para las iniciales de una etiqueta.")

(defun recortar (texto largo)
  (if (> (length texto) largo) (subseq texto 0 largo) texto))

(defun sin-signos-prohibidos (texto)
  "TEXTO sin los signos que Excel no admite en un nombre de hoja, sin
   apostrofos ni espacios en los extremos."
  (string-trim "' " (remove-if (lambda (c) (find c "[]:*?/\\")) texto)))

(defun nombre-valido (texto)
  "TEXTO convertido en un nombre de hoja admisible, aunque quiza repetido."
  (let ((limpio (string-trim "' " (recortar (sin-signos-prohibidos texto)
                                            +largo-de-pestana+))))
    (if (string= limpio "") "Hoja" limpio)))

(defun entrecomillar (nombre)
  "NOMBRE de hoja tal como se cita en una formula: siempre entre apostrofos,
   con los apostrofos de dentro duplicados.

   Antes solo se entrecomillaba si tenia espacios. Una etiqueta como
   \"Compra-2026\" -sin espacios, con guion- se leia como una resta y todas
   las formulas que la citaban daban #VALUE!; una con apostrofo, como
   \"Catalogo d'articulos\", daba #NAME?."
  (with-output-to-string (s)
    (write-char #\' s)
    (loop for c across nombre
          do (when (char= c #\') (write-char #\' s))
             (write-char c s))
    (write-char #\' s)))

(defun iniciales (etiqueta)
  "Las iniciales de las palabras con significado de ETIQUETA, en mayusculas:
   \"Horario del profesor\" da \"HP\"."
  (let ((palabras (loop with inicio = 0
                        for fin = (position #\Space etiqueta :start inicio)
                        collect (subseq etiqueta inicio (or fin (length etiqueta)))
                        while fin
                        do (setf inicio (1+ fin)))))
    (string-upcase
     (coerce (loop for p in palabras
                   when (and (plusp (length p))
                             (not (member p +palabras-vacias+ :test #'string-equal))
                             (alphanumericp (char p 0)))
                     collect (char p 0))
             'string))))

(defun nombres-de-una-vista (etiqueta secciones)
  "Los nombres de las pestanas de una vista partida, uno por seccion, con el
   mismo esquema para todas (ver la cabecera de este archivo)."
  (let* ((etiqueta (sin-signos-prohibidos etiqueta))
         (textos (mapcar (lambda (s) (sin-signos-prohibidos (nucleo:como-texto s)))
                         secciones))
         (iniciales (iniciales etiqueta)))
    (flet ((todas-caben (prefijo)
             (every (lambda (texto)
                      (<= (+ (length prefijo) (if (string= prefijo "") 0 3)
                             (length texto))
                          +largo-de-pestana+))
                    textos))
           (con-prefijo (prefijo)
             (mapcar (lambda (texto)
                       (if (string= prefijo "") texto (format nil "~a - ~a" prefijo texto)))
                     textos)))
      (cond ((todas-caben etiqueta) (con-prefijo etiqueta))
            ((and (plusp (length iniciales)) (todas-caben iniciales))
             (con-prefijo iniciales))
            ((todas-caben "") (con-prefijo ""))
            (t (mapcar #'nombre-valido textos))))))

(defun nombre-de-pestana (etiqueta seccion)
  "El nombre de la pestana de un cruce suelto, con su seccion si la tiene.
   Para las pestanas de un libro se usa ASIGNAR-NOMBRES-DE-HOJA, que ademas
   las hace unicas; esta sirve a los archivos de una sola pestana."
  (nombre-valido (if seccion
                     (first (nombres-de-una-vista etiqueta (list seccion)))
                     etiqueta)))

(defun unico (nombre usados)
  "NOMBRE cambiado lo justo para no coincidir, sin distinguir mayusculas, con
   ninguno de USADOS ni con \"History\", que Excel reserva."
  (let ((elegido nombre))
    (loop for n from 2
          while (or (member elegido usados :test #'string-equal)
                    (string-equal elegido "History"))
          do (let ((sufijo (format nil " (~d)" n)))
               (setf elegido (concatenate 'string
                                          (string-right-trim
                                           " " (recortar nombre (- +largo-de-pestana+
                                                                   (length sufijo))))
                                          sufijo))))
    elegido))

(defun asignar-nombres-de-hoja (plan)
  "Fija el nombre definitivo de cada hoja del libro: las de datos primero,
   que son las que mas se citan, luego las auxiliares y por ultimo las
   pestanas de las tablas cruzadas. Cada nombre es valido y distinto de todos
   los anteriores."
  (let ((usados '()))
    (flet ((tomar (texto)
             (let ((nombre (unico (nombre-valido texto) usados)))
               (push nombre usados)
               nombre)))
      ;; La hoja de datos lleva la etiqueta de su vista de datos, como la
      ;; tabla que dibujan el texto y la pagina; sin vista de lista, la de
      ;; la coleccion.
      (dolist (hoja (hojas plan))
        (let ((vista (nucleo:vista-de-datos (situacion plan)
                                            (nucleo:nombre (coleccion hoja)))))
          (setf (titulo hoja) (if vista (nucleo:etiqueta vista)
                                  (nucleo:etiqueta (coleccion hoja)))
                (nombre hoja) (tomar (titulo hoja)))))
      (dolist (derivada (vistas-derivadas plan))
        (setf (titulo derivada) (nucleo:etiqueta (vista derivada))
              (nombre derivada) (tomar (titulo derivada))))
      (when (necesita-listas-p plan)
        (setf (nombre-de-listas plan) (tomar "Listas")))
      (dolist (detalle (auxiliares plan))
        (let ((tabla (tabla-cruda detalle)))
          (setf (titulo tabla) (titulo-de-detalle (campo detalle))
                (nombre tabla) (tomar (titulo tabla)))))
      ;; Las pestanas de una vista se nombran juntas, para que compartan
      ;; esquema; despues cada una se hace unica.
      (let ((por-vista '()))
        (dolist (cruce (cruces plan))
          (let ((par (assoc (vista cruce) por-vista)))
            (if par (push cruce (cdr par)) (push (list (vista cruce) cruce) por-vista))))
        (dolist (par (reverse por-vista))
          (let* ((vista (car par))
                 (suyos (reverse (cdr par))))
            (if (seccion (first suyos))
                (loop for cruce in suyos
                      for nombre in (nombres-de-una-vista (nucleo:etiqueta vista)
                                                          (mapcar #'seccion suyos))
                      do (setf (titulo cruce) (format nil "~a - ~a" (nucleo:etiqueta vista)
                                                      (nucleo:como-texto (seccion cruce)))
                               (nombre cruce) (tomar nombre)))
                (dolist (cruce suyos)
                  (setf (titulo cruce) (nucleo:etiqueta vista)
                        (nombre cruce) (tomar (nucleo:etiqueta vista)))))))))
    plan))
