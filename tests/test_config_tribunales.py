import pytest
from tribunales.config import cargar_facultad, cargar_asignaciones, ErrorConfig


def _yaml(tmp_path, texto):
    p = tmp_path / "tribunal.yaml"
    p.write_text(texto, encoding="utf-8")
    return p


BASE = """
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
"""


def test_carga_valida(tmp_path):
    fac = cargar_facultad(_yaml(tmp_path, BASE))
    assert fac.estudiantes[0].id == "JPER"
    assert fac.dias[0].momentos[0].id == "09:00-10:00"
    assert fac.tesis[0].tutor == "PIAD"


def test_tesis_con_estudiante_inexistente(tmp_path):
    malo = BASE.replace("estudiante: JPER, tutor", "estudiante: XXXX, tutor")
    with pytest.raises(ErrorConfig):
        cargar_facultad(_yaml(tmp_path, malo))


def test_tesis_con_profesor_inexistente(tmp_path):
    malo = BASE.replace("tutor: PIAD", "tutor: ZZZZ")
    with pytest.raises(ErrorConfig):
        cargar_facultad(_yaml(tmp_path, malo))


def test_asignaciones_validas(tmp_path):
    fac = cargar_facultad(_yaml(tmp_path, BASE))
    a = tmp_path / "asig.yaml"
    a.write_text('- {estudiante: JPER, local: POST, fecha: 2026-07-27, momento: "09:00-10:00"}\n',
                 encoding="utf-8")
    asigs = cargar_asignaciones(a, fac)
    assert asigs[0].local == "POST"


def test_asignaciones_none_devuelve_vacio(tmp_path):
    fac = cargar_facultad(_yaml(tmp_path, BASE))
    assert cargar_asignaciones(None, fac) == ()


def test_asignacion_con_momento_inexistente(tmp_path):
    fac = cargar_facultad(_yaml(tmp_path, BASE))
    a = tmp_path / "asig.yaml"
    a.write_text('- {estudiante: JPER, local: POST, fecha: 2026-07-27, momento: "23:00-23:30"}\n',
                 encoding="utf-8")
    with pytest.raises(ErrorConfig):
        cargar_asignaciones(a, fac)
