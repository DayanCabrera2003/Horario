;;;; Pruebas del nucleo: el lenguaje, el analisis y el evaluador de referencia.
;;;;
;;;; Estas pruebas no necesitan ninguna arquitectura. Eso no es una casualidad
;;;; del orden en que se escribieron: es la propiedad que hace que el
;;;; evaluador de referencia valga para algo. El algebra de expresion entera
;;;; se puede desarrollar y comprobar antes de que exista el primer backend,
;;;; que es exactamente lo contrario de lo que hicieron las tres tesis
;;;; anteriores de la linea.

(in-package #:situacion.pruebas)

(defun n (texto)
  "El simbolo con que se nombra algo en una descripcion.

   Pasa por NOMBRAR igual que el lenguaje, porque los identificadores de
   usuario viven en su propio paquete y no con el vocabulario del nucleo."
  (nucleo:nombrar texto))

(defun fila-de (datos &rest pares)
  (declare (ignore datos))
  (loop for (campo valor) on pares by #'cddr collect (cons (n campo) valor)))

;;; ---------------------------------------------------------------------
;;; Una situacion de prueba, minima y con las cuatro patas
;;; ---------------------------------------------------------------------

(situacion.lenguaje:defsituacion ejemplo (:etiqueta "Ejemplo")
  (coleccion personas
    (:clave id)
    (campo id     :rol fijo)
    (campo nombre :rol fijo)
    (campo area   :rol fijo))
  (coleccion tareas
    (:clave codigo)
    (:orden codigo)
    (:crece)
    (campo codigo   :rol fijo)
    (campo previstas :rol fijo :tipo entero)
    (campo hechas   :rol entrada :tipo entero)
    (campo persona  :rol entrada :dominio (los id de personas) :al-violar advertir)
    (campo faltan   :rol derivado :tipo entero
           (- (de fila previstas) (de fila hechas)))
    (campo quien    :rol derivado
           (el nombre de (la-fila-de personas :donde (= id (de fila persona)))
               :si-no "sin asignar"))
    (campo carga    :rol derivado :tipo entero
           (cuantas tareas :donde (= persona (de fila persona))))
    (campo areas    :rol derivado :tipo entero
           (cuantas-distintas area de personas)))
  (marca atrasada
    :en tareas
    :cuando (> (de fila faltan) 0)
    :sobre (codigo faltan)
    :severidad advertencia
    :explica (texto (plural (de fila faltan) "Falta" "Faltan") " "
                    (de fila faltan))))

(defparameter *datos-de-ejemplo*
  (list (cons (n "personas")
              (list (list (cons (n "id") "ana") (cons (n "nombre") "Ana Diaz")
                          (cons (n "area") "docencia"))
                    (list (cons (n "id") "luis") (cons (n "nombre") "Luis Paz")
                          (cons (n "area") "docencia"))
                    (list (cons (n "id") "eva") (cons (n "nombre") "Eva Mora")
                          (cons (n "area") "investigacion"))))
        (cons (n "tareas")
              (list (list (cons (n "codigo") "T1") (cons (n "previstas") 5)
                          (cons (n "hechas") 5) (cons (n "persona") "ana"))
                    (list (cons (n "codigo") "T2") (cons (n "previstas") 4)
                          (cons (n "hechas") 1) (cons (n "persona") "ana"))
                    (list (cons (n "codigo") "T3") (cons (n "previstas") 3)
                          (cons (n "hechas") 3) (cons (n "persona") ""))))))

(defun valor (entorno coleccion indice campo)
  (let ((fila (nth indice (nucleo:filas-de entorno (n coleccion)))))
    (nucleo:valor-de-campo entorno fila (n campo))))

;;; ---------------------------------------------------------------------
;;; El lenguaje construye lo que dice construir
;;; ---------------------------------------------------------------------

(definir-prueba lenguaje-construye-el-arbol
    "El lenguaje: una descripcion se convierte en el arbol esperado"
  (let* ((s (situacion.lenguaje:situacion-llamada "EJEMPLO"))
         (tareas (nucleo:coleccion-llamada s (n "tareas"))))
    (comprobar s "la situacion no quedo registrada")
    (comprobar (= 2 (length (nucleo:colecciones s))) "deberian ser dos colecciones")
    (comprobar (eq :crece (nucleo:crecimiento tareas)) "tareas declara :crece")
    (comprobar (eq (n "codigo") (nucleo:orden tareas)) "tareas se ordena por codigo")
    ;; El rol llega al modelo como palabra clave aunque se escriba suelto.
    (comprobar (eq :entrada (nucleo:rol (nucleo:campo-llamado tareas (n "hechas")))))
    (comprobar (eq :derivado (nucleo:rol (nucleo:campo-llamado tareas (n "faltan")))))
    (comprobar (eq :fijo (nucleo:rol (nucleo:campo-llamado tareas (n "codigo")))))
    ;; El dominio solo existe sobre un campo de entrada.
    (comprobar (nucleo:dominio (nucleo:campo-llamado tareas (n "persona"))))
    (comprobar (null (nucleo:dominio (nucleo:campo-llamado tareas (n "faltan")))))
    ;; La busqueda por clave produce una proyeccion sobre una busqueda.
    (let ((quien (nucleo:expresion (nucleo:campo-llamado tareas (n "quien")))))
      (comprobar (typep quien 'nucleo:proyeccion))
      (comprobar (typep (nucleo:sobre quien) 'nucleo:busqueda))
      (comprobar (nucleo:por-defecto quien)
                 "una busqueda sin valor por defecto es media busqueda"))))

(definir-prueba lenguaje-funciona-desde-cualquier-paquete
    "El lenguaje: los identificadores se normalizan a un paquete propio"
  ;; Una descripcion se escribe desde el paquete de quien la escribe. Si los
  ;; simbolos se compararan por identidad, el lenguaje solo funcionaria desde
  ;; un paquete, que es justo lo que un DSL interno no debe exigir.
  (let* ((s (situacion.lenguaje:situacion-llamada "EJEMPLO"))
         (tareas (nucleo:coleccion-llamada s (n "tareas")))
         (campo (nucleo:campo-llamado tareas (n "faltan"))))
    (comprobar campo "el campo no se encuentra por su nombre normalizado")
    (comprobar (eq (symbol-package (nucleo:nombre campo))
                   (find-package '#:situacion.nombres))
               "el nombre del campo deberia vivir en el paquete de los nombres~@
                de usuario, no con el vocabulario del nucleo: si no, el~@
                invariante I1 acabaria juzgando nombres que eligio otro")))

;;; ---------------------------------------------------------------------
;;; El evaluador de referencia
;;; ---------------------------------------------------------------------

(definir-prueba evaluador-derivaciones
    "Evaluador: aritmetica, busqueda por clave, agregado y distintos"
  (let* ((s (situacion.lenguaje:situacion-llamada "EJEMPLO"))
         (e (nucleo:hacer-entorno s *datos-de-ejemplo*)))
    ;; Aritmetica por fila.
    (comprobar (= 0 (valor e "tareas" 0 "faltan")) "T1: 5-5 deberia dar 0")
    (comprobar (= 3 (valor e "tareas" 1 "faltan")) "T2: 4-1 deberia dar 3")
    ;; Busqueda por clave, con y sin acierto.
    (comprobar (string= "Ana Diaz" (valor e "tareas" 0 "quien"))
               "la busqueda deberia traer el nombre de ana")
    (comprobar (string= "sin asignar" (valor e "tareas" 2 "quien"))
               "sin persona, deberia salir el valor por defecto")
    ;; Agregado con filtro.
    (comprobar (= 2 (valor e "tareas" 0 "carga"))
               "ana tiene dos tareas")
    ;; Conteo de distintos: tres personas, dos areas.
    (comprobar (= 2 (valor e "tareas" 0 "areas"))
               "hay dos areas distintas, no tres")))

(definir-prueba evaluador-marcas-y-concordancia
    "Evaluador: las marcas disparan donde deben, con su explicacion"
  (let* ((s (situacion.lenguaje:situacion-llamada "EJEMPLO"))
         (e (nucleo:hacer-entorno s *datos-de-ejemplo*))
         (filas (nucleo:filas-de e (n "tareas"))))
    (comprobar (null (nucleo:marcas-que-disparan e (first filas)))
               "T1 esta al dia y no deberia marcarse")
    (let ((m (first (nucleo:marcas-que-disparan e (second filas)))))
      (comprobar m "T2 tiene tres tareas pendientes y deberia marcarse")
      (comprobar (string= "Faltan 3" (nucleo:explicacion-de-marca e (second filas) m))
                 "la concordancia de plural deberia dar \"Faltan 3\""))
    (comprobar (null (nucleo:marcas-que-disparan e (third filas)))
               "T3 esta al dia")))

(definir-prueba evaluador-coercion
    "Evaluador: un campo sin rellenar vale cero en aritmetica y vacio en texto"
  ;; Es la misma regla que el corpus aplica a mano en casi toda formula. Que
  ;; este en un solo sitio es lo que permite que las arquitecturas coincidan.
  (comprobar (nucleo:vacio-p ""))
  (comprobar (nucleo:vacio-p nil))
  (comprobar (not (nucleo:vacio-p 0)) "el cero SI esta escrito")
  (comprobar (= 0 (nucleo:como-numero "")))
  (comprobar (= 7 (nucleo:como-numero "7")))
  (comprobar (nucleo:iguales-p "" nil) "dos vacios son iguales entre si")
  (comprobar (not (nucleo:iguales-p "" "a")))
  (comprobar (nucleo:iguales-p 3 3.0)))

;;; ---------------------------------------------------------------------
;;; El analisis estatico
;;; ---------------------------------------------------------------------

(defun problemas-de (constructor)
  "Los problemas que el analisis encuentra en una situacion construida a mano."
  (handler-case (analisis:comprobar-situacion (funcall constructor))
    (error (e) (list (format nil "~a" e)))))

(defun situacion-con-campo (expresion &key (orden nil))
  "Una situacion minima con un campo derivado que usa EXPRESION."
  (let ((coleccion (nucleo:hacer-coleccion
                    :nombre (n "cosas") :etiqueta "Cosas"
                    :orden orden
                    :campos (list (nucleo:hacer-campo :nombre (n "id") :rol :fijo
                                                      :etiqueta "Id")
                                  (nucleo:hacer-campo :nombre (n "calc") :rol :derivado
                                                      :etiqueta "Calc"
                                                      :expresion expresion)))))
    (nucleo:hacer-situacion :nombre (n "prueba") :etiqueta "Prueba"
                            :colecciones (list coleccion))))

(definir-prueba analisis-caza-la-errata
    "Analisis: una referencia a un campo que no existe no llega a ningun backend"
  (let ((problemas (analisis:comprobar-situacion
                    (situacion-con-campo
                     (nucleo:hacer-ref-campo :variable (n "fila")
                                             :campo (n "no-existe"))))))
    (comprobar (= 1 (length problemas)) "deberia haber exactamente un problema")
    (comprobar (search "no-existe" (analisis:texto-de-problema (first problemas)))
               "el mensaje deberia nombrar el campo que falta")
    (comprobar (search "Tiene:" (analisis:texto-de-problema (first problemas)))
               "y deberia decir cuales si existen, que es lo util")))

(definir-prueba analisis-exige-orden-para-la-vecindad
    "Analisis: no se puede hablar de la fila anterior sin orden declarado"
  ;; Es la regla que impide que se cuele el modelo de la hoja de calculo. Sin
  ;; orden declarado, "anterior" solo puede significar "la de arriba", que es
  ;; una propiedad de como se dibuja y no del problema.
  (let* ((vecino (nucleo:hacer-proyeccion
                  :sobre (nucleo:hacer-vecino :direccion :anterior
                                              :variable (n "fila"))
                  :campo (n "id")
                  :por-defecto (nucleo:hacer-literal :valor nil)))
         (sin-orden (analisis:comprobar-situacion (situacion-con-campo vecino)))
         (con-orden (analisis:comprobar-situacion
                     (situacion-con-campo vecino :orden (n "id")))))
    (comprobar (= 1 (length sin-orden)) "sin orden deberia dar un error")
    (comprobar (search "orden" (analisis:texto-de-problema (first sin-orden)))
               "el mensaje deberia explicar que falta el orden")
    (comprobar (null con-orden) "con orden declarado deberia pasar")))

(definir-prueba analisis-caza-el-ciclo
    "Analisis: un campo derivado que depende de si mismo no compila"
  (let* ((coleccion (nucleo:hacer-coleccion
                     :nombre (n "cosas") :etiqueta "Cosas"
                     :campos (list
                              (nucleo:hacer-campo
                               :nombre (n "a") :rol :derivado :etiqueta "A"
                               :expresion (nucleo:hacer-ref-campo
                                           :variable (n "fila") :campo (n "b")))
                              (nucleo:hacer-campo
                               :nombre (n "b") :rol :derivado :etiqueta "B"
                               :expresion (nucleo:hacer-ref-campo
                                           :variable (n "fila") :campo (n "a"))))))
         (s (nucleo:hacer-situacion :nombre (n "ciclo") :etiqueta "Ciclo"
                                    :colecciones (list coleccion)))
         (problemas (analisis:comprobar-situacion s)))
    (comprobar problemas "un ciclo deberia detectarse")
    (comprobar (some (lambda (p) (search "si mismo" (analisis:texto-de-problema p)))
                     problemas)
               "el mensaje deberia decir que depende de si mismo")))

(definir-prueba analisis-acepta-el-corpus
    "Analisis: las dos descripciones del corpus pasan sin errores"
  (dolist (nombre '("PLAN-DEL-GRUPO" "DEFENSAS-DE-TESIS"))
    (let* ((s (situacion.lenguaje:situacion-llamada nombre))
           (problemas (when s (analisis:comprobar-situacion s))))
      (comprobar s "no se encuentra la descripcion ~a" nombre)
      (comprobar (null problemas)
                 "~a deberia pasar el analisis y da: ~{~a~^; ~}"
                 nombre (mapcar #'analisis:texto-de-problema problemas)))))
