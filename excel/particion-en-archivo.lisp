;;;; H2: una vista particionada, materializada como un .xlsx por seccion en
;;;; vez de una pestana del libro principal.
;;;;
;;;; SIN FORMULAS. Cada archivo es una copia de consulta -nunca fue :ENTRADA
;;;; T- asi que se escribe con el evaluador de referencia del nucleo, la
;;;; misma pieza que ya usa TEXTO. No hace falta copiar la hoja de origen
;;;; dentro del archivo porque no hay BUSCARV/INDICE que resolver ahi.

(in-package #:situacion.excel)

(defun sanear-para-archivo (texto)
  "Nombre de archivo a partir de un valor de seccion: minusculas, sin
   acentos, espacios a guiones."
  (string-downcase
   (substitute #\- #\Space
               (remove-if (lambda (c) (find c "/\\:*?\"<>|")) texto))))
;; Nota: esto no quita acentos (nucleo:como-texto puede traer "ñ"/tildes).
;; Si el sistema de archivos real lo exige, anadir aqui una tabla de
;; sustitucion explicita (a->a, ñ->n, etc.) en vez de una libreria: el
;; proyecto no usa Quicklisp en el nucleo/protocolo/excel.

(defun ruta-de-archivo (destino-principal seccion)
  "La ruta del archivo de una seccion, junto al libro principal.

   DESTINO-PRINCIPAL tiene que ser una ruta real (path o string), no un
   flujo: no se puede escribir mas de un archivo dentro de un unico flujo en
   memoria. Quien llama (ESCRIBIR-ARCHIVOS-DE-VISTA) lo comprueba antes de
   entrar aqui."
  (let* ((base (pathname-name destino-principal))
         (tipo (pathname-type destino-principal)))
    (make-pathname :name (format nil "~a-~a" base (sanear-para-archivo
                                                    (nucleo:como-texto seccion)))
                   :type tipo
                   :defaults destino-principal)))

;;; ---------------------------------------------------------------------
;;; El cuadrante congelado
;;; ---------------------------------------------------------------------

(defun valor-congelado-de-casilla (plan filas-en-la-casilla campo-celda)
  "Lo que va en una casilla congelada del cruce.

   Mismo criterio que TEXTO-DE-LA-CASILLA (texto/emision.lisp), que es el
   precedente correcto: sin formulas vivas, se lee el valor directamente del
   entorno con NUCLEO:VALOR-DE-CAMPO, no del diccionario que precalcula
   NUCLEO:EVALUAR-SITUACION. Sin filas, cadena vacia; con una, su valor; con
   mas de una -conflicto declarado con :UNICA-SALVO y de verdad presente en
   los datos- todas juntas separadas por \" / \", para ensenar el choque en
   vez de elegir una y callarse.

   No recibe el CRUCE: a diferencia de FILAS-DE-LA-CASILLA-CONGELADA, no
   necesita nada de su geometria, solo las filas ya elegidas y el campo a
   mostrar."
  (format nil "~{~a~^ / ~}"
          (loop for f in filas-en-la-casilla
                collect (nucleo:como-texto
                         (nucleo:valor-de-campo (entorno plan) f campo-celda)))))

(defun filas-de-la-casilla-congelada (plan cruce valor-fila valor-columna)
  "Las filas de CRUCE que caen en la casilla (VALOR-FILA, VALOR-COLUMNA).

   Analoga a FILAS-DEL-CRUCE (texto/emision.lisp), pero restringida de
   entrada a las filas de la SECCION de este cruce -CRUCE ya trae su
   SECCION, asi que no hace falta recalcular FILAS-DE-LA-SECCION contra la
   vista entera."
  (let ((vista (vista cruce)))
    (remove-if-not
     (lambda (f)
       (and (nucleo:iguales-p valor-fila
                              (nucleo:valor-de-campo (entorno plan) f
                                                     (nucleo:eje-de-filas vista)))
            (nucleo:iguales-p valor-columna
                              (nucleo:valor-de-campo (entorno plan) f
                                                     (nucleo:eje-de-columnas vista)))))
     (filas-de-la-seccion plan vista (seccion cruce)))))

(defun plano-de-cruce-congelado (a plan cruce)
  "El plano de la hoja de un cruce en VISTAS-EN-ARCHIVO: mismos ejes y
   nombre de pestana que PLANO-DE-CRUCE, pero con los valores ya resueltos
   en vez de formulas INDICE/COINCIDIR. No hay columna de clave compuesta
   que anadir a ninguna hoja de origen: no hay nada que buscar aqui, solo
   que leer."
  (declare (ignore a))
  (let* ((vista (vista cruce))
         (campo-celda (nucleo:lo-que-se-muestra vista))
         (fila-enc 3) (fila-ini 4)
         (encabezados
           (cons (list (cons "celda" (format nil "A~d" fila-enc))
                       (cons "campo" "__eje__")
                       (cons "rol" "fijo")
                       (cons "texto" (string-capitalize
                                      (symbol-name (nucleo:eje-de-filas vista)))))
                 (loop for v in (valores-de-columna cruce)
                       for i from 1
                       collect (list (cons "celda" (format nil "~a~d"
                                                           (letra-de-columna i) fila-enc))
                                     (cons "campo" (format nil "__col~d__" i))
                                     (cons "rol" "fijo")
                                     (cons "texto" (nucleo:como-texto v))))))
         (celdas-de-eje
           (loop for v in (valores-de-fila cruce)
                 for f from fila-ini
                 collect (list (cons "celda" (format nil "A~d" f))
                               (cons "valor" v))))
         (celdas-del-cuadrante
           (loop for vf in (valores-de-fila cruce)
                 for f from fila-ini
                 append (loop for vc in (valores-de-columna cruce)
                              for i from 1
                              collect
                              (list (cons "celda" (format nil "~a~d"
                                                          (letra-de-columna i) f))
                                    (cons "valor"
                                          (valor-congelado-de-casilla
                                           plan
                                           (filas-de-la-casilla-congelada plan cruce vf vc)
                                           campo-celda)))))))
    (list (cons "nombre" (nombre-de-pestana (nucleo:etiqueta vista) (seccion cruce)))
          (cons "fila_encabezado" fila-enc)
          (cons "fila_primera" fila-ini)
          (cons "capacidad" (max 1 (length (valores-de-fila cruce))))
          (cons "color_pestana" "8EA9DB")
          (cons "encabezados" (lista encabezados))
          (cons "celdas" (lista (append celdas-de-eje celdas-del-cuadrante)))
          (cons "formulas" (lista nil))
          (cons "editables" :lista-vacia)
          (cons "validaciones" :lista-vacia)
          (cons "formatos_condicionales" :lista-vacia)
          (cons "rangos_nombrados" :lista-vacia)
          (cons "leyenda" :lista-vacia))))

;;; ---------------------------------------------------------------------
;;; Escritura de los archivos
;;; ---------------------------------------------------------------------

(defun escribir-archivos-de-vista (a plan destino-principal)
  "Escribe un .xlsx por cada cruce de (archivos plan), junto al libro
   principal. Devuelve la lista de rutas escritas.

   Si DESTINO-PRINCIPAL es un flujo (como el que usan las pruebas de
   conformidad que materializan en memoria con MATERIALIZAR-EN-CADENA), no
   hay junto a que escribir los archivos adicionales: se senala un error
   claro en vez de fallar mas abajo con un mensaje criptico de PATHNAME-NAME
   sobre un STREAM."
  (when (streamp destino-principal)
    (error "VISTAS-EN-ARCHIVO necesita una ruta real como destino~@
            (recibio un flujo): no se pueden escribir varios archivos~@
            dentro de un solo flujo en memoria."))
  (loop for cruce in (archivos plan)
        for ruta = (ruta-de-archivo destino-principal (seccion cruce))
        for plano = (list (cons "libro" (format nil "~a - ~a"
                                                (nucleo:etiqueta (vista cruce))
                                                (nucleo:como-texto (seccion cruce))))
                          (cons "vistas" :lista-vacia)
                          (cons "hojas" (lista (list (plano-de-cruce-congelado a plan cruce)))))
        do (escribir-plano plano ruta)
        collect ruta))
