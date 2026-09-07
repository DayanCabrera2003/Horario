"""Hoja `Cobertura por asignatura`: que le falta a cada asignatura del plan.

Una fila por hueco de la hoja `Asignaturas` -las declaradas y las de reserva-,
de modo que anadir una asignatura alli la hace aparecer aqui sin regenerar el
libro. Ese es el pedido del tutor de 2026-09-07, y es la razon de que la hoja
dejara de ser un bloque por asignatura: la geometria de bloques se decide al
generar y no puede crecer.

La fila responde a dos preguntas que el diseno de bloques no podia separar:

1. **żEstan creadas todas sus filas de carga?** Las horas que suman las filas
   de `Asignacion` con este id, comparadas con las que la asignatura declara.
   Asi se ve el grupo de CP que alguien olvido crear, que antes era invisible
   porque las filas venian dadas por el YAML.
2. **żTienen todas profesor?** Cuantas de esas filas se quedaron sin asignar.

La columna `Estado` dice con texto cual de las dos falta, para que no haya que
interpretar un color. El detalle de quien imparte cada grupo esta en la hoja
`Asignacion`, que tiene autofiltro: filtrar por un id da exactamente eso.
"""
from openpyxl.utils import quote_sheetname

from comun import formato, leyenda
from comun import proteccion
from comun import vista
from comun.hoja_listado import FILA_PRIMER_DATO
from departamento import estilos
from departamento import hoja_asignaturas as A
from departamento import layout as L
from departamento.hoja_asignacion import NOMBRE_HOJA as HOJA_ASIGNACION
from departamento.modelo import Departamento

NOMBRE_HOJA = "Cobertura por asignatura"

ENCABEZADOS = ("Id", "Asignatura", "Carrera", "Horas planificadas",
               "Filas de carga", "Horas en filas", "Horas asignadas",
               "Filas sin profesor", "Estado")

COL_ID = "A"
COL_HORAS_PLAN = "D"
COL_FILAS = "E"
COL_HORAS_FILAS = "F"
COL_HORAS_ASIGNADAS = "G"
COL_SIN_PROFESOR = "H"
COL_ESTADO = "I"
COL_ULTIMA = COL_ESTADO

# Las cinco columnas de cifras, para darles formato de entero de una vez.
COLUMNAS_CIFRA = (COL_HORAS_PLAN, COL_FILAS, COL_HORAS_FILAS,
                  COL_HORAS_ASIGNADAS, COL_SIN_PROFESOR)

FILA_TITULO = 1
FILA_ENCABEZADO = 2
FILA_PRIMER_DATO_COBERTURA = 3

ESTADO_COMPLETA = "Completa"


def _fila(idx: int) -> int:
    return FILA_PRIMER_DATO_COBERTURA + idx


def construir_hoja_cobertura(wb, depto: Departamento) -> None:
    ws = wb.create_sheet(NOMBRE_HOJA)
    ws[f"A{FILA_TITULO}"] = f"{NOMBRE_HOJA} — {depto.nombre} — {depto.semestre}"
    ws[f"A{FILA_TITULO}"].font = estilos.fuente_encabezado()

    _escribir_encabezados(ws)
    huecos = depto.capacidad_asignaturas()
    n_filas = depto.capacidad_filas()
    for i in range(huecos):
        _escribir_fila(ws, i, n_filas)

    fila_fin = _fila(huecos - 1)
    _aplicar_formato(ws, depto, fila_fin)
    _aplicar_formato_condicional(ws, fila_fin)
    _escribir_leyenda(ws, fila_fin + 2)

    ws.freeze_panes = f"A{FILA_PRIMER_DATO_COBERTURA}"
    # Se puede ordenar y filtrar: aqui ninguna fila tiene gemela por posicion,
    # cada una se resuelve por su id. Es la diferencia con la hoja Asignacion,
    # donde ordenar descuadraria la tabla auxiliar.
    ws.auto_filter.ref = f"A{FILA_ENCABEZADO}:{COL_ULTIMA}{fila_fin}"
    proteccion.proteger_hoja(ws, permitir_orden=True, permitir_filtro=True)
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_CALCULO)
    # Hoja de reporte: la tabla ya va bordeada y la cuadricula de fondo compite.
    vista.ocultar_cuadricula(ws)


def _escribir_encabezados(ws) -> None:
    for i, texto in enumerate(ENCABEZADOS):
        celda = ws.cell(row=FILA_ENCABEZADO, column=i + 1, value=texto)
        celda.font = estilos.fuente_encabezado()
        celda.fill = estilos.fill(estilos.COLOR_ENCABEZADO)


def _del_plan(fila_plan: int, columna: str) -> str:
    """Dato de la hoja Asignaturas, con la guarda del hueco libre: sin id no hay
    asignatura de la que hablar y la fila se queda en blanco."""
    id_ = f"{A.NOMBRE_HOJA}!{A.COL_ID}{fila_plan}"
    return f'=IF({id_}="","",{A.NOMBRE_HOJA}!{columna}{fila_plan})'


def _rango(col: str, n_filas: int) -> str:
    """Rango de la columna `col` de la hoja Asignacion, reserva incluida: las
    filas de carga creadas a mano tienen que contar igual que las del YAML."""
    hoja = quote_sheetname(HOJA_ASIGNACION)
    return (f"{hoja}!${col}${L.FILA_PRIMERA_CARGA}"
            f":${col}${L.fila_carga(n_filas - 1)}")


def _formula_estado(f: int) -> str:
    """Que le falta a la asignatura, en texto y por orden de gravedad.

    Primero si no tiene ninguna fila de carga (nadie ha empezado), luego si las
    que tiene no cubren las horas declaradas (falta crear alguna) y por ultimo
    si alguna se quedo sin profesor. Un color solo no distingue estos tres
    casos, y son tres trabajos distintos.

    El singular se distingue del plural con un IF. Es una linea mas de formula
    a cambio de que la hoja no diga "Faltan 1 profesores" a quien la lea.
    """
    faltan = f"${COL_SIN_PROFESOR}{f}"
    profesores = (f'IF({faltan}=1,"Falta 1 profesor",'
                  f'"Faltan "&{faltan}&" profesores")')
    horas = f"${COL_HORAS_PLAN}{f}-${COL_HORAS_FILAS}{f}"
    carga = (f'IF({horas}=1,"Falta 1 hora de carga",'
             f'"Faltan "&({horas})&" horas de carga")')
    return (f'=IF(${COL_ID}{f}="","",'
            f'IF(${COL_FILAS}{f}=0,"Sin filas de carga",'
            f"IF(${COL_HORAS_FILAS}{f}<${COL_HORAS_PLAN}{f},{carga},"
            f"IF({faltan}>0,{profesores},"
            f'"{ESTADO_COMPLETA}"))))')


def _escribir_fila(ws, idx: int, n_filas: int) -> None:
    f = _fila(idx)
    p = FILA_PRIMER_DATO + idx      # hueco gemelo en la hoja Asignaturas
    id_ = f"${COL_ID}{f}"
    guarda = f'=IF({id_}="","",'
    rango_id = _rango(L.COL_ID, n_filas)
    rango_horas = _rango(L.COL_HORAS, n_filas)
    rango_prof = _rango(L.COL_PROFESOR, n_filas)

    ws[f"{COL_ID}{f}"] = _del_plan(p, A.COL_ID)
    ws[f"B{f}"] = _del_plan(p, "B")
    ws[f"C{f}"] = _del_plan(p, "C")
    ws[f"{COL_HORAS_PLAN}{f}"] = _del_plan(p, A.COL_TOTAL)
    ws[f"{COL_FILAS}{f}"] = f"{guarda}COUNTIF({rango_id},{id_}))"
    ws[f"{COL_HORAS_FILAS}{f}"] = (
        f"{guarda}SUMIF({rango_id},{id_},{rango_horas}))")
    # Horas ya repartidas: las mismas filas, pero solo las que tienen profesor.
    # El "<>" es el criterio de "distinto de vacio".
    ws[f"{COL_HORAS_ASIGNADAS}{f}"] = (
        f"{guarda}SUMIFS({rango_horas},{rango_id},{id_},{rango_prof},\"<>\"))")
    ws[f"{COL_SIN_PROFESOR}{f}"] = (
        f'{guarda}COUNTIFS({rango_id},{id_},{rango_prof},""))')
    ws[f"{COL_ESTADO}{f}"] = _formula_estado(f)


def _aplicar_formato(ws, depto: Departamento, fila_fin: int) -> None:
    rango = f"A{FILA_ENCABEZADO}:{COL_ULTIMA}{fila_fin}"
    formato.aplicar_borde_tabla(ws, rango, interno=estilos.lado_fino(),
                                externo=estilos.lado_medio())
    formato.aplicar_alineacion(ws, rango, estilos.alineacion_padding())
    formato.aplicar_alto_filas(ws, FILA_ENCABEZADO, fila_fin, estilos.ALTO_FILA)
    for col in COLUMNAS_CIFRA:
        formato.aplicar_formato_numero(
            ws, f"{col}{FILA_PRIMER_DATO_COBERTURA}:{col}{fila_fin}")
    formato.autoajustar_columnas(ws, extra=4)
    # Toda la tabla son formulas: `autoajustar_columnas` no ve sus resultados,
    # asi que el ancho se fija con los valores que pueden llegar a mostrar.
    for col, textos in (
        (COL_ID, [a.id for a in depto.asignaturas] + ["Id"]),
        ("B", [a.nombre for a in depto.asignaturas] + ["Asignatura"]),
        ("C", [a.carrera for a in depto.asignaturas] + ["Carrera"]),
        (COL_ESTADO, ["Faltan 999 horas de carga"]),
    ):
        formato.fijar_ancho_por_textos(ws, col, textos, extra=4)
    for col, encabezado in zip(COLUMNAS_CIFRA, ENCABEZADOS[3:]):
        formato.fijar_ancho_por_textos(ws, col, [encabezado], extra=4)


def _aplicar_formato_condicional(ws, fila_fin: int) -> None:
    f = FILA_PRIMER_DATO_COBERTURA
    rango = f"A{f}:{COL_ULTIMA}{fila_fin}"
    # Verde cuando la columna Estado ya lo dice; naranja mientras falte algo.
    # La guarda del id deja las filas de reserva sin pintar: una asignatura que
    # todavia no existe no esta incompleta.
    ws.conditional_formatting.add(
        rango, estilos.regla_formula(f'${COL_ESTADO}{f}="{ESTADO_COMPLETA}"',
                                     estilos.COLOR_COMPLETA))
    ws.conditional_formatting.add(
        rango, estilos.regla_formula(
            f'AND(${COL_ID}{f}<>"",${COL_ESTADO}{f}<>"{ESTADO_COMPLETA}")',
            estilos.COLOR_INCOMPLETA))


def _escribir_leyenda(ws, fila: int) -> None:
    leyenda.escribir_leyenda(ws, f"A{fila}", (
        (estilos.COLOR_COMPLETA, "Asignatura completa (todo creado y asignado)"),
        (estilos.COLOR_INCOMPLETA,
         "Asignatura incompleta (ver la columna Estado)"),
    ))
