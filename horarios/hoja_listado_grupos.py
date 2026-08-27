"""Hoja Grupos: los ids de grupo, escritos.

El id `Casg` (carrera + ano + sesion + grupo) no se declara en ninguna parte del
YAML: sale de combinar carreras x anos x sesiones x grupos. Quien abre el libro
ve 22 pestanas llamadas C111, C112... y no tiene donde comprobar de donde sale
cada una. Esta hoja lo escribe.

El modulo se llama `hoja_listado_grupos` y no `hoja_grupos` a proposito: en este
paquete ya existe `hoja_grupo.py`, que construye la rejilla de horario de un
grupo, y dos modulos separados por una sola letra se confunden al editar.
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from horarios import estilos
from horarios.modelo import Facultad

NOMBRE_HOJA = "Grupos"
ENCABEZADOS = ("Grupo", "Carrera", "Año", "Sesión", "Número")


def construir_hoja_grupos(wb, facultad: Facultad) -> None:
    filas = [(g.id, g.carrera, g.anio, g.sesion, g.numero)
             for g in facultad.grupos]
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
