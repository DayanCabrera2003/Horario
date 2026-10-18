;;;; El informe de conformidad.
;;;;
;;;; Para cada cosa que pedia la descripcion, cual de las cuatro respuestas
;;;; dio la arquitectura y por que.
;;;;
;;;; Es la evidencia que ninguna de las tres tesis anteriores tiene. Convierte
;;;; "el mecanismo de extension funciona" en algo que se ensena, y el renglon
;;;; de limite de cada emulacion -"no admite huecos", "muestra como mucho seis
;;;; filas relacionadas"- es la clase de detalle que hoy vive enterrado en un
;;;; comentario del corpus y que separa un prototipo de algo usable.

(in-package #:situacion.protocolo)

(defstruct (entrada-de-informe (:constructor hacer-entrada (respuesta capacidad nota)))
  respuesta capacidad nota)

(defvar *informe* nil
  "El informe que se esta construyendo, o NIL si no hay compilacion en curso.")

(defun anotar-en-informe (respuesta capacidad nota)
  "Anota en el informe en curso que CAPACIDAD se resolvio con RESPUESTA.

   Una entrada identica a otra ya anotada no se repite: una arquitectura
   pide la capacidad de un nodo cada vez que lo emite, y un nodo se emite
   una vez por fila. Sin esto, la validacion de forma de una fecha llenaba
   el informe con cien lineas iguales."
  (when (and *informe*
             (not (find-if (lambda (e)
                             (and (eq (entrada-de-informe-respuesta e) respuesta)
                                  (eq (entrada-de-informe-capacidad e) capacidad)
                                  (equal (entrada-de-informe-nota e) nota)))
                           (cdr *informe*))))
    (push (hacer-entrada respuesta capacidad nota) (cdr *informe*)))
  respuesta)

(defun rebajar-en-informe (capacidad detalle respuesta nota)
  "Corrige la entrada del informe en curso que respondio a CAPACIDAD con una
   nota que contiene DETALLE: pasa a valer RESPUESTA, con NOTA.

   Existe porque una arquitectura puede declarar que cumple una capacidad y
   descubrir, al emitir un nodo concreto, que para ese nodo no puede: la
   hoja de calculo cumple el marcado textual, pero una explicacion que no
   sabe traducir a formula lo degrada. El informe tiene que decirlo de ese
   nodo, no mantener el \"cumple\" que anoto al principio. Si no hay tal
   entrada, se anade una."
  (when *informe*
    (let ((entrada (find-if (lambda (e)
                              (and (eq (entrada-de-informe-capacidad e) capacidad)
                                   (search detalle (or (entrada-de-informe-nota e) ""))))
                            (cdr *informe*))))
      (if entrada
          (setf (entrada-de-informe-respuesta entrada) respuesta
                (entrada-de-informe-nota entrada) nota)
          (anotar-en-informe respuesta capacidad nota))))
  respuesta)

(defmacro con-informe ((arquitectura) &body cuerpo)
  "Ejecuta CUERPO acumulando un informe de conformidad.

   Devuelve (VALUES <lo que devuelva CUERPO> INFORME)."
  (let ((i (gensym "INFORME")))
    `(let* ((,i (informe-vacio ,arquitectura))
            (*informe* ,i))
       (let ((resultado (progn ,@cuerpo)))
         (setf (cdr ,i) (reverse (cdr ,i)))
         (values resultado ,i)))))

(defun informe-vacio (arquitectura) (cons arquitectura '()))
(defun arquitectura-del-informe (informe) (car informe))
(defun entradas-del-informe (informe) (cdr informe))

(defun resumen-de-informe (informe)
  "Cuantas de cada respuesta, como lista asociativa."
  (let ((cuenta (list (cons :cumple 0) (cons :emula 0)
                      (cons :degrada 0) (cons :rechaza 0))))
    (dolist (e (entradas-del-informe informe) cuenta)
      (let ((par (assoc (entrada-de-informe-respuesta e) cuenta)))
        (when par (incf (cdr par)))))))

(defun escribir-informe (informe &optional (flujo *standard-output*))
  "Imprime el informe en un formato legible de un vistazo."
  (let* ((arquitectura (arquitectura-del-informe informe))
         (entradas (entradas-del-informe informe))
         (resumen (resumen-de-informe informe))
         (raya (make-string 68 :initial-element #\-)))
    (format flujo "~&Informe de conformidad~30tArquitectura: ~(~a~)~%"
            (class-name (class-of arquitectura)))
    (format flujo "~a~%" raya)
    (if (null entradas)
        (format flujo "  (la descripcion no pidio ninguna capacidad)~%")
        (dolist (e entradas)
          (format flujo "  ~(~8a~) ~(~28a~) ~a~%"
                  (entrada-de-informe-respuesta e)
                  (entrada-de-informe-capacidad e)
                  (or (entrada-de-informe-nota e) ""))))
    (format flujo "~a~%" raya)
    (format flujo "  ~d nativas, ~d emuladas, ~d degradadas, ~d rechazadas~%"
            (cdr (assoc :cumple resumen)) (cdr (assoc :emula resumen))
            (cdr (assoc :degrada resumen)) (cdr (assoc :rechaza resumen)))
    informe))
