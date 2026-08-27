"""Ajustes de como se ve y se navega una hoja: cuadricula y color de pestana.
No tocan el contenido ni el formato de las celdas; eso es de `formato.py`."""


def ocultar_cuadricula(ws) -> None:
    """Quita las lineas de cuadricula de fondo. En las hojas de reporte, donde
    todo va bordeado, la cuadricula compite con los bordes de las tablas."""
    ws.sheet_view.showGridLines = False


def colorear_pestana(ws, color: str) -> None:
    """Pinta la pestana de la hoja (color RRGGBB sin almohadilla). Con una hoja
    por grupo o por dia, la barra de pestanas es un muro de nombres; el color
    agrupa de un vistazo."""
    ws.sheet_properties.tabColor = color
