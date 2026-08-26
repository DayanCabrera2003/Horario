import datetime

from openpyxl import load_workbook
from tribunales import estilos
from tribunales.generador import generar


def _escribir(tmp_path):
    cfg = tmp_path / "tribunal.yaml"
    cfg.write_text("""
profesores:
  - {id: PIAD, nombre: "Pedro", grado: "Dr."}
  - {id: MARA, nombre: "Maria", grado: "MSc."}
  - {id: LGOM, nombre: "Luis", grado: "Dr."}
  - {id: ANSU, nombre: "Ana", grado: "MSc."}
estudiantes:
  - {id: JPER, nombre: "Juan"}
locales:
  - {id: POST, nombre: "Postgrado"}
dias:
  - fecha: 2026-07-27
    momentos:
      - {inicio: "09:00", fin: "10:00"}
tesis:
  - {estudiante: JPER, tutor: PIAD, oponente: MARA, presidente: LGOM, secretario: ANSU}
""", encoding="utf-8")
    return cfg


def test_genera_hojas_esperadas(tmp_path):
    cfg = _escribir(tmp_path)
    salida = tmp_path / "tesis.xlsx"
    generar(config_path=cfg, asignaciones_path=None, salida=salida)
    wb = load_workbook(salida)
    assert "Localizar" in wb.sheetnames
    assert "27 jul (lun)" in wb.sheetnames
    assert "Datos" in wb.sheetnames
    assert "Tribunales" in wb.sheetnames


def test_genera_con_asignaciones(tmp_path):
    cfg = _escribir(tmp_path)
    asig = tmp_path / "asig.yaml"
    asig.write_text('- {estudiante: JPER, local: POST, fecha: 2026-07-27, momento: "09:00-10:00"}\n',
                    encoding="utf-8")
    salida = tmp_path / "tesis.xlsx"
    generar(config_path=cfg, asignaciones_path=asig, salida=salida)
    wb = load_workbook(salida)
    ws = wb["27 jul (lun)"]
    assert ws["B3"].value == "JPER"   # columna Estudiante, primer momento, primer local


GENERADO = datetime.datetime(2026, 8, 25, 14, 30)


def _generar(tmp_path, **kwargs):
    """Genera el libro de tesis de ejemplo y devuelve su workbook ya releido."""
    cfg = _escribir(tmp_path)
    salida = tmp_path / "tesis.xlsx"
    generar(config_path=cfg, asignaciones_path=None, salida=salida, **kwargs)
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
    for hoja in ("Tribunales", "Localizar"):
        assert any(hoja in e for e in enlaces), f"falta el enlace a {hoja}"
    # Datos es fontaneria de formulas y esta oculta: no se indexa.
    assert not any("Datos" in e for e in enlaces)


def test_la_portada_indexa_una_hoja_por_dia(tmp_path):
    # El indice se arma con los nombres reales de las hojas de dia, que la
    # tarea F1.11 va a renombrar. Si se armara con una lista aparte, el
    # renombrado dejaria enlaces rotos sin que nadie se enterara.
    wb = _generar(tmp_path)
    assert any("27 jul (lun)" in e for e in _enlaces(wb))


def test_las_pestanas_distinguen_las_hojas_de_dia_de_las_de_consulta(tmp_path):
    wb = _generar(tmp_path)
    # En las hojas de dia se coloca a cada estudiante: ahi se escribe.
    assert wb["27 jul (lun)"].sheet_properties.tabColor.rgb.endswith(
        estilos.COLOR_PESTANA_ENTRADA)
    # Tribunales es una vista de solo lectura del YAML.
    assert wb["Tribunales"].sheet_properties.tabColor.rgb.endswith(
        estilos.COLOR_PESTANA_CALCULO)
