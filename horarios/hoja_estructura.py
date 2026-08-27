"""Hoja Estructura: los datos del problema que no son una lista.

Los dias y el numero de turnos son dos hechos sueltos, no una tabla, y no caben
en ninguna de las otras hojas de listado sin deformarlas. Van aqui como pares
concepto/valor, junto con un resumen de cuanto abarca el libro.

Los dias importan mas de lo que parece: el texto de cada dia tiene que coincidir
**exactamente** con el del YAML de horarios (tildes incluidas), y hasta ahora la
unica forma de comprobarlo era abrir el YAML.
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from horarios import estilos
from horarios.modelo import Facultad

NOMBRE_HOJA = "Estructura"
ENCABEZADOS = ("Concepto", "Valor")


def construir_hoja_estructura(wb, facultad: Facultad) -> None:
    carreras = sorted({g.carrera for g in facultad.grupos})
    filas = [
        ("Días", ", ".join(facultad.dias)),
        ("Turnos por día", facultad.turnos),
        ("Carreras", ", ".join(carreras)),
        ("Años", ", ".join(facultad.anios)),
        ("Grupos", len(facultad.grupos)),
        ("Aulas", len(facultad.aulas)),
    ]
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
