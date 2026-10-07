#!/bin/sh
# Regenera los resultados de los ejemplos y los deja en ejemplos/resultados/.
#
# Los resultados se versionan, a diferencia de salida/, para que se puedan
# abrir sin instalar SBCL, Python ni LibreOffice. Este guion es la unica
# forma de producirlos: si cambia el lenguaje o una descripcion, se vuelve a
# ejecutar y se versiona lo que salga.
#
# ./demostrar.sh genera todas las descripciones del corpus y las verifica
# contra el evaluador de referencia. Si algo no coincide, se para aqui y no
# se copia nada.
#
# Regenerar un .xlsx cambia solo la fecha que lleva dentro
# (docProps/core.xml). Si git los da por modificados sin que haya cambiado
# nada mas, se descartan con git checkout.
set -e
cd "$(dirname "$0")/.."

./demostrar.sh > /dev/null

for f in plan-del-grupo defensas-de-tesis horario-del-grupo departamento \
         horario-saul seder; do
  cp "salida/$f.xlsx" "salida/$f.html" "salida/$f.txt" ejemplos/resultados/
done

echo "Resultados en ejemplos/resultados/:"
ls ejemplos/resultados/
