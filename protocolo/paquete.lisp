;;;; Paquete del protocolo de arquitectura.
;;;;
;;;; Este paquete es el contrato de extension: lo que recibe quien quiera
;;;; incorporar una arquitectura de salida nueva sin tocar el nucleo.
;;;;
;;;; Se rige por la misma regla lexica que el nucleo (invariante I1): ningun
;;;; simbolo de aqui puede nombrar una direccion. Un parametro del protocolo
;;;; no puede tener forma de hoja de calculo.
;;;;
;;;; Y por una segunda, que es la que da nombre al trabajo (invariante I2):
;;;; toda operacion del protocolo recibe la arquitectura como primer
;;;; parametro. No es una convencion que se vigile a mano; el macro
;;;; DEFINIR-OPERACION rechaza en tiempo de expansion cualquier operacion
;;;; que no lo cumpla.
;;;;
;;;; Este paquete no depende del lenguaje. El contrato se define contra el
;;;; dominio, no contra la sintaxis, y no contra su primer implementador.

(defpackage #:situacion.protocolo
  (:use #:common-lisp)
  (:nicknames #:protocolo)
  (:documentation
   "Contrato de extension: la jerarquia de capacidades y las operaciones que
    una arquitectura de salida debe especializar.")
  (:export
   ;; La raiz de la jerarquia.
   #:arquitectura

   ;; Las capacidades componibles.
   #:con-rejilla
   #:con-derivacion-viva
   #:con-derivacion-por-consulta
   #:con-entrada
   #:con-dominio-de-entrada
   #:con-orden-declarado
   #:con-busqueda-por-clave
   #:con-relacion-uno-a-muchos
   #:con-tabla-cruzada
   #:con-agrupacion
   #:con-conteo-de-distintos
   #:con-crecimiento
   #:con-marcado-visual
   #:con-marcado-textual
   #:con-particion-de-vista
   #:con-agrupacion-en-vista
   #:con-navegacion

   ;; Declaracion de la arquitectura.
   #:capacidades
   #:nivel-de-recalculo

   ;; Planificacion (fase 5).
   #:planificar
   #:planificar-coleccion
   #:planificar-campo
   #:planificar-vista

   ;; Emision (fase 6).
   #:emitir
   #:emitir-expresion
   #:emitir-marca
   #:emitir-entrada
   #:emitir-vista

   ;; Carencias y degradacion.
   #:resolver-carencia
   #:requerir #:cumple-p #:*politica*
   #:carencia-de-capacidad #:capacidad-no-disponible
   #:capacidad-pedida #:nodo-afectado #:arquitectura-afectada

   ;; Informe de conformidad.
   #:con-informe #:informe-vacio #:escribir-informe #:resumen-de-informe
   #:entradas-del-informe #:arquitectura-del-informe
   #:entrada-de-informe-respuesta #:entrada-de-informe-capacidad
   #:entrada-de-informe-nota

   ;; Planificacion de alto nivel
   #:materializar
   #:requerimientos))
