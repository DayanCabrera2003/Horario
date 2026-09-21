;;;; Pruebas de las construcciones que salieron del experimento de alcance.
;;;;
;;;; El 2026-09-21 se intentaron describir cinco dominios ajenos al corpus
;;;; -un almacen, un cuadro de notas, un presupuesto, un torneo y un cuadrante
;;;; de turnos- y se ejecutaron de verdad. Ninguno dio NO-CABE y ninguno dio
;;;; CABE limpio: los cinco informes coincidieron en una lista de huecos.
;;;;
;;;; Cada prueba de este archivo cierra uno de esos huecos y dice cual. Es el
;;;; registro de que el metodo funciono: describir dominios nuevos encontro
;;;; cosas que las pruebas existentes no encontraban, porque las pruebas
;;;; comprueban lo que ya se sabe.

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion almacen (:etiqueta "Almacen")
  (coleccion movimientos
    (:clave id) (:orden fecha) (:crece)
    (campo id        :rol fijo)
    (campo fecha     :rol fijo :tipo fecha)
    (campo hora      :rol fijo :tipo hora)
    (campo proveedor :rol fijo)
    (campo tipo      :rol entrada
                     :dominio (uno-de "entrada" "salida") :al-violar advertir)
    (campo unidad    :rol fijo)
    (campo cantidad  :rol entrada :tipo entero)
    ;; El sustantivo sale de los datos, y su plural se compone con ellos.
    ;; En el plan del grupo el sustantivo siempre era "turno"; en un almacen
    ;; es caja, resma o par, y esta en la fila.
    (campo aviso     :rol derivado
           (texto (de fila cantidad) " "
                  (plural (de fila cantidad)
                          (de fila unidad)
                          (texto (de fila unidad) "s")))))
  ;; Una fila por proveedor, calculada. Antes habia que declararlos a mano y
  ;; mantener la lista sincronizada con lo que escribiera el operario.
  (coleccion proveedores
    (:una-fila-por proveedor :de movimientos)
    (campo proveedor :rol fijo)
    (campo cuantos   :rol derivado :tipo entero
           (cuantas movimientos :donde (= proveedor (de fila proveedor))))
    (campo desde-marzo :rol derivado :tipo entero
           (cuantas movimientos :donde (y (= proveedor (de fila proveedor))
                                          (>= fecha "2026-03-01"))))
    (campo entradas  :rol derivado :tipo entero
           (suma cantidad de movimientos
                 :donde (y (= proveedor (de fila proveedor)) (= tipo "entrada"))))
    (campo detalle   :rol derivado
           (las-filas-de movimientos :donde (= proveedor (de fila proveedor)))))
  ;; Una afirmacion sobre la situacion entera, no sobre ninguna fila.
  (coleccion resumen
    (:una-sola-fila)
    (campo total :rol derivado :tipo entero (cuantas movimientos))
    (campo casas :rol derivado :tipo entero
           (cuantas-distintas proveedor de movimientos)))
  (marca sin-tipo :en movimientos
    :cuando (vacio? (de fila tipo)) :sobre (tipo) :severidad advertencia)
  (vista libro :de movimientos :entrada t :etiqueta "Movimientos")
  ;; Aqui habia una rejilla de proveedor por tipo, y era ambigua: la clave de
  ;; MOVIMIENTOS es ID, que no esta en ninguno de los dos ejes, asi que M1 y M4
  ;; -los dos de Acme y de entrada- caian en la misma casilla y solo se
  ;; dibujaba uno. Lo que el dominio quiere ahi es la SUMA, y un agregado en el
  ;; cruce es una construccion que el lenguaje no tiene todavia. Hasta
  ;; entonces, la vista plana de los proveedores, que si dice lo que dice.
  ;;
  ;; Nadie lo habia visto porque estas descripciones se evaluaban y se
  ;; materializaban, pero no se pasaban por el analisis estatico.
  (vista resumen :de proveedores :etiqueta "Por proveedor"))

(defparameter *almacen*
  (list (cons (nucleo:nombrar "movimientos")
              (loop for (id fecha hora prov tipo unidad cant)
                      in '(("M1" "2026-02-10" "09:00" "Acme"  "entrada" "caja"  20)
                           ("M2" "2026-03-05" "14:30" "Acme"  "salida"  "caja"   5)
                           ("M3" "2026-03-11" "08:15" "Borja" "entrada" "resma" 40)
                           ("M4" "2026-01-20" "11:00" "Acme"  "entrada" "caja"  10)
                           ("M5" "2026-03-20" "16:45" "Borja" "salida"  "resma"  1))
                    collect (list (cons (nucleo:nombrar "id") id)
                                  (cons (nucleo:nombrar "fecha") fecha)
                                  (cons (nucleo:nombrar "hora") hora)
                                  (cons (nucleo:nombrar "proveedor") prov)
                                  (cons (nucleo:nombrar "tipo") tipo)
                                  (cons (nucleo:nombrar "unidad") unidad)
                                  (cons (nucleo:nombrar "cantidad") cant))))))

(defun entorno-del-almacen ()
  (nucleo:hacer-entorno (situacion.lenguaje:situacion-llamada "ALMACEN") *almacen*))

;;; ---------------------------------------------------------------------

(definir-prueba alcance-agrupacion
    "Alcance: una coleccion puede tener una fila por valor distinto de otra"
  ;; Hueco que encontraron el inventario y el presupuesto. Antes toda
  ;; coleccion era :ORIGEN :DECLARADA y habia que enumerar los grupos a mano.
  (let* ((e (entorno-del-almacen))
         (filas (nucleo:filas-de e (n "proveedores"))))
    (comprobar (= 2 (length filas)) "deberian salir dos proveedores, no ~d"
               (length filas))
    (comprobar (= 3 (nucleo:valor-de-campo e (first filas) (n "cuantos")))
               "Acme movio tres veces")
    (comprobar (= 30 (nucleo:valor-de-campo e (first filas) (n "entradas")))
               "Acme metio 20 y 10")))

(definir-prueba alcance-resumen-de-una-sola-fila
    "Alcance: una afirmacion sobre la situacion entera, no sobre una fila"
  ;; Hueco del inventario y del presupuesto: \"el total general\", \"el almacen
  ;; esta vacio\". Antes habia que inventarse una coleccion de una fila que en
  ;; el problema no existe.
  (let* ((e (entorno-del-almacen))
         (fila (first (nucleo:filas-de e (n "resumen")))))
    (comprobar fila "el resumen deberia tener exactamente una fila")
    (comprobar (= 5 (nucleo:valor-de-campo e fila (n "total"))))
    (comprobar (= 2 (nucleo:valor-de-campo e fila (n "casas"))))))

(definir-prueba alcance-fechas-y-horas
    "Alcance: las fechas y las horas se comparan por su valor, no por su texto"
  ;; Hueco del inventario: \"existencias a fecha de corte\" reventaba, porque
  ;; la coercion hacia READ-FROM-STRING sobre la cadena.
  (let* ((e (entorno-del-almacen))
         (filas (nucleo:filas-de e (n "proveedores"))))
    (comprobar (= 1 (nucleo:valor-de-campo e (first filas) (n "desde-marzo")))
               "de Acme, solo M2 es de marzo")
    (comprobar (= 2 (nucleo:valor-de-campo e (second filas) (n "desde-marzo")))
               "de Borja, los dos"))
  ;; Y el orden: la coleccion se declara ordenada por fecha.
  (let* ((e (entorno-del-almacen))
         (primero (first (nucleo:filas-de e (n "movimientos")))))
    (comprobar (string= "M4" (nucleo:valor-de-campo e primero (n "id")))
               "el mas antiguo es el de enero, no el primero que se escribio"))
  ;; Las horas, a minutos desde medianoche.
  (comprobar (= 540 (nucleo:como-numero "09:00")) "nueve horas son 540 minutos")
  (comprobar (< (nucleo:como-numero "08:15") (nucleo:como-numero "14:30")))
  ;; Y lo que no es fecha ni hora sigue siendo lo que era.
  (comprobar (= 42 (nucleo:como-numero "42")))
  (comprobar (= 0 (nucleo:como-numero "hola"))))

(definir-prueba alcance-dominio-escrito-a-mano
    "Alcance: un dominio puede ser dos palabras, sin inventarse una tabla"
  ;; Hueco del inventario: \"entrada o salida\" obligaba a declarar una
  ;; coleccion de una columna y dos filas que en el almacen no existe, y que
  ;; acababa apareciendo como una pestana mas del libro.
  (let* ((s (situacion.lenguaje:situacion-llamada "ALMACEN"))
         (movimientos (nucleo:coleccion-llamada s (n "movimientos")))
         (campo (nucleo:campo-llamado movimientos (n "tipo")))
         (e (entorno-del-almacen))
         (valores (nucleo:evaluar (nucleo:dominio campo) (nucleo:hacer-ambito) e '())))
    (comprobar (equal '("entrada" "salida") valores)
               "el dominio literal deberia dar sus dos valores, y da ~s" valores)))

(definir-prueba alcance-concordancia-con-el-sustantivo-de-los-datos
    "Alcance: el sustantivo de un plural puede venir de los datos"
  ;; Hueco del inventario: en el plan del grupo el sustantivo siempre es
  ;; \"turno\"; en un almacen esta en los datos -caja, resma, par- y antes
  ;; (plural n (de fila unidad) ...) reventaba porque no se compilaba.
  (let* ((e (entorno-del-almacen))
         (filas (nucleo:filas-de e (n "movimientos"))))
    (comprobar (string= "1 resma"
                        (nucleo:valor-de-campo e (first (last filas)) (n "aviso")))
               "con uno deberia decir el singular de los datos")
    (comprobar (search "cajas" (nucleo:valor-de-campo e (second filas) (n "aviso")))
               "con varios, el plural")))

(definir-prueba alcance-relacion-uno-a-muchos
    "Alcance: todas las filas relacionadas con una, sin limite fijo"
  (let* ((e (entorno-del-almacen))
         (acme (first (nucleo:filas-de e (n "proveedores"))))
         (detalle (nucleo:valor-de-campo e acme (n "detalle"))))
    (comprobar (= 3 (length detalle))
               "Acme tiene tres movimientos y salen ~d" (length detalle))))

(definir-prueba alcance-tabla-cruzada
    "Alcance: la tabla cruzada es una vista, y las tres arquitecturas la dan"
  ;; Hueco del cuadrante de turnos, y la parte del corpus que se creia fuera
  ;; del modelo: la hoja de grupo del generador de horarios. La salida fue
  ;; darse cuenta de que la matriz nunca fue una estructura de datos.
  ;;
  ;; Esta prueba se hacia sobre una rejilla del almacen -proveedor por tipo-
  ;; que resulto ser ambigua: la clave de MOVIMIENTOS es ID y no estaba en
  ;; ningun eje. Se traslada al horario del grupo, donde la clave es
  ;; (dia turno) y los ejes la cubren exactamente, que es la forma correcta
  ;; de una tabla cruzada.
  (let* ((s (situacion.lenguaje:situacion-llamada "HORARIO-DEL-GRUPO"))
         (cruzada (find-if #'nucleo:cruzada-p (nucleo:vistas s))))
    (comprobar cruzada "deberia haber una vista cruzada")
    (comprobar (eq (n "turno") (nucleo:eje-de-filas cruzada)))
    (comprobar (eq (n "dia") (nucleo:eje-de-columnas cruzada)))
    (comprobar (eq (n "asignatura") (nucleo:lo-que-se-muestra cruzada)))
    ;; Y los ejes determinan la fila, que es lo que la hace significar algo.
    (comprobar (null (set-difference
                      (nucleo:clave (nucleo:coleccion-llamada
                                     s (nucleo:fuente cruzada)))
                      (list (nucleo:eje-de-filas cruzada)
                            (nucleo:eje-de-columnas cruzada))))
               "los ejes de un cruce tienen que cubrir la clave"))
  ;; Y la pide como capacidad, para que salga en el informe.
  (let* ((s (situacion.lenguaje:situacion-llamada "HORARIO-DEL-GRUPO"))
         (pedidas (mapcar #'first (protocolo:requerimientos s))))
    (comprobar (member 'protocolo:con-tabla-cruzada pedidas)
               "una vista cruzada tiene que pedir la capacidad; si no, ninguna~@
                arquitectura puede declarar lo que le cuesta")))

(definir-prueba alcance-las-descripciones-pasan-el-analisis
    "Alcance: las descripciones del experimento pasan el analisis estatico"
  ;; Hueco encontrado el 2026-09-21 al anadir la comprobacion de rejilla
  ;; ambigua: estas descripciones se evaluaban y se materializaban, pero
  ;; NUNCA se pasaban por el analisis. Por eso la rejilla ambigua del almacen
  ;; llevaba ahi desde que se escribio sin que nadie lo notara.
  (dolist (nombre '("ALMACEN"))
    (let ((errores (remove-if-not
                    (lambda (p) (eq (analisis:gravedad-de-problema p) :error))
                    (analisis:comprobar-situacion
                     (situacion.lenguaje:situacion-llamada nombre)))))
      (comprobar (null errores) "~a no pasa el analisis: ~a" nombre
                 (analisis:informe-de-problemas errores)))))

(definir-prueba alcance-nada-se-descarta-en-silencio
    "Alcance: las formas que antes se tragaban ahora se rechazan"
  ;; Los dos descartes silenciosos que encontro el experimento. Son del mismo
  ;; genero que el fallo que este trabajo le reprocha a 2026: una descripcion
  ;; que se lee como correcta y significa otra cosa.
  (flet ((rechaza-p (forma)
           (handler-case (progn (macroexpand-1 forma) nil) (error () t))))
    (comprobar (rechaza-p '(situacion.lenguaje:defsituacion s-orden ()
                            (coleccion c (:orden a b)
                              (campo a :rol fijo) (campo b :rol fijo))))
               "(:orden a b) deberia rechazarse: el orden solo admite un campo~@
                y antes se quedaba con el primero sin decir nada")
    (comprobar (rechaza-p '(situacion.lenguaje:defsituacion s-vecino ()
                            (coleccion c (:orden a)
                              (campo a :rol fijo)
                              (campo x :rol derivado
                                     (de (anterior fila :donde (= a 1)) a)))))
               "(anterior fila :donde ...) deberia rechazarse: el vecino no~@
                sabe particionar y antes el :DONDE se descartaba en silencio")))
