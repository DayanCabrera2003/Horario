"""Hoja Asignaturas: el plan del semestre con las horas declaradas.

Una fila por asignatura, con las tres cifras que la definen (horas de Conf,
horas de CP por grupo y cuantos grupos de CP) y el total que sale de ellas.

El total va como formula y no como numero calculado al generar. Hoy la hoja sale
bloqueada -ninguna formula del libro la lee, asi que editarla no cambiaria nada-,
pero el dia que se desbloquee un total congelado no se moveria al cambiar los
grupos de CP, que es justo el error que la hoja deberia evitar.
"""
from comun.hoja_listado import construir_hoja_listado, FILA_PRIMER_DATO
from comun import formato, vista
from departamento import estilos
from departamento.modelo import Departamento

NOMBRE_HOJA = "Asignaturas"
ENCABEZADOS = ("Id", "Nombre", "Carrera", "Horas Conf", "Horas CP por grupo",
               "Grupos CP", "Total")

COL_HORAS_CONF = "D"
COL_HORAS_CP = "E"
COL_GRUPOS_CP = "F"
COL_TOTAL = "G"


def _formula_total(fila: int) -> str:
    """Horas totales de la asignatura: la Conf mas las CP de todos sus grupos.
    Las horas de CP son por grupo, de ahi el producto."""
    return (f"={COL_HORAS_CONF}{fila}+{COL_HORAS_CP}{fila}*{COL_GRUPOS_CP}{fila}")


def construir_hoja_asignaturas(wb, depto: Departamento) -> None:
    filas = [(a.id, a.nombre, a.carrera, a.horas_conf, a.horas_cp, a.grupos_cp,
              _formula_total(FILA_PRIMER_DATO + i))
             for i, a in enumerate(depto.asignaturas)]
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO)
    # El ancho de la columna de formulas no lo puede deducir el autoajuste: el
    # texto que se ve es el resultado, no la formula.
    formato.fijar_ancho_por_textos(ws, COL_TOTAL, ["Total", "99999"], extra=4)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)
