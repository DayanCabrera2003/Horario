;;;; Pruebas de la particion de vista en archivos independientes (H2).

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion horario-con-profesores (:etiqueta "Horario con profesores")
  (coleccion casillas
    (:clave grupo dia turno)
    (campo grupo      :rol fijo)
    (campo dia        :rol fijo)
    (campo turno      :rol fijo :tipo entero)
    (campo profesor   :rol fijo)
    (campo asignatura :rol entrada :dominio (uno-de "MAT" "ESP")
                      :al-violar advertir))
  (vista por-grupo    :de casillas :entrada t :etiqueta "Horario del grupo"
                      :filas turno :columnas dia :muestra asignatura
                      :secciones grupo)
  (vista por-profesor :de casillas :etiqueta "Horario del profesor"
                      :filas turno :columnas dia :muestra grupo
                      :secciones profesor))

(defun situacion-con-profesores ()
  (situacion.lenguaje:situacion-llamada "HORARIO-CON-PROFESORES"))

(defparameter *datos-con-profesores*
  (list (cons (nucleo:nombrar "casillas")
              (loop for (g d tu p a) in '(("10-A" "lunes" 1 "Rosa" "MAT")
                                          ("10-A" "lunes" 2 "Julia" "ESP")
                                          ("10-B" "lunes" 1 "Julia" "ESP"))
                    collect (list (cons (nucleo:nombrar "grupo") g)
                                  (cons (nucleo:nombrar "dia") d)
                                  (cons (nucleo:nombrar "turno") tu)
                                  (cons (nucleo:nombrar "profesor") p)
                                  (cons (nucleo:nombrar "asignatura") a))))))

(definir-prueba vista-en-archivo-no-deja-pestana-en-el-libro-principal
    "H2: una vista en VISTAS-EN-ARCHIVO no tiene pestana en el libro principal"
  (let* ((a (situacion.excel:hacer-excel :vistas-en-archivo '(por-profesor)))
         (destino "/tmp/horario-con-profesores-plano.json"))
    (protocolo:materializar a (situacion-con-profesores) *datos-con-profesores* destino)
    (let ((contenido (leer-archivo destino)))
      ;; Comprobacion textual simple: el nombre de pestana de POR-PROFESOR no
      ;; debe aparecer en el JSON del libro principal.
      (comprobar (not (search "Horario del profesor" contenido))
                 "la vista en VISTAS-EN-ARCHIVO no puede tener pestana en el~@
                  libro principal"))))

;;; ---------------------------------------------------------------------
;;; Utilidades de lectura, solo para estas pruebas
;;;
;;; No hay un lector de JSON en el proyecto -ESCRIBIR-JSON (excel/plano.lisp)
;;; es solo de escritura, y el resto de las pruebas de excel ya se conforman
;;; con SEARCH sobre el texto (vease PRUEBAS/RELACION.LISP). Aqui hace falta
;;; algo un poco mas preciso -el VALOR de una celda concreta, no solo si un
;;; texto aparece en alguna parte- y para eso basta con esto: el plano que
;;; escribe esta arquitectura es siempre plano y predecible en esta forma.
;;; ---------------------------------------------------------------------

(defun leer-archivo (ruta)
  "El contenido entero de RUTA, como una sola cadena."
  (with-open-file (f ruta)
    (let ((s (make-string (file-length f))))
      (read-sequence s f)
      s)))

(defun valor-de-celda-en-json (contenido celda)
  "El valor de la entrada {\"celda\": \"CELDA\", \"valor\": ...} en un plano
   ya escrito como JSON, leido de vuelta como texto y sin las comillas si
   era una cadena.

   No es un lector de JSON generico: busca la marca \"celda\": \"<CELDA>\" y
   lee el token que sigue a la siguiente \"valor\": despues de ella."
  (let* ((marca (format nil "\"celda\": \"~a\"" celda))
         (inicio (search marca contenido)))
    (unless inicio
      (error "No se encontro la celda ~a en el contenido" celda))
    (let ((clave (search "\"valor\":" contenido :start2 inicio)))
      (unless clave
        (error "La celda ~a no tiene \"valor\" despues en el contenido" celda))
      (let* ((desde (position-if (lambda (c) (not (member c '(#\Space #\Newline #\Tab))))
                                 contenido :start (+ clave (length "\"valor\":"))))
             (fin (or (position-if (lambda (c) (member c '(#\, #\Newline)))
                                   contenido :start desde)
                     (length contenido))))
        (string-trim '(#\Space #\Newline #\") (subseq contenido desde fin))))))

;;; ---------------------------------------------------------------------
;;; Los valores congelados de verdad se escriben, no solo "no hay pestana"
;;; ---------------------------------------------------------------------

(definir-prueba vista-en-archivo-escribe-los-valores-correctos-por-seccion
    "H2: cada archivo de seccion lleva los valores congelados correctos"
  ;; Lo que ya confirmo a mano la vuelta con LibreOffice (materializador +
  ;; soffice --convert-to), pero como prueba automatica: sin esto, un cambio
  ;; que rompa PLANO-DE-CRUCE-CONGELADO (por ejemplo, cruzar mal los ejes o
  ;; leer el campo equivocado) solo lo veria alguien mirando el .xlsx a mano.
  (let* ((a (situacion.excel:hacer-excel :vistas-en-archivo '(por-profesor)))
         (destino "/tmp/horario-con-profesores-valores.json"))
    (protocolo:materializar a (situacion-con-profesores) *datos-con-profesores* destino)
    (let* ((ruta-rosa (situacion.excel::ruta-de-archivo destino "Rosa"))
           (ruta-julia (situacion.excel::ruta-de-archivo destino "Julia"))
           (rosa (leer-archivo ruta-rosa))
           (julia (leer-archivo ruta-julia)))
      ;; Rosa: un solo turno (1), lunes -> su unico grupo, 10-A.
      (comprobar (string= "10-A" (valor-de-celda-en-json rosa "B4"))
                 "el archivo de Rosa deberia mostrar 10-A en turno 1, lunes")
      ;; Julia: dos turnos, en el orden en que aparecen en los datos -turno 2
      ;; primero, turno 1 despues- cada uno con su propio grupo.
      (comprobar (string= "10-A" (valor-de-celda-en-json julia "B4"))
                 "el archivo de Julia deberia mostrar 10-A en su primera fila (turno 2)")
      (comprobar (string= "10-B" (valor-de-celda-en-json julia "B5"))
                 "el archivo de Julia deberia mostrar 10-B en su segunda fila (turno 1)"))))

;;; ---------------------------------------------------------------------
;;; La casilla en conflicto, tambien en el camino congelado
;;;
;;; Mismo patron que AGENDA-DEL-PROFESOR en pruebas/vistas.lisp: los ejes mas
;;; la particion dejan GRUPO fuera de la clave, asi que dos filas pueden caer
;;; en la misma casilla. La vista solo es legal si declara que marca lo
;;; garantiza -aqui, la misma PROFESOR-COLISIONA-, y VALOR-CONGELADO-DE-CASILLA
;;; tiene que ensenar las dos, no elegir una.
;;; ---------------------------------------------------------------------

(situacion.lenguaje:defsituacion horario-con-profesores-en-conflicto
    (:etiqueta "Horario con profesores, con conflicto")
  (coleccion casillas
    (:clave grupo dia turno)
    (campo grupo      :rol fijo)
    (campo dia        :rol fijo)
    (campo turno      :rol fijo :tipo entero)
    (campo profesor   :rol fijo)
    (campo asignatura :rol entrada :dominio (uno-de "MAT" "ESP")
                      :al-violar advertir))
  (marca profesor-colisiona
    :en casillas
    :cuando (existe otra :en casillas
              :distinta-de fila
              :donde (y (= (de otra dia) (de fila dia))
                        (= (de otra turno) (de fila turno))
                        (= (de otra profesor) (de fila profesor))))
    :sobre     (profesor)
    :severidad problema
    :explica   "Este profesor da clase a otro grupo en este mismo turno")
  (vista por-profesor :de casillas :etiqueta "Horario del profesor"
                      :filas turno :columnas dia :muestra grupo
                      :secciones profesor
                      :unica-salvo profesor-colisiona))

(defun situacion-con-profesores-en-conflicto ()
  (situacion.lenguaje:situacion-llamada "HORARIO-CON-PROFESORES-EN-CONFLICTO"))

(defparameter *datos-con-profesores-en-conflicto*
  ;; Rosa da MAT a 10-A y a 10-B, el mismo lunes a la misma hora: el mismo
  ;; choque que ya prueba CASILLA-EN-CONFLICTO-SE-VE para texto plano.
  (list (cons (nucleo:nombrar "casillas")
              (loop for (g d tu p a) in '(("10-A" "lunes" 1 "Rosa" "MAT")
                                          ("10-B" "lunes" 1 "Rosa" "MAT"))
                    collect (list (cons (nucleo:nombrar "grupo") g)
                                  (cons (nucleo:nombrar "dia") d)
                                  (cons (nucleo:nombrar "turno") tu)
                                  (cons (nucleo:nombrar "profesor") p)
                                  (cons (nucleo:nombrar "asignatura") a))))))

(definir-prueba vista-en-archivo-casilla-en-conflicto-se-ve-congelada
    "H2: la casilla congelada tambien ensena el choque, no elige una fila"
  (let* ((a (situacion.excel:hacer-excel :vistas-en-archivo '(por-profesor)))
         (destino "/tmp/horario-con-profesores-en-conflicto.json"))
    (protocolo:materializar a (situacion-con-profesores-en-conflicto)
                            *datos-con-profesores-en-conflicto* destino)
    (let* ((ruta-rosa (situacion.excel::ruta-de-archivo destino "Rosa"))
           (valor (valor-de-celda-en-json (leer-archivo ruta-rosa) "B4")))
      (comprobar (string= "10-A / 10-B" valor)
                 "la casilla congelada de Rosa deberia ensenar los dos~@
                  grupos separados por \" / \", y no eligio una: dice ~s"
                 valor))))

;;; ---------------------------------------------------------------------
;;; El destino de flujo, cuando hay VISTAS-EN-ARCHIVO, senala su error propio
;;; ---------------------------------------------------------------------

(definir-prueba vista-en-archivo-con-destino-de-flujo-senala-error-claro
    "H2: VISTAS-EN-ARCHIVO con destino de flujo senala su propio error, no uno criptico"
  ;; MATERIALIZAR-EN-CADENA (pruebas/conformidad.lisp) materializa sobre un
  ;; MAKE-STRING-OUTPUT-STREAM: exactamente el caso que ESCRIBIR-ARCHIVOS-DE-VISTA
  ;; tiene que rechazar antes de llegar a RUTA-DE-ARCHIVO, que fallaria con un
  ;; PATHNAME-NAME sobre un STREAM y un mensaje que no dice nada del dominio.
  (let ((a (situacion.excel:hacer-excel :vistas-en-archivo '(por-profesor))))
    (handler-case
        (progn (materializar-en-cadena a (situacion-con-profesores) *datos-con-profesores*)
               (comprobar nil
                          "tenia que senalar un error -no hay junto a que~@
                           escribir los archivos de seccion- y termino en silencio"))
      (error (e)
        (let ((mensaje (format nil "~a" e)))
          (comprobar (search "VISTAS-EN-ARCHIVO necesita una ruta real" mensaje)
                     "el error tiene que explicar que hace falta una ruta real,~@
                      no uno criptico de PATHNAME-NAME sobre un STREAM (dice: ~a)"
                     mensaje))))))
