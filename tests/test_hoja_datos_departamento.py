from openpyxl import Workbook

from departamento.modelo import Profesor, Asignatura, Departamento
from departamento.hoja_datos import construir_hoja_datos


def _departamento():
    return Departamento(
        nombre="Matemática Aplicada", semestre="2026-2027 / 1",
        tope_horas=160, filas_por_profesor=10,
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
    # 3 filas de carga (Conf + 2 grupos de CP) -> F1:J3.
    assert "$F$1:$J$3" in nombres["CargaPorProfesor"].attr_text


def test_tabla_auxiliar_clave_y_datos():
    _, ws = _hoja()
    # La clave de la fila 1 apunta a la fila 4 de Asignacion y numera las
    # apariciones del profesor con un CONTAR.SI de rango creciente.
    clave = ws["F1"].value
    assert clave.startswith("=IF(")
    assert "Asignación'!$G$4" in clave
    assert "COUNTIF('Asignación'!$G$4:$G$4" in clave
    # La fila 3 cierra el rango creciente en $F$6.
    assert "COUNTIF('Asignación'!$G$4:$G$6" in ws["F3"].value
    # Datos estaticos de la fila de carga: asignatura, tipo, grupo, horas.
    assert ws["G1"].value == "Estadística (CC)"
    assert ws["H1"].value == "Conf"
    assert ws["I1"].value == "-"
    assert ws["J1"].value == 32
    assert ws["H2"].value == "CP"
    assert ws["I2"].value == 1


def test_la_hoja_de_datos_queda_protegida():
    # Nada es editable a mano en esta hoja oculta: todo son tablas de apoyo.
    _, ws = _hoja()
    assert ws.protection.sheet is True


def test_sin_asignaturas_no_se_declara_el_rango_de_carga():
    # Un departamento recien creado, con profesores pero sin asignaturas, no
    # tiene ninguna fila de carga. Declarar "CargaPorProfesor" sobre un rango
    # vacio dejaria un nombre roto en el libro.
    from dataclasses import replace
    depto = replace(_departamento(), asignaturas=())
    assert depto.filas() == ()
    wb = Workbook()
    wb.remove(wb.active)
    construir_hoja_datos(wb, depto)
    assert "CargaPorProfesor" not in wb.defined_names
