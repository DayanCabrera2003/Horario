from departamento import layout as L


def test_columnas_asignacion():
    assert L.ENCABEZADOS_ASIGNACION == (
        "Id", "Asignatura", "Carrera", "Tipo", "Grupo", "Horas", "Profesor",
        "Nombre")
    assert L.COL_ID == "A"
    assert L.COL_PROFESOR == "G"
    assert L.COL_ULTIMA == "H"


def test_el_panel_va_detras_de_una_canaleta():
    # Una columna vacia entre la tabla y el panel: asi el panel queda fuera del
    # autofiltro y del formato condicional, que abarcan hasta COL_ULTIMA.
    assert L.COL_CANALETA > L.COL_ULTIMA
    assert L.COL_PANEL_ID > L.COL_CANALETA
    assert L.ENCABEZADOS_PANEL == ("Id", "Nombre", "Horas", "Asignaturas",
                                   "Tope")


def test_fila_del_panel():
    # El panel comparte la fila de encabezado con la tabla, para que las dos se
    # lean a la misma altura.
    assert L.fila_panel(0) == L.fila_carga(0)


def test_filas_asignacion():
    # Titulo en 1, encabezados en 3, la primera fila de carga en 4.
    assert L.FILA_ENCABEZADO_ASIGNACION == 3
    assert L.fila_carga(0) == 4
    assert L.fila_carga(4) == 8


def test_rango_editable():
    # 7 filas (5 de carga + 2 de reserva) -> G4:G10. Lo comparten el desplegable
    # de profesores y la proteccion de hoja, y sirve para las cuatro columnas
    # que se escriben a mano.
    assert L.rango_editable(L.COL_PROFESOR, 7) == "G4:G10"
    assert L.rango_editable(L.COL_ID, 5) == "A4:A8"


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
