;;;; El plano de libro y su serializacion.
;;;;
;;;; El plano es una descripcion puramente mecanica de un libro: celdas,
;;;; formulas ya compiladas, estilos, rangos nombrados, validaciones y
;;;; protecciones. Su vocabulario es 100% de hoja de calculo, y eso esta bien:
;;;; a esta altura ya estamos dentro de la arquitectura de Excel.
;;;;
;;;; LO QUE IMPORTA SON LAS TRES REGLAS
;;;;
;;;;   1. El plano lo posee esta arquitectura. Ningun otro sistema lo conoce.
;;;;   2. El nucleo no lo ve nunca.
;;;;   3. Web y texto no tienen nada parecido: emiten directamente. La
;;;;      asimetria la causa que un .xlsx sea un contenedor binario
;;;;      comprimido, que es un hecho mecanico y no semantico.
;;;;
;;;; POR QUE ESTO NO ES EL ERROR DE 2026, dicho para la defensa: alli el JSON
;;;; con formulas ERA el punto de extension, el sitio por donde supuestamente
;;;; iba a entrar un backend HTML. Aqui el punto de extension es el protocolo,
;;;; que esta cuatro fases mas arriba.
;;;;
;;;; El serializador es propio y son cuarenta lineas, para que el sistema
;;;; entero siga arrancando con un SBCL recien instalado y sin librerias.

(in-package #:situacion.excel)

(defun escribir-json (valor flujo &optional (sangria 0))
  "Serializa listas asociativas, listas, cadenas, numeros y booleanos."
  (let ((margen (make-string (* 2 sangria) :initial-element #\Space)))
    (cond
      ;; En Common Lisp la lista vacia y el nulo son el mismo objeto; en
      ;; JSON no. Quien emite una lista que puede quedar vacia la marca con
      ;; LISTA, y aqui se distingue.
      ((eq valor :lista-vacia) (write-string "[]" flujo))
      ((null valor) (write-string "null" flujo))
      ((eq valor t) (write-string "true" flujo))
      ((eq valor :false) (write-string "false" flujo))
      ((stringp valor) (escribir-cadena-json valor flujo))
      ((realp valor) (format flujo "~a" valor))
      ((symbolp valor) (escribir-cadena-json (string-downcase (symbol-name valor)) flujo))
      ;; Lista asociativa: la reconocemos porque su primer elemento es un par
      ;; con una cadena delante.
      ((and (consp valor) (consp (first valor)) (stringp (car (first valor))))
       (format flujo "{~%")
       (loop for (clave . contenido) in valor
             for primera = t then nil
             do (unless primera (format flujo ",~%"))
                (format flujo "~a  " margen)
                (escribir-cadena-json clave flujo)
                (write-string ": " flujo)
                (escribir-json contenido flujo (1+ sangria)))
       (format flujo "~%~a}" margen))
      ((consp valor)
       (format flujo "[~%")
       (loop for elemento in valor
             for primera = t then nil
             do (unless primera (format flujo ",~%"))
                (format flujo "~a  " margen)
                (escribir-json elemento flujo (1+ sangria)))
       (format flujo "~%~a]" margen))
      (t (escribir-cadena-json (princ-to-string valor) flujo)))))

(defun escribir-cadena-json (cadena flujo)
  (write-char #\" flujo)
  (loop for c across cadena
        do (case c
             (#\" (write-string "\\\"" flujo))
             (#\\ (write-string "\\\\" flujo))
             (#\Newline (write-string "\\n" flujo))
             (#\Tab (write-string "\\t" flujo))
             (t (if (< (char-code c) 32)
                    (format flujo "\\u~4,'0x" (char-code c))
                    (write-char c flujo)))))
  (write-char #\" flujo))

(defun lista (elementos)
  "Marca una lista que puede quedar vacia, para que salga como [] y no null."
  (or elementos :lista-vacia))

(defun escribir-plano (plano destino)
  "Escribe el plano de libro en DESTINO, que puede ser una ruta o un flujo."
  (if (streamp destino)
      (progn (escribir-json plano destino) (terpri destino))
      (with-open-file (flujo destino :direction :output :if-exists :supersede
                                     :if-does-not-exist :create
                                     :external-format :utf-8)
        (escribir-json plano flujo)
        (terpri flujo)))
  destino)
