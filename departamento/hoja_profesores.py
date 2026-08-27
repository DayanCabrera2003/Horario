"""Hoja Profesores: el claustro del departamento con su grado y su tope.

Es el pedido del tutor tal como lo formulo: "un listado con los profesores y sus
datos; inicialmente solo el grado y la cantidad de horas maxima". Hasta ahora
esos datos vivian repartidos como cabecera de cada bloque de `Carga por
profesor`, que es un reporte y no un listado.

La columna del origen del tope existe porque el numero solo no responde la
pregunta que se hace quien lo mira: ese 160, lo declaro el profesor o le viene
del departamento.
"""
from comun.hoja_listado import construir_hoja_listado
from comun import vista
from departamento import estilos
from departamento.modelo import Departamento

NOMBRE_HOJA = "Profesores"
ENCABEZADOS = ("Id", "Nombre", "Grado", "Tope horas", "Origen del tope")

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
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
