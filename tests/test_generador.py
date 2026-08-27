"""Tests de integración para horarios.generador."""
import datetime

from openpyxl import load_workbook
from horarios.config import cargar_facultad
from horarios.generador import generar
from horarios import layout as L

BASE = """
aulas: [Aula 1, Lab]
dias: [Lunes, Martes]
turnos: 6
carreras:
  C:
    nombre: Carrera C
    años:
      1:
        sesiones: { 1: { grupos: [1, 2] } }
        asignaturas:
          - { id: L-C, nombre: "Lógica", frecuencia: 1 }
"""


def _config(tmp_path):
    cfg = tmp_path / "facultad.yaml"
    cfg.write_text(BASE, encoding="utf-8")
    return cfg


# --- Test dado en la especificación ---

def test_genera_workbook_con_hojas(tmp_path):
    cfg = _config(tmp_path)
    salida = tmp_path / "out.xlsx"
    generar(config_path=cfg, horarios_path=None, salida=salida)
    wb = load_workbook(salida)
    assert "Ocupación de aulas" in wb.sheetnames
    assert "C111" in wb.sheetnames and "C112" in wb.sheetnames
    assert "Auxiliar" in wb.sheetnames
    assert wb["Auxiliar"].sheet_state == "hidden"


# --- Test extra 1: ruta con horarios (faithful-copy) ---

def test_horarios_yaml_rellena_celdas(tmp_path):
    """generar con horarios_path escribe asig y aula en la hoja del grupo."""
    cfg = _config(tmp_path)
    horarios_yaml = tmp_path / "horarios.yaml"
    horarios_yaml.write_text(
        "C111:\n  Lunes:\n    1:\n      asig: L-C\n      aula: Aula 1\n",
        encoding="utf-8",
    )
    salida = tmp_path / "out.xlsx"
    generar(config_path=cfg, horarios_path=horarios_yaml, salida=salida)

    wb = load_workbook(salida)
    ws = wb["C111"]
    # día 0 = Lunes, turno 1
    assert ws[L.celda_asig(0, 1)].value == "L-C"
    assert ws[L.celda_aula(0, 1)].value == "Aula 1"
    # Hoja C112 (sin horario) debe tener esa misma celda vacía
    assert wb["C112"][L.celda_asig(0, 1)].value is None


# --- Test extra 2: humo de fórmulas en modo esqueleto ---

def test_formulas_presentes_en_modo_esqueleto(tmp_path):
    """En modo esqueleto las hojas de grupo contienen COUNTIF y Aulas tiene SUBSTITUTE."""
    cfg = _config(tmp_path)
    salida = tmp_path / "out.xlsx"
    generar(config_path=cfg, horarios_path=None, salida=salida)

    wb = load_workbook(salida)

    # Hoja de grupo: debe contener al menos un =COUNTIF( en la columna Asignadas
    ws_grupo = wb["C111"]
    formulas_grupo = [
        c.value
        for row in ws_grupo.iter_rows()
        for c in row
        if isinstance(c.value, str) and c.value.startswith("=")
    ]
    assert any("COUNTIF(" in f for f in formulas_grupo), (
        f"No se encontró =COUNTIF en C111; fórmulas vistas: {formulas_grupo[:10]}"
    )

    # Hoja Aulas: debe contener al menos un =SUBSTITUTE(
    ws_aulas = wb["Ocupación de aulas"]
    formulas_aulas = [
        c.value
        for row in ws_aulas.iter_rows()
        for c in row
        if isinstance(c.value, str) and c.value.startswith("=")
    ]
    assert any("SUBSTITUTE" in f for f in formulas_aulas), (
        f"No se encontró SUBSTITUTE en Aulas; fórmulas vistas: {formulas_aulas[:10]}"
    )


# --- Portada ---

GENERADO = datetime.datetime(2026, 8, 25, 14, 30)


def _generar(tmp_path, **kwargs):
    """Genera el libro de horarios de ejemplo y devuelve su workbook releido."""
    salida = tmp_path / "out.xlsx"
    generar(config_path=_config(tmp_path), horarios_path=None, salida=salida,
            **kwargs)
    return load_workbook(salida)


def _enlaces(wb):
    return [c.hyperlink.location for fila in wb["Portada"].iter_rows()
            for c in fila if c.hyperlink is not None]


def test_el_libro_abre_por_la_portada(tmp_path):
    wb = _generar(tmp_path)
    assert wb.sheetnames[0] == "Portada"
    assert wb.active.title == "Portada"


def test_la_portada_muestra_la_fecha_inyectada(tmp_path):
    wb = _generar(tmp_path, generado=GENERADO)
    textos = [c.value for fila in wb["Portada"].iter_rows() for c in fila
              if isinstance(c.value, str)]
    assert any("25/08/2026 14:30" in t for t in textos)


def test_la_portada_enlaza_las_hojas_visibles(tmp_path):
    wb = _generar(tmp_path)
    enlaces = _enlaces(wb)
    assert any("Ocupación de aulas" in e for e in enlaces)
    # Datos es fontaneria de formulas y esta oculta: no se indexa.
    assert not any("Auxiliar" in e for e in enlaces)


def test_la_portada_indexa_una_hoja_por_grupo(tmp_path):
    # Igual que con las hojas de dia de tesis: el indice se arma con los
    # nombres reales de las hojas creadas, no con una lista paralela.
    wb = _generar(tmp_path)
    enlaces = _enlaces(wb)
    for grupo in ("C111", "C112"):
        assert any(grupo in e for e in enlaces), f"falta el enlace a {grupo}"


def _fila_del_indice(ws, nombre: str):
    for fila in ws.iter_rows():
        if fila[0].value == nombre:
            return fila
    return None


def test_el_indice_situa_cada_grupo_en_su_carrera_y_ano(tmp_path):
    # Con 22 grupos, repetir la misma descripcion en cada fila no dice nada.
    # La carrera y el ano son el eje por el que se navega el libro.
    wb = _generar(tmp_path)
    assert _fila_del_indice(wb["Portada"], "C111")[1].value == "Carrera C · año 1"
