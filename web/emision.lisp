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
      (protocolo:anotar-avisos-de-los-datos situacion (entorno plan))
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

(defun html-escapar (texto)
  "TEXTO escapado para escribirlo dentro de un elemento HTML. Una etiqueta
   como \"Precios <IVA>\" se colaba como un elemento de verdad."
  (with-output-to-string (s)
    (loop for c across texto
          do (case c
               (#\& (write-string "&amp;" s))
               (#\< (write-string "&lt;" s))
               (#\> (write-string "&gt;" s))
               (#\" (write-string "&quot;" s))
               (#\' (write-string "&#39;" s))
               (t (write-char c s))))))

;;; ---------------------------------------------------------------------
;;; La pagina
;;; ---------------------------------------------------------------------

(defun escribir-pagina (a plan flujo)
  (let ((situacion (situacion plan)))
    (format flujo "<!DOCTYPE html>~%<html lang=\"es\">~%<head>~%")
    (format flujo "<meta charset=\"utf-8\">~%")
    (format flujo "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">~%")
    (format flujo "<title>~a</title>~%" (html-escapar (nucleo:etiqueta situacion)))
    (format flujo "<style>~%~a</style>~%" +estilos+)
    (format flujo "</head>~%<body>~%")
    (format flujo "<h1 id=\"arriba\">~a</h1>~%" (html-escapar (nucleo:etiqueta situacion)))
    ;; La ayuda solo si hay algo que escribir.
    (when (algo-que-escribir-p situacion)
      (format flujo "<p class=\"nota\">Escribe en las casillas: lo calculado y las ~
                 marcas se actualizan solos.</p>~%"))
    (format flujo "<nav id=\"indice\" class=\"indice\"></nav>~%")
    (format flujo "<div id=\"app\"></div>~%")
    (format flujo "<script>~%")
    (escribir-datos a plan flujo)
    (escribir-parametros plan flujo)
    (write-string +ayudas-js+ flujo)
    (escribir-derivaciones a plan flujo)
    (escribir-marcas a plan flujo)
    (escribir-dominios a plan flujo)
    (escribir-ordenes plan flujo)
    (escribir-render a plan flujo)
    (write-string +render-js+ flujo)
    (format flujo "~%construir();~%</script>~%</body>~%</html>~%")))

(defun escribir-ordenes (plan flujo)
  "El orden declarado de cada coleccion que lo tiene, como ORDENES.

   La pagina lo necesita para volver a ordenar una coleccion cuando el
   usuario anade una fila o cambia un campo del orden (fase 2, hueco C3):
   el evaluador ve las filas ordenadas, y la fila anterior de VECINO es la
   anterior del arreglo, asi que el arreglo tiene que estar en ese orden."
  (format flujo "~%const ORDENES = {~{~a~^, ~}};~%"
          (loop for coleccion in (nucleo:colecciones (situacion plan))
                when (nucleo:orden coleccion)
                  collect (format nil "~/situacion.web::js/: [~{~/situacion.web::js/~^, ~}]"
                                  (nombre-js (nucleo:nombre coleccion))
                                  (mapcar #'nombre-js (nucleo:orden coleccion))))))

(defun algo-que-escribir-p (situacion)
  "Cierto si alguna coleccion tiene un campo de entrada, o alguna crece, o
   hay algun parametro de entrada."
  (or (some (lambda (c) (or (nucleo:campos-de-rol c :entrada)
                            (eq (nucleo:crecimiento c) :crece)))
            (nucleo:colecciones situacion))
      (some (lambda (p) (eq (nucleo:rol p) :entrada))
            (nucleo:parametros situacion))))

(defun escribir-datos (a plan flujo)
  "Los datos conocidos, como objeto de JavaScript."
  (declare (ignore a))
  (format flujo "const D = {};~%")
  (dolist (coleccion (nucleo:colecciones (situacion plan)))
    (format flujo "D[~/situacion.web::js/] = [~%" (nombre-js (nucleo:nombre coleccion)))
    (let ((filas (nucleo:filas-de (entorno plan) (nucleo:nombre coleccion))))
      (loop for fila in filas
            for primera = t then nil
            do (unless primera (format flujo ",~%"))
               (format flujo "  {~{~a~^, ~}}"
                       (loop for campo in (nucleo:campos coleccion)
                             unless (eq (nucleo:rol campo) :derivado)
                               collect (format nil "~/situacion.web::js/: ~a"
                                               (nombre-js (nucleo:nombre campo))
                                               (js-literal
                                                (gethash (nucleo:nombre campo)
                                                         (nucleo:valores fila))))))))
    (format flujo "~%];~%"))
  ;; Filas en blanco para que la coleccion pueda crecer. En una pagina esto
  ;; no hace falta -basta un boton- y por eso aqui se declara como cumplida y
  ;; no como emulada.
  (format flujo "const CRECEN = [~{~/situacion.web::js/~^, ~}];~%"
          (loop for c in (nucleo:colecciones (situacion plan))
                when (eq (nucleo:crecimiento c) :crece)
                  collect (nombre-js (nucleo:nombre c)))))

(defun escribir-parametros (plan flujo)
  "Los parametros de entrada: su valor en P, que es lo que leen las
   derivaciones y las marcas, y su descripcion en PARAMETROS, que es lo que
   dibuja la seccion donde se editan (web/dibujo.lisp).

   Hasta el 2026-10-21 la pagina copiaba el valor de todo parametro en el
   codigo, y el tope del Saul no se podia cambiar en ella. Los fijos se
   siguen copiando y no aparecen aqui."
  (let ((de-entrada (remove-if-not (lambda (p) (eq (nucleo:rol p) :entrada))
                                   (nucleo:parametros (situacion plan)))))
    (format flujo "const P = {~{~a~^, ~}};~%"
            (loop for p in de-entrada
                  collect (format nil "~/situacion.web::js/: ~a"
                                  (nombre-js (nucleo:nombre p))
                                  (js-literal (nucleo:valor p)))))
    (format flujo "const PARAMETROS = [~{~a~^, ~}];~%"
            (loop for p in de-entrada
                  collect (format nil "{n: ~/situacion.web::js/, e: ~/situacion.web::js/, tipo: ~/situacion.web::js/}"
                                  (nombre-js (nucleo:nombre p))
                                  (nucleo:etiqueta p)
                                  (string-downcase (symbol-name (nucleo:tipo p))))))))

(defun escribir-derivaciones (a plan flujo)
  "Una funcion por campo derivado. La pagina las recalcula todas tras cada
   cambio, hasta punto fijo, y ACTUALIZAR lleva los valores a lo dibujado
   (web/dibujo.lisp)."
  (format flujo "~%const DERIV = {};~%")
  (dolist (coleccion (nucleo:colecciones (situacion plan)))
    (let ((ambito (ambito-de coleccion))
          (derivados (nucleo:campos-de-rol coleccion :derivado)))
      (when derivados
        (format flujo "DERIV[~/situacion.web::js/] = {~%" (nombre-js (nucleo:nombre coleccion)))
        (loop for campo in derivados
              for primera = t then nil
              do (unless primera (format flujo ",~%"))
                 (format flujo "  ~/situacion.web::js/: (f) => ~a"
                         (nombre-js (nucleo:nombre campo))
                         ;; Un campo booleano vale "si" o "no", nunca true o
                         ;; false: es lo que escriben las otras dos.
                         (handler-case
                             (let ((js (protocolo:emitir-expresion
                                        a (nucleo:expresion campo) ambito plan)))
                               (if (nucleo:campo-booleano-p campo)
                                   (format nil "BOOL(~a)" js)
                                   js))
                           ;; Sin traduccion: la celda lo dice, el informe
                           ;; anota el rechazo, y la pagina sale entera.
                           (error (e)
                             (protocolo:rebajar-en-informe
                              'protocolo:con-derivacion-viva
                              (format nil "~(~a~) se recalcula" (nucleo:nombre campo))
                              :rechaza
                              (format nil "~(~a~) no tiene traduccion a la pagina: ~a"
                                      (nucleo:nombre campo) e))
                             (js-cadena protocolo:+pieza-ausente+)))))
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
    ;; Una marca :POR-CAMPO (fase 2, hueco C7) recibe, ademas de la fila, el
    ;; valor del campo que se esta mirando, y lo dice con porCampo.
    (let ((parametros (if (nucleo:por-campo marca)
                          (format nil "(f, ~a)" (js-variable-de-valor (nucleo:por-campo marca)))
                          "(f)")))
      (format nil "  {nombre: ~/situacion.web::js/, leyenda: ~/situacion.web::js/, coleccion: ~/situacion.web::js/, clase: ~/situacion.web::js/, campos: [~{~/situacion.web::js/~^, ~}],~@[ porCampo: ~a,~]~%   cond: ~a => ~a,~%   explica: ~a}"
              (nombre-js (nucleo:nombre marca))
              (substitute #\Space #\- (nombre-js (nucleo:nombre marca)))
              (nombre-js (nucleo:nombre coleccion))
              (or (cdr (assoc (nucleo:severidad marca) +paleta-web+)) "informativa")
              (mapcar #'nombre-js (nucleo:alcance marca))
              (when (nucleo:por-campo marca) "true")
              parametros
              (js-condicion a (nucleo:condicion marca) ambito plan)
              (if (nucleo:explicacion marca)
                  (format nil "~a => ~a" parametros
                          (protocolo:emitir-expresion a (nucleo:explicacion marca)
                                                      ambito plan))
                  "null")))))

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
  (format nil "  {nombre: ~/situacion.web::js/, titulo: ~/situacion.web::js/, coleccion: ~/situacion.web::js/, entrada: ~a}"
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
        (format flujo "DOMINIOS[~/situacion.web::js/] = ~a;~%"
                (format nil "~a.~a" (nombre-js (nucleo:nombre coleccion))
                        (nombre-js (nucleo:nombre campo)))
                (protocolo:emitir-entrada a campo (ambito-de coleccion) plan)))))
  ;; Las vistas, para el indice de la pagina.
  (format flujo "~%const VISTAS = [~%~{~a~^,~%~}~%];~%"
          (mapcar (lambda (v) (protocolo:emitir-vista a v plan))
                  (nucleo:vistas (situacion plan)))))

(defun clave-relacionada (plan campo)
  "Si CAMPO es una relacion uno a muchos, la clave de la coleccion
   relacionada como arreglo de JavaScript; si no, null. La celda la usa para
   nombrar cada fila relacionada en vez de imprimir el objeto."
  (let ((expresion (nucleo:expresion campo)))
    (if (typep expresion 'nucleo:relacionadas)
        (format nil "[~{~/situacion.web::js/~^, ~}]"
                (mapcar #'nombre-js
                        (nucleo:clave (nucleo:coleccion-llamada
                                       (situacion plan)
                                       (nucleo:coleccion expresion)))))
        "null")))

(defun campo-js (plan campo)
  "La descripcion de CAMPO para la pagina: nombre, etiqueta, rol, tipo y, si
   es una relacion uno a muchos, la clave de las filas relacionadas."
  (format nil "{n: ~/situacion.web::js/, e: ~/situacion.web::js/, rol: ~/situacion.web::js/, tipo: ~/situacion.web::js/, clave: ~a~@[, dec: ~d~]}"
          (nombre-js (nucleo:nombre campo))
          (nucleo:etiqueta campo)
          (string-downcase (symbol-name (nucleo:rol campo)))
          (string-downcase (symbol-name (or (nucleo:tipo campo) :texto)))
          (clave-relacionada plan campo)
          ;; Los decimales que el campo declara (fase 2, hueco C6).
          (nucleo:decimales campo)))

(defun columna-de-estado (coleccion)
  "El rotulo de la columna de estado de COLECCION: \"Estado\", o \"Avisos\" si
   ya hay un campo con esa etiqueta y se leerian dos columnas iguales."
  (if (find "Estado" (nucleo:campos coleccion) :key #'nucleo:etiqueta :test #'string-equal)
      "Avisos"
      "Estado"))

(defun escribir-render (a plan flujo)
  "Las tablas y las rejillas que dibuja la pagina.

   El rol de campo decide aqui exactamente lo mismo que en la hoja de
   calculo, con otra realizacion: de entrada es un control, derivado es texto
   de solo lectura, fijo es texto. Un solo hecho del dominio, dos destinos."
  (let* ((situacion (situacion plan))
         (tablas (append
                  (mapcar (lambda (v)
                            (list (nucleo:nombre v) (nucleo:etiqueta v)
                                  (nucleo:coleccion-llamada situacion (nucleo:fuente v))
                                  (nucleo:agrupacion v)))
                          (nucleo:vistas-de-lista situacion))
                  (mapcar (lambda (c) (list nil (nucleo:etiqueta c) c nil))
                          (nucleo:colecciones-sin-vista-de-lista situacion))))
         (cruzadas (remove-if-not #'nucleo:cruzada-p (nucleo:vistas situacion))))
    ;; Una tabla por vista de lista, y una por coleccion que ninguna presenta
    ;; (nucleo/tablas.lisp). Antes habia una por coleccion, y dos vistas de
    ;; la misma coleccion salian como una sola tabla.
    (format flujo "~%const TABLAS = [~%~{~a~^,~%~}~%];~%"
            (loop for (vista titulo coleccion agrupacion) in tablas
                  collect (format nil "  {id: ~/situacion.web::js/, vista: ~/situacion.web::js/, titulo: ~/situacion.web::js/, coleccion: ~/situacion.web::js/, crece: ~a, agrupa: ~a, columnaEstado: ~/situacion.web::js/, campos: [~{~a~^, ~}]}"
                                  (format nil "t-~a" (nombre-js (or vista (nucleo:nombre coleccion))))
                                  (nombre-js (or vista (nucleo:nombre coleccion)))
                                  titulo
                                  (nombre-js (nucleo:nombre coleccion))
                                  (if (eq (nucleo:crecimiento coleccion) :crece) "true" "false")
                                  (if agrupacion
                                      (format nil "~/situacion.web::js/" (nombre-js agrupacion))
                                      "null")
                                  (columna-de-estado coleccion)
                                  (mapcar (lambda (c) (campo-js plan c)) (nucleo:campos coleccion)))))
    ;; Las vistas cruzadas. Una pagina no tiene direcciones que repartir, asi
    ;; que el numero de columnas puede depender del contenido sin que eso
    ;; mueva nada: se calculan al dibujar.
    (format flujo "~%const CRUCES = [~%~{~a~^,~%~}~%];~%"
            (mapcar (lambda (v) (escribir-cruce a plan v)) cruzadas))
    ;; El orden en que se dibujan: las vistas como se declararon, y despues
    ;; las colecciones sin vista de lista. Es tambien el indice de la pagina.
    (format flujo "~%const ORDEN = [~%~{~a~^,~%~}~%];~%"
            (append
             (loop for v in (nucleo:vistas situacion)
                   collect (if (nucleo:cruzada-p v)
                               (format nil "  {tipo: 'cruce', indice: ~d}" (position v cruzadas))
                               (format nil "  {tipo: 'tabla', indice: ~d}"
                                       (position (nucleo:nombre v) tablas :key #'first))))
             (loop for i from (length (nucleo:vistas-de-lista situacion)) below (length tablas)
                   collect (format nil "  {tipo: 'tabla', indice: ~d}" i))))))

(defun escribir-cruce (a plan vista)
  "La descripcion de una vista cruzada para la pagina."
  (let* ((coleccion (nucleo:coleccion-llamada (situacion plan) (nucleo:fuente vista)))
         (campo-celda (nucleo:campo-llamado coleccion (nucleo:lo-que-se-muestra vista)))
         (campo-filas (nucleo:campo-llamado coleccion (nucleo:eje-de-filas vista))))
    (format nil "  {id: ~/situacion.web::js/, titulo: ~/situacion.web::js/, coleccion: ~/situacion.web::js/, ejeFilas: ~/situacion.web::js/, etiquetaFilas: ~/situacion.web::js/, ejeColumnas: ~/situacion.web::js/, etiquetaColumnas: ~/situacion.web::js/, celda: ~/situacion.web::js/, campoCelda: ~a, entrada: ~a, orden: ~a, secciones: ~a, etiquetaSecciones: ~/situacion.web::js/, filtro: ~a, dominioFilas: ~a, dominioColumnas: ~a, dominioSecciones: ~a}"
            (format nil "c-~a" (nombre-js (nucleo:nombre vista)))
            (nucleo:etiqueta vista)
            (nombre-js (nucleo:fuente vista))
            (nombre-js (nucleo:eje-de-filas vista))
            (if campo-filas (nucleo:etiqueta campo-filas)
                (string-capitalize (symbol-name (nucleo:eje-de-filas vista))))
            (nombre-js (nucleo:eje-de-columnas vista))
            (etiqueta-de-eje coleccion (nucleo:eje-de-columnas vista))
            (nombre-js (nucleo:lo-que-se-muestra vista))
            (if campo-celda (campo-js plan campo-celda) "null")
            (if (nucleo:es-entrada vista) "true" "false")
            (if (nucleo:orden coleccion)
                (format nil "[~{~/situacion.web::js/~^, ~}]"
                        (mapcar #'nombre-js (nucleo:orden coleccion)))
                "null")
            ;; El campo por el que se parte, o null. La pagina calcula las
            ;; secciones al dibujar: si manana aparece un grupo nuevo,
            ;; aparece una tabla nueva sin regenerar nada.
            (if (nucleo:secciones vista)
                (format nil "~/situacion.web::js/" (nombre-js (nucleo:secciones vista)))
                "null")
            (if (nucleo:secciones vista)
                (etiqueta-de-eje coleccion (nucleo:secciones vista))
                "")
            ;; El filtro va como FUNCION, no como lista de filas: se reevalua
            ;; en cada puesta al dia, asi que si el usuario escribe algo que
            ;; hace que una fila deje de cumplirlo, desaparece sola.
            (if (nucleo:filtro vista)
                (format nil "(f) => ~a"
                        (js-condicion a (nucleo:filtro vista) (ambito-de coleccion) plan))
                "null")
            ;; El dominio declarado de cada eje (fase 2, hueco C1), como
            ;; FUNCION por la misma razon que los de DOMINIOS: uno escrito
            ;; (los ... de C) tiene que enterarse si C crece en la pagina.
            (dominio-js a plan coleccion (nucleo:dominio-de-filas vista))
            (dominio-js a plan coleccion (nucleo:dominio-de-columnas vista))
            (dominio-js a plan coleccion (nucleo:dominio-de-secciones vista)))))

(defun etiqueta-de-eje (coleccion campo)
  "Como se llama el campo CAMPO de COLECCION en la pagina."
  (let ((declarado (nucleo:campo-llamado coleccion campo)))
    (if declarado
        (nucleo:etiqueta declarado)
        (string-downcase (symbol-name campo)))))

(defun dominio-js (a plan coleccion dominio)
  "La funcion que da los valores de DOMINIO, o null si no se declaro."
  (if dominio
      (format nil "() => ~a"
              (protocolo:emitir-expresion a dominio (ambito-de coleccion) plan))
      "null"))
