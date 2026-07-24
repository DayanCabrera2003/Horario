from tribunales import layout as L


def test_columnas_de_profesor():
    assert L.COLS_PROFESOR == ("C", "D", "E", "F")


def test_fila_titulo_primer_local():
    # n_momentos=1: bloque local 0 empieza en fila 1
    assert L.fila_titulo_local(0, n_momentos=1) == 1
    # local 1 empieza tras (1+1+1+1)=4 filas -> fila 5
    assert L.fila_titulo_local(1, n_momentos=1) == 5


def test_fila_de_momento():
    # local 0, momento 0, n_momentos=1: titulo(1)+encabezado(1) -> fila 3
    assert L.fila_momento(0, 0, n_momentos=1) == 3
    # local 0, momento 1, n_momentos=2 -> 1+2+1 = fila 4
    assert L.fila_momento(0, 1, n_momentos=2) == 4


def test_celda_entrada_localizar():
    assert L.LOCALIZAR_CELDA_ENTRADA == "B1"


def test_bloques_localizar_apilan_por_altura():
    # tabla 0 empieza en fila 3; con n_momentos=2 su altura es 1+2+1=4 -> tabla 1 en fila 7
    assert L.localizar_fila_titulo(0, alturas_previas=0) == 3
    assert L.localizar_fila_titulo(1, alturas_previas=4) == 7
