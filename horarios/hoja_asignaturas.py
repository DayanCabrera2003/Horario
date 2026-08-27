"""Hoja Asignaturas: que se imparte en cada ano, con su frecuencia semanal.

En el modelo las asignaturas cuelgan del ano (`Facultad.anios`), asi que en el
libro solo aparecian repetidas en la tabla de la derecha de cada hoja de grupo.
Aqui se aplanan a una fila por (ano, asignatura), que es como se leen: "que hay
que dar y cuantas veces por semana".
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from horarios import estilos
from horarios.modelo import Facultad

NOMBRE_HOJA = "Asignaturas"
ENCABEZADOS = ("Carrera", "Año", "Id", "Nombre", "Frecuencia")


def construir_hoja_asignaturas(wb, facultad: Facultad) -> None:
    filas = [(anio.carrera, anio.numero, a.id, a.nombre, a.frecuencia)
             for anio in facultad.anios.values()
             for a in anio.asignaturas]
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
