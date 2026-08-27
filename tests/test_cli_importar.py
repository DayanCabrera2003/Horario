"""Tests de los dos CLI de importacion.

Se corren por subprocess, igual que el resto de tests de CLI: es la unica forma
de comprobar el codigo de salida y lo que va a stdout/stderr.
"""
import datetime
import subprocess
import sys
from pathlib import Path

import yaml
from openpyxl import Workbook

RAIZ = Path(__file__).resolve().parents[1]

CABECERA = ["Día", "Hora", "Estudiante", "Tutor", "Presidente", "Secretario",
            "Vocal", "Oponente", "Local", "Observaciones"]


def _correr(argumentos):
    return subprocess.run([sys.executable, *argumentos],
                          cwd=RAIZ, capture_output=True, text=True)


# --- importar_horario.py -----------------------------------------------------

def test_importar_horario_genera_los_tres_archivos(tmp_path):
    fac = tmp_path / "facultad.yaml"
    hor = tmp_path / "horarios.yaml"
    inc = tmp_path / "incidencias.md"
    r = _correr(["importar_horario.py", "--facultad", str(fac),
                 "--horarios", str(hor), "--incidencias", str(inc)])

    assert r.returncode == 0, r.stderr
    assert fac.exists() and hor.exists() and inc.exists()
    # Los YAML tienen que volver a leerse como tales, no como texto suelto.
    assert isinstance(yaml.safe_load(fac.read_text(encoding="utf-8")), dict)
    assert isinstance(yaml.safe_load(hor.read_text(encoding="utf-8")), dict)
    # El resumen impreso menciona lo que acaba de generar.
    assert "Grupos con horario:" in r.stdout
    assert str(inc) in r.stdout


def test_importar_horario_el_resumen_cuadra_con_lo_generado(tmp_path):
    fac = tmp_path / "facultad.yaml"
    hor = tmp_path / "horarios.yaml"
    inc = tmp_path / "incidencias.md"
    r = _correr(["importar_horario.py", "--facultad", str(fac),
                 "--horarios", str(hor), "--incidencias", str(inc)])

    datos_fac = yaml.safe_load(fac.read_text(encoding="utf-8"))
    datos_hor = yaml.safe_load(hor.read_text(encoding="utf-8"))
    # Si el resumen dijera un numero y el archivo otro, el informe no serviria.
    assert f"Carreras: {len(datos_fac['carreras'])}" in r.stdout
    assert f"Aulas: {len(datos_fac['aulas'])}" in r.stdout
    assert f"Turnos: {datos_fac['turnos']}" in r.stdout
    assert f"Grupos con horario: {len(datos_hor)}" in r.stdout


# --- importar_tribunales.py --------------------------------------------------

def _excel(tmp_path, nombre="tri.xlsx"):
    wb = Workbook()
    ws = wb.active
    ws.append(CABECERA)
    ws.append([datetime.datetime(2026, 6, 8), datetime.time(9, 30), "Adrián Hernández",
               "Lic. Alejandra Monzón", "Lic. Amanda Noris", "Lic. Kevin Manzano",
               "Lic. Daniel Abad", "Lic. Rodrigo García", "Posgrado", None])
    ws.append([datetime.datetime(2026, 6, 9), datetime.time(10, 30), "Claudia Pérez",
               "MSc. Celia González", "Dra. Ayme Marrero", "MSc. Joanna Amos",
               None, "Lic. Alejandro Beltrán", "Francofonía", None])
    ruta = tmp_path / nombre
    wb.save(ruta)
    return ruta


def test_importar_tribunales_genera_los_tres_archivos(tmp_path):
    tri = tmp_path / "tribunal.yaml"
    asig = tmp_path / "asignaciones.yaml"
    rev = tmp_path / "revision.md"
    r = _correr(["importar_tribunales.py", str(_excel(tmp_path)),
                 "--tribunal", str(tri), "--asignaciones", str(asig),
                 "--revision", str(rev)])

    assert r.returncode == 0, r.stderr
    assert tri.exists() and asig.exists() and rev.exists()
    datos_tri = yaml.safe_load(tri.read_text(encoding="utf-8"))
    assert {"profesores", "estudiantes", "locales", "dias", "tesis"} <= set(datos_tri)
    assert "Tesis: 2" in r.stdout
    assert "Incidencias: 0" in r.stdout


def test_importar_tribunales_acepta_varios_excel(tmp_path):
    # El argumento es nargs="+": dos archivos se funden en un solo YAML, y la
    # misma persona en los dos no se duplica.
    a = _excel(tmp_path, "a.xlsx")
    b = _excel(tmp_path, "b.xlsx")
    tri = tmp_path / "tribunal.yaml"
    asig = tmp_path / "asignaciones.yaml"
    rev = tmp_path / "revision.md"
    r = _correr(["importar_tribunales.py", str(a), str(b),
                 "--tribunal", str(tri), "--asignaciones", str(asig),
                 "--revision", str(rev)])

    assert r.returncode == 0, r.stderr
    datos = yaml.safe_load(tri.read_text(encoding="utf-8"))
    # Las mismas dos tesis dos veces: cuatro filas, pero las personas se unifican.
    assert len(datos["tesis"]) == 4
    assert len(datos["estudiantes"]) == 2
    ids = [p["id"] for p in datos["profesores"]]
    assert len(ids) == len(set(ids))


def test_importar_tribunales_el_yaml_generado_lo_acepta_el_generador(tmp_path):
    # La prueba de punta a punta: lo que importa el CLI tiene que poder cargarse
    # como configuracion del generador de tribunales.
    from tribunales.config import cargar_facultad, cargar_asignaciones

    tri = tmp_path / "tribunal.yaml"
    asig = tmp_path / "asignaciones.yaml"
    rev = tmp_path / "revision.md"
    r = _correr(["importar_tribunales.py", str(_excel(tmp_path)),
                 "--tribunal", str(tri), "--asignaciones", str(asig),
                 "--revision", str(rev)])
    assert r.returncode == 0, r.stderr

    facultad = cargar_facultad(tri)
    asignaciones = cargar_asignaciones(asig, facultad)
    assert len(facultad.tesis) == 2
    assert len(asignaciones) == 2


def test_importar_tribunales_sin_archivos_falla(tmp_path):
    # `excel` es obligatorio (nargs="+"): argparse tiene que rechazarlo.
    r = _correr(["importar_tribunales.py"])
    assert r.returncode != 0
    assert "excel" in r.stderr.lower()
