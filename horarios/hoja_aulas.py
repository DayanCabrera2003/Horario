"""Hoja Aulas: la lista maestra de aulas de la facultad.

Hasta ahora esta lista existia solo en la columna A de la hoja auxiliar, oculta,
donde alimentaba el desplegable de aulas. Que la unica copia de un dato del
problema viviera en una hoja escondida es justo lo que el tutor senalo al
preguntar donde se entran los datos.
"""
from openpyxl.workbook.defined_name import DefinedName

from comun.hoja_listado import construir_hoja_listado, FILA_PRIMER_DATO
from comun.rangos import capacidad_para, rango_dinamico
from comun import vista
from horarios import estilos
from horarios.modelo import Facultad

NOMBRE_HOJA = "Aulas"
ENCABEZADOS = ("Aula",)
COL_AULA = "A"

# Nombre del rango que alimenta el desplegable de aula de las hojas de grupo y
# la regla que resalta un aula inventada.
RANGO_AULAS = "AulasValidas"


def construir_hoja_aulas(wb, facultad: Facultad) -> None:
    capacidad = capacidad_para(len(facultad.aulas))
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS,
                                [(aula,) for aula in facultad.aulas],
                                color_encabezado=estilos.COLOR_ENCABEZADO,
                                capacidad=capacidad,
                                # Es la fuente del desplegable de aula: anadir
                                # una aqui la mete en la lista sin regenerar.
                                columnas_editables=(COL_AULA,))
    # El rango lo define esta hoja y no la auxiliar: la lista vive aqui, y un
    # rango dinamico hace que anadir un aula la meta en el desplegable sin
    # regenerar el libro.
    wb.defined_names.add(DefinedName(
        RANGO_AULAS,
        attr_text=rango_dinamico(NOMBRE_HOJA, COL_AULA, FILA_PRIMER_DATO,
                                 capacidad)))
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
