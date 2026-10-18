;;;; La demostracion.
;;;;
;;;; Toma las descripciones del corpus y, sin tocar ni una linea de ellas,
;;;; produce tres artefactos distintos mas el informe de conformidad de cada
;;;; arquitectura.
;;;;
;;;; Lo que hay que mirar no es que los tres salgan bonitos. Es que:
;;;;
;;;;   - La descripcion es la misma para los tres.
;;;;   - El evaluador de referencia y las tres arquitecturas coinciden en los
;;;;     valores. Eso es lo que hace que "independiente del destino" signifique
;;;;     algo comprobable.
;;;;   - El informe dice, capacidad por capacidad, que cumplio cada una, que
;;;;     emulo y que degrado. Ninguna de las tres tesis anteriores tiene nada
;;;;     equivalente.

(defpackage #:situacion.demostracion
  (:use #:common-lisp)
  (:export #:generar #:generar-todo #:generar-casos))

(in-package #:situacion.demostracion)

(defparameter +salida+ #p"salida/"
  "Donde caen los artefactos.")

(defun ruta (nombre) (merge-pathnames nombre +salida+))

(defun generar (situacion datos prefijo)
  "Genera los tres artefactos de una situacion y devuelve los informes."
  (ensure-directories-exist +salida+)
  (format t "~&~%~a~%" (make-string 70 :initial-element #\=))
  (format t "~a~%" (nucleo:etiqueta situacion))
  (format t "~a~%" (make-string 70 :initial-element #\=))

  ;; Fase 4: comprobaciones estaticas, sin saber a donde se va a generar.
  (multiple-value-bind (s problemas) (analisis:analizar situacion)
    (declare (ignore s))
    (if problemas
        (format t "~&Analisis: ~d aviso(s)~%~a" (length problemas)
                (analisis:informe-de-problemas problemas))
        (format t "~&Analisis: sin problemas.~%")))

  (let ((informes '()))
    ;; --- texto plano ---
    (multiple-value-bind (destino informe)
        (protocolo:materializar (situacion.texto:hacer-texto) situacion datos
                                (ruta (format nil "~a.txt" prefijo)))
      (format t "~&~%Generado ~a~%" destino)
      (push (cons "texto" informe) informes))

    ;; --- hoja de calculo (el plano que consume el materializador) ---
    (multiple-value-bind (destino informe)
        (protocolo:materializar (situacion.excel:hacer-excel) situacion datos
                                (ruta (format nil "~a-plano.json" prefijo)))
      (format t "Generado ~a~%" destino)
      (push (cons "excel" informe) informes))

    ;; --- los valores esperados, segun el evaluador de referencia ---
    ;; No es un artefacto de salida: es el oraculo. Lo que diga aqui el
    ;; nucleo es lo que tiene que dar la hoja de calculo cuando LibreOffice
    ;; evalue sus formulas, y lo que tiene que dar la pagina al abrirse.
    (escribir-esperado situacion datos (ruta (format nil "~a-esperado.json" prefijo)))
    (format t "Generado salida/~a-esperado.json  (oraculo del evaluador)~%" prefijo)
    (escribir-cruces-esperados situacion datos
                               (ruta (format nil "~a-cruces.json" prefijo)))
    (format t "Generado salida/~a-cruces.json  (oraculo de las tablas cruzadas)~%"
            prefijo)
    (escribir-vistas-esperadas situacion datos
                               (ruta (format nil "~a-vistas.json" prefijo)))
    (format t "Generado salida/~a-vistas.json  (oraculo de las tablas de lista)~%"
            prefijo)

    ;; --- pagina web ---
    (multiple-value-bind (destino informe)
        (protocolo:materializar (situacion.web:hacer-web) situacion datos
                                (ruta (format nil "~a.html" prefijo)))
      (format t "Generado ~a~%" destino)
      (push (cons "web" informe) informes))

    (format t "~%")
    (dolist (par (reverse informes))
      (protocolo:escribir-informe (cdr par))
      (format t "~%"))
    (reverse informes)))

(defun campos-de-relacion (situacion)
  "Los nombres de los campos cuyo valor es una relacion uno a muchos."
  (loop for coleccion in (nucleo:colecciones situacion)
        append (loop for campo in (nucleo:campos coleccion)
                     when (typep (nucleo:expresion campo) 'nucleo:relacionadas)
                       collect (nucleo:nombre campo))))

(defun campos-marcados-esperados (entorno fila)
  "Que campos de FILA pinta cada marca que dispara, en el orden de las
   marcas. En el JSON sale como objeto, {marca: [severidad, [campos]]}, en
   el orden en que se declararon las marcas. Es lo que comparan los
   verificadores con el color de cada celda (fase 2, hueco C7): la severidad
   dice que color, y los campos donde."
  (situacion.excel::lista
   (loop for marca in (nucleo:marcas-que-disparan entorno fila)
         collect (situacion.excel::lista
                  (list (string-downcase (symbol-name (nucleo:nombre marca)))
                        (string-downcase (symbol-name (nucleo:severidad marca)))
                        (situacion.excel::lista
                         (mapcar (lambda (c) (string-downcase (symbol-name c)))
                                 (nucleo:campos-marcados entorno fila marca))))))))

(defun escribir-esperado (situacion datos destino)
  "Los valores que el evaluador de referencia calcula, por coleccion y fila.

   Una relacion uno a muchos se escribe como CUANTAS filas trae. Su contenido
   lo presenta cada arquitectura a su manera -la hoja de calculo en una hoja
   auxiliar, la pagina como una lista-, pero el numero es el mismo en todas y
   es lo que se puede comparar.

   Cada fila sale como [valores, marcas, estado, marcados]: el estado es el
   texto que las arquitecturas tienen que escribir en su columna de estado, y
   MARCADOS dice que campos pinta cada marca (CAMPOS-MARCADOS-ESPERADOS).

   Se reutiliza el serializador de la arquitectura de Excel porque es el que
   hay; no es una dependencia del nucleo, solo una comodidad de esta
   demostracion."
  (let* ((evaluado (nucleo:evaluar-situacion situacion datos))
         (entorno (nucleo:hacer-entorno situacion datos))
         (relaciones (campos-de-relacion situacion)))
    (situacion.excel::escribir-plano
     (loop for (coleccion . filas) in evaluado
           for filas-del-entorno = (nucleo:filas-de entorno coleccion)
           collect (cons (string-downcase (symbol-name coleccion))
                         (or (loop for fila in filas
                                   for fila-del-entorno in filas-del-entorno
                                   collect (list
                                            (loop for (campo . valor) in (car fila)
                                                  collect (cons (string-downcase
                                                                 (symbol-name campo))
                                                                (if (member campo relaciones)
                                                                    (length valor)
                                                                    valor)))
                                            (situacion.excel::lista
                                             (mapcar (lambda (m)
                                                       (string-downcase (symbol-name m)))
                                                     (cdr fila)))
                                            (nucleo:texto-de-estado entorno fila-del-entorno)
                                            (campos-marcados-esperados entorno
                                                                       fila-del-entorno)))
                             :lista-vacia)))
     destino)))

(defun escribir-fila-nueva (situacion datos fila-nueva destino)
  "El oraculo de la sonda de orden: la fila que se anade y como tiene que
   quedar su coleccion entera despues, segun el evaluador.

   FILA-NUEVA es (\"coleccion\" . FILA). El evaluador la recibe con los demas
   datos y la ordena con el :ORDEN de la coleccion, asi que ESPERADO trae las
   filas en el orden en que la pagina tiene que dejarlas tras reordenar, con
   sus campos calculados."
  (let* ((coleccion (nucleo:nombrar (car fila-nueva)))
         (con-la-nueva (loop for (nombre . filas) in datos
                             collect (cons nombre (if (eq nombre coleccion)
                                                      (append filas (list (cdr fila-nueva)))
                                                      filas))))
         (evaluado (cdr (assoc coleccion (nucleo:evaluar-situacion situacion con-la-nueva))))
         (texto (lambda (s) (string-downcase (symbol-name s)))))
    (situacion.excel::escribir-plano
     (list (cons "coleccion" (car fila-nueva))
           (cons "valores" (loop for (campo . valor) in (cdr fila-nueva)
                                 collect (cons (funcall texto campo) valor)))
           (cons "orden" (situacion.excel::lista
                          (mapcar texto (nucleo:orden (nucleo:coleccion-llamada
                                                       situacion coleccion)))))
           (cons "esperado" (situacion.excel::lista
                             (loop for fila in evaluado
                                   collect (loop for (campo . valor) in (car fila)
                                                 collect (cons (funcall texto campo) valor))))))
     destino)))

(defun generar-todo ()
  (generar situacion.corpus:plan-del-grupo
           situacion.corpus:datos-del-plan
           "plan-del-grupo")
  (generar situacion.corpus:defensas-de-tesis
           situacion.corpus:datos-de-las-defensas
           "defensas-de-tesis")
  (generar situacion.corpus:horario-del-grupo
           situacion.corpus:datos-del-horario
           "horario-del-grupo")
  (generar situacion.corpus:departamento
           situacion.corpus:datos-del-departamento
           "departamento")
  (generar situacion.corpus:horario-saul
           situacion.corpus:datos-del-saul
           "horario-saul")
  (generar situacion.corpus:seder
           situacion.corpus:datos-del-seder
           "seder")
  (format t "~&~%Todo en ~a~%" (truename +salida+))
  t)

(defun generar-casos ()
  "Genera los casos de prueba de robustez (pruebas/casos/), con el prefijo de
   cada uno, igual que GENERAR-TODO genera el corpus.

   Un caso que no se puede generar no detiene a los demas: se dice cual y
   por que, y al final se devuelve NIL para que quien llame falle. Callarlo
   haria que la bateria verificara solo los casos que si salieron."
  (let ((fallidos '()))
    (dolist (caso situacion.casos:*casos*)
      (handler-case
          (progn
            (generar (situacion.casos:caso-situacion caso)
                     (situacion.casos:caso-datos caso)
                     (situacion.casos:caso-prefijo caso))
            (when (situacion.casos:caso-fila-nueva caso)
              (escribir-fila-nueva (situacion.casos:caso-situacion caso)
                                   (situacion.casos:caso-datos caso)
                                   (situacion.casos:caso-fila-nueva caso)
                                   (ruta (format nil "~a-fila-nueva.json"
                                                 (situacion.casos:caso-prefijo caso))))
              (format t "Generado salida/~a-fila-nueva.json  (oraculo de la sonda de orden)~%"
                      (situacion.casos:caso-prefijo caso))))
        (error (e)
          (push (situacion.casos:caso-prefijo caso) fallidos)
          (format t "~&FALLO AL GENERAR ~a: ~a~%" (situacion.casos:caso-prefijo caso) e))))
    (format t "~&~%Casos: ~d registrados, ~d fallidos~@[ (~{~a~^, ~})~]~%"
            (length situacion.casos:*casos*) (length fallidos) (reverse fallidos))
    (null fallidos)))
