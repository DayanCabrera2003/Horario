"""Hoja Tribunales: vista de solo lectura con la informacion completa de cada
tesis (nombres, no ids). Sirve para leer el tribunal de un vistazo sin tener que
descifrar los identificadores que usan el resto de hojas y los desplegables."""
from comun import formato
from tribunales import estilos
from tribunales.modelo import Facultad

NOMBRE_HOJA = "Tribunales"

# Encabezados de columna, en orden A..F.
ENCABEZADOS = ("Estudiante (id)", "Estudiante", "Tutor", "Oponente",
               "Presidente", "Secretario")


def construir_hoja_tribunales(wb, facultad: Facultad) -> None:
    """Crea la hoja Tribunales: una fila por tesis con el id del estudiante y los
    nombres completos del estudiante y de los cuatro roles del tribunal."""
    ws = wb.create_sheet(NOMBRE_HOJA)

    nombre_est = {e.id: e.nombre for e in facultad.estudiantes}
    nombre_prof = {p.id: _nombre_profesor(p) for p in facultad.profesores}

    for col, texto in zip("ABCDEF", ENCABEZADOS):
        ws[f"{col}1"] = texto

    for i, tesis in enumerate(facultad.tesis, start=2):
        ws[f"A{i}"] = tesis.estudiante
        # Si un id no aparece en el listado, se muestra el propio id como respaldo.
        ws[f"B{i}"] = nombre_est.get(tesis.estudiante, tesis.estudiante)
        ws[f"C{i}"] = nombre_prof.get(tesis.tutor, tesis.tutor)
        ws[f"D{i}"] = nombre_prof.get(tesis.oponente, tesis.oponente)
        ws[f"E{i}"] = nombre_prof.get(tesis.presidente, tesis.presidente)
        ws[f"F{i}"] = nombre_prof.get(tesis.secretario, tesis.secretario)

    _aplicar_presentacion(ws, len(facultad.tesis))


def _nombre_profesor(profesor) -> str:
    """Nombre para mostrar de un profesor: 'Grado Nombre' (p. ej. 'Dr. Ana Paz'),
    sin espacios sobrantes si falta el grado."""
    return f"{profesor.grado} {profesor.nombre}".strip()


def _aplicar_presentacion(ws, n_tesis: int) -> None:
    """Encabezado en negrita con relleno, borde de tabla, autoajuste e inmovilizado
    de la fila de encabezado."""
    coords_encab = [f"{col}1" for col in "ABCDEF"]
    formato.aplicar_estilo_encabezado(
        ws, coords_encab, estilos.fuente_encabezado(),
        estilos.fill(estilos.COLOR_ENCABEZADO))
    if n_tesis:
        interno, externo = estilos.lado_fino(), estilos.lado_medio()
        formato.aplicar_borde_tabla(ws, f"A1:F{n_tesis + 1}", interno, externo)
    formato.autoajustar_columnas(ws)
    # Inmoviliza la fila de encabezado para que quede visible al hacer scroll.
    ws.freeze_panes = "A2"
