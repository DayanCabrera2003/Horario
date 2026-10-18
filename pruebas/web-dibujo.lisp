;;;; Pruebas del dibujo de la pagina.
;;;;
;;;; Hasta el 2026-10-17 cada pulsacion de tecla volvia a dibujar la pagina
;;;; entera y el control donde se escribia desaparecia: solo se podia teclear
;;;; un caracter seguido. Que ya no pase lo comprueba en un navegador de
;;;; verdad materializador/sonda-foco.js; aqui se comprueba la estructura que
;;;; lo hace posible.

(in-package #:situacion.pruebas)

(defun pagina-del-saul ()
  (materializar-en-cadena (situacion.web:hacer-web)
                          (situacion.lenguaje:situacion-llamada "HORARIO-SAUL")
                          situacion.corpus:datos-del-saul))

(definir-prueba web-escribir-no-redibuja
    "Pagina: escribir en un control actualiza en sitio, no vuelve a dibujar todo"
  (let* ((html (pagina-del-saul))
         (inicio (search "control.addEventListener('input'" html))
         (fin (and inicio (search "});" html :start2 inicio)))
         (manejador (and fin (subseq html inicio fin))))
    (comprobar manejador "la pagina no tiene manejador de entrada")
    (when manejador
      (comprobar (search "actualizar()" manejador)
                 "al escribir hay que llamar a actualizar(): ~a" manejador)
      (comprobar (not (search "construir()" manejador))
                 "al escribir no se puede volver a construir la pagina: ~a" manejador))
    (comprobar (not (search "innerHTML" html))
               "la pagina no puede vaciarse con innerHTML")))

(definir-prueba web-rejilla-de-entrada-es-editable
    "Pagina: la rejilla de una vista :ENTRADA T lleva controles en sus casillas"
  (let ((html (pagina-del-saul)))
    (comprobar (search "entrada: true" html)
               "la rejilla por grupo del Saul es de entrada y la pagina no lo sabe")
    (comprobar (search "td = controlDe(cruce.coleccion, campoCelda" html)
               "la casilla de una rejilla de entrada tiene que ser un control")))
