# Coordenadas de las hojas del generador de tribunales. Solo calcula posiciones;
# no escribe nada en la worksheet (esa es responsabilidad de las hojas).

# --- Hoja de dia: tabla por local, columnas fijas A..F ---
COL_MOMENTO = "A"
COL_ESTUDIANTE = "B"
COLS_PROFESOR = ("C", "D", "E", "F")  # tutor, oponente, presidente, secretario
COL_ULTIMA = "F"

# Encabezados de columna, en orden A..F.
ENCABEZADOS = ("Momento", "Estudiante", "Tutor", "Oponente", "Presidente", "Secretario")


def _altura_bloque(n_momentos: int) -> int:
    # titulo + encabezado de columnas + filas de momento + 1 blanco de separacion.
    return n_momentos + 3


def fila_titulo_local(local_idx: int, n_momentos: int) -> int:
    """Fila del titulo (nombre del local) del bloque `local_idx`. Base 1."""
    return 1 + local_idx * _altura_bloque(n_momentos)


def fila_encabezado_local(local_idx: int, n_momentos: int) -> int:
    return fila_titulo_local(local_idx, n_momentos) + 1


def fila_momento(local_idx: int, momento_idx: int, n_momentos: int) -> int:
    """Fila de datos de un momento dentro del bloque de un local."""
    return fila_encabezado_local(local_idx, n_momentos) + 1 + momento_idx


def rango_profesores_momento(local_idx: int, momento_idx: int, n_momentos: int) -> str:
    """Rango C..F de la fila de un momento (celdas de profesor de esa tesis)."""
    fila = fila_momento(local_idx, momento_idx, n_momentos)
    return f"{COLS_PROFESOR[0]}{fila}:{COL_ULTIMA}{fila}"


# --- Hoja de localizacion: una tabla de una columna por cada (dia, local) ---
LOCALIZAR_CELDA_ENTRADA = "B1"
LOCALIZAR_FILA_PRIMERA_TABLA = 3
LOCALIZAR_COL = "A"  # las tablas de localizacion son de una sola columna (A)


def localizar_altura_tabla(n_momentos: int) -> int:
    # titulo + filas de momento + 1 blanco de separacion.
    return n_momentos + 2


def localizar_fila_titulo(tabla_idx: int, alturas_previas: int) -> int:
    """Fila de titulo de la tabla `tabla_idx`. `alturas_previas` = suma de las
    alturas de las tablas anteriores (las tablas dependen de n_momentos de su
    dia, que varia, por eso se pasa acumulado)."""
    return LOCALIZAR_FILA_PRIMERA_TABLA + alturas_previas
