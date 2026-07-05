from openpyxl.utils import get_column_letter, quote_sheetname
from horarios import layout as L
from horarios import estilos
from horarios.modelo import Facultad

NOMBRE_HOJA = "Aulas"


def _formula_ocupacion(facultad: Facultad, dia_idx: int, turno: int, aula: str) -> str:
    """Fórmula que concatena los ids de los grupos que ocupan (dia_idx, turno, aula)."""
    partes = [
        f'IF({quote_sheetname(g.id)}!{L.celda_aula(dia_idx, turno)}="{aula}","{g.id} ","")'
        for g in facultad.grupos
    ]
    concat = "&".join(partes)
    return f'=SUBSTITUTE(TRIM({concat})," ",",")'


def _formato_por_anio(ws, celda, dir_firma: str, facultad: Facultad) -> None:
    """Adjunta reglas de formato condicional a `celda` basadas en la firma de año."""
    coord = celda.coordinate
    # Una regla por año presente en la facultad: pinta con el color de ese año
    for cod in facultad.anios:
        color = estilos.ANIO_COLOR.get(cod)
        if color is None:
            continue
        ws.conditional_formatting.add(
            coord, estilos.regla_formula(f'{dir_firma}="{cod}"', color))
    # Conflicto: firma == "MIX"
    ws.conditional_formatting.add(
        coord, estilos.regla_formula(f'{dir_firma}="MIX"', estilos.COLOR_CONFLICTO))


def construir_hoja_aulas(wb, facultad: Facultad, firmas: dict) -> None:
    """Crea la hoja Aulas con un bloque por día (columnas=aulas, filas=turnos).

    Cada celda de datos contiene una fórmula que concatena los grupos que ocupan
    esa aula/turno/día, y recibe formato condicional por año (según la firma de Datos)
    más una regla de conflicto para el caso MIX.
    """
    ws = wb.create_sheet(NOMBRE_HOJA, index=0)
    fila = 1
    for dia_idx, dia in enumerate(facultad.dias):
        # Encabezado del bloque
        ws.cell(row=fila, column=1, value=dia)
        for j, aula in enumerate(facultad.aulas, start=2):
            ws.cell(row=fila, column=j, value=aula)
        fila += 1
        for turno in range(1, facultad.turnos + 1):
            ws.cell(row=fila, column=1, value=f"Turno {turno}")
            for j, aula in enumerate(facultad.aulas, start=2):
                celda = ws.cell(row=fila, column=j,
                                value=_formula_ocupacion(facultad, dia_idx, turno, aula))
                _formato_por_anio(ws, celda, firmas[(dia, turno, aula)], facultad)
            fila += 1
        fila += 1  # línea en blanco entre bloques
