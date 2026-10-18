"""Busca errores de formula en todo el libro recalculado.

EL PROBLEMA QUE RESUELVE

Comparar contra el oraculo solo mira las celdas que el oraculo describe. Una
formula rota en una celda que el oraculo no nombra -una columna de clave, una
linea de un bloque de detalle, la casilla de una rejilla que deberia quedar
en blanco- pasaba sin que nadie la viera. Aqui se recorre el libro entero, y
cualquier celda que valga un error de formula es un fallo, este o no en el
oraculo.
"""

ERRORES_DE_FORMULA = (
    "#VALUE!", "#NAME?", "#REF!", "#N/A", "#DIV/0!", "#NUM!", "#NULL!",
    "Err:", "#ERR",
)


def es_error(valor):
    """Cierto si VALOR es el resultado de una formula que fallo."""
    if not isinstance(valor, str):
        return False
    return any(valor.startswith(e) for e in ERRORES_DE_FORMULA)


def errores_del_libro(libro):
    """Las celdas del LIBRO recalculado que valen un error, como textos
    'Hoja!A1  #VALUE!'. Mira todas las hojas, ocultas incluidas."""
    encontrados = []
    for hoja in libro.worksheets:
        for fila in hoja.iter_rows():
            for celda in fila:
                if celda.data_type == "e" or es_error(celda.value):
                    encontrados.append("{}!{}  {}".format(
                        hoja.title, celda.coordinate, celda.value))
    return encontrados
