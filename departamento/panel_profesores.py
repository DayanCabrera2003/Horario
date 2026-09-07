"""Panel de profesores de la hoja Asignacion: el marcador de la reparticion.

Al lado de la tabla, y separado de ella por una columna de canaleta, una fila
por profesor con el total de horas que acumula, cuantas asignaturas distintas
imparte y su tope. La fila se pinta de rojo cuando pasa del tope.

**Por que aqui y no en `Carga por profesor`.** Esa hoja es el detalle -que
imparte cada uno, linea a linea- y se consulta al terminar. Este panel es el
marcador que se mira *mientras* se reparte, en la misma pantalla donde se
elige el profesor de cada fila. La duplicacion es deliberada y cuesta una
formula.

**Por que recalcula las horas en vez de leer la fila TOTAL de la otra hoja.**
Alli los profesores estan en bloques de altura fija y aqui en filas
consecutivas: no hay correspondencia entre las dos numeraciones que sobreviva a
cambiar `filas_por_profesor`. El SUMAR.SI es mas barato que mantener esa
correspondencia.

**Por que la cuenta de asignaturas necesita la hoja Auxiliar.** CONTAR.SI no
sabe contar valores distintos, y las formulas matriciales no se comportan igual
en Excel y en Calc. La hoja `Auxiliar` marca con un 1 la primera aparicion de
cada par profesor-asignatura; sumar esa columna filtrando por profesor da la
cuenta con una formula plana.
"""
from comun import formato
from comun.hoja_listado import FILA_PRIMER_DATO
from departamento import estilos
from departamento import hoja_datos
from departamento import layout as L
from departamento.hoja_profesores import (
    NOMBRE_HOJA as HOJA_CLAUSTRO, COL_ID as COL_CLAUSTRO_ID, COL_TOPE)
from departamento.modelo import Departamento

# Columnas del claustro que el panel muestra tal cual, en su orden de panel.
_COL_CLAUSTRO_NOMBRE = "B"


def construir_panel(ws, depto: Departamento, n_filas: int) -> None:
    """Escribe el panel en `ws`, que debe ser la hoja Asignacion ya rellena.

    `n_filas` son las filas de la tabla (de carga y de reserva): definen el
    rango sobre el que se suman las horas.

    Se llama antes de proteger la hoja, para que el panel nazca bloqueado como
    todo lo que es formula.
    """
    _escribir_encabezados(ws)
    huecos = depto.capacidad_profesores()
    for i in range(huecos):
        _escribir_fila(ws, i, n_filas)
    _aplicar_formato(ws, depto, huecos)


def _escribir_encabezados(ws) -> None:
    fila = L.FILA_ENCABEZADO_ASIGNACION
    for i, texto in enumerate(L.ENCABEZADOS_PANEL):
        celda = ws[f"{_columna(i)}{fila}"]
        celda.value = texto
        celda.font = estilos.fuente_encabezado()
        celda.fill = estilos.fill(estilos.COLOR_ENCABEZADO)


def _columna(indice: int) -> str:
    return (L.COL_PANEL_ID, L.COL_PANEL_NOMBRE, L.COL_PANEL_HORAS,
            L.COL_PANEL_ASIGNATURAS, L.COL_PANEL_TOPE)[indice]


def _del_claustro(fila_claustro: int, columna: str) -> str:
    """Dato del claustro, con la guarda del hueco libre: sin id no hay profesor
    del que hablar y la celda se queda en blanco, como la reserva de cualquier
    listado de la casa."""
    id_ = f"{HOJA_CLAUSTRO}!{COL_CLAUSTRO_ID}{fila_claustro}"
    return f'=IF({id_}="","",{HOJA_CLAUSTRO}!{columna}{fila_claustro})'


def _escribir_fila(ws, idx: int, n_filas: int) -> None:
    r = L.fila_panel(idx)
    # El hueco `idx` del panel mira el hueco `idx` del claustro: las dos hojas
    # se dimensionan con `capacidad_profesores`, asi que van a la par.
    p = FILA_PRIMER_DATO + idx
    id_panel = f"${L.COL_PANEL_ID}{r}"
    rango_prof = f"${L.COL_PROFESOR}${L.FILA_PRIMERA_CARGA}:${L.COL_PROFESOR}${L.fila_carga(n_filas - 1)}"
    rango_horas = f"${L.COL_HORAS}${L.FILA_PRIMERA_CARGA}:${L.COL_HORAS}${L.fila_carga(n_filas - 1)}"

    ws[f"{L.COL_PANEL_ID}{r}"] = _del_claustro(p, COL_CLAUSTRO_ID)
    ws[f"{L.COL_PANEL_NOMBRE}{r}"] = _del_claustro(p, _COL_CLAUSTRO_NOMBRE)
    # Horas: se suman las de todas las filas que llevan su id, reserva incluida.
    ws[f"{L.COL_PANEL_HORAS}{r}"] = (
        f'=IF({id_panel}="","",SUMIF({rango_prof},{id_panel},{rango_horas}))')
    # Asignaturas distintas: se suma la marca de primera aparicion del par
    # profesor-asignatura que prepara la hoja Auxiliar. Los dos rangos viven en
    # hojas distintas pero tienen el mismo tamano y el mismo orden, que es lo
    # unico que SUMAR.SI exige.
    ws[f"{L.COL_PANEL_ASIGNATURAS}{r}"] = (
        f'=IF({id_panel}="","",'
        f"SUMIF({rango_prof},{id_panel},{hoja_datos.RANGO_ASIGNATURA_NUEVA}))")
    ws[f"{L.COL_PANEL_TOPE}{r}"] = _del_claustro(p, COL_TOPE)


def _aplicar_formato(ws, depto: Departamento, huecos: int) -> None:
    fila_ini = L.FILA_ENCABEZADO_ASIGNACION
    fila_fin = L.fila_panel(huecos - 1)
    rango = f"{L.COL_PANEL_ID}{fila_ini}:{L.COL_PANEL_ULTIMA}{fila_fin}"
    formato.aplicar_borde_tabla(ws, rango, interno=estilos.lado_fino(),
                                externo=estilos.lado_medio())
    formato.aplicar_alineacion(ws, rango, estilos.alineacion_padding())
    # Las tres cifras son enteras; sin formato explicito Calc las mostraria
    # segun la configuracion regional de quien abra el libro.
    for col in (L.COL_PANEL_HORAS, L.COL_PANEL_ASIGNATURAS, L.COL_PANEL_TOPE):
        formato.aplicar_formato_numero(
            ws, f"{col}{L.fila_panel(0)}:{col}{fila_fin}")
    # Las cinco columnas muestran resultados de formulas: `autoajustar_columnas`
    # las ignora, asi que el ancho se fija con los valores que pueden mostrar.
    for col, textos in (
        (L.COL_PANEL_ID, [p.id for p in depto.profesores] + ["Id"]),
        (L.COL_PANEL_NOMBRE, [p.nombre for p in depto.profesores] + ["Nombre"]),
        (L.COL_PANEL_HORAS, ["Horas", "9999"]),
        (L.COL_PANEL_ASIGNATURAS, ["Asignaturas"]),
        (L.COL_PANEL_TOPE, ["Tope", "9999"]),
    ):
        formato.fijar_ancho_por_textos(ws, col, textos, extra=4)
    # Canaleta estrecha: es solo el aire que separa la tabla del panel.
    ws.column_dimensions[L.COL_CANALETA].width = 3

    # Rojo cuando el acumulado pasa del tope, como en la fila TOTAL de
    # `Carga por profesor`. La guarda del tope vacio evita que dispare con la
    # casilla en blanco, donde no hay con que comparar.
    fp = L.fila_panel(0)
    ws.conditional_formatting.add(
        f"{L.COL_PANEL_ID}{fp}:{L.COL_PANEL_ULTIMA}{fila_fin}",
        estilos.regla_formula(
            f'AND(${L.COL_PANEL_TOPE}{fp}<>"",'
            f"${L.COL_PANEL_HORAS}{fp}>${L.COL_PANEL_TOPE}{fp})",
            estilos.COLOR_SOBRECARGA))
