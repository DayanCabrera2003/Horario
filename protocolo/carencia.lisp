;;;; Carencias de capacidad y degradacion.
;;;;
;;;; Ninguna de las tres tesis anteriores se plantea que pasa cuando una
;;;; arquitectura no puede expresar algo. La de 2026 lo reconoce en una nota
;;;; -"un backend cuyo formato de salida no admita ese tipo de posicionamiento
;;;; podria simplemente prescindir de esta funcionalidad"- y ahi queda.
;;;;
;;;; Aqui es un paso de primera clase de la compilacion, con cuatro respuestas
;;;; posibles y un informe que las registra todas.
;;;;
;;;;   CUMPLE    lo hace de forma nativa.
;;;;   EMULA     no lo tiene, pero puede fabricarlo. Declara a que coste.
;;;;   DEGRADA   hay una version mas pobre que sigue sirviendo para lo mismo.
;;;;   RECHAZA   no hay version honesta y fingirla seria mentir.
;;;;
;;;; La frontera entre degradar y rechazar es la que hay que poder defender:
;;;; se degrada cuando el resultado sigue cumpliendo el proposito por otra
;;;; via; se rechaza cuando el resultado PARECERIA correcto y no lo seria. Un
;;;; documento que aparenta admitir entrada y no la admite es peor que un
;;;; error.
;;;;
;;;; LA POLITICA VIVE FUERA DEL BACKEND. Una variable especial decide que se
;;;; acepta, asi que la misma descripcion se puede compilar en tres modos y
;;;; obtener tres respuestas distintas sobre la misma arquitectura. Eso
;;;; convierte el mecanismo en algo medible: compilar los libros del corpus
;;;; contra las cuatro arquitecturas en los tres modos es una tabla de
;;;; resultados experimentales, y sale del diseno sin escribir nada mas.

(in-package #:situacion.protocolo)

(defvar *politica* :permisiva
  "Que se acepta cuando una arquitectura no cumple una capacidad.

     :PERMISIVA    se aceptan emulaciones y degradaciones. Es la de por
                   defecto y la que se usa para producir documentos.
     :ESTRICTA     cualquier carencia es un error. Sirve para saber
                   exactamente que descripciones caen enteras dentro de una
                   arquitectura.
     :SOLO-NATIVO  ni siquiera se permite emular. Sirve para medir cuanto de
                   una descripcion es nativo y cuanto es andamiaje.")

(define-condition carencia-de-capacidad ()
  ((capacidad :initarg :capacidad :reader capacidad-pedida)
   (nodo :initarg :nodo :reader nodo-afectado)
   (arquitectura :initarg :arquitectura :reader arquitectura-afectada))
  (:documentation
   "Se senala cada vez que una descripcion pide algo que la arquitectura no
    cumple de forma nativa. No es un error: es informacion. Quien quiera
    observar la compilacion puede instalar un manejador y enterarse de todo
    lo que se emula o se degrada sin cambiar nada."))

(define-condition capacidad-no-disponible (error)
  ((capacidad :initarg :capacidad :reader capacidad-pedida)
   (arquitectura :initarg :arquitectura :reader arquitectura-afectada)
   (detalle :initarg :detalle :initform "" :reader detalle-de-la-carencia))
  (:report
   (lambda (c s)
     (format s "La arquitectura ~(~a~) no puede con ~(~a~).~@[~%  ~a~]"
             (class-name (class-of (arquitectura-afectada c)))
             (capacidad-pedida c)
             (let ((d (detalle-de-la-carencia c))) (unless (string= d "") d))))))

(defun cumple-p (arquitectura capacidad)
  "Cierto si ARQUITECTURA hereda de la clase de CAPACIDAD."
  (let ((clase (find-class capacidad nil)))
    (and clase (typep arquitectura clase))))

(defun requerir (arquitectura capacidad nodo &key (detalle ""))
  "Pide CAPACIDAD para NODO y devuelve que se hizo.

   Es el unico camino por el que una arquitectura declara que necesita algo.
   Cumplir, emular, degradar o rechazar se decide aqui, se anota en el
   informe, y el backend sigue sabiendo con que se ha quedado."
  (if (cumple-p arquitectura capacidad)
      (anotar-en-informe :cumple capacidad detalle)
      (progn
        ;; Se senala para quien quiera observar; si nadie lo hace, seguimos.
        (signal 'carencia-de-capacidad :capacidad capacidad :nodo nodo
                                       :arquitectura arquitectura)
        (multiple-value-bind (respuesta nota)
            (resolver-carencia arquitectura capacidad nodo)
          (let ((nota (or nota detalle)))
            (when (or (eq respuesta :rechaza)
                      (eq *politica* :estricta)
                      (and (eq *politica* :solo-nativo)
                           (member respuesta '(:emula :degrada))))
              (error 'capacidad-no-disponible
                     :capacidad capacidad :arquitectura arquitectura
                     :detalle nota))
            (anotar-en-informe respuesta capacidad nota))))))

;;; Respuesta por defecto: si una arquitectura no dice que hacer con una
;;; carencia, se rechaza. Callar no puede significar "algo saldra".
(defmethod resolver-carencia ((arquitectura arquitectura) capacidad nodo)
  (declare (ignore nodo))
  (values :rechaza
          (format nil "~(~a~) no declara que hacer sin ~(~a~)."
                  (class-name (class-of arquitectura)) capacidad)))
