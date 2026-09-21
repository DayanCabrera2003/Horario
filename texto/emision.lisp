;;;; Emision a texto plano.
;;;;
;;;; Como esta arquitectura no tiene derivacion viva, su plan consiste en
;;;; evaluar la situacion entera con el evaluador de referencia del nucleo y
;;;; quedarse con los valores ya calculados. Es la forma canonica de
;;;; materializar una situacion cuando el destino no recalcula, y es tambien
;;;; la demostracion de que el evaluador de referencia hace falta: sin el,
;;;; esta arquitectura no podria existir sin reimplementar la semantica del
;;;; lenguaje por su cuenta.

(in-package #:situacion.texto)

(defclass plan-de-texto ()
  ((situacion :accessor situacion :initarg :situacion)
   (evaluado :accessor evaluado :initarg :evaluado
             :documentation
             "Lo que devolvio el evaluador de referencia: por coleccion, las
              filas con sus valores calculados y las marcas que disparan.")
   (entorno :accessor entorno :initarg :entorno))
  (:documentation "Plan de la arquitectura de texto. Opaco para el nucleo."))

(defmethod protocolo:planificar-coleccion ((a texto) coleccion plan)
  "Una tabla de texto no tiene geometria que repartir: las columnas se
   alinean al escribir, con el ancho que pida el contenido."
  (declare (ignore coleccion)) plan)

(defmethod protocolo:planificar-campo ((a texto) campo coleccion plan)
  (declare (ignore campo coleccion)) plan)

(defmethod protocolo:planificar ((a texto) situacion)
  (declare (ignore situacion))
  (error "PLANIFICAR necesita los datos. Usa MATERIALIZAR."))

(defmethod protocolo:materializar ((a texto) situacion datos destino)
  (protocolo:con-informe (a)
    ;; Primero se declara todo lo que la descripcion pide, para que el
    ;; informe salga completo aunque despues la emision sea trivial.
    (dolist (r (protocolo:requerimientos situacion))
      (destructuring-bind (capacidad nodo detalle) r
        (protocolo:requerir a capacidad nodo :detalle detalle)))
    (let* ((entorno (nucleo:hacer-entorno situacion datos))
           (plan (make-instance 'plan-de-texto
                                :situacion situacion
                                :entorno entorno
                                :evaluado (nucleo:evaluar-situacion situacion datos))))
      (protocolo:emitir a plan destino))))

(defmethod protocolo:emitir ((a texto) plan destino)
  (let ((flujo (if (streamp destino) destino
                   (open destino :direction :output :if-exists :supersede
                                 :if-does-not-exist :create))))
    (unwind-protect (escribir-documento a plan flujo)
      (unless (streamp destino) (close flujo)))
    destino))

(defun escribir-documento (a plan flujo)
  (let ((situacion (situacion plan)))
    (format flujo "~a~%~a~%~%" (nucleo:etiqueta situacion)
            (make-string (length (nucleo:etiqueta situacion))
                         :initial-element #\=))
    (when (rest (nucleo:vistas situacion))
      (format flujo "Indice~%")
      (dolist (v (nucleo:vistas situacion))
        (format flujo "~a~%" (protocolo:emitir-vista a v plan)))
      (format flujo "~%"))
    ;; Primero las vistas cruzadas: son la forma en que el usuario piensa el
    ;; problema, y la tabla plana de la que salen va despues.
    (dolist (vista (nucleo:vistas situacion))
      (when (nucleo:cruzada-p vista)
        (escribir-cruzada a plan vista flujo)))
    (dolist (coleccion (nucleo:colecciones situacion))
      (escribir-coleccion a plan coleccion flujo))))

(defun valores-distintos (plan coleccion campo)
  "Los valores que toma un campo, sin repetir y en orden de aparicion.

   Son los que van en un eje de una tabla cruzada. Notese que salen de los
   DATOS: el numero de columnas de un cuadrante depende de lo que haya, no de
   lo que se declaro."
  (let ((vistos '()))
    (dolist (f (nucleo:filas-de (entorno plan) (nucleo:nombre coleccion))
               (nreverse vistos))
      (let ((v (nucleo:valor-de-campo (entorno plan) f campo)))
        (unless (or (nucleo:vacio-p v)
                    (member v vistos :test #'nucleo:iguales-p))
          (push v vistos))))))

(defun fila-del-cruce (plan coleccion vista valor-fila valor-columna)
  "La fila de la coleccion que cae en ese cruce, o NIL."
  (find-if (lambda (f)
             (and (nucleo:iguales-p valor-fila
                                    (nucleo:valor-de-campo (entorno plan) f
                                                           (nucleo:eje-de-filas vista)))
                  (nucleo:iguales-p valor-columna
                                    (nucleo:valor-de-campo (entorno plan) f
                                                           (nucleo:eje-de-columnas vista)))))
           (nucleo:filas-de (entorno plan) (nucleo:nombre coleccion))))

(defun escribir-cruzada (a plan vista flujo)
  "La vista cruzada, como rejilla de texto alineada.

   Texto plano si puede con esto: alinear columnas es lo unico que sabe
   hacer. Lo que no puede es que el usuario escriba en ella."
  (let* ((situacion (situacion plan))
         (coleccion (nucleo:coleccion-llamada situacion (nucleo:fuente vista)))
         (filas (valores-distintos plan coleccion (nucleo:eje-de-filas vista)))
         (columnas (valores-distintos plan coleccion (nucleo:eje-de-columnas vista)))
         (campo-celda (nucleo:campo-llamado coleccion (nucleo:lo-que-se-muestra vista)))
         (encabezados (cons (string-capitalize
                             (symbol-name (nucleo:eje-de-filas vista)))
                            (mapcar #'nucleo:como-texto columnas)))
         (celdas (loop for vf in filas
                       collect (cons (nucleo:como-texto vf)
                                     (loop for vc in columnas
                                           collect (let ((f (fila-del-cruce
                                                             plan coleccion vista vf vc)))
                                                     (if f
                                                         (nucleo:como-texto
                                                          (nucleo:valor-de-campo
                                                           (entorno plan) f
                                                           (nucleo:nombre campo-celda)))
                                                         "")))))))
    (format flujo "~a~%" (nucleo:etiqueta vista))
    (let ((anchos (calcular-anchos encabezados celdas)))
      (escribir-fila flujo encabezados anchos)
      (format flujo "~a~%" (raya anchos))
      (dolist (c celdas) (escribir-fila flujo c anchos)))
    (format flujo "~%")))

(defun escribir-coleccion (a plan coleccion flujo)
  (let* ((nombre (nucleo:nombre coleccion))
         (filas (rest (assoc nombre (evaluado plan))))
         (campos (nucleo:campos coleccion))
         ;; La columna de estado es la degradacion del marcado visual: donde
         ;; una hoja de calculo pondria un relleno, aqui va una palabra.
         (encabezados (append (mapcar #'nucleo:etiqueta campos) (list "Estado")))
         (celdas (loop for fila in filas
                       collect (append
                                (loop for campo in campos
                                      collect (nucleo:como-texto
                                               (cdr (assoc (nucleo:nombre campo)
                                                           (car fila)))))
                                (list (texto-del-estado a plan coleccion fila)))))
         (anchos (calcular-anchos encabezados celdas)))
    (format flujo "~a~%" (nucleo:etiqueta coleccion))
    (escribir-fila flujo encabezados anchos)
    (format flujo "~a~%" (raya anchos))
    (dolist (c celdas) (escribir-fila flujo c anchos))
    ;; Los dominios de entrada, al pie: la degradacion del desplegable.
    (dolist (campo campos)
      (when (and (eq (nucleo:rol campo) :entrada) (nucleo:dominio campo))
        (format flujo "~%  ~a~%"
                (protocolo:emitir-entrada a campo (nucleo:hacer-ambito) plan))))
    (format flujo "~%")))

(defmethod protocolo:emitir-marca ((a texto) marca ambito plan)
  "Sin color, una marca es la palabra que la nombra.

   Y si trae explicacion, la explicacion, que esta escrita para leerse. Esa
   es la degradacion honesta del marcado visual: no es un parche, es lo unico
   que funciona en una impresion en blanco y negro."
  (declare (ignore ambito plan))
  (or (nucleo:explicacion marca)
      (string-downcase (substitute #\Space #\- (symbol-name (nucleo:nombre marca))))))

(defmethod protocolo:emitir-entrada ((a texto) campo ambito plan)
  "Sin controles, un dominio de entrada es una nota al pie con los valores."
  (declare (ignore ambito))
  (format nil "~a admite: ~{~a~^, ~}" (nucleo:etiqueta campo)
          (mapcar #'nucleo:como-texto
                  (handler-case
                      (nucleo:evaluar (nucleo:dominio campo) (nucleo:hacer-ambito)
                                      (entorno plan) '())
                    (error () '())))))

(defmethod protocolo:planificar-vista ((a texto) vista plan)
  (declare (ignore vista)) plan)

(defmethod protocolo:emitir-vista ((a texto) vista plan)
  "Sin navegacion, una vista es un renglon del indice del principio."
  (declare (ignore plan))
  (format nil "  - ~a~@[  (punto de entrada)~]"
          (nucleo:etiqueta vista) (nucleo:es-entrada vista)))

(defun texto-del-estado (a plan coleccion fila)
  "El estado de una fila, en palabras.

   Se prefiere la explicacion de la marca si la tiene, porque esta escrita
   para leerse; si no la tiene, se escribe el nombre del estado. Ese nombre
   es el significado que declara la marca, no un color, y por eso aqui se
   puede escribir tal cual."
  (declare (ignore a))
  (let ((disparadas (cdr fila)))
    (if (null disparadas)
        ""
        (let* ((situacion (situacion plan))
               (marcas (remove-if-not (lambda (m) (member (nucleo:nombre m) disparadas))
                                      (nucleo:marcas situacion)))
               (fila-real (fila-del-entorno plan coleccion fila)))
          (format nil "~{~a~^; ~}"
                  (mapcar (lambda (m)
                            (or (and fila-real
                                     (nucleo:explicacion-de-marca (entorno plan)
                                                                  fila-real m))
                                (string-downcase (symbol-name (nucleo:nombre m)))))
                          marcas))))))

(defun fila-del-entorno (plan coleccion fila-evaluada)
  "La fila del entorno que corresponde a una fila ya evaluada.

   Se empareja por la clave declarada. Si la coleccion no declara clave, se
   empareja por posicion, que es lo unico que queda."
  (let* ((nombre (nucleo:nombre coleccion))
         (filas (nucleo:filas-de (entorno plan) nombre))
         (clave (nucleo:clave coleccion)))
    (if clave
        (find-if (lambda (f)
                   (every (lambda (c)
                            (nucleo:iguales-p
                             (nucleo:valor-de-campo (entorno plan) f c)
                             (cdr (assoc c (car fila-evaluada)))))
                          clave))
                 filas)
        (let ((pos (position fila-evaluada (rest (assoc nombre (evaluado plan))))))
          (when pos (nth pos filas))))))

;;; --- alineacion ---

(defun calcular-anchos (encabezados celdas)
  (loop for i from 0 below (length encabezados)
        collect (reduce #'max (cons (length (nth i encabezados))
                                    (mapcar (lambda (c) (length (nth i c))) celdas)))))

(defun escribir-fila (flujo celdas anchos)
  (format flujo "  ~{~a~^  ~}~%"
          (loop for c in celdas for a in anchos
                collect (format nil "~va" a c))))

(defun raya (anchos)
  (format nil "  ~{~a~^  ~}"
          (mapcar (lambda (a) (make-string a :initial-element #\-)) anchos)))
