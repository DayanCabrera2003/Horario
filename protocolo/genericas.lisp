;;;; Las operaciones del protocolo.
;;;;
;;;; Esto es lo que hay que especializar para incorporar una arquitectura de
;;;; salida nueva. Nada mas, y sin tocar el nucleo.
;;;;
;;;; Todas se declaran con DEFINIR-OPERACION, que exige la arquitectura como
;;;; primer parametro (ver operacion.lisp).
;;;;
;;;; LOS DOS OBJETOS QUE SUSTITUYEN A LOS PARAMETROS DE REJILLA DE 2026
;;;;
;;;; Donde 2026 pasaba COL-MAP, FILA, PRIMERA-FILA y ULTIMA-FILA, aqui van
;;;; dos objetos con papeles distintos:
;;;;
;;;;   AMBITO  Es del nucleo y es del dominio. Dice que variables de fila hay
;;;;           ligadas y sobre que coleccion recorre cada una. Es la misma
;;;;           para todas las arquitecturas y no contiene ninguna direccion.
;;;;
;;;;   PLAN    Es de la arquitectura y es opaco. Lo fabrica, lo llena y lo
;;;;           lee ella; el nucleo se limita a transportarlo de una operacion
;;;;           a otra sin abrirlo nunca.
;;;;
;;;; El COL-MAP de 2026 no desaparece: baja de sitio. Sigue existiendo,
;;;; dentro del plan de la arquitectura de Excel, que es donde tiene sentido.
;;;; Lo que desaparece es que este en la firma del punto de extension.

(in-package #:situacion.protocolo)

;;; ---------------------------------------------------------------------
;;; Declaracion de la arquitectura
;;; ---------------------------------------------------------------------

(definir-operacion capacidades (arquitectura)
  (:documentation
   "Las capacidades que ARQUITECTURA cumple de forma nativa.

    Normalmente no hace falta especializarla: el metodo por defecto las
    deduce de las clases de las que hereda."))

(defmethod capacidades ((arquitectura arquitectura))
  "Deduce las capacidades de las clases de las que hereda ARQUITECTURA.

   Se implementa con TYPEP y no recorriendo la lista de precedencia de
   clases porque eso exigiria el MOP, que no es Common Lisp estandar. El
   protocolo tiene que cargarse con un SBCL recien instalado y nada mas."
  (remove-if-not (lambda (capacidad)
                   (typep arquitectura (find-class capacidad)))
                 (capacidades-declaradas)))

(definir-operacion nivel-de-recalculo (arquitectura)
  (:documentation
   "Cuando recalcula ARQUITECTURA los valores derivados.

    Uno de :VIVA, :BAJO-DEMANDA o :CONGELADA.

    El lenguaje describe siempre derivaciones vivas; el nivel que una
    arquitectura puede ofrecer es cosa suya. Asi un PDF no es un caso que el
    diseno no contemple, sino una degradacion declarada con su linea en el
    informe de conformidad."))

(defmethod nivel-de-recalculo ((arquitectura con-derivacion-viva))
  :viva)

(defmethod nivel-de-recalculo ((arquitectura con-derivacion-por-consulta))
  :bajo-demanda)

(defmethod nivel-de-recalculo ((arquitectura arquitectura))
  "Por defecto, congelada: quien no declare lo contrario, calcula al generar."
  :congelada)

;;; ---------------------------------------------------------------------
;;; Planificacion (fase 5)
;;;
;;; Aqui la arquitectura decide como va a materializar la situacion, y aqui
;;; -y solo aqui- ocurre la degradacion. Separar planificar de emitir es lo
;;; que permite que las operaciones de emision no necesiten recibir
;;; direcciones: cuando llega la emision, el plan ya sabe donde va todo.
;;; ---------------------------------------------------------------------

(definir-operacion planificar (arquitectura situacion)
  (:documentation
   "Construye el plan de ARQUITECTURA para SITUACION.

    Devuelve (VALUES PLAN INFORME).

    El plan es un objeto cuya forma pertenece por completo a la
    arquitectura: el de Excel decide que hoja, que columna y que fila ocupa
    cada cosa, cuantas filas de reserva hacen falta y que hojas auxiliares
    hay que inventarse; el de la web decide que componentes hay y como se
    llaman sus variables. El nucleo no mira dentro.

    Senala CARENCIA-DE-CAPACIDAD cada vez que SITUACION pide algo que esta
    arquitectura no cumple de forma nativa."))

(definir-operacion planificar-coleccion (arquitectura coleccion plan)
  (:documentation
   "Planifica una coleccion dentro de PLAN."))

(definir-operacion planificar-campo (arquitectura campo coleccion plan)
  (:documentation
   "Planifica un campo dentro de PLAN.

    Es el sitio natural de las reglas transversales. Por ejemplo, que en
    cualquier arquitectura con entrada lo derivado quede de solo lectura se
    escribe una vez, como metodo auxiliar sobre CON-ENTRADA, y vale para
    todas las arquitecturas presentes y futuras."))

(definir-operacion planificar-vista (arquitectura vista plan)
  (:documentation
   "Planifica una vista dentro de PLAN: secciones, agrupacion y navegacion."))

;;; ---------------------------------------------------------------------
;;; Emision (fase 6)
;;; ---------------------------------------------------------------------

(definir-operacion materializar (arquitectura situacion datos destino)
  (:documentation
   "Planifica y emite de una vez. Es el punto de entrada de alto nivel.

    Devuelve (VALUES DESTINO INFORME). El informe dice, para cada capacidad
    que pedia la descripcion, si se cumplio, se emulo, se degrado o se
    rechazo."))

(definir-operacion emitir (arquitectura plan destino)
  (:documentation
   "Escribe el artefacto. DESTINO es un flujo o una ruta."))

(definir-operacion emitir-expresion (arquitectura expresion ambito plan)
  (:documentation
   "Traduce un nodo de expresion a lo que ARQUITECTURA use para expresar
    calculo.

      EXPRESION  el nodo a traducir.
      AMBITO     que variables de fila hay ligadas y sobre que coleccion
                 recorre cada una. No contiene ninguna direccion.
      PLAN       el plan de esta arquitectura, donde vive el
                 direccionamiento que ella misma decidio en la fase 5.

    Esta es la operacion que en 2026 se llamaba COMPILE-EXCEL-FORMULA, no
    recibia la arquitectura, y llevaba la rejilla metida en la firma. Es el
    punto exacto donde se decide si el trabajo es extensible o no."))

(definir-operacion emitir-marca (arquitectura marca ambito plan)
  (:documentation
   "Materializa una marca.

    La marca declara un significado y una severidad, nunca un color. Como se
    ve es cosa de la arquitectura: un relleno, un color mas un icono, una
    face, o texto si no hay otra cosa."))

(definir-operacion emitir-entrada (arquitectura campo ambito plan)
  (:documentation
   "Materializa un campo de entrada: donde se escribe, con que dominio de
    valores, y si violarlo avisa o impide."))

(definir-operacion emitir-vista (arquitectura vista plan)
  (:documentation
   "Materializa una vista: sus secciones y su navegacion."))

;;; ---------------------------------------------------------------------
;;; Carencias y degradacion
;;; ---------------------------------------------------------------------

(definir-operacion resolver-carencia (arquitectura capacidad nodo)
  (:documentation
   "Que hace ARQUITECTURA cuando le piden CAPACIDAD para NODO y no la
    cumple.

    Devuelve (VALUES RESPUESTA NOTA), donde RESPUESTA es una de:

      :EMULA     no la tiene, pero puede fabricarla. NOTA dice a que coste y
                 con que limite.
      :DEGRADA   hay una version mas pobre que sigue sirviendo para lo
                 mismo.
      :RECHAZA   no hay version honesta y fingirla seria mentir.

    La frontera entre degradar y rechazar es la que hay que poder defender:
    se degrada cuando el resultado sigue cumpliendo el proposito por otra
    via; se rechaza cuando el resultado PARECERIA correcto y no lo seria. Un
    documento que aparenta admitir entrada y no la admite es peor que un
    error."))
