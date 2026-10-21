;;;; Emision de las tablas cruzadas a hoja de calculo.
;;;;
;;;; Una pestana por seccion de cada vista cruzada: los dos ejes fijados al
;;;; generar y, en cada casilla, la busqueda por clave compuesta en la hoja
;;;; de datos, o el dato mismo si la rejilla es de entrada
;;;; (excel/rejilla-de-entrada.lisp). Salio de excel/emision.lisp el
;;;; 2026-10-21, cuando ese archivo paso de setecientas cincuenta lineas.

(in-package #:situacion.excel)

(defun plano-de-cruce (a plan cruce)
  "La hoja de la tabla cruzada, con sus dos ejes fijados y sus busquedas.

   La celda del cruce es una busqueda por DOS criterios, y una hoja de
   calculo no la tiene: BUSCARV busca por uno. Se emula con una columna de
   clave compuesta en la hoja de origen mas INDICE y COINCIDIR, que es la
   pareja portable entre Excel y LibreOffice Calc.

   El coste esta declarado en el informe de conformidad: los ejes se fijan al
   generar."
  (let* ((vista (vista cruce))
         (hoja (hoja-origen cruce))
         (coleccion (coleccion hoja))
         (nombre-origen (entrecomillar (nombre hoja)))
         (fila-enc (1- +fila-primera-de-rejilla+)) (fila-ini +fila-primera-de-rejilla+)
         ;; Una rejilla de entrada lleva el dato y no la busqueda
         ;; (excel/rejilla-de-entrada.lisp).
         (de-entrada (rejilla-de-entrada-p plan cruce))
         (rango-de-casillas (format nil "B~d:~a~d" fila-ini
                                    (letra-de-columna (max 1 (length (valores-de-columna cruce))))
                                    (+ fila-ini (max 0 (1- (length (valores-de-fila cruce)))))))
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
         (celdas (append
                  (loop for v in (valores-de-fila cruce)
                        for f from fila-ini
                        collect (list (cons "celda" (format nil "A~d" f))
                                      (cons "valor" v)))
                  ;; Los valores fuera del dominio declarado de un eje (fase 2,
                  ;; hueco C1) tienen su fila o su columna al final; debajo de
                  ;; la rejilla se dice cuales. Va en la columna B porque la A
                  ;; es el eje de filas.
                  (let ((aviso (nucleo:aviso-fuera-de-dominio (entorno plan) vista)))
                    (when aviso
                      (list (list (cons "celda"
                                        (format nil "B~d" (+ fila-ini
                                                             (length (valores-de-fila cruce))
                                                             1)))
                                  (cons "valor" (format nil "Aviso: ~a" aviso))))))
                  (when de-entrada (celdas-de-la-rejilla plan cruce))))
         (formulas (loop for v in (unless de-entrada (valores-de-fila cruce))
                         for f from fila-ini
                         append (loop for i from 1 to (length (valores-de-columna cruce))
                                      collect
                                      (list (cons "celda" (format nil "~a~d"
                                                                  (letra-de-columna i) f))
                                            (cons "formula"
                                                  (formula-de-casilla
                                                   cruce rango-valor rango-clave
                                                   f (letra-de-columna i) fila-enc)))))))
    (append
     (list (cons "nombre" (nombre cruce))
          (cons "titulo" (titulo cruce))
          (cons "cruce" (identidad-de-cruce cruce))
          (cons "fila_encabezado" fila-enc)
          (cons "fila_primera" fila-ini)
          (cons "capacidad" (max 1 (length (valores-de-fila cruce))))
          ;; Azul si se escribe en ella, como cualquier hoja de entrada.
          (cons "color_pestana" (if de-entrada "4472C4" "8EA9DB"))
          (cons "encabezados" (lista encabezados))
          (cons "celdas" (lista celdas))
          (cons "formulas" (lista formulas))
          (cons "anchos" (anchos-de-cruce plan cruce))
          (cons "impresion" (impresion t))
          (cons "editables" (if de-entrada (lista (list rango-de-casillas)) :lista-vacia))
          (cons "validaciones" (if de-entrada
                                   (lista (validacion-de-la-rejilla a plan cruce rango-de-casillas))
                                   :lista-vacia))
          (cons "formatos_condicionales" (lista (marcas-de-la-rejilla cruce fila-ini fila-enc)))
          (cons "rangos_nombrados" :lista-vacia)
          (cons "leyenda" :lista-vacia))
     ;; Las casillas muestran el campo de la celda: con sus decimales, si
     ;; los declara (fase 2, hueco C6). Sin ellos la hoja no lleva la clave,
     ;; y su plano es el de siempre.
     (let ((campo (nucleo:campo-llamado coleccion campo-celda)))
       (when (and campo (nucleo:decimales campo) (valores-de-fila cruce)
                  (valores-de-columna cruce))
         (list (cons "formatos_de_celda"
                     (lista (list (formato-de-decimales
                                   (format nil "B~d:~a~d" fila-ini
                                           (letra-de-columna (length (valores-de-columna cruce)))
                                           (+ fila-ini (length (valores-de-fila cruce)) -1))
                                   (nucleo:decimales campo)))))))))))

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
   Con dos escribe las dos, \"C111 / F11\"; con mas, las dos primeras y
   cuantas mas, \"C111 / F11 (+1)\". La segunda se busca con el mismo
   COINCIDIR, pero sobre el trozo de la columna que queda debajo de la
   primera: INDICE:INDICE da ese rango sin formulas matriciales, que no se
   comportan igual en los dos programas. Escribirlas todas si necesitaria
   una matricial, y por eso aqui la capacidad se emula y no se cumple. Lo
   que no hace, y es lo que importa, es ensenar una como si fuera la unica.

   Hasta el 2026-10-21 escribia solo la primera, \"C111 (+1)\": se veia que
   habia choque, pero no con quien.

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
        (let* ((cuantas (format nil "SUMPRODUCT(1*~a)" coincide))
               ;; La segunda: la primera coincidencia en el trozo de la
               ;; columna que queda debajo de la primera. Solo se evalua
               ;; con dos o mas, y entonces la primera no es la ultima fila
               ;; y el trozo no esta vacio.
               (debajo (format nil "INDEX(~a,~a+1):INDEX(~a,ROWS(~a))"
                               rango-clave posicion rango-clave rango-clave))
               (posicion-2 (format nil "(~a+MATCH(1,INDEX(EXACT(~a,~a)*1,0),0))"
                                   posicion debajo clave))
               (encontrado-2 (format nil "INDEX(~a,~a)" rango-valor posicion-2))
               (segunda (format nil "IF(ISBLANK(~a),\"\",~a)" encontrado-2 encontrado-2)))
          (format nil "=IF(~a>1,~a&\" / \"&~a&IF(~a>2,\" (+\"&(~a-2)&\")\",\"\"),~a)"
                  cuantas busqueda segunda cuantas cuantas busqueda)))))
