import pytest
from departamento.config import cargar_departamento, ErrorConfig


def _yaml(tmp_path, texto):
    p = tmp_path / "departamento.yaml"
    p.write_text(texto, encoding="utf-8")
    return p


BASE = """
departamento:
  nombre: Matemática Aplicada
  semestre: "2026-2027 / 1"
  tope_horas: 160
  filas_por_profesor: 8

profesores:
  - {id: PIAD, nombre: "Pedro I. Alonso", grado: "Dr."}
  - {id: MARA, nombre: "Maria Ramirez", grado: "MSc.", tope_horas: 80}

asignaturas:
  - id: EST-CC
    nombre: "Estadística (CC)"
    carrera: "Ciencia de la Computación"
    horas_conf: 32
    horas_cp: 32
    grupos_cp: 2
  - id: EST-MAT
    nombre: "Estadística (Mat)"
    carrera: "Matemática"
    horas_conf: 32
    horas_cp: 32
    grupos_cp: 1
"""


def test_carga_valida(tmp_path):
    d = cargar_departamento(_yaml(tmp_path, BASE))
    assert d.nombre == "Matemática Aplicada"
    assert d.semestre == "2026-2027 / 1"
    assert d.tope_horas == 160
    assert d.filas_por_profesor == 8
    assert d.profesores[1].tope_horas == 80
    assert d.asignaturas[0].grupos_cp == 2
    assert len(d.filas()) == 5


MINIMO = """
departamento:
  nombre: X
  semestre: S1
profesores:
  - {id: PIAD, nombre: "Pedro", grado: "Dr."}
asignaturas:
  - {id: A, nombre: "A", carrera: "C", horas_conf: 32, horas_cp: 0, grupos_cp: 0}
"""


def test_defaults(tmp_path):
    d = cargar_departamento(_yaml(tmp_path, MINIMO))
    assert d.tope_horas is None
    assert d.filas_por_profesor == 10


def _espera_error(tmp_path, texto, fragmento):
    with pytest.raises(ErrorConfig, match=fragmento):
        cargar_departamento(_yaml(tmp_path, texto))


def test_raiz_no_dict(tmp_path):
    _espera_error(tmp_path, "- 1\n- 2\n", "diccionario")


def test_sin_profesores(tmp_path):
    _espera_error(tmp_path, BASE.replace("profesores:", "profesores: []\nignorar:"),
                  "profesores")


def test_profesor_duplicado(tmp_path):
    texto = BASE.replace('{id: MARA, nombre: "Maria Ramirez", grado: "MSc.", tope_horas: 80}',
                         '{id: PIAD, nombre: "Otro", grado: "Dr."}')
    _espera_error(tmp_path, texto, "duplicado.*PIAD")


def test_asignatura_duplicada(tmp_path):
    texto = BASE.replace("id: EST-MAT", "id: EST-CC")
    _espera_error(tmp_path, texto, "duplicado.*EST-CC")


def test_horas_negativas(tmp_path):
    _espera_error(tmp_path, BASE.replace("horas_conf: 32", "horas_conf: -1", 1),
                  "EST-CC.*negativ")


def test_grupos_negativos(tmp_path):
    _espera_error(tmp_path, BASE.replace("grupos_cp: 2", "grupos_cp: -2"),
                  "EST-CC.*negativ")


def test_grupos_sin_horas_cp(tmp_path):
    _espera_error(tmp_path, BASE.replace("horas_cp: 32", "horas_cp: 0", 1),
                  "EST-CC.*horas_cp")


def test_tope_no_positivo(tmp_path):
    _espera_error(tmp_path, BASE.replace("tope_horas: 160", "tope_horas: 0"),
                  "tope_horas")


def test_falta_campo_obligatorio(tmp_path):
    _espera_error(tmp_path, BASE.replace("    carrera: \"Matemática\"\n", ""),
                  "EST-MAT.*carrera")


def test_asignatura_sin_carga(tmp_path):
    # Una asignatura sin Conf y sin CP no genera ninguna fila: config invalida.
    texto = MINIMO.replace("horas_conf: 32", "horas_conf: 0")
    _espera_error(tmp_path, texto, "A.*sin carga")
