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
    assert any("celda múltiple" in i for i in res["incidencias"])


def test_parsear_celda_descarta_los_trozos_que_no_son_clase():
    # Las tres razones por las que un trozo de celda se descarta, cada una por su
    # lado, para que el "no sale nada" no pase por el motivo equivocado.
    abrevs = {"IP"}
    # El trozo entero era una anotacion: se va y el resto de la celda sobrevive.
    assert H.quitar_anotaciones("(solo notas)") == ""
    assert H.parsear_celda("IP Aula 8 / (solo notas)", abrevs) == [("IP", "Aula 8")]
    # La abreviatura no esta en la tabla del año.
    assert H.parsear_celda("XYZ Aula 8", abrevs) == []
    # La abreviatura si esta, pero lo que sigue no es un aula.
    assert H.parsear_celda("IP 4:45pm a 5:35pm", abrevs) == []


def test_construir_reporta_las_celdas_que_no_pudo_parsear():
    # Una celda con texto que no produce ninguna clase tiene que aparecer en el
    # informe: es transcripcion que alguien debe revisar a mano, no un hueco.
    rejilla = {1: {"Lunes": "IP Aula 8*", "Martes": "ZZZ Aula 7"}}
    res = H.construir({"D111": rejilla}, _TABLAS)
    sin_parsear = [i for i in res["incidencias"] if "sin parsear" in i]
    assert len(sin_parsear) == 1
    assert "ZZZ Aula 7" in sin_parsear[0]
    assert "D111" in sin_parsear[0] and "Martes" in sin_parsear[0]


def test_construir_no_reporta_las_celdas_vacias():
    # El contrapunto: una casilla vacia no es una incidencia, es un turno libre.
    rejilla = {1: {"Lunes": "IP Aula 8*", "Martes": "", "Miércoles": "   "}}
    res = H.construir({"D111": rejilla}, _TABLAS)
    assert not [i for i in res["incidencias"] if "sin parsear" in i]


def test_nombre_de_id_desconocido_cae_en_el_propio_id():
    # Salvaguarda: si un id no casa con ninguna abreviatura de la tabla, se
    # muestra el id en vez de dejar la casilla vacia.
    assert H._nombre_de_id("ZZZ", {"IP": "Introducción a la Programación"}) == "ZZZ"
    # Y con tabla vacia, lo mismo.
    assert H._nombre_de_id("IP", {}) == "IP"


def test_escribir_yaml_deja_los_dos_archivos_releibles(tmp_path):
    import yaml
    res = H.construir({"D111": _D111}, _TABLAS)
    fac, hor = tmp_path / "facultad.yaml", tmp_path / "horarios.yaml"
    H.escribir_yaml(res, fac, hor)
    # Se releen: lo escrito tiene que volver igual, con los acentos intactos.
    datos_fac = yaml.safe_load(fac.read_text(encoding="utf-8"))
    datos_hor = yaml.safe_load(hor.read_text(encoding="utf-8"))
    assert datos_fac == res["facultad"]
    assert datos_hor == res["horarios"]
    assert "Análisis Matemático I" in fac.read_text(encoding="utf-8")


def test_escribir_incidencias_lista_todas_y_cuenta(tmp_path):
    res = H.construir({"D111": _D111}, _TABLAS)
    ruta = tmp_path / "incidencias.md"
    H.escribir_incidencias(res, ruta)
    texto = ruta.read_text(encoding="utf-8")
    assert f"Total: {len(res['incidencias'])}" in texto
    for inc in res["incidencias"]:
        assert f"- {inc}" in texto


def test_escribir_incidencias_sin_ninguna(tmp_path):
    # Un horario limpio deja el informe en cero, no un archivo a medias.
    ruta = tmp_path / "incidencias.md"
    H.escribir_incidencias({"incidencias": []}, ruta)
    texto = ruta.read_text(encoding="utf-8")
    assert "Total: 0" in texto
    assert texto.endswith("\n")


def test_un_grupo_sin_ninguna_celda_valida_no_entra_en_los_horarios():
    # Si nada de la rejilla parsea, el grupo no tiene horario que escribir: no
    # debe aparecer con un diccionario vacio, porque el generador lo tomaria por
    # un grupo sin clases en vez de por una transcripcion que hay que revisar.
    res = H.construir({"D111": {1: {"Lunes": "ZZZ Aula 8"}}}, _TABLAS)
    assert res["horarios"] == {}
    assert any("sin parsear" in i for i in res["incidencias"])
