;;;; Pruebas de la relacion uno-a-muchos en Excel (H4).

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion carga-de-profesores (:etiqueta "Carga de profesores")
  (coleccion profesores
    (:clave nombre)
    (campo nombre :rol fijo :etiqueta "Profesor")
    (campo asignaciones :rol derivado :etiqueta "Asignaturas que imparte"
           (las-filas-de asignacion :donde (= profesor (de fila nombre))))
    (:datos (("Rosa") ("Julia") ("Pedro"))))
  (coleccion asignacion
    (:clave profesor grupo abrev)
    (campo profesor :rol fijo :etiqueta "Profesor")
    (campo grupo    :rol fijo :etiqueta "Grupo")
    (campo abrev    :rol fijo :etiqueta "Asignatura")
    (:datos (("Rosa" "10-A" "MAT") ("Rosa" "10-B" "MAT") ("Rosa" "10-A" "ING")
             ("Julia" "10-A" "ESP") ("Julia" "10-B" "ESP") ("Julia" "10-A" "HIST")
             ("Julia" "10-B" "HIST") ("Julia" "10-A" "HIST2"))))
  (vista docentes :de profesores :entrada t :etiqueta "Profesores"))

(defun situacion-de-carga () (situacion.lenguaje:situacion-llamada "CARGA-DE-PROFESORES"))

(defparameter *datos-de-carga*
  (list (cons (nucleo:nombrar "profesores")
              (loop for p in '("Rosa" "Julia" "Pedro")
                    collect (list (cons (nucleo:nombrar "nombre") p))))
        (cons (nucleo:nombrar "asignacion")
              (loop for (p g a) in '(("Rosa" "10-A" "MAT") ("Rosa" "10-B" "MAT")
                                     ("Rosa" "10-A" "ING")
                                     ("Julia" "10-A" "ESP") ("Julia" "10-B" "ESP")
                                     ("Julia" "10-A" "HIST") ("Julia" "10-B" "HIST")
                                     ("Julia" "10-A" "HIST2"))
                    collect (list (cons (nucleo:nombrar "profesor") p)
                                  (cons (nucleo:nombrar "grupo") g)
                                  (cons (nucleo:nombrar "abrev") a))))))

;; Nota: la reserva por defecto es 5. Rosa tiene 3 relacionadas y Julia 5:
;; las dos caben dentro de la reserva, asi que esta situacion prueba el caso
;; normal sin desbordar. El caso de desborde va en la prueba de mas abajo,
;; con reserva mas baja a proposito.

(definir-prueba con-relacion-uno-a-muchos-ya-no-se-rechaza
    "H4: la hoja de calculo emula la relacion uno-a-muchos, no la rechaza"
  (let ((informe (nth-value 1
                   (materializar-en-cadena (situacion.excel:hacer-excel)
                                           (situacion-de-carga) *datos-de-carga*))))
    (comprobar (search "emula" (string-downcase (format nil "~a" informe)))
               "el informe tiene que decir EMULA para la relacion uno-a-muchos,~@
                no RECHAZA")))

(definir-prueba con-relacion-uno-a-muchos-produce-formula-real
    "H4: la celda de la relacion lleva un COUNTIF, no el resultado de REQUERIR"
  (let ((destino "/tmp/carga-de-profesores-plano.json"))
    (protocolo:materializar (situacion.excel:hacer-excel) (situacion-de-carga)
                            *datos-de-carga* destino)
    (let ((contenido (with-open-file (f destino)
                       (let ((s (make-string (file-length f)))) (read-sequence s f) s))))
      (comprobar (search "COUNTIF" contenido)
                 "la celda de ASIGNACIONES tiene que llevar una formula COUNTIF~@
                  real, no lo que devuelva REQUERIR"))))

(definir-prueba con-reserva-de-relacion-no-positiva-se-rechaza
    "H4: RESERVA-DE-RELACION 0 o negativa senala error, no un plano corrupto"
  ;; Con CAPACIDAD 0, CELDAS-DE-AVISOS-LEGIBLES (excel/relacion.lisp) escribe
  ;; el aviso de desborde en la misma celda que ya lleva la clave del padre
  ;; -dos entradas "celda" para la misma direccion en el plano, sin que nada
  ;; lo note-, y con un valor negativo el aviso cae en el bloque de OTRA fila
  ;; padre. HACER-EXCEL tiene que rechazarlo antes de que llegue tan lejos.
  (flet ((senala-error-p (reserva)
           (handler-case (progn (situacion.excel:hacer-excel :reserva-de-relacion reserva)
                                 nil)
             (error () t))))
    (comprobar (senala-error-p 0)
               "(hacer-excel :reserva-de-relacion 0) deberia senalar error")
    (comprobar (senala-error-p -1)
               "(hacer-excel :reserva-de-relacion -1) deberia senalar error")))

(definir-prueba con-relacion-uno-a-muchos-avisa-el-desborde
    "H4: con mas relacionadas que reserva, la ultima linea avisa cuantas sobran"
  (let ((informe (nth-value 1
                   (materializar-en-cadena
                    (situacion.excel:hacer-excel :reserva-de-relacion 2)
                    (situacion-de-carga) *datos-de-carga*))))
    (comprobar informe "tiene que producir informe igual")))

;;; ---------------------------------------------------------------------
;;; La clave compuesta del padre
;;;
;;; CARGA-DE-PROFESORES no lo cubre: la clave de PROFESORES es solo NOMBRE,
;;; asi que "el primer campo de la clave" y "la clave entera" coinciden ahi
;;; por accidente. Hace falta una coleccion padre con clave compuesta, y dos
;;; filas que compartan el primer campo y difieran en el segundo, para que
;;; un COUNTIF que solo mirara el primer campo se note: contaria de mas.
;;; ---------------------------------------------------------------------

(situacion.lenguaje:defsituacion carga-por-turno (:etiqueta "Carga por turno")
  (coleccion turnos
    (:clave dia turno)
    (campo dia     :rol fijo :etiqueta "Dia")
    (campo turno   :rol fijo :etiqueta "Turno")
    (campo citados :rol derivado :etiqueta "Profesores citados"
           (las-filas-de citacion
            :donde (y (= dia (de fila dia)) (= turno (de fila turno)))))
    (:datos (("lunes" "1") ("lunes" "2") ("martes" "1"))))
  (coleccion citacion
    (:clave dia turno profesor)
    (campo dia      :rol fijo :etiqueta "Dia")
    (campo turno    :rol fijo :etiqueta "Turno")
    (campo profesor :rol fijo :etiqueta "Profesor")
    (:datos (("lunes" "1" "Rosa") ("lunes" "1" "Julia")
             ("lunes" "2" "Pedro")
             ("martes" "1" "Rosa") ("martes" "1" "Julia") ("martes" "1" "Pedro"))))
  (vista turnos-vista :de turnos :entrada t :etiqueta "Turnos"))

(defun situacion-de-turnos () (situacion.lenguaje:situacion-llamada "CARGA-POR-TURNO"))

(defparameter *datos-de-turnos*
  (list (cons (nucleo:nombrar "turnos")
              (loop for (d tu) in '(("lunes" "1") ("lunes" "2") ("martes" "1"))
                    collect (list (cons (nucleo:nombrar "dia") d)
                                  (cons (nucleo:nombrar "turno") tu))))
        (cons (nucleo:nombrar "citacion")
              (loop for (d tu p) in '(("lunes" "1" "Rosa") ("lunes" "1" "Julia")
                                      ("lunes" "2" "Pedro")
                                      ("martes" "1" "Rosa") ("martes" "1" "Julia")
                                      ("martes" "1" "Pedro"))
                    collect (list (cons (nucleo:nombrar "dia") d)
                                  (cons (nucleo:nombrar "turno") tu)
                                  (cons (nucleo:nombrar "profesor") p))))))

(defun formula-en-hoja (plano nombre-hoja celda)
  "La formula (cadena Lisp, tal cual la produce EMITIR-EXPRESION, sin pasar
   por JSON) de CELDA en la hoja NOMBRE-HOJA del plano nativo que devuelve
   CONSTRUIR-PLANO -no el texto que escribe ESCRIBIR-PLANO.

   No hay un lector de JSON en el proyecto (vease PRUEBAS/PARTICION-EN-
   ARCHIVO.LISP), y una formula con COUNTIF/VLOOKUP lleva comillas internas
   que complican buscarla como texto ya escrito; leer la estructura nativa
   antes de serializar evita los dos problemas."
  (let* ((hojas (cdr (assoc "hojas" plano :test #'string=)))
         (hoja (find nombre-hoja hojas
                     :key (lambda (h) (cdr (assoc "nombre" h :test #'string=)))
                     :test #'string=))
         (formulas (and hoja (cdr (assoc "formulas" hoja :test #'string=)))))
    (and (listp formulas)
         (let ((entrada (find celda formulas
                              :key (lambda (f) (cdr (assoc "celda" f :test #'string=)))
                              :test #'string=)))
           (and entrada (cdr (assoc "formula" entrada :test #'string=)))))))

(definir-prueba con-clave-compuesta-el-countif-cuenta-por-toda-la-clave
    "H4: con clave compuesta, el COUNTIF busca por todos los campos de la clave"
  ;; (lunes,1) y (lunes,2) comparten DIA y difieren en TURNO. Si el COUNTIF
  ;; buscara solo por DIA -el error que corrige esta prueba-, "lunes#*"
  ;; contaria las citaciones de las DOS filas para cada una de las dos: 2+1=3
  ;; en vez de 2 y 1.
  (let* ((a (situacion.excel:hacer-excel))
         (s (situacion-de-turnos))
         (plan (protocolo:planificar a s)))
    (setf (situacion.excel::entorno plan) (nucleo:hacer-entorno s *datos-de-turnos*))
    (let* ((plano (situacion.excel::construir-plano a plan))
           ;; DIA es la columna A, TURNO la B; TURNOS no declara :ORDEN, asi
           ;; que las filas salen en el orden de los datos: (lunes 1) es la
           ;; primera -> fila 4; (lunes 2), la segunda -> fila 5.
           (f-lunes-1 (formula-en-hoja plano "Turnos" "C4"))
           (f-lunes-2 (formula-en-hoja plano "Turnos" "C5")))
      (comprobar f-lunes-1 "no se encontro la formula de C4 en la hoja Turnos")
      (comprobar f-lunes-2 "no se encontro la formula de C5 en la hoja Turnos")
      (when (and f-lunes-1 f-lunes-2)
        (comprobar (search "$B4" f-lunes-1)
                   "el COUNTIF de (lunes,1) tiene que referenciar tambien TURNO~@
                    ($B4), no solo DIA -si no, cuenta tambien las citaciones de~@
                    (lunes,2): ~a" f-lunes-1)
        (comprobar (search "$B5" f-lunes-2)
                   "el COUNTIF de (lunes,2) tiene que referenciar tambien TURNO~@
                    ($B5), no solo DIA -si no, cuenta tambien las citaciones de~@
                    (lunes,1): ~a" f-lunes-2)))))
