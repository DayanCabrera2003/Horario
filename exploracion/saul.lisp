;;;; Horario semanal del preuniversitario Saul.
;;;;
;;;; ENCARGO DE EXPLORACION. No forma parte del sistema: no lo modifica, solo
;;;; lo usa. Mide el lenguaje tal como esta, el 2026-09-21, contra el enunciado
;;;; que trajo Dayan.
;;;;
;;;; LA PREGUNTA QUE SE RESPONDE AQUI NO ES "cabe el dominio", es mas fina:
;;;; el enunciado describe DOS cosas distintas, mezcladas en una sola frase.
;;;;
;;;;   (A) Como ES una asignacion valida. Cuarenta casillas por grupo (cinco
;;;;       dias por ocho turnos), una asignatura por casilla, con nueve
;;;;       reglas que dicen si esa asignacion es correcta. Esto ES una
;;;;       situacion tabular: datos, derivaciones, marcado. Se describe abajo
;;;;       entera y se ejecuta contra las tres arquitecturas.
;;;;
;;;;   (B) ENCONTRAR una asignacion que cumpla las nueve reglas duras a la vez
;;;;       y que ademas prefiera las dos blandas. Esto es un problema de
;;;;       satisfaccion de restricciones -buscar, entre todas las formas de
;;;;       repartir las sesiones en 40 casillas por grupo, una que sirva. El
;;;;       lenguaje no tiene motor de busqueda ni optimizador, y no es un
;;;;       descuido: es la decision 1 de 00-CONTEXTO.md, tomada por el tutor
;;;;       el 2026-09-09 -"la web y el movil solo visualizan la situacion, no
;;;;       la resuelven"- aplicada aqui sin excepcion, porque no hay ninguna
;;;;       excepcion escrita para "restriccion dura" en vez de "blanda".
;;;;
;;;; Asi que este archivo hace (A) de verdad -las nueve reglas duras
;;;; compiladas, evaluadas contra un horario YA escrito a mano, y
;;;; materializadas en las tres arquitecturas- y deja dicho, en cada bloque,
;;;; por que la parte que falta (asignar) no es un hueco del lenguaje sino un
;;;; limite de alcance ya decidido.
;;;;
;;;; SE REUTILIZA A PROPOSITO la forma de corpus/horario-del-grupo.lisp: la
;;;; rejilla como una fila por casilla, no como matriz. Esa descripcion ya
;;;; demostro -corriendo de verdad, con ./demostrar.sh- que el cuadrante
;;;; dia x turno se ve entero en texto y web (CUMPLE con-tabla-cruzada) y se
;;;; emula en la hoja de calculo con una columna de clave compuesta (INDICE +
;;;; COINCIDIR). Aqui no se repite esa prueba: se da por buena y se usa como
;;;; base para lo que el corpus no tenia -turno doble, tarde, dia de
;;;; preparacion, colision de profesor entre grupos, profesor contratado.

(defpackage #:exploracion.saul
  (:use #:common-lisp #:situacion.lenguaje)
  (:export #:informe))

(in-package #:exploracion.saul)

;;; ====================================================================
;;; LA SITUACION
;;; ====================================================================

(defsituacion horario-saul
    (:etiqueta "Horario semanal del preuniversitario Saul")

  ;; ------------------------------------------------------------------
  ;; El plan de la escuela: que asignaturas hay, cuanto y quien las da.
  ;; Simplificacion deliberada para esta exploracion: UN profesor por
  ;; asignatura, el mismo para todos los grupos del ano (normal en un centro
  ;; chico: un especialista por materia). El enunciado dice que el profesor
  ;; de cada sesion "viene dado"; aqui viene dado a este nivel.
  (coleccion asignaturas
    (:etiqueta "Asignaturas")
    (:clave abrev)
    (campo abrev          :rol fijo :etiqueta "Abrev")
    (campo nombre         :rol fijo :etiqueta "Asignatura")
    (campo frecuencia     :rol fijo :tipo entero :etiqueta "Frecuencia semanal")
    ;; "Las asignaturas de frecuencia cinco son exactamente las que admiten
    ;; turno doble": no se guarda como un segundo hecho independiente que
    ;; pudiera contradecir al primero. Se deriva de el, que es lo que dice
    ;; el enunciado.
    (campo turno-doble    :rol derivado :etiqueta "Turno doble"
           (si (= (de fila frecuencia) 5) "si" "no"))
    (campo admite-tarde   :rol fijo :etiqueta "Admite tarde")
    ;; 0 = esta asignatura no tiene dia de preparacion.
    (campo dia-preparacion :rol fijo :tipo entero :etiqueta "Dia de preparacion")
    (campo profesor       :rol fijo :etiqueta "Profesor")
    ;; Donde se da cada asignatura. Igual que el profesor: en un centro chico
    ;; cada materia tiene su local, y el enunciado dice que viene dado.
    (campo local          :rol fijo :etiqueta "Local")
    (:datos (("MAT"  "Matematica"        5 "no" 3 "Rosa"  "Aula 1")
             ("ESP"  "Espanol"           4 "no" 1 "Julia" "Aula 1")
             ("EF"   "Educacion Fisica"  2 "no" 0 "Pedro" "Terreno")
             ("HIST" "Historia"          3 "si" 2 "Julia" "Aula 2")
             ("ING"  "Ingles"            2 "si" 0 "Rosa"  "Lab de idiomas"))))

  ;; Las dos disposiciones fijas del enunciado que hacen falta para las
  ;; reglas duras: quien esta contratado y quien vive lejos. (Las otras dos
  ;; -que grupos y que asignaturas puede dar cada profesor- ya estan
  ;; aplicadas en la tabla de arriba, porque son las que deciden QUIEN es el
  ;; profesor de cada sesion, no una regla sobre donde cae esa sesion.)
  (coleccion profesores
    (:etiqueta "Profesores")
    (:clave nombre)
    (campo nombre       :rol fijo :etiqueta "Profesor")
    (campo contratado   :rol fijo :etiqueta "Contratado")
    (campo vive-lejos   :rol fijo :etiqueta "Vive lejos")
    (:datos (("Rosa"  "no" "no")
             ("Julia" "no" "si")
             ("Pedro" "si" "no"))))

  ;; Que dias asiste cada profesor CONTRATADO. Solo hacen falta filas para
  ;; los que estan contratados: para el resto la regla ni se evalua.
  ;;
  ;; Es la clave compuesta (profesor, dia) buscada por un solo campo. No es
  ;; un capricho: nucleo/expresion.lisp dice que "la clave compuesta sale sin
  ;; sintaxis adicional", pero excel/formula.lisp la rechaza (BUSCARV solo
  ;; admite una igualdad, comprobado el 2026-09-21 en el experimento de
  ;; alcance). El corpus real ya resuelve esto mismo con una clave
  ;; concatenada a mano -horarios/hoja_grupo.py:291-, asi que se usa aqui la
  ;; misma tecnica: un campo CLAVE = profesor + "#" + dia.
  (coleccion disponibilidad
    (:etiqueta "Disponibilidad de profesores contratados")
    (:clave clave)
    (campo clave    :rol fijo :etiqueta "Clave")
    (campo profesor :rol fijo :etiqueta "Profesor")
    (campo dia      :rol fijo :tipo entero :etiqueta "Dia")
    (campo asiste   :rol fijo :etiqueta "Asiste")
    ;; Pedro (contratado) solo asiste lunes, miercoles y viernes.
    (:datos (("Pedro#1" "Pedro" 1 "si")
             ("Pedro#3" "Pedro" 3 "si")
             ("Pedro#5" "Pedro" 5 "si"))))

  ;; ------------------------------------------------------------------
  ;; LA REJILLA. Una fila por casilla: (grupo, dia, turno). Cuarenta casillas
  ;; por grupo, dos grupos. Lo unico que se escribe a mano es la asignatura;
  ;; todo lo demas -el profesor, si admite tarde, si es dia de preparacion,
  ;; si el profesor esta contratado y si asiste hoy- se trae por busqueda.
  (coleccion casillas
    (:etiqueta "Casillas del horario")
    (:clave grupo dia turno)
    (:orden turno)

    (campo grupo :rol fijo :etiqueta "Grupo")
    (campo dia   :rol fijo :tipo entero :etiqueta "Dia")
    (campo turno :rol fijo :tipo entero :etiqueta "Turno")

    (campo asignatura :rol entrada :etiqueta "Asignatura"
           :dominio   (los abrev de asignaturas)
           :al-violar advertir)

    (campo nombre :rol derivado :etiqueta "Nombre"
           (el nombre de (la-fila-de asignaturas
                           :donde (= abrev (de fila asignatura)))
               :si-no ""))

    (campo profesor :rol derivado :etiqueta "Profesor"
           (el profesor de (la-fila-de asignaturas
                             :donde (= abrev (de fila asignatura)))
               :si-no ""))

    (campo aula :rol derivado :etiqueta "Aula"
           (el local de (la-fila-de asignaturas
                          :donde (= abrev (de fila asignatura)))
               :si-no ""))

    (campo turno-doble :rol derivado :etiqueta "Turno doble"
           (el turno-doble de (la-fila-de asignaturas
                                :donde (= abrev (de fila asignatura)))
               :si-no "no"))

    (campo admite-tarde :rol derivado :etiqueta "Admite tarde"
           (el admite-tarde de (la-fila-de asignaturas
                                 :donde (= abrev (de fila asignatura)))
               :si-no "no"))

    (campo dia-preparacion :rol derivado :tipo entero :etiqueta "Dia de preparacion"
           (el dia-preparacion de (la-fila-de asignaturas
                                    :donde (= abrev (de fila asignatura)))
               :si-no 0))

    ;; Dos derivados que dependen de OTRO derivado de la MISMA fila
    ;; (profesor). Es la misma tecnica de horario-del-grupo.lisp (faltan usa
    ;; puestos); aqui se encadena una vez mas.
    (campo profesor-contratado :rol derivado :etiqueta "Profesor contratado"
           (el contratado de (la-fila-de profesores
                               :donde (= nombre (de fila profesor)))
               :si-no "no"))

    (campo profesor-vive-lejos :rol derivado :etiqueta "Profesor vive lejos"
           (el vive-lejos de (la-fila-de profesores
                               :donde (= nombre (de fila profesor)))
               :si-no "no"))

    (campo clave-consulta :rol derivado :etiqueta "Clave de consulta"
           (texto (de fila profesor) "#" (de fila dia)))

    ;; Solo tiene sentido cuando PROFESOR-CONTRATADO es "si": para el resto
    ;; no hay fila en DISPONIBILIDAD, el valor por defecto es "no", y no
    ;; significa nada porque la marca que lo usa exige primero que este
    ;; contratado.
    (campo profesor-asiste-hoy :rol derivado :etiqueta "Profesor asiste hoy"
           (el asiste de (la-fila-de disponibilidad
                           :donde (= clave (de fila clave-consulta)))
               :si-no "no"))

    ;; Ilustrativo, como en el resto del corpus: la rejilla real -las 80
    ;; casillas, dos grupos de 40- la construye el LOOP de mas abajo y se
    ;; pasa como datos de evaluacion. Esta lista no la usa el evaluador.
    (:datos (("10-A" 1 1) ("10-A" 1 2))))

  ;; ------------------------------------------------------------------
  ;; EL PLAN POR GRUPO. Cuantas veces recibio cada grupo cada asignatura,
  ;; para la regla 9. Misma tecnica de plan-del-grupo.lisp, con la
  ;; diferencia de que aqui el agregado filtra por DOS campos a la vez
  ;; (grupo Y asignatura) en vez de uno: es COUNTIFS en la hoja de calculo,
  ;; no CONTAR.SI, y es justo lo que el experimento de alcance de ayer
  ;; encontro roto (una condicion con dos igualdades tumbaba la
  ;; materializacion entera) y que ya esta corregido.
  (coleccion plan-por-grupo
    (:etiqueta "Plan por grupo")
    (:clave grupo abrev)
    (campo grupo :rol fijo :etiqueta "Grupo")
    (campo abrev :rol fijo :etiqueta "Abrev")
    (campo nombre :rol derivado :etiqueta "Asignatura"
           (el nombre de (la-fila-de asignaturas :donde (= abrev (de fila abrev)))
               :si-no ""))
    (campo frecuencia :rol derivado :tipo entero :etiqueta "Frecuencia"
           (el frecuencia de (la-fila-de asignaturas :donde (= abrev (de fila abrev)))
               :si-no 0))
    (campo asignadas :rol derivado :tipo entero :etiqueta "Asignadas"
           (cuantas casillas :donde (y (= grupo (de fila grupo))
                                       (= asignatura (de fila abrev)))))
    (campo faltan :rol derivado :tipo entero :etiqueta "Faltan"
           (- (de fila frecuencia) (de fila asignadas)))
    (:datos (("10-A" "MAT") ("10-A" "ESP") ("10-A" "EF") ("10-A" "HIST") ("10-A" "ING")
             ("10-B" "MAT") ("10-B" "ESP") ("10-B" "EF") ("10-B" "HIST") ("10-B" "ING"))))

  ;; --------------------------------------------------------------------
  ;; LAS NUEVE REGLAS DURAS.
  ;; --------------------------------------------------------------------

  ;; 1. "Un grupo no puede recibir dos sesiones en el mismo dia y turno."
  ;; NO HACE FALTA MARCA. La clave de CASILLAS es (grupo dia turno): dos
  ;; sesiones del mismo grupo en el mismo dia y turno serian la MISMA fila.
  ;; La regla la cumple la FORMA de la representacion, no una condicion
  ;; escrita. Es el hallazgo mas interesante de este archivo.

  ;; 2. "Un profesor no puede impartir dos sesiones en el mismo dia y turno."
  ;; Aqui si hace falta la marca, porque dos GRUPOS distintos si pueden
  ;; coincidir en dia y turno, y el mismo profesor podria estar en las dos
  ;; filas. Es exactamente el patron de AULA-OCUPADA en
  ;; corpus/horario-del-grupo.lisp, cambiando "aula" por "profesor".
  (marca profesor-colisiona
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (existe otra :en casillas
                    :distinta-de fila
                    ;; No hace falta comprobar que OTRA no este vacia: si su
                    ;; asignatura esta vacia, su PROFESOR derivado tambien lo
                    ;; esta ("" por defecto), y nunca sera igual al profesor
                    ;; de FILA, que aqui ya se sabe que no esta vacio.
                    :donde (y (= (de otra dia) (de fila dia))
                              (= (de otra turno) (de fila turno))
                              (= (de otra profesor) (de fila profesor)))))
    :sobre     (asignatura profesor)
    :severidad problema
    :explica   "Este profesor ya da clase a otro grupo en este mismo turno")

  ;; 2b. El aula ocupada por dos grupos a la vez. No esta en el enunciado -el
  ;; centro no la menciono- y hace falta igual: es la garantia del horario por
  ;; aula, igual que la de arriba lo es del horario por profesor. Que aparezca
  ;; al describir la VISTA y no al describir las reglas dice algo: hay
  ;; restricciones del dominio que solo se ven cuando alguien pregunta como se
  ;; quiere mirar el problema.
  (marca aula-ocupada
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (existe otra :en casillas
                    :distinta-de fila
                    :donde (y (= (de otra dia) (de fila dia))
                              (= (de otra turno) (de fila turno))
                              (= (de otra aula) (de fila aula)))))
    :sobre     (aula)
    :severidad problema
    :explica   "Ese local esta ocupado por otro grupo a esa hora")

  ;; 3 y 4 juntas: "una asignatura que no admite turno doble no puede tener
  ;; dos sesiones del mismo grupo el mismo dia" y "una que si admite, solo
  ;; en turnos consecutivos". Una sola marca: son la misma pregunta -"hay
  ;; otra sesion de esta asignatura, este grupo, este dia"- con una condicion
  ;; extra que solo se activa cuando la asignatura admite turno doble.
  (marca sesion-repetida-mal
    :en casillas
    :cuando (y (no (vacio? (de fila asignatura)))
               (existe otra :en casillas
                 :distinta-de fila
                 ;; Igual que arriba: no hace falta comprobar que OTRA no
                 ;; este vacia, porque una fila vacia nunca cumplira la
                 ;; igualdad de asignatura que viene despues.
                 :donde (y (= (de otra grupo) (de fila grupo))
                           (= (de otra dia) (de fila dia))
                           (= (de otra asignatura) (de fila asignatura))
                           (o (= (de fila turno-doble) "no")
                              (y (/= (de otra turno) (+ (de fila turno) 1))
                                 (/= (de otra turno) (- (de fila turno) 1)))))))
    :sobre     (asignatura)
    :severidad problema
    :explica   "Esta asignatura repite el mismo dia en este grupo, y no en turnos consecutivos")

  ;; 5. "Ninguna sesion cae en el dia de preparacion de su asignatura."
  (marca en-dia-de-preparacion
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (= (de fila dia) (de fila dia-preparacion)))
    :sobre     (asignatura dia-preparacion)
    :severidad problema
    :explica   "Este es el dia de preparacion de la asignatura: no se imparte a ningun grupo")

  ;; 6. "Ninguna sesion de educacion fisica cae despues del tercer turno."
  (marca ef-fuera-de-manana
    :en casillas
    :cuando    (y (= (de fila asignatura) "EF") (> (de fila turno) 3))
    :sobre     (asignatura turno)
    :severidad problema
    :explica   "Educacion Fisica no puede caer despues del tercer turno")

  ;; 7. "Ninguna sesion de una asignatura que no admite tarde cae en los
  ;; turnos seis, siete u ocho."
  (marca sin-tarde-en-turno-de-tarde
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (= (de fila admite-tarde) "no")
                  (> (de fila turno) 5))
    :sobre     (asignatura admite-tarde turno)
    :severidad problema
    :explica   "Esta asignatura no admite turnos de tarde")

  ;; 8. "Ningun profesor contratado imparte en un dia en que no asiste."
  (marca contratado-en-dia-que-no-asiste
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (= (de fila profesor-contratado) "si")
                  (= (de fila profesor-asiste-hoy) "no"))
    :sobre     (asignatura profesor)
    :severidad problema
    :explica   "Este profesor esta contratado y no asiste al centro este dia")

  ;; 9. "Cada grupo recibe cada asignatura tantas veces como indica su
  ;; frecuencia." Va sobre PLAN-POR-GRUPO, no sobre CASILLAS: es una cuenta,
  ;; no una condicion de una casilla.
  (marca frecuencia-incompleta
    :en plan-por-grupo
    :cuando    (> (de fila faltan) 0)
    :sobre     (nombre asignadas faltan)
    :severidad advertencia
    :explica   (texto "Faltan " (de fila faltan) " "
                      (plural (de fila faltan) "turno" "turnos")))

  (marca frecuencia-excedida
    :en plan-por-grupo
    :cuando    (< (de fila faltan) 0)
    :sobre     (nombre asignadas faltan)
    :severidad problema
    :explica   (texto "Sobran " (- 0 (de fila faltan)) " "
                      (plural (- 0 (de fila faltan)) "turno" "turnos")))

  ;; --------------------------------------------------------------------
  ;; LAS DOS REGLAS BLANDAS.
  ;;
  ;; Esto es lo que NO se puede pedirle al lenguaje: elegir el horario que
  ;; mas las cumpla. Lo unico que se puede hacer -y es lo que hacen estas dos
  ;; marcas- es SENALAR cuando el horario que alguien ya escribio no las
  ;; cumple. La severidad es ADVERTENCIA, no PROBLEMA: informan, no
  ;; invalidan. Nunca cambian una casilla.
  ;; --------------------------------------------------------------------

  ;; "Se prefiere el reparto que evita el primer turno del dia a los
  ;; profesores que viven lejos."
  (marca primer-turno-a-profesor-lejano
    :en casillas
    :cuando    (y (no (vacio? (de fila asignatura)))
                  (= (de fila profesor-vive-lejos) "si")
                  (= (de fila turno) 1))
    :sobre     (asignatura profesor)
    :severidad advertencia
    :explica   "Se preferiria no darle el primer turno a un profesor que vive lejos")

  ;; "Se prefiere el reparto en que ningun profesor supera un tope de
  ;; sesiones en un mismo dia." Necesita su propio agregado: cuantas
  ;; casillas tiene ESTE profesor, ESTE dia, en cualquier grupo. Se cuenta
  ;; sobre DISPONIBILIDAD-DE-CARGA en vez de anadir un campo mas a CASILLAS,
  ;; porque la pregunta es "por profesor y dia", no "por casilla".
  (coleccion carga-diaria
    (:etiqueta "Carga diaria por profesor")
    (:clave profesor dia)
    (campo profesor :rol fijo :etiqueta "Profesor")
    (campo dia      :rol fijo :tipo entero :etiqueta "Dia")
    (campo sesiones :rol derivado :tipo entero :etiqueta "Sesiones"
           (cuantas casillas :donde (y (= profesor (de fila profesor))
                                       (= dia (de fila dia))
                                       (no (vacio? asignatura)))))
    (:datos (("Rosa" 1) ("Rosa" 2) ("Rosa" 3) ("Rosa" 4) ("Rosa" 5)
             ("Julia" 1) ("Julia" 2) ("Julia" 3) ("Julia" 4) ("Julia" 5)
             ("Pedro" 1) ("Pedro" 2) ("Pedro" 3) ("Pedro" 4) ("Pedro" 5))))

  (parametro tope-diario :tipo entero :valor 3
             :etiqueta "Tope de sesiones al dia por profesor")

  (marca excede-tope-diario
    :en carga-diaria
    :cuando    (> (de fila sesiones) (parametro tope-diario))
    :sobre     (sesiones)
    :severidad advertencia
    :explica   (texto "Lleva " (de fila sesiones) " sesiones ese dia"))

  (marca casilla-libre
    :en casillas
    :cuando    (vacio? (de fila asignatura))
    :sobre     (asignatura)
    :severidad informativa
    :explica   "Turno sin asignar")

  ;; LAS TRES TABLAS QUE PIDIO EL CENTRO. No son tres descripciones: son la
  ;; misma rejilla de turno por dia, partida por tres campos distintos de la
  ;; misma coleccion. La primera sale. Las otras dos NO, y el motivo es el
  ;; hallazgo de esta exploracion.
  ;;
  ;; LA DIFERENCIA ENTRE LA PRIMERA Y LAS OTRAS DOS. La clave de CASILLAS es
  ;; (grupo dia turno). En la vista por grupo, los ejes (turno, dia) mas la
  ;; particion por grupo cubren la clave entera: cada casilla del cuadrante
  ;; corresponde a una fila y a una sola, y no hay nada mas que decir.
  ;;
  ;; En la vista por profesor no. Los ejes mas la particion por profesor
  ;; dejan GRUPO fuera, asi que dos filas -10-A y 10-B- pueden caer en la
  ;; misma casilla del horario de Rosa. Y eso, en el dominio, tiene nombre:
  ;; es que Rosa esta citada en dos grupos a la vez, que es justo lo que
  ;; detecta PROFESOR-COLISIONA.
  ;;
  ;; O sea: EL HORARIO POR PROFESOR ESTA BIEN DEFINIDO SOLO SI EL HORARIO ES
  ;; VALIDO. El analisis no mira los datos -no debe- asi que exige que la
  ;; descripcion lo diga: (:UNICA-SALVO <marca>) declara que la casilla es
  ;; unica mientras esa marca no dispare, y obliga a las arquitecturas a
  ;; ensenar el choque cuando dispare, en vez de dibujar una de las dos como
  ;; si fuera la unica. Lo mismo con el aula.
  (vista por-grupo :de casillas :entrada t :etiqueta "Horario del grupo"
                   :filas turno :columnas dia :muestra asignatura
                   :secciones grupo)

  (vista por-profesor :de casillas :etiqueta "Horario del profesor"
                      :filas turno :columnas dia :muestra grupo
                      :secciones profesor
                      :unica-salvo profesor-colisiona)

  (vista por-aula :de casillas :etiqueta "Horario del aula"
                  :filas turno :columnas dia :muestra grupo
                  :secciones aula
                  :unica-salvo aula-ocupada)

  (vista plan        :de asignaturas   :etiqueta "Plan de asignaturas")
  (vista docentes    :de profesores    :etiqueta "Profesores")
  (vista frecuencias :de plan-por-grupo :etiqueta "Frecuencias por grupo")
  (vista carga       :de carga-diaria  :etiqueta "Carga diaria"))


;;; ====================================================================
;;; LOS DATOS: dos grupos, cuarenta casillas cada uno.
;;;
;;; La mayoria vacias -no hace falta llenar las 80 a mano para probar las
;;; reglas-, con un PLAN valido de fondo y un punado de violaciones puestas
;;; A PROPOSITO, una por regla, para ver disparar cada marca. Estan listadas
;;; despues del LOOP.
;;; ====================================================================

(defparameter +plan-10-a+
  ;; (dia turno abrev)
  '((1 1 "MAT") (2 1 "MAT") (4 1 "MAT") (4 2 "MAT") (5 1 "MAT")   ; MAT: 5 en 4 dias, doble el dia 4 (regla 3/4 OK; evita el dia 3, que es su preparacion)
    (1 2 "ESP") (1 3 "ESP")                                       ; ESP: repite el dia 1 sin ser doble -> VIOLA 3
    (2 2 "ESP") (5 2 "ESP")                                       ; ESP: hasta aqui 4 sesiones (frecuencia OK)
    (1 5 "EF")                                                    ; EF: turno 5 -> VIOLA 6 (despues del 3ro)
    (4 3 "EF")                                                    ; EF (Pedro): dia 4 es jueves, Pedro no asiste -> VIOLA 8
    (2 4 "HIST")                                                  ; HIST: dia 2 es su dia de preparacion -> VIOLA 5
    (3 1 "HIST")                                                  ; HIST (Julia, vive lejos): turno 1 -> VIOLA blanda
    (5 7 "HIST")                                                  ; HIST: turno 7 (tarde), admite tarde -> OK. 3 sesiones (frecuencia OK)
    (1 4 "ING") (4 7 "ING")))                                     ; ING: 2 sesiones, una de tarde -> todo OK

(defparameter +plan-10-b+
  ;; (dia turno abrev)
  '((1 1 "MAT")                                                   ; MAT (Rosa): mismo dia/turno que 10-A -> VIOLA 2 (colision de profesor), a proposito
    (2 3 "MAT") (4 4 "MAT") (5 3 "MAT") (5 4 "MAT")                ; resto del plan de MAT, doble el dia 5, evita el dia 3 y las horas de 10-A
    (1 2 "ESP") (2 2 "ESP") (3 3 "ESP") (5 2 "ESP")                ; ESP: mismo profesor (Julia) que 10-A y sin escalonar -> tambien colisiona con 10-A, sin querer
    (1 3 "EF") (3 2 "EF")                                          ; EF (Pedro): lunes y miercoles, los dos asistidos -> limpio
    (1 6 "HIST") (4 5 "HIST") (5 7 "HIST")                         ; HIST: mismo profesor (Julia) que 10-A, tampoco escalonado
    (2 4 "ING") (4 7 "ING")))                                      ; ING: mismo profesor (Rosa) que 10-A

;;; NOTA HONESTA: este horario no esta escalonado a mano para que Julia y
;;; Rosa no coincidan nunca entre los dos grupos, mas alla de la UNA colision
;;; de MAT puesta a proposito arriba. Es deliberado: escalonar 14 sesiones de
;;; una profesora entre dos grupos sin que ninguna caiga en el mismo hueco ES
;;; el problema (B) del encabezado -encontrar una asignacion que cumpla las
;;; reglas-, y hacerlo bien a mano ya es la prueba de que el lenguaje no lo
;;; hace por uno. Lo que aqui se demuestra es que PROFESOR-COLISIONA encuentra
;;; cada choque, puesto a proposito o no.

(defun clave-plan (dia turno) (cons dia turno))

(defun asignatura-en (plan dia turno)
  (let ((fila (assoc (clave-plan dia turno)
                      (mapcar (lambda (f) (cons (clave-plan (first f) (second f)) (third f)))
                              plan)
                      :test #'equal)))
    (if fila (cdr fila) "")))

(defun n (s) (nucleo:nombrar s))

(defun fila (&rest pares)
  (loop for (campo valor) on pares by #'cddr collect (cons (n campo) valor)))

(defun casillas-de-grupo (grupo plan)
  (loop for dia from 1 to 5
        append (loop for turno from 1 to 8
                     collect (fila "grupo" grupo "dia" dia "turno" turno
                                   "asignatura" (asignatura-en plan dia turno)))))

(defparameter +profesores+ '("Rosa" "Julia" "Pedro"))
(defparameter +dias+ '(1 2 3 4 5))

(defparameter datos-de-saul
  (list
   (cons (n "asignaturas")
         (loop for (a nom f dt dp prof local) in '(("MAT" "Matematica" 5 "no" 3 "Rosa" "Aula 1")
                                                    ("ESP" "Espanol" 4 "no" 1 "Julia" "Aula 1")
                                                    ("EF" "Educacion Fisica" 2 "no" 0 "Pedro" "Terreno")
                                                    ("HIST" "Historia" 3 "si" 2 "Julia" "Aula 2")
                                                    ("ING" "Ingles" 2 "si" 0 "Rosa" "Lab de idiomas"))
               collect (fila "abrev" a "nombre" nom "frecuencia" f
                             "admite-tarde" dt "dia-preparacion" dp "profesor" prof
                             "local" local)))
   (cons (n "profesores")
         (loop for (p c l) in '(("Rosa" "no" "no") ("Julia" "no" "si") ("Pedro" "si" "no"))
               collect (fila "nombre" p "contratado" c "vive-lejos" l)))
   (cons (n "disponibilidad")
         (loop for (clave prof dia asiste) in '(("Pedro#1" "Pedro" 1 "si")
                                                 ("Pedro#3" "Pedro" 3 "si")
                                                 ("Pedro#5" "Pedro" 5 "si"))
               collect (fila "clave" clave "profesor" prof "dia" dia "asiste" asiste)))
   (cons (n "casillas")
         (append (casillas-de-grupo "10-A" +plan-10-a+)
                 (casillas-de-grupo "10-B" +plan-10-b+)))
   (cons (n "plan-por-grupo")
         (loop for grupo in '("10-A" "10-B")
               append (loop for abrev in '("MAT" "ESP" "EF" "HIST" "ING")
                            collect (fila "grupo" grupo "abrev" abrev))))
   (cons (n "carga-diaria")
         (loop for prof in +profesores+
               append (loop for dia in +dias+ collect (fila "profesor" prof "dia" dia))))))


;;; ====================================================================
;;; EL BANCO DE PRUEBAS
;;; ====================================================================

(defun titulo (texto)
  (format t "~&~%~a~%~a~%~a~%"
          (make-string 70 :initial-element #\=) texto
          (make-string 70 :initial-element #\=)))

(defparameter +salida+ #p"exploracion/salida/")

(defun materializar-en (arquitectura etiqueta situacion datos nombre)
  (ensure-directories-exist +salida+)
  (handler-case
      (multiple-value-bind (destino informe)
          (protocolo:materializar arquitectura situacion datos
                                  (merge-pathnames nombre +salida+))
        (format t "~&[~a] generado ~a~%" etiqueta destino)
        (protocolo:escribir-informe informe)
        t)
    (error (e)
      (format t "~&[~a] FALLA: ~a~%" etiqueta e)
      nil)))

(defun informe ()
  (titulo "ANALISIS ESTATICO")
  (let ((problemas (analisis:comprobar-situacion horario-saul)))
    (if problemas
        (format t "~&~d problema(s):~%~a" (length problemas)
                (analisis:informe-de-problemas problemas))
        (format t "~&Sin problemas.~%")))

  (titulo "MARCAS QUE DISPARAN (evaluador de referencia)")
  (dolist (par (nucleo:evaluar-situacion horario-saul datos-de-saul))
    (destructuring-bind (coleccion . filas) par
      (dolist (f filas)
        (when (cdr f)
          (format t "  ~(~a~)  ~{~(~a~)=~a~^ ~}   >> ~{~(~a~)~^, ~}~%"
                  (symbol-name coleccion)
                  (loop for (campo . valor) in (car f)
                        when (member (symbol-name campo)
                                     '("GRUPO" "DIA" "TURNO" "ASIGNATURA" "NOMBRE" "PROFESOR" "SESIONES")
                                     :test #'string=)
                          append (list campo (if (null valor) "-" valor)))
                  (cdr f))))))

  (titulo "MATERIALIZACION EN LAS TRES ARQUITECTURAS")
  (materializar-en (situacion.texto:hacer-texto) "texto" horario-saul datos-de-saul "saul.txt")
  (materializar-en (situacion.excel:hacer-excel) "excel" horario-saul datos-de-saul "saul-plano.json")
  (materializar-en (situacion.web:hacer-web) "web" horario-saul datos-de-saul "saul.html")

  (format t "~&~%Artefactos en ~a~%" (truename +salida+))
  t)

(informe)
