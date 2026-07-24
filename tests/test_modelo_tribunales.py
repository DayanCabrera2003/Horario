from tribunales.modelo import Momento, Tesis, Dia


def test_momento_id_combina_inicio_y_fin():
    assert Momento("09:00", "10:00").id == "09:00-10:00"


def test_tesis_identificada_por_estudiante():
    t = Tesis(estudiante="JPER", tutor="PIAD", oponente="MARA",
              presidente="LGOM", secretario="ANSU")
    assert t.estudiante == "JPER"
    # Los cuatro profesores del tribunal, sin el estudiante
    assert t.profesores() == ("PIAD", "MARA", "LGOM", "ANSU")


def test_dia_expone_sus_momentos():
    d = Dia(fecha="2026-07-27", momentos=(Momento("09:00", "10:00"),))
    assert d.momentos[0].id == "09:00-10:00"
