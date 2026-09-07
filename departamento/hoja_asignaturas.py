"""Hoja Asignaturas: el plan del semestre con las horas declaradas.

Una fila por asignatura, con las tres cifras que la definen (horas de Conf,
horas de CP por grupo y cuantos grupos de CP) y el total que sale de ellas.

Es una hoja de datos **editable**: aqui se anaden las asignaturas nuevas sin
volver al YAML, que es el pedido del tutor de 2026-09-07. De ella cuelgan los
dos rangos nombrados con los que la hoja `Asignacion` resuelve cada fila de
carga y con los que `Cobertura por asignatura` se dimensiona.

El total va como formula y no como numero calculado al generar: siendo la hoja
editable, un total congelado no se moveria al corregir los grupos de CP, que es
justo el error que la hoja deberia evitar.
"""
from openpyxl.workbook.defined_name import DefinedName

from comun.hoja_listado import construir_hoja_listado, FILA_PRIMER_DATO
from comun.rangos import rango_dinamico
from comun import formato, vista
from departamento import estilos
from departamento.modelo import Departamento

NOMBRE_HOJA = "Asignaturas"
ENCABEZADOS = ("Id", "Nombre", "Carrera", "Horas Conf", "Horas CP por grupo",
               "Grupos CP", "Total")

COL_ID = "A"
COL_HORAS_CONF = "D"
COL_HORAS_CP = "E"
COL_GRUPOS_CP = "F"
COL_TOTAL = "G"

# Los seis datos de la asignatura se escriben a mano; el total se calcula.
COLUMNAS_EDITABLES = ("A", "B", "C", COL_HORAS_CONF, COL_HORAS_CP, COL_GRUPOS_CP)

# Rangos que alimentan a las demas hojas: la lista de ids para el desplegable de
# `Asignacion` y la tabla entera para los BUSCARV que resuelven nombre, carrera
# y horas de cada fila de carga.
RANGO_IDS = "AsignaturasValidas"
RANGO_TABLA = "AsignaturasTabla"

# Columnas de AsignaturasTabla, por numero, para quien la consulta. Con nombre
# porque un 4 suelto en una formula de otro archivo no dice nada.
COL_TABLA_NOMBRE = 2
COL_TABLA_CARRERA = 3
COL_TABLA_HORAS_CONF = 4
COL_TABLA_HORAS_CP = 5
COL_TABLA_TOTAL = 7
COLUMNAS_TABLA = 7


def _formula_total(fila: int) -> str:
    """Horas totales de la asignatura: la Conf mas las CP de todos sus grupos.
    Las horas de CP son por grupo, de ahi el producto.

    La guarda del id vacio es para las filas de reserva: sin ella una fila libre
    anunciaria "0" como total de una asignatura que todavia no existe.
    """
    return (f'=IF({COL_ID}{fila}="","",'
            f"{COL_HORAS_CONF}{fila}+{COL_HORAS_CP}{fila}*{COL_GRUPOS_CP}{fila})")


def construir_hoja_asignaturas(wb, depto: Departamento) -> None:
    capacidad = depto.capacidad_asignaturas()
    filas = []
    for i in range(capacidad):
        a = depto.asignaturas[i] if i < len(depto.asignaturas) else None
        datos = ((a.id, a.nombre, a.carrera, a.horas_conf, a.horas_cp, a.grupos_cp)
                 if a else (None,) * 6)
        filas.append((*datos, _formula_total(FILA_PRIMER_DATO + i)))

    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO,
                                capacidad=capacidad,
                                columnas_editables=COLUMNAS_EDITABLES)
    # El ancho de la columna de formulas no lo puede deducir el autoajuste: el
    # texto que se ve es el resultado, no la formula.
    formato.fijar_ancho_por_textos(ws, COL_TOTAL, ["Total", "99999"], extra=4)

    # Los dos rangos se anclan en la columna de Id y no en la del total: el
    # total es una formula y ocupa celda siempre, asi que el COUNTA que
    # dimensiona el rango contaria tambien la reserva (ver `comun/rangos.py`).
    for nombre, columnas in ((RANGO_IDS, 1), (RANGO_TABLA, COLUMNAS_TABLA)):
        wb.defined_names.add(DefinedName(
            nombre, attr_text=rango_dinamico(NOMBRE_HOJA, COL_ID,
                                             FILA_PRIMER_DATO, capacidad,
                                             columnas=columnas)))
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
