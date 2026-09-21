;;;; Marco de pruebas minimo.
;;;;
;;;; Deliberadamente sin dependencias. El nucleo, el protocolo y el juego de
;;;; conformidad tienen que poder cargarse y comprobarse con un SBCL recien
;;;; instalado y nada mas, porque eso es lo que va a recibir quien quiera
;;;; anadir una arquitectura.
;;;;
;;;; Para las pruebas de desarrollo del dia a dia se usara Parachute, que si
;;;; viene por Quicklisp. Este marco cubre lo que tiene que correr en
;;;; cualquier sitio: los invariantes y la conformidad.
;;;;
;;;; Son unas cien lineas. No pretende competir con nada.

(in-package #:situacion.pruebas)

(defvar *pruebas* '()
  "Registro de pruebas, en orden inverso de definicion.
   Cada entrada es (NOMBRE DESCRIPCION . FUNCION).")

(defvar *fallos* '()
  "Fallos acumulados durante la prueba en curso.")

(defvar *comprobaciones* 0
  "Comprobaciones hechas durante la prueba en curso.")

(defun registrar-prueba (nombre descripcion funcion)
  (setf *pruebas*
        (cons (list* nombre descripcion funcion)
              (remove nombre *pruebas* :key #'first)))
  nombre)

(defmacro definir-prueba (nombre descripcion &body cuerpo)
  "Define una prueba y la registra.

   DESCRIPCION se imprime en el informe, asi que se escribe para que quien
   lea la salida entienda que se rompio sin abrir el archivo."
  `(registrar-prueba ',nombre ,descripcion (lambda () ,@cuerpo)))

(defun anotar-fallo (forma explicacion)
  (push (cons forma explicacion) *fallos*))

(defmacro comprobar (forma &optional formato &rest argumentos)
  "Comprueba que FORMA es verdadera. Si no lo es, lo anota y sigue.

   Sigue a proposito en vez de abortar: en un invariante arquitectonico
   interesa la lista completa de lo que esta mal, no el primero que salte."
  (let ((resultado (gensym "RESULTADO")))
    `(let ((,resultado ,forma))
       (incf *comprobaciones*)
       (unless ,resultado
         (anotar-fallo ',forma
                       ,(when formato `(format nil ,formato ,@argumentos))))
       ,resultado)))

(defun ejecutar-una (entrada)
  "Corre una prueba. Devuelve (VALUES EXITO COMPROBACIONES FALLOS)."
  (destructuring-bind (nombre descripcion . funcion) entrada
    (declare (ignore nombre))
    (let ((*fallos* '())
          (*comprobaciones* 0))
      (handler-case (funcall funcion)
        (error (e)
          (anotar-fallo 'error-no-esperado
                        (format nil "~a durante \"~a\"" e descripcion))))
      (values (null *fallos*) *comprobaciones* (reverse *fallos*)))))

(defun informar-fallo (fallo)
  (destructuring-bind (forma . explicacion) fallo
    (format t "      ~s~%" forma)
    (when explicacion
      (format t "        ~a~%" explicacion))))

(defun ejecutar ()
  "Corre todas las pruebas registradas e imprime el informe.
   Devuelve T si todas pasan."
  (let ((pruebas (reverse *pruebas*))
        (fallidas 0)
        (total-comprobaciones 0))
    (format t "~&~%Pruebas de situacion~%")
    (format t "~a~%" (make-string 60 :initial-element #\-))
    (dolist (entrada pruebas)
      (destructuring-bind (nombre descripcion . funcion) entrada
        (declare (ignore funcion))
        (multiple-value-bind (exito comprobaciones fallos) (ejecutar-una entrada)
          (incf total-comprobaciones comprobaciones)
          (format t "  ~:[FALLA~;  ok ~]  ~(~a~)~30t~a~%" exito nombre descripcion)
          (unless exito
            (incf fallidas)
            (mapc #'informar-fallo fallos)))))
    (format t "~a~%" (make-string 60 :initial-element #\-))
    (format t "  ~d pruebas, ~d comprobaciones, ~d fallidas~%~%"
            (length pruebas) total-comprobaciones fallidas)
    (zerop fallidas)))

(defun ejecutar-y-salir ()
  "Corre las pruebas y sale con codigo 1 si alguna falla.
   Es el punto de entrada del script y de cualquier integracion continua."
  (let ((exito (ejecutar)))
    (finish-output)
    (uiop:quit (if exito 0 1))))
