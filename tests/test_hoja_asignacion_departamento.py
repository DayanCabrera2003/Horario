from openpyxl import Workbook

from departamento.modelo import Profesor, Asignatura, Departamento
from departamento.hoja_datos import construir_hoja_datos
from departamento.hoja_asignacion import construir_hoja_asignacion
from departamento import estilos
from departamento import layout as L


def _departamento():
    return Departamento(
        nombre="Matemática Aplicada", semestre="2026-2027 / 1",
        tope_horas=160, filas_por_profesor=10, filas_carga_reserva=2,
        profesores=(
            Profesor(id="PIAD", nombre="Pedro I. Alonso", grado="Dr."),
            Profesor(id="MARA", nombre="Maria Ramirez", grado="MSc."),
        ),
        asignaturas=(
            Asignatura(id="EST-CC", nombre="Estadística (CC)",
                       carrera="Ciencia de la Computación",
                       horas_conf=32, horas_cp=32, grupos_cp=2),
            Asignatura(id="EST-MAT", nombre="Estadística (Mat)",
                       carrera="Matemática", horas_conf=32, horas_cp=32,
                       grupos_cp=1),
        ),
    )


def _hoja():
    wb = Workbook()
    wb.remove(wb.active)
    depto = _departamento()
    construir_hoja_datos(wb, depto)
    construir_hoja_asignacion(wb, depto)
    return wb["Asignación"]


def test_titulo_y_encabezados():
    ws = _hoja()
    assert "Matemática Aplicada" in ws["A1"].value
    assert "2026-2027 / 1" in ws["A1"].value
    assert [c.value for c in ws["A3":"H3"][0]] == [
        "Id", "Asignatura", "Carrera", "Tipo", "Grupo", "Horas", "Profesor",
        "Nombre"]


def test_filas_de_carga():
    ws = _hoja()
    # 5 filas: EST-CC (Conf, CP-1, CP-2) + EST-MAT (Conf, CP-1).
    assert ws["A4"].value == "EST-CC"
    assert [ws[f"D{r}"].value for r in range(4, 9)] == [
        "Conf", "CP", "CP", "Conf", "CP"]
    assert ws["E4"].value == "-"
    assert ws["E6"].value == 2
    assert ws["A8"].value == "EST-MAT"
    # La celda de profesor queda vacia (la decision se toma en el Excel).
    assert ws["G4"].value is None


def test_el_id_es_el_dato_y_lo_demas_se_calcula():
    # Asi, renombrar una asignatura o corregir sus horas en la hoja Asignaturas
    # se propaga aqui; una copia estatica se quedaria vieja.
    ws = _hoja()
    assert ws["B4"].value == (
        '=IF($A4="","",IFERROR(VLOOKUP($A4,AsignaturasTabla,2,0),""))')
    assert ws["C4"].value == (
        '=IF($A4="","",IFERROR(VLOOKUP($A4,AsignaturasTabla,3,0),""))')


def test_las_horas_dependen_del_tipo():
    ws = _hoja()
    formula = ws["F4"].value
    assert formula.startswith('=IF($A4="","",')
    assert '$D4="Conf"' in formula
    assert "AsignaturasTabla,4,0" in formula   # horas de Conf
    assert "AsignaturasTabla,5,0" in formula   # horas de un grupo de CP


def test_filas_de_reserva_vacias_pero_con_sus_formulas():
    # 5 filas de carga + 2 de reserva -> filas 9 y 10 libres. Escribir en ellas
    # un id, un tipo y un grupo basta para crear una fila de carga nueva.
    ws = _hoja()
    assert ws["A9"].value is None
    assert ws["D9"].value is None
    assert ws["B9"].value.startswith("=")
    assert ws["F9"].value.startswith("=")
    assert ws["H9"].value.startswith("=")


def test_formula_nombre_profesor():
    ws = _hoja()
    formula = ws["H4"].value
    assert formula.startswith('=IF($G4=')
    assert "VLOOKUP($G4,ProfesoresTabla,2,0)" in formula


def test_desplegables_no_bloqueantes():
    ws = _hoja()
    dvs = {dv.formula1: dv for dv in ws.data_validations.dataValidation}
    assert set(dvs) == {"AsignaturasValidas", '"Conf,CP"', "ProfesoresValidos"}
    for fuente, dv in dvs.items():
        # Aviso y no veto: hay que poder escribir un id que todavia no esta en
        # la lista sin que Calc lo rechace.
        assert dv.errorStyle == "information", fuente
    # Cubren la reserva tambien: si no, las filas nuevas no tendrian ayuda.
    assert "A4:A10" in str(dvs["AsignaturasValidas"].sqref)
    assert "G4:G10" in str(dvs["ProfesoresValidos"].sqref)


def _reglas(ws):
    reglas = {}
    for rango, lista in ws.conditional_formatting._cf_rules.items():
        for regla in lista:
            color = regla.dxf.fill.start_color.rgb[-6:]
            reglas.setdefault(color, []).append(
                (str(rango.sqref), regla.formula[0]))
    return reglas


def test_formato_condicional_fila_completa():
    ws = _hoja()
    reglas = _reglas(ws)
    sq_amarillo, f_amarillo = reglas[estilos.COLOR_SIN_PROFESOR][0]
    assert sq_amarillo == "A4:H10"
    # La guarda del id: una fila de reserva no esta "sin profesor", esta vacia.
    assert f_amarillo == 'AND($A4<>"",$G4="")'
    ambar = reglas[estilos.COLOR_PROFESOR_DESCONOCIDO]
    assert all(sq == "A4:H10" for sq, _ in ambar)
    formulas = [f for _, f in ambar]
    assert any("COUNTIF(ProfesoresValidos,$G4)=0" in f for f in formulas)
    # El id de asignatura tambien se escribe a mano: tambien puede ser erroneo.
    assert any("COUNTIF(AsignaturasValidas,$A4)=0" in f for f in formulas)


def test_linea_gruesa_entre_asignaturas():
    ws = _hoja()
    # EST-CC termina en la fila 6: linea gruesa debajo, en toda la fila.
    assert ws["A6"].border.bottom.style == "thick"
    assert ws["H6"].border.bottom.style == "thick"
    # Dentro de una asignatura el enrejado sigue fino, y el final de la tabla
    # (ahora la ultima fila de reserva) conserva el perimetro medio.
    assert ws["A5"].border.bottom.style == "thin"
    assert ws["A10"].border.bottom.style == "medium"


def test_la_reserva_no_lleva_separador():
    # La linea gruesa agrupa filas de una misma asignatura. Las de reserva no
    # tienen asignatura todavia, asi que no hay nada que separar.
    ws = _hoja()
    assert ws["A8"].border.bottom.style == "thin"


def test_leyenda_y_paneles():
    ws = _hoja()
    assert ws.freeze_panes == "A4"
    textos = [ws[f"B{r}"].value for r in range(12, 16)]
    assert any("profesor" in (t or "").lower() for t in textos)


def test_la_hoja_de_asignacion_queda_protegida():
    ws = _hoja()
    assert ws.protection.sheet is True


def test_solo_se_editan_las_cuatro_columnas_de_decision():
    ws = _hoja()
    for col in ("A", "D", "E", "G"):             # id, tipo, grupo, profesor
        assert ws[f"{col}4"].protection.locked is False, col
        assert ws[f"{col}10"].protection.locked is False, col   # y la reserva
    for col in ("B", "C", "F", "H"):             # todo lo que es formula
        assert ws[f"{col}4"].protection.locked is True, col


def test_las_horas_llevan_formato_de_numero_entero():
    # Sin formato explicito, una hora puede acabar mostrandose como "32,00" en
    # Calc segun la configuracion regional de quien abra el libro.
    ws = _hoja()
    assert ws[f"{L.COL_HORAS}{L.FILA_PRIMERA_CARGA}"].number_format == "0"


def test_la_hoja_lleva_autofiltro_sobre_toda_la_tabla():
    # Del encabezado a la ultima fila de reserva; el fixture tiene 5 de carga
    # y 2 libres. El panel de profesores queda fuera, tras la canaleta.
    ws = _hoja()
    assert ws.auto_filter.ref == "A3:H10"


def test_la_hoja_deja_filtrar_pero_no_ordenar():
    # Cada fila de Asignacion tiene una gemela por posicion en la hoja Auxiliar.
    # Filtrar solo esconde filas, pero ordenar las moveria y la gemela pasaria
    # a leer la fila equivocada sin avisar.
    ws = _hoja()
    assert ws.protection.autoFilter is False   # filtrar: permitido
    assert ws.protection.sort is True          # ordenar: prohibido
