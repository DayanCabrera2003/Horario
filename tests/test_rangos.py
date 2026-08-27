"""Tests del helper de rangos nombrados dinamicos.

El texto que genera se comprobo en LibreOffice antes de escribir este modulo
(spike de la tarea 3a.1): un rango OFFSET(...COUNTA(...)) sobrevive al
round-trip por Calc, se resuelve a las filas escritas y no a la capacidad
declarada, y crece al escribir en la reserva.
"""
from comun.rangos import rango_dinamico, CAPACIDAD_MINIMA, capacidad_para


def test_el_rango_se_dimensiona_con_counta_y_no_con_la_capacidad():
    # La hoja va siempre entrecomillada, tambien cuando no haria falta: es lo
    # que devuelve quote_sheetname y Calc lo acepta igual (comprobado en el
    # spike de la 3a.1, con nombre simple y con nombre con espacios).
    r = rango_dinamico("Profesores", "A", fila_inicial=2, capacidad=20)
    assert r == "OFFSET('Profesores'!$A$2,0,0,COUNTA('Profesores'!$A$2:$A$21),1)"


def test_la_hoja_va_entrecomillada_si_su_nombre_lleva_espacios():
    # Sin comillas, Calc y Excel leen "Carga" como la hoja y el resto sobra.
    r = rango_dinamico("Carga por profesor", "B", fila_inicial=4, capacidad=10)
    assert r.startswith("OFFSET('Carga por profesor'!$B$4")
    assert "COUNTA('Carga por profesor'!$B$4:$B$13)" in r


def test_el_rango_no_lleva_igual_delante():
    # openpyxl escribe attr_text verbatim; un '=' inicial rompe el nombre.
    assert not rango_dinamico("Aulas", "A", 2, 5).startswith("=")


def test_la_reserva_es_la_mitad_de_lo_declarado_con_un_minimo():
    # Con pocos datos manda el minimo; con muchos, el 50%.
    assert capacidad_para(4) == 4 + CAPACIDAD_MINIMA
    assert capacidad_para(60) == 60 + 30
    assert capacidad_para(0) == CAPACIDAD_MINIMA


def test_un_rango_puede_abarcar_varias_columnas():
    # ProfesoresTabla necesita dos: la clave y el nombre que devuelve BUSCARV.
    r = rango_dinamico("Profesores", "A", 2, 20, columnas=2)
    assert r.endswith(",2)")
    # La cuenta sigue siendo sobre la primera columna: es la que manda.
    assert "COUNTA('Profesores'!$A$2:$A$21)" in r
