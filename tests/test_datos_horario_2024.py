"""Comprobaciones sobre la transcripcion del horario 2024-2025 del PDF de Gianni.

Son datos escritos a mano, no codigo: lo que puede fallar aqui es una errata de
transcripcion, no una regresion logica. Por eso los tests miran la coherencia
interna del dato y que el resultado siga siendo cargable por el generador.
"""
import re

import pytest

from extraccion import horario_pdf as H
from extraccion.datos_horario_2024 import GRUPOS, TABLAS
from horarios.config import cargar_facultad, cargar_horarios


def test_todo_grupo_tiene_la_tabla_de_su_anio():
    # El id de grupo es <carrera><año><sesion><numero>; la tabla de abreviaturas
    # se busca por (carrera, año). Sin ella, ninguna celda del grupo parsearia.
    faltan = [g for g in GRUPOS if (g[0], int(g[1])) not in TABLAS]
    assert faltan == []


def test_toda_tabla_corresponde_a_algun_grupo():
    # El contrapunto: una tabla sin grupos seria una transcripcion huerfana.
    sin_uso = [k for k in TABLAS
               if not any(g[0] == k[0] and int(g[1]) == k[1] for g in GRUPOS)]
    assert sin_uso == []


def test_los_ids_de_grupo_estan_bien_formados():
    for g in GRUPOS:
        assert re.fullmatch(r"[CMD][1-5][12]\d", g), g


def test_ninguna_tabla_esta_vacia():
    for clave, tabla in TABLAS.items():
        assert tabla, clave
        for abrev, nombre in tabla.items():
            assert abrev.strip() == abrev and abrev, clave
            assert isinstance(nombre, str) and nombre.strip(), (clave, abrev)


def test_los_turnos_y_dias_son_los_esperados():
    turnos = {t for rejilla in GRUPOS.values() for t in rejilla}
    assert turnos <= {1, 2, 3, 4, 5, 6}
    dias = {d for rejilla in GRUPOS.values()
            for turnos_dia in rejilla.values() for d in turnos_dia}
    assert dias == {"Lunes", "Martes", "Miércoles", "Jueves", "Viernes"}


@pytest.fixture(scope="module")
def construido():
    return H.construir(GRUPOS, TABLAS)


def test_las_incidencias_conocidas_no_crecen(construido):
    # La transcripcion es de un PDF de 2024 y esta congelada: estas 15 incidencias
    # son las que ya se revisaron a mano (13 celdas con notacion que no es una
    # clase, mas 2 celdas con dos asignaturas). Si el numero cambia, alguien toco
    # el dato: hay que mirar las nuevas y actualizar este numero a conciencia.
    incidencias = construido["incidencias"]
    assert len(incidencias) == 15
    assert len([i for i in incidencias if "sin parsear" in i]) == 13
    assert len([i for i in incidencias if "celda múltiple" in i]) == 2


def test_el_horario_transcrito_lo_acepta_el_generador(tmp_path, construido):
    # La prueba que de verdad importa: lo que sale de la transcripcion tiene que
    # poder cargarse como configuracion del generador de horarios sin errores.
    fac_p, hor_p = tmp_path / "facultad.yaml", tmp_path / "horarios.yaml"
    H.escribir_yaml(construido, fac_p, hor_p)

    facultad = cargar_facultad(fac_p)
    horarios = cargar_horarios(hor_p, facultad)

    assert len(facultad.grupos) == len(GRUPOS)
    assert {g.id for g in facultad.grupos} == set(GRUPOS)
    assert facultad.turnos == 6
    # Cada grupo transcrito acaba con su horario, y toda celda apunta a un aula
    # y a una asignatura declaradas (cargar_horarios ya lo valida, pero se deja
    # explicito para que el test diga que comprueba).
    assert set(horarios) == set(GRUPOS)
    for grupo_id, horario in horarios.items():
        for (dia, turno), asignacion in horario.celdas.items():
            assert asignacion.aula in facultad.aulas
            assert dia in facultad.dias
            assert 1 <= turno <= facultad.turnos


def test_hay_anios_fuera_de_la_paleta_de_colores(construido):
    # C5 y M5 existen en el dato real y `horarios.estilos.ANIO_COLOR` solo llega
    # a 4. Es el caso que cubre `test_un_anio_fuera_de_la_paleta_no_rompe_la_hoja`:
    # se deja anotado aqui para que se vea que no es hipotetico.
    from horarios import estilos
    anios = set(construido["facultad"]["carreras"])
    assert anios
    quintos = [g for g in GRUPOS if g[1] == "5"]
    assert quintos
    assert all(f"{g[0]}5" not in estilos.ANIO_COLOR for g in quintos)
