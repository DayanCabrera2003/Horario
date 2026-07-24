from openpyxl import Workbook
from tribunales.modelo import Estudiante, Tesis, Facultad, Profesor
from tribunales.hoja_datos import construir_hoja_datos, NOMBRE_HOJA


def _fac():
    return Facultad(
        profesores=(Profesor("PIAD", "P", "Dr."),),
        estudiantes=(Estudiante("JPER", "Juan"),),
        locales=(),
        dias=(),
        tesis=(Tesis("JPER", "PIAD", "PIAD", "PIAD", "PIAD"),),
    )


def test_hoja_datos_oculta_y_con_tabla_tesis():
    wb = Workbook()
    wb.remove(wb.active)
    construir_hoja_datos(wb, _fac())
    ws = wb[NOMBRE_HOJA]
    assert ws.sheet_state == "hidden"
    assert ws["A1"].value == "JPER"   # estudiante de la primera tesis
    assert ws["B1"].value == "PIAD"   # tutor


def test_rangos_nombrados_definidos():
    wb = Workbook()
    wb.remove(wb.active)
    construir_hoja_datos(wb, _fac())
    assert "TesisTribunal" in wb.defined_names
    assert "EstudiantesValidos" in wb.defined_names
