;;;; La jerarquia de capacidades.
;;;;
;;;; Recupera la idea que la tesis de 2017 (Arcia Corcho) atribuye a ADOL* y
;;;; GEMURAL, y que ninguna de las tres tesis de la linea llego a
;;;; implementar: componer por propiedades en vez de enumerar destinos.
;;;;
;;;; La forma ingenua de soportar cuatro arquitecturas es escribir, para cada
;;;; concepto, cuatro reglas. La forma buena es darse cuenta de que las
;;;; arquitecturas comparten propiedades, nombrar las propiedades, y que cada
;;;; arquitectura concreta sea la composicion de las que cumple.
;;;;
;;;; De aqui salen tres cosas, y ninguna es taxonomia decorativa:
;;;;
;;;;   1. Un metodo puede especializarse en la CAPACIDAD, no en la
;;;;      arquitectura. Asi Excel y web comparten el emisor de marcado visual
;;;;      sin conocerse entre si, que es lo que exige el criterio C4.
;;;;
;;;;   2. Las reglas transversales caben en un metodo auxiliar. Por ejemplo:
;;;;      en cualquier arquitectura con entrada, lo derivado es de solo
;;;;      lectura. Una regla, un sitio, todas las arquitecturas presentes y
;;;;      futuras.
;;;;
;;;;   3. Decidir que hay que degradar es comparar lo que la situacion pide
;;;;      con lo que la arquitectura declara, y eso es una operacion sobre
;;;;      clases.

(in-package #:situacion.protocolo)

(defclass arquitectura ()
  ()
  (:documentation
   "Raiz de la jerarquia. Toda arquitectura de salida hereda de aqui.

    Una arquitectura concreta no hereda de ARQUITECTURA directamente: hereda
    de las capacidades que cumple, y cada capacidad ya hereda de aqui."))

(eval-when (:compile-toplevel :load-toplevel :execute)

  (defvar *capacidades* '()
    "Nombres de las capacidades declaradas, en orden inverso de declaracion.")

  (defun registrar-capacidad (nombre)
    (pushnew nombre *capacidades*)
    nombre)

  (defun capacidades-declaradas ()
    "Las capacidades del protocolo, en orden de declaracion."
    (reverse *capacidades*)))

(defmacro definir-capacidad (nombre documentacion)
  "Declara una capacidad componible.

   Define la clase y la registra. El registro sirve para dos cosas: para que
   CAPACIDADES pueda deducir por si sola lo que una arquitectura cumple, y
   para que el invariante I5 pueda comprobar que toda capacidad tiene al
   menos un caso en el juego de pruebas de conformidad."
  `(progn
     (eval-when (:compile-toplevel :load-toplevel :execute)
       (registrar-capacidad ',nombre))
     (defclass ,nombre (arquitectura)
       ()
       (:documentation ,documentacion))))

;;; Las capacidades. Cada una corresponde a una columna de la tabla de la
;;; seccion 2.2 del documento de arquitectura, y esa tabla sale del corpus,
;;; no de la especulacion.

(definir-capacidad con-rejilla
  "Organiza sus elementos en filas y columnas de verdad.

   Excel y org-table la tienen; una pagina web no. Es la capacidad que mas
   se echa de menos al escribir un backend, y precisamente por eso el nucleo
   no puede darla por supuesta.")

(definir-capacidad con-derivacion-viva
  "Recalcula los valores derivados sola, cuando el usuario edita.

   Excel con su motor de dependencias, la web con reactividad. Es el nivel
   de recalculo mas alto de los tres.")

(definir-capacidad con-derivacion-por-consulta
  "Recalcula al consultar, no al editar.

   Es lo que hace SQL con las vistas: el valor esta siempre al dia, pero
   nadie se entera hasta que pregunta.")

(definir-capacidad con-entrada
  "El usuario puede escribir en el documento producido.

   Un PDF no la tiene. Es lo que separa un documento que se lee de un
   instrumento de captura, y los tres libros del corpus son lo segundo.")

(definir-capacidad con-dominio-de-entrada
  "Puede restringir los valores admisibles de un campo de entrada.

   Desplegable en Excel, <select> en la web, completado en Emacs, clave
   foranea o CHECK en SQL. Una de las capacidades que mejor se traduce entre
   arquitecturas, y por eso de las mas seguras para el nucleo.")

(definir-capacidad con-orden-declarado
  "Puede materializar una coleccion respetando el orden que declara.

   Es la precondicion para que ANTERIOR y SIGUIENTE signifiquen algo. Sin
   orden declarado, hablar de la fila anterior es hablar de la fila de
   arriba en la rejilla, que es el modelo de Excel colandose en el
   lenguaje.")

(definir-capacidad con-busqueda-por-clave
  "Puede traer un dato de otra coleccion a partir de una clave.

   Es la construccion nueva central del trabajo -el join que la taxonomia de
   2026 no tiene- y hasta ahora era invisible en el informe de conformidad
   porque las tres arquitecturas la cumplen y nadie la pedia. Que salga como
   cumplida no es ruido: un informe que solo lista lo que falla no dice que se
   comprobo, y una arquitectura de exportacion plana no la cumpliria.")

(definir-capacidad con-relacion-uno-a-muchos
  "Puede mostrar todas las filas relacionadas con una dada, sin limite fijo.

   Gratis en la web y en SQL. En Excel hay que emularla con una hoja
   auxiliar de clave numerada, lineas reservadas y un aviso al desbordarse.
   Es uno de los dos casos donde una arquitectura de rejilla pierde frente a
   una que no la tiene.")

(definir-capacidad con-tabla-cruzada
  "Puede poner los valores de un campo en el eje de columnas.

   Un cuadrante de turnos, un horario de dia por turno, una matriz de
   ocupacion. La forma parece una estructura de datos y no lo es: los datos
   siguen siendo filas, y lo que cambia es la presentacion.

   La dificultad real no es dibujarla: es que el numero de columnas depende
   del CONTENIDO y no de la declaracion. En una pagina eso da igual. En una
   hoja de calculo mueve el direccionamiento entero, y por eso alli es una
   emulacion con coste: las columnas se fijan al generar.")

(definir-capacidad con-agrupacion
  "Las filas de una coleccion pueden salir de otra, y seguir saliendo.

   \"Una fila por proveedor\", \"una fila por partida\": el conjunto de filas
   no se declara, se calcula. Una base de datos lo hace con GROUP BY y una
   pagina recalculando al dibujar. Una hoja de calculo no: tiene que fijar las
   filas al generar, y si manana aparece un proveedor nuevo hay que volver a
   generar el libro.

   Es de las capacidades que mejor separan los destinos vivos de los que solo
   lo parecen.")

(definir-capacidad con-conteo-de-distintos
  "Puede contar cuantos valores distintos toma un campo.

   Una palabra en SQL y en JavaScript. En Excel no existe: COUNTIF no sabe
   contar unicos y las formulas matriciales no se comportan igual en Excel
   que en Calc, asi que hay que emularla con una columna de primera
   aparicion. El otro caso donde la rejilla pierde.")

(definir-capacidad con-crecimiento
  "Admite que una coleccion siga creciendo despues de generar el documento.

   Es el mejor caso de estudio del mecanismo entero, porque invierte la
   intuicion: una pagina la cumple de forma nativa con un boton de anadir, y
   una hoja de calculo -que parece mas capaz- tiene que emularla reservando
   filas en blanco y definiendo un rango que se dimensiona con lo escrito,
   con las trampas que eso arrastra. Lo que el lenguaje declara es la
   intencion, nunca el mecanismo.")

(definir-capacidad con-marcado-visual
  "Puede senalar una celda o una fila por medios visuales.

   Relleno en Excel, color mas icono en la web, una face en Emacs. Notese
   que la capacidad es 'senalar visualmente', no 'tener color': lo que el
   lenguaje declara es un significado y una severidad, nunca un color.")

(definir-capacidad con-marcado-textual
  "Puede senalar un estado escribiendolo.

   Es la degradacion natural del marcado visual, y no es un parche: en una
   impresion en blanco y negro tiene que ser texto o no se ve nada. El
   corpus ya lo hace, y con concordancia de plural: la hoja de cobertura del
   departamento escribe 'Falta 1 profesor' o 'Faltan 3 profesores' porque
   ahi el color no alcanzaba.")

(definir-capacidad con-particion-de-vista
  "Puede repetir una misma vista, una vez por cada valor de un campo.

   El horario por grupo, por profesor y por aula no son tres descripciones:
   son la misma rejilla de turno por dia, partida por tres campos distintos
   de la misma coleccion. Lo que el lenguaje declara es POR QUE CAMPO se
   parte; que eso sean tres pestanas, tres bloques de texto o tres secciones
   de una pagina lo decide cada arquitectura.

   No confundir con CON-AGRUPACION, que es otra cosa: alli las FILAS de una
   coleccion se calculan a partir de otra; aqui las filas son las mismas y lo
   que se reparte es la PRESENTACION.

   Es ademas lo que hace que una rejilla signifique algo cuando los dos ejes
   no bastan para identificar la fila: el analisis exige que los ejes mas el
   campo de particion cubran la clave.")

(definir-capacidad con-casilla-en-conflicto
  "Puede ensenar que una casilla de una tabla cruzada tiene mas de una fila
   candidata, en vez de dibujar una y callarse.

   Es la contrapartida de (:UNICA-SALVO <marca>). La descripcion declara que
   la casilla es unica mientras esa marca no dispare; esta capacidad es lo
   que obliga a que, cuando dispare, se vea. Sin ella la garantia seria una
   suposicion, que es lo que este trabajo persigue en las tesis anteriores.

   Cuesta muy poco donde se dibuja al vuelo y algo mas en una rejilla, donde
   hay que preguntar primero cuantas filas cumplen la clave de la casilla.")

(definir-capacidad con-filtro-de-vista
  "Puede presentar solo las filas que cumplen una condicion.

   Partir da una tabla por profesor; filtrar dice cuales. Las dos juntas son
   lo que hace falta para ver la ocupacion de los profesores de UN grupo sin
   sacar a los ciento y pico del centro.

   Lo que se filtra es la presentacion y nunca los datos: una fila escondida
   sigue contando para los agregados y para las marcas. Una arquitectura que
   filtrara de verdad la coleccion estaria cambiando el significado de la
   descripcion, no presentandola.")

(definir-capacidad con-agrupacion-en-vista
  "Puede separar las filas de una tabla por el valor de un campo, dentro de
   la misma tabla.

   Es el escalon intermedio entre no hacer nada y partir en secciones: las
   filas siguen en una sola tabla, con una cabecera por grupo. Una hoja de
   calculo no puede intercalar cabeceras sin correr las filas de datos, y
   todo su direccionamiento parte de que los datos de una coleccion son un
   bloque contiguo; alli se emula ordenando. En texto y en una pagina es
   natural.")

(definir-capacidad con-navegacion
  "El documento tiene secciones, un punto de entrada y forma de moverse
   entre ellas.

   Pestanas y enlaces en Excel, rutas en la web, buffers en Emacs. SQL no la
   tiene. Es de las cosas que mas cambian de forma entre arquitecturas, y
   por eso el lenguaje declara la intencion y no el mecanismo.")
