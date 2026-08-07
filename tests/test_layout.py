from horarios import layout as L


def test_celda_asignatura():
    # turno 1, primer día (Lunes, idx 0) -> B4 (días pegados a la columna A de turnos)
    assert L.celda_asig(dia_idx=0, turno=1) == "B4"
    # turno 2, Lunes -> B6 ; aula debajo -> B7
    assert L.celda_asig(dia_idx=0, turno=2) == "B6"
    assert L.celda_aula(dia_idx=0, turno=2) == "B7"


def test_celda_dia_desplaza_columna():
    assert L.celda_asig(dia_idx=1, turno=1) == "C4"  # Martes
    assert L.celda_asig(dia_idx=4, turno=1) == "F4"  # Viernes


def test_rango_horario_cubre_todos_los_turnos():
    # 5 días, 6 turnos -> B4:F15
    assert L.rango_horario(n_dias=5, n_turnos=6) == "B4:F15"


def test_tabla_asignaturas_posiciones():
    assert L.celda_asig_tabla_id(fila_datos=0) == "I4"
    assert L.celda_asig_tabla_frec(fila_datos=0) == "K4"
    assert L.celda_asig_tabla_asignadas(fila_datos=0) == "L4"
    assert L.celda_asig_tabla_faltan(fila_datos=0) == "M4"


def test_rango_ids_asignaturas_abs():
    assert L.rango_ids_asignaturas_abs(2) == "$I$4:$I$5"
    assert L.rango_ids_asignaturas_abs(11) == "$I$4:$I$14"
