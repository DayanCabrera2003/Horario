import datetime
from openpyxl import Workbook

from extraccion.tribunales_excel import importar, escribir_yaml
from tribunales.config import cargar_facultad, cargar_asignaciones


CABECERA = ["Día", "Hora", "Estudiante", "Tutor", "Presidente", "Secretario",
            "Vocal", "Oponente", "Local", "Observaciones"]


def _excel(tmp_path, filas):
    wb = Workbook()
    ws = wb.active
    ws.append(CABECERA)
    for f in filas:
        ws.append(f)
    ruta = tmp_path / "tri.xlsx"
    wb.save(ruta)
    return ruta


def _datos(tmp_path):
    filas = [
        # Co-tutoria (dos tutores) y local con doble espacio.
        [datetime.datetime(2026, 6, 8), datetime.time(9, 30), "Adrián Hernández",
         "Lic. Alejandra Monzón, MSc. Fernando Rodríguez", "Lic. Amanda Noris",
         "Lic. Kevin Manzano", "Lic. Daniel Abad", "Lic. Rodrigo García",
         "Salón  decanato", None],
        # Tesis conjunta (dos estudiantes) y hora de tarde (1:30 -> 13:30).
        [datetime.datetime(2026, 6, 8), datetime.time(1, 30),
         "Claudia Pérez y Joel Tamayo", "MSc. Celia González", "Dra. Ayme Marrero",
         "MSc. Joanna Amos", "Lic. Daniel Valdés", "Lic. Alejandro Beltrán",
         "Posgrado", None],
        # Fila invalida: sin estudiante -> incidencia.
        [datetime.datetime(2026, 6, 8), datetime.time(10, 0), None,
         "X", "Y", "Z", "W", "V", "Posgrado", None],
    ]
    return importar([_excel(tmp_path, filas)])


def test_cuenta_tesis_y_asignaciones(tmp_path):
    d = _datos(tmp_path)
    assert len(d["facultad"]["tesis"]) == 2       # la fila invalida no cuenta
    assert len(d["asignaciones"]) == 2
    assert len(d["revision"]["incidencias"]) == 1


def test_tesis_conjunta_y_cotutoria(tmp_path):
    d = _datos(tmp_path)
    conjunta = [t for t in d["facultad"]["tesis"] if len(t["estudiantes"]) == 2]
    cotutoria = [t for t in d["facultad"]["tesis"] if len(t["tutores"]) == 2]
    assert conjunta and cotutoria


def test_local_y_hora_normalizados(tmp_path):
    d = _datos(tmp_path)
    nombres_local = {l["nombre"] for l in d["facultad"]["locales"]}
    assert "Salón del decanato" in nombres_local
    assert "Postgrado" in nombres_local
    # 1:30 se interpreta como 13:30 (tarde).
    momentos = {m["inicio"] for dia in d["facultad"]["dias"] for m in dia["momentos"]}
    assert "13:30" in momentos and "09:30" in momentos


def test_yaml_generado_es_cargable(tmp_path):
    d = _datos(tmp_path)
    tri = tmp_path / "tribunal.yaml"
    asig = tmp_path / "asignaciones.yaml"
    escribir_yaml(d, tri, asig)
    fac = cargar_facultad(tri)
    asigs = cargar_asignaciones(asig, fac)
    assert len(fac.tesis) == 2 and len(asigs) == 2
