"""Hoja Profesores del generador de horarios: el claustro de la facultad.

Es el pedido 1 del tutor llevado al libro de horarios: "en algun lugar del excel
tenemos un listado con los profesores y sus datos; inicialmente solo el grado y
la cantidad de horas maxima".

La hoja solo existe si el YAML declara profesores. La seccion es opcional, y una
facultad que no la declare no tiene por que ganar una pestana vacia.
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from horarios import estilos
from horarios.modelo import Facultad

NOMBRE_HOJA = "Profesores"
ENCABEZADOS = ("Id", "Nombre", "Grado", "Tope horas")


def construir_hoja_profesores(wb, facultad: Facultad) -> None:
    if not facultad.profesores:
        return
    filas = [(p.id, p.nombre, p.grado,
              p.tope_horas if p.tope_horas is not None else "")
             for p in facultad.profesores]
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
