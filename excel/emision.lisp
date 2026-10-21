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
        (protocolo:anotar-avisos-de-los-datos situacion (entorno plan))
        (protocolo:emitir a plan destino)))))

(defmethod protocolo:emitir ((a excel) plan destino)
  ;; CONSTRUIR-PLANO resuelve (ARCHIVOS PLAN) como efecto lateral de recorrer
  ;; las vistas (PLANIFICAR-CRUCES, mas arriba en este archivo), asi que para
  ;; cuando llega aqui ya se sabe si hay algo que escribir aparte.
  (escribir-plano (construir-plano a plan) destino)
  (when (archivos plan)
    (escribir-archivos-de-vista a plan destino))
  destino)

(defvar *campos-rechazados* nil
  "Los campos cuyo rechazo ya se anoto en esta emision: una formula por fila
   no puede llenar el informe con el mismo rechazo cien veces.")

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
  ;; Que rejillas de entrada llevan el dato: decide que columnas de las
  ;; hojas de datos pasan a ser formulas, asi que va antes de emitir ninguna.
  (planificar-rejillas-de-entrada a plan)
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
                        ;; La de parametros, detras de las de datos. La de
                        ;; listas va al final: se llena mientras se emiten los
                        ;; desplegables de las demas.
                        (lista (append hojas
                                       (when (nombre-de-parametros plan)
                                         (list (plano-de-parametros plan)))
                                       (when (nombre-de-listas plan)
                                         (list (plano-de-listas plan)))))))))

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
          (cons "color_pestana" (color-de-pestana plan hoja))
          (cons "encabezados" (lista (append (encabezados-de hoja)
                                             (encabezado-de-estado hoja)
                                             (encabezado-de-nivel hoja)
                                             (encabezados-de-claves hoja))))
          (cons "celdas" (lista (celdas-de a plan hoja)))
          (cons "formulas" (lista (append (formulas-de a plan hoja)
                                          (formulas-copiadas-de-la-rejilla plan hoja)
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

(defun color-de-pestana (plan hoja)
  "Azul si en la hoja se escribe a mano, azul claro si todo se calcula.

   Sale del rol de campo, no de una decision aparte. Es el mismo criterio que
   usan los libros del corpus. Un campo de entrada que se escribe en una
   rejilla (excel/rejilla-de-entrada.lisp) no cuenta: aqui se calcula."
  (if (remove-if (lambda (c) (rejilla-que-escribe plan hoja (nucleo:nombre c)))
                 (nucleo:campos-de-rol (coleccion hoja) :entrada))
      "4472C4" "8EA9DB"))

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
         ;; Un campo que se escribe en una rejilla de entrada no lleva el
         ;; valor aqui: lo lleva la rejilla, y aqui hay una formula que lo lee.
         (escribibles (remove-if (lambda (c)
                                   (or (eq (nucleo:rol c) :derivado)
                                       (rejilla-que-escribe plan hoja (nucleo:nombre c))))
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
  (declare (ignore a ambito plan))
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

(defun formatos-de-celda (hoja)
  "El formato de fecha u hora de cada campo fijo o de entrada con ese tipo.

   Plan aprobado de tipos, seccion 4.1: por rango de columna entero, de la
   primera fila a la ultima de la capacidad, como las validaciones. Asi lo
   tiene tambien una fila de reserva que el usuario todavia no ha escrito, y
   una fecha tecleada de verdad se ve como fecha y no como un numero."
  (append
   (loop for campo in (nucleo:campos (coleccion hoja))
         when (and (member (nucleo:tipo campo) '(:fecha :hora))
                   (member (nucleo:rol campo) '(:fijo :entrada)))
           collect (let ((letra (columna-de hoja (nucleo:nombre campo))))
                     (list (cons "rango" (format nil "~a~d:~a~d"
                                                 letra (fila-primera hoja)
                                                 letra (fila-ultima hoja)))
                           (cons "formato" (string-downcase
                                            (symbol-name (nucleo:tipo campo)))))))
   ;; Los decimales de un campo (fase 2, hueco C6): formato de numero en
   ;; toda la columna, derivados y filas de reserva incluidos. La celda
   ;; guarda el valor completo y la hoja calcula con el, como el evaluador.
   (loop for campo in (nucleo:campos (coleccion hoja))
         when (nucleo:decimales campo)
           collect (let ((letra (columna-de hoja (nucleo:nombre campo))))
                     (formato-de-decimales (format nil "~a~d:~a~d"
                                                   letra (fila-primera hoja)
                                                   letra (fila-ultima hoja))
                                           (nucleo:decimales campo))))))

(defun formato-de-decimales (rango decimales)
  "La entrada de FORMATOS_DE_CELDA que escribe RANGO con DECIMALES fijos."
  (list (cons "rango" rango)
        (cons "formato" "decimales")
        (cons "decimales" decimales)))

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
                     (handler-case (if (nucleo:por-campo marca)
                                       (formatos-de-marca-por-campo a marca ambito plan)
                                       (list (protocolo:emitir-marca a marca ambito plan)))
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

   El color sale de la paleta de esta arquitectura, +TONOS+ en
   excel/presentacion.lisp: un tono propio para cada marca, dentro de la
   familia de su severidad. La marca no conoce ningun color: declara un
   significado y lo grave que es."
  (list (cons "rango" (rango-de-alcance *hoja* (nucleo:alcance marca)))
        (cons "estado" (string-downcase (symbol-name (nucleo:nombre marca))))
        (cons "severidad" (string-downcase (symbol-name (nucleo:severidad marca))))
        (cons "formula" (condicion-excel a (nucleo:condicion marca) ambito plan))
        (cons "relleno" (relleno-de-marca plan marca))))

(defun formatos-de-marca-por-campo (a marca ambito plan)
  "Una marca :POR-CAMPO es una regla por campo de su :SOBRE, cada una sobre
   la columna de ese campo y con la variable traducida a la celda de ese
   campo: asi se pinta solo el campo donde se cumple (fase 2, hueco C7)."
  (loop for campo in (nucleo:alcance marca)
        collect (list (cons "rango" (rango-de-alcance *hoja* (list campo)))
                      (cons "estado" (string-downcase (symbol-name (nucleo:nombre marca))))
                      (cons "severidad" (string-downcase (symbol-name (nucleo:severidad marca))))
                      (cons "formula" (condicion-de-marca a marca ambito plan campo))
                      (cons "relleno" (relleno-de-marca plan marca)))))

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
