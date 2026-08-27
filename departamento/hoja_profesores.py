"""Hoja Profesores: el claustro del departamento con su grado y su tope.

Es el pedido del tutor tal como lo formulo: "un listado con los profesores y sus
datos; inicialmente solo el grado y la cantidad de horas maxima". Hasta ahora
esos datos vivian repartidos como cabecera de cada bloque de `Carga por
profesor`, que es un reporte y no un listado.

La columna del origen del tope existe porque el numero solo no responde la
pregunta que se hace quien lo mira: ese 160, lo declaro el profesor o le viene
del departamento.
"""
from openpyxl.workbook.defined_name import DefinedName

from comun.hoja_listado import construir_hoja_listado, FILA_PRIMER_DATO
from comun.rangos import capacidad_para, rango_dinamico
from comun import vista
from departamento import estilos
from departamento.modelo import Departamento

NOMBRE_HOJA = "Profesores"
ENCABEZADOS = ("Id", "Nombre", "Grado", "Tope horas", "Origen del tope")

# Rangos que alimentan la hoja Asignacion: el desplegable de profesor y el
# BUSCARV que resuelve el id a su nombre completo.
RANGO_IDS = "ProfesoresValidos"
RANGO_TABLA = "ProfesoresTabla"
COL_ID = "A"

ORIGEN_PROPIO = "Propio"
ORIGEN_HEREDADO = "Del departamento"
ORIGEN_SIN_TOPE = "Sin tope"


def _origen(depto: Departamento, profesor) -> str:
    if profesor.tope_horas is not None:
        return ORIGEN_PROPIO
    return ORIGEN_HEREDADO if depto.tope_horas is not None else ORIGEN_SIN_TOPE


def construir_hoja_profesores(wb, depto: Departamento) -> None:
    filas = []
    for p in depto.profesores:
        tope = depto.tope_efectivo(p)
        # Celda vacia y no un 0 cuando no hay tope: un 0 se leeria como "no
        # puede impartir nada", que es lo contrario de lo que significa.
        filas.append((p.id, p.nombre, p.grado,
                      tope if tope is not None else "", _origen(depto, p)))
    capacidad = capacidad_para(len(depto.profesores))
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO,
                                capacidad=capacidad)
    # Los dos rangos los define esta hoja, que es donde viven los datos. El de
    # la tabla abarca dos columnas: el id que se busca y el nombre que devuelve
    # el BUSCARV. Ni el grado ni el tope entran: ninguna formula los lee.
    for nombre, columnas in ((RANGO_IDS, 1), (RANGO_TABLA, 2)):
        wb.defined_names.add(DefinedName(
            nombre, attr_text=rango_dinamico(NOMBRE_HOJA, COL_ID,
                                             FILA_PRIMER_DATO, capacidad,
                                             columnas=columnas)))
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
