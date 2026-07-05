from openpyxl import Workbook
from horarios.modelo import Grupo, Anio, Facultad
from horarios.hoja_datos import construir_hoja_datos, NOMBRE_HOJA


def _fac():
    g = [Grupo("C", 1, 1, 1), Grupo("M", 1, 1, 1)]
    anios = {"C1": Anio("C", 1, ()), "M1": Anio("M", 1, ())}
    return Facultad(aulas=("Aula 1", "Lab"), dias=("Lunes",), turnos=2, grupos=tuple(g), anios=anios)


def test_crea_hoja_oculta_y_lista_aulas():
    fac = _fac(); wb = Workbook()
    construir_hoja_datos(wb, fac)
    ws = wb[NOMBRE_HOJA]
    assert ws.sheet_state == "hidden"
    valores = [c.value for col in ws.iter_cols() for c in col]
    assert "Aula 1" in valores and "Lab" in valores


def test_rango_nombrado_aulas_validas():
    fac = _fac(); wb = Workbook()
    construir_hoja_datos(wb, fac)
    assert "AulasValidas" in wb.defined_names


def test_firma_usa_countif():
    fac = _fac(); wb = Workbook()
    celdas = construir_hoja_datos(wb, fac)
    # celdas: {(dia, turno, aula): direccion_de_la_firma}
    dir_firma = celdas[("Lunes", 1, "Aula 1")]   # p.ej. "Datos!C1" (referencia calificada)
    ws = wb[NOMBRE_HOJA]
    coord_local = dir_firma.split("!")[1]         # indexar la hoja con la coord local, no "Datos!C1"
    assert ws[coord_local].value.startswith("=")
    assert "COUNTIF" in ws[coord_local].value
