from extraccion.deduplicar import Deduplicador


def test_une_variantes_de_acento_y_grado():
    d = Deduplicador()
    a = d.agregar("MSc. Fernando Raúl Rodríguez Flores")
    b = d.agregar("Fernando Raul Rodríguez Flores")
    c = d.agregar(" MSc. Fernando Raúl Rodríguez Flores")
    assert a == b == c            # misma persona
    mapa = d.resolver()
    assert len(mapa) == 1
    assert mapa[0]["grado"] == "MSc."


def test_une_erratas_cercanas_mismo_nombre():
    d = Deduplicador()
    x = d.agregar("MSc. Joanna Campbel Amos")
    y = d.agregar("MSc. Joanna Campbell Amos")
    assert x == y                 # 'Campbel' / 'Campbell' se fusionan


def test_no_une_personas_distintas():
    d = Deduplicador()
    p = d.agregar("Dr. Alejandro Piad Morfis")
    q = d.agregar("Lic. Alejandro Beltrán Varela")
    assert p != q                 # mismo primer nombre pero personas distintas


def test_ids_unicos_y_legibles():
    d = Deduplicador()
    d.agregar("Pedro Alonso Diaz")
    d.agregar("Maria Ramirez Gomez")
    mapa = d.resolver()
    ids = {g["id"] for g in mapa.values()}
    assert len(ids) == 2          # sin colisiones
    assert all(i.isalnum() and i.isupper() for i in ids)


def test_nombre_canonico_es_el_mas_frecuente():
    d = Deduplicador()
    d.agregar("Fernando Raul Rodríguez Flores")
    d.agregar("Fernando Raúl Rodríguez Flores")
    d.agregar("Fernando Raúl Rodríguez Flores")
    mapa = d.resolver()
    assert mapa[0]["nombre"] == "Fernando Raúl Rodríguez Flores"


def test_vacio_devuelve_none():
    d = Deduplicador()
    assert d.agregar("   ") is None
