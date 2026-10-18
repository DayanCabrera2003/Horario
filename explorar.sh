#!/bin/sh
# Genera y verifica los experimentos de exploracion/.
#
# Los experimentos no son parte del sistema (exploracion/README.md), pero son
# evidencia de la tesis: descripciones de dominios ajenos al corpus escritas
# para medir hasta donde llega el lenguaje. Durante semanas dejaron de
# funcionar sin que nadie lo viera -internaban los nombres de los datos en un
# paquete que el nucleo ya no usaba y salian tablas vacias-. Este guion los
# carga todos, falla si alguno no carga, y verifica contra el evaluador de
# referencia todo lo que generan, para que no vuelvan a pudrirse.
#
# Sale con codigo 1 si algo falla.
set -e
cd "$(dirname "$0")"
mkdir -p salida exploracion/salida

registro=salida/exploracion.log
sbcl --noinform --disable-debugger --no-userinit \
  --eval '(require :asdf)' \
  --eval '(asdf:initialize-source-registry
            (list :source-registry (list :directory (uiop:getcwd))
                  :inherit-configuration))' \
  --eval '(handler-bind ((warning (function muffle-warning)))
            (asdf:load-system :situacion/demostracion))' \
  --eval '(let ((fallos 0))
            (dolist (f (list "exploracion/torneo.lisp" "exploracion/notas.lisp"
                             "exploracion/presupuesto.lisp" "exploracion/inventario.lisp"
                             "exploracion/turnos.lisp" "exploracion/saul.lisp"))
              (format t "~&~%>>>>>> ~a~%" f)
              (handler-case (handler-bind ((warning (function muffle-warning))) (load f))
                (error (e) (incf fallos)
                  (format t "~&ERROR AL CARGAR ~a: ~a~%" f e))))
            (uiop:quit (if (zerop fallos) 0 1)))' \
  > "$registro.crudo" 2>&1 || cargados=1
grep -v '^;' "$registro.crudo" > "$registro"
rm -f "$registro.crudo"

fallos=${cargados:-0}
grep '^ERROR AL CARGAR' "$registro" || true

# Lo generado con situacion.demostracion:generar tiene los cuatro oraculos.
for f in $(sed -n 's/^Generado salida\/\(.*\)\.txt$/\1/p' "$registro" | sort -u); do
  python3 materializador/materializar.py "salida/$f-plano.json" "salida/$f.xlsx" > /dev/null || fallos=1
  python3 materializador/verificar.py "salida/$f-plano.json" "salida/$f-esperado.json" \
          "salida/$f.xlsx" "salida/$f-cruces.json" "salida/$f-vistas.json" \
          > salida/exploracion-verificacion.log 2>&1 || fallos=1
  grep -v '^        ' salida/exploracion-verificacion.log
  node materializador/verificar-web.js "salida/$f.html" "salida/$f-esperado.json" || fallos=1
  python3 materializador/verificar-texto.py "salida/$f.txt" "salida/$f-esperado.json" \
          "salida/$f-vistas.json" "salida/$f-cruces.json" || fallos=1
done

# El presupuesto escribe su propio oraculo de valores.
if [ -f exploracion/salida/presupuesto-esperado.json ]; then
  python3 materializador/materializar.py exploracion/salida/presupuesto-plano.json \
          exploracion/salida/presupuesto.xlsx > /dev/null || fallos=1
  python3 materializador/verificar.py exploracion/salida/presupuesto-plano.json \
          exploracion/salida/presupuesto-esperado.json exploracion/salida/presupuesto.xlsx \
          > salida/exploracion-verificacion.log 2>&1 || fallos=1
  grep -v '^        ' salida/exploracion-verificacion.log
  node materializador/verificar-web.js exploracion/salida/presupuesto.html \
       exploracion/salida/presupuesto-esperado.json || fallos=1
fi

# Los demas planos, al menos tienen que materializarse.
for p in exploracion/salida/*-plano.json; do
  case "$p" in *presupuesto-plano.json) continue ;; esac
  python3 materializador/materializar.py "$p" "${p%-plano.json}.xlsx" > /dev/null \
    || { echo "FALLA  no se materializa $p"; fallos=1; }
done

echo
if [ "$fallos" = "0" ]; then
  echo "Exploracion: todos los experimentos cargan y lo que generan coincide."
else
  echo "Exploracion: hay fallos. Ver arriba y $registro."
  exit 1
fi
