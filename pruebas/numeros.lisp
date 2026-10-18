;;;; Pruebas de los numeros y los booleanos.
;;;;
;;;; La auditoria del 2026-10-17 encontro tres formas de escribir el mismo
;;;; promedio (157/3 en el texto, 52.3333333333333 en la hoja de calculo y
;;;; 52.333333333333336 en la pagina), un 3.6000001 por leer 1.2 como
;;;; flotante simple, un oraculo que no era JSON valido, y el falso escrito
;;;; como "", FALSE y false segun el destino.

(in-package #:situacion.pruebas)

(definir-prueba numeros-regla-de-presentacion
    "Numeros: hasta 10 cifras significativas, sin ceros a la derecha"
  (loop for (valor esperado) in '((157/3 "52.33333333") (3 "3") (3.0d0 "3")
                                  (2.5d0 "2.5") (0 "0") (-1/4 "-0.25"))
        do (comprobar (string= (nucleo:texto-de-numero valor) esperado)
                      "~s se escribe ~s y no ~s" valor (nucleo:texto-de-numero valor)
                      esperado))
  (comprobar (string= (nucleo:como-texto (* 3 (nucleo:normalizar-numero 1.2))) "3.6")
             "3 por 1.2 tiene que escribirse 3.6"))

(definir-prueba numeros-division-da-doble
    "Numeros: la division da un doble, nunca un racional; por cero da vacio"
  (let ((cociente (nucleo::aplicar-operador (nucleo:nombrar "/") '(157 3))))
    (comprobar (typep cociente 'double-float)
               "157 entre 3 tiene que ser un doble, y es ~s" cociente))
  (comprobar (null (nucleo::aplicar-operador (nucleo:nombrar "/") '(1 0)))
             "dividir por cero tiene que dar vacio"))

(definir-prueba numeros-oraculo-es-json-valido
    "Numeros: el oraculo escribe los numeros sin fracciones ni sufijos de Lisp"
  (let ((destino (merge-pathnames "situacion-oraculo-notas.json"
                                  (uiop:temporary-directory))))
    (situacion.demostracion::escribir-esperado
     (situacion.lenguaje:situacion-llamada "CASO-NOTAS") (datos-del-caso "DATOS-DE-NOTAS")
     destino)
    (let ((texto (texto-de-archivo destino)))
      (comprobar (not (search "/3" texto)) "el oraculo escribe una fraccion")
      (comprobar (not (search "d0" texto)) "el oraculo escribe un doble con sufijo de Lisp")
      (comprobar (search "52.333333333333336" texto)
                 "el promedio de Lia tiene que salir con todas sus cifras"))
    (delete-file destino)))

(definir-prueba booleanos-son-si-y-no
    "Booleanos: un campo que es una comparacion vale \"si\" o \"no\" en las tres"
  (let* ((s (situacion.lenguaje:situacion-llamada "CASO-NOTAS"))
         (d (datos-del-caso "DATOS-DE-NOTAS"))
         (evaluado (nucleo:evaluar-situacion s d))
         (tardes (mapcar (lambda (fila) (cdr (assoc (nucleo:nombrar "tarde") (car fila))))
                         (cdr (assoc (nucleo:nombrar "estudiantes") evaluado)))))
    (comprobar (every (lambda (v) (member v '("si" "no") :test #'equal)) tardes)
               "el evaluador tiene que dar \"si\" o \"no\": ~s" tardes)
    (let ((html (materializar-en-cadena (situacion.web:hacer-web) s d)))
      (comprobar (search "\"tarde\": (f) => BOOL(" html)
                 "la pagina tiene que convertir el campo booleano con BOOL"))
    (let* ((plano (plano-de s d))
           (formula (formula-de-celda (hoja-de-coleccion plano "estudiantes") "K4")))
      (comprobar (and formula (search "\"si\",\"no\")" formula))
                 "la hoja de calculo tiene que escribir \"si\" o \"no\": ~a" formula))))

(definir-prueba booleanos-no-es-falso-en-una-condicion
    "Booleanos: un campo que vale \"no\" cuenta como falso en una condicion"
  (comprobar (not (nucleo:verdadero-p "no")) "\"no\" tiene que ser falso")
  (comprobar (nucleo:verdadero-p "si") "\"si\" tiene que ser verdadero")
  (comprobar (nucleo:iguales-p t "si") "el literal T tiene que valer lo mismo que \"si\""))
