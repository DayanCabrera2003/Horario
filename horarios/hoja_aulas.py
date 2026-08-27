"""Hoja Aulas: la lista maestra de aulas de la facultad.

Hasta ahora esta lista existia solo en la columna A de la hoja auxiliar, oculta,
donde alimentaba el desplegable de aulas. Que la unica copia de un dato del
problema viviera en una hoja escondida es justo lo que el tutor senalo al
preguntar donde se entran los datos.
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from horarios import estilos
from horarios.modelo import Facultad

NOMBRE_HOJA = "Aulas"
ENCABEZADOS = ("Aula",)


def construir_hoja_aulas(wb, facultad: Facultad) -> None:
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS,
                                [(aula,) for aula in facultad.aulas],
                                color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
