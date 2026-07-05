from horarios.modelo import Aula, Asignatura, Grupo, Anio, Asignacion, Horario


def test_grupo_id_se_deriva():
    assert Grupo(carrera="C", anio=1, sesion=1, numero=3).id == "C113"
    assert Grupo(carrera="N", anio=2, sesion=1, numero=3).id == "N213"


def test_grupo_anio_codigo():
    assert Grupo(carrera="C", anio=1, sesion=2, numero=1).anio_codigo == "C1"
    assert Grupo(carrera="M", anio=4, sesion=1, numero=1).anio_codigo == "M4"


def test_anio_codigo():
    a = Anio(carrera="C", numero=1, asignaturas=())
    assert a.codigo == "C1"


def test_horario_celdas_por_defecto_vacio():
    h = Horario(grupo_id="C111")
    assert h.celdas == {}
    h.celdas[("Lunes", 1)] = Asignacion(asig="L-C", aula="Aula 6")
    assert h.celdas[("Lunes", 1)].aula == "Aula 6"
