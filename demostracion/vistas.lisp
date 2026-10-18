;;;; El oraculo de las tablas que se dibujan.
;;;;
;;;; El oraculo de valores dice que vale cada campo de cada fila; el de
;;;; cruces, que hay en cada casilla de cada rejilla. Este dice que tablas de
;;;; lista tiene que dibujar cada arquitectura -una por vista de lista, mas
;;;; una por coleccion sin ninguna (nucleo/tablas.lisp)-, con que titulo, y
;;;; en que orden van sus filas y sus cabeceras de grupo.
;;;;
;;;; Con el se comprueban la tabla del texto plano, la tabla que dibuja la
;;;; pagina en un navegador y las hojas derivadas de la hoja de calculo. Antes
;;;; nadie comprobaba que una vista se dibujara: dos vistas agrupadas sobre la
;;;; misma coleccion salian como una sola tabla y todo daba verde.

(in-package #:situacion.demostracion)

(defun tabla-esperada (entorno vista coleccion titulo agrupacion)
  "Lo que tiene que dibujarse para una tabla de lista."
  (let ((orden (nucleo:filas-en-orden-de-presentacion entorno (nucleo:nombre coleccion)
                                                      agrupacion)))
    (list (cons "vista" (if vista (string-downcase (symbol-name (nucleo:nombre vista))) ""))
          (cons "titulo" titulo)
          (cons "coleccion" (string-downcase (symbol-name (nucleo:nombre coleccion))))
          (cons "agrupada_por" (if agrupacion (string-downcase (symbol-name agrupacion)) ""))
          ;; Los campos en el orden en que se dibujan, y cuales son una
          ;; relacion uno a muchos: de esas el oraculo de valores da cuantas
          ;; filas trae, y cada destino las ensena a su manera.
          (cons "campos" (situacion.excel::lista
                          (loop for campo in (nucleo:campos coleccion)
                                collect (append
                                         (list (cons "campo" (string-downcase
                                                              (symbol-name (nucleo:nombre campo))))
                                               (cons "relacion"
                                                     (if (typep (nucleo:expresion campo)
                                                                'nucleo:relacionadas)
                                                         t :false)))
                                         ;; Con cuantos decimales se escribe la
                                         ;; celda, si el campo lo declara (C6).
                                         (when (nucleo:decimales campo)
                                           (list (cons "decimales"
                                                       (nucleo:decimales campo))))))))
          (cons "filas" (situacion.excel::lista (mapcar #'car orden)))
          (cons "cabeceras" (situacion.excel::lista
                             (loop for (nil . cabecera) in orden
                                   for posicion from 0
                                   when cabecera
                                     collect (list posicion (nucleo:como-texto cabecera))))))))

(defun escribir-vistas-esperadas (situacion datos destino)
  "Las tablas de lista que tiene que dibujar cada arquitectura, en orden: las
   vistas de lista en el orden declarado y despues las colecciones que no
   tienen ninguna."
  (let ((entorno (nucleo:hacer-entorno situacion datos)))
    (situacion.excel::escribir-plano
     (situacion.excel::lista
      (append
       (loop for vista in (nucleo:vistas-de-lista situacion)
             collect (tabla-esperada entorno vista
                                     (nucleo:coleccion-llamada situacion (nucleo:fuente vista))
                                     (nucleo:etiqueta vista)
                                     (nucleo:agrupacion vista)))
       (loop for coleccion in (nucleo:colecciones-sin-vista-de-lista situacion)
             collect (tabla-esperada entorno nil coleccion (nucleo:etiqueta coleccion) nil))))
     destino)))
