"""Construye bloques de leyenda (color + descripcion) sobre una worksheet.

Responsabilidad unica: dado un anclaje y una lista de pares (color, texto),
escribe una fila por item con una celda rellena del color y su descripcion en
la celda de al lado. No decide colores ni textos: los recibe ya resueltos."""
from openpyxl.utils.cell import coordinate_to_tuple
from comun import estilos_base as estilos


def escribir_leyenda(ws, celda_ancla: str, items) -> None:
    """Escribe la leyenda a partir de `celda_ancla` (esquina superior izq.).

    `items` es una secuencia de (color_hex, texto). Por cada item se colorea
    la celda de la columna de anclaje y se escribe el texto en la de su
    derecha; se avanza una fila por item.
    """
    fila_ini, col_ini = coordinate_to_tuple(celda_ancla)   # (fila, columna)
    for k, (color, texto) in enumerate(items):
        fila = fila_ini + k
        celda_color = ws.cell(row=fila, column=col_ini)
        celda_color.fill = estilos.fill(color)
        celda_color.border = estilos.borde_fino()
        ws.cell(row=fila, column=col_ini + 1, value=texto)
