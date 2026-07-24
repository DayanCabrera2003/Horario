from openpyxl.workbook.defined_name import DefinedName
from openpyxl.utils import quote_sheetname, absolute_coordinate
from tribunales.modelo import Facultad

NOMBRE_HOJA = "Datos"


def _rango_nombrado(nombre: str, celda_ini: str, celda_fin: str) -> DefinedName:
    ref = (f"{quote_sheetname(NOMBRE_HOJA)}!"
           f"{absolute_coordinate(celda_ini)}:{absolute_coordinate(celda_fin)}")
    return DefinedName(nombre, attr_text=ref)


def construir_hoja_datos(wb, facultad: Facultad) -> None:
    """Crea la hoja oculta Datos: tabla tesis->tribunal (A..E) y lista de ids de
    estudiantes (columna G), cada una con su rango nombrado."""
    ws = wb.create_sheet(NOMBRE_HOJA)
    ws.sheet_state = "hidden"

    # Tabla tesis->tribunal, una fila por tesis, sin encabezado (VLOOKUP directo).
    for i, t in enumerate(facultad.tesis, start=1):
        ws[f"A{i}"] = t.estudiante
        ws[f"B{i}"] = t.tutor
        ws[f"C{i}"] = t.oponente
        ws[f"D{i}"] = t.presidente
        ws[f"E{i}"] = t.secretario
    n_tesis = len(facultad.tesis)
    if n_tesis:
        wb.defined_names.add(_rango_nombrado("TesisTribunal", "A1", f"E{n_tesis}"))

    # Lista de ids de estudiantes en columna G (F en blanco de separacion).
    for i, e in enumerate(facultad.estudiantes, start=1):
        ws[f"G{i}"] = e.id
    n_est = len(facultad.estudiantes)
    if n_est:
        wb.defined_names.add(_rango_nombrado("EstudiantesValidos", "G1", f"G{n_est}"))
