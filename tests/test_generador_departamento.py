import datetime

from openpyxl import load_workbook

from departamento import estilos
from departamento.generador import generar


CONFIG = """
departamento:
  nombre: Matemática Aplicada
  semestre: "2026-2027 / 1"
  tope_horas: 160
profesores:
  - {id: PIAD, nombre: "Pedro I. Alonso", grado: "Dr."}
asignaturas:
  - {id: EST-CC, nombre: "Estadística (CC)", carrera: "CC",
     horas_conf: 32, horas_cp: 32, grupos_cp: 2}
"""


def test_genera_libro_completo(tmp_path):
    cfg = tmp_path / "departamento.yaml"
    cfg.write_text(CONFIG, encoding="utf-8")
    salida = tmp_path / "gestion.xlsx"

    ruta = generar(config_path=cfg, salida=salida)

    assert ruta == salida and salida.exists()
    wb = load_workbook(salida)
    # Asignacion primera y activa; Datos oculta al final.
    assert wb.sheetnames == ["Portada", "Profesores", "Asignaturas", "Asignación",
                             "Carga por profesor", "Cobertura por asignatura",
                             "Auxiliar"]
    assert wb["Auxiliar"].sheet_state == "hidden"


GENERADO = datetime.datetime(2026, 8, 25, 14, 30)


def _generar(tmp_path, **kwargs):
    """Genera el libro de ejemplo y devuelve su workbook ya releido."""
    cfg = tmp_path / "departamento.yaml"
    cfg.write_text(CONFIG, encoding="utf-8")
    salida = tmp_path / "gestion.xlsx"
    generar(config_path=cfg, salida=salida, **kwargs)
    return load_workbook(salida)


def test_el_libro_abre_por_la_portada(tmp_path):
    # No basta con que la portada exista: si el libro abre por otra hoja, nadie
    # la ve, que es justo el problema que vino a resolver.
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
    enlaces = [c.hyperlink.location
               for fila in wb["Portada"].iter_rows() for c in fila
               if c.hyperlink is not None]
    for hoja in ("Asignación", "Carga por profesor", "Cobertura por asignatura"):
        assert any(hoja in e for e in enlaces), f"falta el enlace a {hoja}"
    # Datos es fontaneria de formulas y esta oculta: no se indexa.
    assert not any("Auxiliar" in e for e in enlaces)


def test_la_portada_dice_de_que_yaml_salio(tmp_path):
    wb = _generar(tmp_path)
    textos = [c.value for fila in wb["Portada"].iter_rows() for c in fila
              if isinstance(c.value, str)]
    assert any("departamento.yaml" in t for t in textos)


def test_las_pestanas_distinguen_la_hoja_de_entrada_de_las_de_calculo(tmp_path):
    # El color de pestana repite en la barra la misma distincion que el indice
    # de la portada: donde se escribe frente a lo que sale solo.
    wb = _generar(tmp_path)
    entrada = wb["Asignación"].sheet_properties.tabColor.rgb
    assert entrada.endswith(estilos.COLOR_PESTANA_ENTRADA)
    for hoja in ("Carga por profesor", "Cobertura por asignatura"):
        assert wb[hoja].sheet_properties.tabColor.rgb.endswith(
            estilos.COLOR_PESTANA_CALCULO), f"{hoja} deberia ir de calculo"


def test_el_indice_marca_asignaturas_como_editable(tmp_path):
    # Dejo de ser un listado de solo lectura: ahi se anaden las asignaturas
    # nuevas. Si el indice sigue diciendo "datos del problema", el usuario no
    # sabra que puede escribir en ella.
    from comun.portada import SE_ESCRIBE
    wb = _generar(tmp_path)
    textos = [[c.value for c in fila] for fila in wb["Portada"].iter_rows()]
    fila = next(f for f in textos if "Asignaturas" in f)
    assert SE_ESCRIBE in fila
