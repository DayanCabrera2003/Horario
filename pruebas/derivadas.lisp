;;;; Pruebas de las colecciones derivadas (fase 2, hueco C8).
;;;;
;;;; (:una-fila-por CAMPO :de COLECCION) pone el valor de cada grupo en el
;;;; campo de la derivada que se llama igual. Hasta el 2026-10-18, si ese
;;;; campo no estaba declarado, el analisis solo avisaba y el evaluador ponia
;;;; el valor en el PRIMER campo de la coleccion, fuera cual fuera: un
;;;; descarte silencioso. Ahora es un error que dice como arreglarlo, y hay
;;;; dos comprobaciones mas del mismo tipo.

(in-package #:situacion.pruebas)

(situacion.lenguaje:defsituacion derivada-sin-agrupador (:etiqueta "Sin agrupador")
  (coleccion registros
    (:etiqueta "Registros")
    (:clave numero)
    (campo numero  :rol fijo :tipo entero :etiqueta "No.")
    (campo persona :rol fijo :etiqueta "Persona"))
  (coleccion personas
    (:una-fila-por persona :de registros)
    (:etiqueta "Personas")
    (campo total :rol derivado :tipo entero :etiqueta "Total"
           (cuantas registros)))
  (vista v :de personas :etiqueta "Personas"))

(situacion.lenguaje:defsituacion derivada-agrupador-calculado (:etiqueta "Agrupador calculado")
  (coleccion registros
    (:etiqueta "Registros")
    (:clave numero)
    (campo numero  :rol fijo :tipo entero :etiqueta "No.")
    (campo persona :rol fijo :etiqueta "Persona"))
  (coleccion personas
    (:una-fila-por persona :de registros)
    (:etiqueta "Personas")
    (campo persona :rol derivado :etiqueta "Persona" (texto "x")))
  (vista v :de personas :etiqueta "Personas"))

(situacion.lenguaje:defsituacion derivada-con-entrada (:etiqueta "Derivada con entrada")
  (coleccion registros
    (:etiqueta "Registros")
    (:clave numero)
    (campo numero  :rol fijo :tipo entero :etiqueta "No.")
    (campo persona :rol fijo :etiqueta "Persona"))
  (coleccion personas
    (:una-fila-por persona :de registros)
    (:etiqueta "Personas")
    (campo persona :rol fijo :etiqueta "Persona")
    (campo notas   :rol entrada :etiqueta "Notas")
    (campo alias   :rol fijo :etiqueta "Alias"))
  (coleccion resumen
    (:una-sola-fila)
    (:etiqueta "Resumen")
    (campo comentario :rol entrada :etiqueta "Comentario"))
  (vista v :de personas :etiqueta "Personas"))

(defun textos-de-error (nombre)
  (mapcar #'analisis:texto-de-problema
          (errores-de (situacion.lenguaje:situacion-llamada nombre))))

(definir-prueba derivada-sin-agrupador-es-error
    "Derivadas: sin el campo agrupador es un error que dice como declararlo"
  (let ((errores (textos-de-error "DERIVADA-SIN-AGRUPADOR")))
    (comprobar (some (lambda (e) (search "(campo persona :rol fijo" e)) errores)
               "el error tiene que sugerir (campo persona :rol fijo ...): ~s" errores)))

(definir-prueba derivada-agrupador-tiene-que-ser-fijo
    "Derivadas: el campo agrupador tiene que ser :rol fijo"
  (let ((errores (textos-de-error "DERIVADA-AGRUPADOR-CALCULADO")))
    (comprobar (some (lambda (e) (and (search "persona" e) (search ":rol fijo" e))) errores)
               "el error tiene que pedir que persona sea :rol fijo: ~s" errores)))

(definir-prueba derivada-sin-entrada-ni-otros-fijos
    "Derivadas: una coleccion derivada no tiene campos de entrada ni otros fijos"
  (let ((errores (textos-de-error "DERIVADA-CON-ENTRADA")))
    (dolist (campo '("notas" "alias" "comentario"))
      (comprobar (some (lambda (e) (search campo e)) errores)
                 "tiene que haber un error que nombre el campo ~a: ~s" campo errores))
    (comprobar (some (lambda (e) (search ":rol derivado" e)) errores)
               "el error tiene que decir que los demas campos son :rol derivado: ~s" errores)))

(definir-prueba derivada-bien-escrita-pasa
    "Derivadas: la de caso-horas declara su agrupador y pasa el analisis"
  (comprobar (null (errores-de (situacion.lenguaje:situacion-llamada "CASO-HORAS")))
             "caso-horas no puede tener errores de analisis"))

(definir-prueba derivada-sin-agrupador-no-reparte-al-primer-campo
    "Derivadas: el evaluador ya no pone el grupo en el primer campo"
  (comprobar (handler-case
                 (progn (nucleo:evaluar-situacion
                         (situacion.lenguaje:situacion-llamada "DERIVADA-SIN-AGRUPADOR")
                         (situacion.casos::datos
                          (list "registros" (situacion.casos::fila "numero" 1 "persona" "Ana"))))
                        nil)
               (error () t))
             "evaluar una derivada sin agrupador tiene que ser un error, no repartir el valor"))

(definir-prueba derivada-en-la-hoja-lo-dice
    "Derivadas: el informe de la hoja dice que una derivada no gana filas hasta regenerar"
  (multiple-value-bind (salida informe)
      (materializar-en-cadena (situacion.excel:hacer-excel)
                              (situacion.lenguaje:situacion-llamada "CASO-HORAS")
                              (datos-del-caso "DATOS-DE-HORAS"))
    (declare (ignore salida))
    (let ((entrada (find 'protocolo:con-agrupacion (protocolo:entradas-del-informe informe)
                         :key #'protocolo:entrada-de-informe-capacidad)))
      (comprobar (and entrada
                      (eq (protocolo:entrada-de-informe-respuesta entrada) :emula)
                      (search "crezca" (protocolo:entrada-de-informe-nota entrada))
                      (search "regenerar" (protocolo:entrada-de-informe-nota entrada)))
                 "la hoja tiene que decir emula y que, aunque el origen crezca, hay que regenerar"))))
