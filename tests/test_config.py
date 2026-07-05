import pytest
from pathlib import Path
from horarios.config import cargar_facultad, ErrorConfig

FIXT = Path(__file__).parent / "fixtures"

def escribir(tmp_path, texto):
    p = tmp_path / "facultad.yaml"
    p.write_text(texto, encoding="utf-8")
    return p

BASE = """
aulas: [Aula 1, Lab]
dias: [Lunes, Martes]
turnos: 6
carreras:
  C:
    nombre: Carrera C
    años:
      1:
        sesiones:
          1: { grupos: [1, 2] }
          2: { grupos: [1] }
        asignaturas:
          - { id: L-C, nombre: "Lógica", frecuencia: 1 }
"""

def test_cargar_deriva_grupos(tmp_path):
    fac = cargar_facultad(escribir(tmp_path, BASE))
    ids = sorted(g.id for g in fac.grupos)
    assert ids == ["C111", "C112", "C121"]

def test_cargar_expone_anios_con_asignaturas(tmp_path):
    fac = cargar_facultad(escribir(tmp_path, BASE))
    assert fac.anios["C1"].asignaturas[0].id == "L-C"
    assert fac.turnos == 6
    assert fac.aulas == ("Aula 1", "Lab")

def test_config_invalida_turnos_cero(tmp_path):
    mal = BASE.replace("turnos: 6", "turnos: 0")
    with pytest.raises(ErrorConfig, match="turnos"):
        cargar_facultad(escribir(tmp_path, mal))

def test_config_invalida_asignaturas_faltan(tmp_path):
    mal = BASE.replace('        asignaturas:\n          - { id: L-C, nombre: "Lógica", frecuencia: 1 }\n', "")
    with pytest.raises(ErrorConfig, match="asignaturas"):
        cargar_facultad(escribir(tmp_path, mal))
