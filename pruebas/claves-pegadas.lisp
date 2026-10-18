;;;; Prueba estatica: ninguna clave del corpus ni de la bateria va pegada a mano.
;;;;
;;;; Hasta el 2026-10-17 la hoja de calculo solo buscaba por una igualdad, y
;;;; las descripciones lo rodeaban pegando dos campos en uno con "#" o "|"
;;;; ("10-3#M", "PIAD|EST-CC"). Desde la fase 2 (hueco C2) una busqueda puede
;;;; usar varios campos y una clave puede ser compuesta, asi que una clave
;;;; pegada es una limitacion vieja escrita en la descripcion. La limpieza de
;;;; C2 busco las que se construian con (texto ...) y se le escapo una que
;;;; venia escrita en los datos ("Central#T-01").
;;;;
;;;; Lo que delata una clave pegada no es el caracter, sino lo que hay a sus
;;;; lados: "Central#T-01" son el almacen y el codigo de esa misma fila. Un
;;;; valor que lleva "|" por si mismo ("Limpieza|Hogar", que la bateria usa a
;;;; proposito para probar separadores) no lo es. La prueba mira cada campo de
;;;; cada fila, derivados incluidos (el "PIAD|EST-CC" del departamento no era
;;;; clave, pero se usaba para buscar), y falla si un valor partido por "#" o
;;;; "|" da dos o mas trozos que son todos valores de otros campos de la fila.

(in-package #:situacion.pruebas)

(defun situaciones-con-datos ()
  "Cada situacion del corpus y de la bateria con sus datos, como lista de
   (NOMBRE SITUACION DATOS)."
  (append
   (list (list "plan-del-grupo" situacion.corpus:plan-del-grupo situacion.corpus:datos-del-plan)
         (list "defensas-de-tesis" situacion.corpus:defensas-de-tesis
               situacion.corpus:datos-de-las-defensas)
         (list "horario-del-grupo" situacion.corpus:horario-del-grupo
               situacion.corpus:datos-del-horario)
         (list "departamento" situacion.corpus:departamento
               situacion.corpus:datos-del-departamento)
         (list "horario-saul" situacion.corpus:horario-saul situacion.corpus:datos-del-saul)
         (list "seder" situacion.corpus:seder situacion.corpus:datos-del-seder))
   (mapcar (lambda (caso) (list (situacion.casos:caso-prefijo caso)
                                (situacion.casos:caso-situacion caso)
                                (situacion.casos:caso-datos caso)))
           situacion.casos:*casos*)))

(defun trozos (texto)
  "TEXTO partido por \"#\" y \"|\"."
  (loop with inicio = 0
        for fin = (position-if (lambda (c) (find c "#|")) texto :start inicio)
        collect (subseq texto inicio (or fin (length texto)))
        while fin
        do (setf inicio (1+ fin))))

(defun claves-pegadas (situacion datos)
  "Los valores que son otros campos de su fila pegados con \"#\" o \"|\",
   como lista de (COLECCION CAMPO VALOR). Mira las filas tal como las ve el
   evaluador: las de los datos, las escritas con (:DATOS ...) y los campos
   derivados ya calculados."
  (let ((entorno (nucleo:hacer-entorno situacion datos))
        (pegadas '()))
    (dolist (coleccion (nucleo:colecciones situacion) (nreverse pegadas))
      (dolist (fila (nucleo:filas-de entorno (nucleo:nombre coleccion)))
        (let ((valores (loop for campo in (nucleo:campos coleccion)
                             collect (cons (nucleo:nombre campo)
                                           (ignore-errors
                                            (nucleo:valor-de-campo entorno fila
                                                                   (nucleo:nombre campo)))))))
          (loop for (campo . valor) in valores
                for partes = (and (stringp valor) (trozos valor))
                when (and (rest partes)
                          (every (lambda (parte)
                                   (some (lambda (otro)
                                           (and (not (eq (car otro) campo))
                                                (nucleo:iguales-p (cdr otro) parte)))
                                         valores))
                                 partes))
                  do (push (list (nucleo:nombre coleccion) campo valor) pegadas)))))))

(definir-prueba ninguna-clave-pegada-a-mano
    "Claves: ningun valor del corpus ni de la bateria pega otros campos con \"#\" o \"|\""
  (dolist (entrada (situaciones-con-datos))
    (destructuring-bind (nombre situacion datos) entrada
      (let ((pegadas (claves-pegadas situacion datos)))
        (comprobar (null pegadas)
                   "~a tiene claves pegadas a mano (usa una clave compuesta): ~{~s~^, ~}"
                   nombre pegadas)))))
