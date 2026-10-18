"""Escribir un numero con N decimales fijos, como lo escribe el sistema.

Es la misma regla que NUCLEO:TEXTO-CON-DECIMALES (fase 2, hueco C6): se
redondea al mas cercano y, en el empate, alejandose de cero, sobre la
escritura decimal del numero y no sobre el doble binario. 2.675 con 2
decimales es "2.68" aunque en binario sea 2.67499999...: repr() da la
escritura mas corta que vuelve al mismo doble, y Decimal la toma tal cual.

La usan los verificadores para saber que texto tiene que verse en una celda
de un campo que declara :DECIMALES.
"""

from decimal import ROUND_HALF_UP, Decimal


def texto_con_decimales(valor, n):
    """VALOR con exactamente N decimales, o None si VALOR no es un numero
    (entonces la celda se escribe como cualquier otro valor)."""
    if isinstance(valor, bool) or not isinstance(valor, (int, float)):
        return None
    redondeado = Decimal(repr(valor)).quantize(Decimal(1).scaleb(-n), rounding=ROUND_HALF_UP)
    if redondeado == 0:
        redondeado = abs(redondeado)
    return "{:.{}f}".format(redondeado, n)
