;;;; Casos de prueba de robustez.
;;;;
;;;; No son corpus: no son libros de la facultad. Son las descripciones que
;;;; escribio la auditoria del 2026-10-17 para comprobar si el lenguaje servia
;;;; para situaciones ajenas al corpus -una lista de la compra, unas notas,
;;;; una agenda de salas, un inventario, un registro de horas, unos prestamos-
;;;; y si las tres arquitecturas aguantaban datos que el corpus nunca tuvo:
;;;; etiquetas con guion o apostrofo, valores con "*", comas, mayusculas
;;;; distintas o saltos de linea, decimales, fechas, horas y booleanos.
;;;;
;;;; Ninguna salio bien en las tres arquitecturas a la primera. Aqui se
;;;; conservan para que no vuelva a pasar: ./demostrar-robustez.sh las genera,
;;;; las materializa y las verifica igual que el corpus.

(defpackage #:situacion.casos
  (:use #:common-lisp #:situacion.lenguaje)
  (:documentation "Casos de prueba de robustez, ajenos al corpus.")
  (:export #:*casos* #:caso-prefijo #:caso-situacion #:caso-datos))

(in-package #:situacion.casos)

(defvar *casos* '()
  "Los casos registrados, en orden de definicion. Cada uno es una lista
   (PREFIJO SITUACION DATOS).")

(defun caso-prefijo (caso) (first caso))
(defun caso-situacion (caso) (second caso))
(defun caso-datos (caso) (third caso))

(defun registrar-caso (prefijo situacion datos)
  "Registra un caso. Si ya hay uno con ese prefijo, lo sustituye."
  (setf *casos* (append (remove prefijo *casos* :key #'first :test #'string=)
                        (list (list prefijo situacion datos))))
  prefijo)

(defun fila (&rest pares)
  "Una fila de datos a partir de pares nombre-valor: (fila \"nombre\" \"Ana\")."
  (loop for (campo valor) on pares by #'cddr
        collect (cons (nucleo:nombrar campo) valor)))

(defun datos (&rest colecciones)
  "Los datos de una situacion. Cada argumento es (\"coleccion\" fila fila ...)."
  (loop for (nombre . filas) in colecciones
        collect (cons (nucleo:nombrar nombre) filas)))
