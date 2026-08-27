from openpyxl.utils import quote_sheetname
from openpyxl.worksheet.datavalidation import DataValidation
from horarios import layout as L
from horarios import hoja_datos as HOJA_DATOS
from horarios import estilos
from comun import formato
from comun import impresion
from comun import leyenda
from comun import vista
from comun import proteccion
from horarios.modelo import Grupo, Facultad, Horario

# Alto de fila (en puntos) de la rejilla y la tabla: da aire vertical, parte del
# padding aproximado que se pide para que en Calc no queden las celdas apretadas.
ALTO_FILA_HORARIO = 22


def construir_hoja_grupo(ws, grupo: Grupo, facultad: Facultad,
                         horario: Horario | None = None) -> None:
    """Rellena `ws` en el sitio con la hoja de un grupo: rejilla de horario, tabla de
    asignaturas con fórmulas, dropdowns de aula/asignatura y formato condicional."""
    ws.title = grupo.id
    ws["A1"] = "Grupo"
    ws[L.CELDA_GRUPO_ID] = grupo.id

    # Encabezado de días
    for i, dia in enumerate(facultad.dias):
        ws[f"{L.col_dia(i)}{L.FILA_ENCABEZADO_DIAS}"] = dia
    # Etiquetas de turno
    for t in range(1, facultad.turnos + 1):
        ws[f"A{L.fila_asig(t)}"] = f"Turno {t}"

    # Rejilla de horario (rellena si hay horario)
    if horario:
        for (dia, turno), asg in horario.celdas.items():
            dia_idx = facultad.dias.index(dia)
            ws[L.celda_asig(dia_idx, turno)] = asg.asig
            ws[L.celda_aula(dia_idx, turno)] = asg.aula

    # Tabla de asignaturas + fórmulas
    asignaturas = facultad.asignaturas_de(grupo)
    # Un COUNTIF por fila de asignatura, sumados. Contar sobre el rectángulo
    # entero de la rejilla sería más corto pero cuenta de más: en él conviven los
    # ids de asignatura con los nombres de aula (y, desde la fase 3b, con los ids
    # de profesor), así que un aula o un profesor llamados como una asignatura se
    # contarían como clases suyas.
    filas_asig = L.filas_asig_por_turno(len(facultad.dias), facultad.turnos)
    ws["I3"] = "Asignatura"
    ws["J3"], ws["K3"], ws["L3"], ws["M3"] = "Nombre", "Frec", "Asignadas", "Faltan"
    for i, a in enumerate(asignaturas):
        id_cell = L.celda_asig_tabla_id(i)
        ws[id_cell] = a.id
        ws[L.celda_asig_tabla_nombre(i)] = a.nombre
        frec_cell = L.celda_asig_tabla_frec(i)
        ws[frec_cell] = a.frecuencia
        asignadas_cell = L.celda_asig_tabla_asignadas(i)
        ws[asignadas_cell] = "=" + "+".join(
            f"COUNTIF({r},{id_cell})" for r in filas_asig)
        ws[L.celda_asig_tabla_faltan(i)] = f"={frec_cell}-{asignadas_cell}"

    _escribir_profesores(ws, grupo, facultad)
    _aplicar_fondo_aulas(ws, facultad)
    _aplicar_dropdown_aulas(ws, facultad)
    _aplicar_dropdown_asignaturas(ws, grupo, facultad)
    _aplicar_formato_condicional(ws, grupo, facultad)
    _aplicar_bordes(ws, grupo, facultad)
    _aplicar_estilo_encabezados(ws, grupo, facultad)
    # 'extra' algo mayor que el habitual para dejar sitio a la sangria del padding.
    formato.autoajustar_columnas(ws, extra=4)
    _aplicar_padding(ws, grupo, facultad)
    # La leyenda va tras el autoajuste para que sus textos largos no ensanchen
    # la columna J (que es tambien la columna "Nombre" de la tabla).
    _aplicar_leyenda(ws, grupo, facultad)
    # Inmoviliza la fila de dias y la columna de etiquetas de turno.
    ws.freeze_panes = L.celda_asig(0, 1)
    # Un horario acaba pegado en la pared: apaisado y con la cabecera de dias
    # repetida en cada pagina, que si no la segunda pagina no se sabe leer.
    impresion.preparar(ws, filas_encabezado=f"1:{L.FILA_ENCABEZADO_DIAS}")
    # Pestana coloreada por ano: agrupa de un vistazo una barra con una hoja
    # por grupo.
    vista.colorear_pestana(ws, estilos.color_pestana_anio(grupo.anio))
    # Toda la hoja se calcula sola salvo la rejilla: es lo unico que se llena a
    # mano, asi que es lo unico que queda desbloqueado.
    proteccion.proteger_hoja(ws, editables=[
        L.rangos_filas_asig(len(facultad.dias), facultad.turnos),
        L.rangos_filas_aula(len(facultad.dias), facultad.turnos),
    ])


def _aplicar_padding(ws, grupo: Grupo, facultad: Facultad) -> None:
    """Da 'aire' a las celdas del horario (padding aproximado para Calc): sangria
    izquierda y centrado vertical en la rejilla y la tabla, mas un alto de fila
    mayor. El .xlsx no tiene padding real de celda, asi que se emula asi."""
    n_dias, n_turnos = len(facultad.dias), facultad.turnos
    n_asig = len(facultad.asignaturas_de(grupo))
    alin = estilos.alineacion_padding()
    col_fin_dias = L.col_dia(n_dias - 1)
    fila_fin_grid = L.fila_aula(n_turnos)
    fila_fin_tabla = L.FILA_PRIMERA_ASIG + n_asig - 1
    # Rejilla (incluye la columna A de turnos) y tabla de asignaturas.
    formato.aplicar_alineacion(
        ws, f"A{L.FILA_ENCABEZADO_DIAS}:{col_fin_dias}{fila_fin_grid}", alin)
    formato.aplicar_alineacion(ws, f"I3:M{fila_fin_tabla}", alin)
    formato.aplicar_alto_filas(
        ws, L.FILA_ENCABEZADO_DIAS, max(fila_fin_grid, fila_fin_tabla),
        ALTO_FILA_HORARIO)


def _aplicar_fondo_aulas(ws, facultad: Facultad) -> None:
    """Pinta un fondo neutro en las filas de aula de la rejilla, para senalar de
    un vistazo donde van las aulas (util al arrastrar y soltar). El formato
    condicional de aula invalida se evalua encima y prevalece cuando aplica."""
    relleno = estilos.fill(estilos.COLOR_FONDO_AULA)
    n_dias, n_turnos = len(facultad.dias), facultad.turnos
    for rango in L.rangos_filas_aula(n_dias, n_turnos).split():
        formato.aplicar_relleno(ws, rango, relleno)


def _aplicar_bordes(ws, grupo: Grupo, facultad: Facultad) -> None:
    """Bordea la rejilla de horario, las etiquetas de turno y la tabla de
    asignaturas: enrejado fino interno y perimetro medio en cada tabla."""
    n_dias, n_turnos = len(facultad.dias), facultad.turnos
    n_asig = len(facultad.asignaturas_de(grupo))
    interno, externo = estilos.lado_fino(), estilos.lado_medio()
    formato.aplicar_borde_tabla(ws, L.rango_bloque_horario(n_dias, n_turnos), interno, externo)
    formato.aplicar_borde_tabla(ws, L.rango_etiquetas_turno(n_turnos), interno, externo)
    formato.aplicar_borde_tabla(ws, L.rango_tabla_asignaturas(n_asig), interno, externo)
    # Linea gruesa separando cada turno del siguiente (bajo su fila de aula), para
    # distinguir de un vistazo los bloques de dos filas de cada turno.
    grueso = estilos.lado_grueso()
    for rango in L.filas_separadoras_turno(n_dias, n_turnos):
        formato.aplicar_borde_inferior(ws, rango, grueso)


def _aplicar_estilo_encabezados(ws, grupo: Grupo, facultad: Facultad) -> None:
    """Negrita + relleno neutro en dias, etiquetas de turno y cabeceras de la
    tabla de asignaturas. Solo celdas con contenido (las filas de aula en la
    columna A quedan sin tocar)."""
    coords = [f"{L.col_dia(i)}{L.FILA_ENCABEZADO_DIAS}" for i in range(len(facultad.dias))]
    coords += [f"A{L.fila_asig(t)}" for t in range(1, facultad.turnos + 1)]
    coords += ["I3", "J3", "K3", "L3", "M3"]
    formato.aplicar_estilo_encabezado(
        ws, coords, estilos.fuente_encabezado(),
        estilos.fill(estilos.COLOR_ENCABEZADO))


def _aplicar_leyenda(ws, grupo: Grupo, facultad: Facultad) -> None:
    """Mini-leyenda bajo la tabla de asignaturas (columna I), con los colores
    que aparecen en esta hoja."""
    n_asig = len(facultad.asignaturas_de(grupo))
    fila = L.FILA_PRIMERA_ASIG + n_asig - 1 + 2   # dos filas bajo la tabla
    ws[f"I{fila}"] = "Leyenda"
    items = [
        (estilos.COLOR_AULA_INVALIDA, "Aula fuera del listado de la facultad"),
        (estilos.COLOR_ASIG_DESCONOCIDA, "Asignatura fuera de la tabla del grupo"),
        (estilos.COLOR_AULA_SIN_ASIG, "Aula puesta, sin asignatura"),
        (estilos.COLOR_SOBRE_PLANIFICADA, "Sobre-planificada (asignadas > frecuencia)"),
        (estilos.COLOR_FREC_EXACTA, "Frecuencia exacta cumplida"),
    ]
    # El color de la colision solo se explica si la regla existe: sin profesores
    # no hay regla, y una leyenda que nombra un color que no aparece confunde.
    if facultad.profesores:
        items.append(
            (estilos.COLOR_CONFLICTO, "Profesor en dos grupos a la vez"))
    leyenda.escribir_leyenda(ws, f"I{fila + 1}", items)


def _aplicar_dropdown_aulas(ws, facultad: Facultad) -> None:
    # Fuente en la hoja Datos (creada por hoja_datos). Rango nombrado 'AulasValidas'.
    # OJO: openpyxl escribe formula1 verbatim en el XML; NO lleva '=' inicial o el
    # dropdown no se puebla al abrir en Excel/LibreOffice.
    # errorStyle 'information': el aviso es no bloqueante, de modo que en Calc/Excel se
    # pueden escribir aulas fuera del listado (el dropdown queda solo como ayuda). Sin
    # una accion de error explicita, Calc asume 'Stop' y rechaza los valores nuevos.
    dv = DataValidation(type="list", formula1="AulasValidas", allow_blank=True,
                        showErrorMessage=True, errorStyle="information")
    ws.add_data_validation(dv)
    dv.sqref = L.rangos_filas_aula(len(facultad.dias), facultad.turnos)


def _aplicar_dropdown_asignaturas(ws, grupo: Grupo, facultad: Facultad) -> None:
    # Fuente: los ids de la tabla de asignaturas del propio grupo (misma hoja).
    # Sin '=' inicial y con rango absoluto para que no se desplace al insertar filas.
    n_asig = len(facultad.asignaturas_de(grupo))
    rango = L.rango_ids_asignaturas_abs(n_asig)   # $I$4:$I$5
    # Mismo criterio que las aulas: aviso 'information' no bloqueante para no rechazar
    # asignaturas escritas a mano fuera de la lista del grupo.
    dv = DataValidation(type="list", formula1=rango, allow_blank=True,
                        showErrorMessage=True, errorStyle="information")
    ws.add_data_validation(dv)
    dv.sqref = L.rangos_filas_asig(len(facultad.dias), facultad.turnos)


def _aplicar_formato_condicional(ws, grupo: Grupo, facultad: Facultad) -> None:
    n_dias, n_turnos = len(facultad.dias), facultad.turnos
    n_asig = len(facultad.asignaturas_de(grupo))
    # Rango absoluto ($I$): la regla se aplica sobre un sqref multi-rango; si fuera
    # relativo, Excel lo desplazaría por fila y comprobaría el rango equivocado.
    rango_ids = L.rango_ids_asignaturas_abs(n_asig)

    # Asignatura desconocida (naranja) en filas de asignatura
    sq_asig = L.rangos_filas_asig(n_dias, n_turnos)
    primera = L.celda_asig(0, 1)
    # celda_aula(0, 1) es la aula del primer turno, una fila bajo 'primera': la
    # reutilizan tanto la regla de aula-sin-asignatura (mas abajo) como la de
    # aula invalida, asi que se calcula una sola vez aqui.
    primera_aula = L.celda_aula(0, 1)
    ws.conditional_formatting.add(
        sq_asig,
        estilos.regla_formula(
            f'AND({primera}<>"",COUNTIF({rango_ids},{primera})=0)',
            estilos.COLOR_ASIG_DESCONOCIDA),
    )
    # Aula puesta y asignatura vacia: el turno esta a medias. La formula se ancla
    # en la primera celda de asignatura y su aula (una fila mas abajo); la regla
    # se desplaza sola al resto de turnos, esten cada dos filas o cada tres.
    ws.conditional_formatting.add(
        sq_asig,
        estilos.regla_formula(
            f'AND({primera}="",{primera_aula}<>"")',
            estilos.COLOR_AULA_SIN_ASIG),
    )
    # Aula inválida (amarillo) en filas de aula
    sq_aula = L.rangos_filas_aula(n_dias, n_turnos)
    ws.conditional_formatting.add(
        sq_aula,
        estilos.regla_formula(
            f'AND({primera_aula}<>"",COUNTIF(AulasValidas,{primera_aula})=0)',
            estilos.COLOR_AULA_INVALIDA),
    )
    # Profesor en dos grupos a la vez (rojo intenso). Todas las hojas de grupo
    # comparten geometria, asi que el mismo (dia, turno) cae en la misma
    # direccion en todas: basta contar esa celda en cada hoja y ver si el
    # profesor aparece mas de una vez. No hace falta la tabla de firmas que usan
    # las aulas, cuya formula es mucho mas cara porque ademas decide QUE año
    # ocupa cada celda.
    if facultad.profesores:
        sq_prof = L.rangos_filas_profesor(n_dias, n_turnos)
        primera_prof = L.celda_profesor(0, 1)
        conteos = "+".join(
            f"COUNTIF({quote_sheetname(g.id)}!{primera_prof},{primera_prof})"
            for g in facultad.grupos)
        ws.conditional_formatting.add(
            sq_prof,
            estilos.regla_formula(
                f'AND({primera_prof}<>"",({conteos})>1)',
                estilos.COLOR_CONFLICTO),
        )

    # Tabla de asignaturas: sobre-planificada (rojo) y frecuencia exacta (verde).
    # Se colorea la fila completa (I..M) de cada asignatura, no solo la celda
    # "Asignadas". Las columnas L (asignadas) y K (frec) van fijadas ($L/$K) y la
    # fila relativa: asi toda la fila evalua el estado de esa misma asignatura.
    fila_ini = L.FILA_PRIMERA_ASIG
    rango_filas = L.rango_datos_tabla_asignaturas(n_asig)
    ws.conditional_formatting.add(
        rango_filas,
        estilos.regla_formula(f"$L{fila_ini}>$K{fila_ini}", estilos.COLOR_SOBRE_PLANIFICADA),
    )
    ws.conditional_formatting.add(
        rango_filas,
        estilos.regla_formula(f"$L{fila_ini}=$K{fila_ini}", estilos.COLOR_FREC_EXACTA),
    )


def _escribir_profesores(ws, grupo: Grupo, facultad: Facultad) -> None:
    """Tercera fila de cada turno: quien imparte la asignatura de arriba.

    No se escribe a mano. Se busca en la tabla derivada de la hoja Docencia con
    la clave "<grupo>#<asignatura>": el grupo es fijo en esta hoja, asi que va
    escrito en la formula, y la asignatura sale de la celda de arriba. Al cambiar
    la asignatura de un turno, el profesor la sigue.

    Si la facultad no declara profesores no hay nada que mostrar: las filas se
    ocultan para que la rejilla se vea como antes de la fase 3b, sin una linea
    vacia por turno.
    """
    filas = [L.fila_profesor(t) for t in range(1, facultad.turnos + 1)]
    if not facultad.profesores:
        for fila in filas:
            ws.row_dimensions[fila].hidden = True
        return
    for dia_idx in range(len(facultad.dias)):
        for turno in range(1, facultad.turnos + 1):
            celda_asig = L.celda_asig(dia_idx, turno)
            ws[L.celda_profesor(dia_idx, turno)] = (
                f'=IF({celda_asig}="","",'
                f'IFERROR(VLOOKUP("{grupo.id}#"&{celda_asig},'
                f'{HOJA_DATOS.RANGO_DOCENCIA},2,0),""))')
