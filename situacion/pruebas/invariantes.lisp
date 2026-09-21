;;;; Invariantes arquitectonicos.
;;;;
;;;; Las afirmaciones del tipo "el nucleo es independiente de la
;;;; arquitectura" son las que se caen en las defensas. Aqui dejan de ser
;;;; afirmaciones.
;;;;
;;;; De momento estan I1, I2 e I3, que son los que se pueden comprobar con lo
;;;; que hay construido. I4 a I8 entran conforme haya de donde.

(in-package #:situacion.pruebas)

;;; ---------------------------------------------------------------------
;;; I1 - Lexico del nucleo y del protocolo
;;; ---------------------------------------------------------------------

(defparameter *vocabulario-de-direccionamiento*
  '("CELDA" "COORDENADA" "LETRA-DE-COLUMNA" "NUMERO-DE-FILA"
    "RANGO" "HOJA" "LIBRO"
    "COUNTIF" "COUNTIFS" "COUNTA" "SUMIF" "SUMIFS" "SUMPRODUCT"
    "VLOOKUP" "BUSCARV" "IFERROR" "OFFSET"
    "EXCEL" "OPENPYXL" "XLSX")
  "Palabras que no pueden aparecer en el nombre de ningun simbolo del nucleo
   ni del protocolo.

   DOS MATICES QUE HACEN QUE ESTA PRUEBA SIRVA DE ALGO.

   Primero: la lista es de DIRECCIONAMIENTO, no de estructura. FILA, CAMPO y
   COLECCION son vocabulario del dominio y estan permitidos. Una coleccion
   tiene filas y (DE FILA CAMPO) se lee perfectamente. Lo prohibido es la
   direccion de una fila, no su existencia.

   Segundo: la comprobacion es sobre SIMBOLOS, no sobre el texto del
   archivo. Los comentarios pueden hablar de Excel todo lo que haga falta
   para explicar por que algo esta como esta -y de hecho lo hacen, porque
   media arquitectura se justifica contra lo que hizo la tesis de 2026-. Lo
   que no puede haber es una funcion llamada LETRA-DE-COLUMNA.")

(defparameter *vocabulario-prohibido-solo-en-el-nucleo*
  '("REJILLA" "ARQUITECTURA" "BACKEND")
  "Palabras que el protocolo si puede usar y el nucleo no.

   La distincion importa y conviene dejarla por escrito. El protocolo tiene
   que poder nombrar la capacidad CON-REJILLA: que una arquitectura declare
   si organiza sus elementos en filas y columnas es informacion sobre la
   arquitectura, no sobre la situacion, y el mecanismo de degradacion no
   existe sin ella.

   El nucleo, en cambio, no tiene ningun motivo para saber que existe algo
   llamado rejilla, ni algo llamado arquitectura. Si algun dia lo necesita,
   no es que le falte un sinonimo: es que se ha metido el destino en el
   modelo, que es exactamente como la tesis de 2026 acabo con REGION, NAV y
   ANCHOR dentro de un arbol supuestamente independiente.")

(defun vocabulario-prohibido-en (nombre-de-paquete)
  (if (string= nombre-de-paquete "SITUACION.NUCLEO")
      (append *vocabulario-de-direccionamiento*
              *vocabulario-prohibido-solo-en-el-nucleo*)
      *vocabulario-de-direccionamiento*))

(defun simbolos-propios (nombre-de-paquete)
  "Los simbolos cuyo paquete de origen es NOMBRE-DE-PAQUETE.

   No vale DO-SYMBOLS a secas: incluiria los heredados de COMMON-LISP, y
   entonces la prueba estaria juzgando simbolos que no son nuestros."
  (let ((paquete (find-package nombre-de-paquete))
        (propios '()))
    (when paquete
      (do-symbols (simbolo paquete)
        (when (eq (symbol-package simbolo) paquete)
          (pushnew simbolo propios))))
    propios))

(defun palabra-prohibida (simbolo prohibidas)
  "La primera palabra de PROHIBIDAS que aparece en SIMBOLO, o NIL."
  (let ((nombre (symbol-name simbolo)))
    (find-if (lambda (palabra) (search palabra nombre)) prohibidas)))

(definir-prueba i1-lexico
    "I1: ni el nucleo ni el protocolo nombran direcciones"
  (dolist (paquete '("SITUACION.NUCLEO" "SITUACION.PROTOCOLO"))
    (comprobar (find-package paquete)
               "el paquete ~a no existe" paquete)
    (let ((prohibidas (vocabulario-prohibido-en paquete)))
      (dolist (simbolo (simbolos-propios paquete))
        (let ((palabra (palabra-prohibida simbolo prohibidas)))
          (comprobar (null palabra)
                     "~a contiene ~s, que es vocabulario prohibido en ~a.~@
                      Si de verdad hace falta ese concepto aqui, no es un~@
                      problema de nombre: es que se ha colado el destino en~@
                      el modelo."
                     simbolo palabra paquete))))))

(definir-prueba i1-la-prueba-lexica-muerde
    "I1: la comprobacion lexica detecta un simbolo prohibido"
  ;; Sin esto, I1 pasaria igual de verde con la lista vacia o con un error
  ;; de logica que hiciera que nunca encontrara nada. Se comprueba contra
  ;; simbolos inventados, sin tocar los paquetes de verdad.
  (let ((malos '("LETRA-DE-COLUMNA" "PRIMERA-CELDA" "RANGO-DINAMICO"
                 "COMPILAR-FORMULA-EXCEL" "CONTAR-CON-COUNTIF"))
        (buenos '("FILA" "CAMPO" "COLECCION" "DERIVACION" "AMBITO" "MARCA")))
    (dolist (nombre malos)
      (comprobar (palabra-prohibida (make-symbol nombre)
                                    *vocabulario-de-direccionamiento*)
                 "~a deberia estar prohibido y no se detecta" nombre))
    (dolist (nombre buenos)
      (comprobar (null (palabra-prohibida (make-symbol nombre)
                                          *vocabulario-de-direccionamiento*))
                 "~a es vocabulario legitimo del dominio y se esta~@
                  rechazando. FILA es palabra del dominio: lo prohibido es~@
                  la direccion de una fila, no su existencia."
                 nombre))
    ;; Y la distincion entre el nucleo y el protocolo.
    (comprobar (null (palabra-prohibida (make-symbol "CON-REJILLA")
                                        (vocabulario-prohibido-en
                                         "SITUACION.PROTOCOLO")))
               "el protocolo tiene que poder nombrar la capacidad CON-REJILLA")
    (comprobar (palabra-prohibida (make-symbol "CON-REJILLA")
                                  (vocabulario-prohibido-en
                                   "SITUACION.NUCLEO"))
               "el nucleo no tiene por que saber que existe una rejilla")))

;;; ---------------------------------------------------------------------
;;; I2 - Firma del protocolo
;;;
;;; El invariante central del trabajo. Es la deteccion automatica del fallo
;;; que dejo sin cerrar la tesis de 2026: su COMPILE-EXCEL-FORMULA no recibia
;;; el destino, asi que no habia donde enganchar una segunda arquitectura.
;;; ---------------------------------------------------------------------

(defun generica-p (simbolo)
  (and (fboundp simbolo)
       (typep (fdefinition simbolo) 'generic-function)))

(definir-prueba i2-toda-operacion-recibe-la-arquitectura
    "I2: toda operacion del protocolo despacha sobre la arquitectura"
  (let ((registradas (situacion.protocolo::operaciones-registradas)))
    (comprobar (plusp (length registradas))
               "el registro de operaciones esta vacio")
    ;; Todas las registradas cumplen la firma.
    (dolist (entrada registradas)
      (destructuring-bind (nombre . lambda-lista) entrada
        (comprobar (situacion.protocolo::parametro-de-arquitectura-p lambda-lista)
                   "la operacion ~a tiene lambda-lista ~s, que no empieza~@
                    por ARQUITECTURA"
                   nombre lambda-lista)))))

(defparameter *genericas-que-no-son-operaciones*
  '("CAPACIDAD-PEDIDA" "NODO-AFECTADO" "ARQUITECTURA-AFECTADA"
    "DETALLE-DE-LA-CARENCIA")
  "Funciones genericas exportadas por el protocolo que NO son operaciones.

   Son los lectores de las condiciones CARENCIA-DE-CAPACIDAD y
   CAPACIDAD-NO-DISPONIBLE, que Common Lisp genera como genericas al declarar
   la condicion. Leen un objeto de condicion, no despachan sobre una
   arquitectura, y no son puntos de extension: nadie las especializa al anadir
   un destino.

   La lista es EXPLICITA y corta a proposito. La alternativa -reconocerlas por
   alguna regla automatica- dejaria la puerta abierta a que una operacion de
   verdad se colara por la misma via. Anadir un nombre aqui tiene que ser un
   acto deliberado que se vea en la revision.")

(definir-prueba i2-ninguna-generica-se-cuela-sin-registrar
    "I2: no hay genericas exportadas por el protocolo fuera del registro"
  (let ((registradas (mapcar #'car (situacion.protocolo::operaciones-registradas)))
        (paquete (find-package "SITUACION.PROTOCOLO")))
    (do-external-symbols (simbolo paquete)
      (when (and (generica-p simbolo)
                 (not (member (symbol-name simbolo)
                              *genericas-que-no-son-operaciones*
                              :test #'string=)))
        (comprobar (member simbolo registradas)
                   "~a es una funcion generica exportada por el protocolo~@
                    pero no se declaro con DEFINIR-OPERACION, asi que nadie~@
                    ha comprobado que reciba la arquitectura"
                   simbolo)))))

(definir-prueba i2-se-rechaza-una-operacion-sin-arquitectura
    "I2: declarar una operacion sin arquitectura no compila"
  ;; La prueba negativa, que es la que demuestra que el invariante muerde.
  ;; Se intenta declarar una operacion con la misma forma que tenia la de
  ;; 2026 y se espera que el macro la rechace en tiempo de expansion.
  (let ((rechazada
          (handler-case
              (progn
                (macroexpand-1
                 '(situacion.protocolo::definir-operacion compilar-formula
                   (nodo mapa-de-columnas fila primera-fila ultima-fila)))
                nil)
            (error () t))))
    (comprobar rechazada
               "DEFINIR-OPERACION acepto una operacion que no recibe la~@
                arquitectura. El invariante no sirve de nada asi."))
  ;; Y el caso positivo, para que la prueba no pase por el motivo equivocado
  ;; (por ejemplo, porque el macro falle siempre).
  (let ((aceptada
          (handler-case
              (progn
                (macroexpand-1
                 '(situacion.protocolo::definir-operacion operacion-de-prueba
                   (arquitectura nodo plan)))
                t)
            (error () nil))))
    (comprobar aceptada
               "DEFINIR-OPERACION rechazo una operacion bien formada")))

;;; ---------------------------------------------------------------------
;;; I3 - Grafo de dependencias
;;;
;;; Lo que impide que una arquitectura vea el lenguaje, o que dos
;;; arquitecturas se vean entre si. La independencia deja de ser una promesa
;;; y pasa a ser algo que la herramienta no deja violar.
;;; ---------------------------------------------------------------------

(defparameter *dependencias-permitidas*
  '(("situacion/nucleo"    . ())
    ("situacion/corpus"    . ("situacion/lenguaje"))
    ("situacion/protocolo" . ("situacion/nucleo"))
    ("situacion/lenguaje"  . ("situacion/nucleo"))
    ("situacion/analisis"  . ("situacion/nucleo")))
  "De quien puede depender cada sistema. Un sistema que no este en esta
   tabla no se comprueba, pero tampoco puede ser una arquitectura: para esas
   esta la regla aparte de mas abajo.")

(defun dependencias-de (nombre)
  "Las dependencias declaradas de un sistema, como cadenas en minusculas.
   NIL si el sistema no existe todavia."
  (let ((sistema (asdf:find-system nombre nil)))
    (when sistema
      (mapcar (lambda (d) (string-downcase (princ-to-string d)))
              (asdf:system-depends-on sistema)))))

(definir-prueba i3-dependencias-declaradas
    "I3: cada sistema depende solo de lo que tiene permitido"
  (loop for (sistema . permitidas) in *dependencias-permitidas*
        for declaradas = (dependencias-de sistema)
        when (asdf:find-system sistema nil)
          do (dolist (d declaradas)
               (comprobar (member d permitidas :test #'string=)
                          "~a depende de ~a, que no esta permitido.~@
                           Solo puede depender de: ~{~a~^, ~}"
                          sistema d (or permitidas '("nada"))))))

(definir-prueba i3-el-protocolo-no-ve-el-lenguaje
    "I3: el protocolo no depende del lenguaje"
  ;; El contrato de extension se define contra el dominio, no contra la
  ;; sintaxis. Si el protocolo pudiera ver las macros, acabaria usandolas y
  ;; una arquitectura tendria que conocer el lenguaje para existir.
  (comprobar (not (member "situacion/lenguaje"
                          (dependencias-de "situacion/protocolo")
                          :test #'string=))
             "el protocolo depende del lenguaje"))

(definir-prueba i3-ninguna-arquitectura-ve-a-otra
    "I3: las arquitecturas dependen del protocolo y de nada mas"
  ;; Todavia no hay arquitecturas; la prueba pasa en vacio a proposito, para
  ;; que este escrita el dia que entre la primera y no haya que acordarse.
  (let ((arquitecturas '("situacion/texto" "situacion/excel"
                         "situacion/web" "situacion/sql")))
    (dolist (a arquitecturas)
      (when (asdf:find-system a nil)
        (dolist (d (dependencias-de a))
          (comprobar (string= d "situacion/protocolo")
                     "la arquitectura ~a depende de ~a. Una arquitectura~@
                      depende del protocolo y de nada mas: ni del lenguaje,~@
                      ni de otra arquitectura. Lo que dos compartan sube a~@
                      una clase de capacidad."
                     a d))))))
