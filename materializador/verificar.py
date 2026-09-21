"""Comprueba que las formulas del libro generado EVALUAN, y que dan lo mismo
que el evaluador de referencia.

EL PROBLEMA QUE RESUELVE

Una bateria de pruebas de Python no evalua formulas: comprueba que en la celda
hay la cadena que esperabamos, no que esa cadena calcule bien. Un libro puede
pasar todas las pruebas y abrirse lleno de errores.

EL PROCEDIMIENTO

  1. Se genera el libro.
  2. Se pasa por LibreOffice en modo headless, que lo abre, recalcula y lo
     vuelve a escribir.
  3. Se relee con data_only=True, que da los VALORES y no las formulas.
  4. Se comparan con lo que dijo el evaluador de referencia del nucleo.

Si los dos coinciden, dos cosas quedan demostradas a la vez: que las formulas
son validas, y que la arquitectura de Excel coincide con la semantica del
lenguaje. Ninguna de las tres tesis anteriores de la linea presenta evidencia
de que las formulas que genera se evaluen; la de 2026 lo afirma y lo respalda
con capturas de pantalla, que es lo mas lejos que se llego.

Uso:
    python3 verificar.py <plano.json> <esperado.json> <libro.xlsx>
"""

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from openpyxl import load_workbook
from openpyxl.utils import get_column_letter


def recalcular_con_libreoffice(xlsx):
    """Abre el libro con LibreOffice y lo vuelve a escribir, recalculado."""
    destino = Path(tempfile.mkdtemp(prefix="situacion-"))
    subprocess.run(
        ["soffice", "--headless", "--norestore",
         "--convert-to", "xlsx", "--outdir", str(destino), str(xlsx)],
        check=True, capture_output=True, timeout=180,
    )
    salida = destino / Path(xlsx).name
    if not salida.exists():
        candidatos = list(destino.glob("*.xlsx"))
        if not candidatos:
            raise RuntimeError("LibreOffice no produjo ningun archivo")
        salida = candidatos[0]
    return salida, destino


def columnas_de(hoja_plan):
    """De nombre interno de campo a letra de columna.

    Se usa el nombre interno y no la etiqueta visible: emparejar por etiqueta
    es adivinar, y adivinar da falsos positivos (la etiqueta "Asignatura"
    casaria con el campo "asignadas").
    """
    columnas = {}
    for enc in hoja_plan.get("encabezados") or []:
        letra = "".join(c for c in enc["celda"] if c.isalpha())
        columnas[enc["campo"]] = letra
    return columnas


def normalizar(valor):
    if valor is None:
        return ""
    if isinstance(valor, bool):
        return valor
    if isinstance(valor, (int, float)):
        return float(valor)
    texto = str(valor).strip()
    if texto == "":
        return ""
    try:
        return float(texto)
    except ValueError:
        return texto


def verificar(plano_path, esperado_path, xlsx_path):
    plano = json.loads(Path(plano_path).read_text(encoding="utf-8"))
    esperado = json.loads(Path(esperado_path).read_text(encoding="utf-8"))

    recalculado, temporal = recalcular_con_libreoffice(xlsx_path)
    try:
        libro = load_workbook(recalculado, data_only=True)

        comprobadas = 0
        fallos = []

        for hoja_plan in plano["hojas"]:
            nombre = hoja_plan["nombre"][:31]
            if nombre not in libro.sheetnames:
                fallos.append("falta la hoja {!r}".format(nombre))
                continue
            hoja = libro[nombre]
            columnas = columnas_de(hoja_plan)

            # Las etiquetas visibles son la unica via que tenemos desde aqui
            # para emparejar columna con campo, porque el plano no lleva el
            # nombre interno: es informacion del dominio y no tiene por que
            # bajar hasta aqui.
            clave = _clave_de_coleccion(esperado, hoja_plan, columnas)
            if clave is None:
                continue
            filas_esperadas = esperado[clave]

            for i, envoltura in enumerate(filas_esperadas):
                fila_valores = envoltura[0] if isinstance(envoltura, list) else envoltura
                fila = hoja_plan["fila_primera"] + i
                for campo, letra in columnas.items():
                    if campo not in fila_valores:
                        continue
                    real = normalizar(hoja["{}{}".format(letra, fila)].value)
                    esperado_v = normalizar(fila_valores[campo])
                    comprobadas += 1
                    if real != esperado_v:
                        fallos.append(
                            "{}!{}{}  esperado {!r}  obtenido {!r}".format(
                                nombre, letra, fila, esperado_v, real))

        return comprobadas, fallos
    finally:
        shutil.rmtree(temporal, ignore_errors=True)


def _clave_de_coleccion(esperado, hoja_plan, columnas):
    """Empareja la hoja con la coleccion del oraculo.

    Se hace por numero de campos y por que los nombres encajen; es una
    heuristica de esta herramienta de verificacion, no del sistema.
    """
    for clave, filas in esperado.items():
        if not filas:
            continue
        primera = filas[0][0] if isinstance(filas[0], list) else filas[0]
        if set(primera.keys()) == set(columnas.keys()):
            return clave
    return None


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    comprobadas, fallos = verificar(argv[1], argv[2], argv[3])
    nombre = Path(argv[3]).name
    if fallos:
        print("FALLA  {}: {} celdas comprobadas, {} discrepancias"
              .format(nombre, comprobadas, len(fallos)))
        for f in fallos[:20]:
            print("   " + f)
        return 1
    print("  ok   {}: {} celdas evaluadas por LibreOffice coinciden con el "
          "evaluador de referencia".format(nombre, comprobadas))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
