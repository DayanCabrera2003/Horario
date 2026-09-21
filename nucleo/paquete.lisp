;;;; Paquete del nucleo semantico.
;;;;
;;;; Aqui vive el modelo de la situacion: colecciones, campos, expresiones,
;;;; ambitos, marcas y vistas. Nada de este paquete sabe que existe ninguna
;;;; arquitectura de salida.
;;;;
;;;; Regla lexica (invariante I1): ningun simbolo de este paquete puede
;;;; nombrar una direccion. Ni letra de columna, ni coordenada, ni numero de
;;;; fila, ni rango, ni celda, ni el nombre de ninguna funcion de hoja de
;;;; calculo. Tampoco puede nombrar la rejilla ni la arquitectura: el nucleo
;;;; no tiene por que saber que existen.
;;;;
;;;; La regla es sobre simbolos, no sobre el texto del archivo: los
;;;; comentarios pueden hablar de Excel todo lo que haga falta para explicar
;;;; por que algo esta como esta.
;;;;
;;;; Y ojo con el matiz que hace que la prueba sirva de algo: FILA si es
;;;; palabra del dominio. Una coleccion tiene filas, y (DE FILA CAMPO) es
;;;; vocabulario legitimo. Lo prohibido es la DIRECCION de una fila, no su
;;;; existencia.

(defpackage #:situacion.nombres
  (:use)
  (:documentation
   "Los identificadores que elige quien escribe una descripcion: nombres de
    coleccion, de campo, de vista, de marca, y las variables de fila.

    Viven aparte del nucleo a proposito. Si se internaran con el vocabulario
    del lenguaje, el invariante I1 estaria juzgando nombres que no son del
    sistema: alguien puede llamar REJILLA a una vista sin que el nucleo haya
    nombrado ninguna rejilla."))

(defpackage #:situacion.nucleo
  (:use #:common-lisp)
  (:nicknames #:nucleo)
  ;; VARIABLE es un simbolo de COMMON-LISP y su paquete esta bloqueado, asi
  ;; que no se puede definir un accesor con ese nombre sin sombrearlo. Se
  ;; sombrea a proposito y no se renombra el slot: "variable de fila" es el
  ;; termino correcto del dominio y cambiarlo por uno peor para esquivar una
  ;; colision tecnica seria dejar que la implementacion mande sobre el
  ;; vocabulario, que es justo lo que este trabajo critica.
  (:shadow #:variable)
  (:documentation
   "Modelo semantico de una situacion tabular, independiente de cualquier
    arquitectura de salida.")
  (:export
   ;; Infraestructura de nodos
   #:nodo #:defnodo

   ;; Estructura
   #:situacion #:hacer-situacion
   #:nombre #:parametros #:colecciones #:marcas #:vistas
   #:parametro #:hacer-parametro #:valor
   #:coleccion #:hacer-coleccion
   #:campos #:clave #:orden #:crecimiento #:datos #:origen
   #:campo #:hacer-campo
   #:etiqueta #:tipo #:rol #:opcional #:dominio #:al-violar #:expresion
   #:marca #:hacer-marca
   #:condicion #:alcance #:severidad #:explicacion
   #:vista #:hacer-vista
   #:fuente #:secciones #:agrupacion #:filtro #:conflicto #:es-entrada
   #:eje-de-filas #:eje-de-columnas #:lo-que-se-muestra #:cruzada-p

   ;; Expresiones
   #:literal #:hacer-literal
   #:ref-parametro #:hacer-ref-parametro
   #:ref-campo #:hacer-ref-campo #:variable
   #:aplicacion #:hacer-aplicacion #:operador #:argumentos
   #:condicional #:hacer-condicional #:prueba #:entonces #:si-no
   #:sin-escribir #:hacer-sin-escribir #:argumento
   #:concatenacion #:hacer-concatenacion #:partes
   #:concordancia #:hacer-concordancia #:cantidad #:singular #:plural
   #:conjunto #:hacer-conjunto
   #:enumeracion #:hacer-enumeracion
   #:relacionadas #:hacer-relacionadas
   #:agregado #:hacer-agregado #:operacion
   #:busqueda #:hacer-busqueda
   #:proyeccion #:hacer-proyeccion #:sobre #:por-defecto
   #:existe #:hacer-existe #:distinta-de
   #:comparten #:hacer-comparten #:variable-a #:variable-b
   #:vecino #:hacer-vecino #:direccion

   ;; Ambitos
   #:ambito #:hacer-ambito #:ligaduras #:actual
   #:ambito-extendido #:coleccion-de-variable #:variable-ligada-p

   ;; Utilidades del modelo
   #:campo-llamado #:coleccion-llamada #:campos-de-rol #:nombrar
   #:recorrer-expresion #:subexpresiones

   ;; Evaluador de referencia
   #:entorno #:hacer-entorno #:filas-de #:fila #:hacer-fila #:valores
   #:evaluar #:valor-de-campo #:marcas-que-disparan #:evaluar-situacion
   #:explicacion-de-marca #:evaluar-en-fila #:parametro-llamado #:indice
   #:vacio-p #:como-numero #:como-texto #:iguales-p
   #:error-de-evaluacion #:mensaje-de-error))
