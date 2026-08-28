"""Hoja Profesores del generador de horarios: el claustro de la facultad.

Es el pedido 1 del tutor llevado al libro de horarios: "en algun lugar del excel
tenemos un listado con los profesores y sus datos; inicialmente solo el grado y
la cantidad de horas maxima".

La hoja solo existe si el YAML declara profesores. La seccion es opcional, y una
facultad que no la declare no tiene por que ganar una pestana vacia.
"""
from openpyxl.workbook.defined_name import DefinedName

from comun.hoja_listado import construir_hoja_listado, FILA_PRIMER_DATO
from comun.rangos import capacidad_para, rango_dinamico
from comun import vista
from horarios import estilos
from horarios import hoja_datos as HOJA_DATOS
from horarios.modelo import Facultad

NOMBRE_HOJA = "Profesores"
ENCABEZADOS = ("Id", "Nombre", "Grado", "Tope de turnos", "Turnos semanales")
COL_ID, COL_TOPE, COL_TURNOS = "A", "D", "E"

# Rangos que consume la hoja Docencia: la lista de ids para su desplegable y la
# tabla id -> nombre para resolver a quien corresponde cada id.
RANGO_IDS = "ProfesoresValidos"
RANGO_TABLA = "ProfesoresTabla"


def _formula_turnos(fila: int) -> str:
    """Turnos que le tocan a la semana: la suma de las frecuencias de todo lo
    que imparte, segun la hoja Docencia. Va como formula para que cambiar alli
    quien da que se refleje aqui sin regenerar."""
    return (f"=SUMIF({HOJA_DATOS.RANGO_DOCENCIA_PROFESOR},{COL_ID}{fila},"
            f"{HOJA_DATOS.RANGO_DOCENCIA_FRECUENCIA})")


def construir_hoja_profesores(wb, facultad: Facultad) -> None:
    if not facultad.profesores:
        return
    filas = [(p.id, p.nombre, p.grado,
              p.tope_turnos if p.tope_turnos is not None else "",
              _formula_turnos(FILA_PRIMER_DATO + i))
             for i, p in enumerate(facultad.profesores)]
    capacidad = capacidad_para(len(facultad.profesores))
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO,
                                capacidad=capacidad)
    for nombre, columnas in ((RANGO_IDS, 1), (RANGO_TABLA, 2)):
        wb.defined_names.add(DefinedName(
            nombre, attr_text=rango_dinamico(NOMBRE_HOJA, COL_ID,
                                             FILA_PRIMER_DATO, capacidad,
                                             columnas=columnas)))
    _aplicar_alerta_de_tope(ws, capacidad)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)


def _aplicar_alerta_de_tope(ws, capacidad: int) -> None:
    """Resalta los turnos de quien pasa de su tope. Sin tope declarado no hay
    nada que comparar y la fila se queda como esta."""
    fila_ini = FILA_PRIMER_DATO
    fila_fin = FILA_PRIMER_DATO + capacidad - 1
    ws.conditional_formatting.add(
        f"{COL_TURNOS}{fila_ini}:{COL_TURNOS}{fila_fin}",
        estilos.regla_formula(
            f'AND(${COL_TOPE}{fila_ini}<>"",'
            f'${COL_TURNOS}{fila_ini}>${COL_TOPE}{fila_ini})',
            estilos.COLOR_SOBRE_PLANIFICADA))
