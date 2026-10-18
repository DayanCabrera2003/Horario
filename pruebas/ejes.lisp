;;;; Pruebas de los ejes de las vistas cruzadas.
;;;;
;;;; Antes cada seccion de una vista partida tenia sus propios ejes, en su
;;;; propio orden de aparicion: en el Saul, la pestana de un profesor era una
;;;; rejilla de 1 x 2 y la de un aula tenia las columnas M, V, L, MI, J.
;;;; Ahora todas las secciones comparten los ejes de la vista entera, y si el
;;;; eje es el campo de orden de la coleccion, van en ese orden
;;;; (nucleo/ejes.lisp).

(in-package #:situacion.pruebas)

(defun rejillas-de-vista (plano vista)
  "Las pestanas cruzadas del plano que son de VISTA (una cadena)."
  (remove-if-not (lambda (h) (equal (dato (dato h "cruce") "vista") vista))
                 (hojas-del-plano plano)))

(defun ejes-de-rejilla (hoja)
  "(VALUES FILAS COLUMNAS) de una pestana cruzada del plano."
  (values (mapcar (lambda (c) (dato c "valor"))
                  (remove-if-not (lambda (c) (char= #\A (char (dato c "celda") 0)))
                                 (lista-del-plano (dato hoja "celdas"))))
          (mapcar (lambda (e) (dato e "texto"))
                  (remove "__eje__" (lista-del-plano (dato hoja "encabezados"))
                          :key (lambda (e) (dato e "campo")) :test #'equal))))

(definir-prueba ejes-comunes-a-todas-las-secciones
    "Ejes: todas las pestanas de una vista partida tienen las mismas filas y columnas"
  (let ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                         situacion.corpus:datos-del-saul)))
    (dolist (vista '("por-grupo" "por-profesor" "por-aula"))
      (let ((rejillas (rejillas-de-vista plano vista)))
        (multiple-value-bind (filas columnas) (ejes-de-rejilla (first rejillas))
          (comprobar (equal filas '(1 2 3 4 5 6 7))
                     "~a: las filas tienen que ser los siete turnos en orden: ~s" vista filas)
          (comprobar (equal columnas '("L" "M" "MI" "J" "V"))
                     "~a: las columnas tienen que ser los cinco dias en orden: ~s"
                     vista columnas)
          (dolist (otra (rest rejillas))
            (multiple-value-bind (f c) (ejes-de-rejilla otra)
              (comprobar (and (equal f filas) (equal c columnas))
                         "~a: la pestana ~s tiene otros ejes" vista (dato otra "nombre")))))))))

(definir-prueba ejes-las-secciones-van-ordenadas
    "Ejes: las secciones de una vista partida van ordenadas por su valor"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                          situacion.corpus:datos-del-saul))
         (secciones (mapcar (lambda (h) (dato (dato h "cruce") "seccion"))
                            (rejillas-de-vista plano "por-aula"))))
    (comprobar (equal secciones (sort (copy-list secciones) #'string<))
               "las aulas tienen que ir ordenadas: ~s" secciones)))

;;; ---------------------------------------------------------------------
;;; El dominio declarado de un eje (fase 2, hueco C1)
;;;
;;; Un eje o unas secciones escritas (CAMPO :DOMINIO EXPRESION) tienen
;;; exactamente los valores del dominio, en su orden, haya datos o no; un
;;; valor de los datos que no este en el se anade al final y se avisa. El
;;; caso es pruebas/casos/guardias.lisp: los datos empiezan por un miercoles,
;;; nadie hace guardia en el turno 4 ni en la sala Este, y una guardia cae en
;;; sabado.
;;; ---------------------------------------------------------------------

(defun situacion-de-guardias ()
  (situacion.lenguaje:situacion-llamada "CASO-GUARDIAS"))

(defun entorno-de-guardias ()
  (nucleo:hacer-entorno (situacion-de-guardias) (datos-del-caso "DATOS-DE-GUARDIAS")))

(defun cuadrante-de-guardias ()
  (find (nucleo:nombrar "cuadrante") (nucleo:vistas (situacion-de-guardias))
        :key #'nucleo:nombre))

(definir-prueba ejes-dominio-da-todos-los-valores-en-su-orden
    "Ejes: un eje con dominio tiene sus valores en su orden, tambien los que no tienen datos"
  (let ((entorno (entorno-de-guardias))
        (vista (cuadrante-de-guardias)))
    (comprobar (equal (nucleo:valores-de-eje entorno vista (nucleo:eje-de-filas vista))
                      '(1 2 3 4))
               "las filas tienen que ser los turnos 1 a 4, tambien el 4, que no tiene guardias")
    (comprobar (equal (nucleo:valores-de-eje entorno vista (nucleo:eje-de-columnas vista))
                      '("L" "M" "MI" "J" "V" "S"))
               "las columnas tienen que ser los dias en el orden declarado y el sabado al final: ~s"
               (nucleo:valores-de-eje entorno vista (nucleo:eje-de-columnas vista)))))

(definir-prueba ejes-dominio-de-las-secciones
    "Ejes: unas secciones con dominio salen todas, en el orden de su coleccion"
  (comprobar (equal (nucleo:secciones-de-vista (entorno-de-guardias) (cuadrante-de-guardias))
                    '("Norte" "Sur" "Este"))
             "las salas tienen que ser Norte, Sur y Este, en ese orden: ~s"
             (nucleo:secciones-de-vista (entorno-de-guardias) (cuadrante-de-guardias))))

(definir-prueba ejes-fuera-de-dominio-se-avisa-en-el-nucleo
    "Ejes: el nucleo dice que valores de los datos caen fuera del dominio declarado"
  (let ((aviso (nucleo:aviso-fuera-de-dominio (entorno-de-guardias) (cuadrante-de-guardias))))
    (comprobar (and aviso (search "fuera del dominio declarado" aviso) (search "S" aviso))
               "el aviso tiene que nombrar el sabado: ~s" aviso))
  (comprobar (null (nucleo:aviso-fuera-de-dominio
                    (nucleo:hacer-entorno (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                                          situacion.corpus:datos-del-saul)
                    (first (nucleo:vistas (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")))))
             "una vista sin dominio declarado no avisa de nada"))

(definir-prueba ejes-fuera-de-dominio-se-ve-en-las-tres
    "Ejes: el aviso de valores fuera del dominio sale en el texto, la pagina y los informes"
  (let ((s (situacion-de-guardias))
        (d (datos-del-caso "DATOS-DE-GUARDIAS")))
    (dolist (arquitectura (list (situacion.texto:hacer-texto) (situacion.web:hacer-web)
                                (situacion.excel:hacer-excel)))
      (multiple-value-bind (salida informe) (materializar-en-cadena arquitectura s d)
        (comprobar (find-if (lambda (e) (search "fuera del dominio declarado"
                                                (or (protocolo:entrada-de-informe-nota e) "")))
                            (protocolo:entradas-del-informe informe))
                   "el informe de ~a tiene que avisar del sabado" (type-of arquitectura))
        ;; La hoja de calculo lo escribe debajo de cada rejilla del plano.
        (comprobar (search "fuera del dominio declarado" salida)
                   "la salida de ~a tiene que avisar del sabado" (type-of arquitectura))))))

(definir-prueba ejes-dominio-en-la-hoja-de-calculo
    "Ejes: la hoja de calculo tiene una pestana por sala, la vacia tambien, con todos los ejes"
  (let* ((plano (plano-de (situacion-de-guardias) (datos-del-caso "DATOS-DE-GUARDIAS")))
         (rejillas (rejillas-de-vista plano "cuadrante")))
    (comprobar (equal (mapcar (lambda (h) (dato (dato h "cruce") "seccion")) rejillas)
                      '("Norte" "Sur" "Este"))
               "las pestanas tienen que ser Norte, Sur y Este")
    (dolist (hoja rejillas)
      (multiple-value-bind (filas columnas) (ejes-de-rejilla hoja)
        (comprobar (and (equal filas '(1 2 3 4))
                        (equal columnas '("L" "M" "MI" "J" "V" "S")))
                   "la pestana ~s tiene otros ejes: ~s ~s" (dato hoja "nombre") filas columnas)))))

(definir-prueba ejes-dominio-en-la-pagina
    "Ejes: la pagina recibe el dominio de cada eje como funcion, para que siga vivo"
  (let ((html (materializar-en-cadena (situacion.web:hacer-web) (situacion-de-guardias)
                                      (datos-del-caso "DATOS-DE-GUARDIAS"))))
    (dolist (clave '("dominioFilas: " "dominioColumnas: " "dominioSecciones: "))
      (comprobar (search clave html) "la rejilla de la pagina no lleva ~a" clave))))

(definir-prueba ejes-forma-larga-mal-escrita-es-error
    "Ejes: (CAMPO :DOMINIO ...) solo admite :DOMINIO y un conjunto"
  (dolist (eje '((dia :rango (uno-de "L")) (dia :dominio "L") (dia)))
    (comprobar (handler-case
                   (progn (situacion.lenguaje::compilar-vista
                           `(vista v :de guardias :filas turno :columnas ,eje :muestra persona))
                          nil)
                 (error () t))
               "~s tendria que ser un error de compilacion" eje)))
