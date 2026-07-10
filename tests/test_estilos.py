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
