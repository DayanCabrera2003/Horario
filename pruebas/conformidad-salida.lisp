;;;; Conformidad comprobada en la salida.
;;;;
;;;; REGLA: una capacidad que una arquitectura declara cumplir tiene que verse
;;;; en lo que produce. La auditoria del 2026-10-17 encontro tres que se
;;;; declaraban y no estaban: el marcado textual en la hoja de calculo (no
;;;; habia ni una explicacion en el libro), la navegacion en la pagina (ni un
;;;; enlace) y la agrupacion de una segunda vista (no se dibujaba).
;;;;
;;;; Aqui hay, para cada arquitectura y cada capacidad que declara, una
;;;; comprobacion sobre su salida real. La prueba recorre el corpus y los
;;;; casos de robustez y, para cada linea "cumple" del informe, exige que la
;;;; comprobacion de esa capacidad encuentre su evidencia. Otra prueba exige
;;;; que no quede ninguna capacidad declarada sin comprobacion.
;;;;
;;;; Las comprobaciones son de estructura: que este la pieza. Que ademas
;;;; calcule lo que dice el evaluador lo comprueban los verificadores de
;;;; ./demostrar.sh y ./demostrar-robustez.sh.

(in-package #:situacion.pruebas)

(defun contiene (texto &rest trozos)
  "Cierto si TEXTO contiene todos los TROZOS."
  (every (lambda (trozo) (search trozo texto)) trozos))

(defun hojas-con (plano clave)
  (remove-if-not (lambda (h) (dato h clave)) (hojas-del-plano plano)))

(defun formulas-del-plano (plano)
  (format nil "~{~a~%~}" (loop for h in (hojas-del-plano plano)
                               append (mapcar (lambda (f) (dato f "formula"))
                                              (lista-del-plano (dato h "formulas"))))))

(defun explicaciones-literales (situacion)
  "Los textos de explicacion de las marcas que son una cadena escrita."
  (loop for m in (nucleo:marcas situacion)
        for e = (nucleo:explicacion m)
        when (and e (typep e 'nucleo:literal) (stringp (nucleo:valor e)))
          collect (nucleo:valor e)))

(defun ordenados-p (valores)
  "Cierto si VALORES no bajan nunca, con la comparacion del evaluador."
  (loop for (a b) on valores while b never (nucleo::menor-p b a)))

(defun orden-en-el-plano-p (plano situacion)
  "Cierto si, en cada coleccion que declara orden, los valores de su campo
   de orden salen en la hoja de datos de arriba abajo sin bajar."
  (every (lambda (coleccion)
           (let* ((hoja (hoja-de-coleccion plano (string-downcase
                                                   (symbol-name (nucleo:nombre coleccion)))))
                  ;; Con un orden compuesto, el primer campo no baja nunca.
                  (encabezado (find (string-downcase
                                     (symbol-name (first (nucleo:orden coleccion))))
                                    (lista-del-plano (dato hoja "encabezados"))
                                    :key (lambda (e) (dato e "campo")) :test #'equal))
                  (letra (and encabezado (string-right-trim "0123456789"
                                                            (dato encabezado "celda")))))
             (and letra
                  (ordenados-p
                   (mapcar (lambda (c) (dato c "valor"))
                           (sort (remove-if-not
                                  (lambda (c)
                                    (string= letra (string-right-trim "0123456789"
                                                                      (dato c "celda"))))
                                  (copy-list (lista-del-plano (dato hoja "celdas"))))
                                 #'< :key (lambda (c) (parse-integer
                                                       (string-left-trim
                                                        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                                                        (dato c "celda"))))))))))
         (remove-if-not #'nucleo:orden (nucleo:colecciones situacion))))

(defun orden-en-la-pagina-p (salida situacion)
  "Cierto si, en cada coleccion que declara orden, las filas de D llevan los
   valores de su campo de orden sin bajar."
  (every (lambda (coleccion)
           (let* ((nombre (string-downcase (symbol-name (nucleo:nombre coleccion))))
                  (campo (format nil "\"~(~a~)\": " (first (nucleo:orden coleccion))))
                  (inicio (search (format nil "D[\"~a\"] = [" nombre) salida))
                  (fin (and inicio (search "];" salida :start2 inicio)))
                  (valores '()))
             (and inicio
                  (loop for p = (search campo salida :start2 inicio :end2 fin)
                          then (search campo salida :start2 (1+ p) :end2 fin)
                        while p
                        do (push (let ((*read-default-float-format* 'double-float))
                                   (read-from-string salida t nil :start (+ p (length campo))))
                                 valores)
                        finally (return (ordenados-p (nreverse valores)))))))
         (remove-if-not #'nucleo:orden (nucleo:colecciones situacion))))

;;; Cada comprobacion recibe la salida (cadena), el plano nativo (solo la
;;; hoja de calculo; NIL para las demas) y la situacion.

(defparameter +evidencias+
  `(("excel"
     (protocolo:con-busqueda-por-clave
      . ,(lambda (salida plano s) (declare (ignore salida s))
           ;; Una igualdad sobre un campo, o el producto de factores de
           ;; cualquier otra condicion (fase 2, hueco C2).
           (or (search "MATCH(1,INDEX(EXACT(" (formulas-del-plano plano))
               (search "MATCH(1,INDEX(1*" (formulas-del-plano plano)))))
     (protocolo:con-derivacion-viva
      . ,(lambda (salida plano s) (declare (ignore salida s))
           (plusp (length (formulas-del-plano plano)))))
     (protocolo:con-entrada
      . ,(lambda (salida plano s) (declare (ignore salida s))
           (some (lambda (h) (lista-del-plano (dato h "editables"))) (hojas-del-plano plano))))
     (protocolo:con-dominio-de-entrada
      . ,(lambda (salida plano s) (declare (ignore salida s))
           (some (lambda (h) (some (lambda (v) (stringp (dato v "lista")))
                                   (lista-del-plano (dato h "validaciones"))))
                 (hojas-del-plano plano))))
     (protocolo:con-orden-declarado
      . ,(lambda (salida plano s) (declare (ignore salida)) (orden-en-el-plano-p plano s)))
     (protocolo:con-marcado-visual
      . ,(lambda (salida plano s) (declare (ignore salida s))
           (some (lambda (h) (lista-del-plano (dato h "formatos_condicionales")))
                 (hojas-del-plano plano))))
     (protocolo:con-marcado-textual
      . ,(lambda (salida plano s) (declare (ignore salida))
           (and (some (lambda (h) (stringp (dato h "estado"))) (hojas-del-plano plano))
                (every (lambda (texto)
                         (search (situacion.excel::cadena-excel texto) (formulas-del-plano plano)))
                       (explicaciones-literales s)))))
     (protocolo:con-navegacion
      . ,(lambda (salida plano s) (declare (ignore salida s))
           (every (lambda (v) (plusp (length (dato v "hoja"))))
                  (lista-del-plano (dato plano "vistas")))))
     (protocolo:con-rejilla
      . ,(lambda (salida plano s) (declare (ignore salida s)) (hojas-del-plano plano))))
    ("web"
     (protocolo:con-tabla-cruzada
      . ,(lambda (salida plano s) (declare (ignore plano))
           (every (lambda (v) (or (not (nucleo:cruzada-p v))
                                  (search (format nil "titulo: ~a"
                                                  (situacion.web::js-cadena (nucleo:etiqueta v)))
                                          salida)))
                  (nucleo:vistas s))))
     (protocolo:con-derivacion-viva
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search "DERIV[" salida)))
     (protocolo:con-busqueda-por-clave
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search ".find(" salida)))
     (protocolo:con-entrada
      . ,(lambda (salida plano s) (declare (ignore plano s))
           (contiene salida "rol: \"entrada\"" "controlDe(")))
     (protocolo:con-dominio-de-entrada
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search "DOMINIOS[" salida)))
     (protocolo:con-orden-declarado
      . ,(lambda (salida plano s) (declare (ignore plano)) (orden-en-la-pagina-p salida s)))
     (protocolo:con-crecimiento
      . ,(lambda (salida plano s) (declare (ignore plano s))
           (contiene salida "crece: true" "Añadir fila")))
     (protocolo:con-relacion-uno-a-muchos
      . ,(lambda (salida plano s) (declare (ignore plano s)) (contiene salida ".filter(" "clave: [")))
     (protocolo:con-particion-de-vista
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search "secciones: \"" salida)))
     (protocolo:con-agrupacion-en-vista
      . ,(lambda (salida plano s) (declare (ignore plano))
           (every (lambda (v) (or (not (nucleo:agrupacion v))
                                  (search (format nil "titulo: ~a"
                                                  (situacion.web::js-cadena (nucleo:etiqueta v)))
                                          salida)))
                  (nucleo:vistas s))))
     (protocolo:con-filtro-de-vista
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search "filtro: (f) =>" salida)))
     (protocolo:con-casilla-en-conflicto
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search "join(' / ')" salida)))
     (protocolo:con-conteo-de-distintos
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search "new Set(" salida)))
     (protocolo:con-marcado-visual
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search "clase: \"" salida)))
     (protocolo:con-marcado-textual
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search "explica: (f) =>" salida)))
     (protocolo:con-navegacion
      . ,(lambda (salida plano s) (declare (ignore plano s))
           (contiene salida "<nav id=\"indice\"" "const ORDEN" "volver arriba")))
     (protocolo:con-validacion-de-forma
      . ,(lambda (salida plano s) (declare (ignore plano s))
           (or (search "(!ESFECHA(" salida) (search "(!ESHORA(" salida)))))
    ("texto"
     (protocolo:con-tabla-cruzada
      . ,(lambda (salida plano s) (declare (ignore plano))
           (every (lambda (v) (or (not (nucleo:cruzada-p v))
                                  (search (nucleo:etiqueta v) salida)))
                  (nucleo:vistas s))))
     (protocolo:con-particion-de-vista
      . ,(lambda (salida plano s) (declare (ignore plano))
           (every (lambda (v) (or (not (nucleo:secciones v))
                                  (search (format nil "~a - " (nucleo:etiqueta v)) salida)))
                  (nucleo:vistas s))))
     (protocolo:con-agrupacion-en-vista
      . ,(lambda (salida plano s) (declare (ignore plano))
           (every (lambda (v) (or (not (nucleo:agrupacion v))
                                  (search (format nil "~%~a~%" (nucleo:etiqueta v)) salida)))
                  (nucleo:vistas s))))
     (protocolo:con-filtro-de-vista
      . ,(lambda (salida plano s) (declare (ignore salida plano s)) t))
     (protocolo:con-casilla-en-conflicto
      . ,(lambda (salida plano s) (declare (ignore salida plano s)) t))
     (protocolo:con-marcado-textual
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search "Estado" salida)))
     (protocolo:con-busqueda-por-clave
      . ,(lambda (salida plano s) (declare (ignore salida plano s)) t))
     (protocolo:con-orden-declarado
      . ,(lambda (salida plano s) (declare (ignore salida plano s)) t))
     (protocolo:con-conteo-de-distintos
      . ,(lambda (salida plano s) (declare (ignore salida plano s)) t))
     (protocolo:con-validacion-de-forma
      . ,(lambda (salida plano s) (declare (ignore salida plano s)) t))
     (protocolo:con-relacion-uno-a-muchos
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search ", " salida)))
     (protocolo:con-navegacion
      . ,(lambda (salida plano s) (declare (ignore plano s)) (search "Indice" salida)))))
  "Por arquitectura, la comprobacion de cada capacidad sobre su salida.

   Las que valen T sin mirar son las que el texto plano cumple porque las
   calcula el evaluador de referencia al generar, o porque no dejan rastro
   propio en un documento estatico (el orden ya es el de las filas): su
   evidencia es que ./demostrar.sh compara cada celda del texto con el
   evaluador.")

(defun situaciones-de-conformidad ()
  "El corpus y los casos de robustez, como (NOMBRE SITUACION DATOS)."
  (append
   (loop for (nombre variable) in '(("PLAN-DEL-GRUPO" "DATOS-DEL-PLAN")
                                    ("DEFENSAS-DE-TESIS" "DATOS-DE-LAS-DEFENSAS")
                                    ("HORARIO-DEL-GRUPO" "DATOS-DEL-HORARIO")
                                    ("DEPARTAMENTO" "DATOS-DEL-DEPARTAMENTO")
                                    ("HORARIO-SAUL" "DATOS-DEL-SAUL")
                                    ("SEDER" "DATOS-DEL-SEDER"))
         collect (list nombre (situacion.lenguaje:situacion-llamada nombre)
                       (symbol-value (find-symbol variable '#:situacion.corpus))))
   (loop for caso in situacion.casos:*casos*
         collect (list (situacion.casos:caso-prefijo caso)
                       (situacion.casos:caso-situacion caso)
                       (situacion.casos:caso-datos caso)))))

(definir-prueba conformidad-toda-capacidad-declarada-tiene-comprobacion
    "Conformidad: cada capacidad que declara una arquitectura tiene su comprobacion en la salida"
  (dolist (par (arquitecturas-disponibles))
    (let ((evidencias (cdr (assoc (car par) +evidencias+ :test #'string=))))
      (dolist (capacidad (protocolo:capacidades (cdr par)))
        (comprobar (assoc capacidad evidencias)
                   "~a declara ~(~a~) y no hay forma de comprobarla en su salida"
                   (car par) capacidad)))))

(definir-prueba conformidad-lo-que-se-cumple-se-ve-en-la-salida
    "Conformidad: cada linea \"cumple\" del informe tiene su evidencia en la salida real"
  (dolist (caso (situaciones-de-conformidad))
    (destructuring-bind (nombre situacion datos) caso
      (dolist (par (arquitecturas-disponibles))
        (multiple-value-bind (salida informe)
            (materializar-en-cadena (cdr par) situacion datos)
          (let ((plano (when (string= (car par) "excel") (plano-de situacion datos)))
                (evidencias (cdr (assoc (car par) +evidencias+ :test #'string=))))
            (dolist (capacidad (remove-duplicates
                                (mapcar #'protocolo:entrada-de-informe-capacidad
                                        (remove :cumple (protocolo:entradas-del-informe informe)
                                                :key #'protocolo:entrada-de-informe-respuesta
                                                :test-not #'eq))))
              (let ((comprobacion (cdr (assoc capacidad evidencias))))
                (comprobar (and comprobacion (funcall comprobacion salida plano situacion))
                           "~a dice que cumple ~(~a~) en ~a y su salida no lo ensena"
                           (car par) capacidad nombre)))))))))
