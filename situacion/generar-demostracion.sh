#!/bin/sh
# Genera los artefactos de las tres arquitecturas a partir de las mismas
# descripciones del corpus. No necesita Quicklisp.
set -e
cd "$(dirname "$0")"
exec sbcl --noinform --disable-debugger --no-userinit \
  --eval '(require :asdf)' \
  --eval '(asdf:initialize-source-registry
            (list :source-registry (list :directory (uiop:getcwd))
                  :inherit-configuration))' \
  --eval '(handler-bind ((warning (function muffle-warning)))
            (asdf:load-system :situacion/demostracion))' \
  --eval '(situacion.demostracion:generar-todo)' \
  --quit
