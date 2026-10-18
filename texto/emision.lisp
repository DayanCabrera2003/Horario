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
      (protocolo:anotar-avisos-de-los-datos situacion entorno)
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
    ;; Las vistas en el orden en que se declararon: una rejilla por seccion
    ;; si es cruzada, una tabla si es de lista. Despues, las colecciones que
    ;; ninguna vista de lista presenta, que es donde estan sus datos
    ;; (nucleo/tablas.lisp).
    (dolist (vista (nucleo:vistas situacion))
      (if (nucleo:cruzada-p vista)
          (progn
            (dolist (valor (secciones-de plan vista))
              (escribir-cruzada a plan vista flujo valor))
            ;; Los valores que caen fuera del dominio declarado salen al
            ;; final de su eje; aqui se dice cuales, una vez por vista.
            (let ((aviso (nucleo:aviso-fuera-de-dominio (entorno plan) vista)))
              (when aviso (format flujo "Aviso: ~a~%~%" aviso))))
          (escribir-coleccion a plan
                              (nucleo:coleccion-llamada situacion (nucleo:fuente vista))
                              flujo (nucleo:etiqueta vista) (nucleo:agrupacion vista))))
    (dolist (coleccion (nucleo:colecciones-sin-vista-de-lista situacion))
      (escribir-coleccion a plan coleccion flujo (nucleo:etiqueta coleccion) nil))))

(defun secciones-de (plan vista)
  "Los valores por los que se parte VISTA, ordenados, o (NIL) si no se parte.

   Devolver una lista de un solo elemento cuando no hay particion deja el
   recorrido igual en los dos casos: se escribe una tabla por elemento. Las
   secciones salen de las filas PRESENTABLES: si el filtro deja fuera a un
   profesor entero, no tiene que aparecer su tabla vacia."
  (nucleo:secciones-de-vista (entorno plan) vista))

(defun filas-presentables (plan vista)
  "Las filas que VISTA presenta: las de su coleccion que pasan su filtro.

   El filtro es de presentacion y no toca los datos: la coleccion sigue
   entera en el entorno, asi que los agregados y las marcas siguen viendo
   las filas que aqui se esconden."
  (nucleo:filas-que-presenta (entorno plan) vista))

(defun filas-de-la-seccion (plan vista valor)
  "Las filas de VISTA que caen en la seccion VALOR.

   Con VALOR en NIL son todas las presentables: es el caso de la vista que no
   se parte."
  (let ((filas (filas-presentables plan vista)))
    (if (null valor)
        filas
        (remove-if-not
         (lambda (f) (nucleo:iguales-p
                      valor (nucleo:valor-de-campo (entorno plan) f
                                                   (nucleo:secciones vista))))
         filas))))

(defun filas-del-cruce (plan filas vista valor-fila valor-columna)
  "TODAS las filas que caen en ese cruce, en orden.

   Busca dentro de FILAS y no en la coleccion entera. Es lo que hace que la
   particion signifique algo: con dos grupos en la misma coleccion, los dos
   caen en el mismo (turno, dia) y sin restringir se dibujaria el primero.

   Devuelve la lista entera y no la primera a proposito. Normalmente trae una
   sola fila, porque los ejes determinan la fila y el analisis lo exige. Trae
   mas cuando la vista declaro (:UNICA-SALVO <marca>): entonces el conflicto
   existe, la marca lo nombra, y hay que ensenarlo en vez de elegir."
  (remove-if-not
   (lambda (f)
     (and (nucleo:iguales-p valor-fila
                            (nucleo:valor-de-campo (entorno plan) f
                                                   (nucleo:eje-de-filas vista)))
          (nucleo:iguales-p valor-columna
                            (nucleo:valor-de-campo (entorno plan) f
                                                   (nucleo:eje-de-columnas vista)))))
   filas))

(defun texto-de-la-casilla (plan vista filas-en-la-casilla campo-celda)
  "Lo que se escribe en una casilla del cruce.

   Con una sola fila, su valor. Con mas de una, todos separados por barras:
   la casilla ensena el choque en vez de elegir uno y callarse, que es lo que
   hacia antes."
  (format nil "~{~a~^ / ~}"
          (loop for f in filas-en-la-casilla
                collect (en-una-linea
                         (nucleo:como-texto
                          (nucleo:valor-de-campo (entorno plan) f campo-celda))))))

(defun escribir-cruzada (a plan vista flujo &optional valor-de-seccion)
  "La vista cruzada, como rejilla de texto alineada.

   Texto plano si puede con esto: alinear columnas es lo unico que sabe
   hacer. Lo que no puede es que el usuario escriba en ella.

   VALOR-DE-SECCION es el valor del campo por el que se parte la vista, o NIL
   si no se parte. Las casillas se llenan con las filas de ESA seccion; los
   ejes son los de la vista entera."
  (let* ((situacion (situacion plan))
         (coleccion (nucleo:coleccion-llamada situacion (nucleo:fuente vista)))
         (filas-fuente (filas-de-la-seccion plan vista valor-de-seccion))
         ;; Los ejes son los de la vista entera, no los de esta seccion: todas
         ;; las secciones se leen con las mismas filas y columnas
         ;; (nucleo/ejes.lisp).
         (filas (nucleo:valores-de-eje (entorno plan) vista (nucleo:eje-de-filas vista)))
         (columnas (nucleo:valores-de-eje (entorno plan) vista
                                          (nucleo:eje-de-columnas vista)))
         (campo-celda (nucleo:campo-llamado coleccion (nucleo:lo-que-se-muestra vista)))
         (campo-filas (nucleo:campo-llamado coleccion (nucleo:eje-de-filas vista)))
         (encabezados (cons (if campo-filas
                                (nucleo:etiqueta campo-filas)
                                (string-capitalize (symbol-name (nucleo:eje-de-filas vista))))
                            (mapcar (lambda (c) (en-una-linea (nucleo:como-texto c)))
                                    columnas)))
         (celdas (loop for vf in filas
                       collect (cons (en-una-linea (nucleo:como-texto vf))
                                     (loop for vc in columnas
                                           collect (texto-de-la-casilla
                                                    plan vista
                                                    (filas-del-cruce plan filas-fuente
                                                                     vista vf vc)
                                                    (nucleo:nombre campo-celda)))))))
    (format flujo "~a~@[ - ~a~]~%" (nucleo:etiqueta vista)
            (when valor-de-seccion (nucleo:como-texto valor-de-seccion)))
    (let ((anchos (calcular-anchos encabezados celdas)))
      (escribir-fila flujo encabezados anchos)
      (format flujo "~a~%" (raya anchos))
      (dolist (c celdas) (escribir-fila flujo c anchos)))
    (format flujo "~%")))

(defun texto-de-valor (plan valor)
  "Como se escribe en una celda un valor ya calculado.

   Una relacion uno a muchos llega como lista de filas del evaluador: cada
   una se escribe por su clave y se separan con comas. Es lo que promete el
   informe de esta arquitectura para CON-RELACION-UNO-A-MUCHOS."
  (if (and (consp valor) (typep (first valor) 'nucleo:fila))
      (format nil "~{~a~^, ~}"
              (loop for fila in valor
                    collect (format nil "~{~a~^ ~}"
                                    (loop for campo in (nucleo:clave (nucleo:coleccion fila))
                                          collect (nucleo:como-texto
                                                   (nucleo:valor-de-campo
                                                    (entorno plan) fila campo))))))
      (en-una-linea (nucleo:como-texto valor))))

(defun en-una-linea (texto)
  "TEXTO sin saltos de linea: una celda de una tabla alineada es una linea.
   Un salto de linea dentro de un valor partia la fila en dos."
  (substitute-if #\Space (lambda (c) (member c '(#\Newline #\Return #\Tab))) texto))

(defun escribir-coleccion (a plan coleccion flujo titulo agrupacion)
  "La tabla de COLECCION con TITULO, agrupada por AGRUPACION si no es NIL:
   un renglon de cabecera por grupo y debajo sus filas. La tabla es la misma
   agrupada o no; lo que cambia es que se puede leer."
  (let* ((nombre (nucleo:nombre coleccion))
         (filas (rest (assoc nombre (evaluado plan))))
         (campos (nucleo:campos coleccion))
         ;; La columna de estado es la degradacion del marcado visual: donde
         ;; una hoja de calculo pondria un relleno, aqui va una palabra.
         (encabezados (append (mapcar #'nucleo:etiqueta campos)
                              (list (rotulo-de-estado coleccion))))
         (celdas (loop for fila in filas
                       collect (append
                                (loop for campo in campos
                                      collect (texto-de-valor
                                               plan
                                               (cdr (assoc (nucleo:nombre campo)
                                                           (car fila)))))
                                (list (en-una-linea
                                       (texto-del-estado a plan coleccion fila))))))
         (anchos (calcular-anchos encabezados celdas)))
    (format flujo "~a~%" titulo)
    (escribir-fila flujo encabezados anchos)
    (format flujo "~a~%" (raya anchos))
    (loop for (indice . cabecera)
            in (nucleo:filas-en-orden-de-presentacion (entorno plan) nombre agrupacion)
          do (when cabecera
               (format flujo "  ~a~%" (en-una-linea (nucleo:como-texto cabecera))))
             (escribir-fila flujo (nth indice celdas) anchos))
    ;; Los dominios de entrada, al pie: la degradacion del desplegable.
    (dolist (campo campos)
      (when (and (eq (nucleo:rol campo) :entrada) (nucleo:dominio campo))
        (format flujo "~%  ~a~%"
                (en-una-linea
                 (protocolo:emitir-entrada a campo (nucleo:hacer-ambito) plan)))))
    (format flujo "~%")))

(defun rotulo-de-estado (coleccion)
  "\"Estado\", o \"Avisos\" si ya hay un campo con esa etiqueta."
  (if (find "Estado" (nucleo:campos coleccion) :key #'nucleo:etiqueta :test #'string-equal)
      "Avisos"
      "Estado"))

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
  "El estado de una fila, en palabras: la explicacion de cada marca que
   dispara, o su nombre si no la trae. Es NUCLEO:TEXTO-DE-ESTADO, el mismo
   texto que escriben la hoja de calculo y la pagina."
  (declare (ignore a))
  (let ((fila-real (fila-del-entorno plan coleccion fila)))
    (if fila-real
        (nucleo:texto-de-estado (entorno plan) fila-real)
        "")))

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
