from horarios import layout as L


def test_cada_turno_ocupa_tres_filas():
    # Desde la fase 3b un turno son tres filas: asignatura, aula y profesor.
    # Turno 1 -> B4/B5/B6; turno 2 -> B7/B8/B9.
    assert L.celda_asig(dia_idx=0, turno=1) == "B4"
    assert L.celda_aula(dia_idx=0, turno=1) == "B5"
    assert L.celda_profesor(dia_idx=0, turno=1) == "B6"
    assert L.celda_asig(dia_idx=0, turno=2) == "B7"
    assert L.celda_aula(dia_idx=0, turno=2) == "B8"
    assert L.celda_profesor(dia_idx=0, turno=2) == "B9"


def test_celda_dia_desplaza_columna():
    assert L.celda_asig(dia_idx=1, turno=1) == "C4"  # Martes
    assert L.celda_asig(dia_idx=4, turno=1) == "F4"  # Viernes


def test_rango_horario_cubre_todos_los_turnos():
    # 5 días, 6 turnos, 3 filas por turno -> B4:F21
    assert L.rango_horario(n_dias=5, n_turnos=6) == "B4:F21"


def test_las_separadoras_van_bajo_la_fila_de_profesor():
    # La linea gruesa cierra el turno, y el turno ahora acaba en el profesor.
    separadoras = L.filas_separadoras_turno(n_dias=2, n_turnos=3)
    assert separadoras == ["A6:C6", "A9:C9"]


def test_las_etiquetas_de_turno_llegan_hasta_la_ultima_fila():
    assert L.rango_etiquetas_turno(n_turnos=2) == "A4:A9"


def test_hay_un_rango_por_fila_de_profesor():
    assert L.rangos_filas_profesor(n_dias=2, n_turnos=2) == "B6:C6 B9:C9"


def test_tabla_asignaturas_posiciones():
    assert L.celda_asig_tabla_id(fila_datos=0) == "I4"
    assert L.celda_asig_tabla_frec(fila_datos=0) == "K4"
    assert L.celda_asig_tabla_asignadas(fila_datos=0) == "L4"
    assert L.celda_asig_tabla_faltan(fila_datos=0) == "M4"


def test_rango_ids_asignaturas_abs():
    assert L.rango_ids_asignaturas_abs(2) == "$I$4:$I$5"
    assert L.rango_ids_asignaturas_abs(11) == "$I$4:$I$14"
