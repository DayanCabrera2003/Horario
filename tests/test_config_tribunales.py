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


NUEVO = """
profesores:
  - {id: PIAD, nombre: "Pedro", grado: "Dr."}
  - {id: MARA, nombre: "Maria", grado: "MSc."}
  - {id: LGOM, nombre: "Luis", grado: "Dr."}
  - {id: ANSU, nombre: "Ana", grado: "MSc."}
  - {id: RTOR, nombre: "Raul", grado: "Dr."}
estudiantes:
  - {id: JPER, nombre: "Juan"}
  - {id: MGOM, nombre: "Mario"}
locales:
  - {id: POST, nombre: "Postgrado"}
dias:
  - fecha: 2026-07-27
    momentos:
      - {inicio: "09:00", fin: "10:00"}
tesis:
  - estudiantes: [JPER, MGOM]
    tutores: [PIAD, MARA]
    oponente: LGOM
    presidente: ANSU
    secretario: RTOR
    vocal: PIAD
"""


def test_carga_esquema_nuevo_listas_y_vocal(tmp_path):
    fac = cargar_facultad(_yaml(tmp_path, NUEVO))
    t = fac.tesis[0]
    assert t.estudiantes == ("JPER", "MGOM")   # tesis conjunta
    assert t.tutores == ("PIAD", "MARA")       # co-tutoria
    assert t.vocal == "PIAD"
    assert t.estudiante == "JPER" and t.tutor == "PIAD"   # principales


def test_vocal_inexistente_falla(tmp_path):
    malo = NUEVO.replace("vocal: PIAD", "vocal: ZZZZ")
    with pytest.raises(ErrorConfig):
        cargar_facultad(_yaml(tmp_path, malo))


def test_cotutor_inexistente_falla(tmp_path):
    malo = NUEVO.replace("tutores: [PIAD, MARA]", "tutores: [PIAD, ZZZZ]")
    with pytest.raises(ErrorConfig):
        cargar_facultad(_yaml(tmp_path, malo))


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


def test_raiz_no_es_diccionario(tmp_path):
    # Un YAML que es una lista, no un mapa.
    with pytest.raises(ErrorConfig, match="diccionario"):
        cargar_facultad(_yaml(tmp_path, "- PIAD\n- MARA\n"))


def test_raiz_vacia(tmp_path):
    # Un archivo vacio deja los datos en None, que tampoco es un diccionario.
    with pytest.raises(ErrorConfig, match="diccionario"):
        cargar_facultad(_yaml(tmp_path, ""))


def test_lista_obligatoria_vacia_falla(tmp_path):
    # `profesores: []` no es lo mismo que faltar: hay que avisar igual.
    mal = BASE.replace("""profesores:
  - {id: PIAD, nombre: "Pedro", grado: "Dr."}
  - {id: MARA, nombre: "Maria", grado: "MSc."}
  - {id: LGOM, nombre: "Luis", grado: "Dr."}
  - {id: ANSU, nombre: "Ana", grado: "MSc."}
""", "profesores: []\n")
    with pytest.raises(ErrorConfig, match="profesores"):
        cargar_facultad(_yaml(tmp_path, mal))


def test_tesis_sin_tutor_ni_tutores_falla(tmp_path):
    # Ni el campo nuevo en plural ni el antiguo en singular.
    mal = BASE.replace("tutor: PIAD, ", "")
    with pytest.raises(ErrorConfig, match="tutores"):
        cargar_facultad(_yaml(tmp_path, mal))


def test_tesis_con_lista_de_tutores_vacia_falla(tmp_path):
    # El campo esta, pero no nombra a nadie.
    mal = BASE.replace("tutor: PIAD", "tutores: []")
    with pytest.raises(ErrorConfig, match="tutores"):
        cargar_facultad(_yaml(tmp_path, mal))


def test_dia_sin_momentos_falla(tmp_path):
    # Un dia sin momentos no genera hoja: mejor avisar que producirla vacia.
    mal = BASE.replace("""    momentos:
      - {inicio: "09:00", fin: "10:00"}
""", "")
    with pytest.raises(ErrorConfig, match="momentos"):
        cargar_facultad(_yaml(tmp_path, mal))


def _asignacion(tmp_path, linea):
    a = tmp_path / "asig.yaml"
    a.write_text(linea, encoding="utf-8")
    return a


def test_asignacion_con_estudiante_inexistente(tmp_path):
    fac = cargar_facultad(_yaml(tmp_path, BASE))
    a = _asignacion(tmp_path, '- {estudiante: XXXX, local: POST, '
                              'fecha: 2026-07-27, momento: "09:00-10:00"}\n')
    with pytest.raises(ErrorConfig, match="estudiante inexistente"):
        cargar_asignaciones(a, fac)


def test_asignacion_con_local_inexistente(tmp_path):
    fac = cargar_facultad(_yaml(tmp_path, BASE))
    a = _asignacion(tmp_path, '- {estudiante: JPER, local: XXXX, '
                              'fecha: 2026-07-27, momento: "09:00-10:00"}\n')
    with pytest.raises(ErrorConfig, match="local inexistente"):
        cargar_asignaciones(a, fac)


def test_asignacion_con_fecha_inexistente(tmp_path):
    fac = cargar_facultad(_yaml(tmp_path, BASE))
    a = _asignacion(tmp_path, '- {estudiante: JPER, local: POST, '
                              'fecha: 2026-12-31, momento: "09:00-10:00"}\n')
    with pytest.raises(ErrorConfig, match="fecha inexistente"):
        cargar_asignaciones(a, fac)
