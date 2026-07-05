from openpyxl.utils import get_column_letter

# --- Hoja de grupo ---
CELDA_GRUPO_ID = "B1"
FILA_ENCABEZADO_DIAS = 3
COL_PRIMER_DIA = 3          # C
COL_TABLA_ASIG = 9          # I
FILA_PRIMERA_ASIG = 4


def _col(idx: int) -> str:
    return get_column_letter(idx)


def col_dia(dia_idx: int) -> str:
    return _col(COL_PRIMER_DIA + dia_idx)


def fila_asig(turno: int) -> int:
    return 2 + 2 * turno            # turno 1 -> 4


def fila_aula(turno: int) -> int:
    return fila_asig(turno) + 1


def celda_asig(dia_idx: int, turno: int) -> str:
    return f"{col_dia(dia_idx)}{fila_asig(turno)}"


def celda_aula(dia_idx: int, turno: int) -> str:
    return f"{col_dia(dia_idx)}{fila_aula(turno)}"


def rango_horario(n_dias: int, n_turnos: int) -> str:
    c1 = celda_asig(0, 1)
    c2 = f"{col_dia(n_dias - 1)}{fila_aula(n_turnos)}"
    return f"{c1}:{c2}"


def rangos_filas_asig(n_dias: int, n_turnos: int) -> str:
    """sqref multi-rango que cubre solo las filas de asignatura (para formato condicional)."""
    ini, fin = COL_PRIMER_DIA, COL_PRIMER_DIA + n_dias - 1
    return " ".join(f"{_col(ini)}{fila_asig(t)}:{_col(fin)}{fila_asig(t)}"
                    for t in range(1, n_turnos + 1))


def rangos_filas_aula(n_dias: int, n_turnos: int) -> str:
    ini, fin = COL_PRIMER_DIA, COL_PRIMER_DIA + n_dias - 1
    return " ".join(f"{_col(ini)}{fila_aula(t)}:{_col(fin)}{fila_aula(t)}"
                    for t in range(1, n_turnos + 1))


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


def rango_ids_asignaturas(n_asig: int) -> str:
    return f"I{FILA_PRIMERA_ASIG}:I{FILA_PRIMERA_ASIG + n_asig - 1}"


def rango_ids_asignaturas_abs(n_asig: int) -> str:
    """Igual que rango_ids_asignaturas pero absoluto ($I$), para usos que no deben
    desplazarse (dropdowns, lookups de formato condicional sobre sqref multi-rango)."""
    return f"$I${FILA_PRIMERA_ASIG}:$I${FILA_PRIMERA_ASIG + n_asig - 1}"
