"""Tests de las secciones 'profesores' y 'docencia' del YAML de facultad.

Son nuevas en la fase 2 y las dos son opcionales: una facultad que no declare
profesores tiene que seguir cargando igual, porque asi son todos los YAML que
existian antes.

La docencia dice quien imparte cada (asignatura, grupo). El par completo hace
falta: en el modelo las asignaturas cuelgan del **ano**, no del grupo, asi que
el mismo `AMI-CP` lo puede impartir un profesor distinto en cada grupo.
"""
import pytest

from horarios.config import cargar_facultad, ErrorConfig

BASE = """
aulas: [Aula 1]
dias: [Lunes]
turnos: 6
carreras:
  C:
    nombre: Ciencia de la Computación
    años:
      1:
        sesiones:
          1: {grupos: [1, 2]}
        asignaturas:
          - {id: AMI-C, nombre: "Análisis Matemático I (Conf)", frecuencia: 1}
          - {id: AMI-CP, nombre: "Análisis Matemático I (C.P.)", frecuencia: 2}
"""

PROFESORES = """
profesores:
  - {id: PIAD, nombre: "Pedro I. Alonso Diaz", grado: "Dr.", tope_turnos: 160}
  - {id: MARA, nombre: "Maria Ramirez", grado: "MSc."}
"""


def _cargar(tmp_path, texto):
    ruta = tmp_path / "facultad.yaml"
    ruta.write_text(texto, encoding="utf-8")
    return cargar_facultad(ruta)


def test_sin_profesores_la_facultad_carga_igual(tmp_path):
    # Todos los YAML anteriores a la fase 2 son asi.
    facultad = _cargar(tmp_path, BASE)
    assert facultad.profesores == ()
    assert facultad.docencia == ()


def test_los_profesores_se_cargan_con_grado_y_tope(tmp_path):
    facultad = _cargar(tmp_path, BASE + PROFESORES)
    assert [p.id for p in facultad.profesores] == ["PIAD", "MARA"]
    assert facultad.profesores[0].tope_turnos == 160
    # El tope es opcional, como en el generador del departamento.
    assert facultad.profesores[1].tope_turnos is None
    assert facultad.profesores[1].grado == "MSc."


def test_ids_de_profesor_duplicados_dan_error(tmp_path):
    texto = BASE + """
profesores:
  - {id: PIAD, nombre: "Pedro"}
  - {id: PIAD, nombre: "Otro Pedro"}
"""
    with pytest.raises(ErrorConfig, match="id duplicado"):
        _cargar(tmp_path, texto)


def test_la_docencia_dice_quien_imparte_cada_asignatura_de_cada_grupo(tmp_path):
    texto = BASE + PROFESORES + """
docencia:
  C111:
    AMI-C: PIAD
    AMI-CP: MARA
  C112:
    AMI-CP: PIAD
"""
    facultad = _cargar(tmp_path, texto)
    assert len(facultad.docencia) == 3
    assert facultad.profesor_de("C111", "AMI-CP") == "MARA"
    # El mismo AMI-CP, otro grupo, otro profesor: es el caso que obliga a que
    # la clave sea el par y no solo la asignatura.
    assert facultad.profesor_de("C112", "AMI-CP") == "PIAD"
    assert facultad.profesor_de("C112", "AMI-C") == ""


def test_docencia_de_un_profesor_inexistente_da_error(tmp_path):
    texto = BASE + PROFESORES + """
docencia:
  C111: {AMI-C: NADIE}
"""
    with pytest.raises(ErrorConfig, match="profesor inexistente"):
        _cargar(tmp_path, texto)


def test_docencia_de_un_grupo_inexistente_da_error(tmp_path):
    texto = BASE + PROFESORES + """
docencia:
  C999: {AMI-C: PIAD}
"""
    with pytest.raises(ErrorConfig, match="grupo inexistente"):
        _cargar(tmp_path, texto)


def test_docencia_de_una_asignatura_que_no_es_del_ano_da_error(tmp_path):
    # El grupo existe y la asignatura tambien podria existir en otro ano; lo que
    # no vale es asignarle a C111 algo que su ano no imparte.
    texto = BASE + PROFESORES + """
docencia:
  C111: {XYZ: PIAD}
"""
    with pytest.raises(ErrorConfig, match="asignatura"):
        _cargar(tmp_path, texto)


def test_un_tope_de_turnos_invalido_da_error(tmp_path):
    # Mismo criterio que en el generador del departamento: si se declara, tiene
    # que ser un entero positivo. Cero significaria "no puede impartir nada",
    # que no es lo que nadie quiere decir al escribirlo.
    texto = BASE + """
profesores:
  - {id: PIAD, nombre: "Pedro", tope_turnos: 0}
"""
    with pytest.raises(ErrorConfig, match="tope_turnos"):
        _cargar(tmp_path, texto)
