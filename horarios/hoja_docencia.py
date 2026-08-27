"""Hoja Docencia: quien imparte cada asignatura en cada grupo.

Una fila por par (grupo, asignatura). El par completo hace falta porque en el
modelo las asignaturas cuelgan del ano y no del grupo: el mismo `AMI-CP` lo
puede impartir un profesor distinto en cada grupo del ano.

Es la hoja donde se decide el profesor una sola vez por (asignatura, grupo). La
rejilla del horario lo mostrara calculado a partir de aqui, de modo que no haya
que teclear el mismo profesor una vez por turno.
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from horarios import estilos
from horarios.modelo import Facultad

NOMBRE_HOJA = "Docencia"
ENCABEZADOS = ("Grupo", "Asignatura", "Profesor", "Nombre")


def construir_hoja_docencia(wb, facultad: Facultad) -> None:
    if not facultad.profesores:
        return
    nombres = {p.id: p.nombre for p in facultad.profesores}
    filas = [(d.grupo, d.asignatura, d.profesor, nombres.get(d.profesor, ""))
             for d in facultad.docencia]
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
