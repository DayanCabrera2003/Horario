import datetime
from extraccion import normalizar as N


def test_quitar_acentos_conserva_ene():
    assert N.quitar_acentos("Gónzalez") == "Gonzalez"
    assert N.quitar_acentos("Muñoz Peña") == "Muñoz Peña"


def test_extraer_grado_simple_y_repetido():
    assert N.extraer_grado("MSc. Carmen Fernández") == ("MSc.", "Carmen Fernández")
    assert N.extraer_grado("Dr. Alberto Oliva") == ("Dr.", "Alberto Oliva")
    # Grado repetido por errata: se queda con uno y limpia el resto.
    assert N.extraer_grado("Lic. Lic. Alejandro Soto") == ("Lic.", "Alejandro Soto")
    # Variantes de MSc se canonizan.
    assert N.extraer_grado("Msc. Joanna Amos")[0] == "MSc."
    assert N.extraer_grado("MS. Wilfredo Morales")[0] == "MSc."


def test_extraer_grado_sin_grado():
    assert N.extraer_grado("Dany Naranjo Feliciano") == ("", "Dany Naranjo Feliciano")


def test_quitar_anotaciones():
    assert N.quitar_anotaciones("Ana Paula (Graduada de CC)") == "Ana Paula"
    assert N.quitar_anotaciones("Gabriel Fundora (dermatógolo)") == "Gabriel Fundora"


def test_separar_personas_por_coma_y_conjuncion():
    assert N.separar_personas("Lic. Alejandra Monzón, MSc. Fernando Rodríguez") == [
        "Lic. Alejandra Monzón", "MSc. Fernando Rodríguez"]
    assert N.separar_personas("Claudia Hernández y Joel Aparicio") == [
        "Claudia Hernández", "Joel Aparicio"]


def test_separar_personas_no_corta_grado_con_punto():
    # El punto de 'Dr.' no separa; el punto entre dos personas (antes de un grado) si.
    assert N.separar_personas("Dr. Yudivian Almeida") == ["Dr. Yudivian Almeida"]
    assert N.separar_personas("Dra. Suilan Velarde. Lic. Deborah Famadas") == [
        "Dra. Suilan Velarde", "Lic. Deborah Famadas"]


def test_extraer_grado_pegado_al_nombre():
    # 'Dr.Alberto' sin espacio -> el grado se separa del nombre.
    assert N.extraer_grado("Dr.Alberto Fernández Oliva") == ("Dr.", "Alberto Fernández Oliva")
    assert N.extraer_grado("MSc.Yeneit Delgado")[0] == "MSc."


def test_separar_personas_punto_antes_de_grado_con_punto():
    # Antes fallaba porque el grado termina en '.' (el limite de palabra no se
    # cumplia): 'Velarde. Lic. Deborah' debe separar en dos personas.
    assert N.separar_personas("Dra. Suilan Esteves Velarde. Lic. Deborah Famadas") == [
        "Dra. Suilan Esteves Velarde", "Lic. Deborah Famadas"]


def test_clave_persona_unifica_variantes():
    # Acentos, mayusculas, grado y espacios no cambian la clave.
    assert N.clave_persona("MSc. Fernando Raúl Rodríguez Flores") == \
           N.clave_persona("Fernando Raul Rodríguez Flores")


def test_normalizar_local_variantes():
    assert N.normalizar_local("Posgrado") == "Postgrado"
    assert N.normalizar_local("posgrado") == "Postgrado"
    assert N.normalizar_local("Salón  decanato") == "Salón del decanato"
    assert N.normalizar_local("Francofomia") == "Francofonía"
    assert N.normalizar_local("Aula de las laptop Laboratorio") == "Aula de laptop (Laboratorio)"
    assert N.normalizar_local("VIRTUAL (Tutor coordinará la exposición)") == "Virtual"


def test_normalizar_local_frase_larga_no_es_local():
    assert N.normalizar_local(
        "Carmen coordina para la entrega de portafolio y acta correspondiente") == ""
    assert N.normalizar_local(None) == ""


def test_parsear_hora_manana_y_tarde():
    assert N.parsear_hora(datetime.time(9, 30)) == "09:30"
    assert N.parsear_hora(datetime.time(12, 0)) == "12:00"
    assert N.parsear_hora(datetime.time(1, 30)) == "13:30"    # tarde
    assert N.parsear_hora(datetime.time(2, 0)) == "14:00"
    assert N.parsear_hora("1 30 ") == "13:30"


def test_parsear_hora_no_reconocible():
    assert N.parsear_hora(None) == ""
    assert N.parsear_hora("pendiente") == ""


def test_sumar_minutos():
    assert N.sumar_minutos("09:30", 60) == "10:30"
    assert N.sumar_minutos("12:30", 60) == "13:30"
