from openpyxl import Workbook
from horarios import estilos, formato


def test_aplicar_borde_pone_borde_en_cada_celda_del_rango():
    wb = Workbook()
    ws = wb.active
    formato.aplicar_borde(ws, "B2:C3", estilos.borde_fino())
    for coord in ("B2", "C2", "B3", "C3"):
        assert ws[coord].border.left.style == "thin"


def test_aplicar_borde_no_afecta_celdas_fuera_del_rango():
    wb = Workbook()
    ws = wb.active
    formato.aplicar_borde(ws, "B2:C3", estilos.borde_fino())
    assert ws["A1"].border.left.style is None
