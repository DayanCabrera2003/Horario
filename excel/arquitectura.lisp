;;;; La arquitectura de hoja de calculo.
;;;;
;;;; Cumple casi todo de forma nativa, y las dos cosas que no cumple son las
;;;; interesantes: el crecimiento y el conteo de distintos. Las dos las emula,
;;;; y las dos las emula con maquinaria que en una pagina web no haria ninguna
;;;; falta.
;;;;
;;;; Esa inversion es el mejor argumento disponible de que la jerarquia de
;;;; capacidades no es decorativa: NO HAY UNA ARQUITECTURA QUE PUEDA MAS Y
;;;; OTRAS QUE PUEDAN MENOS. Cada una puede cosas distintas.

(defpackage #:situacion.excel
  (:use #:common-lisp)
  (:documentation "Arquitectura de salida a hoja de calculo.")
  (:export #:excel #:hacer-excel #:plan-de-excel #:escribir-plano))

(in-package #:situacion.excel)

(defclass excel (protocolo:con-rejilla
                 protocolo:con-busqueda-por-clave
                 protocolo:con-derivacion-viva
                 protocolo:con-entrada
                 protocolo:con-dominio-de-entrada
                 protocolo:con-orden-declarado
                 protocolo:con-marcado-visual
                 protocolo:con-marcado-textual
                 protocolo:con-navegacion)
  ((reserva-minima :accessor reserva-minima :initarg :reserva-minima
                   :initform 20
                   :documentation
                   "Filas en blanco que se reservan como minimo a una
                    coleccion que crece. Viene del corpus: con pocos datos,
                    reservar un porcentaje se queda en nada."))
  (:documentation
   "Salida a un libro de hoja de calculo.

    No hereda de CON-CRECIMIENTO ni de CON-CONTEO-DE-DISTINTOS a proposito:
    no los tiene. Los emula, y el informe de conformidad lo dice."))

(defun hacer-excel (&key (reserva-minima 20))
  (make-instance 'excel :reserva-minima reserva-minima))

(defmethod protocolo:resolver-carencia ((a excel) capacidad nodo)
  (case capacidad

    (protocolo:con-particion-de-vista
     (values :emula
             "cada seccion sale como una pestana propia, y el conjunto de
              pestanas se fija AL GENERAR leyendo los datos. La clave compuesta
              de la hoja de origen lleva el campo de particion delante, para
              que la busqueda no cruce secciones.
              Limite: si manana aparece un grupo nuevo, no aparece una pestana
              para el; hay que volver a generar el libro. Es el mismo coste que
              la tabla cruzada, y por la misma razon: lo que depende del
              contenido mueve el direccionamiento entero."))
    (protocolo:con-filtro-de-vista
     (values :emula
             "las filas que cumplen la condicion se eligen AL GENERAR y se
              reparten por las pestanas. Limite: si manana una fila deja de
              cumplir el filtro, sigue en su pestana hasta que se regenere el
              libro. Es el mismo coste que la particion y que la tabla
              cruzada, y por la misma razon: lo que depende del contenido
              mueve el direccionamiento entero."))

    (protocolo:con-agrupacion-en-vista
     (values :degrada
             "las filas salen en el orden de la coleccion, sin cabecera por
              grupo. La tabla es correcta -son las mismas filas- y solo pierde
              legibilidad, que es lo que distingue degradar de rechazar.
              Aqui cuesta lo que en los otros dos destinos es gratis, y la
              razon merece decirse: en una pagina o en un informe de texto
              agrupar es solo el orden en que se DIBUJAN las filas, y el dato
              no se mueve. En una rejilla la posicion de la fila ES el dato:
              reordenarla cambiaria lo que significan ANTERIOR y SIGUIENTE, e
              intercalar cabeceras correria las filas fuera de los rangos."))

    (protocolo:con-crecimiento
     (values :emula
             (format nil
                     "~d filas de reserva y un rango que se dimensiona con lo~@
                      escrito. Limite comprobado en el corpus: no admite huecos~@
                      en medio del listado, porque el conteo de celdas no vacias~@
                      no distingue una fila en blanco de una fila ausente y la~@
                      ultima entrada se queda fuera del rango."
                     (reserva-minima a))))

    (protocolo:con-tabla-cruzada
     (values :emula
             "los dos ejes se leen de los datos y se fijan AL GENERAR, y se
              anade a la hoja de origen una columna de clave compuesta para
              poder buscar por dos criterios con INDICE y COINCIDIR, que es
              la pareja portable entre Excel y LibreOffice Calc.
              Limite: si manana aparece un valor nuevo en cualquiera de los
              dos ejes, no aparece una fila ni una columna para el; hay que
              volver a generar el libro."))

    (protocolo:con-agrupacion
     (values :emula
             "las filas se calculan al generar y quedan fijas. Si despues
              aparece un valor nuevo en la coleccion de origen, no aparece
              una fila para el: hay que volver a generar."))

    (protocolo:con-conteo-de-distintos
     (values :emula
             "columna auxiliar que marca la primera aparicion de cada valor y
              se suma. El recuento condicional no sabe contar unicos, y las
              formulas matriciales no se comportan igual en Excel que en
              LibreOffice Calc, asi que el rodeo plano es el unico portable."))

    (protocolo:con-relacion-uno-a-muchos
     ;; La emulacion esta disenada -hoja auxiliar con clave numerada, lineas
     ;; reservadas por fila padre y un aviso al desbordarse, que es lo que
     ;; hace hoy departamento/hoja_carga.py- y NO esta implementada.
     ;;
     ;; Se responde :RECHAZA y no :EMULA a proposito. Decir que se emula algo
     ;; que no se emula es exactamente el verde falso que este trabajo le
     ;; reprocha a la tesis de 2026, y el informe de conformidad no sirve
     ;; para nada si miente.
     (values :rechaza
             "la hoja de calculo no tiene listas de largo variable dentro de
              una fila. La emulacion esta disenada -hoja auxiliar con clave
              numerada, lineas reservadas y aviso al desbordarse- y todavia no
              implementada, asi que esta descripcion no se puede materializar
              aqui sin mentir."))

    (protocolo:con-derivacion-por-consulta
     (values :degrada "las derivaciones son vivas, que es mas de lo que se pide"))

    (t (values :rechaza
               (format nil "la hoja de calculo no tiene ~(~a~) ni forma de~@
                            emularla de manera honesta~@[ (~a)~]"
                       capacidad
                       (when (typep nodo 'nucleo:nodo)
                         (ignore-errors (nucleo:nombre nodo))))))))
