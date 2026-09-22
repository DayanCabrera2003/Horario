;;;; Emision a hoja de calculo.
;;;;
;;;; Recorre el plan y produce el plano de libro. Aqui es donde el rol de
;;;; campo -un solo hecho del dominio- se convierte en cuatro cosas distintas:
;;;; la celda escrita o la formula, el bloqueo, el color de la pestana y la
;;;; validacion.

(in-package #:situacion.excel)

(defparameter +paleta+
  '((:problema    . "FFC7CE")
    (:advertencia . "FFEB9C")
    (:informativa . "DDEBF7"))
  "De severidad a relleno.

   Es una opcion de esta arquitectura, no del lenguaje. La marca declara un
   significado y una severidad; que el problema se vea rojo es una decision
   de como se pinta una hoja de calculo, y otra arquitectura puede decidir
   otra cosa sin tocar ninguna descripcion.

   Que este aqui y no en el nodo de la marca es la correccion del hallazgo
   sobre 2026: alli la definicion 3.8 decia que la regla tenia color, el nodo
   no lo tenia, y el backend lo asignaba por orden de aparicion.")

(defun relleno-de (severidad)
  (or (cdr (assoc severidad +paleta+)) "EEEEEE"))

(defmethod protocolo:materializar ((a excel) situacion datos destino)
  (protocolo:con-informe (a)
    (dolist (r (protocolo:requerimientos situacion))
      (destructuring-bind (capacidad nodo detalle) r
        (protocolo:requerir a capacidad nodo :detalle detalle)))
    (let ((plan (protocolo:planificar a situacion)))
      (setf (entorno plan) (nucleo:hacer-entorno situacion datos))
      (protocolo:emitir a plan destino))))

(defmethod protocolo:emitir ((a excel) plan destino)
  (escribir-plano (construir-plano a plan) destino))

(defun construir-plano (a plan)
  ;; Las vistas se planifican antes de emitir: pueden reordenar las hojas y,
  ;; si son cruzadas, anaden geometria propia.
  ;; Antes que nada, las hojas se redimensionan con las filas que de verdad
  ;; hay: al planificar solo se conocian las declaradas.
  (ajustar-capacidades a plan)
  (dolist (vista (nucleo:vistas (situacion plan)))
    (when (nucleo:cruzada-p vista) (planificar-cruces a vista plan))
    (protocolo:planificar-vista a vista plan))
  (setf (cruces plan) (nreverse (cruces plan)))
  ;; La hoja auxiliar de cada relacion uno-a-muchos (H4), antes que
  ;; PLANO-DE-HOJA: EMITIR-EXPRESION sobre RELACIONADAS (excel/formula.lisp)
  ;; necesita encontrar su hoja auxiliar en (AUXILIARES PLAN) para escribir
  ;; el COUNTIF de la hoja de origen.
  (dolist (hoja (hojas plan))
    (dolist (campo (campos-de-relacion (coleccion hoja)))
      (push (planificar-detalle a plan hoja campo) (auxiliares plan))))
  (setf (auxiliares plan) (nreverse (auxiliares plan)))
  (list (cons "libro" (nucleo:etiqueta (situacion plan)))
        (cons "vistas" (lista (mapcar (lambda (v) (protocolo:emitir-vista a v plan))
                                      (nucleo:vistas (situacion plan)))))
        (cons "hojas" (lista (append
                              (mapcar (lambda (c) (plano-de-cruce a plan c))
                                      (cruces plan))
                              (mapcar (lambda (h) (plano-de-hoja a plan h))
                                      (hojas plan))
                              (mapcar (lambda (d) (plano-de-detalle a plan d))
                                      (auxiliares plan)))))))

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
                              (columna-auxiliar cruce) (fila-primera hoja)
                              (columna-auxiliar cruce) (fila-ultima hoja)))
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
    (list (cons "nombre" (nombre-de-pestana (nucleo:etiqueta vista) (seccion cruce)))
          (cons "fila_encabezado" fila-enc)
          (cons "fila_primera" fila-ini)
          (cons "capacidad" (max 1 (length (valores-de-fila cruce))))
          (cons "color_pestana" "8EA9DB")
          (cons "encabezados" (lista encabezados))
          (cons "celdas" (lista celdas))
          (cons "formulas" (lista formulas))
          (cons "editables" :lista-vacia)
          (cons "validaciones" :lista-vacia)
          (cons "formatos_condicionales" :lista-vacia)
          (cons "rangos_nombrados" :lista-vacia)
          (cons "leyenda" :lista-vacia))))

(defun formula-de-casilla (cruce rango-valor rango-clave fila columna fila-enc)
  "La formula de una casilla del cruce.

   Normalmente es una busqueda por la clave compuesta: INDICE mas COINCIDIR,
   que es la pareja portable entre Excel y LibreOffice Calc. La primera parte
   de la clave es el valor de ESTA pestana, fijado al generar.

   Si la vista declaro (:UNICA-SALVO <marca>), la casilla puede tener mas de
   una fila candidata, y entonces la formula pregunta primero CUANTAS hay.
   Con mas de una escribe la primera y cuantas mas: es todo lo que una hoja
   de calculo puede decir sin formulas matriciales, que no se comportan igual
   en los dos programas. Por eso aqui la capacidad se emula y no se cumple.
   Lo que no hace, y es lo que importa, es ensenar una de las dos como si
   fuera la unica."
  (let ((clave (format nil "~@[\"~a\"&\"|\"&~]$A~d&\"|\"&~a$~d"
                       (when (seccion cruce)
                         (nucleo:como-texto (seccion cruce)))
                       fila columna fila-enc))
        (busqueda "IFERROR(INDEX(~a,MATCH(~a,~a,0)),\"\")"))
    (if (null (nucleo:conflicto (vista cruce)))
        (format nil "=~a" (format nil busqueda rango-valor clave rango-clave))
        (format nil "=IF(COUNTIF(~a,~a)>1,~a&\" (+\"&(COUNTIF(~a,~a)-1)&\")\",~a)"
                rango-clave clave
                (format nil busqueda rango-valor clave rango-clave)
                rango-clave clave
                (format nil busqueda rango-valor clave rango-clave)))))

(defun nombre-de-pestana (etiqueta seccion)
  "El nombre de la pestana de un cruce, con su seccion si la tiene.

   Excel no admite nombres de hoja de mas de 31 caracteres. Es una
   restriccion del formato de salida, asi que se resuelve aqui y ni el
   lenguaje ni el protocolo se enteran."
  (let ((completo (if seccion
                      (format nil "~a - ~a" etiqueta (nucleo:como-texto seccion))
                      etiqueta)))
    (if (> (length completo) 31) (subseq completo 0 31) completo)))

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
  "El nombre visible de la pestana y si es por donde se entra."
  (let ((hoja (hoja-de plan (nucleo:fuente vista))))
    (list (cons "vista" (string-downcase (symbol-name (nucleo:nombre vista))))
          (cons "titulo" (nucleo:etiqueta vista))
          (cons "hoja" (if hoja (nombre hoja) ""))
          (cons "es_entrada" (if (nucleo:es-entrada vista) t :false)))))

(defun plano-de-hoja (a plan hoja)
  (let ((*hoja* hoja))
    (declare (special *hoja*))
    (list (cons "nombre" (nombre hoja))
          (cons "fila_encabezado" (fila-encabezado hoja))
          (cons "fila_primera" (fila-primera hoja))
          (cons "capacidad" (capacidad hoja))
          (cons "color_pestana" (color-de-pestana hoja))
          (cons "encabezados" (lista (append (encabezados-de hoja)
                                             (encabezado-auxiliar plan hoja))))
          (cons "celdas" (lista (celdas-de a plan hoja)))
          (cons "formulas" (lista (append (formulas-de a plan hoja)
                                          (claves-compuestas plan hoja))))
          (cons "editables" (lista (rangos-editables hoja)))
          (cons "validaciones" (lista (validaciones-de a plan hoja)))
          (cons "formatos_condicionales" (lista (formatos-de a plan hoja)))
          (cons "rangos_nombrados" (lista (rangos-nombrados-de hoja)))
          (cons "leyenda" (lista (leyenda-de plan hoja))))))

(defun color-de-pestana (hoja)
  "Azul si en la hoja se escribe a mano, gris si todo se calcula.

   Sale del rol de campo, no de una decision aparte. Es el mismo criterio que
   usan los libros del corpus."
  (if (nucleo:campos-de-rol (coleccion hoja) :entrada) "4472C4" "8EA9DB"))

(defun cruce-de-la-hoja (plan hoja)
  (find hoja (cruces plan) :key #'hoja-origen))

(defun encabezados-de (hoja)
  (loop for campo in (nucleo:campos (coleccion hoja))
        collect (list (cons "celda" (format nil "~a~d"
                                            (columna-de hoja (nucleo:nombre campo))
                                            (fila-encabezado hoja)))
                      (cons "campo" (string-downcase (symbol-name (nucleo:nombre campo))))
                      (cons "rol" (string-downcase (symbol-name (nucleo:rol campo))))
                      (cons "texto" (nucleo:etiqueta campo)))))

(defun encabezado-auxiliar (plan hoja)
  "El encabezado de la columna de clave compuesta, si esta hoja alimenta una
   tabla cruzada."
  (let ((cruce (cruce-de-la-hoja plan hoja)))
    (when cruce
      (list (list (cons "celda" (format nil "~a~d" (columna-auxiliar cruce)
                                        (fila-encabezado hoja)))
                  (cons "campo" "__clave__")
                  (cons "rol" "derivado")
                  (cons "texto" "(clave)"))))))

(defun claves-compuestas (plan hoja)
  "La columna que concatena los dos ejes, para que la tabla cruzada pueda
   buscar por dos criterios.

   Es maquinaria que el lenguaje no nombra: la inventa esta arquitectura
   porque no tiene busqueda por clave compuesta. En una pagina no hace
   ninguna falta."
  (let ((cruce (cruce-de-la-hoja plan hoja)))
    (when cruce
      (let* ((vista (vista cruce))
             (parte-de-seccion (nucleo:secciones vista)))
        (loop for i from 0 below (capacidad hoja)
              for f = (+ (fila-primera hoja) i)
              collect (list (cons "celda" (format nil "~a~d"
                                                  (columna-auxiliar cruce) f))
                            (cons "formula"
                                  ;; Con particion la clave lleva tres partes:
                                  ;; seccion | eje-de-filas | eje-de-columnas.
                                  ;; Sin la primera, dos secciones producen la
                                  ;; misma clave y COINCIDIR devuelve la fila
                                  ;; de otra pestana.
                                  (format nil "=~@[~a&\"|\"&~]~a&\"|\"&~a"
                                          (when parte-de-seccion
                                            (celda hoja parte-de-seccion f))
                                          (celda hoja (nucleo:eje-de-filas vista) f)
                                          (celda hoja (nucleo:eje-de-columnas vista) f)))))))))

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
                                            (protocolo:emitir-expresion
                                             a (nucleo:expresion campo) ambito plan)))))
                       resultado))))
    (nreverse resultado)))

(defun con-guarda-de-fila (a coleccion hoja ambito plan formula)
  "Envuelve una formula para que no muestre nada en una fila todavia vacia.

   En una rejilla con filas reservadas, una formula sin guarda llena de ceros
   las filas en blanco. Es un problema de esta arquitectura -una pagina web
   no tiene filas vacias- y por eso se resuelve aqui y el lenguaje no lo
   menciona."
  (declare (ignore ambito plan))
  (let ((clave (or (first (nucleo:clave coleccion))
                   (nucleo:nombre (first (nucleo:campos coleccion))))))
    (if (eq (nucleo:crecimiento coleccion) :crece)
        (format nil "IF(~a=\"\",\"\",~a)" (celda hoja clave *fila*) formula)
        formula)))

(defun ambito-de (coleccion)
  (nucleo:hacer-ambito
   :ligaduras (list (cons (nucleo:nombrar "fila") coleccion))
   :actual (nucleo:nombrar "fila")))

(defun rangos-editables (hoja)
  "Los rangos donde el usuario puede escribir.

   Salen del rol de campo. Todo lo demas queda bloqueado al proteger la hoja,
   que es lo que impide borrar una formula sin querer."
  (loop for campo in (nucleo:campos-de-rol (coleccion hoja) :entrada)
        collect (format nil "~a~d:~a~d"
                        (columna-de hoja (nucleo:nombre campo)) (fila-primera hoja)
                        (columna-de hoja (nucleo:nombre campo)) (fila-ultima hoja))))

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
  (let ((letra (columna-de *hoja* (nucleo:nombre campo))))
    (list (cons "rango" (format nil "~a~d:~a~d" letra (fila-primera *hoja*)
                                letra (fila-ultima *hoja*)))
          (cons "tipo" "lista")
          (cons "valores" (valores-del-dominio a plan campo))
          (cons "bloquea" (if (eq (nucleo:al-violar campo) :impedir) t :false)))))

(defun valores-del-dominio (a plan campo)
  "Los valores admisibles, vengan de una coleccion o escritos a mano.

   Se evaluan con el evaluador de referencia del nucleo, que es quien sabe
   que significa un conjunto. El backend no tiene que distinguir entre
   (los x de y) y (uno-de \"a\" \"b\"): los dos son expresiones de conjunto."
  (declare (ignore a))
  (handler-case
      (mapcar #'nucleo:como-texto
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
            collect (let ((*fila* (fila-primera hoja))
                          (*hoja* hoja))
                      (protocolo:emitir-marca a marca ambito plan)))))

(defmethod protocolo:emitir-marca ((a excel) marca ambito plan)
  "Una marca es una regla de formato condicional sobre el rango de su alcance.

   El color sale de la paleta de esta arquitectura, por severidad. La marca
   no conoce ningun color: declara un significado y lo grave que es."
  (list (cons "rango" (rango-de-alcance *hoja* (nucleo:alcance marca)))
        (cons "estado" (string-downcase (symbol-name (nucleo:nombre marca))))
        (cons "severidad" (string-downcase (symbol-name (nucleo:severidad marca))))
        (cons "formula" (protocolo:emitir-expresion
                         a (nucleo:condicion marca) ambito plan))
        (cons "relleno" (relleno-de (nucleo:severidad marca)))))

(defun marca-de-esta-hoja-p (marca coleccion)
  (if (nucleo:coleccion marca)
      (eq (nucleo:coleccion marca) (nucleo:nombre coleccion))
      (every (lambda (c) (nucleo:campo-llamado coleccion c))
             (nucleo:alcance marca))))

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
            collect (list (cons "relleno" (relleno-de (nucleo:severidad marca)))
                          (cons "texto" (string-downcase
                                         (substitute #\Space #\-
                                                     (symbol-name (nucleo:nombre marca)))))))))
