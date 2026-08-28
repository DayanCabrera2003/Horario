from openpyxl.utils import get_column_letter

# --- Hoja de grupo ---
CELDA_GRUPO_ID = "B1"
FILA_ENCABEZADO_DIAS = 3
# Los dias arrancan en la columna B, pegados a la columna A de etiquetas de
# turno: asi la columna de turnos queda unida a la rejilla de dias, sin hueco.
COL_PRIMER_DIA = 2          # B
COL_TABLA_ASIG = 9          # I
FILA_PRIMERA_ASIG = 4


def _col(idx: int) -> str:
    return get_column_letter(idx)


def col_dia(dia_idx: int) -> str:
    return _col(COL_PRIMER_DIA + dia_idx)


# Filas por turno: asignatura, aula y profesor. Eran dos hasta la fase 3b; el
# profesor no se escribe a mano sino que se calcula desde la hoja Docencia.
FILAS_POR_TURNO = 3


def fila_asig(turno: int) -> int:
    return 1 + FILAS_POR_TURNO * turno      # turno 1 -> 4


def fila_aula(turno: int) -> int:
    return fila_asig(turno) + 1


def fila_profesor(turno: int) -> int:
    return fila_asig(turno) + 2


def celda_asig(dia_idx: int, turno: int) -> str:
    return f"{col_dia(dia_idx)}{fila_asig(turno)}"


def celda_aula(dia_idx: int, turno: int) -> str:
    return f"{col_dia(dia_idx)}{fila_aula(turno)}"


def celda_profesor(dia_idx: int, turno: int) -> str:
    return f"{col_dia(dia_idx)}{fila_profesor(turno)}"


def fila_fin_turno(turno: int, con_profesor: bool = True) -> int:
    """Ultima fila visible de un turno.

    Sin profesores declarados la fila de profesor se oculta, y una fila oculta no
    dibuja sus bordes: el separador de turnos y el cierre de la rejilla tienen que
    bajar a la fila de aula o la rejilla se queda sin ellos.
    """
    return fila_profesor(turno) if con_profesor else fila_aula(turno)


def rango_horario(n_dias: int, n_turnos: int) -> str:
    c1 = celda_asig(0, 1)
    c2 = f"{col_dia(n_dias - 1)}{fila_profesor(n_turnos)}"
    return f"{c1}:{c2}"


def rangos_filas_asig(n_dias: int, n_turnos: int) -> str:
    """sqref multi-rango que cubre solo las filas de asignatura (para formato condicional)."""
    ini, fin = COL_PRIMER_DIA, COL_PRIMER_DIA + n_dias - 1
    return " ".join(f"{_col(ini)}{fila_asig(t)}:{_col(fin)}{fila_asig(t)}"
                    for t in range(1, n_turnos + 1))


def filas_asig_por_turno(n_dias: int, n_turnos: int) -> list[str]:
    """Un rango por turno, cubriendo solo su fila de asignatura.

    Devuelve una lista y no el sqref multi-rango de `rangos_filas_asig` porque
    el consumidor es COUNTIF, que no acepta varios rangos en un solo argumento:
    hay que sumar un COUNTIF por fila.
    """
    ini, fin = _col(COL_PRIMER_DIA), _col(COL_PRIMER_DIA + n_dias - 1)
    return [f"{ini}{fila_asig(t)}:{fin}{fila_asig(t)}"
            for t in range(1, n_turnos + 1)]


def rangos_filas_aula(n_dias: int, n_turnos: int) -> str:
    ini, fin = COL_PRIMER_DIA, COL_PRIMER_DIA + n_dias - 1
    return " ".join(f"{_col(ini)}{fila_aula(t)}:{_col(fin)}{fila_aula(t)}"
                    for t in range(1, n_turnos + 1))


def rangos_filas_profesor(n_dias: int, n_turnos: int) -> str:
    """sqref multi-rango con solo las filas de profesor (formato condicional)."""
    ini, fin = COL_PRIMER_DIA, COL_PRIMER_DIA + n_dias - 1
    return " ".join(f"{_col(ini)}{fila_profesor(t)}:{_col(fin)}{fila_profesor(t)}"
                    for t in range(1, n_turnos + 1))


def rango_bloque_horario(n_dias: int, n_turnos: int,
                         con_profesor: bool = True) -> str:
    """Rectangulo de la rejilla: encabezado de dias mas las filas de cada turno."""
    c1 = f"{col_dia(0)}{FILA_ENCABEZADO_DIAS}"
    c2 = f"{col_dia(n_dias - 1)}{fila_fin_turno(n_turnos, con_profesor)}"
    return f"{c1}:{c2}"


def filas_separadoras_turno(n_dias: int, n_turnos: int,
                            con_profesor: bool = True) -> list[str]:
    """Rangos de fila (columna A de turnos hasta el ultimo dia) sobre cuya cara
    inferior va la linea gruesa que separa un turno del siguiente.

    Un turno ocupa tres filas (asignatura + aula + profesor). La separacion va
    bajo la ultima de cada turno salvo el ultimo, cuyo borde inferior ya es el
    perimetro.
    """
    col_fin = col_dia(n_dias - 1)
    return [f"A{fila_fin_turno(t, con_profesor)}:{col_fin}{fila_fin_turno(t, con_profesor)}"
            for t in range(1, n_turnos)]


def rango_etiquetas_turno(n_turnos: int, con_profesor: bool = True) -> str:
    """Columna A con las etiquetas 'Turno t', de la primera fila del primer turno
    a la ultima del ultimo."""
    return f"A{fila_asig(1)}:A{fila_fin_turno(n_turnos, con_profesor)}"


# --- Tabla de asignaturas (I=id, J=nombre, K=frec, L=asignadas, M=faltan) ---
def _fila_tabla(fila_datos: int) -> int:
    return FILA_PRIMERA_ASIG + fila_datos


def celda_asig_tabla_id(fila_datos: int) -> str:
    return f"I{_fila_tabla(fila_datos)}"


def celda_asig_tabla_nombre(fila_datos: int) -> str:
    return f"J{_fila_tabla(fila_datos)}"


def celda_asig_tabla_frec(fila_datos: int) -> str:
    return f"K{_fila_tabla(fila_datos)}"


def celda_asig_tabla_asignadas(fila_datos: int) -> str:
    return f"L{_fila_tabla(fila_datos)}"


def celda_asig_tabla_faltan(fila_datos: int) -> str:
    return f"M{_fila_tabla(fila_datos)}"


def rango_tabla_asignaturas(n_asig: int) -> str:
    """Tabla de asignaturas I..M: fila de encabezado (3) mas n_asig filas de datos (para bordear)."""
    return f"I3:M{FILA_PRIMERA_ASIG + n_asig - 1}"


def rango_datos_tabla_asignaturas(n_asig: int) -> str:
    """Filas de datos de la tabla de asignaturas (id..faltan, sin encabezado), para
    aplicar el formato condicional que colorea la fila completa de cada asignatura."""
    return f"I{FILA_PRIMERA_ASIG}:M{FILA_PRIMERA_ASIG + n_asig - 1}"


def rango_ids_asignaturas_abs(n_asig: int) -> str:
    """Columna de ids de la tabla de asignaturas, en absoluto ($I$), para usos
    que no deben desplazarse (dropdowns, lookups de formato condicional sobre
    sqref multi-rango)."""
    return f"$I${FILA_PRIMERA_ASIG}:$I${FILA_PRIMERA_ASIG + n_asig - 1}"
