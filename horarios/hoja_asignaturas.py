"""Hoja Asignaturas: que se imparte en cada ano, con su frecuencia semanal.

En el modelo las asignaturas cuelgan del ano (`Facultad.anios`), asi que en el
libro solo aparecian repetidas en la tabla de la derecha de cada hoja de grupo.
Aqui se aplanan a una fila por (ano, asignatura), que es como se leen: "que hay
que dar y cuantas veces por semana".
"""
from openpyxl.workbook.defined_name import DefinedName

from comun.hoja_listado import construir_hoja_listado, FILA_PRIMER_DATO
from comun.rangos import capacidad_para, rango_dinamico
from comun import vista
from horarios import estilos
from horarios.modelo import Facultad

NOMBRE_HOJA = "Asignaturas"
ENCABEZADOS = ("Carrera", "Año", "Id", "Nombre", "Frecuencia")

# Cada columna se publica como rango nombrado porque la frecuencia se busca por
# tres criterios a la vez (carrera, año e id): el mismo id existe en varios años
# -"EF" esta en casi todos- y buscar solo por id daria la frecuencia de otro.
RANGOS = {"AsigCarrera": "A", "AsigAnio": "B", "AsigId": "C",
          "AsigFrecuencia": "E"}


def construir_hoja_asignaturas(wb, facultad: Facultad) -> None:
    filas = [(anio.carrera, anio.numero, a.id, a.nombre, a.frecuencia)
             for anio in facultad.anios.values()
             for a in anio.asignaturas]
    capacidad = capacidad_para(len(filas))
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO,
                                capacidad=capacidad)
    for nombre, columna in RANGOS.items():
        # La cuenta de filas la manda siempre la columna A: si se dimensionara
        # cada rango con su propia columna, uno con huecos quedaria mas corto y
        # los criterios dejarian de casar fila a fila.
        ref = rango_dinamico(NOMBRE_HOJA, "A", FILA_PRIMER_DATO, capacidad)
        wb.defined_names.add(DefinedName(
            nombre, attr_text=ref.replace(f"!$A${FILA_PRIMER_DATO},0,0",
                                          f"!${columna}${FILA_PRIMER_DATO},0,0")))
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
