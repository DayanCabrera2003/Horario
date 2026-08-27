"""Hoja Profesores: el claustro completo, tal como viene del YAML.

Existe porque hasta ahora un profesor solo aparecia en el libro si formaba parte
de algun tribunal. Quien no participaba en ninguno no estaba en ninguna parte, y
no habia forma de saber desde el Excel a quien se podia convocar.

Sin tope de horas a proposito: un tribunal de tesis no es carga docente, y ese
dato vive en el libro del departamento.
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from tribunales import estilos
from tribunales.modelo import Facultad

NOMBRE_HOJA = "Profesores"
ENCABEZADOS = ("Id", "Nombre", "Grado")


def construir_hoja_profesores(wb, facultad: Facultad) -> None:
    ws = construir_hoja_listado(
        wb, NOMBRE_HOJA, ENCABEZADOS,
        [(p.id, p.nombre, p.grado) for p in facultad.profesores],
        color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
