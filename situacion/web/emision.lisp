;;;; Emision a pagina web.
;;;;
;;;; Produce un archivo HTML autonomo: sin servidor, sin dependencias, sin
;;;; conexion. Se abre con doble clic.
;;;;
;;;; Lo que hay que mirar al compararla con la hoja de calculo no es que se
;;;; parezcan, sino que el comportamiento sea el mismo: al escribir en un
;;;; campo de entrada, los derivados se recalculan y las marcas aparecen o
;;;; desaparecen. Eso es lo que significa que las derivaciones sean vivas, y
;;;; es lo que ninguna de las tres tesis anteriores llego a demostrar en dos
;;;; destinos a la vez.

(in-package #:situacion.web)

(defclass plan-de-web ()
  ((situacion :accessor situacion :initarg :situacion)
   (entorno :accessor entorno :initarg :entorno :initform nil))
  (:documentation "Plan de la web. Opaco para el nucleo, y casi vacio: una
   pagina no tiene direcciones que repartir, que es justo por lo que esta
   arquitectura sirve de control."))

(defparameter +paleta-web+
  '((:problema    . "problema")
    (:advertencia . "advertencia")
    (:informativa . "informativa"))
  "De severidad a clase de CSS. La misma idea que la paleta de la hoja de
   calculo, con otra realizacion: el lenguaje declara el significado, cada
   arquitectura decide como se ve.")

(defmethod protocolo:planificar ((a web) situacion)
  (make-instance 'plan-de-web :situacion situacion))

(defmethod protocolo:planificar-coleccion ((a web) coleccion plan)
  (declare (ignore coleccion)) plan)

(defmethod protocolo:planificar-campo ((a web) campo coleccion plan)
  (declare (ignore campo coleccion)) plan)

(defmethod protocolo:materializar ((a web) situacion datos destino)
  (protocolo:con-informe (a)
    (dolist (r (protocolo:requerimientos situacion))
      (destructuring-bind (capacidad nodo detalle) r
        (protocolo:requerir a capacidad nodo :detalle detalle)))
    (let ((plan (protocolo:planificar a situacion)))
      (setf (entorno plan) (nucleo:hacer-entorno situacion datos))
      (protocolo:emitir a plan destino))))

(defmethod protocolo:emitir ((a web) plan destino)
  (if (streamp destino)
      (escribir-pagina a plan destino)
      (with-open-file (flujo destino :direction :output :if-exists :supersede
                                     :if-does-not-exist :create
                                     :external-format :utf-8)
        (escribir-pagina a plan flujo)))
  destino)

(defun ambito-de (coleccion)
  (nucleo:hacer-ambito
   :ligaduras (list (cons (nucleo:nombrar "fila") coleccion))
   :actual (nucleo:nombrar "fila")))

(defun nombre-js (simbolo) (string-downcase (symbol-name simbolo)))

;;; ---------------------------------------------------------------------
;;; La pagina
;;; ---------------------------------------------------------------------

(defun escribir-pagina (a plan flujo)
  (let ((situacion (situacion plan)))
    (format flujo "<!DOCTYPE html>~%<html lang=\"es\">~%<head>~%")
    (format flujo "<meta charset=\"utf-8\">~%")
    (format flujo "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">~%")
    (format flujo "<title>~a</title>~%" (nucleo:etiqueta situacion))
    (format flujo "<style>~%~a</style>~%" +estilos+)
    (format flujo "</head>~%<body>~%")
    (format flujo "<h1>~a</h1>~%" (nucleo:etiqueta situacion))
    (format flujo "<p class=\"nota\">Escribe en las casillas: lo calculado y las~
 marcas se actualizan solos.</p>~%")
    (format flujo "<div id=\"app\"></div>~%")
    (format flujo "<script>~%")
    (escribir-datos a plan flujo)
    (write-string +ayudas-js+ flujo)
    (escribir-derivaciones a plan flujo)
    (escribir-marcas a plan flujo)
    (escribir-dominios a plan flujo)
    (escribir-render a plan flujo)
    (format flujo "~%render();~%</script>~%</body>~%</html>~%")))

(defun escribir-datos (a plan flujo)
  "Los datos conocidos, como objeto de JavaScript."
  (declare (ignore a))
  (format flujo "const D = {};~%")
  (dolist (coleccion (nucleo:colecciones (situacion plan)))
    (format flujo "D[~s] = [~%" (nombre-js (nucleo:nombre coleccion)))
    (let ((filas (nucleo:filas-de (entorno plan) (nucleo:nombre coleccion))))
      (loop for fila in filas
            for primera = t then nil
            do (unless primera (format flujo ",~%"))
               (format flujo "  {~{~a~^, ~}}"
                       (loop for campo in (nucleo:campos coleccion)
                             unless (eq (nucleo:rol campo) :derivado)
                               collect (format nil "~s: ~a"
                                               (nombre-js (nucleo:nombre campo))
                                               (js-literal
                                                (gethash (nucleo:nombre campo)
                                                         (nucleo:valores fila))))))))
    (format flujo "~%];~%"))
  ;; Filas en blanco para que la coleccion pueda crecer. En una pagina esto
  ;; no hace falta -basta un boton- y por eso aqui se declara como cumplida y
  ;; no como emulada.
  (format flujo "const CRECEN = [~{~s~^, ~}];~%"
          (loop for c in (nucleo:colecciones (situacion plan))
                when (eq (nucleo:crecimiento c) :crece)
                  collect (nombre-js (nucleo:nombre c)))))

(defun escribir-derivaciones (a plan flujo)
  "Una funcion por campo derivado. Se recalculan en cada render, que es la
   forma mas simple de tener derivaciones vivas."
  (format flujo "~%const DERIV = {};~%")
  (dolist (coleccion (nucleo:colecciones (situacion plan)))
    (let ((ambito (ambito-de coleccion))
          (derivados (nucleo:campos-de-rol coleccion :derivado)))
      (when derivados
        (format flujo "DERIV[~s] = {~%" (nombre-js (nucleo:nombre coleccion)))
        (loop for campo in derivados
              for primera = t then nil
              do (unless primera (format flujo ",~%"))
                 (format flujo "  ~s: (f) => ~a"
                         (nombre-js (nucleo:nombre campo))
                         (protocolo:emitir-expresion a (nucleo:expresion campo)
                                                     ambito plan)))
        (format flujo "~%};~%")))))

(defun escribir-marcas (a plan flujo)
  (format flujo "~%const MARCAS = [~%")
  (loop for marca in (nucleo:marcas (situacion plan))
        for coleccion = (coleccion-de-la-marca marca (situacion plan))
        for primera = t then nil
        when coleccion
          do (unless primera (format flujo ",~%"))
             (write-string (protocolo:emitir-marca a marca (ambito-de coleccion) plan)
                           flujo))
  (format flujo "~%];~%"))

(defmethod protocolo:emitir-marca ((a web) marca ambito plan)
  "Una marca es una entrada del arreglo MARCAS de la pagina.

   Lleva la condicion como funcion, los campos que senala, la clase de CSS
   que le corresponde por severidad, y la explicacion tambien como funcion
   para que se recalcule con los datos."
  (let ((coleccion (nucleo:coleccion-llamada (situacion plan)
                                             (or (nucleo:coleccion marca)
                                                 (nucleo:nombre
                                                  (coleccion-de-la-marca
                                                   marca (situacion plan)))))))
    (format nil "  {nombre: ~s, coleccion: ~s, clase: ~s, campos: [~{~s~^, ~}],~%   cond: (f) => ~a,~%   explica: ~a}"
            (nombre-js (nucleo:nombre marca))
            (nombre-js (nucleo:nombre coleccion))
            (or (cdr (assoc (nucleo:severidad marca) +paleta-web+)) "informativa")
            (mapcar #'nombre-js (nucleo:alcance marca))
            (protocolo:emitir-expresion a (nucleo:condicion marca) ambito plan)
            (if (nucleo:explicacion marca)
                (format nil "(f) => ~a"
                        (protocolo:emitir-expresion a (nucleo:explicacion marca)
                                                    ambito plan))
                "null"))))

(defmethod protocolo:emitir-entrada ((a web) campo ambito plan)
  "Un campo de entrada con dominio es una entrada de DOMINIOS.

   Los valores admisibles van como FUNCION y no como lista fija: un dominio
   puede depender de los datos, y si el usuario anade una fila el desplegable
   tiene que enterarse. Es lo mismo que hace el rango que crece con lo escrito
   en la hoja de calculo, con mucho menos esfuerzo."
  (format nil "{bloquea: ~a, valores: () => ~a}"
          (if (eq (nucleo:al-violar campo) :impedir) "true" "false")
          (protocolo:emitir-expresion a (nucleo:dominio campo) ambito plan)))

(defmethod protocolo:planificar-vista ((a web) vista plan)
  "Una pagina no tiene direcciones que repartir: no hay nada que planificar."
  (declare (ignore vista)) plan)

(defmethod protocolo:emitir-vista ((a web) vista plan)
  "Una vista es una seccion de la pagina, con su titulo."
  (declare (ignore plan))
  (format nil "  {nombre: ~s, titulo: ~s, coleccion: ~s, entrada: ~a}"
          (nombre-js (nucleo:nombre vista))
          (nucleo:etiqueta vista)
          (nombre-js (nucleo:fuente vista))
          (if (nucleo:es-entrada vista) "true" "false")))

(defun coleccion-de-la-marca (marca situacion)
  (if (nucleo:coleccion marca)
      (nucleo:coleccion-llamada situacion (nucleo:coleccion marca))
      (find-if (lambda (c) (every (lambda (campo) (nucleo:campo-llamado c campo))
                                  (nucleo:alcance marca)))
               (nucleo:colecciones situacion))))

(defun escribir-dominios (a plan flujo)
  "Los valores admisibles de cada campo de entrada con dominio.

   Se emiten como funcion y no como lista fija: un dominio puede depender de
   los datos, y si el usuario anade una fila, el desplegable tiene que
   enterarse. Es lo mismo que hace el rango dinamico de la hoja de calculo,
   con mucho menos esfuerzo."
  (format flujo "~%const DOMINIOS = {};~%")
  (dolist (coleccion (nucleo:colecciones (situacion plan)))
    (dolist (campo (nucleo:campos-de-rol coleccion :entrada))
      (when (nucleo:dominio campo)
        (format flujo "DOMINIOS[~s] = ~a;~%"
                (format nil "~a.~a" (nombre-js (nucleo:nombre coleccion))
                        (nombre-js (nucleo:nombre campo)))
                (protocolo:emitir-entrada a campo (ambito-de coleccion) plan)))))
  ;; Las vistas, para el indice de la pagina.
  (format flujo "~%const VISTAS = [~%~{~a~^,~%~}~%];~%"
          (mapcar (lambda (v) (protocolo:emitir-vista a v plan))
                  (nucleo:vistas (situacion plan)))))

(defun escribir-render (a plan flujo)
  "La tabla y sus controles.

   El rol de campo decide aqui exactamente lo mismo que en la hoja de
   calculo, con otra realizacion: de entrada es un control, derivado es texto
   de solo lectura, fijo es texto. Un solo hecho del dominio, dos destinos."
  (declare (ignore a))
  (format flujo "~%const ESQUEMA = [~%")
  (loop for coleccion in (nucleo:colecciones (situacion plan))
        for primera = t then nil
        do (unless primera (format flujo ",~%"))
           (format flujo "  {nombre: ~s, etiqueta: ~s, crece: ~a, campos: [~{~a~^, ~}]}"
                   (nombre-js (nucleo:nombre coleccion))
                   (nucleo:etiqueta coleccion)
                   (if (eq (nucleo:crecimiento coleccion) :crece) "true" "false")
                   (loop for campo in (nucleo:campos coleccion)
                         collect (format nil "{n: ~s, e: ~s, rol: ~s, tipo: ~s}"
                                         (nombre-js (nucleo:nombre campo))
                                         (nucleo:etiqueta campo)
                                         (string-downcase (symbol-name (nucleo:rol campo)))
                                         (string-downcase (symbol-name
                                                           (or (nucleo:tipo campo) :texto)))))))
  (format flujo "~%];~%")
  ;; Las vistas cruzadas. Una pagina no tiene direcciones que repartir, asi
  ;; que el numero de columnas puede depender del contenido sin que eso
  ;; mueva nada: se calculan al dibujar, y si aparece un valor nuevo aparece
  ;; una columna nueva sola.
  (format flujo "~%const CRUCES = [~%~{~a~^,~%~}~%];~%"
          (loop for vista in (nucleo:vistas (situacion plan))
                when (nucleo:cruzada-p vista)
                  collect (format nil "  {titulo: ~s, coleccion: ~s, ejeFilas: ~s, ejeColumnas: ~s, celda: ~s}"
                                  (nucleo:etiqueta vista)
                                  (nombre-js (nucleo:fuente vista))
                                  (nombre-js (nucleo:eje-de-filas vista))
                                  (nombre-js (nucleo:eje-de-columnas vista))
                                  (nombre-js (nucleo:lo-que-se-muestra vista)))))
  (write-string +render-js+ flujo))
