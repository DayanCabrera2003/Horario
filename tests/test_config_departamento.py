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


@pytest.mark.parametrize("valor", ["0", "-3", '"ocho"', "2.5"])
def test_filas_por_profesor_invalida_falla(tmp_path, valor):
    # Reserva las lineas de detalle de cada bloque de la hoja Profesores: si no
    # es un entero positivo no hay bloque que construir.
    mal = BASE.replace("filas_por_profesor: 8", f"filas_por_profesor: {valor}")
    with pytest.raises(ErrorConfig, match="filas_por_profesor"):
        cargar_departamento(_yaml(tmp_path, mal))


def test_filas_por_profesor_booleana_falla(tmp_path):
    # En Python `True` es un int y pasaria la comprobacion de tipo por accidente;
    # como valor es absurdo, se comprueba aparte.
    mal = BASE.replace("filas_por_profesor: 8", "filas_por_profesor: true")
    with pytest.raises(ErrorConfig, match="filas_por_profesor"):
        cargar_departamento(_yaml(tmp_path, mal))


def test_tope_horas_booleano_falla(tmp_path):
    mal = BASE.replace("tope_horas: 160", "tope_horas: true")
    with pytest.raises(ErrorConfig, match="tope_horas"):
        cargar_departamento(_yaml(tmp_path, mal))


def test_horas_de_asignatura_booleanas_falla(tmp_path):
    mal = BASE.replace("horas_conf: 32", "horas_conf: true", 1)
    with pytest.raises(ErrorConfig, match="horas_conf"):
        cargar_departamento(_yaml(tmp_path, mal))


@pytest.mark.parametrize("valor,motivo", [
    ("-1", "un entero negativo"),
    ("no", "un booleano (en YAML 'no' es False)"),
    ('"mucho"', "texto"),
    ("2.5", "un decimal"),
])
def test_horas_invalidas_dicen_que_hace_falta_un_entero(tmp_path, valor, motivo):
    # Las cuatro formas de equivocarse dan el mismo error, asi que el mensaje
    # tiene que servir para las cuatro: decir "no puede ser negativo" ante un
    # texto o un booleano manda a buscar el signo menos que no existe.
    mal = BASE.replace("horas_conf: 32", f"horas_conf: {valor}", 1)
    with pytest.raises(ErrorConfig,
                       match=r"'horas_conf' debe ser un entero no negativo") as e:
        cargar_departamento(_yaml(tmp_path, mal))
    assert "EST-CC" in str(e.value), motivo
