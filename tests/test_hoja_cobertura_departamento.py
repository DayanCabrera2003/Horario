from openpyxl import Workbook

from departamento.modelo import Profesor, Asignatura, Departamento
from departamento.hoja_datos import construir_hoja_datos
from departamento.hoja_asignacion import construir_hoja_asignacion
from departamento.hoja_cobertura import construir_hoja_cobertura
from departamento import estilos
from departamento import layout as L


def _departamento():
    return Departamento(
        nombre="Matemática Aplicada", semestre="2026-2027 / 1",
        tope_horas=160, filas_por_profesor=10,
        profesores=(Profesor(id="PIAD", nombre="Pedro I. Alonso", grado="Dr."),),
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
    construir_hoja_cobertura(wb, depto)
    return wb["Cobertura por asignatura"]


def test_bloques_por_asignatura():
    ws = _hoja()
    # EST-CC: titulo en 3, subcabecera en 4, filas 5..7 (Conf + 2 CP).
    assert "Estadística (CC)" in ws["A3"].value
    assert "Ciencia de la Computación" in ws["A3"].value
    assert [c.value for c in ws["A4":"E4"][0]] == [
        "Tipo", "Grupo", "Horas", "Profesor", "Nombre"]
    assert [ws[f"A{r}"].value for r in (5, 6, 7)] == ["Conf", "CP", "CP"]
    assert ws["B6"].value == 1
    assert ws["C5"].value == 32
    # EST-MAT: bloque siguiente (altura previa 6) -> titulo en 9.
    assert "Estadística (Mat)" in ws["A9"].value
    assert [ws[f"A{r}"].value for r in (11, 12)] == ["Conf", "CP"]


def test_profesor_referencia_a_asignacion():
    ws = _hoja()
    # La fila Conf de EST-CC es la fila de carga 4 de Asignacion. El IF evita
    # que una celda vacia se muestre como 0.
    assert ws["D5"].value == "=IF('Asignación'!F4=\"\",\"\",'Asignación'!F4)"
    assert ws["E5"].value == "='Asignación'!G4"
    # La fila CP de EST-MAT es la fila de carga 8.
    assert "'Asignación'!F8" in ws["D12"].value


def test_titulo_coloreado_por_completitud():
    ws = _hoja()
    reglas = []
    for rango, lista in ws.conditional_formatting._cf_rules.items():
        for regla in lista:
            reglas.append((str(rango.sqref), regla.formula[0],
                           regla.dxf.fill.start_color.rgb[-6:]))
    # Verde si ninguna fila de EST-CC (F4:F6 de Asignacion) esta en blanco.
    assert ("A3:E3", "COUNTBLANK('Asignación'!$F$4:$F$6)=0",
            estilos.COLOR_COMPLETA) in reglas
    assert ("A3:E3", "COUNTBLANK('Asignación'!$F$4:$F$6)>0",
            estilos.COLOR_INCOMPLETA) in reglas
    # EST-MAT evalua sus propias filas (F7:F8).
    assert ("A9:E9", "COUNTBLANK('Asignación'!$F$7:$F$8)=0",
            estilos.COLOR_COMPLETA) in reglas


def test_alto_de_filas_para_padding():
    ws = _hoja()
    # Bloques de la fila 3 a la 12 (ultima fila de carga): filas mas altas.
    assert ws.row_dimensions[3].height == estilos.ALTO_FILA
    assert ws.row_dimensions[12].height == estilos.ALTO_FILA


def test_leyenda():
    ws = _hoja()
    # Ultimo bloque termina en la fila 12; leyenda dos filas despues.
    textos = [(ws[f"B{r}"].value or "") for r in (14, 15)]
    assert any("completa" in t.lower() for t in textos)


def test_la_hoja_de_asignaturas_queda_protegida():
    # Nada es editable a mano en esta hoja: todo son referencias a Asignacion.
    ws = _hoja()
    assert ws.protection.sheet is True


def test_las_horas_llevan_formato_de_numero_entero():
    ws = _hoja()
    fila = L.asig_fila_carga(0, 0)
    assert ws[f"C{fila}"].number_format == "0"


def test_la_hoja_no_muestra_cuadricula():
    assert _hoja().sheet_view.showGridLines is False
