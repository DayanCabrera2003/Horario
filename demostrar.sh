#!/bin/sh
# Demostracion completa, de punta a punta y con un solo comando.
#
#   1. Toma las descripciones del corpus, escritas en el lenguaje.
#   2. Genera tres artefactos por descripcion: texto plano, plano de libro y
#      pagina web. Mas el oraculo del evaluador de referencia.
#   3. Materializa el plano en un .xlsx de verdad.
#   4. Pasa el .xlsx por LibreOffice, lo relee ya calculado, y comprueba que
#      cada celda coincide con lo que dijo el evaluador.
#
# El paso 4 es el que importa: demuestra a la vez que las formulas son validas
# y que la arquitectura de Excel coincide con la semantica del lenguaje.
set -e
cd "$(dirname "$0")"

echo
echo "#############################################################"
echo "#  1 y 2.  De la descripcion a los artefactos"
echo "#############################################################"
./generar-demostracion.sh 2>/dev/null | grep -v '^;'

echo
echo "#############################################################"
echo "#  3.  Del plano de libro al .xlsx"
echo "#############################################################"
for f in plan-del-grupo defensas-de-tesis horario-del-grupo departamento horario-saul seder; do
  python3 materializador/materializar.py "salida/$f-plano.json" "salida/$f.xlsx"
done

echo
echo "#############################################################"
echo "#  4.  Las tres arquitecturas contra el evaluador de referencia"
echo "#############################################################"
echo
echo "Hoja de calculo: LibreOffice abre el libro, recalcula, y se releen los"
echo "valores para compararlos con los del evaluador."
fallos=0
for f in plan-del-grupo defensas-de-tesis horario-del-grupo departamento horario-saul seder; do
  python3 materializador/verificar.py "salida/$f-plano.json" \
          "salida/$f-esperado.json" "salida/$f.xlsx" \
          "salida/$f-cruces.json" || fallos=1
done

echo
echo "Texto plano: se leen sus tablas y sus rejillas por el ancho de sus columnas"
echo "y se compara cada celda con el evaluador."
for f in plan-del-grupo defensas-de-tesis horario-del-grupo departamento horario-saul seder; do
  python3 materializador/verificar-texto.py "salida/$f.txt" "salida/$f-esperado.json" \
          "salida/$f-vistas.json" "salida/$f-cruces.json" || fallos=1
done

echo
echo "Pagina web: se ejecuta el JavaScript que emitio la arquitectura y se"
echo "comparan los valores que calcula."
if command -v node >/dev/null 2>&1; then
  for f in plan-del-grupo defensas-de-tesis horario-del-grupo departamento horario-saul seder; do
    node materializador/verificar-web.js "salida/$f.html" \
         "salida/$f-esperado.json" || fallos=1
  done
else
  echo "  (node no esta instalado; esta comprobacion se salta)"
fi

echo
echo "Pagina dibujada: se abre cada pagina en un navegador sin pantalla, se"
echo "teclea en un control y se comprueba que no pierde el foco ni salta ningun"
echo "error, y que lo calculado se pone al dia."
. materializador/navegador.sh
if arrancar_navegador; then
  for f in plan-del-grupo defensas-de-tesis horario-del-grupo departamento horario-saul seder; do
    aparece=""
    [ "$f" = "horario-saul" ] && aparece="no está en la lista"
    node materializador/sonda-foco.js "$PUERTO_NAVEGADOR" "salida/$f.html" "$aparece" || fallos=1
  done
  cerrar_navegador
else
  echo "  (no hay Chromium; esta comprobacion se salta)"
fi

echo
echo "Los dos destinos no comparten nada: uno evalua formulas A1 dentro de una"
echo "rejilla, el otro ejecuta funciones sobre arreglos. Que los dos coincidan"
echo "con el mismo evaluador es lo que hace comprobable la afirmacion de que la"
echo "descripcion es independiente de la arquitectura."

echo
if [ "$fallos" = "0" ]; then
  echo "Todo coincide. Los artefactos estan en salida/"
  echo
  echo "  salida/plan-del-grupo.xlsx        abrelo con LibreOffice"
  echo "  salida/plan-del-grupo.html        abrelo con doble clic"
  echo "  salida/plan-del-grupo.txt         mirar en la terminal"
  echo "  salida/defensas-de-tesis.xlsx     escribe un estudiante y mira"
  echo "  salida/defensas-de-tesis.html     lo mismo, en el navegador"
  echo "  salida/departamento.xlsx          reparte la carga y mira la cobertura"
else
  echo "Hay discrepancias. Ver arriba."
  exit 1
fi
