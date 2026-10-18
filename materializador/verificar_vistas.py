"""Comprueba las hojas derivadas de las vistas de lista.

Una vista de lista que no es la de datos de su coleccion sale en la hoja de
calculo como una hoja derivada: cada celda apunta a la de la hoja de datos, y
las filas van en el orden de su agrupacion, con una cabecera por grupo. El
plano dice, para cada linea de la hoja derivada, que fila de la coleccion
presenta; aqui se comprueba cada celda contra esa fila del oraculo, y que el
orden sea el que dice el oraculo de vistas.
"""

from comparar import iguales, normalizar


def verificar_vista(hoja_plan, hoja, esperado, vistas=None):
    """Compara una hoja derivada con el oraculo. Devuelve (comprobadas, fallos)."""
    identidad = hoja_plan["vista"]
    filas_esperadas = esperado.get(identidad["coleccion"])
    if filas_esperadas is None:
        return 0, ["{}: el oraculo no trae la coleccion {!r}".format(
            hoja.title, identidad["coleccion"])]
    columnas = {}
    for enc in hoja_plan.get("encabezados") or []:
        if not enc["campo"].startswith("__"):
            columnas[enc["campo"]] = "".join(c for c in enc["celda"] if c.isalpha())
    fallos = []
    comprobadas = 0
    filas = identidad["filas"] or []
    if vistas is not None:
        tabla = next((t for t in vistas if t["vista"] == identidad["vista"]), None)
        orden = [f["indice"] for f in filas]
        if tabla is None:
            fallos.append("{}: el oraculo de vistas no trae la vista {!r}".format(
                hoja.title, identidad["vista"]))
        elif orden != (tabla["filas"] or []):
            fallos.append("{}: las filas van en otro orden que el del oraculo".format(
                hoja.title))
    for f in filas:
        envoltura = filas_esperadas[f["indice"]]
        valores = envoltura[0] if isinstance(envoltura, list) else envoltura
        for campo, letra in columnas.items():
            if campo not in valores:
                continue
            real = normalizar(hoja["{}{}".format(letra, f["fila"])].value)
            esperado_v = normalizar(valores[campo])
            comprobadas += 1
            if not iguales(real, esperado_v):
                fallos.append("{}!{}{}  esperado {!r}  obtenido {!r}".format(
                    hoja.title, letra, f["fila"], esperado_v, real))
        estado = identidad.get("estado")
        if estado and isinstance(envoltura, list) and len(envoltura) > 2:
            real = normalizar(hoja["{}{}".format(estado, f["fila"])].value)
            comprobadas += 1
            if not iguales(real, normalizar(envoltura[2])):
                fallos.append("{}!{}{}  estado esperado {!r}  obtenido {!r}".format(
                    hoja.title, estado, f["fila"], normalizar(envoltura[2]), real))
    if filas and comprobadas == 0:
        fallos.append("{}: no se comparo ninguna celda".format(hoja.title))
    return comprobadas, fallos
