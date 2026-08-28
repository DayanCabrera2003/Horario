"""Hoja Docencia: quien imparte cada asignatura en cada grupo.

Una fila por par (grupo, asignatura). El par completo hace falta porque en el
modelo las asignaturas cuelgan del ano y no del grupo: el mismo `AMI-CP` lo
puede impartir un profesor distinto en cada grupo del ano.

Es la hoja donde se decide el profesor una sola vez por (asignatura, grupo). La
rejilla del horario lo mostrara calculado a partir de aqui, de modo que no haya
que teclear el mismo profesor una vez por turno.
"""
from openpyxl.worksheet.datavalidation import DataValidation

from comun.hoja_listado import construir_hoja_listado, FILA_PRIMER_DATO
from comun.rangos import capacidad_para
from comun import formato, vista
from horarios import estilos
from horarios import hoja_asignaturas, hoja_listado_grupos, hoja_profesores
from horarios.modelo import Facultad

NOMBRE_HOJA = "Docencia"
ENCABEZADOS = ("Grupo", "Asignatura", "Profesor", "Nombre")
COL_GRUPO, COL_ASIGNATURA, COL_PROFESOR, COL_NOMBRE = "A", "B", "C", "D"


def capacidad(facultad: Facultad) -> int:
    """Cuantas filas abarca la tabla, contando la reserva. La necesita tambien
    la hoja auxiliar, que deriva una clave por fila."""
    return capacidad_para(len(facultad.docencia))


def _formula_nombre(fila: int) -> str:
    """El nombre completo del profesor de esa fila, resuelto desde el claustro.

    Va como formula y no como copia escrita al generar porque la columna de al
    lado se edita: una copia se quedaria con el nombre del profesor anterior en
    cuanto alguien cambiara el id, y ademas esta bloqueada, asi que no habria
    forma de corregirla.
    """
    return (f'=IF({COL_PROFESOR}{fila}="","",'
            f'IFERROR(VLOOKUP({COL_PROFESOR}{fila},'
            f'{hoja_profesores.RANGO_TABLA},2,0),"(desconocido)"))')


def construir_hoja_docencia(wb, facultad: Facultad) -> None:
    if not facultad.profesores:
        return
    filas = [(d.grupo, d.asignatura, d.profesor, _formula_nombre(FILA_PRIMER_DATO + i))
             for i, d in enumerate(facultad.docencia)]
    ws = construir_hoja_listado(wb, NOMBRE_HOJA, ENCABEZADOS, filas,
                                color_encabezado=estilos.COLOR_ENCABEZADO,
                                capacidad=capacidad(facultad),
                                # Se edita: la rejilla de cada grupo lee de aqui
                                # quien imparte cada asignatura.
                                columnas_editables=(COL_GRUPO, COL_ASIGNATURA,
                                                    COL_PROFESOR))
    _aplicar_desplegables(ws, capacidad(facultad))
    _aplicar_formato_condicional(ws, capacidad(facultad))
    # El nombre lo resuelve una formula; el ancho no lo puede deducir el
    # autoajuste, que solo mira texto escrito.
    formato.fijar_ancho_por_textos(
        ws, COL_NOMBRE, [p.nombre for p in facultad.profesores] + ["(desconocido)"],
        extra=4)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_DATOS)


def _aplicar_desplegables(ws, capacidad: int) -> None:
    """Una lista de ayuda por columna editable. Sin ellas se escribe a ciegas, y
    un id mal tecleado deja la celda de profesor de la rejilla en blanco sin
    decir por que.

    Aviso no bloqueante, como en el resto del proyecto: se admite escribir algo
    que no este en la lista, pero se ve.
    """
    fila_fin = FILA_PRIMER_DATO + capacidad - 1
    for columna, rango in ((COL_GRUPO, hoja_listado_grupos.RANGO_IDS),
                           (COL_ASIGNATURA, hoja_asignaturas.RANGO_IDS),
                           (COL_PROFESOR, hoja_profesores.RANGO_IDS)):
        dv = DataValidation(type="list", formula1=rango, allow_blank=True,
                            showErrorMessage=True, errorStyle="information")
        ws.add_data_validation(dv)
        dv.sqref = f"{columna}{FILA_PRIMER_DATO}:{columna}{fila_fin}"


def _aplicar_formato_condicional(ws, capacidad: int) -> None:
    """Ambar en la fila cuyo profesor no esta en el claustro, con el mismo
    criterio que la hoja Asignacion del libro del departamento."""
    fila_ini = FILA_PRIMER_DATO
    fila_fin = FILA_PRIMER_DATO + capacidad - 1
    celda = f"${COL_PROFESOR}{fila_ini}"
    ws.conditional_formatting.add(
        f"{COL_GRUPO}{fila_ini}:{COL_NOMBRE}{fila_fin}",
        estilos.regla_formula(
            f'AND({celda}<>"",COUNTIF({hoja_profesores.RANGO_IDS},{celda})=0)',
            estilos.COLOR_ASIG_DESCONOCIDA))
