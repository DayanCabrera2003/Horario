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
    # profesor o le viene del departamento? La respuesta va como formula porque
    # el tope se edita en esta misma hoja.
    ws = _hoja(construir_hoja_profesores)
    assert ws["D2"].value == 160
    assert ws["D3"].value == 80
    assert "Del departamento" in ws["E2"].value
    assert "Propio" in ws["E2"].value
    assert "160" in ws["E2"].value      # el tope global con el que compara


def test_sin_ningun_tope_la_columna_lo_dice():
    ws = _hoja(construir_hoja_profesores, SIN_TOPE)
    assert ws["D2"].value == ""
    # Sin tope global no hay con que comparar: o hay tope propio o no hay tope.
    assert "Sin tope" in ws["E2"].value
    assert "Del departamento" not in ws["E2"].value


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


def test_la_reserva_del_claustro_ya_trae_la_formula_del_origen():
    ws = _hoja(construir_hoja_profesores)
    fila_libre = next(f for f in range(2, ws.max_row + 1) if ws[f"A{f}"].value is None)
    formula = str(ws[f"E{fila_libre}"].value)
    assert formula.startswith("="), fila_libre
    # Con la fila vacia no dice "Sin tope": no hay profesor del que hablar.
    assert f'A{fila_libre}=""' in formula


# --- La hoja Asignaturas, editable (2026-09-07) -------------------------------
# Deja de ser un listado de solo lectura: es donde se anaden las asignaturas
# nuevas sin volver al YAML, y de ella cuelgan las formulas de Asignacion y de
# Cobertura.

DEPTO_RESERVA = Departamento(
    nombre="D", semestre="1", tope_horas=160, filas_por_profesor=10,
    profesores=DEPTO.profesores, asignaturas=DEPTO.asignaturas,
    asignaturas_reserva=1,
)


def _libro(depto=DEPTO_RESERVA):
    wb = Workbook()
    wb.remove(wb.active)
    construir_hoja_asignaturas(wb, depto)
    return wb


def test_asignaturas_tiene_reserva_y_es_editable():
    ws = _libro()["Asignaturas"]
    # 1 asignatura declarada + 1 de reserva: la fila 3 esta vacia pero ya trae
    # su formula de total, para que escribir en ella sea escribir seis datos.
    assert ws["A3"].value is None
    assert str(ws["G3"].value).startswith("=")
    for col in ("A", "B", "C", "D", "E", "F"):
        assert ws[f"{col}3"].protection.locked is False, col
    # La columna calculada no se desbloquea: es la unica que no es un dato.
    assert ws["G3"].protection.locked is True


def test_el_total_no_muestra_un_cero_en_la_reserva():
    # Sin la guarda, una fila libre anunciaria "0 horas" de una asignatura que
    # todavia no existe.
    assert 'A3=""' in _libro()["Asignaturas"]["G3"].value


def test_rangos_nombrados_de_asignaturas():
    wb = _libro()
    assert "AsignaturasValidas" in wb.defined_names
    assert "AsignaturasTabla" in wb.defined_names
    # Anclados en la columna de Id y no en la del total: el total es una formula
    # y ocupa celda siempre, asi que COUNTA sobre el no mide nada.
    texto = wb.defined_names["AsignaturasValidas"].attr_text
    assert "$A$2" in texto
    assert "Asignaturas" in texto


def test_el_claustro_tiene_los_huecos_que_declara_el_departamento():
    # Los mismos huecos son las filas del panel de `Asignacion` y los bloques de
    # `Carga por profesor`. Si esta hoja tuviera mas, un profesor escrito en un
    # hueco de mas entraria en el desplegable pero no tendria ni panel ni bloque.
    depto = Departamento(
        nombre="D", semestre="1", tope_horas=160, filas_por_profesor=10,
        profesores=DEPTO.profesores, asignaturas=DEPTO.asignaturas,
        profesores_reserva=1)
    ws = _hoja(construir_hoja_profesores, depto)
    assert ws["A4"].value is None            # 2 profesores + 1 hueco libre
    assert ws["E4"].value is not None        # el hueco existe, con su formula
    assert ws["E5"].value is None            # y no hay ninguno de mas
