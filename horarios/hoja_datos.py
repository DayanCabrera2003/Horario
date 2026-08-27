from openpyxl.utils import quote_sheetname
from openpyxl.workbook.defined_name import DefinedName

from comun.hoja_listado import FILA_PRIMER_DATO
from comun.rangos import rango_dinamico
from horarios import hoja_docencia
from horarios import layout as L
from comun import proteccion
from horarios.modelo import Facultad

# "Auxiliar" y no "Datos": desde que el libro tiene hojas de listado con los
# datos del problema, "Datos" seria el nombre mas enganoso posible para la
# hoja oculta, que solo guarda calculos intermedios de las formulas.
NOMBRE_HOJA = "Auxiliar"


def _formula_firma_anio(anios_por_codigo: dict, dia_idx: int, turno: int, aula: str) -> str:
    """Fórmula que devuelve el código del año único presente en (dia,turno,aula), "MIX" si hay varios, o "" si ninguno."""
    presencias, etiquetas = [], []
    for cod, grupos in anios_por_codigo.items():
        partes = [f'COUNTIF({quote_sheetname(g.id)}!{L.celda_aula(dia_idx, turno)},"{aula}")' for g in grupos]
        presencias.append(f'({"+".join(partes)})>0')
        etiquetas.append(cod)
    suma = "+".join(f"IF({p},1,0)" for p in presencias)
    # se construye anidando: elige el año cuya presencia es verdadera cuando total=1
    elegir = '""'
    for p, cod in zip(reversed(presencias), reversed(etiquetas)):
        elegir = f'IF({p},"{cod}",{elegir})'
    # código si exactamente 1 año presente, "MIX" si >1, "" si 0
    return f'=IF(({suma})=0,"",IF(({suma})=1,{elegir},"MIX"))'


def construir_hoja_datos(wb, facultad: Facultad) -> dict[tuple[str, int, str], str]:
    """Crea la hoja auxiliar oculta con las firmas de año por celda.

    Retorna un dict que mapea (dia, turno, aula) -> "Auxiliar!<addr>" con la
    dirección calificada de la fórmula de firma de año para esa combinación.

    Ya no guarda la lista de aulas: desde la fase 3a esa lista vive en la hoja
    visible `Aulas`, que es la que define el rango `AulasValidas`. Aquí solo
    queda lo derivado, que es de lo que una hoja auxiliar debería estar hecha.
    """
    ws = wb.create_sheet(NOMBRE_HOJA)
    ws.sheet_state = "hidden"

    _tabla_docencia(wb, ws, facultad)

    # Firmas de año, una por (dia, turno, aula).
    # Para cada año, presencia = suma de COUNTIF sobre las celdas-aula de los grupos de ese año.
    anios_por_codigo: dict[str, list] = {}
    for g in facultad.grupos:
        anios_por_codigo.setdefault(g.anio_codigo, []).append(g)

    celdas: dict[tuple[str, int, str], str] = {}
    fila = 1
    # La columna B se deja en blanco a propósito: separa la lista de aulas (col A)
    # de las firmas (col C) para que ambas regiones sean legibles por separado.
    col_firma = "C"   # las firmas viven en columna C hacia abajo
    for dia_idx, dia in enumerate(facultad.dias):
        for turno in range(1, facultad.turnos + 1):
            for aula in facultad.aulas:
                dir_firma = f"{col_firma}{fila}"
                ws[dir_firma] = _formula_firma_anio(anios_por_codigo, dia_idx, turno, aula)
                celdas[(dia, turno, aula)] = f"{NOMBRE_HOJA}!{dir_firma}"
                fila += 1
    # Hoja de apoyo oculta: nada se edita a mano aqui.
    proteccion.proteger_hoja(ws)
    return celdas


# Columnas de la tabla derivada de docencia, a la derecha de las firmas para no
# pisarlas. X = clave "<grupo>#<asignatura>", Y = profesor.
COL_CLAVE_DOCENCIA = "X"
COL_PROFESOR_DOCENCIA = "Y"
COL_FRECUENCIA_DOCENCIA = "Z"
RANGO_DOCENCIA = "DocenciaPorGrupo"
RANGO_DOCENCIA_PROFESOR = "DocenciaProfesor"
RANGO_DOCENCIA_FRECUENCIA = "DocenciaFrecuencia"


def _tabla_docencia(wb, ws, facultad: Facultad) -> None:
    """Tabla auxiliar clave -> profesor, derivada de la hoja Docencia.

    La rejilla de cada grupo necesita buscar por (grupo, asignatura) y BUSCARV
    solo mira la primera columna, asi que la clave se compone aqui. Se compone
    con formulas que leen la hoja Docencia -y no con los valores del YAML- para
    que cambiar alli quien imparte algo se refleje en las rejillas sin regenerar.

    Abarca tambien las filas de reserva de la hoja Docencia: una fila vacia
    produce una clave vacia, inofensiva para el BUSCARV.
    """
    if not facultad.profesores:
        return
    hoja = quote_sheetname(hoja_docencia.NOMBRE_HOJA)
    capacidad = hoja_docencia.capacidad(facultad)
    for i in range(capacidad):
        fila_origen = FILA_PRIMER_DATO + i
        fila = FILA_PRIMER_DATO + i
        grupo = f"{hoja}!${hoja_docencia.COL_GRUPO}${fila_origen}"
        asig = f"{hoja}!${hoja_docencia.COL_ASIGNATURA}${fila_origen}"
        ws[f"{COL_CLAVE_DOCENCIA}{fila}"] = (
            f'=IF({grupo}="","",{grupo}&"#"&{asig})')
        ws[f"{COL_PROFESOR_DOCENCIA}{fila}"] = (
            f"={hoja}!${hoja_docencia.COL_PROFESOR}${fila_origen}")
        # Turnos semanales que supone esa fila: la frecuencia de la asignatura
        # en el año del grupo. Se busca por los tres criterios porque el mismo
        # id existe en varios años (EF esta en casi todos) y el año sale del
        # propio id de grupo: "C111" -> carrera C, año 1.
        ws[f"{COL_FRECUENCIA_DOCENCIA}{fila}"] = (
            f'=IF({grupo}="",0,IFERROR(SUMIFS(AsigFrecuencia,'
            f'AsigCarrera,LEFT({grupo},1),'
            f'AsigAnio,VALUE(MID({grupo},2,1)),'
            f'AsigId,{asig}),0))')
    wb.defined_names.add(DefinedName(
        RANGO_DOCENCIA,
        attr_text=rango_dinamico(NOMBRE_HOJA, COL_CLAVE_DOCENCIA,
                                 FILA_PRIMER_DATO, capacidad, columnas=2)))
    # Las dos columnas que suma el claustro para saber la carga de cada uno. Se
    # dimensionan con la columna de la clave, que es la que dice cuantas filas
    # de docencia hay de verdad.
    ref_base = rango_dinamico(NOMBRE_HOJA, COL_CLAVE_DOCENCIA, FILA_PRIMER_DATO,
                              capacidad)
    for nombre, columna in ((RANGO_DOCENCIA_PROFESOR, COL_PROFESOR_DOCENCIA),
                            (RANGO_DOCENCIA_FRECUENCIA, COL_FRECUENCIA_DOCENCIA)):
        wb.defined_names.add(DefinedName(
            nombre,
            attr_text=ref_base.replace(
                f"!${COL_CLAVE_DOCENCIA}${FILA_PRIMER_DATO},0,0",
                f"!${columna}${FILA_PRIMER_DATO},0,0")))
