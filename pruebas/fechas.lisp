;;;; Pruebas de los tipos booleano, fecha y hora.
;;;;
;;;; Siguen la seccion 7 del plan aprobado PLAN-TIPOS-FECHA-HORA-BOOLEANO.md,
;;;; mas lo que encontro la auditoria del 2026-10-17: la pagina comparaba
;;;; fechas y horas con parseFloat, de modo que "2026-10-12" no era mayor que
;;;; "2026-10-10" ni "09:00" menor que "09:30".

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion tipos-de-fecha (:etiqueta "Tipos de fecha")
  (coleccion tareas
    (:etiqueta "Tareas")
    (:clave nombre)
    (:crece)
    (campo nombre :rol fijo :etiqueta "Tarea")
    (campo hecha :rol entrada :tipo booleano :etiqueta "Hecha")
    (campo limite :rol entrada :tipo fecha :etiqueta "Limite" :opcional t)
    (campo hora :rol entrada :tipo hora :etiqueta "Hora" :al-violar impedir))
  (vista v :de tareas :entrada t :etiqueta "Tareas"))

(defparameter *datos-tipos-de-fecha*
  (list (cons (nucleo:nombrar "tareas")
              (list (list (cons (nucleo:nombrar "nombre") "bien")
                          (cons (nucleo:nombrar "limite") "2026-10-12")
                          (cons (nucleo:nombrar "hora") "09:30"))
                    (list (cons (nucleo:nombrar "nombre") "mal")
                          (cons (nucleo:nombrar "limite") "no es una fecha")
                          (cons (nucleo:nombrar "hora") "9:30"))
                    (list (cons (nucleo:nombrar "nombre") "vacia"))))))

(defun situacion-de-tipos () (situacion.lenguaje:situacion-llamada "TIPOS-DE-FECHA"))

(definir-prueba tipos-booleano-de-entrada-admite-si-y-no
    "Tipos: un booleano de entrada sin dominio solo admite \"si\" y \"no\""
  (let* ((campo (nucleo:campo-llamado (first (nucleo:colecciones (situacion-de-tipos)))
                                      (nucleo:nombrar "hecha")))
         (dominio (nucleo:dominio campo)))
    (comprobar (and dominio (equal (nucleo:valores dominio) '("si" "no")))
               "el dominio implicito tiene que ser (uno-de \"si\" \"no\")")))

(definir-prueba tipos-forma-invalida-en-el-evaluador
    "Tipos: un valor que no es una fecha o una hora dispara la marca, uno vacio no"
  (let* ((evaluado (nucleo:evaluar-situacion (situacion-de-tipos) *datos-tipos-de-fecha*))
         (filas (cdr (assoc (nucleo:nombrar "tareas") evaluado)))
         (marcas (mapcar (lambda (f) (mapcar #'symbol-name (cdr f))) filas)))
    (comprobar (null (first marcas)) "la fila bien escrita no tiene que marcarse: ~s"
               (first marcas))
    (comprobar (and (member "LIMITE-FORMA-INVALIDA" (second marcas) :test #'string=)
                    (member "HORA-FORMA-INVALIDA" (second marcas) :test #'string=))
               "la fila mal escrita tiene que marcar la fecha y la hora: ~s" (second marcas))
    (comprobar (null (third marcas)) "una fila sin fecha ni hora no se marca: ~s"
               (third marcas))))

(definir-prueba tipos-forma-invalida-se-pide-y-se-responde
    "Tipos: la validacion de forma se pide, la web la cumple y la hoja de calculo la degrada"
  (comprobar (member 'protocolo:con-validacion-de-forma
                     (mapcar #'first (protocolo:requerimientos (situacion-de-tipos))))
             "los requerimientos tienen que pedir CON-VALIDACION-DE-FORMA")
  (flet ((respuesta (arquitectura)
           (let ((entrada (find 'protocolo:con-validacion-de-forma
                                (protocolo:entradas-del-informe
                                 (nth-value 1 (materializar-en-cadena
                                               arquitectura (situacion-de-tipos)
                                               *datos-tipos-de-fecha*)))
                                :key #'protocolo:entrada-de-informe-capacidad)))
             (and entrada (protocolo:entrada-de-informe-respuesta entrada)))))
    (comprobar (eq (respuesta (situacion.web:hacer-web)) :cumple) "la web tiene que cumplirla")
    (comprobar (eq (respuesta (situacion.excel:hacer-excel)) :degrada)
               "la hoja de calculo tiene que degradarla")))

(definir-prueba tipos-formato-de-celda-cubre-la-reserva
    "Tipos: el formato de fecha cubre la columna entera, filas de reserva incluidas"
  (let* ((plano (plano-de (situacion-de-tipos) *datos-tipos-de-fecha*))
         (hoja (hoja-de-coleccion plano "tareas"))
         (formatos (lista-del-plano (dato hoja "formatos_de_celda")))
         (fecha (find "fecha" formatos :key (lambda (f) (dato f "formato")) :test #'string=)))
    (comprobar fecha "la columna de la fecha no tiene formato")
    (when fecha
      ;; Tres filas mas veinte de reserva: de la 4 a la 26.
      (comprobar (string= (dato fecha "rango") "C4:C26")
                 "el formato tiene que llegar a la ultima fila de reserva: ~a"
                 (dato fecha "rango")))))

(definir-prueba tipos-la-web-compara-fechas-y-horas-por-su-valor
    "Tipos: la pagina convierte fechas y horas como el evaluador, no con parseFloat"
  (let ((html (materializar-en-cadena (situacion.web:hacer-web) (situacion-de-tipos)
                                      *datos-tipos-de-fecha*)))
    (comprobar (search "function FECHANUM(" html) "la pagina no sabe leer una fecha")
    (comprobar (search "function HORANUM(" html) "la pagina no sabe leer una hora")
    (comprobar (not (search "parseFloat(" html)) "la pagina sigue llamando a parseFloat")
    (comprobar (search "control.type = 'date'" html)
               "una fecha de entrada tiene que tener un selector de fecha")))
