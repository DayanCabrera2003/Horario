from openpyxl.utils import quote_sheetname, absolute_coordinate
from tribunales import layout as L
from tribunales.modelo import Facultad

NOMBRE_HOJA = "Localizar"


def construir_hoja_localizar(wb, facultad: Facultad) -> None:
    """Crea la hoja Localizar: celda de entrada global (B1) y una tabla de una
    columna por cada (dia, local), con una fila por momento del dia."""
    ws = wb.create_sheet(NOMBRE_HOJA)
    ws["A1"] = "Localizar a:"
    ws[L.LOCALIZAR_CELDA_ENTRADA] = ""   # celda de entrada global

    # Referencia absoluta de la entrada, "$B$1" (no "$B1"): la usa el formato
    # condicional de participacion.
    entrada = absolute_coordinate(L.LOCALIZAR_CELDA_ENTRADA)
    alturas = 0
    for dia in facultad.dias:
        n_mom = len(dia.momentos)
        for li, local in enumerate(facultad.locales):
            f_tit = L.localizar_fila_titulo(0, alturas)
            ws[f"{L.LOCALIZAR_COL}{f_tit}"] = f"{dia.fecha} · {local.nombre}"
            for mi, momento in enumerate(dia.momentos):
                f = f_tit + 1 + mi
                ws[f"{L.LOCALIZAR_COL}{f}"] = momento.id
                # (F2 anadira aqui el formato condicional de participacion)
            alturas += L.localizar_altura_tabla(n_mom)
