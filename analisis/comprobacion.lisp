;;;; Comprobaciones estaticas.
;;;;
;;;; Ninguna de estas consulta a ninguna arquitectura. Todas se pueden
;;;; contestar mirando solo la descripcion, y por eso el error sale antes de
;;;; que exista un destino.
;;;;
;;;; La mas importante de todas es la del orden, porque es la que impide que
;;;; se cuele el modelo de la hoja de calculo. (ANTERIOR FILA) solo es legal
;;;; sobre una coleccion que declare por que campo esta ordenada. Sin esa
;;;; regla, "anterior" significa "la fila de arriba en la rejilla", que es
;;;; exactamente lo que significaba el PREVIOUS-OF de 2026 y lo que no tiene
;;;; traduccion a una pagina ni a una base de datos.

(in-package #:situacion.analisis)

(defstruct (problema (:constructor hacer-problema (gravedad texto &optional donde)))
  gravedad texto donde)

(defun texto-de-problema (p) (problema-texto p))
(defun gravedad-de-problema (p) (problema-gravedad p))

(define-condition situacion-invalida (error)
  ((problemas :initarg :problemas :reader problemas))
  (:report (lambda (c s)
             (format s "La descripcion tiene ~d problema~:[s~;~]:~%~{  - ~a~%~}"
                     (length (problemas c))
                     (= 1 (length (problemas c)))
                     (mapcar #'texto-de-problema (problemas c))))))

(defmacro con-problemas (&body cuerpo)
  `(let ((*problemas* '()))
     (declare (special *problemas*))
     ,@cuerpo
     (nreverse *problemas*)))

(defun anotar (gravedad formato &rest argumentos)
  (declare (special *problemas*))
  (push (hacer-problema gravedad (apply #'format nil formato argumentos))
        *problemas*))

;;; ---------------------------------------------------------------------
;;; Comprobacion de una expresion en su ambito
;;; ---------------------------------------------------------------------

(defun comprobar-expresion (expresion ambito situacion contexto)
  "Recorre EXPRESION comprobando que todo lo que nombra existe.

   CONTEXTO es una cadena que describe de donde viene, para que el mensaje de
   error diga en que campo o en que marca esta el problema y no solo que algo
   esta mal."
  (when (null expresion) (return-from comprobar-expresion))
  (typecase expresion

    (nucleo:ref-campo
     (let* ((v (nucleo:variable expresion))
            (coleccion (nucleo:coleccion-de-variable ambito v)))
       (cond
         ((null coleccion)
          (anotar :error "~a: la variable de fila ~(~a~) no esta ligada.~@
                          Las variables ligadas aqui son: ~{~(~a~)~^, ~}."
                  contexto v (mapcar #'car (nucleo:ligaduras ambito))))
         ((null (nucleo:campo-llamado coleccion (nucleo:campo expresion)))
          (anotar :error "~a: la coleccion ~(~a~) no tiene un campo ~(~a~).~@
                          Tiene: ~{~(~a~)~^, ~}."
                  contexto (nucleo:nombre coleccion) (nucleo:campo expresion)
                  (mapcar #'nucleo:nombre (nucleo:campos coleccion)))))))

    (nucleo:ref-parametro
     (unless (nucleo:parametro-llamado situacion (nucleo:nombre expresion))
       (anotar :error "~a: no hay ningun parametro llamado ~(~a~)."
               contexto (nucleo:nombre expresion))))

    (nucleo:vecino
     (let ((coleccion (nucleo:coleccion-de-variable ambito (nucleo:variable expresion))))
       (cond
         ((null coleccion)
          (anotar :error "~a: la variable de fila ~(~a~) no esta ligada."
                  contexto (nucleo:variable expresion)))
         ((null (nucleo:orden coleccion))
          (anotar :error
                  "~a: se pide la fila ~(~a~) de ~(~a~), pero esa coleccion no~@
                   declara orden.~@
                   Sin orden declarado, \"anterior\" solo puede significar \"la~@
                   de arriba\", que es una propiedad de como se dibuja y no del~@
                   problema. Anade (:orden <campo>) a la coleccion."
                  contexto (nucleo:direccion expresion) (nucleo:nombre coleccion))))))

    ((or nucleo:existe nucleo:busqueda nucleo:agregado nucleo:conjunto
         nucleo:relacionadas)
     (let* ((nombre-coleccion (nucleo:coleccion expresion))
            (coleccion (nucleo:coleccion-llamada situacion nombre-coleccion)))
       (if (null coleccion)
           (anotar :error "~a: no hay ninguna coleccion llamada ~(~a~)."
                   contexto nombre-coleccion)
           (let ((interno (if (nucleo:variable expresion)
                              (nucleo:ambito-extendido ambito
                                                       (nucleo:variable expresion)
                                                       coleccion)
                              ambito)))
             ;; El campo sobre el que se agrega o se proyecta pertenece a la
             ;; coleccion recorrida, no a la de fuera.
             (when (and (typep expresion '(or nucleo:agregado nucleo:conjunto))
                        (nucleo:campo expresion)
                        (null (nucleo:campo-llamado coleccion (nucleo:campo expresion))))
               (anotar :error "~a: la coleccion ~(~a~) no tiene un campo ~(~a~)."
                       contexto nombre-coleccion (nucleo:campo expresion)))
             (when (typep expresion 'nucleo:existe)
               (let ((d (nucleo:distinta-de expresion)))
                 (when (and d (not (nucleo:variable-ligada-p ambito d)))
                   (anotar :error "~a: :DISTINTA-DE ~(~a~) no esta ligada."
                           contexto d))))
             (dolist (hija (nucleo:subexpresiones expresion))
               (comprobar-expresion hija interno situacion contexto))
             (return-from comprobar-expresion)))))

    (nucleo:comparten
     (dolist (v (list (nucleo:variable-a expresion) (nucleo:variable-b expresion)))
       (unless (nucleo:variable-ligada-p ambito v)
         (anotar :error "~a: la variable de fila ~(~a~) no esta ligada." contexto v)))
     (let ((coleccion (nucleo:coleccion-de-variable ambito (nucleo:variable-a expresion))))
       (when coleccion
         (dolist (c (nucleo:campos expresion))
           (unless (nucleo:campo-llamado coleccion c)
             (anotar :error "~a: la coleccion ~(~a~) no tiene un campo ~(~a~)."
                     contexto (nucleo:nombre coleccion) c))))))

    (nucleo:proyeccion
     ;; El campo proyectado pertenece a la coleccion de la busqueda de abajo.
     (let ((sobre (nucleo:sobre expresion)))
       (when (typep sobre 'nucleo:busqueda)
         (let ((coleccion (nucleo:coleccion-llamada situacion (nucleo:coleccion sobre))))
           (when (and coleccion
                      (null (nucleo:campo-llamado coleccion (nucleo:campo expresion))))
             (anotar :error "~a: la coleccion ~(~a~) no tiene un campo ~(~a~)."
                     contexto (nucleo:coleccion sobre) (nucleo:campo expresion))))))))

  ;; Caso general: bajar a las hijas en el mismo ambito.
  (dolist (hija (nucleo:subexpresiones expresion))
    (comprobar-expresion hija ambito situacion contexto)))

;;; ---------------------------------------------------------------------
;;; Comprobaciones de estructura
;;; ---------------------------------------------------------------------

(defun ambito-de-coleccion (coleccion)
  (nucleo:hacer-ambito
   :ligaduras (list (cons (nucleo:nombrar "fila") coleccion))
   :actual (nucleo:nombrar "fila")))

(defun comprobar-origen (coleccion situacion)
  "Una coleccion derivada tiene que decir de donde salen sus filas."
  (let ((origen (nucleo:origen coleccion)))
    (when (and (consp origen) (eq (first origen) :una-fila-por))
      (destructuring-bind (clase campo de fuente) origen
        (declare (ignore clase de))
        (let ((otra (nucleo:coleccion-llamada situacion fuente)))
          (cond
            ((null otra)
             (anotar :error "~(~a~) dice tener una fila por ~(~a~) de ~(~a~), y~@
                             ~:*~(~a~) no existe."
                     (nucleo:nombre coleccion) campo fuente))
            ((null (nucleo:campo-llamado otra campo))
             (anotar :error "~(~a~) se agrupa por ~(~a~), que no es campo de ~(~a~)."
                     (nucleo:nombre coleccion) campo fuente))
            ((null (nucleo:campo-llamado coleccion campo))
             (anotar :aviso "~(~a~) se agrupa por ~(~a~) y no tiene un campo con~@
                             ese nombre donde ponerlo; se usara el primero."
                     (nucleo:nombre coleccion) campo))))))))

(defun comprobar-coleccion (coleccion situacion)
  (comprobar-origen coleccion situacion)
  (let ((ambito (ambito-de-coleccion coleccion)))
    ;; Nombres de campo repetidos.
    (let ((vistos '()))
      (dolist (campo (nucleo:campos coleccion))
        (when (member (nucleo:nombre campo) vistos)
          (anotar :error "La coleccion ~(~a~) declara dos veces el campo ~(~a~)."
                  (nucleo:nombre coleccion) (nucleo:nombre campo)))
        (push (nucleo:nombre campo) vistos)))
    ;; La clave y el orden tienen que existir.
    (dolist (c (nucleo:clave coleccion))
      (unless (nucleo:campo-llamado coleccion c)
        (anotar :error "La clave de ~(~a~) menciona un campo ~(~a~) que no existe."
                (nucleo:nombre coleccion) c)))
    (when (and (nucleo:orden coleccion)
               (null (nucleo:campo-llamado coleccion (nucleo:orden coleccion))))
      (anotar :error "~(~a~) dice estar ordenada por ~(~a~), que no es un campo suyo."
              (nucleo:nombre coleccion) (nucleo:orden coleccion)))
    ;; Cada campo.
    (dolist (campo (nucleo:campos coleccion))
      (let ((contexto (format nil "El campo ~(~a~).~(~a~)"
                              (nucleo:nombre coleccion) (nucleo:nombre campo))))
        (when (nucleo:expresion campo)
          (comprobar-expresion (nucleo:expresion campo) ambito situacion contexto))
        (when (nucleo:dominio campo)
          (comprobar-expresion (nucleo:dominio campo) ambito situacion
                               (format nil "~a, en su dominio" contexto)))
        (when (and (eq (nucleo:rol campo) :entrada)
                   (null (nucleo:dominio campo))
                   (eq (nucleo:al-violar campo) :impedir))
          (anotar :aviso "~a: dice :AL-VIOLAR IMPEDIR pero no tiene dominio que violar."
                  contexto))))))

(defun comprobar-ciclos (coleccion)
  "Detecta campos derivados que dependen de si mismos.

   Solo se miran las dependencias dentro de la misma fila: un campo derivado
   que se refiere a otro campo derivado de su propia coleccion. Las
   dependencias que pasan por un agregado o una busqueda no forman ciclo de
   fila, porque van a otra fila."
  (let ((dependencias (make-hash-table :test #'eq)))
    (dolist (campo (nucleo:campos coleccion))
      (when (eq (nucleo:rol campo) :derivado)
        (let ((suyas '()))
          (nucleo:recorrer-expresion
           (nucleo:expresion campo)
           (lambda (e)
             (when (and (typep e 'nucleo:ref-campo)
                        (eq (nucleo:variable e) (nucleo:nombrar "fila")))
               (pushnew (nucleo:campo e) suyas))))
          (setf (gethash (nucleo:nombre campo) dependencias) suyas))))
    (labels ((alcanza-p (desde objetivo visitados)
               ;; El orden de las dos primeras clausulas importa: si se
               ;; comprueba lo visitado ANTES que el objetivo, el ciclo que
               ;; vuelve al punto de partida se descarta por visitado y no se
               ;; detecta nunca. Lo cazo una prueba, no la lectura.
               (cond ((and visitados (eq desde objetivo)) t)
                     ((member desde visitados) nil)
                     (t (some (lambda (d) (alcanza-p d objetivo (cons desde visitados)))
                              (gethash desde dependencias))))))
      (loop for nombre being the hash-keys of dependencias
            do (when (alcanza-p nombre nombre '())
                 (anotar :error
                         "El campo derivado ~(~a~).~(~a~) depende de si mismo."
                         (nucleo:nombre coleccion) nombre))))))

(defun comprobar-marca (marca situacion)
  (let* ((coleccion (coleccion-de-la-marca marca situacion))
         (contexto (format nil "La marca ~(~a~)" (nucleo:nombre marca))))
    (cond
      ((null (nucleo:alcance marca))
       (anotar :error "~a no dice sobre que campos senala." contexto))
      ((null coleccion)
       (let ((candidatas (colecciones-compatibles marca situacion)))
         (if (rest candidatas)
             (anotar :error
                     "~a senala campos (~{~(~a~)~^, ~}) que existen en mas de~@
                      una coleccion (~{~(~a~)~^, ~}). Anade :EN <coleccion>~@
                      para decir de cual se trata."
                     contexto (nucleo:alcance marca)
                     (mapcar #'nucleo:nombre candidatas))
             (anotar :error
                     "~a senala campos (~{~(~a~)~^, ~}) que no estan todos en~@
                      ninguna coleccion."
                     contexto (nucleo:alcance marca)))))
      (t
       (let ((ambito (ambito-de-coleccion coleccion)))
         (comprobar-expresion (nucleo:condicion marca) ambito situacion contexto)
         (when (nucleo:explicacion marca)
           (comprobar-expresion (nucleo:explicacion marca) ambito situacion
                                (format nil "~a, en su explicacion" contexto))))))
    (unless (member (nucleo:severidad marca) '(:informativa :advertencia :problema))
      (anotar :error "~a tiene severidad ~(~a~), que no es una de las tres.~@
                      Son :INFORMATIVA, :ADVERTENCIA y :PROBLEMA."
              contexto (nucleo:severidad marca)))))

(defun colecciones-compatibles (marca situacion)
  (remove-if-not (lambda (c)
                   (every (lambda (campo) (nucleo:campo-llamado c campo))
                          (nucleo:alcance marca)))
                 (nucleo:colecciones situacion)))

(defun coleccion-de-la-marca (marca situacion)
  "La coleccion cuyas filas evalua MARCA.

   Si la marca lo declara con :EN, esa. Si no, se deduce del alcance, y solo
   vale si no hay ambiguedad: dos colecciones pueden tener campos con el
   mismo nombre, y adivinar en ese caso es como el color por orden de
   aparicion de 2026, un acierto que depende de como esten escritas las
   cosas."
  (if (nucleo:coleccion marca)
      (nucleo:coleccion-llamada situacion (nucleo:coleccion marca))
      (let ((candidatas (colecciones-compatibles marca situacion)))
        (when (= 1 (length candidatas)) (first candidatas)))))

(defun comprobar-vista (vista situacion)
  (let ((coleccion (nucleo:coleccion-llamada situacion (nucleo:fuente vista))))
    (cond
      ((null coleccion)
       (anotar :error "La vista ~(~a~) muestra ~(~a~), que no existe."
               (nucleo:nombre vista) (nucleo:fuente vista)))
      (t
       ;; Una tabla cruzada se declara con tres ranuras, y las tres o ninguna:
       ;; con dos no se sabe que va en el cruce.
       (let ((ejes (remove nil (list (nucleo:eje-de-filas vista)
                                     (nucleo:eje-de-columnas vista)
                                     (nucleo:lo-que-se-muestra vista)))))
         (when (and ejes (< (length ejes) 3))
           (anotar :error
                   "La vista ~(~a~) declara una tabla cruzada a medias.~@
                    Hacen falta las tres: :FILAS, :COLUMNAS y :CELDA."
                   (nucleo:nombre vista))))
       ;; Los ejes de un cruce, mas el campo por el que se parte, tienen que
       ;; determinar la fila. Si no, dos filas distintas caen en la misma
       ;; casilla y se dibuja una de las dos -la primera que aparezca-, que es
       ;; el PREVIOUS-OF posicional otra vez: el resultado depende del orden en
       ;; que esten escritos los datos y no de lo que dice la descripcion.
       ;;
       ;; Solo se puede comprobar si la coleccion DECLARA clave. Sin clave no
       ;; hay con que saberlo, y callar ahi es honesto: no es lo mismo no poder
       ;; comprobar que comprobar y aprobar.
       (when (and (nucleo:cruzada-p vista) (nucleo:clave coleccion))
         (let ((sueltos (set-difference
                         (nucleo:clave coleccion)
                         (remove nil (list (nucleo:eje-de-filas vista)
                                           (nucleo:eje-de-columnas vista)
                                           (nucleo:secciones vista))))))
           (when (and sueltos (null (nucleo:conflicto vista)))
             (anotar :error
                     "La vista ~(~a~) cruza ~(~a~) por ~(~a~) sobre ~(~a~), cuya~@
                      clave es (~{~(~a~)~^ ~}).~@
                      Queda fuera: ~{~(~a~)~^, ~}. Dos filas distintas caen en la~@
                      misma casilla y solo se dibujaria una, la primera que~@
                      apareciera en los datos.~@
                      Anade (:SECCIONES ~(~a~)) para que la vista se parta por ese~@
                      campo, cambia los ejes, o -si la casilla es unica porque~@
                      una regla del dominio lo garantiza- di cual con~@
                      (:UNICA-SALVO <marca>)."
                     (nucleo:nombre vista)
                     (nucleo:eje-de-filas vista) (nucleo:eje-de-columnas vista)
                     (nucleo:nombre coleccion) (nucleo:clave coleccion)
                     sueltos (first sueltos)))
           ;; Declarar una garantia donde no hace falta no rompe nada, pero
           ;; hace creer que la casilla es fragil cuando no lo es.
           (when (and (null sueltos) (nucleo:conflicto vista))
             (anotar :aviso
                     "La vista ~(~a~) declara :UNICA-SALVO y no le hace falta:~@
                      sus ejes ya determinan la fila."
                     (nucleo:nombre vista)))))
       ;; La marca que se declara como garantia tiene que existir y tiene que
       ;; hablar de esta coleccion. Si no, la garantia no garantiza nada.
       (when (nucleo:conflicto vista)
         (let ((marca (find (nucleo:conflicto vista) (nucleo:marcas situacion)
                            :key #'nucleo:nombre)))
           (cond
             ((null marca)
              (anotar :error
                      "La vista ~(~a~) dice :UNICA-SALVO ~(~a~), y no hay~@
                       ninguna marca con ese nombre."
                      (nucleo:nombre vista) (nucleo:conflicto vista)))
             ((and (nucleo:coleccion marca)
                   (not (eq (nucleo:coleccion marca) (nucleo:nombre coleccion))))
              (anotar :error
                      "La vista ~(~a~) muestra ~(~a~) y dice estar garantizada~@
                       por la marca ~(~a~), que es de ~(~a~).~@
                       Una marca de otra coleccion no puede decir nada sobre~@
                       las casillas de esta."
                      (nucleo:nombre vista) (nucleo:nombre coleccion)
                      (nucleo:nombre marca) (nucleo:coleccion marca))))))
       ;; El filtro se escribe pensando en una fila, asi que se comprueba con
       ;; la variable FILA ligada a la coleccion de la vista.
       (when (nucleo:filtro vista)
         ;; De momento solo lo materializan las vistas cruzadas. En una vista
         ;; plana, las arquitecturas dibujan la tabla de la COLECCION, que es
         ;; el dato entero, y el filtro se quedaria sin efecto. Se rechaza en
         ;; vez de ignorarse en silencio, que es la regla de toda esta casa.
         (unless (nucleo:cruzada-p vista)
           (anotar :error
                   "La vista ~(~a~) declara :DONDE y no es una tabla cruzada.~@
                    El filtro solo esta implementado para vistas cruzadas: en~@
                    una vista plana se dibuja la tabla de la coleccion entera~@
                    y el filtro no se aplicaria.~@
                    Quita el :DONDE, o declara los tres ejes de la tabla~@
                    cruzada."
                   (nucleo:nombre vista)))
         (comprobar-expresion (nucleo:filtro vista)
                              (nucleo:ambito-extendido (nucleo:hacer-ambito)
                                                       (nucleo:nombrar "fila")
                                                       coleccion)
                              situacion
                              (format nil "El filtro de la vista ~(~a~)"
                                      (nucleo:nombre vista))))
       ;; Y todo campo que la vista mencione tiene que ser de su coleccion.
       (dolist (par (list (cons :secciones (nucleo:secciones vista))
                          (cons :agrupada-por (nucleo:agrupacion vista))
                          (cons :filas (nucleo:eje-de-filas vista))
                          (cons :columnas (nucleo:eje-de-columnas vista))
                          (cons :muestra (nucleo:lo-que-se-muestra vista))))
         (when (and (cdr par) (null (nucleo:campo-llamado coleccion (cdr par))))
           (anotar :error
                   "La vista ~(~a~) usa ~(~a~) ~(~a~), que no es campo de ~(~a~)."
                   (nucleo:nombre vista) (car par) (cdr par)
                   (nucleo:nombre coleccion))))))))

(defun comprobar-situacion (situacion)
  "Todos los problemas de SITUACION, como lista. Vacia si esta bien."
  (con-problemas
    (dolist (c (nucleo:colecciones situacion))
      (comprobar-coleccion c situacion)
      (comprobar-ciclos c))
    (dolist (m (nucleo:marcas situacion)) (comprobar-marca m situacion))
    (dolist (v (nucleo:vistas situacion)) (comprobar-vista v situacion))
    (unless (nucleo:colecciones situacion)
      (anotar :error "La situacion no declara ninguna coleccion."))))

(defun informe-de-problemas (problemas)
  (format nil "~{  ~(~a~): ~a~%~}"
          (loop for p in problemas
                append (list (gravedad-de-problema p) (texto-de-problema p)))))

(defun analizar (situacion &key (estricto t))
  "Comprueba SITUACION y la devuelve. Con ESTRICTO, senala un error si hay
   problemas de gravedad :ERROR."
  (let* ((problemas (comprobar-situacion situacion))
         (errores (remove-if-not (lambda (p) (eq (gravedad-de-problema p) :error))
                                 problemas)))
    (when (and estricto errores)
      (error 'situacion-invalida :problemas errores))
    (values situacion problemas)))
