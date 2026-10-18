;;;; La presentacion del libro: anchos, impresion, colores y columnas ocultas.
;;;;
;;;; Nada de esto cambia un valor; cambia como se lee el libro. La auditoria
;;;; del 2026-10-17 encontro que los anchos se median sobre el texto de las
;;;; formulas (toda columna calculada salia a 42, aunque valiera "no"), que el
;;;; horario del Saul se imprimia en 91 paginas, con un dia por pagina, que
;;;; siete marcas distintas compartian el mismo rosa sin que la leyenda
;;;; dijera cual era cual, y que las columnas de clave se veian en la hoja de
;;;; datos.

(in-package #:situacion.excel)

(defparameter +ancho-minimo+ 6 "Ancho minimo de una columna, en caracteres.")
(defparameter +ancho-maximo+ 40 "Ancho maximo de una columna, en caracteres.")

(defun ancho-para (textos)
  "El ancho de una columna que tiene que ensenar TEXTOS: el del mas largo,
   con un poco de aire, entre el minimo y el maximo."
  (min +ancho-maximo+
       (max +ancho-minimo+
            (+ 2 (reduce #'max (mapcar #'length textos) :initial-value 0)))))

(defun anchos-de-hoja (plan hoja)
  "El ancho de cada columna de la hoja de datos de HOJA, medido sobre su
   etiqueta y los valores que calcula el evaluador para cada fila, no sobre
   el texto de las formulas."
  (let* ((entorno (entorno plan))
         (coleccion (coleccion hoja))
         (filas (nucleo:filas-de entorno (nucleo:nombre coleccion))))
    (append
     (loop for campo in (nucleo:campos coleccion)
           collect (cons (columna-de hoja (nucleo:nombre campo))
                         (ancho-para (cons (nucleo:etiqueta campo)
                                           (mapcar (lambda (f)
                                                     (texto-de-celda
                                                      (nucleo:valor-de-campo
                                                       entorno f (nucleo:nombre campo))))
                                                   filas)))))
     (when (columna-de-estado hoja)
       (list (cons (columna-de-estado hoja)
                   (ancho-para (cons (rotulo-de-estado coleccion)
                                     (mapcar (lambda (f) (nucleo:texto-de-estado entorno f))
                                             filas)))))))))

(defun texto-de-celda (valor)
  "VALOR como se ve en una celda: una relacion se ve como su conteo."
  (if (and (consp valor) (typep (first valor) 'nucleo:fila))
      (format nil "~d" (length valor))
      (nucleo:como-texto valor)))

(defun anchos-de-cruce (plan cruce)
  "El ancho de cada columna de una pestana cruzada: el eje de filas y una
   columna por valor del eje de columnas, medidas sobre lo que ensenan."
  (let* ((entorno (entorno plan))
         (vista (vista cruce))
         (filas (filas-de-la-seccion plan vista (seccion cruce)))
         (campo (nucleo:lo-que-se-muestra vista)))
    (cons (cons "A" (ancho-para (cons (nucleo:como-texto (nucleo:eje-de-filas vista))
                                      (mapcar #'nucleo:como-texto (valores-de-fila cruce)))))
          (loop for vc in (valores-de-columna cruce)
                for i from 1
                collect (cons (letra-de-columna i)
                              (ancho-para
                               (cons (nucleo:como-texto vc)
                                     (loop for f in filas
                                           when (nucleo:iguales-p
                                                 vc (nucleo:valor-de-campo
                                                     entorno f (nucleo:eje-de-columnas vista)))
                                             collect (format nil "~a~:[~; (+1)~]"
                                                             (nucleo:como-texto
                                                              (nucleo:valor-de-campo
                                                               entorno f campo))
                                                             ;; Con conflicto declarado,
                                                             ;; la casilla puede decir
                                                             ;; cuantas mas hay.
                                                             (nucleo:conflicto vista))))))))))

(defun columnas-ocultas (hoja)
  "Las columnas auxiliares de HOJA, que no son para leer: las de clave
   compuesta y las de primera aparicion."
  (append (when (columna-de-nivel hoja) (list (columna-de-nivel hoja)))
          (mapcar #'letra (claves hoja))
          (mapcar #'letra (distintos hoja))))

(defun impresion (horizontal)
  "Como se imprime una hoja: ajustada a una pagina de ancho, y apaisada si
   HORIZONTAL. Una rejilla de cinco dias tiene que caber en una hoja."
  (list (cons "horizontal" (if horizontal t :false))
        (cons "ajustar_ancho" t)))

;;; ---------------------------------------------------------------------
;;; Colores de las marcas
;;; ---------------------------------------------------------------------

(defparameter +tonos+
  '((:problema    "FFC7CE" "F4B183" "F8CBAD" "E6B8B7" "FF9999" "F2A2A2" "FCD5B4"
                  "E59C9C" "FFB3C6" "D99594")
    (:advertencia "FFEB9C" "FFE699" "FFD966" "FCE4D6" "FFF2CC" "F9E79F" "FAD7A0"
                  "FFE5B4" "EEDC82" "F7DC6F")
    (:informativa "DDEBF7" "BDD7EE" "E2EFDA" "D9E1F2" "C6E0B4" "D5E8D4" "DAE8FC"
                  "E1D5E7" "CCE5FF" "D4EFDF"))
  "Los tonos de cada severidad. La primera marca de una severidad lleva el
   primero, la segunda el segundo, y asi. Antes todas las de una severidad
   compartian uno, y la leyenda no dejaba saber cual habia disparado.

   Es una opcion de esta arquitectura, no del lenguaje. La marca declara un
   significado y una severidad; que el problema se vea rojo es una decision
   de como se pinta una hoja de calculo, y otra arquitectura puede decidir
   otra cosa sin tocar ninguna descripcion. Que este aqui y no en el nodo de
   la marca es la correccion del hallazgo sobre 2026: alli la definicion 3.8
   decia que la regla tenia color, el nodo no lo tenia, y el backend lo
   asignaba por orden de aparicion.")

(defun relleno-de-severidad (severidad)
  "El tono base de SEVERIDAD: el que pinta una casilla de una rejilla cuya
   fila tiene alguna marca de esa severidad."
  (or (second (assoc severidad +tonos+)) "EEEEEE"))

(defun relleno-de-marca (plan marca)
  "El relleno de MARCA: un tono de su severidad, distinto para cada marca de
   esa severidad en la misma coleccion, que es lo que comparte una leyenda."
  (let* ((severidad (nucleo:severidad marca))
         (tonos (or (rest (assoc severidad +tonos+)) (list "EEEEEE")))
         (coleccion (coleccion-de-marca plan marca))
         (iguales (remove-if-not (lambda (m) (and (eq (nucleo:severidad m) severidad)
                                                  (eq (coleccion-de-marca plan m) coleccion)))
                                 (nucleo:marcas (situacion plan))))
         (posicion (or (position marca iguales) 0)))
    (nth (mod posicion (length tonos)) tonos)))

(defun coleccion-de-marca (plan marca)
  "La coleccion que senala MARCA."
  (find-if (lambda (c) (marca-de-esta-hoja-p marca c))
           (nucleo:colecciones (situacion plan))))

(defun texto-de-leyenda (marca)
  "Lo que dice la leyenda de MARCA: su explicacion si es un texto escrito,
   y si no su nombre."
  (let ((e (nucleo:explicacion marca)))
    (if (and e (typep e 'nucleo:literal) (stringp (nucleo:valor e)))
        (nucleo:valor e)
        (nucleo:nombre-legible-de-marca marca))))
