import datetime
from openpyxl import Workbook

from extraccion.tribunales_excel import (importar, escribir_yaml,
                                         escribir_revision, leer_filas, _fecha)
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


def test_fecha_acepta_date_y_datetime():
    # openpyxl devuelve unas celdas como `datetime` y otras como `date`.
    assert _fecha(datetime.datetime(2026, 6, 8, 9, 30)) == "2026-06-08"
    assert _fecha(datetime.date(2026, 6, 8)) == "2026-06-08"


def test_fecha_rechaza_lo_que_no_es_fecha():
    # Una celda con texto o vacia no es una fecha; la fila se ignorara despues.
    assert _fecha(None) == ""
    assert _fecha("8 de junio") == ""
    assert _fecha(2026) == ""


def test_leer_filas_salta_encabezados_y_filas_en_blanco(tmp_path):
    filas = [
        [datetime.datetime(2026, 6, 8), datetime.time(9, 30), "Adrián Hernández",
         "Lic. Alejandra Monzón", "Lic. Amanda Noris", "Lic. Kevin Manzano",
         None, "Lic. Rodrigo García", "Posgrado", None],
        [None] * 10,                      # fila completamente vacia
        CABECERA,                          # un segundo encabezado a media hoja
    ]
    leidas = list(leer_filas(_excel(tmp_path, filas)))
    assert len(leidas) == 1
    assert leidas[0]["estudiante"] == "Adrián Hernández"


def test_rol_vacio_queda_en_none(tmp_path):
    # El vocal es opcional: una casilla vacia no debe inventar una persona.
    filas = [[datetime.datetime(2026, 6, 8), datetime.time(9, 30), "Adrián Hernández",
              "Lic. Alejandra Monzón", "Lic. Amanda Noris", "Lic. Kevin Manzano",
              "   ", "Lic. Rodrigo García", "Posgrado", None]]
    datos = importar([_excel(tmp_path, filas)])
    tesis = datos["facultad"]["tesis"][0]
    assert "vocal" not in tesis or tesis["vocal"] in (None, "")
    # Y los profesores registrados son solo los cuatro con nombre.
    assert len(datos["facultad"]["profesores"]) == 4


def test_incidencia_por_hora_no_valida(tmp_path):
    filas = [[datetime.datetime(2026, 6, 8), "pendiente", "Adrián Hernández",
              "Lic. Alejandra Monzón", "Lic. Amanda Noris", "Lic. Kevin Manzano",
              "Lic. Daniel Abad", "Lic. Rodrigo García", "Posgrado", None]]
    datos = importar([_excel(tmp_path, filas)])
    incidencias = datos["revision"]["incidencias"]
    assert any("Sin hora válida" in i and "Adrián Hernández" in i for i in incidencias)
    assert not any("Sin local" in i for i in incidencias)


def test_incidencia_por_local_no_reconocible(tmp_path):
    # Una nota larga en la casilla de local no es un local.
    filas = [[datetime.datetime(2026, 6, 8), datetime.time(9, 30), "Adrián Hernández",
              "Lic. Alejandra Monzón", "Lic. Amanda Noris", "Lic. Kevin Manzano",
              "Lic. Daniel Abad", "Lic. Rodrigo García",
              "Carmen coordina para la entrega de portafolio y acta", None]]
    datos = importar([_excel(tmp_path, filas)])
    incidencias = datos["revision"]["incidencias"]
    assert any("Sin local reconocible" in i for i in incidencias)
    assert not any("Sin hora válida" in i for i in incidencias)


def test_escribir_revision_lista_personas_locales_e_incidencias(tmp_path):
    datos = _datos(tmp_path)
    ruta = tmp_path / "revision.md"
    escribir_revision(datos, ruta)
    texto = ruta.read_text(encoding="utf-8")

    rev = datos["revision"]
    assert f"## Profesores ({len(rev['profesores'])})" in texto
    assert f"## Estudiantes ({len(rev['estudiantes'])})" in texto
    assert f"## Locales ({len(datos['facultad']['locales'])})" in texto
    assert f"## Incidencias ({len(rev['incidencias'])})" in texto
    # La tabla de profesores lleva columna de grado; la de estudiantes, no.
    assert "| id | nombre | grado | variantes fusionadas |" in texto
    assert "| id | nombre | variantes fusionadas |" in texto
    # Cada persona y cada local aparecen por su id.
    for g in rev["profesores"].values():
        assert f"| {g['id']} |" in texto
    for l in datos["facultad"]["locales"]:
        assert f"| {l['id']} | {l['nombre']} |" in texto
    # El fixture trae una fila sin estudiante: su incidencia tiene que salir.
    assert rev["incidencias"]
    for inc in rev["incidencias"]:
        assert f"- {inc}" in texto


def test_escribir_revision_sin_incidencias_lo_dice(tmp_path):
    filas = [[datetime.datetime(2026, 6, 8), datetime.time(9, 30), "Adrián Hernández",
              "Lic. Alejandra Monzón", "Lic. Amanda Noris", "Lic. Kevin Manzano",
              "Lic. Daniel Abad", "Lic. Rodrigo García", "Posgrado", None]]
    datos = importar([_excel(tmp_path, filas)])
    assert datos["revision"]["incidencias"] == []
    ruta = tmp_path / "revision.md"
    escribir_revision(datos, ruta)
    texto = ruta.read_text(encoding="utf-8")
    assert "## Incidencias (0)" in texto
    assert "Ninguna." in texto


def test_el_mismo_local_en_dos_filas_reutiliza_su_id(tmp_path):
    # El id del local se genera la primera vez y se reutiliza despues; si no,
    # el mismo salon saldria dos veces en la lista de locales.
    fila = lambda est: [datetime.datetime(2026, 6, 8), datetime.time(9, 30), est,
                        "Lic. Alejandra Monzón", "Lic. Amanda Noris",
                        "Lic. Kevin Manzano", None, "Lic. Rodrigo García",
                        "Posgrado", None]
    datos = importar([_excel(tmp_path, [fila("Adrián Hernández"), fila("Claudia Pérez")])])
    locales = datos["facultad"]["locales"]
    assert len(locales) == 1
    assert locales[0]["nombre"] == "Postgrado"
    # Las dos tesis apuntan al mismo id de local.
    ids = {a["local"] for a in datos["asignaciones"]}
    assert ids == {locales[0]["id"]}
