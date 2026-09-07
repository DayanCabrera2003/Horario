"""Hoja auxiliar oculta del generador del departamento.

Guarda solo lo derivado. Los datos del problema viven en las hojas visibles: el
claustro esta en la hoja `Profesores` y el plan del semestre en la hoja
`Asignaturas`; las dos declaran sus propios rangos nombrados.

Dos tablas, ambas con una fila por fila de la hoja `Asignacion` (las de carga y
las de reserva, para que lo que se cree a mano cuente igual):

- F:J  carga por profesor. La columna F construye la clave '<prof>#<n>' con un
       CONTAR.SI de rango creciente (n = numero de aparicion del profesor hasta
       esa fila); G:J traen asignatura, tipo, grupo y horas **por referencia** a
       la hoja Asignacion, no copiados: desde que esa hoja es editable, una
       copia escrita al generar se quedaria vieja en cuanto alguien cambiara
       una fila. El rango nombrado CargaPorProfesor permite a la hoja
       `Carga por profesor` rellenar su detalle con BUSCARV planos, sin
       formulas matriciales.
- L:M  asignaturas distintas por profesor. L es la clave del par
       '<prof>|<asignatura>' y M marca con un 1 la primera aparicion de cada
       par. Sumar M filtrando por profesor da cuantas asignaturas distintas
       imparte, que es lo que muestra el panel de la hoja `Asignacion`.
       CONTAR.SI no sabe contar valores unicos y las formulas matriciales no se
       comportan igual en Excel y en Calc; esta columna es el rodeo plano.
"""
from openpyxl.workbook.defined_name import DefinedName
from openpyxl.utils import quote_sheetname, absolute_coordinate

from comun import proteccion
from departamento import layout as L
from departamento.modelo import Departamento

# "Auxiliar" y no "Datos": desde que el libro tiene hojas de listado con los
# datos del problema, "Datos" seria el nombre mas enganoso posible para la
# hoja oculta, que solo guarda calculos intermedios de las formulas.
NOMBRE_HOJA = "Auxiliar"
NOMBRE_HOJA_ASIGNACION = "Asignación"

# Columnas de la tabla de carga (F:J) y su origen en la hoja Asignacion.
COL_CLAVE = "F"
_DETALLE = (("G", L.COL_ASIGNATURA), ("H", L.COL_TIPO), ("I", L.COL_GRUPO),
            ("J", L.COL_HORAS))

# Columnas de la cuenta de asignaturas distintas.
COL_PAR = "L"
COL_PRIMERA_VEZ = "M"

RANGO_CARGA = "CargaPorProfesor"
RANGO_ASIGNATURA_NUEVA = "AsignaturaNuevaProfesor"


def _celda_asignacion(col: str, idx: int, absoluta: bool = True) -> str:
    """Referencia a la celda de la columna `col` en la fila de carga `idx` de la
    hoja Asignacion."""
    hoja = quote_sheetname(NOMBRE_HOJA_ASIGNACION)
    fila = L.fila_carga(idx)
    return f"{hoja}!${col}${fila}" if absoluta else f"{hoja}!{col}{fila}"


def _rango_nombrado(nombre: str, celda_ini: str, celda_fin: str) -> DefinedName:
    ref = (f"{quote_sheetname(NOMBRE_HOJA)}!"
           f"{absolute_coordinate(celda_ini)}:{absolute_coordinate(celda_fin)}")
    return DefinedName(nombre, attr_text=ref)


def _formula_clave(idx: int) -> str:
    """Formula de la clave '<prof>#<n>' para la fila de carga `idx`. El CONTAR.SI
    va de la primera fila de carga hasta la propia (rango creciente), de modo que
    cuenta cuantas veces ha aparecido ese profesor hasta aqui."""
    hoja = quote_sheetname(NOMBRE_HOJA_ASIGNACION)
    celda = _celda_asignacion(L.COL_PROFESOR, idx)
    rango = (f"{hoja}!${L.COL_PROFESOR}${L.FILA_PRIMERA_CARGA}"
             f":${L.COL_PROFESOR}${L.fila_carga(idx)}")
    return f'=IF({celda}="","",{celda}&"#"&COUNTIF({rango},{celda}))'


def _formula_par(idx: int) -> str:
    """Clave '<profesor>|<asignatura>' de la fila de carga `idx`.

    Vacia si le falta cualquiera de las dos mitades. Que falte el profesor es lo
    normal en una fila pendiente. Que falte la asignatura pasa mientras se
    escribe una fila nueva: se elige antes a quien se le da que que se le da, y
    entre un paso y otro la clave seria '<profesor>|', que es una asignatura
    distinta de su propio derecho y le sumaria una de mas en el panel.
    """
    profesor = _celda_asignacion(L.COL_PROFESOR, idx)
    asignatura = _celda_asignacion(L.COL_ID, idx)
    return (f'=IF(OR({profesor}="",{asignatura}=""),"",'
            f'{profesor}&"|"&{asignatura})')


def _formula_primera_vez(fila: int) -> str:
    """1 si la fila `fila` es la primera aparicion de su par profesor-asignatura.

    El CONTAR.SI va del principio de la columna hasta la propia fila (rango
    creciente), asi que de cada par solo se marca la primera. Devuelve 0 y no
    "" a proposito: es un sumando, y una cadena vacia en medio de un rango de
    suma es un valor que algunas versiones de Calc se niegan a ignorar.
    """
    celda = f"{COL_PAR}{fila}"
    return (f'=IF({celda}="",0,'
            f"IF(COUNTIF(${COL_PAR}$1:${COL_PAR}{fila},{celda})=1,1,0))")


def construir_hoja_datos(wb, depto: Departamento) -> None:
    ws = wb.create_sheet(NOMBRE_HOJA)
    ws.sheet_state = "hidden"

    # Una fila por fila de la hoja Asignacion, reserva incluida: si la tabla se
    # quedara en las filas que trae el YAML, las que se creen a mano no
    # apareceran en el detalle de nadie ni contarian como asignatura.
    n = depto.capacidad_filas()
    for i in range(n):
        r = i + 1
        ws[f"{COL_CLAVE}{r}"] = _formula_clave(i)
        for col, col_origen in _DETALLE:
            ws[f"{col}{r}"] = f"={_celda_asignacion(col_origen, i, absoluta=False)}"
        ws[f"{COL_PAR}{r}"] = _formula_par(i)
        ws[f"{COL_PRIMERA_VEZ}{r}"] = _formula_primera_vez(r)

    if n:
        wb.defined_names.add(_rango_nombrado(RANGO_CARGA, f"{COL_CLAVE}1", f"J{n}"))
        wb.defined_names.add(_rango_nombrado(
            RANGO_ASIGNATURA_NUEVA, f"{COL_PRIMERA_VEZ}1", f"{COL_PRIMERA_VEZ}{n}"))

    # Hoja de apoyo oculta: nada se edita a mano aqui.
    proteccion.proteger_hoja(ws)
