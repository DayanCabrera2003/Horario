;;;; EXPLORACION: seguimiento de un presupuesto de proyecto.
;;;;
;;;; No es corpus. Es una sonda: un dominio que el corpus no pedia, escrito
;;;; en el lenguaje tal como esta, para medir donde llega y donde no.
;;;;
;;;; Lo que se quiere averiguar, aparte de lo obvio (partidas, gastos,
;;;; ejecutado, avisos):
;;;;
;;;;   1. UN TOTAL GENERAL. Un valor que no pertenece a ninguna fila. Se
;;;;      prueban las dos unicas formas que el lenguaje admite hoy: repetirlo
;;;;      en cada fila, y fabricar una coleccion de una sola fila.
;;;;
;;;;   2. UNA JERARQUIA. Partidas que son subpartidas de otras, con el gasto
;;;;      del padre sumando el de las hijas. Tres niveles a proposito, para
;;;;      que haga falta recursion de verdad y no baste una suma de hojas.
;;;;
;;;;   3. UN ACUMULADO. El saldo corrido del libro de gastos, que es
;;;;      recursion sobre la fila anterior.

(defpackage #:situacion.exploracion.presupuesto
  (:use #:common-lisp #:situacion.lenguaje)
  (:export #:presupuesto #:datos-del-presupuesto))

(in-package #:situacion.exploracion.presupuesto)

(defsituacion presupuesto (:etiqueta "Presupuesto y ejecucion de un proyecto")

  ;; El umbral del aviso es del dominio y se escribe una vez.
  (parametro umbral-aviso :tipo entero :valor 90 :etiqueta "Umbral de aviso")

  ;; ------------------------------------------------------------------
  ;; Las partidas, con jerarquia: PADRE es el codigo de la partida de la
  ;; que esta es subpartida. Vacio si es de primer nivel.
  ;; ------------------------------------------------------------------
  (coleccion partidas
    (:etiqueta "Partidas")
    (:clave codigo)
    (:orden codigo)
    (campo codigo    :rol fijo :etiqueta "Codigo")
    (campo concepto  :rol fijo :etiqueta "Concepto")
    (campo padre     :rol fijo :etiqueta "Subpartida de")

    (campo presupuestado :rol entrada :tipo numero :etiqueta "Presupuestado")

    ;; Lo gastado directamente contra esta partida.
    (campo gasto-directo :rol derivado :tipo numero :etiqueta "Gasto directo"
           (suma importe de gastos :donde (= partida (de fila codigo))))

    ;; Lo gastado en total: lo propio mas lo de las subpartidas. Esta es la
    ;; RECURSION: el campo se suma a si mismo en las filas hijas.
    (campo gastado :rol derivado :tipo numero :etiqueta "Gastado"
           (+ (de fila gasto-directo)
              (suma gastado de partidas :donde (= padre (de fila codigo)))))

    (campo queda :rol derivado :tipo numero :etiqueta "Queda"
           (- (de fila presupuestado) (de fila gastado)))

    (campo ejecutado :rol derivado :tipo entero :etiqueta "% ejecutado"
           (si (vacio? (de fila presupuestado))
               0
               (/ (* (de fila gastado) 100) (de fila presupuestado))))

    ;; EXPERIMENTO 1a: el total general repetido en cada fila. Cabe, pero
    ;; miente sobre a quien pertenece el valor.
    (campo total-del-proyecto :rol derivado :tipo numero
           :etiqueta "Gasto total (todas)"
           (suma importe de gastos))

    (:datos (("1000" "Proyecto completo"     "")
             ("1100" "Equipamiento"          "1000")
             ("1110" "Computadoras"          "1100")
             ("1120" "Mobiliario"            "1100")
             ("1200" "Personal"              "1000")
             ("1300" "Viajes"                "1000"))))

  ;; ------------------------------------------------------------------
  ;; El libro de gastos. Crece: siempre aparece un gasto mas.
  ;; ------------------------------------------------------------------
  (coleccion gastos
    (:etiqueta "Gastos")
    (:clave fecha partida)
    (:orden fecha)
    (:crece)
    (campo fecha :rol fijo :etiqueta "Fecha")

    (campo partida :rol entrada :etiqueta "Partida"
           :dominio   (los codigo de partidas)
           :al-violar advertir)

    (campo importe :rol entrada :tipo numero :etiqueta "Importe")

    ;; El concepto se trae solo de la partida imputada.
    (campo concepto :rol derivado :etiqueta "Concepto"
           (el concepto de (la-fila-de partidas
                             :donde (= codigo (de fila partida)))
               :si-no ""))

    ;; EXPERIMENTO 3: saldo corrido. Recursion sobre la fila anterior.
    (campo acumulado :rol derivado :tipo numero :etiqueta "Acumulado"
           (+ (de fila importe) (de (anterior fila) acumulado)))

    (:datos (("2026-01-15")
             ("2026-02-03")
             ("2026-02-20")
             ("2026-03-05")
             ("2026-03-18"))))

  ;; ------------------------------------------------------------------
  ;; EXPERIMENTO 1b: el total general como coleccion de una sola fila.
  ;; La fila no existe en el dominio: hay que inventarla para tener donde
  ;; colgar los valores.
  ;; ------------------------------------------------------------------
  (coleccion resumen
    (:etiqueta "Total del proyecto")
    (:clave titulo)
    (campo titulo :rol fijo :etiqueta "Concepto")

    ;; Solo las partidas de primer nivel, para no contar dos veces.
    (campo total-presupuestado :rol derivado :tipo numero
           :etiqueta "Presupuesto total"
           (suma presupuestado de partidas :donde (= padre "")))

    (campo total-gastado :rol derivado :tipo numero :etiqueta "Gasto total"
           (suma importe de gastos))

    (campo total-disponible :rol derivado :tipo numero :etiqueta "Disponible"
           (- (de fila total-presupuestado) (de fila total-gastado)))

    (campo cuantos-gastos :rol derivado :tipo entero :etiqueta "Num. de gastos"
           (cuantas gastos))

    (:datos (("Proyecto completo"))))

  ;; ------------------------------------------------------------------
  ;; Las marcas.
  ;; ------------------------------------------------------------------
  (marca sobrepasada
    :en        partidas
    :cuando    (> (de fila gastado) (de fila presupuestado))
    :sobre     (concepto gastado queda ejecutado)
    :severidad problema
    :explica   (texto "Se paso del presupuesto en "
                      (- (de fila gastado) (de fila presupuestado))))

  (marca al-limite
    :en        partidas
    :cuando    (y (>= (de fila ejecutado) (parametro umbral-aviso))
                  (<= (de fila gastado) (de fila presupuestado)))
    :sobre     (ejecutado)
    :severidad advertencia
    :explica   (texto "Lleva ejecutado el " (de fila ejecutado) " por ciento"))

  (marca sin-imputar
    :en        gastos
    :cuando    (vacio? (de fila partida))
    :sobre     (partida)
    :severidad informativa
    :explica   "Este gasto todavia no esta imputado a ninguna partida")

  (marca proyecto-sobregirado
    :en        resumen
    :cuando    (< (de fila total-disponible) 0)
    :sobre     (total-disponible)
    :severidad problema
    :explica   "El proyecto entero se paso del presupuesto")

  (vista ejecucion :de partidas :entrada t :etiqueta "Ejecucion por partida")
  (vista libro     :de gastos   :etiqueta "Libro de gastos")
  (vista total     :de resumen  :etiqueta "Total del proyecto"))

;;; ---------------------------------------------------------------------
;;; Los datos de prueba.
;;;
;;; Los porcentajes salen enteros a proposito: el lenguaje no tiene redondeo
;;; y un cociente no exacto se quedaria como fraccion.
;;; ---------------------------------------------------------------------

(defparameter datos-del-presupuesto
  (let ((n (lambda (s) (intern (string-upcase s) '#:situacion.nucleo))))
    (list
     (cons (funcall n "partidas")
           (loop for (codigo concepto padre presupuestado)
                   in '(("1000" "Proyecto completo" ""     20000)
                        ("1100" "Equipamiento"      "1000"  8000)
                        ("1110" "Computadoras"      "1100"  6000)
                        ("1120" "Mobiliario"        "1100"  2000)
                        ("1200" "Personal"          "1000" 10000)
                        ("1300" "Viajes"            "1000"  2000))
                 collect (list (cons (funcall n "codigo") codigo)
                               (cons (funcall n "concepto") concepto)
                               (cons (funcall n "padre") padre)
                               (cons (funcall n "presupuestado") presupuestado))))
     (cons (funcall n "gastos")
           (loop for (fecha partida importe)
                   in '(("2026-01-15" "1110" 5800)
                        ("2026-02-03" "1120" 2400)
                        ("2026-02-20" "1200" 9600)
                        ("2026-03-05" "1300"  600)
                        ("2026-03-18" "1110"  200))
                 collect (list (cons (funcall n "fecha") fecha)
                               (cons (funcall n "partida") partida)
                               (cons (funcall n "importe") importe))))
     ;; La fila inventada del resumen. Si no se escribe aqui, la coleccion
     ;; queda vacia y el total no se calcula nunca.
     (cons (funcall n "resumen")
           (list (list (cons (funcall n "titulo") "Proyecto completo"))))))
  "Seis partidas en tres niveles, cinco gastos y la fila inventada del total.")

;;; ---------------------------------------------------------------------
;;; Una situacion minima para sondear una sola construccion: un agregado
;;; cuya condicion no es una igualdad ("cuanto se lleva gastado en gastos
;;; grandes"). El lenguaje la admite; la pregunta es que hace cada destino.
;;; ---------------------------------------------------------------------

(defsituacion sonda-desigualdad (:etiqueta "Sonda: agregado con desigualdad")
  (coleccion apuntes
    (:etiqueta "Apuntes")
    (:clave fecha)
    (campo fecha   :rol fijo :etiqueta "Fecha")
    (campo importe :rol entrada :tipo numero :etiqueta "Importe")
    (campo grandes :rol derivado :tipo numero :etiqueta "Suma de los grandes"
           (suma importe de apuntes :donde (> importe 1000)))
    (:datos (("2026-01-15") ("2026-02-03"))))
  (vista unica :de apuntes :entrada t :etiqueta "Apuntes"))

(defparameter datos-de-la-sonda
  (let ((n (lambda (s) (intern (string-upcase s) '#:situacion.nucleo))))
    (list (cons (funcall n "apuntes")
                (loop for (fecha importe) in '(("2026-01-15" 5800) ("2026-02-03" 200))
                      collect (list (cons (funcall n "fecha") fecha)
                                    (cons (funcall n "importe") importe)))))))

;;; ---------------------------------------------------------------------
;;; La ejecucion.
;;; ---------------------------------------------------------------------

(defparameter +salida+ #p"exploracion/salida/")

(defun ruta (nombre) (merge-pathnames nombre +salida+))

(defun raya (&optional (c #\=))
  (format t "~&~a~%" (make-string 70 :initial-element c)))

(defun mostrar-analisis ()
  (raya)
  (format t "1. ANALISIS ESTATICO~%")
  (raya)
  (let ((problemas (situacion.analisis:comprobar-situacion presupuesto)))
    (if problemas
        (format t "~d problema(s):~%~a" (length problemas)
                (situacion.analisis:informe-de-problemas problemas))
        (format t "Sin problemas.~%"))))

(defun mostrar-evaluacion ()
  (raya)
  (format t "2. EVALUADOR DE REFERENCIA~%")
  (raya)
  (dolist (par (nucleo:evaluar-situacion presupuesto datos-del-presupuesto))
    (format t "~%~(~a~)~%" (car par))
    (dolist (fila (cdr par))
      (format t "  ~{~(~a~)=~a~^  ~}~@[   [marcas: ~{~(~a~)~^, ~}]~]~%"
              (loop for (campo . valor) in (car fila)
                    append (list campo (nucleo:como-texto valor)))
              (cdr fila)))))

(defun mostrar-requerimientos ()
  (raya)
  (format t "3. CAPACIDADES QUE PIDE LA DESCRIPCION~%")
  (raya)
  (dolist (r (protocolo:requerimientos presupuesto))
    (format t "  ~(~28a~) ~a~%" (first r) (third r))))

(defun materializar-en (arquitectura nombre)
  (handler-case
      (multiple-value-bind (destino informe)
          (protocolo:materializar arquitectura presupuesto datos-del-presupuesto
                                  (ruta nombre))
        (format t "~&Generado ~a~%" destino)
        (protocolo:escribir-informe informe))
    (error (e)
      (format t "~&FALLO al materializar ~a:~%  ~a~%" nombre e))))

(defun ejecutar ()
  (ensure-directories-exist +salida+)
  (mostrar-analisis)
  (mostrar-evaluacion)
  (mostrar-requerimientos)
  (raya)
  (format t "4. LAS TRES ARQUITECTURAS~%")
  (raya)
  (materializar-en (situacion.texto:hacer-texto) "presupuesto.txt")
  (materializar-en (situacion.excel:hacer-excel) "presupuesto-plano.json")
  (materializar-en (situacion.web:hacer-web) "presupuesto.html")
  ;; El oraculo, en el mismo formato que usa la demostracion del corpus.
  (let ((evaluado (nucleo:evaluar-situacion presupuesto datos-del-presupuesto)))
    (situacion.excel::escribir-plano
     (loop for (coleccion . filas) in evaluado
           collect (cons (string-downcase (symbol-name coleccion))
                         (or (loop for fila in filas
                                   collect (cons (loop for (campo . valor) in (car fila)
                                                       collect (cons (string-downcase
                                                                      (symbol-name campo))
                                                                     valor))
                                                 nil))
                             :lista-vacia)))
     (ruta "presupuesto-esperado.json")))
  (format t "~&Generado el oraculo en exploracion/salida/presupuesto-esperado.json~%")
  (sondas-negativas)
  t)

;;; ---------------------------------------------------------------------
;;; Sondas negativas: lo que se intento escribir y el lenguaje no admite.
;;;
;;; Se ejecutan de verdad y se imprime el mensaje exacto, para no tener que
;;; creerse ninguna afirmacion sobre lo que falta.
;;; ---------------------------------------------------------------------

(defun sonda (rotulo pensamiento)
  (format t "~&~%  ~a~%    ~s~%    -> " rotulo pensamiento)
  (handler-case
      (let ((r (funcall (lambda () (lenguaje:compilar-expresion pensamiento)))))
        (format t "COMPILA (~a)~%" (first r)))
    (error (e) (format t "RECHAZA: ~a~%" e))))

(defun sondas-negativas ()
  (raya)
  (format t "5. SONDAS NEGATIVAS~%")
  (raya)

  (sonda "Redondear un porcentaje" '(redondear (/ 100 3)))
  (sonda "Truncar un porcentaje"   '(entero-de (/ 100 3)))
  (sonda "Valor absoluto"          '(absoluto (- 0 5)))
  (sonda "Promedio de una columna" '(promedio importe de gastos))
  (sonda "Agregado con condicion que no es una igualdad"
         '(suma importe de gastos :donde (> importe 1000)))
  (sonda "Sumar una expresion en vez de un campo"
         '(suma (* importe 2) de gastos))
  (sonda "Profundidad en la jerarquia (cuantos antepasados tiene)"
         '(cuantos-antepasados de fila))

  ;; Un parametro cuyo valor fuera una expresion del dominio.
  (format t "~&~%  Parametro cuyo valor es un agregado~%")
  (format t "    (parametro total :valor (suma importe de gastos))~%    -> ")
  (handler-case
      (progn (eval '(lenguaje::compilar-parametro
                     '(parametro total :tipo numero
                       :valor (suma importe de gastos))))
             (format t "COMPILA la forma; se evalua como codigo Lisp al cargar~%"))
    (error (e) (format t "RECHAZA: ~a~%" e)))

  ;; Un agregado con condicion de desigualdad: el lenguaje lo admite, pero
  ;; hay que ver si las tres arquitecturas saben emitirlo.
  (format t "~&~%  Agregado con desigualdad, contra las tres arquitecturas~%")
  (dolist (par (list (cons "texto" (situacion.texto:hacer-texto))
                     (cons "excel" (situacion.excel:hacer-excel))
                     (cons "web"   (situacion.web:hacer-web))))
    (format t "    ~8a -> " (car par))
    (handler-case
        (progn (protocolo:materializar (cdr par) sonda-desigualdad
                                       datos-de-la-sonda
                                       (ruta (format nil "sonda-~a.out" (car par))))
               (format t "emite~%"))
      (error (e) (format t "FALLA: ~a~%" e))))

  ;; Una marca sin campos sobre los que senalar: el total no tiene columna.
  (format t "~&~%  Marca sobre la situacion entera, sin campos~%")
  (format t "    (marca sobregirado :cuando (> (suma importe de gastos) 100))~%    -> ")
  (handler-case
      (progn (eval '(lenguaje::compilar-marca
                     '(marca sobregirado
                       :cuando (> (suma importe de gastos) 100)
                       :severidad problema)))
             (format t "COMPILA~%"))
    (error (e) (format t "RECHAZA: ~a~%" e))))

(ejecutar)
