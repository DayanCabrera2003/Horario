#!/bin/sh
# Demostracion completa, de punta a punta y con un solo comando.
#
#   1. Toma las descripciones del corpus, escritas en el lenguaje.
#   2. Genera tres artefactos por descripcion: texto plano, plano de libro y
#      pagina web. Mas el oraculo del evaluador de referencia.
#   3. Materializa el plano en un .xlsx de verdad.
#   4. Pasa el .xlsx por LibreOffice, lo relee ya calculado, y comprueba que
#      cada celda de cada hoja coincide con lo que dijo el evaluador; lee el
#      texto plano por sus columnas; ejecuta el JavaScript de la pagina y la
#      abre en un navegador para comparar lo que dibuja; y escribe en el
#      libro y en la pagina como lo haria quien los usa.
#   5. Repite todo con los casos de robustez (./demostrar-robustez.sh).
#
# El paso 4 es el que importa: demuestra a la vez que las formulas son validas
# y que la arquitectura de Excel coincide con la semantica del lenguaje.
set -e
cd "$(dirname "$0")"

echo
echo "#############################################################"
echo "#  1 y 2.  De la descripcion a los artefactos"
echo "#############################################################"
# La salida pasa por un archivo y no por una tuberia: en una tuberia, el
# codigo de salida es el del ultimo programa, y si la generacion fallaba (un
# .lisp que no compila) la demostracion seguia con los artefactos de la
# vez anterior y podia acabar en "ok" sin haber generado nada (2026-10-21).
mkdir -p salida
if ! ./generar-demostracion.sh > salida/generacion.log 2> salida/generacion.err; then
  grep -v '^;' salida/generacion.err | head -20
  echo
  echo "FALLA  la generacion no termino: no se verifica nada (salida/generacion.err)"
  exit 1
fi
grep -v '^;' salida/generacion.log

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
          "salida/$f-cruces.json" "salida/$f-vistas.json" || fallos=1
done

echo
echo "Texto plano: se leen sus tablas y sus rejillas por el ancho de sus columnas"
echo "y se compara cada celda con el evaluador."
for f in plan-del-grupo defensas-de-tesis horario-del-grupo departamento horario-saul seder; do
  python3 materializador/verificar-texto.py "salida/$f.txt" "salida/$f-esperado.json" \
          "salida/$f-vistas.json" "salida/$f-cruces.json" || fallos=1
done

echo
echo "Libro usado: se escribe una asignatura nueva en una fila de reserva del"
echo "plan del grupo, se recalcula y se comprueba que la fila calcula."
python3 materializador/sonda_escritura.py salida/plan-del-grupo.xlsx "Plan del grupo" \
        A10=X B10=Nueva C10=3 D10=1 -- E10=2 || fallos=1

echo
echo "Parametro de entrada: se baja el tope diario del Saul a 1 en su hoja y"
echo "se comprueba que el profesor de Matematica del 10-3, que da 2 sesiones"
echo "el viernes, pasa a estar por encima del tope."
python3 materializador/sonda_escritura.py salida/horario-saul.xlsx "Carga diaria" \
        Parametros!B4=1 -- "D8=Da 2 sesiones ese dia" || fallos=1

echo
echo "Casilla en conflicto: en el SEDER se manda una tercera brigada (C211) a"
echo "la Pista 2 de la semana impar a las 11, donde ya chocan C212 y M21. La"
echo "casilla tiene que nombrar las dos primeras y decir que hay una mas."
python3 materializador/sonda_escritura.py salida/seder.xlsx "Reparto de brigadas" \
        "E6=11 a.m." "F6=Pista 2" -- "OI - impar!C5=C211 / C212 (+1)" || fallos=1

echo
echo "Rejilla de entrada: se escribe EF en el horario del 10-3, miercoles, turno 2,"
echo "como lo haria quien arma el horario. Casillas la copia, y salen las dos"
echo "marcas: Educacion Fisica repite el dia y el Terreno esta ocupado por el 10-4."
python3 materializador/sonda_escritura.py salida/horario-saul.xlsx "Horario del grupo - 10-3" \
        D5=EF -- "Casillas del horario!D16=EF" \
        "Casillas del horario!P16=Ese local esta ocupado por otro grupo a esa hora; Esta asignatura no admite turno doble y repite el dia en este grupo" \
        || fallos=1

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
echo "compara cada tabla y cada rejilla que se ve con el evaluador, se teclea en"
echo "un control y se comprueba que no pierde el foco ni salta ningun error."
. materializador/navegador.sh
if arrancar_navegador; then
  for f in plan-del-grupo defensas-de-tesis horario-del-grupo departamento horario-saul seder; do
    aparece=""
    [ "$f" = "horario-saul" ] && aparece="no está en la lista"
    node materializador/verificar-dom.js "$PUERTO_NAVEGADOR" "salida/$f.html" \
         "salida/$f-esperado.json" "salida/$f-vistas.json" "salida/$f-cruces.json" || fallos=1
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
echo "#############################################################"
echo "#  5.  Robustez: situaciones ajenas al corpus"
echo "#############################################################"
echo
echo "Las mismas comprobaciones sobre los casos de pruebas/casos/: una lista de"
echo "la compra, notas, una agenda, un inventario, horas trabajadas, prestamos y"
echo "textos con signos raros. Ver ./demostrar-robustez.sh."
./demostrar-robustez.sh || fallos=1

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
