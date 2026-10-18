;;;; Pruebas del escape de valores.
;;;;
;;;; La auditoria del 2026-10-17 encontro que un dato con un salto de linea
;;;; dejaba la pagina en blanco (la cadena de JavaScript se cortaba), que una
;;;; etiqueta con "<" entraba en el HTML como un elemento, que un dato "=1+1"
;;;; se escribia en la hoja de calculo como formula y que un valor con coma
;;;; partia en dos un desplegable.

(in-package #:situacion.pruebas)

(defun datos-del-caso (nombre)
  "Los datos de un caso de pruebas/casos/, por el nombre de su variable."
  (symbol-value (find-symbol nombre '#:situacion.casos)))

(definir-prueba web-cadena-es-json-valido
    "Escapes: un literal de JavaScript no lleva saltos de linea crudos ni cierra el script"
  (let ((cadena (situacion.web::js-cadena
                 (format nil "Dos~%lineas, \"comillas\", barra \\ y </script>"))))
    (comprobar (not (find #\Newline cadena))
               "la cadena lleva un salto de linea crudo: ~a" cadena)
    (comprobar (not (search "</script" cadena))
               "la cadena cerraria el bloque <script>: ~a" cadena)
    (comprobar (search "<\\/script" cadena) "\"</\" tiene que escribirse \"<\\/\": ~a" cadena)
    (comprobar (search "\\\"comillas\\\"" cadena) "las comillas tienen que ir escapadas: ~a"
               cadena)))

(definir-prueba web-pagina-con-textos-raros-es-valida
    "Escapes: la pagina de un caso con saltos de linea y </script> cierra bien y escapa el titulo"
  (let* ((html (materializar-en-cadena (situacion.web:hacer-web)
                                       (situacion.lenguaje:situacion-llamada "CASO-ESCAPES")
                                       (datos-del-caso "DATOS-DE-ESCAPES")))
         (inicio (search "<script>" html))
         (primer-cierre (search "</script>" html :start2 (1+ (or inicio 0)))))
    (comprobar (and inicio primer-cierre (= primer-cierre (search "</script>" html :from-end t)))
               "un dato cierra el <script> antes de tiempo")
    (comprobar (search ">Precios &lt;IVA&gt; &amp; descuentos</h1>" html)
               "la etiqueta de la situacion tiene que ir escapada en el h1")))

(definir-prueba excel-desplegable-con-coma-va-a-un-rango
    "Escapes: la lista de un desplegable va a la hoja oculta, y una coma no la parte"
  (let* ((plano (plano-de (situacion.lenguaje:situacion-llamada "CASO-COMPRAS-B")
                          (datos-del-caso "DATOS-DE-COMPRAS-B")))
         (productos (hoja-de-coleccion plano "productos"))
         (validacion (first (lista-del-plano (dato productos "validaciones"))))
         (listas (find "listas" (hojas-del-plano plano)
                       :key (lambda (h) (dato h "auxiliar")) :test #'equal)))
    (comprobar listas "el libro tiene desplegables y no tiene hoja de listas")
    (comprobar (and validacion (stringp (dato validacion "lista"))
                    (search "!" (dato validacion "lista")))
               "la validacion tiene que citar un rango de la hoja de listas")
    (when listas
      (comprobar (dato listas "oculta") "la hoja de listas tiene que ir oculta")
      (comprobar (find "Aseo, Hogar" (lista-del-plano (dato listas "celdas"))
                       :key (lambda (c) (dato c "valor")) :test #'equal)
                 "\"Aseo, Hogar\" tiene que ser un solo valor de la lista"))))
