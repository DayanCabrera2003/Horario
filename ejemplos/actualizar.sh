#!/bin/sh
# Regenera los resultados de los ejemplos y los deja en ejemplos/resultados/.
#
# Los resultados se versionan, a diferencia de salida/, para que se puedan
# abrir sin instalar SBCL, Python ni LibreOffice. Este guion es la unica
# forma de producirlos: si cambia el lenguaje o una descripcion, se vuelve a
# ejecutar y se versiona lo que salga.
#
#   1. ./demostrar.sh genera las cuatro descripciones del corpus y las
#      verifica contra el evaluador de referencia. Si algo no coincide, se
#      para aqui y no se copia nada.
#   2. El horario del Saul Delgado vive en exploracion/ y se ejecuta aparte.
#      Hoy produce texto y pagina web; la hoja de calculo todavia no (ver
#      ejemplos/README.md).
set -e
cd "$(dirname "$0")/.."

./demostrar.sh > /dev/null

for f in plan-del-grupo defensas-de-tesis horario-del-grupo departamento; do
  cp "salida/$f.xlsx" "salida/$f.html" "salida/$f.txt" ejemplos/resultados/
done

sbcl --noinform --disable-debugger --no-userinit \
  --eval '(require :asdf)' \
  --eval '(asdf:initialize-source-registry
            (list :source-registry (list :directory (uiop:getcwd))
                  :inherit-configuration))' \
  --eval '(handler-bind ((warning (function muffle-warning)))
            (asdf:load-system :situacion/demostracion))' \
  --load exploracion/saul.lisp \
  --quit > /dev/null 2>&1
cp exploracion/salida/saul.html exploracion/salida/saul.txt ejemplos/resultados/

echo "Resultados en ejemplos/resultados/:"
ls ejemplos/resultados/
