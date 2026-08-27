"""Hoja Estudiantes: todos los estudiantes declarados, tengan tesis o no.

El que aun no tiene tesis asignada es justo el que interesa ver: es el que falta
por planificar. Antes de esta hoja no aparecia en el libro por ningun lado.
"""
from openpyxl.workbook.defined_name import DefinedName

from comun.hoja_listado import construir_hoja_listado, FILA_PRIMER_DATO
from comun.rangos import capacidad_para, rango_dinamico
from comun import vista
from tribunales import estilos
from tribunales.modelo import Facultad

NOMBRE_HOJA = "Estudiantes"
ENCABEZADOS = ("Id", "Nombre")
COL_ID = "A"

# Rango que alimenta el desplegable de estudiante de las hojas de dia.
RANGO_IDS = "EstudiantesValidos"


def construir_hoja_estudiantes(wb, facultad: Facultad) -> None:
    capacidad = capacidad_para(len(facultad.estudiantes))
    ws = construir_hoja_listado(
        wb, NOMBRE_HOJA, ENCABEZADOS,
        [(e.id, e.nombre) for e in facultad.estudiantes],
        color_encabezado=estilos.COLOR_ENCABEZADO, capacidad=capacidad,
        # Es la fuente del desplegable de estudiante de las hojas de dia.
        columnas_editables=("A", "B"))
    # El rango lo define esta hoja: la lista de estudiantes vive aqui desde la
    # fase 3a, y no como copia escondida en la auxiliar.
    wb.defined_names.add(DefinedName(
        RANGO_IDS,
        attr_text=rango_dinamico(NOMBRE_HOJA, COL_ID, FILA_PRIMER_DATO,
                                 capacidad)))
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
