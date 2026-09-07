from openpyxl import Workbook

from departamento.modelo import Profesor, Asignatura, Departamento
from departamento.hoja_datos import construir_hoja_datos


def _departamento():
    return Departamento(
        nombre="Matemática Aplicada", semestre="2026-2027 / 1",
        tope_horas=160, filas_por_profesor=10, filas_carga_reserva=2,
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


def _hoja():
    wb = Workbook()
    wb.remove(wb.active)
    construir_hoja_datos(wb, _departamento())
    return wb, wb["Auxiliar"]


def test_hoja_oculta():
    _, ws = _hoja()
    assert ws.sheet_state == "hidden"


def test_la_auxiliar_ya_no_copia_la_tabla_de_profesores():
    # Desde la fase 3a los profesores viven en la hoja visible `Profesores`, que
    # es quien define ProfesoresValidos y ProfesoresTabla. Aqui solo queda lo
    # derivado de la hoja Asignacion.
    _, ws = _hoja()
    assert ws["A1"].value is None
    assert ws["B1"].value is None


def test_rangos_nombrados():
    wb, _ = _hoja()
    nombres = wb.defined_names
    assert "CargaPorProfesor" in nombres
    # Los de profesores los declara la hoja visible, no esta.
    assert "ProfesoresValidos" not in nombres
    assert "ProfesoresTabla" not in nombres
    # 3 filas de carga (Conf + 2 grupos de CP) + 2 de reserva -> F1:J5. La
    # reserva entra: si no, las filas que se creen a mano no tendrian detalle.
    assert "$F$1:$J$5" in nombres["CargaPorProfesor"].attr_text
    assert "AsignaturaNuevaProfesor" in nombres
    assert "$M$1:$M$5" in nombres["AsignaturaNuevaProfesor"].attr_text


def test_tabla_auxiliar_clave_y_datos():
    _, ws = _hoja()
    # La clave de la fila 1 apunta a la fila 4 de Asignacion y numera las
    # apariciones del profesor con un CONTAR.SI de rango creciente.
    clave = ws["F1"].value
    assert clave.startswith("=IF(")
    assert "Asignación'!$G$4" in clave
    assert "COUNTIF('Asignación'!$G$4:$G$4" in clave
    # La fila 3 cierra el rango creciente en $G$6.
    assert "COUNTIF('Asignación'!$G$4:$G$6" in ws["F3"].value


def test_el_detalle_referencia_a_asignacion_y_no_lo_copia():
    # Desde que Asignacion es editable, una copia escrita al generar se
    # quedaria vieja en cuanto alguien cambiara el id, el tipo o el grupo de
    # una fila. El detalle del reporte de carga leeria entonces datos de otra
    # asignatura sin avisar.
    _, ws = _hoja()
    assert "'Asignación'!B4" in ws["G1"].value     # nombre de la asignatura
    assert "'Asignación'!D4" in ws["H1"].value     # tipo
    assert "'Asignación'!E4" in ws["I1"].value     # grupo
    assert "'Asignación'!F4" in ws["J1"].value     # horas
    assert "'Asignación'!B6" in ws["G3"].value


def test_la_auxiliar_cubre_la_reserva_de_asignacion():
    # 3 filas de carga + 2 de reserva: las filas 4 y 5 de la auxiliar existen.
    _, ws = _hoja()
    assert ws["F5"].value is not None
    assert "'Asignación'!B8" in ws["G5"].value


def test_clave_del_par_profesor_asignatura():
    # Para contar asignaturas distintas por profesor. Vacia si la fila no tiene
    # profesor: una fila sin asignar no cuenta para nadie.
    _, ws = _hoja()
    assert ws["L1"].value == (
        '=IF(OR(\'Asignación\'!$G$4="",\'Asignación\'!$A$4=""),"",'
        '\'Asignación\'!$G$4&"|"&\'Asignación\'!$A$4)')


def test_marca_de_primera_aparicion_del_par():
    # CONTAR.SI de rango creciente: solo la primera fila de cada par se marca,
    # asi que sumar la columna filtrando por profesor da sus asignaturas
    # distintas. La columna devuelve 0 y no "", por eso no sirve para
    # dimensionar nada con CONTARA, pero si como rango de suma de SUMAR.SI.
    _, ws = _hoja()
    assert ws["M1"].value == '=IF(L1="",0,IF(COUNTIF($L$1:$L1,L1)=1,1,0))'
    assert ws["M3"].value == '=IF(L3="",0,IF(COUNTIF($L$1:$L3,L3)=1,1,0))'


def test_la_hoja_de_datos_queda_protegida():
    # Nada es editable a mano en esta hoja oculta: todo son tablas de apoyo.
    _, ws = _hoja()
    assert ws.protection.sheet is True


def test_sin_asignaturas_no_se_declara_el_rango_de_carga():
    # Un departamento recien creado, con profesores pero sin asignaturas, no
    # tiene ninguna fila de carga. Declarar "CargaPorProfesor" sobre un rango
    # vacio dejaria un nombre roto en el libro.
    from dataclasses import replace
    depto = replace(_departamento(), asignaturas=(), filas_carga_reserva=0)
    assert depto.filas() == ()
    wb = Workbook()
    wb.remove(wb.active)
    construir_hoja_datos(wb, depto)
    assert "CargaPorProfesor" not in wb.defined_names


def test_una_referencia_a_celda_vacia_no_muestra_un_cero():
    # En Excel y en Calc, "=A1" sobre una celda vacia muestra 0, no un blanco.
    # Las columnas Tipo y Grupo de Asignacion se escriben a mano y pueden estar
    # vacias: sin la guarda, el bloque de `Carga por profesor` ensena un 0 donde
    # no hay nada.
    _, ws = _hoja()
    for col in ("G", "H", "I", "J"):
        assert ws[f"{col}1"].value.startswith("=IF("), col
        assert '="","",' in ws[f"{col}1"].value, col


def test_la_clave_del_par_exige_las_dos_mitades():
    # Se elige antes el profesor que la asignatura: entre un paso y otro la
    # clave seria "<profesor>|", que contaria como una asignatura distinta y le
    # sumaria una de mas en el panel.
    _, ws = _hoja()
    assert "OR(" in ws["L1"].value
