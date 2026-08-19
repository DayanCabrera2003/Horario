from departamento import layout as L


def test_columnas_asignacion():
    assert L.ENCABEZADOS_ASIGNACION == (
        "Asignatura", "Carrera", "Tipo", "Grupo", "Horas", "Profesor", "Nombre")
    assert L.COL_PROFESOR == "F"
    assert L.COL_ULTIMA == "G"


def test_filas_asignacion():
    # Titulo en 1, encabezados en 3, la primera fila de carga en 4.
    assert L.FILA_ENCABEZADO_ASIGNACION == 3
    assert L.fila_carga(0) == 4
    assert L.fila_carga(4) == 8


def test_bloque_profesor():
    # cabecera + valores + subcabecera + filas reservadas + TOTAL + blanco.
    assert L.altura_bloque_profesor(10) == 15
    assert L.prof_fila_cabecera(0, 10) == 3
    assert L.prof_fila_cabecera(1, 10) == 18
    assert L.prof_fila_valores(0, 10) == 4
    assert L.prof_fila_subcabecera(0, 10) == 5
    assert L.prof_fila_detalle(0, 0, 10) == 6
    assert L.prof_fila_detalle(0, 9, 10) == 15
    assert L.prof_fila_total(0, 10) == 16


def test_bloque_asignatura():
    # titulo + subcabecera + filas de carga + blanco; altura variable, se pasa
    # el acumulado de alturas previas como en la hoja de localizar.
    assert L.altura_bloque_asignatura(3) == 6
    assert L.asig_fila_titulo(0) == 3
    assert L.asig_fila_titulo(6) == 9
    assert L.asig_fila_subcabecera(0) == 4
    assert L.asig_fila_carga(0, 0) == 5
    assert L.asig_fila_carga(0, 2) == 7
    assert L.asig_fila_carga(6, 0) == 11
