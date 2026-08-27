"""Hoja Estudiantes: todos los estudiantes declarados, tengan tesis o no.

El que aun no tiene tesis asignada es justo el que interesa ver: es el que falta
por planificar. Antes de esta hoja no aparecia en el libro por ningun lado.
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from tribunales import estilos
from tribunales.modelo import Facultad

NOMBRE_HOJA = "Estudiantes"
ENCABEZADOS = ("Id", "Nombre")


def construir_hoja_estudiantes(wb, facultad: Facultad) -> None:
    ws = construir_hoja_listado(
        wb, NOMBRE_HOJA, ENCABEZADOS,
        [(e.id, e.nombre) for e in facultad.estudiantes],
        color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
