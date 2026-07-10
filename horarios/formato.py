"""Utilidades para aplicar formato de presentacion (bordes, ancho de columnas)
sobre una worksheet ya construida. Separado de `estilos`, que solo define objetos
de estilo puros, y de `layout`, que solo calcula posiciones."""
from openpyxl.styles import Border


def aplicar_borde(ws, rango: str, borde: Border) -> None:
    """Aplica `borde` a cada celda del `rango` (p. ej. "C3:D15").

    openpyxl no tiene un borde "de rango": el borde es un estilo por celda, asi que
    se recorre el rango y se asigna a cada una.
    """
    for fila in ws[rango]:
        for celda in fila:
            celda.border = borde


def autoajustar_columnas(ws, min_ancho: int = 8, max_ancho: int = 45,
                         extra: int = 2) -> None:
    """Fija el ancho de cada columna al del texto mas largo que contiene.

    openpyxl no tiene "autofit" real (requiere renderizar), asi que se estima por
    longitud de caracteres. Las formulas ("=...") se ignoran: su texto no coincide con
    el valor que se muestra e inflaria la columna. El ancho se limita a [min_ancho, max_ancho].
    """
    largos: dict[str, int] = {}
    for fila in ws.iter_rows():
        for celda in fila:
            valor = celda.value
            if valor is None:
                continue
            if isinstance(valor, str) and valor.startswith("="):
                continue
            largo = len(str(valor))
            if largo > largos.get(celda.column_letter, 0):
                largos[celda.column_letter] = largo
    for letra, largo in largos.items():
        ws.column_dimensions[letra].width = min(max_ancho, max(min_ancho, largo + extra))
