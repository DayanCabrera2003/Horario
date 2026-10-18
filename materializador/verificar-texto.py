"""Comprueba el documento de texto plano contra los oraculos.

EL PROBLEMA QUE RESUELVE

Hasta el 2026-10-17 el texto plano no lo comprobaba nadie. Por eso salian en
el, sin que ninguna prueba lo viera, un promedio escrito como 157/3, un
3.6000001, una fila partida por un salto de linea y una tabla de mas o de
menos cuando habia dos vistas sobre la misma coleccion.

LO QUE COMPRUEBA

  - Cada tabla de lista del oraculo de vistas esta en el documento, con su
    titulo, sus filas en su orden, sus cabeceras de grupo y cada celda
    escrita con la regla de presentacion del evaluador (hasta 10 cifras
    significativas). La columna de estado dice lo mismo que el oraculo.
  - Cada rejilla del oraculo de cruces esta en el documento, y cada casilla
    dice lo que dice el oraculo (varias filas, separadas por " / ").

Las columnas se leen por su ancho, que da la raya de guiones que va debajo
de los encabezados.

Uso:
    python3 verificar-texto.py <documento.txt> <esperado.json> <vistas.json> [<cruces.json>]
"""

import json
import sys
from pathlib import Path


def texto_de_valor(valor):
    """VALOR escrito como lo escribe el texto plano, sin espacios a los
    lados: en una tabla alineada no se distinguen."""
    return _texto(valor).strip()


def _texto(valor):
    if valor is None or valor is False:
        return ""
    if valor is True:
        return "si"
    if isinstance(valor, int):
        return str(valor)
    if isinstance(valor, float):
        if valor == int(valor) and abs(valor) < 1e15:
            return str(int(valor))
        return format(valor, ".10g")
    return " ".join(str(valor).replace("\r", " ").replace("\t", " ").split("\n"))


def anchos_de_raya(raya):
    """Las columnas de una tabla, como (inicio, ancho), leidas de la raya."""
    columnas = []
    i = 0
    while i < len(raya):
        if raya[i] == "-":
            j = i
            while j < len(raya) and raya[j] == "-":
                j += 1
            columnas.append((i, j - i))
            i = j
        else:
            i += 1
    return columnas


def celdas_de(linea, columnas):
    """Las celdas de una linea de tabla, recortadas."""
    return [linea[inicio:inicio + ancho].strip() for inicio, ancho in columnas]


def buscar_bloque(lineas, titulo, desde):
    """La posicion de la linea TITULO seguida de encabezado y raya, a partir
    de DESDE, o None."""
    for i in range(desde, len(lineas) - 2):
        if lineas[i] == titulo and set(lineas[i + 2].strip()) <= set("- ") \
                and "-" in lineas[i + 2]:
            return i
    return None


def verificar_tabla(lineas, tabla, esperado, desde):
    """Compara una tabla de lista. Devuelve (comprobadas, fallos, siguiente)."""
    titulo = tabla["titulo"]
    i = buscar_bloque(lineas, titulo, desde)
    if i is None:
        return 0, ["no esta la tabla {!r}".format(titulo)], desde
    columnas = anchos_de_raya(lineas[i + 2])
    filas = esperado.get(tabla["coleccion"], [])
    cabeceras = {pos: valor for pos, valor in (tabla["cabeceras"] or [])}
    campos = tabla["campos"] or []
    fallos = []
    comprobadas = 0
    j = i + 3
    for posicion, indice in enumerate(tabla["filas"] or []):
        if posicion in cabeceras:
            if j >= len(lineas) or lineas[j].strip() != texto_de_valor(cabeceras[posicion]):
                fallos.append("{}: falta la cabecera de grupo {!r}".format(
                    titulo, cabeceras[posicion]))
            j += 1
        if j >= len(lineas):
            fallos.append("{}: faltan filas".format(titulo))
            break
        celdas = celdas_de(lineas[j], columnas)
        valores, _marcas, estado = filas[indice]
        for k, campo in enumerate(campos):
            esperado_v = valores.get(campo["campo"])
            real = celdas[k] if k < len(celdas) else ""
            comprobadas += 1
            if campo["relacion"]:
                cuantas = 0 if real == "" else len(real.split(", "))
                if cuantas != int(esperado_v or 0):
                    fallos.append("{} fila {}: {} trae {} relacionadas y el oraculo {}"
                                  .format(titulo, posicion + 1, campo["campo"], cuantas,
                                          esperado_v))
            elif real != texto_de_valor(esperado_v):
                fallos.append("{} fila {}: {} esperado {!r} obtenido {!r}".format(
                    titulo, posicion + 1, campo["campo"], texto_de_valor(esperado_v), real))
        comprobadas += 1
        real_estado = celdas[len(campos)] if len(celdas) > len(campos) else ""
        if real_estado != texto_de_valor(estado):
            fallos.append("{} fila {}: estado esperado {!r} obtenido {!r}".format(
                titulo, posicion + 1, texto_de_valor(estado), real_estado))
        j += 1
    return comprobadas, fallos, j


def verificar_rejilla(lineas, cuadrante):
    """Compara una rejilla con su cuadrante del oraculo de cruces."""
    titulo = cuadrante["titulo"]
    i = buscar_bloque(lineas, titulo, 0)
    if i is None:
        return 0, ["no esta la rejilla {!r}".format(titulo)]
    columnas = anchos_de_raya(lineas[i + 2])
    encabezados = celdas_de(lineas[i + 1], columnas)
    casillas = {}
    for c in cuadrante["casillas"] or []:
        casillas[(texto_de_valor(c["fila"]), texto_de_valor(c["columna"]))] = \
            " / ".join(texto_de_valor(v) for v in c["valores"])
    comprobadas = 0
    fallos = []
    vistas = set()
    j = i + 3
    while j < len(lineas) and lineas[j].strip():
        celdas = celdas_de(lineas[j], columnas)
        for k in range(1, len(columnas)):
            posicion = (celdas[0], encabezados[k])
            vistas.add(posicion)
            comprobadas += 1
            if celdas[k] != casillas.get(posicion, ""):
                fallos.append("{} ({}, {}): esperado {!r} obtenido {!r}".format(
                    titulo, posicion[0], posicion[1], casillas.get(posicion, ""), celdas[k]))
        j += 1
    for posicion in casillas:
        if posicion not in vistas:
            fallos.append("{}: la casilla {!r} no esta en la rejilla".format(titulo, posicion))
    # Los ejes, en su orden: con un dominio declarado hay filas y columnas
    # sin ninguna casilla ocupada, y solo asi se comprueba que estan.
    if "filas" in cuadrante:
        leidas = [celdas_de(lineas[k], columnas)[0] for k in range(i + 3, j)]
        esperadas = [texto_de_valor(v) for v in cuadrante["filas"] or []]
        comprobadas += 1
        if leidas != esperadas:
            fallos.append("{}: las filas son {!r} y el oraculo dice {!r}".format(
                titulo, leidas, esperadas))
        esperadas = [texto_de_valor(v) for v in cuadrante["columnas"] or []]
        comprobadas += 1
        if encabezados[1:] != esperadas:
            fallos.append("{}: las columnas son {!r} y el oraculo dice {!r}".format(
                titulo, encabezados[1:], esperadas))
    return comprobadas, fallos


def main(argv):
    if len(argv) not in (4, 5):
        print(__doc__)
        return 2
    lineas = Path(argv[1]).read_text(encoding="utf-8").split("\n")
    esperado = json.loads(Path(argv[2]).read_text(encoding="utf-8"))
    vistas = json.loads(Path(argv[3]).read_text(encoding="utf-8"))
    cruces = json.loads(Path(argv[4]).read_text(encoding="utf-8")) if len(argv) == 5 else []
    comprobadas = 0
    fallos = []
    desde = 0
    for tabla in vistas:
        n, f, desde = verificar_tabla(lineas, tabla, esperado, desde)
        comprobadas += n
        fallos.extend(f)
    for vista in cruces:
        for cuadrante in vista["cuadrantes"]:
            n, f = verificar_rejilla(lineas, cuadrante)
            comprobadas += n
            fallos.extend(f)
    filas = sum(len(t["filas"] or []) for t in vistas)
    if filas and comprobadas == 0:
        fallos.append("no se comparo ninguna celda")
    nombre = Path(argv[1]).name
    if fallos:
        print("FALLA  {}: {} celdas comprobadas, {} discrepancias".format(
            nombre, comprobadas, len(fallos)))
        for f in fallos[:25]:
            print("   " + f)
        return 1
    print("  ok   {}: {} celdas del texto coinciden con el evaluador de referencia"
          .format(nombre, comprobadas))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
