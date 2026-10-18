;;;; Pruebas de la marca por campo (fase 2, hueco C7).
;;;;
;;;; Una marca :POR-CAMPO VARIABLE evalua su condicion (y su explicacion) una
;;;; vez por cada campo de :SOBRE, con VARIABLE ligada al valor de ese campo,
;;;; y solo pinta los campos donde se cumple. Hasta el 2026-10-18 una marca
;;;; pintaba siempre todo su :SOBRE: en las defensas del corpus salia en rojo
;;;; el oponente M. Ramirez, que no chocaba con nadie. El caso es
;;;; pruebas/casos/tribunales.lisp.

(in-package #:situacion.pruebas)

(defun situacion-de-tribunales ()
  (situacion.lenguaje:situacion-llamada "CASO-TRIBUNALES"))

(defun entorno-de-tribunales ()
  (nucleo:hacer-entorno (situacion-de-tribunales) (datos-del-caso "DATOS-DE-TRIBUNALES")))

(defun marca-llamada (situacion nombre)
  (find (nucleo:nombrar nombre) (nucleo:marcas situacion) :key #'nucleo:nombre))

(defun marcados-por-fila (nombre-de-marca)
  "Para cada citacion, en orden, los campos que pinta la marca."
  (let* ((entorno (entorno-de-tribunales))
         (marca (marca-llamada (situacion-de-tribunales) nombre-de-marca)))
    (mapcar (lambda (fila)
              (mapcar (lambda (c) (string-downcase (symbol-name c)))
                      (nucleo:campos-marcados entorno fila marca)))
            (nucleo:filas-de entorno (nucleo:nombrar "citaciones")))))

(definir-prueba marca-por-campo-pinta-solo-lo-que-choca
    "Marca por campo: con 0, 1 y 2 miembros que chocan, solo se pintan esos"
  (comprobar (equal (marcados-por-fila "en-dos-locales")
                    '(() () ("tutor") ("tutor") ("tutor" "oponente") ("tutor" "oponente")))
             "los campos pintados no son los esperados: ~s"
             (marcados-por-fila "en-dos-locales")))

(definir-prueba marca-normal-pinta-todo-su-sobre
    "Marca por campo: una marca sin :por-campo pinta todo su :sobre cuando dispara"
  (comprobar (equal (marcados-por-fila "sin-estudiante")
                    '(() () () () () ("estudiante")))
             "la marca normal tiene que pintar el estudiante del hueco: ~s"
             (marcados-por-fila "sin-estudiante")))

(definir-prueba marca-por-campo-explica-cada-campo
    "Marca por campo: el estado lleva una explicacion por campo que dispara"
  (let* ((entorno (entorno-de-tribunales))
         (estados (mapcar (lambda (f) (nucleo:texto-de-estado entorno f))
                          (nucleo:filas-de entorno (nucleo:nombrar "citaciones")))))
    (comprobar (equal (third estados) "P1 está en dos locales a la vez")
               "Caro: ~s" (third estados))
    (comprobar (equal (fifth estados)
                      "P1 está en dos locales a la vez; P2 está en dos locales a la vez")
               "Eva: ~s" (fifth estados))
    (comprobar (equal (sixth estados)
                      "P2 está en dos locales a la vez; P1 está en dos locales a la vez; Hueco sin defensa")
               "el hueco de las 11:00: ~s" (sixth estados))
    (comprobar (equal (first estados) "") "Ana no tiene ninguna marca: ~s" (first estados))))

(definir-prueba marca-por-campo-errores
    "Marca por campo: :por-campo tiene que ser un simbolo"
  (comprobar (handler-case
                 (progn (situacion.lenguaje::compilar-marca
                         '(marca m :sobre (a b) :por-campo "x" :cuando (vacio? x)))
                        nil)
               (error (e) (search ":POR-CAMPO" (string-upcase (princ-to-string e)))))
             ":por-campo \"x\" tiene que ser un error que nombre :POR-CAMPO")
  (comprobar (handler-case
                 (progn (situacion.lenguaje::compilar-expresion 'profesor) nil)
               (error () t))
             "la variable de una marca no existe fuera de ella"))

(definir-prueba marca-por-campo-en-la-hoja-de-calculo
    "Marca por campo: la hoja tiene un formato por campo, cada uno con su celda"
  (let* ((plano (plano-de (situacion-de-tribunales) (datos-del-caso "DATOS-DE-TRIBUNALES")))
         (hoja (hoja-de-coleccion plano "citaciones"))
         (formatos (remove-if-not (lambda (f) (equal (dato f "estado") "en-dos-locales"))
                                  (lista-del-plano (dato hoja "formatos_condicionales")))))
    (comprobar (= 3 (length formatos))
               "tiene que haber un formato por miembro del tribunal: ~d" (length formatos))
    (dolist (campo '("tutor" "oponente" "presidente"))
      (let* ((celda (celda-de-campo hoja campo 4))
             (letra (remove-if #'digit-char-p celda))
             (formato (find-if (lambda (f) (eql 0 (search letra (dato f "rango")))) formatos)))
        (comprobar (and formato (search celda (dato formato "formula")))
                   "el formato de ~a tiene que mirar su propia celda ~a: ~s"
                   campo celda formato)))))

(definir-prueba marca-por-campo-en-la-pagina
    "Marca por campo: la pagina evalua la condicion por campo"
  (let ((html (materializar-en-cadena (situacion.web:hacer-web) (situacion-de-tribunales)
                                      (datos-del-caso "DATOS-DE-TRIBUNALES"))))
    (comprobar (search "porCampo: true" html) "la marca tiene que decir porCampo: true")
    (comprobar (search "cond: (f, v_profesor) =>" html)
               "la condicion tiene que recibir el valor del campo")))

(definir-prueba marca-por-campo-en-el-oraculo
    "Marca por campo: el oraculo dice, por fila, que campos pinta cada marca"
  (let ((destino (merge-pathnames "situacion-esperado-tribunales.json"
                                  (uiop:temporary-directory))))
    (situacion.demostracion::escribir-esperado (situacion-de-tribunales)
                                               (datos-del-caso "DATOS-DE-TRIBUNALES") destino)
    (let ((texto (remove-if (lambda (c) (member c '(#\Space #\Newline)))
                            (texto-de-archivo destino))))
      (comprobar (search "{\"en-dos-locales\":[\"problema\",[\"tutor\",\"oponente\"]]}" texto)
                 "el oraculo tiene que decir que Eva tiene pintados tutor y oponente"))
    (delete-file destino)))
