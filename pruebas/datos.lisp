;;;; Pruebas de que los datos no se tiran en silencio.
;;;;
;;;; Antes, una coleccion o un campo de los datos que la situacion no
;;;; declaraba se ignoraba: la tabla salia vacia y todo daba verde. Asi se
;;;; pudrieron los experimentos de exploracion/ durante semanas.

(in-package #:situacion.pruebas)

(defun falla-al-cargar-p (datos)
  "Cierto si cargar DATOS en PLAN-DEL-GRUPO falla con un error del nucleo."
  (handler-case (progn (nucleo:hacer-entorno
                        (situacion.lenguaje:situacion-llamada "PLAN-DEL-GRUPO") datos)
                       nil)
    (nucleo:error-de-evaluacion () t)))

(definir-prueba datos-coleccion-desconocida-falla
    "Datos: una coleccion que la situacion no declara es un error, no una tabla vacia"
  (comprobar (falla-al-cargar-p (list (cons (nucleo:nombrar "asignatura") '())))
             "ASIGNATURA (sin S) no existe y tendria que fallar"))

(definir-prueba datos-campo-desconocido-falla
    "Datos: un campo que la coleccion no declara es un error"
  (comprobar (falla-al-cargar-p
              (list (cons (nucleo:nombrar "asignaturas")
                          (list (list (cons (nucleo:nombrar "abreviatura") "AL"))))))
             "ABREVIATURA no es un campo de ASIGNATURAS y tendria que fallar"))

(definir-prueba datos-campo-derivado-falla
    "Datos: un valor escrito para un campo derivado es un error"
  (comprobar (falla-al-cargar-p
              (list (cons (nucleo:nombrar "asignaturas")
                          (list (list (cons (nucleo:nombrar "abrev") "AL")
                                      (cons (nucleo:nombrar "faltan") 3))))))
             "FALTAN es derivado y no se puede escribir"))

(definir-prueba datos-del-corpus-se-cargan
    "Datos: los datos del corpus casan con sus descripciones"
  (dolist (caso (situaciones-de-conformidad))
    (destructuring-bind (nombre situacion datos) caso
      (comprobar (handler-case (progn (nucleo:hacer-entorno situacion datos) t)
                   (error () nil))
                 "los datos de ~a no casan con su descripcion" nombre))))
