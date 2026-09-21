#!/bin/sh
# Carga el sistema y corre las pruebas.
#
# No necesita Quicklisp: el nucleo, el protocolo y las pruebas de invariantes
# son Common Lisp puro. Con un SBCL recien instalado basta, que es justo lo
# que tiene que poder hacer quien reciba el protocolo para anadir su propia
# arquitectura.
#
# Sale con codigo 1 si alguna prueba falla.
set -e
cd "$(dirname "$0")"
exec sbcl --noinform --disable-debugger --no-userinit \
  --eval '(require :asdf)' \
  --eval '(asdf:initialize-source-registry
            (list :source-registry
                  (list :directory (uiop:getcwd))
                  :inherit-configuration))' \
  --eval '(asdf:load-system :situacion/pruebas)' \
  --eval '(situacion.pruebas:ejecutar-y-salir)'
