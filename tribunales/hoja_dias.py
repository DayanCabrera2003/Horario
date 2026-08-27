"""Hoja Dias: que dias hay y que momentos tiene cada uno.

Lleva tres columnas y no dos por una razon practica: la fecha en ISO es lo que
se escribe en el YAML, pero la hoja de ese dia se llama '27 jul (lun)'. Sin la
equivalencia escrita hay que deducirla, y es la primera pregunta que aparece al
buscar un dia concreto en la barra de pestanas.
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from tribunales import estilos
from tribunales.modelo import Facultad

NOMBRE_HOJA = "Días"
ENCABEZADOS = ("Fecha", "Hoja", "Momentos")


def construir_hoja_dias(wb, facultad: Facultad) -> None:
    ws = construir_hoja_listado(
        wb, NOMBRE_HOJA, ENCABEZADOS,
        [(d.fecha, d.nombre_hoja, ", ".join(m.id for m in d.momentos))
         for d in facultad.dias],
        color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
