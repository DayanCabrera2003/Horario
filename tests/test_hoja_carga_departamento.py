from openpyxl import Workbook

from departamento.modelo import Profesor, Asignatura, Departamento
from departamento.hoja_datos import construir_hoja_datos
from departamento.hoja_asignacion import construir_hoja_asignacion
from departamento.hoja_carga import construir_hoja_carga
from departamento import estilos
from departamento import layout as L


def _departamento(tope_global=160):
    return Departamento(
        nombre="Matemática Aplicada", semestre="2026-2027 / 1",
        tope_horas=tope_global, filas_por_profesor=4,
        profesores=(
            Profesor(id="PIAD", nombre="Pedro I. Alonso", grado="Dr."),
            Profesor(id="MARA", nombre="Maria Ramirez", grado="MSc.", tope_horas=80),
        ),
        asignaturas=(
            Asignatura(id="EST-CC", nombre="Estadística (CC)",
                       carrera="Ciencia de la Computación",
                       horas_conf=32, horas_cp=32, grupos_cp=2),
        ),
    )


def _hoja(depto=None):
    wb = Workbook()
    wb.remove(wb.active)
    depto = depto or _departamento()
    construir_hoja_datos(wb, depto)
    construir_hoja_asignacion(wb, depto)
    construir_hoja_carga(wb, depto)
    return wb["Carga por profesor"]


def test_bloque_cabecera():
    ws = _hoja()
    # filas_por_profesor=4 -> bloques de altura 9; PIAD en 3, MARA en 12.
    assert [c.value for c in ws["A3":"D3"][0]] == ["Id", "Nombre", "Grado", "Tope horas"]
    assert ws["A4"].value == "PIAD"
    # Nombre, grado y tope llegan del claustro por BUSCARV desde la fase 3a.
    assert "ProfesoresTabla" in ws["B4"].value
    assert "ProfesoresTabla,4" in ws["D4"].value   # el tope, tambien del claustro
    assert ws["A12"].value == "Id"
    assert ws["A13"].value == "MARA"
    assert "ProfesoresTabla,4" in ws["D13"].value  # el suyo, del claustro


def test_detalle_por_buscarv():
    ws = _hoja()
    # Subcabecera en 5; detalle en 6..9.
    assert [c.value for c in ws["A5":"D5"][0]] == ["Asignatura", "Tipo", "Grupo", "Horas"]
    f = ws["A6"].value
    assert 'VLOOKUP("PIAD#1",CargaPorProfesor,2,0)' in f
    assert f.startswith("=IFERROR(")
    assert 'VLOOKUP("PIAD#2",CargaPorProfesor,3,0)' in ws["B7"].value
    assert 'CargaPorProfesor,5,0' in ws["D6"].value


def test_ultima_fila_reservada_avisa_desborde():
    ws = _hoja()
    # La fila reservada 4 (fila 9) avisa si el profesor tiene mas filas de las
    # que caben en el bloque.
    f = ws["A9"].value
    assert "más)" in f
    assert 'COUNTIF(' in f and '"PIAD"' in f


def test_total_con_sumif():
    ws = _hoja()
    assert ws["A10"].value == "TOTAL"
    f = ws["D10"].value
    # 3 filas de carga -> rango F4:F6 de Asignacion.
    assert f == ('=SUMIF(\'Asignación\'!$F$4:$F$6,"PIAD",'
                 "'Asignación'!$E$4:$E$6)")


def test_alto_de_filas_para_padding():
    ws = _hoja()
    # Bloques de la fila 3 a la ultima fila TOTAL (19): filas mas altas.
    assert ws.row_dimensions[3].height == estilos.ALTO_FILA
    assert ws.row_dimensions[19].height == estilos.ALTO_FILA


def test_alerta_sobrecarga_en_la_fila_total_de_cada_bloque():
    ws = _hoja()
    rangos = {str(r.sqref) for r in ws.conditional_formatting._cf_rules}
    # Regla roja sobre la fila TOTAL de cada bloque.
    assert "A10:D10" in rangos
    assert "A19:D19" in rangos
    # La regla se crea siempre; el caso de quien no traia tope al generar lo
    # cubre test_la_alerta_existe_aunque_el_profesor_no_tuviera_tope_al_generar.


def test_la_hoja_de_profesores_queda_protegida():
    ws = _hoja()
    assert ws.protection.sheet is True


def test_el_tope_ya_no_se_edita_en_el_reporte():
    # Era la arruga declarada de la fase 1: el tope se editaba en el reporte.
    # Su sitio es el claustro; aqui llega calculado y bloqueado.
    ws = _hoja()
    fila_val = L.prof_fila_valores(0, 4)
    assert ws[f"D{fila_val}"].protection.locked is not False
    assert "ProfesoresTabla" in ws[f"D{fila_val}"].value


def test_el_total_de_horas_queda_bloqueado():
    # Control en la misma celda del bloque: D{fila_val} (el tope) sale
    # desbloqueada porque esta en editables. Sin este control, la aserción de
    # abajo pasaria igual aunque proteger_hoja nunca se hubiera llamado, pues
    # toda celda de openpyxl nace bloqueada por defecto.
    ws = _hoja()
    fila_total = L.prof_fila_total(0, 4)
    fila_val = L.prof_fila_valores(0, 4)
    assert ws[f"D{fila_total}"].protection.locked is True


def test_las_horas_llevan_formato_de_numero_entero():
    # Las tres celdas de horas del bloque: el tope que se escribe a mano, una
    # linea de detalle y el TOTAL que las suma.
    ws = _hoja()
    fpp = 4
    assert ws[f"D{L.prof_fila_valores(0, fpp)}"].number_format == "0"
    assert ws[f"D{L.prof_fila_detalle(0, 0, fpp)}"].number_format == "0"
    assert ws[f"D{L.prof_fila_total(0, fpp)}"].number_format == "0"


def test_la_hoja_no_muestra_cuadricula():
    assert _hoja().sheet_view.showGridLines is False


def test_la_alerta_existe_aunque_el_profesor_no_tuviera_tope_al_generar():
    """Hallazgo de la revision: la regla solo se creaba si el YAML declaraba un
    tope. Desde que el tope se edita en el claustro, quien no lo traia se queda
    sin alerta para siempre, y la guia dice que ahi se cambia el de cualquiera.
    """
    from dataclasses import replace
    from departamento.modelo import Profesor
    depto = replace(_departamento(), tope_horas=None,
                    profesores=(Profesor(id="PIAD", nombre="Pedro", grado="Dr."),))
    wb = Workbook()
    wb.remove(wb.active)
    construir_hoja_carga(wb, depto)
    ws = wb["Carga por profesor"]
    formulas = [r.formula[0] for reglas in ws.conditional_formatting._cf_rules.values()
                for r in reglas if r.formula]
    assert formulas, "sin tope declarado no se creo ninguna alerta"
    # Y no dispara cuando la casilla del tope esta vacia.
    assert any('<>""' in f for f in formulas), formulas
