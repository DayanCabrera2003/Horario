;;;; Emision a hoja de calculo.
;;;;
;;;; Recorre el plan y produce el plano de libro. Aqui es donde el rol de
;;;; campo -un solo hecho del dominio- se convierte en cuatro cosas distintas:
;;;; la celda escrita o la formula, el bloqueo, el color de la pestana y la
;;;; validacion.

(in-package #:situacion.excel)

(defmethod protocolo:materializar ((a excel) situacion datos destino)
  (protocolo:con-informe (a)
    (let ((*situacion* situacion))
      (dolist (r (protocolo:requerimientos situacion))
        (destructuring-bind (capacidad nodo detalle) r
          (protocolo:requerir a capacidad nodo :detalle detalle)))
      (let ((plan (protocolo:planificar a situacion)))
        (setf (entorno plan) (nucleo:hacer-entorno situacion datos))
        (protocolo:emitir a plan destino)))))

(defmethod protocolo:emitir ((a excel) plan destino)
  ;; CONSTRUIR-PLANO resuelve (ARCHIVOS PLAN) como efecto lateral de recorrer
  ;; las vistas (PLANIFICAR-CRUCES, mas arriba en este archivo), asi que para
  ;; cuando llega aqui ya se sabe si hay algo que escribir aparte.
  (escribir-plano (construir-plano a plan) destino)
  (when (archivos plan)
    (escribir-archivos-de-vista a plan destino))
  destino)

(defun construir-plano (a plan)
  (let ((*campos-rechazados* '()))
    (armar-plano a plan)))

(defun armar-plano (a plan)
  ;; Las vistas se planifican antes de emitir: pueden reordenar las hojas y,
  ;; si son cruzadas, anaden geometria propia.
  ;; Antes que nada, las hojas se redimensionan con las filas que de verdad
  ;; hay: al planificar solo se conocian las declaradas.
  (ajustar-capacidades a plan)
  (dolist (vista (nucleo:vistas (situacion plan)))
    (when (nucleo:cruzada-p vista) (planificar-cruces a vista plan))
    (protocolo:planificar-vista a vista plan))
  (setf (cruces plan) (nreverse (cruces plan)))
  ;; Las columnas auxiliares del conteo de distintos se reparten antes de
  ;; emitir ninguna hoja: una hoja puede contar los distintos de otra que se
  ;; emite antes que ella, y su columna tiene que existir ya.
  (reservar-columnas-de-distintos plan)
  ;; Los cruces de una vista en VISTAS-EN-ARCHIVO (H2) tambien se acumularon
  ;; con PUSH dentro de PLANIFICAR-CRUCES, por la misma razon que CRUCES.
  (setf (archivos plan) (nreverse (archivos plan)))
  ;; La hoja auxiliar de cada relacion uno-a-muchos (H4), antes que
  ;; PLANO-DE-HOJA: EMITIR-EXPRESION sobre RELACIONADAS (excel/formula.lisp)
  ;; necesita encontrar su hoja auxiliar en (AUXILIARES PLAN) para escribir
  ;; el conteo de la hoja de origen.
  (dolist (hoja (hojas plan))
    (dolist (campo (campos-de-relacion (coleccion hoja)))
      (push (planificar-detalle a plan hoja campo) (auxiliares plan))))
  (setf (auxiliares plan) (nreverse (auxiliares plan)))
  ;; Las vistas de lista que no son la de datos de su coleccion salen como
  ;; hojas derivadas (excel/vistas.lisp).
  (planificar-vistas-derivadas plan)
  ;; Los nombres de pestana se fijan aqui, una vez y antes de emitir ninguna
  ;; formula: son los que citan las formulas y los rangos con nombre.
  (asignar-nombres-de-hoja plan)
  (list (cons "libro" (nucleo:etiqueta (situacion plan)))
        ;; Una vista en VISTAS-EN-ARCHIVO (H2) no vive en este libro: no
        ;; tiene pestana aqui, y su "hoja" en el indice apuntaria -de forma
        ;; enganosa- a la hoja de datos de origen y no a ningun cuadrante de
        ;; este libro. Se deja fuera del indice por la misma razon que se
        ;; deja fuera de (CRUCES PLAN).
        (cons "vistas" (lista (mapcar
                               (lambda (v) (protocolo:emitir-vista a v plan))
                               (remove-if (lambda (v) (member (nucleo:nombre v)
                                                              (vistas-en-archivo a)))
                                          (nucleo:vistas (situacion plan))))))
        (cons "hojas" (let ((hojas (append
                                    (mapcar (lambda (c) (plano-de-cruce a plan c))
                                            (cruces plan))
                                    (mapcar (lambda (h) (plano-de-hoja a plan h))
                                            (hojas plan))
                                    (mapcar (lambda (d) (plano-de-vista-derivada plan d))
                                            (vistas-derivadas plan))
                                    (mapcar (lambda (d) (plano-de-detalle a plan d))
                                            (auxiliares plan)))))
                        ;; La hoja de listas va al final: se llena mientras se
                        ;; emiten los desplegables de las demas.
                        (lista (if (nombre-de-listas plan)
                                   (append hojas (list (plano-de-listas plan)))
                                   hojas))))))

(defun reservar-columnas-de-distintos (plan)
  "Una columna de primera aparicion por cada campo cuyos valores distintos
   cuenta alguna expresion de la situacion sin condicion. Con condicion no
   hay columna: esa forma se rechaza al emitirla (excel/agregados.lisp)."
  (flet ((mirar (expresion)
           (when expresion
             (nucleo:recorrer-expresion
              expresion
              (lambda (e)
                (when (and (typep e 'nucleo:agregado)
                           (eq (nucleo:operacion e) :distintas)
                           (null (nucleo:condicion e)))
                  (let ((hoja (hoja-de plan (nucleo:coleccion e))))
                    (when hoja (columna-de-distintos-de hoja (nucleo:campo e))))))))))
    (let ((situacion (situacion plan)))
      (dolist (coleccion (nucleo:colecciones situacion))
        (dolist (campo (nucleo:campos coleccion))
          (mirar (nucleo:expresion campo))))
      (dolist (marca (nucleo:marcas situacion))
        (mirar (nucleo:condicion marca))
        (mirar (nucleo:explicacion marca))))))

(defun plano-de-cruce (a plan cruce)
  "La hoja de la tabla cruzada, con sus dos ejes fijados y sus busquedas.

   La celda del cruce es una busqueda por DOS criterios, y una hoja de
   calculo no la tiene: BUSCARV busca por uno. Se emula con una columna de
   clave compuesta en la hoja de origen mas INDICE y COINCIDIR, que es la
   pareja portable entre Excel y LibreOffice Calc.

   El coste esta declarado en el informe de conformidad: los ejes se fijan al
   generar."
  (declare (ignore a))
  (let* ((vista (vista cruce))
         (hoja (hoja-origen cruce))
         (coleccion (coleccion hoja))
         (nombre-origen (entrecomillar (nombre hoja)))
         (fila-enc 3) (fila-ini 4)
         (campo-celda (nucleo:lo-que-se-muestra vista))
         (rango-clave (format nil "~a!$~a$~d:$~a$~d" nombre-origen
                              (letra (clave cruce)) (fila-primera hoja)
                              (letra (clave cruce)) (fila-ultima hoja)))
         (rango-valor (format nil "~a!$~a$~d:$~a$~d" nombre-origen
                              (columna-de hoja campo-celda) (fila-primera hoja)
                              (columna-de hoja campo-celda) (fila-ultima hoja)))
         (encabezados
           (cons (list (cons "celda" (format nil "A~d" fila-enc))
                       (cons "campo" "__eje__")
                       (cons "rol" "fijo")
                       (cons "texto" (string-capitalize
                                      (symbol-name (nucleo:eje-de-filas vista)))))
                 (loop for v in (valores-de-columna cruce)
                       for i from 1
                       collect (list (cons "celda" (format nil "~a~d"
                                                           (letra-de-columna i) fila-enc))
                                     (cons "campo" (format nil "__col~d__" i))
                                     (cons "rol" "fijo")
                                     (cons "texto" (nucleo:como-texto v))))))
         (celdas (loop for v in (valores-de-fila cruce)
                       for f from fila-ini
                       collect (list (cons "celda" (format nil "A~d" f))
                                     (cons "valor" v))))
         (formulas (loop for v in (valores-de-fila cruce)
                         for f from fila-ini
                         append (loop for i from 1 to (length (valores-de-columna cruce))
                                      collect
                                      (list (cons "celda" (format nil "~a~d"
                                                                  (letra-de-columna i) f))
                                            (cons "formula"
                                                  (formula-de-casilla
                                                   cruce rango-valor rango-clave
                                                   f (letra-de-columna i) fila-enc)))))))
    (declare (ignore coleccion))
    (list (cons "nombre" (nombre cruce))
          (cons "titulo" (titulo cruce))
          (cons "cruce" (identidad-de-cruce cruce))
          (cons "fila_encabezado" fila-enc)
          (cons "fila_primera" fila-ini)
          (cons "capacidad" (max 1 (length (valores-de-fila cruce))))
          (cons "color_pestana" "8EA9DB")
          (cons "encabezados" (lista encabezados))
          (cons "celdas" (lista celdas))
          (cons "formulas" (lista formulas))
          (cons "anchos" (anchos-de-cruce plan cruce))
          (cons "impresion" (impresion t))
          (cons "editables" :lista-vacia)
          (cons "validaciones" :lista-vacia)
          (cons "formatos_condicionales" (lista (marcas-de-la-rejilla cruce fila-ini fila-enc)))
          (cons "rangos_nombrados" :lista-vacia)
          (cons "leyenda" :lista-vacia))))

(defun marcas-de-la-rejilla (cruce fila-ini fila-enc)
  "Las reglas que pintan las casillas de una rejilla con la severidad mas
   alta de las marcas de la fila que cae en ella. La leen de la columna de
   nivel de la hoja de origen. Antes las marcas no pintaban las rejillas: la
   pagina si, la hoja de calculo no."
  (let ((hoja (hoja-origen cruce)))
    (when (and (columna-de-nivel hoja) (clave cruce)
               (valores-de-fila cruce) (valores-de-columna cruce))
      (let* ((origen (entrecomillar (nombre hoja)))
             (rango (lambda (letra) (format nil "~a!$~a$~d:$~a$~d" origen letra
                                            (fila-primera hoja) letra (fila-ultima hoja))))
             (clave (format nil "~@[~a&CHAR(31)&~]$A~d&CHAR(31)&B$~d"
                            (when (seccion cruce)
                              (cadena-excel (nucleo:como-texto (seccion cruce))))
                            fila-ini fila-enc))
             (nivel (format nil "IFERROR(INDEX(~a,MATCH(1,INDEX(EXACT(~a,~a)*1,0),0)),0)"
                            (funcall rango (columna-de-nivel hoja))
                            (funcall rango (letra (clave cruce))) clave))
             (casillas (format nil "B~d:~a~d" fila-ini
                               (letra-de-columna (length (valores-de-columna cruce)))
                               (+ fila-ini (length (valores-de-fila cruce)) -1))))
        (loop for (severidad . numero) in +niveles+
              collect (list (cons "rango" casillas)
                            (cons "estado" (string-downcase (symbol-name severidad)))
                            (cons "severidad" (string-downcase (symbol-name severidad)))
                            (cons "formula" (format nil "~a=~d" nivel numero))
                            (cons "relleno" (relleno-de-severidad severidad))))))))

(defun identidad-de-cruce (cruce)
  "De que vista y de que seccion es la pestana de CRUCE.

   El nombre de la pestana no sirve para saberlo: se recorta a 31 caracteres
   y se renombra si se repite. Quien compare el libro con el oraculo de las
   tablas cruzadas necesita el dato sin adivinarlo."
  (list (cons "vista" (string-downcase (symbol-name (nucleo:nombre (vista cruce)))))
        (cons "seccion" (if (seccion cruce)
                            (nucleo:como-texto (seccion cruce))
                            ""))))

(defun formula-de-casilla (cruce rango-valor rango-clave fila columna fila-enc)
  "La formula de una casilla del cruce.

   Normalmente es una busqueda por la clave compuesta: INDICE mas COINCIDIR,
   que es la pareja portable entre Excel y LibreOffice Calc. La primera parte
   de la clave es el valor de ESTA pestana, fijado al generar. Las partes van
   en el orden de PARTES-DE-LA-CLAVE, que es el de la columna donde se busca.

   Si la vista declaro (:UNICA-SALVO <marca>), la casilla puede tener mas de
   una fila candidata, y entonces la formula pregunta primero CUANTAS hay.
   Con mas de una escribe la primera y cuantas mas: es todo lo que una hoja
   de calculo puede decir sin formulas matriciales, que no se comportan igual
   en los dos programas. Por eso aqui la capacidad se emula y no se cumple.
   Lo que no hace, y es lo que importa, es ensenar una de las dos como si
   fuera la unica.

   La busqueda pregunta ademas si lo encontrado esta vacio. INDICE sobre una
   celda en blanco devuelve cero, no blanco, y sin la pregunta un turno libre
   se leeria como un 0 en el cuadrante.

   La coincidencia es EXACT, no COINCIDIR a secas: COINCIDIR no distingue
   mayusculas y lee \"*\" y \"?\" como comodines, y una sala llamada
   \"Sala*\" ensenaba la reunion de \"Sala Azul\"."
  (let* ((clave (format nil "~@[~a&CHAR(31)&~]$A~d&CHAR(31)&~a$~d"
                        (when (seccion cruce)
                          (cadena-excel (nucleo:como-texto (seccion cruce))))
                        fila columna fila-enc))
         (coincide (format nil "EXACT(~a,~a)" rango-clave clave))
         (posicion (format nil "MATCH(1,INDEX(~a*1,0),0)" coincide))
         (encontrado (format nil "INDEX(~a,~a)" rango-valor posicion))
         (busqueda (format nil "IF(ISNA(~a),\"\",IF(ISBLANK(~a),\"\",~a))"
                           posicion encontrado encontrado)))
    (if (null (nucleo:conflicto (vista cruce)))
        (format nil "=~a" busqueda)
        (let ((cuantas (format nil "SUMPRODUCT(1*~a)" coincide)))
          (format nil "=IF(~a>1,~a&\" (+\"&(~a-1)&\")\",~a)"
                  cuantas busqueda cuantas busqueda)))))

(defmethod protocolo:planificar-vista ((a excel) vista plan)
  "Una vista se materializa como la hoja de su coleccion.

   Una hoja de calculo no tiene rutas ni pantallas: tiene pestanas, y la
   coleccion ya tiene la suya. Lo que la vista aporta aqui es que su hoja sea
   la primera del libro si es el punto de entrada."
  (when (nucleo:es-entrada vista)
    (let ((hoja (hoja-de plan (nucleo:fuente vista))))
      (when hoja
        (setf (hojas plan) (cons hoja (remove hoja (hojas plan)))))))
  plan)

(defmethod protocolo:emitir-vista ((a excel) vista plan)
  "El nombre visible de la pestana de VISTA y si es por donde se entra: su
   hoja derivada, la primera de sus pestanas cruzadas, o la hoja de datos."
  (let ((derivada (find vista (vistas-derivadas plan) :key #'vista))
        (cruce (find vista (cruces plan) :key #'vista))
        (hoja (hoja-de plan (nucleo:fuente vista))))
    (list (cons "vista" (string-downcase (symbol-name (nucleo:nombre vista))))
          (cons "titulo" (nucleo:etiqueta vista))
          (cons "hoja" (cond (derivada (nombre derivada))
                             (cruce (nombre cruce))
                             (hoja (nombre hoja))
                             (t "")))
          (cons "es_entrada" (if (nucleo:es-entrada vista) t :false)))))

(defun plano-de-hoja (a plan hoja)
  (let ((*hoja* hoja))
    (declare (special *hoja*))
    (list (cons "nombre" (nombre hoja))
          (cons "titulo" (titulo hoja))
          ;; Que coleccion es: el verificador empareja por esto con el
          ;; oraculo, nunca por las etiquetas de las columnas.
          (cons "coleccion" (nombre-de-coleccion (coleccion hoja)))
          (cons "estado" (or (columna-de-estado hoja) :false))
          (cons "fila_encabezado" (fila-encabezado hoja))
          (cons "fila_primera" (fila-primera hoja))
          (cons "capacidad" (capacidad hoja))
          (cons "color_pestana" (color-de-pestana hoja))
          (cons "encabezados" (lista (append (encabezados-de hoja)
                                             (encabezado-de-estado hoja)
                                             (encabezado-de-nivel hoja)
                                             (encabezados-de-claves hoja))))
          (cons "celdas" (lista (celdas-de a plan hoja)))
          (cons "formulas" (lista (append (formulas-de a plan hoja)
                                          (formulas-de-estado a plan hoja)
                                          (formulas-de-nivel a plan hoja)
                                          (formulas-de-claves a plan hoja))))
          (cons "anchos" (anchos-de-hoja plan hoja))
          (cons "columnas_ocultas" (lista (columnas-ocultas hoja)))
          (cons "impresion" (impresion (> (length (nucleo:campos (coleccion hoja))) 6)))
          (cons "editables" (lista (rangos-editables plan hoja)))
          (cons "validaciones" (lista (validaciones-de a plan hoja)))
          (cons "formatos_de_celda" (lista (formatos-de-celda hoja)))
          (cons "formatos_condicionales" (lista (formatos-de a plan hoja)))
          (cons "rangos_nombrados" (lista (rangos-nombrados-de hoja)))
          (cons "leyenda" (lista (leyenda-de plan hoja))))))

(defun color-de-pestana (hoja)
  "Azul si en la hoja se escribe a mano, gris si todo se calcula.

   Sale del rol de campo, no de una decision aparte. Es el mismo criterio que
   usan los libros del corpus."
  (if (nucleo:campos-de-rol (coleccion hoja) :entrada) "4472C4" "8EA9DB"))

(defun encabezados-de (hoja)
  (loop for campo in (nucleo:campos (coleccion hoja))
        collect (list (cons "celda" (format nil "~a~d"
                                            (columna-de hoja (nucleo:nombre campo))
                                            (fila-encabezado hoja)))
                      (cons "campo" (string-downcase (symbol-name (nucleo:nombre campo))))
                      (cons "rol" (string-downcase (symbol-name (nucleo:rol campo))))
                      (cons "texto" (nucleo:etiqueta campo)))))

(defun encabezados-de-claves (hoja)
  "El encabezado de cada columna auxiliar de HOJA: las de clave compuesta y
   las de primera aparicion.

   Dice que contiene: con mas de una columna auxiliar en la hoja, un rotulo
   igual para todas no deja saber cual es cual."
  (append
   (loop for clave in (claves hoja)
         for i from 1
         collect (list (cons "celda" (format nil "~a~d" (letra clave)
                                             (fila-encabezado hoja)))
                       (cons "campo" (format nil "__clave~d__" i))
                       (cons "rol" "derivado")
                       (cons "texto" (format nil "(clave ~{~(~a~)~^|~}~:[~;, filtrada~])"
                                             (partes clave) (filtro clave)))))
   (loop for columna in (distintos hoja)
         for i from 1
         collect (list (cons "celda" (format nil "~a~d" (letra columna)
                                             (fila-encabezado hoja)))
                       (cons "campo" (format nil "__distintos~d__" i))
                       (cons "rol" "derivado")
                       (cons "texto" (format nil "(primera vez de ~(~a~))"
                                             (campo-de columna)))))))

(defun formulas-de-claves (a plan hoja)
  "Las columnas de clave compuesta de HOJA, fila por fila.

   Cada una concatena sus campos para que una tabla cruzada pueda buscar por
   todos a la vez. Es maquinaria que el lenguaje no nombra: la inventa esta
   arquitectura porque no tiene busqueda por clave compuesta. En una pagina
   no hace ninguna falta."
  (append
   (loop for clave in (claves hoja)
         append (loop for i from 0 below (capacidad hoja)
                      for f = (+ (fila-primera hoja) i)
                      collect (list (cons "celda" (format nil "~a~d" (letra clave) f))
                                    (cons "formula"
                                          (formula-de-clave-compuesta a plan hoja clave f)))))
   (loop for columna in (distintos hoja)
         append (loop for i from 0 below (capacidad hoja)
                      for f = (+ (fila-primera hoja) i)
                      collect (list (cons "celda" (format nil "~a~d" (letra columna) f))
                                    (cons "formula"
                                          (formula-de-primera-aparicion plan hoja columna f)))))))

(defun formula-de-clave-compuesta (a plan hoja clave fila)
  "La clave compuesta de una fila: sus partes separadas por el caracter 31
   de ASCII, que no se puede teclear en una celda. Con una barra, un valor
   que llevara una barra podia confundirse con otro.

   Si la clave lleva filtro, la fila que no lo cumple se queda con la clave
   vacia. El filtro se pregunta en la hoja y no al generar: una fila que
   deja de cumplirlo sale de su casilla sin regenerar el libro."
  (let ((partes (format nil "~{~a~^&CHAR(31)&~}"
                        (loop for parte in (partes clave)
                              collect (celda hoja parte fila)))))
    (if (null (filtro clave))
        (format nil "=~a" partes)
        (let ((*fila* fila)
              (*hoja* hoja))
          (format nil "=IF(~a,~a,\"\")"
                  (condicion-excel a (filtro clave) (ambito-de (coleccion hoja)) plan)
                  partes)))))

(defun celdas-de (a plan hoja)
  "Los valores que no se calculan: los fijos y lo que el usuario ya escribio.

   Se toman del entorno, es decir del estado actual de la situacion, y no de
   los datos estaticos de la declaracion. Un libro generado es una foto de la
   situacion mas las formulas vivas; si solo llevara lo declarado, el usuario
   abriria el archivo y encontraria vacio lo que ya habia decidido."
  (declare (ignore a))
  (let* ((coleccion (coleccion hoja))
         (escribibles (remove-if (lambda (c) (eq (nucleo:rol c) :derivado))
                                 (nucleo:campos coleccion)))
         (filas (nucleo:filas-de (entorno plan) (nucleo:nombre coleccion)))
         (resultado '()))
    (loop for fila in filas
          for i from 0
          do (let ((numero (+ (fila-primera hoja) i)))
               (dolist (campo escribibles)
                 (let ((valor (gethash (nucleo:nombre campo) (nucleo:valores fila))))
                   (unless (nucleo:vacio-p valor)
                     (push (list (cons "celda"
                                       (format nil "~a~d"
                                               (columna-de hoja (nucleo:nombre campo))
                                               numero))
                                 (cons "valor" valor))
                           resultado))))))
    (nreverse resultado)))

(defun formulas-de (a plan hoja)
  "Una formula por celda derivada y por fila, incluidas las de reserva.

   Las filas reservadas tambien llevan su formula: si no, la primera fila que
   escriba el usuario no calcularia nada. Es una de las cosas que el corpus
   aprendio por las malas."
  (let* ((coleccion (coleccion hoja))
         (derivados (nucleo:campos-de-rol coleccion :derivado))
         (ambito (ambito-de coleccion))
         (resultado '()))
    (loop for i from 0 below (capacidad hoja)
          do (let ((*fila* (+ (fila-primera hoja) i))
                   (*hoja* hoja))
               (dolist (campo derivados)
                 (push (list (cons "celda" (format nil "~a~d"
                                                   (columna-de hoja (nucleo:nombre campo))
                                                   *fila*))
                             (cons "formula"
                                   (format nil "=~a"
                                           (con-guarda-de-fila
                                            a coleccion hoja ambito plan
                                            (formula-del-campo a campo ambito plan)))))
                       resultado))))
    (nreverse resultado)))

(defun formula-del-campo (a campo ambito plan)
  "La formula de un campo derivado. Un campo booleano vale \"si\" o \"no\",
   nunca VERDADERO o FALSO: es lo que escriben el texto y la pagina.

   Si la expresion no tiene traduccion a esta hoja de calculo, la celda dice
   que la pieza no esta disponible y el informe lo anota como rechazo, con
   el motivo. Antes la generacion entera se detenia."
  (handler-case
      (if (nucleo:campo-booleano-p campo)
          (format nil "IF(~a,\"si\",\"no\")"
                  (condicion-excel a (nucleo:expresion campo) ambito plan))
          (protocolo:emitir-expresion a (nucleo:expresion campo) ambito plan))
    (error (e)
      (rechazar-campo campo e)
      (cadena-excel protocolo:+pieza-ausente+))))

(defvar *campos-rechazados* nil
  "Los campos cuyo rechazo ya se anoto en esta emision: una formula por fila
   no puede llenar el informe con el mismo rechazo cien veces.")

(defun rechazar-campo (campo condicion)
  "Anota, una sola vez por campo, que CAMPO no tiene traduccion."
  (unless (member campo *campos-rechazados*)
    (push campo *campos-rechazados*)
    (protocolo:rebajar-en-informe
     'protocolo:con-derivacion-viva
     (format nil "~(~a~) se recalcula" (nucleo:nombre campo))
     :rechaza
     (format nil "~(~a~) no tiene traduccion a esta hoja de calculo: ~a"
             (nucleo:nombre campo) condicion))))

(defun con-guarda-de-fila (a coleccion hoja ambito plan formula)
  "Envuelve una formula para que no muestre nada en una fila todavia vacia.

   En una rejilla con filas reservadas, una formula sin guarda llena de ceros
   las filas en blanco. Es un problema de esta arquitectura -una pagina web
   no tiene filas vacias- y por eso se resuelve aqui y el lenguaje no lo
   menciona."
  (declare (ignore ambito plan))
  (if (eq (nucleo:crecimiento coleccion) :crece)
      ;; La fila existe en cuanto tiene escrito algun campo de su clave, no
      ;; solo el primero: una clave compuesta se puede empezar a escribir por
      ;; cualquiera de sus campos.
      (format nil "IF(AND(~{~a=\"\"~^,~}),\"\",~a)"
              (mapcar (lambda (c) (celda hoja c *fila*)) (campos-de-existencia coleccion))
              formula)
      formula))

(defun ambito-de (coleccion)
  (nucleo:hacer-ambito
   :ligaduras (list (cons (nucleo:nombrar "fila") coleccion))
   :actual (nucleo:nombrar "fila")))

(defun rangos-editables (plan hoja)
  "Los rangos donde el usuario puede escribir.

   Salen del rol de campo. Los campos de entrada, en todas las filas. Los
   fijos de una coleccion que crece, en las filas de reserva: en una
   coleccion que crece, fijo quiere decir que lo escribe quien crea la fila
   y despues no cambia. Antes quedaban bloqueados, y no habia forma de
   anadir una fila sin desproteger la hoja. Todo lo demas queda bloqueado
   al proteger la hoja, que es lo que impide borrar una formula sin querer."
  (let ((coleccion (coleccion hoja)))
    (append
     (loop for campo in (nucleo:campos-de-rol coleccion :entrada)
           collect (format nil "~a~d:~a~d"
                           (columna-de hoja (nucleo:nombre campo)) (fila-primera hoja)
                           (columna-de hoja (nucleo:nombre campo)) (fila-ultima hoja)))
     (when (eq (nucleo:crecimiento coleccion) :crece)
       (let ((primera-de-reserva (+ (fila-primera hoja) (filas-reales plan hoja))))
         (when (<= primera-de-reserva (fila-ultima hoja))
           (loop for campo in (nucleo:campos-de-rol coleccion :fijo)
                 collect (format nil "~a~d:~a~d"
                                 (columna-de hoja (nucleo:nombre campo)) primera-de-reserva
                                 (columna-de hoja (nucleo:nombre campo)) (fila-ultima hoja)))))))))

(defun formatos-de-celda (hoja)
  "El formato de fecha u hora de cada campo fijo o de entrada con ese tipo.

   Plan aprobado de tipos, seccion 4.1: por rango de columna entero, de la
   primera fila a la ultima de la capacidad, como las validaciones. Asi lo
   tiene tambien una fila de reserva que el usuario todavia no ha escrito, y
   una fecha tecleada de verdad se ve como fecha y no como un numero."
  (loop for campo in (nucleo:campos (coleccion hoja))
        when (and (member (nucleo:tipo campo) '(:fecha :hora))
                  (member (nucleo:rol campo) '(:fijo :entrada)))
          collect (let ((letra (columna-de hoja (nucleo:nombre campo))))
                    (list (cons "rango" (format nil "~a~d:~a~d"
                                                letra (fila-primera hoja)
                                                letra (fila-ultima hoja)))
                          (cons "formato" (string-downcase
                                           (symbol-name (nucleo:tipo campo))))))))

(defun validaciones-de (a plan hoja)
  "El desplegable de cada campo de entrada con dominio.

   :AL-VIOLAR ADVERTIR se traduce a un aviso no bloqueante, que es lo que
   hacen los libros del corpus; :IMPEDIR, a uno que si bloquea. La diferencia
   la declara el lenguaje porque es del dominio: hay restricciones que
   invalidan y restricciones que solo advierten."
  (let ((ambito (ambito-de (coleccion hoja)))
        (*hoja* hoja))
    (loop for campo in (nucleo:campos-de-rol (coleccion hoja) :entrada)
          when (nucleo:dominio campo)
            collect (protocolo:emitir-entrada a campo ambito plan))))

(defmethod protocolo:emitir-entrada ((a excel) campo ambito plan)
  "Un campo de entrada con dominio es un desplegable.

   :AL-VIOLAR ADVERTIR se traduce a un aviso no bloqueante e :IMPEDIR a uno
   que si bloquea. La diferencia la declara el lenguaje porque es del dominio."
  (declare (ignore ambito))
  (let ((letra (columna-de *hoja* (nucleo:nombre campo)))
        (valores (valores-del-dominio a plan campo)))
    (list (cons "rango" (format nil "~a~d:~a~d" letra (fila-primera *hoja*)
                                letra (fila-ultima *hoja*)))
          (cons "tipo" "lista")
          ;; Los valores van a una hoja oculta y la validacion cita su rango:
          ;; escritos dentro de la validacion, una coma partia un valor en dos.
          (cons "lista" (if valores (registrar-lista plan valores) :false))
          (cons "valores" (lista (mapcar #'nucleo:como-texto valores)))
          (cons "bloquea" (if (eq (nucleo:al-violar campo) :impedir) t :false)))))

(defun valores-del-dominio (a plan campo)
  "Los valores admisibles, vengan de una coleccion o escritos a mano.

   Se evaluan con el evaluador de referencia del nucleo, que es quien sabe
   que significa un conjunto. El backend no tiene que distinguir entre
   (los x de y) y (uno-de \"a\" \"b\"): los dos son expresiones de conjunto."
  (declare (ignore a))
  ;; Los valores se dejan como son: un numero sigue siendo numero en la
  ;; lista, para que coincida con el numero que el usuario teclee.
  (handler-case
      (mapcar #'nucleo:normalizar-numero
              (nucleo:evaluar (nucleo:dominio campo) (nucleo:hacer-ambito)
                              (entorno plan) '()))
    (error () '())))

(defun formatos-de (a plan hoja)
  "Una regla de formato condicional por marca que senale campos de esta hoja.

   El trabajo lo hace EMITIR-MARCA, que es una operacion del protocolo: asi
   materializar una marca es un punto de extension de verdad y no codigo
   interno de este backend. Quien anada una arquitectura escribe su propio
   metodo y no toca nada de aqui."
  (let* ((coleccion (coleccion hoja))
         (ambito (ambito-de coleccion)))
    (loop for marca in (nucleo:marcas (situacion plan))
          when (marca-de-esta-hoja-p marca coleccion)
            append (let ((*fila* (fila-primera hoja))
                         (*hoja* hoja))
                     ;; Una condicion sin traduccion no pinta nada, y el
                     ;; informe lo dice de esa marca; el resto del libro sale.
                     (handler-case (list (protocolo:emitir-marca a marca ambito plan))
                       (error (e)
                         (protocolo:rebajar-en-informe
                          'protocolo:con-marcado-visual
                          (string-downcase (symbol-name (nucleo:nombre marca)))
                          :rechaza
                          (format nil "la condicion de ~(~a~) no tiene traduccion a~@
                                       esta hoja de calculo: ~a" (nucleo:nombre marca) e))
                         '()))))))

(defmethod protocolo:emitir-marca ((a excel) marca ambito plan)
  "Una marca es una regla de formato condicional sobre el rango de su alcance.

   El color sale de la paleta de esta arquitectura, por severidad. La marca
   no conoce ningun color: declara un significado y lo grave que es."
  (list (cons "rango" (rango-de-alcance *hoja* (nucleo:alcance marca)))
        (cons "estado" (string-downcase (symbol-name (nucleo:nombre marca))))
        (cons "severidad" (string-downcase (symbol-name (nucleo:severidad marca))))
        (cons "formula" (condicion-excel a (nucleo:condicion marca) ambito plan))
        (cons "relleno" (relleno-de-marca plan marca))))

(defun rango-de-alcance (hoja campos)
  (format nil "~{~a~^ ~}"
          (loop for c in campos
                collect (format nil "~a~d:~a~d"
                                (columna-de hoja c) (fila-primera hoja)
                                (columna-de hoja c) (fila-ultima hoja)))))

(defun rangos-nombrados-de (hoja)
  "Un rango con nombre por coleccion, para que las busquedas lo referencien.

   Si la coleccion crece, el rango se dimensiona con lo escrito en vez de
   abarcar toda la reserva: es la emulacion del crecimiento, y trae la trampa
   documentada de que no admite huecos en medio."
  (let* ((coleccion (coleccion hoja))
         (clave (or (first (nucleo:clave coleccion))
                    (nucleo:nombre (first (nucleo:campos coleccion)))))
         (n-columnas (length (nucleo:campos coleccion)))
         (letra (columna-de hoja clave))
         (nombre-hoja (entrecomillar (nombre hoja))))
    (list
     (list (cons "nombre" (rango-nombrado hoja))
           (cons "referencia"
                 (if (eq (nucleo:crecimiento coleccion) :crece)
                     (format nil "OFFSET(~a!$~a$~d,0,0,COUNTA(~a!$~a$~d:$~a$~d),~d)"
                             nombre-hoja letra (fila-primera hoja)
                             nombre-hoja letra (fila-primera hoja)
                             letra (fila-ultima hoja) n-columnas)
                     (format nil "~a!$~a$~d:$~a$~d"
                             nombre-hoja letra (fila-primera hoja)
                             (letra-de-columna (1- n-columnas)) (fila-ultima hoja))))))))

(defun leyenda-de (plan hoja)
  "Que significa cada color, escrito. Sin esto, una marca visual es un color
   sin explicacion, que es medio concepto."
  (let ((coleccion (coleccion hoja)))
    (loop for marca in (nucleo:marcas (situacion plan))
          when (marca-de-esta-hoja-p marca coleccion)
            collect (list (cons "relleno" (relleno-de-marca plan marca))
                          (cons "texto" (texto-de-leyenda marca))))))
