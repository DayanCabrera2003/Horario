"""Hoja auxiliar oculta del generador del departamento.

Guarda solo lo derivado. Los datos del problema viven en las hojas visibles: el
claustro esta en la hoja `Profesores`, que es quien declara ProfesoresValidos y
ProfesoresTabla desde la fase 3a.

- F:J  tabla auxiliar de carga por profesor: una fila por fila de carga de la
       hoja Asignacion. La columna F construye la clave '<prof>#<n>' con un
       CONTAR.SI de rango creciente (n = numero de aparicion del profesor hasta
       esa fila); G:J llevan asignatura, tipo, grupo y horas. El rango nombrado
       CargaPorProfesor permite a la hoja `Carga por profesor` rellenar su
       detalle con BUSCARV planos, sin formulas matriciales.
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


def _rango_nombrado(nombre: str, celda_ini: str, celda_fin: str) -> DefinedName:
    ref = (f"{quote_sheetname(NOMBRE_HOJA)}!"
           f"{absolute_coordinate(celda_ini)}:{absolute_coordinate(celda_fin)}")
    return DefinedName(nombre, attr_text=ref)


def _formula_clave(idx: int) -> str:
    """Formula de la clave '<prof>#<n>' para la fila de carga `idx`. El CONTAR.SI
    va de la primera fila de carga hasta la propia (rango creciente), de modo que
    cuenta cuantas veces ha aparecido ese profesor hasta aqui."""
    hoja = quote_sheetname(NOMBRE_HOJA_ASIGNACION)
    celda = f"{hoja}!${L.COL_PROFESOR}${L.fila_carga(idx)}"
    rango = (f"{hoja}!${L.COL_PROFESOR}${L.FILA_PRIMERA_CARGA}"
             f":${L.COL_PROFESOR}${L.fila_carga(idx)}")
    return f'=IF({celda}="","",{celda}&"#"&COUNTIF({rango},{celda}))'


def construir_hoja_datos(wb, depto: Departamento) -> None:
    ws = wb.create_sheet(NOMBRE_HOJA)
    ws.sheet_state = "hidden"

    # Tabla auxiliar de carga: clave por formula, datos estaticos de cada fila.
    filas = depto.filas()
    for i, f in enumerate(filas):
        r = i + 1
        ws[f"F{r}"] = _formula_clave(i)
        ws[f"G{r}"] = f.asignatura.nombre
        ws[f"H{r}"] = f.tipo
        ws[f"I{r}"] = f.grupo if f.grupo is not None else "-"
        ws[f"J{r}"] = f.horas
    if filas:
        wb.defined_names.add(_rango_nombrado("CargaPorProfesor", "F1", f"J{len(filas)}"))

    # Hoja de apoyo oculta: nada se edita a mano aqui.
    proteccion.proteger_hoja(ws)
