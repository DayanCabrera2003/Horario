;;;; La rejilla de entrada: cuando la tabla cruzada es donde se escribe.
;;;;
;;;; Una vista cruzada con :ENTRADA T dice que la rejilla es el punto de
;;;; entrada. La pagina lo cumple sin mas: deja escribir en la casilla, y la
;;;; tabla y la rejilla se avisan entre si. Una hoja de calculo no puede: la
;;;; casilla era una formula que buscaba en la hoja de datos, y una celda es
;;;; o formula o dato. Hasta el 2026-10-21 la rejilla salia bloqueada y para
;;;; cambiar un turno del Saul habia que buscar la fila entre setenta en
;;;; "Casillas del horario".
;;;;
;;;; La solucion es dar la vuelta al espejo: la rejilla lleva el dato y es
;;;; editable, y la columna de la hoja de datos pasa a ser una formula que lo
;;;; lee de su casilla. Todo lo demas -las otras rejillas, las marcas, los
;;;; colores- sigue leyendo la hoja de datos y no se entera del cambio.
;;;;
;;;; Solo se puede si cada fila tiene exactamente una casilla y cada casilla
;;;; es exactamente una fila; si no, la rejilla sale como antes, de solo
;;;; lectura, y el informe dice por que. Diseno en
;;;; documentacion/2026-10-21-rejilla-de-entrada-diseno.md (fuera del repo).

(in-package #:situacion.excel)

(defparameter +fila-primera-de-rejilla+ 4
  "La fila de la primera casilla de toda tabla cruzada. Por encima van el
   titulo y la fila del eje de columnas.")

(defun campos-de-la-casilla (vista)
  "Los campos que fijan una casilla de VISTA: seccion, fila y columna."
  (remove nil (list (nucleo:secciones vista)
                    (nucleo:eje-de-filas vista)
                    (nucleo:eje-de-columnas vista))))

(defun motivo-sin-rejilla-de-entrada (a plan vista)
  "NIL si la rejilla de VISTA puede ser donde se escribe; si no, por que no.

   Solo se pregunta por las vistas cruzadas declaradas de entrada."
  (let* ((coleccion (nucleo:coleccion-llamada (situacion plan) (nucleo:fuente vista)))
         (campo (and coleccion (nucleo:campo-llamado coleccion
                                                     (nucleo:lo-que-se-muestra vista)))))
    (cond ((member (nucleo:nombre vista) (vistas-en-archivo a))
           "sale en archivos aparte, que no se pueden leer desde el libro")
          ((not (and campo (eq (nucleo:rol campo) :entrada)))
           "lo que ensena la casilla no es un campo de entrada")
          ;; Cada casilla, una fila: la clave son justo los ejes.
          ((not (and (= (length (nucleo:clave coleccion))
                        (length (campos-de-la-casilla vista)))
                     (subsetp (nucleo:clave coleccion) (campos-de-la-casilla vista))))
           "una casilla puede tener varias filas: la clave de la coleccion no son sus ejes")
          ;; Cada fila, una casilla. Una fila nueva no tendria casilla en una
          ;; rejilla fijada al generar, y una que el filtro deja fuera
          ;; tampoco.
          ((eq (nucleo:crecimiento coleccion) :crece)
           "la coleccion crece, y una fila nueva no tendria casilla")
          ((nucleo:filtro vista)
           "la vista filtra filas, y las que deja fuera no tendrian casilla"))))

(defun planificar-rejillas-de-entrada (a plan)
  "Decide que vistas cruzadas de entrada llevan el dato en la rejilla y lo
   anota en el informe, con el motivo cuando no se puede."
  (dolist (vista (nucleo:vistas (situacion plan)))
    (when (and (nucleo:es-entrada vista) (nucleo:cruzada-p vista))
      (let ((motivo (motivo-sin-rejilla-de-entrada a plan vista)))
        (if motivo
            (protocolo:anotar-en-informe
             :degrada 'protocolo:con-entrada
             (format nil "la rejilla ~a es de solo lectura: ~a; se escribe en la hoja de datos"
                     (nucleo:etiqueta vista) motivo))
            (progn
              (push vista (rejillas-de-entrada plan))
              (protocolo:anotar-en-informe
               :emula 'protocolo:con-entrada
               (format nil "en la rejilla ~a se escribe y la hoja de datos copia de ella:~@
                            una celda es formula o dato, no las dos. Limite: esa columna~@
                            de la hoja de datos deja de poder escribirse."
                       (nucleo:etiqueta vista))))))))
  (setf (rejillas-de-entrada plan) (nreverse (rejillas-de-entrada plan))))

(defun rejilla-de-entrada-p (plan cruce)
  "Cierto si CRUCE es una pestana de una rejilla donde se escribe."
  (and (member (vista cruce) (rejillas-de-entrada plan)) t))

(defun rejilla-que-escribe (plan hoja campo)
  "La vista cuya rejilla escribe CAMPO de HOJA, o NIL si se escribe en HOJA."
  (find-if (lambda (vista)
             (and (eq (nucleo:fuente vista) (nucleo:nombre (coleccion hoja)))
                  (eq (nucleo:lo-que-se-muestra vista) campo)))
           (rejillas-de-entrada plan)))

(defun mismo-valor-p (a b)
  "Cierto si A y B son el mismo valor de eje, como los compara la rejilla."
  (string= (nucleo:como-texto a) (nucleo:como-texto b)))

(defun casilla-de-la-fila (plan vista fila)
  "Donde esta FILA en la rejilla de VISTA: la celda con su pestana, lista
   para citarla en una formula, o NIL si no tiene casilla."
  (flet ((de (campo) (and campo (gethash campo (nucleo:valores fila)))))
    (let ((cruce (find-if (lambda (c)
                            (and (eq (vista c) vista)
                                 (or (null (nucleo:secciones vista))
                                     (mismo-valor-p (seccion c)
                                                    (de (nucleo:secciones vista))))))
                          (cruces plan))))
      (when cruce
        (let ((i (position (de (nucleo:eje-de-filas vista)) (valores-de-fila cruce)
                           :test #'mismo-valor-p))
              (j (position (de (nucleo:eje-de-columnas vista)) (valores-de-columna cruce)
                           :test #'mismo-valor-p)))
          (when (and i j)
            (format nil "~a!~a~d" (entrecomillar (nombre cruce))
                    (letra-de-columna (1+ j)) (+ +fila-primera-de-rejilla+ i))))))))

(defun formulas-copiadas-de-la-rejilla (plan hoja)
  "La formula de cada celda de HOJA cuyo campo se escribe en una rejilla:
   lee su casilla, y deja blanco si la casilla esta vacia (una celda en
   blanco citada vale 0)."
  (loop for campo in (nucleo:campos (coleccion hoja))
        for vista = (rejilla-que-escribe plan hoja (nucleo:nombre campo))
        when vista
          append (loop for fila in (nucleo:filas-de (entorno plan)
                                                    (nucleo:nombre (coleccion hoja)))
                       for numero from (fila-primera hoja)
                       for casilla = (casilla-de-la-fila plan vista fila)
                       when casilla
                         collect (list (cons "celda"
                                             (format nil "~a~d"
                                                     (columna-de hoja (nucleo:nombre campo))
                                                     numero))
                                       (cons "formula"
                                             (format nil "=IF(ISBLANK(~a),\"\",~a)"
                                                     casilla casilla))))))

(defun celdas-de-la-rejilla (plan cruce)
  "Los valores que lleva escritos la rejilla de entrada CRUCE: la casilla
   de cada fila de su seccion."
  (let* ((vista (vista cruce))
         (campo (nucleo:lo-que-se-muestra vista))
         (prefijo (format nil "~a!" (entrecomillar (nombre cruce)))))
    (loop for fila in (nucleo:filas-de (entorno plan) (nucleo:fuente vista))
          for casilla = (casilla-de-la-fila plan vista fila)
          for valor = (gethash campo (nucleo:valores fila))
          when (and casilla
                    (eql 0 (search prefijo casilla))
                    (not (nucleo:vacio-p valor)))
            collect (list (cons "celda" (subseq casilla (length prefijo)))
                          (cons "valor" valor)))))

(defun validacion-de-la-rejilla (a plan cruce rango)
  "El desplegable de RANGO en la rejilla de entrada CRUCE: el del campo que
   ensena la casilla, si tiene dominio."
  (let* ((vista (vista cruce))
         (coleccion (nucleo:coleccion-llamada (situacion plan) (nucleo:fuente vista)))
         (campo (nucleo:campo-llamado coleccion (nucleo:lo-que-se-muestra vista))))
    (when (nucleo:dominio campo)
      (list (desplegable a plan campo rango)))))
