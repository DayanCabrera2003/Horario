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
from comun.rangos import rango_dinamico
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
COL_TOPE = "D"

ORIGEN_PROPIO = "Propio"
ORIGEN_HEREDADO = "Del departamento"
ORIGEN_SIN_TOPE = "Sin tope"


def _formula_origen(depto: Departamento, fila: int) -> str:
    """El origen del tope, calculado a partir de la celda de al lado.

    Va como formula y no como texto escrito al generar porque el tope se edita
    aqui: si fuera texto, cambiarlo dejaria la etiqueta mintiendo. Un tope igual
    al global del departamento se lee como heredado, que es lo que significa.
    """
    celda = f"{COL_TOPE}{fila}"
    # La guarda del id vacio es para las filas de reserva: sin ella una linea
    # libre anunciaria "Sin tope" de un profesor que todavia no existe.
    vacia = f'{COL_ID}{fila}=""'
    if depto.tope_horas is None:
        return (f'=IF({vacia},"",'
                f'IF({celda}="","{ORIGEN_SIN_TOPE}","{ORIGEN_PROPIO}"))')
    return (f'=IF({vacia},"",'
            f'IF({celda}="","{ORIGEN_SIN_TOPE}",'
            f'IF({celda}={depto.tope_horas},"{ORIGEN_HEREDADO}","{ORIGEN_PROPIO}")))')


def construir_hoja_profesores(wb, depto: Departamento) -> None:
    # La capacidad la decide el departamento y no `capacidad_para`: estos mismos
    # huecos son las filas del panel de `Asignacion` y los bloques de `Carga por
    # profesor`. Con la reserva generica de un listado (20 filas como minimo) el
    # reporte de carga tendria veinte bloques vacios, que son trescientas filas.
    capacidad = depto.capacidad_profesores()
    filas = []
    for i in range(capacidad):
        p = depto.profesores[i] if i < len(depto.profesores) else None
        tope = depto.tope_efectivo(p) if p else None
        # Celda vacia y no un 0 cuando no hay tope: un 0 se leeria como "no
        # puede impartir nada", que es lo contrario de lo que significa.
        filas.append((p.id if p else None, p.nombre if p else None,
                      p.grado if p else None,
                      tope if tope is not None else "",
                      _formula_origen(depto, FILA_PRIMER_DATO + i)))
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO,
                                capacidad=capacidad,
                                # Todo menos el origen del tope, que es una
                                # formula: anadir un profesor es escribir su id,
                                # su nombre, su grado y su tope en una fila libre.
                                columnas_editables=("A", "B", "C", COL_TOPE))
    # Los dos rangos los define esta hoja, que es donde viven los datos. El de
    # la tabla abarca cuatro columnas porque el reporte de carga busca en el dos
    # cosas: el nombre (columna 2) y el tope (columna 4).
    for nombre, columnas in ((RANGO_IDS, 1), (RANGO_TABLA, 4)):
        wb.defined_names.add(DefinedName(
            nombre, attr_text=rango_dinamico(NOMBRE_HOJA, COL_ID,
                                             FILA_PRIMER_DATO, capacidad,
                                             columnas=columnas)))
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
