"""Hoja Asignacion: la tabla donde se reparte la carga del semestre.

Una fila por fila de carga (la Conf de una asignatura o un grupo de CP suyo),
mas filas de reserva al final para las que se creen a mano.

De las ocho columnas solo cuatro se escriben: el id de la asignatura, el tipo,
el grupo y el profesor. El nombre de la asignatura, la carrera, las horas y el
nombre del profesor se calculan a partir de ellas con BUSCARV sobre las hojas
de datos. Asi, corregir una asignatura en la hoja `Asignaturas` se propaga
aqui, y una fila de reserva no necesita codigo aparte: es una fila normal con
las cuatro casillas vacias.

Los colores avisan de las tres cosas que pueden faltar o estar mal: fila sin
profesor (amarillo), id de profesor fuera del claustro e id de asignatura fuera
del plan (ambar). A la derecha, tras una columna de canaleta, el panel de
profesores (`panel_profesores.py`).
"""
from openpyxl.worksheet.datavalidation import DataValidation

from comun import formato, leyenda
from comun import proteccion
from comun import vista
from departamento import estilos
from departamento import hoja_asignaturas as A
from departamento import layout as L
from departamento.modelo import Departamento
from departamento.panel_profesores import construir_panel

NOMBRE_HOJA = "Asignación"

# Los dos unicos tipos de fila de carga que conoce el modelo. Van como lista
# literal en el desplegable (openpyxl escribe formula1 verbatim, de ahi las
# comillas dobles que envuelven la lista).
TIPOS = ("Conf", "CP")
FUENTE_TIPOS = '"' + ",".join(TIPOS) + '"'


def construir_hoja_asignacion(wb, depto: Departamento) -> None:
    ws = wb.create_sheet(NOMBRE_HOJA)
    filas = depto.filas()
    n = depto.capacidad_filas()

    ws[f"A{L.FILA_TITULO}"] = f"Asignación — {depto.nombre} — {depto.semestre}"
    ws[f"A{L.FILA_TITULO}"].font = estilos.fuente_encabezado()

    _escribir_encabezados(ws)
    _escribir_filas(ws, filas, n)
    _aplicar_dropdowns(ws, n)
    _aplicar_formato_condicional(ws, n)
    _aplicar_formato(ws, depto, n)
    construir_panel(ws, depto, n)
    _escribir_leyenda(ws, n)

    # Encabezados fijos al hacer scroll: todo lo anterior a la primera carga.
    ws.freeze_panes = f"A{L.FILA_PRIMERA_CARGA}"

    # Autofiltro sobre la tabla entera, para aislar una carrera, una asignatura
    # o las filas sin profesor mientras se reparte la carga. Llega hasta
    # COL_ULTIMA: el panel vive tras la canaleta y queda fuera.
    ws.auto_filter.ref = (f"A{L.FILA_ENCABEZADO_ASIGNACION}"
                          f":{L.COL_ULTIMA}{L.fila_carga(n - 1)}")

    # Se deja filtrar pero no ordenar: cada fila tiene una gemela por posicion
    # en la hoja Auxiliar (la clave del detalle y la marca de asignatura nueva),
    # y ordenar aqui la descuadraria sin avisar.
    proteccion.proteger_hoja(
        ws, editables=[L.rango_editable(col, n) for col in L.COLUMNAS_EDITABLES],
        permitir_filtro=True)
    # Pestana de navegacion: la hoja donde se decide quien imparte que.
    vista.colorear_pestana(ws, estilos.COLOR_PESTANA_ENTRADA)


def _escribir_encabezados(ws) -> None:
    fila = L.FILA_ENCABEZADO_ASIGNACION
    for i, texto in enumerate(L.ENCABEZADOS_ASIGNACION):
        celda = ws.cell(row=fila, column=i + 1, value=texto)
        celda.font = estilos.fuente_encabezado()
        celda.fill = estilos.fill(estilos.COLOR_ENCABEZADO)


def _buscar_asignatura(fila: int, columna: int) -> str:
    """Dato de la asignatura de esta fila, buscado por su id en la tabla del
    plan. El IFERROR cubre el id que todavia no existe en la hoja Asignaturas:
    la celda queda en blanco y el aviso lo da el color de la fila, no un #N/A
    repetido en tres columnas."""
    id_ = f"${L.COL_ID}{fila}"
    return (f'=IF({id_}="","",'
            f'IFERROR(VLOOKUP({id_},{A.RANGO_TABLA},{columna},0),""))')


def _formula_horas(fila: int) -> str:
    """Horas de la fila: las de la Conf o las de un grupo de CP, segun el tipo.
    Las horas de CP son por grupo, asi que una fila de CP vale una tanda entera
    y no hay que repartir nada."""
    id_ = f"${L.COL_ID}{fila}"
    conf = f"VLOOKUP({id_},{A.RANGO_TABLA},{A.COL_TABLA_HORAS_CONF},0)"
    cp = f"VLOOKUP({id_},{A.RANGO_TABLA},{A.COL_TABLA_HORAS_CP},0)"
    return (f'=IF({id_}="","",'
            f'IFERROR(IF(${L.COL_TIPO}{fila}="{TIPOS[0]}",{conf},{cp}),""))')


def _formula_nombre_profesor(fila: int) -> str:
    """Nombre completo del profesor elegido. Es BUSCARV y no una copia: si
    fuera copia, cambiar el id dejaria en pantalla el nombre del anterior."""
    celda = f"${L.COL_PROFESOR}{fila}"
    return (f'=IF({celda}="","",'
            f'IFERROR(VLOOKUP({celda},ProfesoresTabla,2,0),"(desconocido)"))')


def _escribir_filas(ws, filas, n: int) -> None:
    """Escribe las `n` filas de la tabla: las de carga que trae el YAML y, tras
    ellas, las de reserva. Las dos llevan exactamente las mismas formulas; la
    unica diferencia es que las de reserva nacen sin datos."""
    for i in range(n):
        r = L.fila_carga(i)
        if i < len(filas):
            f = filas[i]
            # Solo el id, el tipo y el grupo son datos; el resto se calcula.
            ws[f"{L.COL_ID}{r}"] = f.asignatura.id
            ws[f"{L.COL_TIPO}{r}"] = f.tipo
            ws[f"{L.COL_GRUPO}{r}"] = f.grupo if f.grupo is not None else "-"
        ws[f"{L.COL_ASIGNATURA}{r}"] = _buscar_asignatura(r, A.COL_TABLA_NOMBRE)
        ws[f"{L.COL_CARRERA}{r}"] = _buscar_asignatura(r, A.COL_TABLA_CARRERA)
        ws[f"{L.COL_HORAS}{r}"] = _formula_horas(r)
        ws[f"{L.COL_NOMBRE}{r}"] = _formula_nombre_profesor(r)


def _aplicar_dropdowns(ws, n: int) -> None:
    """Un desplegable por columna editable que tenga lista de valores conocida.

    El aviso es 'information' y no bloqueante a proposito: hay que poder
    escribir un id que todavia no esta en la lista (una asignatura recien
    anadida, un profesor que aun no se ha dado de alta) sin que Calc o Excel lo
    rechacen. Quien se equivoque lo vera en ambar, que es un aviso y no un veto.
    """
    for fuente, col in ((A.RANGO_IDS, L.COL_ID),
                        (FUENTE_TIPOS, L.COL_TIPO),
                        ("ProfesoresValidos", L.COL_PROFESOR)):
        dv = DataValidation(type="list", formula1=fuente, allow_blank=True,
                            showErrorMessage=True, errorStyle="information")
        ws.add_data_validation(dv)
        dv.sqref = L.rango_editable(col, n)


def _aplicar_formato_condicional(ws, n: int) -> None:
    fi = L.FILA_PRIMERA_CARGA
    rango = f"A{fi}:{L.COL_ULTIMA}{L.fila_carga(n - 1)}"
    # Columnas fijadas con $ y fila relativa: toda la fila evalua sus propias
    # celdas de id y de profesor.
    #
    # Las tres reglas piden que la fila exista (que tenga id de asignatura).
    # Sin esa guarda, las filas de reserva saldrian todas amarillas y la hoja
    # se abriria con un aviso de "falta asignar" para trabajo que nadie ha
    # creado todavia.
    for formula, color in (
        # Amarillo: la fila existe pero nadie la imparte.
        (f'AND($A{fi}<>"",$G{fi}="")', estilos.COLOR_SIN_PROFESOR),
        # Ambar: hay algo escrito que no esta en la lista que le corresponde.
        (f'AND($G{fi}<>"",COUNTIF(ProfesoresValidos,$G{fi})=0)',
         estilos.COLOR_PROFESOR_DESCONOCIDO),
        (f'AND($A{fi}<>"",COUNTIF({A.RANGO_IDS},$A{fi})=0)',
         estilos.COLOR_PROFESOR_DESCONOCIDO),
    ):
        ws.conditional_formatting.add(rango, estilos.regla_formula(formula, color))


def _aplicar_formato(ws, depto: Departamento, n: int) -> None:
    fila_fin = L.fila_carga(n - 1)
    rango = f"A{L.FILA_ENCABEZADO_ASIGNACION}:{L.COL_ULTIMA}{fila_fin}"
    formato.aplicar_borde_tabla(ws, rango, interno=estilos.lado_fino(),
                                externo=estilos.lado_medio())
    # Padding aproximado para Calc: sangria + centrado vertical + filas mas altas.
    formato.aplicar_alineacion(ws, rango, estilos.alineacion_padding())
    formato.aplicar_alto_filas(ws, L.FILA_PRIMERA_CARGA, fila_fin, estilos.ALTO_FILA)
    # Las horas son enteras: sin formato explicito, Calc las muestra segun la
    # configuracion regional de quien abra el libro ("32" o "32,00").
    formato.aplicar_formato_numero(
        ws, f"{L.COL_HORAS}{L.FILA_PRIMERA_CARGA}:{L.COL_HORAS}{fila_fin}")
    _separar_asignaturas(ws, depto.filas())
    formato.autoajustar_columnas(ws, extra=4)
    # Las cuatro columnas calculadas muestran el resultado de una formula, no su
    # texto: `autoajustar_columnas` las ignora y su ancho se fija aqui con los
    # valores que pueden llegar a mostrar.
    for col, textos in (
        (L.COL_ASIGNATURA, [a.nombre for a in depto.asignaturas] + ["Asignatura"]),
        (L.COL_CARRERA, [a.carrera for a in depto.asignaturas] + ["Carrera"]),
        (L.COL_HORAS, ["Horas", "999"]),
        (L.COL_NOMBRE, [p.nombre for p in depto.profesores] + ["(desconocido)"]),
    ):
        formato.fijar_ancho_por_textos(ws, col, textos, extra=4)


def _separar_asignaturas(ws, filas) -> None:
    """Traza una linea gruesa bajo la ultima fila de carga de cada asignatura,
    como la que separa los turnos en la rejilla del horario: las filas de una
    misma asignatura (Conf + sus grupos de CP) se leen como un bloque.

    Solo recorre las filas que trae el YAML: las de reserva no tienen todavia
    asignatura y no hay nada que separar. La linea se traza al generar, asi que
    no sigue a los cambios manuales de id; el agrupamiento real se ve filtrando.
    """
    for i in range(len(filas) - 1):
        if filas[i].asignatura.id != filas[i + 1].asignatura.id:
            fila = L.fila_carga(i)
            formato.aplicar_borde_inferior(
                ws, f"A{fila}:{L.COL_ULTIMA}{fila}", estilos.lado_grueso())


def _escribir_leyenda(ws, n: int) -> None:
    fila = L.fila_carga(n - 1) + 2
    leyenda.escribir_leyenda(ws, f"A{fila}", (
        (estilos.COLOR_SIN_PROFESOR, "Falta asignar profesor"),
        (estilos.COLOR_PROFESOR_DESCONOCIDO,
         "Id fuera de la lista (profesor o asignatura)"),
        (estilos.COLOR_SOBRECARGA,
         "Profesor por encima de su tope (panel de la derecha)"),
    ))
