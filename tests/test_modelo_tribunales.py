from tribunales.modelo import Momento, Tesis, Dia


def test_momento_id_combina_inicio_y_fin():
    assert Momento("09:00", "10:00").id == "09:00-10:00"


def test_tesis_identificada_por_estudiante_principal():
    t = Tesis(estudiantes=("JPER",), tutores=("PIAD",), oponente="MARA",
              presidente="LGOM", secretario="ANSU", vocal="RTOR")
    assert t.estudiante == "JPER"     # principal
    assert t.tutor == "PIAD"          # tutor principal
    # Todos los profesores del tribunal, con el vocal e ignorando al estudiante.
    assert t.profesores() == ("PIAD", "MARA", "LGOM", "ANSU", "RTOR")


def test_tesis_sin_vocal_no_lo_cuenta():
    t = Tesis(estudiantes=("JPER",), tutores=("PIAD",), oponente="MARA",
              presidente="LGOM", secretario="ANSU")
    assert t.vocal == ""
    assert t.profesores() == ("PIAD", "MARA", "LGOM", "ANSU")


def test_tesis_conjunta_y_cotutoria():
    t = Tesis(estudiantes=("JPER", "MGOM"), tutores=("PIAD", "MARA"),
              oponente="LGOM", presidente="ANSU", secretario="RTOR")
    assert t.estudiante == "JPER"     # principal es el primero
    assert t.tutor == "PIAD"
    # Los dos tutores participan en el conteo de profesores del tribunal.
    assert t.profesores()[:2] == ("PIAD", "MARA")


def test_dia_expone_sus_momentos():
    d = Dia(fecha="2026-07-27", momentos=(Momento("09:00", "10:00"),))
    assert d.momentos[0].id == "09:00-10:00"


def test_el_nombre_de_hoja_de_un_dia_es_legible():
    # "2026-07-27" no dice ni que dia de la semana es. La hoja se llama como se
    # lee en voz alta.
    assert Dia(fecha="2026-07-27", momentos=()).nombre_hoja == "27 jul (lun)"


def test_el_nombre_de_hoja_cabe_en_el_limite_de_excel():
    # Excel corta los nombres de hoja en 31 caracteres y prohibe []:*?/\\.
    for iso in ("2026-01-01", "2026-12-31", "2026-07-27"):
        nombre = Dia(fecha=iso, momentos=()).nombre_hoja
        assert len(nombre) <= 31
        assert not set(nombre) & set("[]:*?/\\")

