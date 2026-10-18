;;;; Pruebas de los verificadores ante un oraculo sin nada que comparar.
;;;;
;;;; Hasta el 2026-10-17 materializador/verificar.py y verificar-web.js
;;;; decian "ok 0 celdas" si el oraculo traia las colecciones vacias: una
;;;; situacion sin ninguna fila comparada salia en verde. Comparar cero
;;;; valores nunca demuestra nada, asi que con el total global en cero los
;;;; dos tienen que fallar siempre.
;;;;
;;;; Las pruebas lanzan los verificadores de verdad (Python y Node), pero sin
;;;; LibreOffice: el de la hoja de calculo se prueba por la funcion que decide
;;;; el veredicto, y el de la pagina con una pagina real y un oraculo vacio.

(in-package #:situacion.pruebas)

(defun directorio-del-materializador ()
  (namestring (asdf:system-relative-pathname "situacion" "materializador/")))

(defun codigo-de-salida (programa)
  "Ejecuta PROGRAMA (lista de cadenas) y devuelve su codigo de salida."
  (nth-value 2 (uiop:run-program programa :ignore-error-status t
                                          :output nil :error-output nil)))

(definir-prueba verificador-libro-sin-celdas-falla
    "Verificadores: la hoja de calculo con cero celdas comparadas falla"
  (let ((guion (format nil "import sys; sys.path.insert(0, ~s); import verificar; ~
                            sys.exit(0 if verificar.fallos_del_total(0) and ~
                            not verificar.fallos_del_total(1) else 1)"
                       (directorio-del-materializador))))
    (comprobar (eql 0 (codigo-de-salida (list "python3" "-c" guion)))
               "verificar.py tiene que dar un fallo con 0 celdas y ninguno con 1")))

(definir-prueba verificador-pagina-sin-valores-falla
    "Verificadores: la pagina con un oraculo vacio falla"
  (let ((pagina (merge-pathnames "situacion-sin-comparar.html" (uiop:temporary-directory)))
        (oraculo (merge-pathnames "situacion-sin-comparar.json" (uiop:temporary-directory))))
    (with-open-file (f pagina :direction :output :if-exists :supersede
                              :external-format :utf-8)
      (write-string (materializar-en-cadena (situacion.web:hacer-web)
                                            (situacion.lenguaje:situacion-llamada "CASO-NOTAS")
                                            (datos-del-caso "DATOS-DE-NOTAS"))
                    f))
    (with-open-file (f oraculo :direction :output :if-exists :supersede)
      (write-string "{}" f))
    (unwind-protect
         (comprobar (eql 1 (codigo-de-salida
                            (list "node" (concatenate 'string (directorio-del-materializador)
                                                      "verificar-web.js")
                                  (namestring pagina) (namestring oraculo))))
                    "verificar-web.js tiene que fallar si no compara ningun valor")
      (delete-file pagina)
      (delete-file oraculo))))
