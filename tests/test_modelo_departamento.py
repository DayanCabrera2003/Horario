from departamento.modelo import (
    Profesor, Asignatura, FilaCarga, Departamento, filas_de_carga,
)


def _asignatura(**cambios):
    base = dict(id="EST-CC", nombre="Estadística (CC)",
                carrera="Ciencia de la Computación",
                horas_conf=32, horas_cp=32, grupos_cp=2)
    base.update(cambios)
    return Asignatura(**base)


def test_profesor_tope_opcional():
    p = Profesor(id="PIAD", nombre="Pedro", grado="Dr.")
    assert p.tope_horas is None
    q = Profesor(id="MARA", nombre="Maria", grado="MSc.", tope_horas=80)
    assert q.tope_horas == 80


def test_filas_de_carga_conf_mas_un_grupo_por_cp():
    filas = filas_de_carga((_asignatura(),))
    assert filas == (
        FilaCarga(asignatura=_asignatura(), tipo="Conf", grupo=None, horas=32),
        FilaCarga(asignatura=_asignatura(), tipo="CP", grupo=1, horas=32),
        FilaCarga(asignatura=_asignatura(), tipo="CP", grupo=2, horas=32),
    )


def test_filas_de_carga_sin_conferencia():
    filas = filas_de_carga((_asignatura(horas_conf=0, grupos_cp=1),))
    assert [f.tipo for f in filas] == ["CP"]


def test_filas_de_carga_sin_cp():
    filas = filas_de_carga((_asignatura(horas_cp=0, grupos_cp=0),))
    assert [f.tipo for f in filas] == ["Conf"]


def test_filas_de_carga_respeta_orden_de_asignaturas():
    a = _asignatura()
    b = _asignatura(id="EST-MAT", nombre="Estadística (Mat)",
                    carrera="Matemática", grupos_cp=1)
    filas = filas_de_carga((a, b))
    assert [f.asignatura.id for f in filas] == ["EST-CC"] * 3 + ["EST-MAT"] * 2


def test_departamento_tope_efectivo():
    piad = Profesor(id="PIAD", nombre="Pedro", grado="Dr.")
    mara = Profesor(id="MARA", nombre="Maria", grado="MSc.", tope_horas=80)
    d = Departamento(nombre="Matemática Aplicada", semestre="2026-2027 / 1",
                     tope_horas=160, filas_por_profesor=10,
                     profesores=(piad, mara), asignaturas=(_asignatura(),))
    # El tope del profesor manda; sin el, se hereda el global.
    assert d.tope_efectivo(piad) == 160
    assert d.tope_efectivo(mara) == 80


def test_departamento_sin_tope_global():
    piad = Profesor(id="PIAD", nombre="Pedro", grado="Dr.")
    d = Departamento(nombre="X", semestre="S1", tope_horas=None,
                     filas_por_profesor=10, profesores=(piad,),
                     asignaturas=(_asignatura(),))
    assert d.tope_efectivo(piad) is None
