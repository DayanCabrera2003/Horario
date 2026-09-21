;;;; El algebra de expresion.
;;;;
;;;; Cada construccion de aqui esta en el corpus. No hay ninguna por si acaso.
;;;; La justificacion, construccion a construccion:
;;;;
;;;;   BUSQUEDA y PROYECCION   once usos de BUSCARV: tribunales/hoja_dia.py:42,
;;;;                           departamento/hoja_asignacion.py:88 y
;;;;                           hoja_carga.py:102, horarios/hoja_grupo.py:291.
;;;;                           Es lo que 2025 llamo "consulta" y 2026 dejo fuera.
;;;;   clave compuesta         horarios/hoja_grupo.py:291, clave "<grupo>#<asig>".
;;;;   AGREGADO                CONTAR.SI, SUMAR.SI y sus variantes con varios
;;;;                           criterios, en departamento/hoja_cobertura.py.
;;;;   :DISTINTAS              departamento/hoja_datos.py, columnas L y M.
;;;;   EXISTE y COMPARTEN      la deteccion de colisiones, en los tres libros.
;;;;   CONCORDANCIA            departamento/hoja_cobertura.py, "Falta 1 profesor"
;;;;                           frente a "Faltan N profesores".
;;;;   VECINO                  la parrilla de television de 2026 y el aula de la
;;;;                           fila de abajo en el horario.
;;;;   SIN-ESCRIBIR            la guarda que abre casi toda formula del corpus.
;;;;
;;;; LO QUE SE REHACE DE 2026. Su EXPR-COUNTA -"contar celdas no vacias"- no
;;;; entra. En el dominio la pregunta es cuantas filas hay, y eso es un
;;;; agregado de conteo. "Celda vacia" solo tiene sentido donde hay una
;;;; rejilla preasignada con huecos, y esa rejilla es invencion del destino.
;;;; SIN-ESCRIBIR si entra, pero significa otra cosa: un campo de entrada que
;;;; el usuario todavia no ha rellenado, que si es un hecho del dominio.

(in-package #:situacion.nucleo)

(defnodo expresion () ()
  "Raiz de las expresiones.")

(defnodo literal (expresion)
  ((valor "Numero, cadena, booleano o NIL."))
  "Un valor escrito tal cual.")

(defnodo ref-parametro (expresion)
  ((nombre "Nombre del parametro."))
  "El valor de un parametro con nombre.")

(defnodo ref-campo (expresion)
  ((variable "Variable de fila ligada, por ejemplo FILA u OTRA.")
   (campo "Nombre del campo."))
  "El valor de un campo en la fila a la que apunta VARIABLE.

   Notese que no hay forma de escribir esto sin nombrar una variable de fila.
   La iteracion es siempre explicita: no existe 'la fila actual' implicita ni
   'la celda de arriba'.")

(defnodo aplicacion (expresion)
  ((operador "Uno de + - * / = /= < <= > >= Y O NO.")
   (argumentos "Lista de expresiones."))
  "Aritmetica, comparacion y logica.

   Se unifican en un solo nodo con un operador simbolico en vez de una clase
   por operador. 2026 tiene EXPR-GT, EXPR-GTE, EXPR-LT, EXPR-EQUALS,
   EXPR-ADD, EXPR-SUBTRACT... una clase por cada uno, y cada arquitectura
   nueva tiene que escribir un metodo por cada clase. Con un solo nodo, un
   backend escribe un metodo y una tabla.")

(defnodo condicional (expresion)
  ((prueba "Expresion booleana.")
   (entonces "Expresion.")
   (si-no "Expresion."))
  "Condicional de tres ramas.")

(defnodo sin-escribir (expresion)
  ((argumento "Expresion, normalmente una referencia a campo."))
  "Cierto si el campo esta sin rellenar.

   Es la guarda que abre casi toda formula del corpus. En el dominio
   significa que el usuario todavia no ha escrito ahi, no que una celda este
   vacia: la diferencia importa porque una coleccion sin rejilla no tiene
   celdas.")

(defnodo concatenacion (expresion)
  ((partes "Lista de expresiones."))
  "Texto compuesto.")

(defnodo concordancia (expresion)
  ((cantidad "Expresion numerica.")
   (singular "Expresion: como se dice cuando la cantidad es uno.")
   (plural "Expresion: como se dice cuando no."))
  "Concordancia de numero.

   Parece un detalle y no lo es: es lo que permite que una arquitectura sin
   color pueda expresar un estado en palabras que se lean bien. El corpus ya
   lo hace a mano en departamento/hoja_cobertura.py.")

(defnodo conjunto (expresion)
  ((coleccion "Nombre de la coleccion.")
   (campo "Campo cuyos valores forman el conjunto.")
   (variable "Variable ligada para la condicion, o NIL.")
   (condicion "Expresion booleana que filtra, o NIL."))
  "Los valores que toma un campo en una coleccion. Alimenta los dominios de
   entrada.")

(defnodo enumeracion (expresion)
  ((valores "Lista de literales."))
  "Un conjunto escrito a mano.

   \"Entrada o salida\", \"manana, tarde o noche\": dos o tres palabras del
   dominio que no son una tabla y que no deberian obligar a inventarse una.
   Sale del experimento de alcance: sin esto, un almacen tiene que declarar
   una coleccion de una columna y dos filas que en el almacen no existe, y
   que acaba apareciendo como una pestana mas del libro.")

(defnodo relacionadas (expresion)
  ((coleccion "Nombre de la coleccion.")
   (variable "Variable ligada a la fila candidata.")
   (condicion "Expresion booleana que las selecciona."))
  "Todas las filas de otra coleccion relacionadas con esta.

   Es la relacion uno a muchos: el detalle de carga de un profesor, los
   movimientos de un articulo, los gastos de una partida. Gratis en una
   pagina y en una base de datos; en una hoja de calculo hay que emularla con
   lineas reservadas y un aviso al desbordarse, que es de los mejores casos
   de estudio del mecanismo de degradacion.")

(defnodo agregado (expresion)
  ((operacion ":CUANTAS :SUMA :MINIMO :MAXIMO :DISTINTAS.")
   (coleccion "Nombre de la coleccion sobre la que se agrega.")
   (campo "Campo sobre el que opera, o NIL para :CUANTAS.")
   (variable "Variable ligada a la fila recorrida.")
   (condicion "Expresion booleana que filtra, o NIL."))
  "Un valor unico obtenido de muchas filas.")

(defnodo busqueda (expresion)
  ((coleccion "Nombre de la coleccion donde se busca.")
   (variable "Variable ligada a la fila candidata.")
   (condicion "Expresion booleana que la identifica."))
  "La fila de una coleccion que cumple una condicion.

   Es el join que falta en 2026. Su condicion puede mencionar varios campos,
   con lo que la clave compuesta sale sin sintaxis adicional.")

(defnodo proyeccion (expresion)
  ((sobre "Expresion de busqueda.")
   (campo "Campo que se trae.")
   (por-defecto "Expresion, valor cuando no hay tal fila."))
  "Un campo de una fila encontrada, con valor por defecto si no hay ninguna.

   El valor por defecto no es un adorno: es la mitad del concepto. Once de
   las once busquedas del corpus van envueltas en una guarda de ausencia,
   porque el usuario escribe antes de que exista la fila relacionada.")

(defnodo existe (expresion)
  ((variable "Variable ligada a la fila candidata.")
   (coleccion "Nombre de la coleccion que se recorre.")
   (condicion "Expresion booleana.")
   (distinta-de "Variable de la que debe diferir, o NIL."))
  "Cierto si hay alguna fila que cumple la condicion.

   Es el cuantificador existencial de 2026, con dos cambios. Aqui la
   condicion es una expresion cualquiera en vez de dos listas de columnas
   (:MATCHING y :SELF-IN), asi que las dos variantes de 2026 son el mismo
   nodo con condiciones distintas. Y la exclusion de la propia fila se dice
   con :DISTINTA-DE en vez de esconderse en la formula generada.")

(defnodo comparten (expresion)
  ((variable-a "Primera variable de fila.")
   (variable-b "Segunda variable de fila.")
   (campos "Lista de nombres de campo."))
  "Cierto si las dos filas tienen algun valor en comun en esos campos.

   Es azucar sobre una disyuncion de igualdades, pero merece nodo propio:
   'estas dos defensas comparten algun miembro de tribunal' es una frase del
   dominio, y escribirla desplegada son veinticinco comparaciones.")

(defnodo vecino (expresion)
  ((direccion ":ANTERIOR o :SIGUIENTE.")
   (variable "Variable de fila."))
  "La fila contigua segun el orden declarado de la coleccion.

   Solo es legal si la coleccion declara orden, y el analisis lo comprueba
   sin consultar a ninguna arquitectura. Esa restriccion es lo que impide que
   se cuele el modelo de la hoja de calculo: el PREVIOUS-OF de 2026
   significaba de hecho 'la fila de arriba en la rejilla', que no tiene
   traduccion fuera de ella. Con orden declarado, 'anterior' significa lo
   mismo en los cuatro destinos.")

;;; ---------------------------------------------------------------------
;;; Recorrido generico
;;; ---------------------------------------------------------------------

(defgeneric subexpresiones (expresion)
  (:documentation
   "Las expresiones hijas de EXPRESION, en orden. Permite recorrer el arbol
    sin saber de que nodo se trata."))

(defmethod subexpresiones ((e expresion)) '())
(defmethod subexpresiones ((e aplicacion)) (argumentos e))
(defmethod subexpresiones ((e condicional))
  (list (prueba e) (entonces e) (si-no e)))
(defmethod subexpresiones ((e sin-escribir)) (list (argumento e)))
(defmethod subexpresiones ((e concatenacion)) (partes e))
(defmethod subexpresiones ((e concordancia))
  (list (cantidad e) (singular e) (plural e)))
(defmethod subexpresiones ((e conjunto))
  (when (condicion e) (list (condicion e))))
(defmethod subexpresiones ((e agregado))
  (when (condicion e) (list (condicion e))))
(defmethod subexpresiones ((e relacionadas)) (list (condicion e)))
(defmethod subexpresiones ((e enumeracion)) '())
(defmethod subexpresiones ((e busqueda)) (list (condicion e)))
(defmethod subexpresiones ((e proyeccion))
  (remove nil (list (sobre e) (por-defecto e))))
(defmethod subexpresiones ((e existe)) (list (condicion e)))

(defun recorrer-expresion (expresion funcion)
  "Aplica FUNCION a EXPRESION y, recursivamente, a todas sus subexpresiones."
  (when (typep expresion 'expresion)
    (funcall funcion expresion)
    (dolist (hija (subexpresiones expresion))
      (recorrer-expresion hija funcion))))
