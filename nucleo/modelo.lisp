;;;; El modelo de una situacion.
;;;;
;;;; Los nodos de estructura: situacion, parametro, coleccion, campo, marca y
;;;; vista. Las expresiones van aparte, en expresion.lisp.
;;;;
;;;; Tres decisiones de este archivo merecen justificarse, porque son de las
;;;; que separan este modelo de los de 2025 y 2026.
;;;;
;;;; EL ROL DE CAMPO. No aparece en ninguna de las tres tesis anteriores. De
;;;; una sola declaracion salen, en una hoja de calculo, el bloqueo y el
;;;; color; en una pagina, si el campo es un control de entrada o un texto;
;;;; en una base de datos, si es columna o vista; en un editor, si el cursor
;;;; puede entrar ahi. Sale del corpus: donde hoy hay una llamada de proteccion
;;;; por hoja, repartidas por catorce sitios de los cuatro generadores, hay un
;;;; solo hecho del dominio.
;;;;
;;;; EL CRECIMIENTO DECLARA INTENCION, NO MECANISMO. :CRECE dice que la lista
;;;; no esta cerrada y que el usuario anadira filas despues de generar. Eso
;;;; es un hecho del dominio. Las filas de reserva y el rango que crece con
;;;; lo escrito son lo que una arquitectura de rejilla se inventa para
;;;; cumplirlo; una pagina pone un boton. El lenguaje no nombra ninguna de
;;;; las dos cosas.
;;;;
;;;; LA MARCA DECLARA SIGNIFICADO, NO COLOR. La definicion 3.8 de 2026 dice
;;;; que una regla de marcado tiene una condicion y un color de fondo; su
;;;; nodo no tiene color, y las tres reglas de su caso real se distinguen por
;;;; comentarios y por orden. Aqui la marca tiene nombre y severidad, y como
;;;; se ve lo decide cada arquitectura. El color no sobrevive al cambio de
;;;; destino; el significado si.

(in-package #:situacion.nucleo)

;;; ---------------------------------------------------------------------
;;; Estructura
;;; ---------------------------------------------------------------------

(defnodo parametro ()
  ((nombre "Simbolo que lo identifica.")
   (etiqueta "Como se muestra.")
   (tipo "Uno de :TEXTO :ENTERO :NUMERO :HORA :FECHA :BOOLEANO.")
   (rol ":FIJO si se establece al generar, :ENTRADA si el usuario lo edita.")
   (valor "Valor inicial."))
  "Una constante con nombre. Un tope de carga docente se edita en el
   documento; una constante del dominio, no. Por eso lleva rol.")

(defnodo campo ()
  ((nombre "Identificador interno, un simbolo.")
   (etiqueta "Lo que se ve. Separado del identificador a proposito.")
   (tipo "Uno de :TEXTO :ENTERO :NUMERO :HORA :FECHA :BOOLEANO.")
   (rol ":FIJO se escribe al generar, :ENTRADA lo escribe el usuario,
         :DERIVADO se calcula.")
   (opcional "Si puede quedarse sin valor.")
   (dominio "Expresion de conjunto con los valores admisibles. Solo si el rol
             es :ENTRADA.")
   (al-violar ":ADVERTIR o :IMPEDIR. Hay restricciones que invalidan y
               restricciones que solo avisan, y la diferencia es del dominio:
               los desplegables del corpus avisan sin bloquear.")
   (expresion "Como se calcula. Solo si el rol es :DERIVADO."))
  "Un atributo compartido por todas las filas de una coleccion.")

(defnodo coleccion ()
  ((nombre "Simbolo que la identifica.")
   (etiqueta "Como se muestra.")
   (campos "Lista de campos.")
   (clave "Lista de campos que identifican una fila. Puede ser compuesta.")
   (orden "Campo por el que esta ordenada, o NIL. Sin orden declarado no se
           puede hablar de la fila anterior ni de la siguiente.")
   (crecimiento "NIL o :CRECE. Intencion, nunca mecanismo.")
   (origen ":DECLARADA, o (:UNA-FILA-POR campo :DE coleccion) para una
            coleccion que se proyecta de otra.")
   (datos "Las filas conocidas al generar, como lista de listas de valores en
           el orden de los campos de rol :FIJO."))
  "Una coleccion de filas homogeneas.")

(defnodo marca ()
  ((nombre "El significado. Nunca un color.")
   (coleccion "Coleccion cuyas filas se evaluan. Si dos colecciones tienen
               campos con el mismo nombre, hay que decirlo; si no, se deduce.")
   (condicion "Expresion booleana, evaluada por fila.")
   (alcance "Campos sobre los que se senala.")
   (severidad ":INFORMATIVA, :ADVERTENCIA o :PROBLEMA.")
   (explicacion "Expresion de texto que dice por que, o NIL."))
  "Una condicion que senala un estado con nombre.

   Que la marca declare significado y no color es lo que permite que
   sobreviva al cambio de arquitectura: en una hoja de calculo es un relleno,
   en una pagina un color con un icono, en un editor un estilo de texto, y en
   una impresion en blanco y negro tiene que ser texto o no se ve nada.")

(defnodo vista ()
  ((nombre "Simbolo que la identifica.")
   (etiqueta "Titulo visible.")
   (fuente "Coleccion que muestra.")
   (secciones "Campo por cuyo valor se parte en secciones, o NIL.")
   (agrupacion "Campo por el que se agrupa dentro de cada seccion, o NIL.")
   (eje-de-filas "Campo cuyos valores van en el eje vertical, o NIL.")
   (eje-de-columnas "Campo cuyos valores van en el eje horizontal, o NIL.")
   (lo-que-se-muestra "Campo que aparece en el cruce de los dos ejes, o NIL.")
   (es-entrada "Si es el punto de entrada del documento."))
  "Como se organiza y se recorre lo que hay. Sin una sola coordenada: las
   secciones se declaran por el campo que las distingue, no por donde caen.

   LA TABLA CRUZADA ES UNA VISTA, NO UNA ESTRUCTURA DE DATOS. Un cuadrante de
   turnos o un horario de dia por turno parecen una matriz, y no lo son: los
   datos siguen siendo una coleccion de filas -dia, turno, persona-, y lo que
   cambia es como se presentan. Declararlo aqui y no en la coleccion es
   aplicar el mismo criterio que el resto del lenguaje: la intencion se
   declara, el mecanismo lo inventa cada arquitectura.

   Es tambien lo que hace barato lo que parecia caro. Meter matrices en el
   modelo de datos habria tocado el nucleo, el analisis y las tres
   arquitecturas; como vista, son tres ranuras y un metodo por destino.")

(defnodo situacion ()
  ((nombre "Simbolo que la identifica.")
   (etiqueta "Titulo del documento.")
   (parametros "Lista de parametros.")
   (colecciones "Lista de colecciones.")
   (marcas "Lista de marcas.")
   (vistas "Lista de vistas."))
  "Una situacion tabular completa.")

;;; ---------------------------------------------------------------------
;;; Consultas sobre el modelo
;;; ---------------------------------------------------------------------

(defun cruzada-p (vista)
  "Cierto si VISTA declara los dos ejes y la celda."
  (and (eje-de-filas vista) (eje-de-columnas vista) (lo-que-se-muestra vista)))

(defun coleccion-llamada (situacion nombre)
  "La coleccion de SITUACION llamada NOMBRE, o NIL."
  (find nombre (colecciones situacion) :key #'nombre))

(defun campo-llamado (coleccion nombre)
  "El campo de COLECCION llamado NOMBRE, o NIL."
  (find nombre (campos coleccion) :key #'nombre))

(defun campos-de-rol (coleccion rol)
  "Los campos de COLECCION cuyo rol es ROL, en orden de declaracion."
  (remove-if-not (lambda (c) (eq (rol c) rol)) (campos coleccion)))

(defun parametro-llamado (situacion nombre)
  (find nombre (parametros situacion) :key #'nombre))
