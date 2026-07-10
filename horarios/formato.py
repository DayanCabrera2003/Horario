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
