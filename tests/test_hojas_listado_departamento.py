"""Tests de las hojas de listado del generador del departamento.

Son el pedido 1 del tutor: un listado de profesores con su grado y su tope de
horas. Hasta ahora esos datos solo existian como cabecera de cada bloque del
reporte de carga, uno por profesor, que no es un listado.
"""
from openpyxl import Workbook

from departamento.hoja_profesores import construir_hoja_profesores
from departamento.hoja_asignaturas import construir_hoja_asignaturas
from departamento.modelo import Profesor, Asignatura, Departamento

DEPTO = Departamento(
    nombre="Matemática Aplicada", semestre="2026-2027 / 1",
    tope_horas=160, filas_por_profesor=10,
    profesores=(Profesor(id="PIAD", nombre="Pedro I. Alonso Diaz", grado="Dr."),
                Profesor(id="ANSU", nombre="Ana Suarez", grado="MSc.", tope_horas=80)),
    asignaturas=(Asignatura(id="EST-CC", nombre="Estadística (CC)",
                            carrera="Ciencia de la Computación",
                            horas_conf=32, horas_cp=32, grupos_cp=2),),
)

SIN_TOPE = Departamento(
    nombre="D", semestre="1", tope_horas=None, filas_por_profesor=10,
    profesores=(Profesor(id="PIAD", nombre="Pedro", grado="Dr."),),
    asignaturas=DEPTO.asignaturas,
)


def _hoja(constructor, depto=DEPTO):
    wb = Workbook()
    wb.remove(wb.active)
    constructor(wb, depto)
    return wb[wb.sheetnames[0]]


def test_profesores_lista_grado_y_tope():
    ws = _hoja(construir_hoja_profesores)
    assert ws.title == "Profesores"
    assert [c.value for c in ws[1][:5]] == ["Id", "Nombre", "Grado",
                                            "Tope horas", "Origen del tope"]
    assert ws["A2"].value == "PIAD"
    assert ws["C2"].value == "Dr."


def test_el_tope_heredado_se_distingue_del_propio():
    # Es la pregunta que se hace quien mira la columna: ese 160, ¿lo declaro el
    # profesor o le viene del departamento?
    ws = _hoja(construir_hoja_profesores)
    assert ws["D2"].value == 160
    assert ws["E2"].value == "Del departamento"
    assert ws["D3"].value == 80
    assert ws["E3"].value == "Propio"


def test_sin_ningun_tope_la_columna_lo_dice():
    ws = _hoja(construir_hoja_profesores, SIN_TOPE)
    assert ws["D2"].value == ""
    assert ws["E2"].value == "Sin tope"


def test_asignaturas_lista_las_horas_declaradas():
    ws = _hoja(construir_hoja_asignaturas)
    assert ws.title == "Asignaturas"
    assert [c.value for c in ws[1][:7]] == ["Id", "Nombre", "Carrera",
                                            "Horas Conf", "Horas CP por grupo",
                                            "Grupos CP", "Total"]
    assert ws["A2"].value == "EST-CC"
    assert ws["C2"].value == "Ciencia de la Computación"
    assert ws["D2"].value == 32
    assert ws["E2"].value == 32
    assert ws["F2"].value == 32 * 2 or ws["F2"].value == 2


def test_el_total_es_una_formula_y_no_un_numero_congelado():
    # En la fase 3a estas hojas pasan a ser editables: si el total fuera un
    # numero escrito al generar, cambiar los grupos de CP no lo movería.
    ws = _hoja(construir_hoja_asignaturas)
    assert str(ws["G2"].value).startswith("=")
    assert "D2" in ws["G2"].value and "E2" in ws["G2"].value


def test_los_listados_quedan_protegidos_y_ordenables():
    for constructor in (construir_hoja_profesores, construir_hoja_asignaturas):
        ws = _hoja(constructor)
        assert ws.protection.sheet is True, ws.title
        assert ws.protection.sort is False, ws.title
