"""Hoja Tribunales: vista de solo lectura con la informacion completa de cada
tesis (nombres, no ids). Sirve para leer el tribunal de un vistazo sin tener que
descifrar los identificadores que usan el resto de hojas y los desplegables."""
from comun import formato
from tribunales import estilos
from tribunales.modelo import Facultad

NOMBRE_HOJA = "Tribunales"

# Encabezados de columna, en orden A..G.
ENCABEZADOS = ("Estudiante (id)", "Estudiante", "Tutor", "Oponente",
               "Presidente", "Secretario", "Vocal")


def construir_hoja_tribunales(wb, facultad: Facultad) -> None:
    """Crea la hoja Tribunales: una fila por tesis con el id del estudiante
    principal y los nombres completos de estudiantes y roles del tribunal. Las
    tesis conjuntas y las co-tutorias muestran sus nombres unidos con ' / '."""
    ws = wb.create_sheet(NOMBRE_HOJA)

    nombre_est = {e.id: e.nombre for e in facultad.estudiantes}
    nombre_prof = {p.id: _nombre_profesor(p) for p in facultad.profesores}

    def nombres(ids, mapa):
        # Si un id no aparece en el listado, se muestra el propio id como respaldo.
        return " / ".join(mapa.get(x, x) for x in ids)

    for col, texto in zip("ABCDEFG", ENCABEZADOS):
        ws[f"{col}1"] = texto

    for i, tesis in enumerate(facultad.tesis, start=2):
        ws[f"A{i}"] = tesis.estudiante
        ws[f"B{i}"] = nombres(tesis.estudiantes, nombre_est)
        ws[f"C{i}"] = nombres(tesis.tutores, nombre_prof)
        ws[f"D{i}"] = nombre_prof.get(tesis.oponente, tesis.oponente)
        ws[f"E{i}"] = nombre_prof.get(tesis.presidente, tesis.presidente)
        ws[f"F{i}"] = nombre_prof.get(tesis.secretario, tesis.secretario)
        # El vocal es opcional: casilla vacia si la tesis no tiene.
        ws[f"G{i}"] = nombre_prof.get(tesis.vocal, tesis.vocal) if tesis.vocal else ""

    _aplicar_presentacion(ws, len(facultad.tesis))


def _nombre_profesor(profesor) -> str:
    """Nombre para mostrar de un profesor: 'Grado Nombre' (p. ej. 'Dr. Ana Paz'),
    sin espacios sobrantes si falta el grado."""
    return f"{profesor.grado} {profesor.nombre}".strip()


def _aplicar_presentacion(ws, n_tesis: int) -> None:
    """Encabezado en negrita con relleno, borde de tabla, autoajuste e inmovilizado
    de la fila de encabezado."""
    coords_encab = [f"{col}1" for col in "ABCDEFG"]
    formato.aplicar_estilo_encabezado(
        ws, coords_encab, estilos.fuente_encabezado(),
        estilos.fill(estilos.COLOR_ENCABEZADO))
    if n_tesis:
        interno, externo = estilos.lado_fino(), estilos.lado_medio()
        formato.aplicar_borde_tabla(ws, f"A1:G{n_tesis + 1}", interno, externo)
    formato.autoajustar_columnas(ws)
    # Inmoviliza la fila de encabezado para que quede visible al hacer scroll.
    ws.freeze_panes = "A2"
