import pytest
from pathlib import Path
from horarios.config import cargar_facultad, cargar_horarios, ErrorConfig

FIXT = Path(__file__).parent / "fixtures"

def escribir(tmp_path, texto):
    p = tmp_path / "facultad.yaml"
    p.write_text(texto, encoding="utf-8")
    return p

def escribir_horarios(tmp_path, texto):
    p = tmp_path / "horarios.yaml"
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

def test_config_invalida_raiz_no_es_diccionario(tmp_path):
    # Un YAML que es una lista, no un mapa: el error tiene que ser el de la raiz
    # y no un AttributeError al buscar claves.
    with pytest.raises(ErrorConfig, match="diccionario"):
        cargar_facultad(escribir(tmp_path, "- Aula 1\n- Aula 2\n"))

def test_config_invalida_raiz_vacia(tmp_path):
    # Un archivo vacio deja `datos` en None, que tampoco es un diccionario.
    with pytest.raises(ErrorConfig, match="diccionario"):
        cargar_facultad(escribir(tmp_path, ""))

def test_config_invalida_aulas_vacias(tmp_path):
    mal = BASE.replace("aulas: [Aula 1, Lab]", "aulas: []")
    with pytest.raises(ErrorConfig, match="aulas"):
        cargar_facultad(escribir(tmp_path, mal))

def test_config_invalida_dias_vacios(tmp_path):
    mal = BASE.replace("dias: [Lunes, Martes]", "dias: []")
    with pytest.raises(ErrorConfig, match="dias"):
        cargar_facultad(escribir(tmp_path, mal))

def test_config_invalida_sin_ningun_grupo(tmp_path):
    # El año existe y tiene asignaturas, pero ninguna sesion declara grupos:
    # no hay nada que generar y hay que decirlo en vez de producir un libro vacio.
    mal = BASE.replace("""        sesiones:
          1: { grupos: [1, 2] }
          2: { grupos: [1] }
""", "")
    with pytest.raises(ErrorConfig, match="grupo"):
        cargar_facultad(escribir(tmp_path, mal))


def _fac(tmp_path):
    return cargar_facultad(escribir(tmp_path, BASE))

def test_cargar_horarios_happy_path(tmp_path):
    fac = _fac(tmp_path)
    hor = """
C111:
  Lunes:
    1: { asig: L-C, aula: Aula 1 }
"""
    horarios = cargar_horarios(escribir_horarios(tmp_path, hor), fac)
    celda = horarios["C111"].celdas[("Lunes", 1)]
    assert celda.asig == "L-C"
    assert celda.aula == "Aula 1"

def test_cargar_horarios_grupo_inexistente(tmp_path):
    fac = _fac(tmp_path)
    hor = "C999:\n  Lunes:\n    1: { asig: L-C, aula: Aula 1 }\n"
    with pytest.raises(ErrorConfig, match="inexistente"):
        cargar_horarios(escribir_horarios(tmp_path, hor), fac)

def test_cargar_horarios_dia_desconocido(tmp_path):
    fac = _fac(tmp_path)
    hor = "C111:\n  Domingo:\n    1: { asig: L-C, aula: Aula 1 }\n"
    with pytest.raises(ErrorConfig, match="día"):
        cargar_horarios(escribir_horarios(tmp_path, hor), fac)

def test_cargar_horarios_turno_fuera_de_rango(tmp_path):
    fac = _fac(tmp_path)
    hor = "C111:\n  Lunes:\n    9: { asig: L-C, aula: Aula 1 }\n"
    with pytest.raises(ErrorConfig, match="turno"):
        cargar_horarios(escribir_horarios(tmp_path, hor), fac)

def test_cargar_horarios_aula_desconocida(tmp_path):
    fac = _fac(tmp_path)
    hor = "C111:\n  Lunes:\n    1: { asig: L-C, aula: Aula 42 }\n"
    with pytest.raises(ErrorConfig, match="aula"):
        cargar_horarios(escribir_horarios(tmp_path, hor), fac)

def test_cargar_horarios_celda_incompleta(tmp_path):
    fac = _fac(tmp_path)
    hor = "C111:\n  Lunes:\n    1: { aula: Aula 1 }\n"
    with pytest.raises(ErrorConfig, match="'asig' y 'aula'"):
        cargar_horarios(escribir_horarios(tmp_path, hor), fac)
