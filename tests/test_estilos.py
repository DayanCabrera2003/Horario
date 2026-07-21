from horarios import estilos


def test_hay_color_para_cada_anio():
    for cod in ["C1","C2","C3","C4","M1","M2","M3","M4","D1","D2","D3","D4"]:
        assert cod in estilos.ANIO_COLOR
        assert len(estilos.ANIO_COLOR[cod]) == 6  # hex RRGGBB


def test_color_conflicto_definido():
    assert len(estilos.COLOR_CONFLICTO) == 6


def test_fill_devuelve_patternfill():
    from openpyxl.styles import PatternFill
    assert isinstance(estilos.fill(estilos.ANIO_COLOR["C1"]), PatternFill)


def test_borde_fino_tiene_los_cuatro_lados_thin():
    from openpyxl.styles import Border
    b = estilos.borde_fino()
    assert isinstance(b, Border)
    assert b.left.style == "thin"
    assert b.right.style == "thin"
    assert b.top.style == "thin"
    assert b.bottom.style == "thin"


def test_lado_fino_es_thin():
    from openpyxl.styles.borders import Side
    lado = estilos.lado_fino()
    assert isinstance(lado, Side)
    assert lado.style == "thin"


def test_lado_medio_es_medium():
    lado = estilos.lado_medio()
    assert lado.style == "medium"


def test_alineacion_ajuste_activa_wrap():
    from openpyxl.styles import Alignment
    al = estilos.alineacion_ajuste()
    assert isinstance(al, Alignment)
    assert al.wrap_text is True
