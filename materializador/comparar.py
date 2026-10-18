"""Como se iguala un valor leido del libro con uno del oraculo.

Lo usan todas las comprobaciones del libro (hojas de datos, tablas cruzadas,
relaciones) para que las tres apliquen exactamente el mismo criterio.

LOS NUMEROS SE COMPARAN CON TOLERANCIA RELATIVA

El evaluador de referencia calcula en doble precision, igual que Excel y
LibreOffice. Pero LibreOffice guarda en el archivo quince cifras
significativas, y el evaluador escribe diecisiete: 52.333333333333336 frente
a 52.3333333333333. Esa diferencia no es de semantica sino de cuantas cifras
se escriben, asi que dos numeros son iguales si difieren en menos de una
parte en mil millones.
"""

import math

TOLERANCIA_RELATIVA = 1e-9


def normalizar(valor):
    """El valor en una forma comparable: numero, texto sin espacios a los
    lados, o cadena vacia para lo que no tiene nada."""
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


def iguales(a, b):
    """Cierto si A y B, ya normalizados, valen lo mismo."""
    if isinstance(a, float) and isinstance(b, float):
        return math.isclose(a, b, rel_tol=TOLERANCIA_RELATIVA, abs_tol=1e-12)
    return a == b
