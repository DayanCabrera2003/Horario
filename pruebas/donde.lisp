;;;; Pruebas de la regla unica de :DONDE (fase 2, hueco C4).
;;;;
;;;; Dentro de un :DONDE, un simbolo suelto es un campo de la fila que ese
;;;; :DONDE filtra: la candidata en LA-FILA-DE y en los agregados, la variable
;;;; de un EXISTE y la fila de una vista. Manda el :DONDE mas interior. Hasta
;;;; el 2026-10-18 solo valia en las busquedas y los agregados; en EXISTE y en
;;;; las vistas era un error que decia "fuera de un :DONDE" estando dentro.
;;;; La forma corta tiene que dar EXACTAMENTE el mismo arbol que la larga.

(in-package #:situacion.pruebas)

(defun compila (forma)
  (situacion.lenguaje::compilar-expresion forma))

(definir-prueba donde-existe-forma-corta
    "Donde: en un EXISTE, un simbolo suelto es un campo de su variable"
  (comprobar (equal (compila '(existe otra :en citaciones :distinta-de fila
                               :donde (y (= dia (de fila dia)) (= momento (de fila momento)))))
                    (compila '(existe otra :en citaciones :distinta-de fila
                               :donde (y (= (de otra dia) (de fila dia))
                                         (= (de otra momento) (de fila momento))))))
             "la forma corta del EXISTE tiene que dar el mismo arbol que la larga"))

(definir-prueba donde-vista-forma-corta
    "Donde: en el :donde de una vista, un simbolo suelto es un campo de la fila"
  (comprobar (equal (situacion.lenguaje::compilar-vista
                     '(vista v :de reuniones :filas hora :columnas dia :muestra sala
                       :donde (no (vacio? asunto))))
                    (situacion.lenguaje::compilar-vista
                     '(vista v :de reuniones :filas hora :columnas dia :muestra sala
                       :donde (no (vacio? (de fila asunto))))))
             "la forma corta de la vista tiene que dar el mismo arbol que la larga"))

(definir-prueba donde-busqueda-sin-cambios
    "Donde: en una busqueda, un simbolo suelto sigue siendo la candidata"
  (comprobar (search "CANDIDATA"
                     (prin1-to-string (compila '(la-fila-de tesis :donde (= estudiante 1)))))
             "en LA-FILA-DE el simbolo suelto tiene que ser la candidata"))

(definir-prueba donde-manda-el-mas-interior
    "Donde: con :donde anidados, un simbolo suelto es del mas interior"
  (comprobar (equal (compila '(cuantas casillas
                               :donde (existe o :en profesores :donde (= nombre profesor))))
                    (compila '(cuantas casillas
                               :donde (existe o :en profesores
                                       :donde (= (de o nombre) (de o profesor))))))
             "dentro del EXISTE, nombre y profesor son de O, no de la candidata del CUANTAS")
  (comprobar (equal (compila '(existe o :en profesores
                               :donde (= nombre (el x de (la-fila-de y :donde (= z 1))))))
                    (compila '(existe o :en profesores
                               :donde (= (de o nombre)
                                         (el x de (la-fila-de y :donde (= z 1)))))))
             "dentro de una busqueda anidada en un EXISTE, Z es de la candidata"))

(definir-prueba donde-error-fuera-dice-donde
    "Donde: un simbolo suelto fuera de todo :donde es error, y dice donde esta"
  (let ((mensaje (handler-case
                     (progn (macroexpand-1
                             '(situacion.lenguaje:defsituacion s-fuera ()
                               (coleccion personas
                                (campo horas :rol fijo :tipo entero)
                                (campo doble :rol derivado :tipo entero (* horas 2)))))
                            nil)
                   (error (e) (princ-to-string e)))))
    (comprobar (and mensaje (search "HORAS" (string-upcase mensaje))
                    (search "el campo doble de personas" mensaje)
                    (search "fuera de todo :DONDE" mensaje))
               "el error tiene que nombrar el simbolo, el campo y la coleccion: ~a" mensaje))
  (let ((mensaje (handler-case
                     (progn (situacion.lenguaje::compilar-marca
                             '(marca alta :sobre (horas) :cuando (> horas 40)))
                            nil)
                   (error (e) (princ-to-string e)))))
    (comprobar (and mensaje (search "la marca alta" mensaje))
               "el error en una marca tiene que nombrar la marca: ~a" mensaje)))
