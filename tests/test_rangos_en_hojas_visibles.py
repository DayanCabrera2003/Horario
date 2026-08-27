"""Los rangos nombrados viven en las hojas visibles, no en la auxiliar.

Antes de la fase 3a, los desplegables se alimentaban de copias escondidas en la
hoja auxiliar: la lista de aulas, la de estudiantes y la tabla de profesores.
Eso obligaba a regenerar el libro para anadir uno. Ahora apuntan al listado que
el usuario ve, con un rango que crece solo.
"""
from openpyxl import Workbook

from departamento.hoja_profesores import construir_hoja_profesores as claustro
from departamento.hoja_datos import construir_hoja_datos as aux_departamento
from departamento.modelo import (
    Profesor as ProfDepto, Asignatura as AsigDepto, Departamento,
)
from horarios.hoja_aulas import construir_hoja_aulas
from horarios.hoja_datos import construir_hoja_datos as aux_horarios
from horarios.modelo import Asignatura, Anio, Grupo, Facultad
from tribunales.hoja_estudiantes import construir_hoja_estudiantes
from tribunales.hoja_datos import construir_hoja_datos as aux_tribunales
from tribunales.modelo import (
    Profesor, Estudiante, Local, Momento, Dia, Tesis, Facultad as FacultadT,
)

DEPTO = Departamento(
    nombre="D", semestre="1", tope_horas=160, filas_por_profesor=10,
    profesores=(ProfDepto(id="PIAD", nombre="Pedro", grado="Dr."),),
    asignaturas=(AsigDepto(id="EST", nombre="Estadística", carrera="CC",
                           horas_conf=32, horas_cp=0, grupos_cp=0),),
)

FACULTAD = Facultad(
    aulas=("Aula 1", "Lab"), dias=("Lunes",), turnos=6,
    grupos=(Grupo(carrera="C", anio=1, sesion=1, numero=1),),
    anios={"C1": Anio(carrera="C", numero=1, asignaturas=(
        Asignatura(id="L-C", nombre="Lógica", frecuencia=1),))},
)

FACULTAD_T = FacultadT(
    profesores=(Profesor(id="PIAD", nombre="Pedro", grado="Dr."),
                Profesor(id="MARA", nombre="Maria", grado="MSc."),
                Profesor(id="LGOM", nombre="Luis", grado="Dr."),
                Profesor(id="ANSU", nombre="Ana", grado="")),
    estudiantes=(Estudiante(id="JPER", nombre="Juan"),),
    locales=(Local(id="POST", nombre="Postgrado"),),
    dias=(Dia(fecha="2026-07-27", momentos=(Momento("09:00", "10:00"),)),),
    tesis=(Tesis(estudiantes=("JPER",), tutores=("PIAD",), oponente="MARA",
                 presidente="LGOM", secretario="ANSU"),),
)


def _wb():
    wb = Workbook()
    wb.remove(wb.active)
    return wb


def _texto(wb, nombre):
    return wb.defined_names[nombre].attr_text


def test_aulas_validas_apunta_al_listado_visible():
    wb = _wb()
    aux_horarios(wb, FACULTAD)
    construir_hoja_aulas(wb, FACULTAD)
    ref = _texto(wb, "AulasValidas")
    assert "'Aulas'!" in ref
    assert "OFFSET" in ref and "COUNTA" in ref
    assert "Auxiliar" not in ref


def test_la_auxiliar_de_horarios_ya_no_copia_la_lista_de_aulas():
    wb = _wb()
    aux_horarios(wb, FACULTAD)
    assert wb["Auxiliar"]["A1"].value is None


def test_profesores_validos_y_tabla_apuntan_al_claustro():
    wb = _wb()
    aux_departamento(wb, DEPTO)
    claustro(wb, DEPTO)
    for nombre in ("ProfesoresValidos", "ProfesoresTabla"):
        ref = _texto(wb, nombre)
        assert "'Profesores'!" in ref, nombre
        assert "OFFSET" in ref, nombre
    # La tabla llega hasta la columna del tope: el reporte de carga busca en
    # ella el nombre (2) y el tope (4).
    assert _texto(wb, "ProfesoresTabla").endswith(",4)")


def test_la_auxiliar_del_departamento_solo_guarda_lo_derivado():
    # Se va la copia de profesores (A..D); se queda CargaPorProfesor, que si es
    # un calculo y no un dato.
    wb = _wb()
    aux_departamento(wb, DEPTO)
    assert wb["Auxiliar"]["A1"].value is None
    assert "CargaPorProfesor" in wb.defined_names


def test_estudiantes_validos_apunta_al_listado_visible():
    wb = _wb()
    aux_tribunales(wb, FACULTAD_T)
    construir_hoja_estudiantes(wb, FACULTAD_T)
    ref = _texto(wb, "EstudiantesValidos")
    assert "'Estudiantes'!" in ref
    assert "OFFSET" in ref
    # TesisTribunal se queda en la auxiliar: es una tabla derivada de las tesis.
    assert "Auxiliar" in _texto(wb, "TesisTribunal")
