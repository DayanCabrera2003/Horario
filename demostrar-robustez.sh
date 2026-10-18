#!/bin/sh
# Bateria de regresion de robustez.
#
# Genera los casos de pruebas/casos/ -situaciones ajenas al corpus, con
# etiquetas, valores, numeros, fechas y vistas que el corpus nunca tuvo-, los
# materializa y los verifica contra el evaluador de referencia exactamente
# igual que ./demostrar.sh verifica el corpus. Sale con codigo 1 si algun caso
# no coincide.
#
# Uso: ./demostrar-robustez.sh [prefijo ...]   (sin argumentos, todos)
set -e
cd "$(dirname "$0")"

mkdir -p salida
generados=0
sbcl --noinform --disable-debugger --no-userinit \
  --eval '(require :asdf)' \
  --eval '(asdf:initialize-source-registry
            (list :source-registry (list :directory (uiop:getcwd))
                  :inherit-configuration))' \
  --eval '(handler-bind ((warning (function muffle-warning)))
            (asdf:load-system :situacion/demostracion))' \
  --eval '(uiop:quit (if (situacion.demostracion:generar-casos) 0 1))' \
  > salida/casos-generacion.crudo 2>/dev/null || generados=1
grep -v '^;' salida/casos-generacion.crudo > salida/casos-generacion.log
rm -f salida/casos-generacion.crudo
grep -E '^(FALLO AL GENERAR|Casos:)' salida/casos-generacion.log || true

casos="$*"
if [ -z "$casos" ]; then
  casos=$(sed -n 's/^Generado salida\/\(caso-[a-z0-9-]*\)\.txt$/\1/p' salida/casos-generacion.log)
fi

fallos=$generados
for f in $casos; do
  python3 materializador/materializar.py "salida/$f-plano.json" "salida/$f.xlsx" > /dev/null || fallos=1
  python3 materializador/verificar.py "salida/$f-plano.json" \
          "salida/$f-esperado.json" "salida/$f.xlsx" "salida/$f-cruces.json" || fallos=1
  node materializador/verificar-web.js "salida/$f.html" "salida/$f-esperado.json" || fallos=1
done

# Una fecha tecleada de verdad (un numero de serie) tiene que comparar igual
# que una escrita como texto: Lia entrega el 11 de octubre, despues del 10.
case " $casos " in
  *" caso-notas "*)
    python3 materializador/sonda_fecha_tecleada.py salida/caso-notas.xlsx \
            Estudiantes H4 2026-10-11 K4 si || fallos=1 ;;
esac

echo
if [ "$fallos" = "0" ]; then
  echo "Robustez: todos los casos coinciden en las tres arquitecturas."
else
  echo "Robustez: hay discrepancias. Ver arriba y salida/casos-generacion.log."
  exit 1
fi
