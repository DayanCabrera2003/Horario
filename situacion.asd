;;;; Definicion de sistemas.
;;;;
;;;; El grafo de dependencias de este archivo no es administrativo: es la
;;;; prueba de dos de los criterios de diseno.
;;;;
;;;;   - Una arquitectura depende del protocolo y de nada mas. No puede ver
;;;;     el lenguaje, asi que no puede usar sus macros ni por descuido.
;;;;   - Ninguna arquitectura depende de otra. Lo que compartan sube a una
;;;;     clase de capacidad, que es el unico sitio donde se comparte.
;;;;
;;;; El invariante I3 lee estas declaraciones y comprueba que se cumplen.
;;;;
;;;; Nota sobre el nombre: "situacion" es provisional. El nombre del lenguaje
;;;; no esta decidido todavia.

(defsystem "situacion"
  :description "Lenguaje para describir situaciones tabulares y materializarlas
                en varias arquitecturas de salida."
  :author "Dayan Cabrera"
  :license "por decidir"
  :version "0.1.0"
  :depends-on ("situacion/nucleo"
               "situacion/protocolo")
  :in-order-to ((test-op (test-op "situacion/pruebas"))))

;;; El nucleo no depende de nada. Es lo que garantiza que la representacion
;;; intermedia no pueda contaminarse: no hay nada de donde contaminarse.
(defsystem "situacion/nucleo"
  :description "El modelo semantico: situaciones, colecciones, campos,
                expresiones, ambitos, marcas y vistas. No sabe que existe
                ninguna arquitectura."
  :depends-on ()
  :pathname "nucleo/"
  :serial t
  :components ((:file "paquete")
               (:file "nodo")
               (:file "modelo")
               (:file "expresion")
               (:file "ambito")
               (:file "evaluador")))

;;; El protocolo depende del nucleo y de nada mas. En particular NO depende
;;; del lenguaje: el contrato de extension se define contra el dominio, no
;;; contra la sintaxis.
;;; El lenguaje depende del nucleo. Ninguna arquitectura depende de el.
(defsystem "situacion/lenguaje"
  :description "La sintaxis: las macros que construyen el arbol en tiempo de
                expansion."
  :depends-on ("situacion/nucleo")
  :pathname "lenguaje/"
  :serial t
  :components ((:file "paquete")
               (:file "expresiones")
               (:file "macros")))

(defsystem "situacion/protocolo"
  :description "El contrato de extension: la jerarquia de capacidades y las
                operaciones que una arquitectura debe especializar."
  :depends-on ("situacion/nucleo")
  :pathname "protocolo/"
  :serial t
  :components ((:file "paquete")
               (:file "operacion")
               (:file "capacidades")
               (:file "genericas")
               (:file "informe")
               (:file "carencia")
               (:file "requerimientos")))

;;; El analisis depende del nucleo. Ninguna arquitectura depende de el: para
;;; cuando llega un backend, la descripcion ya esta comprobada.
(defsystem "situacion/analisis"
  :description "Comprobaciones estaticas, independientes de arquitectura."
  :depends-on ("situacion/nucleo")
  :pathname "analisis/"
  :serial t
  :components ((:file "paquete")
               (:file "comprobacion")))

;;; Las pruebas dependen de todo, y no al reves.
(defsystem "situacion/pruebas"
  :description "Pruebas del sistema: invariantes arquitectonicos, nucleo,
                analisis y juego de conformidad.

                Depende de todo, y nada depende de ella. Es el unico sistema
                que puede mirar dentro de los demas."
  :depends-on ("situacion/nucleo" "situacion/protocolo" "situacion/lenguaje"
               "situacion/analisis" "situacion/corpus"
               "situacion/texto" "situacion/excel" "situacion/web")
  :pathname "pruebas/"
  :serial t
  :components ((:file "paquete")
               (:file "marco")
               (:file "invariantes")
               (:file "nucleo")
               (:file "alcance")
               (:file "conformidad")
               (:file "vistas")
               (:file "relacion")
               (:file "formula")
               (:file "particion-en-archivo")
               (:file "ejecutar"))
  :perform (test-op (op system)
                    (uiop:symbol-call :situacion.pruebas :ejecutar)))


;;; --- Las arquitecturas. Cada una depende del protocolo y de nada mas. ---
;;; Ninguna depende del lenguaje (no puede ver las macros) ni de otra. Lo
;;; comprueba el invariante I3.

(defsystem "situacion/texto"
  :description "Arquitectura de salida a texto plano. Existe para que haya dos
                arquitecturas desde el primer dia."
  :depends-on ("situacion/protocolo")
  :pathname "texto/"
  :serial t
  :components ((:file "arquitectura")
               (:file "emision")))

(defsystem "situacion/excel"
  :description "Arquitectura de salida a hoja de calculo."
  :depends-on ("situacion/protocolo")
  :pathname "excel/"
  :serial t
  :components ((:file "arquitectura")
               (:file "plan")
               (:file "plano")
               (:file "relacion")
               (:file "particion-en-archivo")
               (:file "formula")
               (:file "emision")))

(defsystem "situacion/web"
  :description "Arquitectura de salida a pagina web con recalculo vivo."
  :depends-on ("situacion/protocolo")
  :pathname "web/"
  :serial t
  :components ((:file "arquitectura")
               (:file "recursos")
               (:file "expresiones")
               (:file "emision")))

;;; --- El corpus y la demostracion ---

(defsystem "situacion/corpus"
  :description "Los libros de la facultad, descritos en el lenguaje. Son a la
                vez el vocabulario del que sale el lenguaje y el oraculo
                contra el que se valida."
  :depends-on ("situacion/lenguaje")
  :pathname "corpus/"
  :serial t
  :components ((:file "paquete")
               (:file "plan-del-grupo")
               (:file "defensas-de-tesis")
               (:file "horario-del-grupo")))

(defsystem "situacion/demostracion"
  :description "Genera los artefactos de las tres arquitecturas a partir de
                las mismas descripciones."
  :depends-on ("situacion/corpus" "situacion/analisis"
               "situacion/texto" "situacion/excel" "situacion/web")
  :pathname "demostracion/"
  :serial t
  :components ((:file "demostracion")))
