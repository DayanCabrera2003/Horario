from extraccion import horario_pdf as H


def test_normalizar_aula():
    assert H.normalizar_aula("Aula 8*") == "Aula 8"
    assert H.normalizar_aula("8") == "Aula 8"
    assert H.normalizar_aula("Lab") == "Lab"
    assert H.normalizar_aula("Lab2") == "Lab2"
    assert H.normalizar_aula("Aula Lab") == "Lab"
    assert H.normalizar_aula("SEDER") == "SEDER"
    assert H.normalizar_aula("") == ""


def test_normalizar_aula_rechaza_no_reconocidas():
    # Restos de celdas con notacion rara no son aulas -> "" (pasan a incidencia).
    assert H.normalizar_aula("4:45pm a 5:35pm") == ""
    assert H.normalizar_aula("I cp 5") == ""


def test_id_asignatura_con_tipo():
    assert H.id_asignatura("AM I", "") == "AM-I"
    assert H.id_asignatura("ED", "c") == "ED-C"
    assert H.id_asignatura("ED", "cp") == "ED-CP"


def test_parsear_celda_simple_y_tipo():
    abrevs = {"IP", "AM I", "ED", "MA"}
    assert H.parsear_celda("IP Aula 8*", abrevs) == [("IP", "Aula 8")]
    assert H.parsear_celda("AM I Aula 7*", abrevs) == [("AM-I", "Aula 7")]
    assert H.parsear_celda("ED c 2", abrevs) == [("ED-C", "Aula 2")]
    # Tipo pegado al numero ('MD c6') y aula tipo Lab ('cp Lab2').
    assert H.parsear_celda("MD c6", abrevs | {"MD"}) == [("MD-C", "Aula 6")]
    assert H.parsear_celda("RN cp Lab2", abrevs | {"RN"}) == [("RN-CP", "Lab2")]
    # La anotacion '(EDO)' se ignora; queda 'MA cp 6'.
    assert H.parsear_celda("MA (EDO) cp 6 (con C211)", abrevs) == [("MA-CP", "Aula 6")]


def test_parsear_celda_dividida_por_semanas():
    abrevs = {"F", "ICD"}
    r = H.parsear_celda("F Aula 7 (s. 1-8) / ICD Aula 7 (s. 9-16)", abrevs)
    assert r == [("F", "Aula 7"), ("ICD", "Aula 7")]


# Transcripcion minima de CD para probar el ensamblado completo.
_TABLAS = {
    ("D", 1): {"AL": "Álgebra Lineal", "L": "Lógica", "IP": "Introducción a la Programación",
               "ICD": "Introducción a la Ciencia de Datos", "AM I": "Análisis Matemático I",
               "F": "Filosofía", "EF": "Educación Física I"},
}
_D111 = {
    1: {"Lunes": "IP Aula 8*", "Martes": "ICD Aula 7", "Miércoles": "AL Aula 7*",
        "Jueves": "AM I Aula 7*", "Viernes": ""},
    2: {"Lunes": "F Aula 7", "Martes": "AL Aula 6*", "Miércoles": "EF SEDER",
        "Jueves": "AL Aula 7*", "Viernes": "F Aula 7 (s. 1-8) / ICD Aula 7 (s. 9-16)"},
    3: {"Lunes": "L Aula 6*", "Martes": "AM I Aula 6*", "Miércoles": "AM I Aula 7*",
        "Jueves": "IP Lab*", "Viernes": "L Aula 7*"},
}


def test_construir_frecuencias_y_horarios():
    res = H.construir({"D111": _D111}, _TABLAS)
    fac = res["facultad"]
    assert fac["turnos"] == 3
    # Aulas normalizadas y ordenadas.
    assert fac["aulas"] == ["Aula 6", "Aula 7", "Aula 8", "Lab", "SEDER"]
    # Frecuencia de AL = 3 (Miércoles T1, Martes T2, Jueves T2).
    asigs = {a["id"]: a["frecuencia"] for a in fac["carreras"]["D"]["años"][1]["asignaturas"]}
    assert asigs["AL"] == 3
    assert asigs["AM-I"] == 3
    assert asigs["IP"] == 2
    assert asigs["L"] == 2
    # El nombre de 'AM-I' se recupera de la tabla (id con guion != sufijo de tipo).
    nombres = {a["id"]: a["nombre"] for a in fac["carreras"]["D"]["años"][1]["asignaturas"]}
    assert nombres["AM-I"] == "Análisis Matemático I"
    # El grupo D111 aparece en la sesion 1 de D1.
    assert fac["carreras"]["D"]["años"][1]["sesiones"] == {1: {"grupos": [1]}}
    # Horario del grupo: celda con asig y aula.
    assert res["horarios"]["D111"]["Lunes"][1] == {"asig": "IP", "aula": "Aula 8"}


def test_construir_reporta_celda_multiple():
    res = H.construir({"D111": _D111}, _TABLAS)
    assert any("celda multiple" in i for i in res["incidencias"])
