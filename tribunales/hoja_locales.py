"""Hoja Locales: los locales donde se puede defender.

El id es lo que se escribe en el YAML de asignaciones; el nombre es lo que
titula cada tabla en las hojas de dia. Tener las dos columnas juntas evita
adivinar cual es cual.
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from tribunales import estilos
from tribunales.modelo import Facultad

NOMBRE_HOJA = "Locales"
ENCABEZADOS = ("Id", "Nombre")


def construir_hoja_locales(wb, facultad: Facultad) -> None:
    ws = construir_hoja_listado(
        wb, NOMBRE_HOJA, ENCABEZADOS,
        [(l.id, l.nombre) for l in facultad.locales],
        color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
