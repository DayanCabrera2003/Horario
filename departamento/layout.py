# Coordenadas de las hojas del generador de gestion del departamento. Solo
# calcula posiciones; no escribe nada en la worksheet (eso lo hace cada hoja).

# --- Hoja Asignacion: titulo en la fila 1, encabezados en la 3, una fila de
# carga por linea a partir de la 4. Columnas fijas A..G. ---
COL_ASIGNATURA = "A"
COL_CARRERA = "B"
COL_TIPO = "C"
COL_GRUPO = "D"
COL_HORAS = "E"
COL_PROFESOR = "F"
COL_NOMBRE = "G"
COL_ULTIMA = "G"

ENCABEZADOS_ASIGNACION = ("Asignatura", "Carrera", "Tipo", "Grupo", "Horas",
                          "Profesor", "Nombre")

FILA_TITULO = 1
FILA_ENCABEZADO_ASIGNACION = 3
FILA_PRIMERA_CARGA = 4


def fila_carga(idx: int) -> int:
    """Fila (base 1) de la fila de carga `idx` en la hoja Asignacion."""
    return FILA_PRIMERA_CARGA + idx


# --- Hoja Profesores: un bloque por profesor a partir de la fila 3. Cada
# bloque: cabecera (etiquetas), valores, subcabecera del detalle, N filas
# reservadas de detalle, fila TOTAL y una fila en blanco de separacion. ---
PROF_FILA_PRIMER_BLOQUE = 3


def altura_bloque_profesor(filas_por_profesor: int) -> int:
    return filas_por_profesor + 5


def prof_fila_cabecera(prof_idx: int, filas_por_profesor: int) -> int:
    return PROF_FILA_PRIMER_BLOQUE + prof_idx * altura_bloque_profesor(filas_por_profesor)


def prof_fila_valores(prof_idx: int, filas_por_profesor: int) -> int:
    return prof_fila_cabecera(prof_idx, filas_por_profesor) + 1


def prof_fila_subcabecera(prof_idx: int, filas_por_profesor: int) -> int:
    return prof_fila_cabecera(prof_idx, filas_por_profesor) + 2


def prof_fila_detalle(prof_idx: int, k: int, filas_por_profesor: int) -> int:
    """Fila de la linea de detalle `k` (0-based) del bloque del profesor."""
    return prof_fila_subcabecera(prof_idx, filas_por_profesor) + 1 + k


def prof_fila_total(prof_idx: int, filas_por_profesor: int) -> int:
    return prof_fila_detalle(prof_idx, filas_por_profesor, filas_por_profesor)


# --- Hoja Asignaturas: un bloque por asignatura a partir de la fila 3. La
# altura depende de cuantas filas de carga tiene la asignatura, por eso las
# posiciones se calculan con el acumulado de alturas previas. ---
ASIG_FILA_PRIMER_BLOQUE = 3


def altura_bloque_asignatura(n_filas_carga: int) -> int:
    # titulo + subcabecera + filas de carga + blanco de separacion.
    return n_filas_carga + 3


def asig_fila_titulo(alturas_previas: int) -> int:
    return ASIG_FILA_PRIMER_BLOQUE + alturas_previas


def asig_fila_subcabecera(alturas_previas: int) -> int:
    return asig_fila_titulo(alturas_previas) + 1


def asig_fila_carga(alturas_previas: int, k: int) -> int:
    """Fila de la linea de carga `k` (0-based) dentro del bloque."""
    return asig_fila_subcabecera(alturas_previas) + 1 + k
