# Coordenadas de las hojas del generador de gestion del departamento. Solo
# calcula posiciones; no escribe nada en la worksheet (eso lo hace cada hoja).

# --- Hoja Asignacion: titulo en la fila 1, encabezados en la 3, una fila de
# carga por linea a partir de la 4 (datos del YAML primero, reserva despues).
#
# Cuatro columnas se escriben a mano -Id, Tipo, Grupo y Profesor- y el resto se
# calcula a partir de ellas, de modo que una fila de reserva es una fila normal
# con las cuatro casillas vacias. A la derecha, tras una columna de canaleta,
# el panel de profesores. ---
COL_ID = "A"
COL_ASIGNATURA = "B"
COL_CARRERA = "C"
COL_TIPO = "D"
COL_GRUPO = "E"
COL_HORAS = "F"
COL_PROFESOR = "G"
COL_NOMBRE = "H"
COL_ULTIMA = "H"

ENCABEZADOS_ASIGNACION = ("Id", "Asignatura", "Carrera", "Tipo", "Grupo",
                          "Horas", "Profesor", "Nombre")

# Las que se escriben a mano, en orden de columna. Lo comparten la proteccion
# de la hoja y los desplegables.
COLUMNAS_EDITABLES = (COL_ID, COL_TIPO, COL_GRUPO, COL_PROFESOR)

# Columna vacia de separacion. Deja el panel fuera del autofiltro y del formato
# condicional de la tabla, que llegan hasta COL_ULTIMA.
COL_CANALETA = "I"
COL_PANEL_ID = "J"
COL_PANEL_NOMBRE = "K"
COL_PANEL_HORAS = "L"
COL_PANEL_ASIGNATURAS = "M"
COL_PANEL_TOPE = "N"
COL_PANEL_ULTIMA = COL_PANEL_TOPE
ENCABEZADOS_PANEL = ("Id", "Nombre", "Horas", "Asignaturas", "Tope")

FILA_TITULO = 1
FILA_ENCABEZADO_ASIGNACION = 3
FILA_PRIMERA_CARGA = 4


def fila_carga(idx: int) -> int:
    """Fila (base 1) de la fila de carga `idx` en la hoja Asignacion."""
    return FILA_PRIMERA_CARGA + idx


def rango_editable(col: str, n_filas: int) -> str:
    """Rango de `col` que cubre las `n_filas` de la tabla, datos y reserva.

    Lo consumen la proteccion de hoja y los desplegables, que tienen que cubrir
    exactamente las mismas filas: una casilla desbloqueada sin desplegable
    invita a escribir a ciegas, y al reves el desplegable no serviria de nada.
    """
    return f"{col}{FILA_PRIMERA_CARGA}:{col}{fila_carga(n_filas - 1)}"


def fila_panel(idx: int) -> int:
    """Fila del hueco `idx` del panel de profesores. Arranca a la altura de la
    primera fila de carga: el panel y la tabla comparten encabezado."""
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
