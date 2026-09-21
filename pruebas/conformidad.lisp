;;;; El juego de pruebas de conformidad.
;;;;
;;;; Es lo que se le entrega a un tercero junto con el protocolo, y lo que
;;;; convierte "mi arquitectura funciona" en algo comprobable.
;;;;
;;;; LA REGLA QUE LO ORDENA TODO: el evaluador de referencia del nucleo dice
;;;; que significa el lenguaje. Toda arquitectura tiene que coincidir con el.
;;;; Lo que cada una haga por dentro es asunto suyo; lo que no puede es
;;;; discrepar del significado.
;;;;
;;;; Una arquitectura es conforme si:
;;;;
;;;;   1. Materializa sin error toda descripcion del juego.
;;;;   2. Para cada capacidad que declara cumplir, la cumple en modo estricto.
;;;;   3. Para cada capacidad que no declara, emite una de las cuatro
;;;;      respuestas CON SU NOTA, en vez de fallar en silencio o de producir
;;;;      algo que parece correcto y no lo es.
;;;;
;;;; El punto 3 es el que mas importa y el que no tiene ninguna de las tres
;;;; tesis anteriores.

(in-package #:situacion.pruebas)

(defun arquitecturas-disponibles ()
  "Las arquitecturas que hay cargadas, cada una con su nombre legible."
  (remove nil
          (list (when (find-package '#:situacion.texto)
                  (cons "texto" (funcall (intern "HACER-TEXTO" '#:situacion.texto))))
                (when (find-package '#:situacion.excel)
                  (cons "excel" (funcall (intern "HACER-EXCEL" '#:situacion.excel))))
                (when (find-package '#:situacion.web)
                  (cons "web" (funcall (intern "HACER-WEB" '#:situacion.web)))))))

(defun materializar-en-cadena (arquitectura situacion datos)
  "Materializa en memoria. Devuelve (VALUES TEXTO INFORME)."
  (let ((flujo (make-string-output-stream)))
    (multiple-value-bind (destino informe)
        (protocolo:materializar arquitectura situacion datos flujo)
      (declare (ignore destino))
      (values (get-output-stream-string flujo) informe))))

;;; ---------------------------------------------------------------------
;;; Toda arquitectura materializa todo caso sin error
;;; ---------------------------------------------------------------------

(definir-prueba conformidad-todas-materializan
    "Conformidad: las tres arquitecturas materializan las dos descripciones"
  (dolist (par (arquitecturas-disponibles))
    (dolist (caso '(("PLAN-DEL-GRUPO" . situacion.corpus:datos-del-plan)
                    ("DEFENSAS-DE-TESIS" . situacion.corpus:datos-de-las-defensas)))
      (let ((s (situacion.lenguaje:situacion-llamada (car caso)))
            (datos (symbol-value (cdr caso))))
        (multiple-value-bind (salida informe)
            (handler-case (materializar-en-cadena (cdr par) s datos)
              (error (e) (values nil (format nil "~a" e))))
          (comprobar (and salida (plusp (length salida)))
                     "~a no pudo materializar ~a: ~a"
                     (car par) (car caso) informe))))))

;;; ---------------------------------------------------------------------
;;; Toda arquitectura responde a toda capacidad que se le pide
;;; ---------------------------------------------------------------------

(definir-prueba conformidad-sin-silencios
    "Conformidad: ninguna capacidad pedida queda sin respuesta en el informe"
  ;; Es el punto 3: lo que no se cumple tiene que salir en el informe como
  ;; emulado, degradado o rechazado. Callar no puede significar "algo saldra".
  (dolist (par (arquitecturas-disponibles))
    (let* ((s (situacion.lenguaje:situacion-llamada "DEFENSAS-DE-TESIS"))
           (pedidas (mapcar #'first (protocolo:requerimientos s))))
      (multiple-value-bind (salida informe)
          (materializar-en-cadena (cdr par) s situacion.corpus:datos-de-las-defensas)
        (declare (ignore salida))
        (let ((respondidas (mapcar #'protocolo:entrada-de-informe-capacidad
                                   (protocolo:entradas-del-informe informe))))
          (dolist (capacidad pedidas)
            (comprobar (member capacidad respondidas)
                       "~a no dice nada sobre ~(~a~), que la descripcion pide"
                       (car par) capacidad)))))))

(definir-prueba conformidad-cada-respuesta-lleva-nota
    "Conformidad: lo emulado y lo degradado dice en que consiste"
  ;; Una emulacion sin su limite escrito es una promesa. El renglon que dice
  ;; \"no admite huecos\" es lo que separa un prototipo de algo usable.
  (dolist (par (arquitecturas-disponibles))
    (let ((s (situacion.lenguaje:situacion-llamada "PLAN-DEL-GRUPO")))
      (multiple-value-bind (salida informe)
          (materializar-en-cadena (cdr par) s situacion.corpus:datos-del-plan)
        (declare (ignore salida))
        (dolist (entrada (protocolo:entradas-del-informe informe))
          (when (member (protocolo:entrada-de-informe-respuesta entrada)
                        '(:emula :degrada))
            (let ((nota (protocolo:entrada-de-informe-nota entrada)))
              (comprobar (and nota (stringp nota) (> (length nota) 20))
                         "~a ~(~a~) ~(~a~) sin explicar en que consiste"
                         (car par)
                         (protocolo:entrada-de-informe-respuesta entrada)
                         (protocolo:entrada-de-informe-capacidad entrada)))))))))

;;; ---------------------------------------------------------------------
;;; Las capacidades declaradas se cumplen en modo estricto
;;; ---------------------------------------------------------------------

(definir-prueba conformidad-modo-estricto
    "Conformidad: en modo estricto solo pasa lo que la arquitectura declara"
  ;; La politica vive fuera del backend, asi que la misma descripcion se puede
  ;; compilar exigiendo que no haya ni una emulacion. La web pasa; las otras
  ;; dos no, y eso es informacion, no un fallo.
  (let ((s (situacion.lenguaje:situacion-llamada "PLAN-DEL-GRUPO"))
        (resultados '()))
    (dolist (par (arquitecturas-disponibles))
      (let ((protocolo:*politica* :estricta))
        (push (cons (car par)
                    (handler-case
                        (progn (materializar-en-cadena (cdr par) s
                                                       situacion.corpus:datos-del-plan)
                               :pasa)
                      (protocolo:capacidad-no-disponible () :no-pasa)
                      (error () :no-pasa)))
              resultados)))
    (let ((web (cdr (assoc "web" resultados :test #'string=)))
          (texto (cdr (assoc "texto" resultados :test #'string=))))
      (when web
        (comprobar (eq web :pasa)
                   "la web cumple todo lo que esta descripcion pide, asi que~@
                    deberia pasar en modo estricto"))
      (when texto
        (comprobar (eq texto :no-pasa)
                   "texto plano degrada casi todo, asi que NO deberia pasar en~@
                    modo estricto. Que pase significaria que la politica no~@
                    esta haciendo nada.")))))

;;; ---------------------------------------------------------------------
;;; La inversion de capacidades
;;; ---------------------------------------------------------------------

(definir-prueba conformidad-inversion-de-capacidades
    "Conformidad: la hoja de calculo emula lo que la pagina cumple"
  ;; Es el resultado que demuestra que la jerarquia no es decorativa: no hay
  ;; una arquitectura que pueda mas y otras que puedan menos.
  (let ((s (situacion.lenguaje:situacion-llamada "PLAN-DEL-GRUPO"))
        (respuestas (make-hash-table :test #'equal)))
    (dolist (par (arquitecturas-disponibles))
      (multiple-value-bind (salida informe)
          (materializar-en-cadena (cdr par) s situacion.corpus:datos-del-plan)
        (declare (ignore salida))
        (dolist (e (protocolo:entradas-del-informe informe))
          (setf (gethash (list (car par) (protocolo:entrada-de-informe-capacidad e))
                         respuestas)
                (protocolo:entrada-de-informe-respuesta e)))))
    (let ((excel (gethash (list "excel" 'protocolo:con-crecimiento) respuestas))
          (web (gethash (list "web" 'protocolo:con-crecimiento) respuestas)))
      (when (and excel web)
        (comprobar (eq excel :emula)
                   "la hoja de calculo tiene que EMULAR el crecimiento, con~@
                    filas de reserva; da ~(~a~)" excel)
        (comprobar (eq web :cumple)
                   "la pagina CUMPLE el crecimiento de forma nativa, con un~@
                    boton; da ~(~a~)" web)))))

;;; ---------------------------------------------------------------------
;;; Las arquitecturas coinciden con el evaluador de referencia
;;; ---------------------------------------------------------------------

(definir-prueba conformidad-texto-coincide-con-el-evaluador
    "Conformidad: lo que escribe texto plano es lo que calculo el evaluador"
  ;; La comprobacion equivalente para la hoja de calculo la hace el
  ;; round-trip por LibreOffice, porque ahi las formulas las evalua el propio
  ;; programa de hojas de calculo y no hay forma honesta de hacerlo desde
  ;; aqui. Ver materializador/verificar.py.
  (when (find-package '#:situacion.texto)
    (let* ((s (situacion.lenguaje:situacion-llamada "PLAN-DEL-GRUPO"))
           (datos situacion.corpus:datos-del-plan)
           (evaluado (nucleo:evaluar-situacion s datos))
           (salida (materializar-en-cadena
                    (funcall (intern "HACER-TEXTO" '#:situacion.texto)) s datos)))
      (dolist (tabla evaluado)
        (dolist (fila (rest tabla))
          (loop for (campo . valor) in (car fila)
                do (let ((texto (nucleo:como-texto valor)))
                     (unless (string= texto "")
                       (comprobar (search texto salida)
                                  "el valor ~s de ~(~a~) no aparece en la salida~@
                                   de texto plano"
                                  texto campo)))))))))

;;; ---------------------------------------------------------------------
;;; Invariantes que necesitan las arquitecturas cargadas
;;; ---------------------------------------------------------------------

(definir-prueba i4-el-plano-no-sale-de-la-hoja-de-calculo
    "I4: el plano de libro solo lo conoce la arquitectura que lo fabrica"
  ;; Criterio C5: lo que una arquitectura se inventa es suyo y no sale de ahi.
  ;; Si otro sistema referenciara el plano, dejaria de ser un detalle interno
  ;; y pasaria a ser una interfaz, que es exactamente lo que le ocurrio al
  ;; JSON de la tesis de 2026.
  (let ((excel (find-package '#:situacion.excel))
        (ajenos '("SITUACION.NUCLEO" "SITUACION.PROTOCOLO" "SITUACION.LENGUAJE"
                  "SITUACION.ANALISIS" "SITUACION.TEXTO" "SITUACION.WEB")))
    (when excel
      (dolist (nombre ajenos)
        (let ((paquete (find-package nombre)))
          (when paquete
            (do-symbols (simbolo paquete)
              (when (eq (symbol-package simbolo) excel)
                (comprobar nil "~a referencia ~a, que es interno de la hoja de~@
                                calculo" nombre simbolo)))))))))

(definir-prueba i6-ninguna-operacion-del-protocolo-esta-muerta
    "I6: toda operacion del protocolo tiene metodos en alguna arquitectura"
  ;; Una operacion declarada que ningun backend especializa no es un punto de
  ;; extension: es una promesa. Y es facil que pase sin que nadie se entere,
  ;; porque el sistema compila igual.
  ;;
  ;; Este invariante nacio de un hallazgo real: PLANIFICAR-VISTA, EMITIR-MARCA,
  ;; EMITIR-ENTRADA y EMITIR-VISTA estaban declaradas y no las implementaba
  ;; nadie, asi que las marcas, la entrada y las vistas se materializaban con
  ;; codigo interno de cada backend y NO pasaban por el punto de extension.
  ;; El protocolo prometia mas de lo que cumplia.
  (let ((sin-metodos '()))
    (dolist (entrada (situacion.protocolo::operaciones-registradas))
      (let* ((nombre (car entrada))
             (gf (and (fboundp nombre) (fdefinition nombre)))
             (metodos (when (typep gf 'generic-function)
                        (sb-mop:generic-function-methods gf))))
        (when (null metodos) (push nombre sin-metodos))))
    (comprobar (null sin-metodos)
               "estas operaciones del protocolo no las implementa nadie:~@
                ~{~(~a~)~^, ~}.~@
                Una operacion sin metodos no es un punto de extension, es una~@
                promesa."
               sin-metodos)))

(definir-prueba i5-toda-capacidad-tiene-arquitectura-que-la-declare
    "I5: no hay capacidades que nadie declare ni ejercite"
  ;; Una capacidad que ninguna arquitectura declara y que ninguna descripcion
  ;; pide es vocabulario muerto: engorda la jerarquia sin ganar nada. Esta
  ;; prueba avisa, sin exigir que todas esten cubiertas hoy.
  (let* ((declaradas (situacion.protocolo::capacidades-declaradas))
         (cubiertas '()))
    (dolist (par (arquitecturas-disponibles))
      (setf cubiertas (union cubiertas (protocolo:capacidades (cdr par)))))
    (let ((huerfanas (set-difference declaradas cubiertas))
          ;; Capacidades que hoy NO cumple nativamente ninguna arquitectura, y
          ;; el motivo. La lista es explicita para que anadir una sea un acto
          ;; deliberado: una capacidad huerfana que nadie vigile es vocabulario
          ;; muerto engordando la jerarquia.
          (justificadas
            '(;; La cumpliria SQL con una vista. No hay arquitectura SQL.
              protocolo:con-derivacion-por-consulta
              ;; Ninguna de las tres la cumple: las tres fijan las filas al
              ;; generar y lo declaran como emulacion. La cumpliria una pagina
              ;; que reagrupara al dibujar, o SQL con GROUP BY.
              protocolo:con-agrupacion
              ;; Las dos son nuevas y todavia no las materializa nadie. La
              ;; primera se rechaza de forma explicita y la segunda degrada;
              ;; en los dos casos el informe lo dice. Salen de esta lista en
              ;; cuanto alguna arquitectura las cumpla, que es lo que hace que
              ;; anadir una huerfana tenga que ser un acto deliberado.
              protocolo:con-particion-de-vista
              protocolo:con-agrupacion-en-vista)))
      (comprobar (subsetp huerfanas justificadas)
                 "hay capacidades que ninguna arquitectura declara y que no~@
                  estan en la lista de las justificadas: ~{~(~a~)~^, ~}.~@
                  O alguna arquitectura tiene que cumplirla, o hay que decir~@
                  aqui por que no la cumple ninguna."
                 (set-difference huerfanas justificadas)))))

;;; ---------------------------------------------------------------------
;;; I7 - Ninguna ranura de vista se ignora en silencio
;;; ---------------------------------------------------------------------

(defun situacion-con-ranura-de-vista (ranura)
  "Una situacion minima cuya unica vista declara RANURA.

   Se construye con los constructores del nucleo y no con la macro del
   lenguaje porque un invariante tiene que poder recorrer las ranuras por
   nombre, y la macro las fija al escribirlas."
  (flet ((campo (n) (nucleo:hacer-campo :nombre (nucleo:nombrar n)
                                        :etiqueta n :rol :fijo)))
    (let* ((coleccion (nucleo:hacer-coleccion
                       :nombre (nucleo:nombrar "filas") :etiqueta "Filas"
                       :campos (list (campo "a") (campo "b") (campo "c"))))
           (vista (nucleo:hacer-vista :nombre (nucleo:nombrar "v") :etiqueta "V"
                                      :fuente (nucleo:nombre coleccion))))
      ;; La tabla cruzada necesita las tres ranuras a la vez para contar como
      ;; declarada; las demas, solo la suya.
      (if (eq ranura 'nucleo:eje-de-filas)
          (setf (nucleo:eje-de-filas vista) (nucleo:nombrar "a")
                (nucleo:eje-de-columnas vista) (nucleo:nombrar "b")
                (nucleo:lo-que-se-muestra vista) (nucleo:nombrar "c"))
          (funcall (fdefinition (list 'setf ranura)) (nucleo:nombrar "a") vista))
      (nucleo:hacer-situacion :nombre (nucleo:nombrar "s") :etiqueta "S"
                              :colecciones (list coleccion)
                              :vistas (list vista)))))

(definir-prueba i7-ninguna-ranura-de-vista-se-ignora-en-silencio
    "I7: toda ranura declarada de una vista pide una capacidad"
  ;; La forma general del fallo que destapo el caso del Saul Delgado: una
  ;; ranura que la sintaxis acepta, el analisis valida y nadie materializa.
  ;; :SECCIONES y :AGRUPADA-POR estuvieron asi desde que se escribieron.
  ;;
  ;; Esta prueba tiene una debilidad y conviene decirla: solo comprueba lo que
  ;; se le enumera. Si manana el nodo VISTA gana una ranura, hay que anadirla
  ;; A MANO a esta lista. Lo que impide es que una ranura que YA se sabe que
  ;; existe se quede sin pedir nada.
  (let ((ranuras '((nucleo:secciones . protocolo:con-particion-de-vista)
                   (nucleo:agrupacion . protocolo:con-agrupacion-en-vista)
                   (nucleo:eje-de-filas . protocolo:con-tabla-cruzada))))
    (dolist (par ranuras)
      (let* ((situacion (situacion-con-ranura-de-vista (car par)))
             (pedidas (mapcar #'first (protocolo:requerimientos situacion))))
        (comprobar (member (cdr par) pedidas)
                   "una vista con ~(~a~) no pide ~(~a~): la ranura se acepta y~@
                    no la materializa nadie, que es el verde falso que este~@
                    trabajo critica"
                   (car par) (cdr par))))))
