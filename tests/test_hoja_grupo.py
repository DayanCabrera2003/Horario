from openpyxl import Workbook
from horarios.modelo import Grupo, Asignatura, Anio, Facultad, Horario, Asignacion
from horarios.hoja_grupo import construir_hoja_grupo
from horarios import layout as L
from horarios import estilos


def _facultad():
    anio = Anio(carrera="C", numero=1, asignaturas=(
        Asignatura("L-C", "Lógica", 1),
        Asignatura("Pro-C", "Programación", 2),
    ))
    g = Grupo("C", 1, 1, 1)
    return Facultad(aulas=("Aula 1", "Lab"), dias=("Lunes", "Martes"),
                    turnos=6, grupos=(g,), anios={"C1": anio}), g


def test_escribe_id_y_formulas():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    assert ws[L.CELDA_GRUPO_ID].value == "C111"
    # Asignadas = un COUNTIF por fila de asignatura, sumados (ver la regresion
    # de test_asignadas_solo_cuenta_las_filas_de_asignatura).
    asignadas = ws[L.celda_asig_tabla_asignadas(0)].value
    assert asignadas.startswith("=COUNTIF(")
    # fixture: 2 días, 6 turnos, 3 filas por turno -> asignatura en 4, 7, ... 19
    assert "COUNTIF(B4:C4," in asignadas
    assert "COUNTIF(B19:C19," in asignadas
    assert asignadas.count("COUNTIF") == 6
    faltan = ws[L.celda_asig_tabla_faltan(0)].value
    assert faltan.startswith("=")


def test_hay_dropdowns_de_aula_y_asignatura():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    # dos validaciones de lista: aula (filas de aula) y asignatura (filas de asignatura)
    dvs = ws.data_validations.dataValidation
    assert len(dvs) == 2
    formulas = {dv.formula1 for dv in dvs}
    assert "AulasValidas" in formulas
    assert "$I$4:$I$5" in formulas
    # openpyxl escribe formula1 verbatim: un '=' inicial rompe el dropdown en Excel.
    assert all(not f.startswith("=") for f in formulas)


def test_dropdowns_no_bloquean_valores_fuera_de_lista():
    # En Calc, un dropdown de lista sin accion de error configurada rechaza (Stop) los
    # valores nuevos. Para poder escribir aulas/asignaturas fuera de la lista sin que se
    # bloquee, ambas validaciones usan errorStyle 'information' (aviso no bloqueante) con
    # el mensaje de error activo. El desplegable se mantiene como ayuda.
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    dvs = ws.data_validations.dataValidation
    assert dvs, "esperaba validaciones de datos"
    for dv in dvs:
        assert dv.errorStyle == "information"
        assert dv.showErrorMessage is True


def test_tablas_tienen_bordes():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    # Esquina superior izquierda de la tabla de asignaturas: perimetro medium
    assert ws["I3"].border.left.style == "medium"
    assert ws["I3"].border.top.style == "medium"
    # Cara interna de la rejilla de horario: fina
    assert ws[L.celda_asig(0, 1)].border.top.style == "thin"
    # Etiqueta de turno (esquina superior de la columna A): perimetro medium
    assert ws[f"A{L.fila_asig(1)}"].border.left.style == "medium"


def test_fondo_en_filas_de_aula():
    # Las filas de aula llevan un fondo neutro que las marca como zona de aulas;
    # las filas de asignatura no reciben ese fondo.
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    aula = ws[L.celda_aula(0, 1)].fill
    assert estilos.COLOR_FONDO_AULA in (aula.fgColor.rgb or "")
    asig = ws[L.celda_asig(0, 1)].fill
    assert estilos.COLOR_FONDO_AULA not in (asig.fgColor.rgb or "")


def test_padding_en_celdas_del_horario():
    # Padding aproximado para Calc: sangria + centrado vertical en la rejilla y
    # mayor alto de fila. El .xlsx no tiene padding real de celda.
    from horarios.hoja_grupo import ALTO_FILA_HORARIO
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    alin = ws[L.celda_asig(0, 1)].alignment
    assert alin.indent >= 1
    assert alin.vertical == "center"
    # La fila de la rejilla tiene un alto mayor que el por defecto.
    assert ws.row_dimensions[L.fila_asig(1)].height == ALTO_FILA_HORARIO


def test_linea_gruesa_separa_turnos():
    # Un turno ocupa 2 filas (asignatura + aula). La frontera inferior de la fila
    # de aula de cada turno (salvo el ultimo) lleva un borde grueso separador.
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    # Turno 1: bajo su ultima fila (la del profesor), borde grueso.
    assert ws[L.celda_profesor(0, 1)].border.bottom.style == "thick"
    assert ws[f"A{L.fila_profesor(1)}"].border.bottom.style == "thick"
    # Ultimo turno (6): su borde inferior es el perimetro medio, no el separador.
    assert ws[L.celda_profesor(0, fac.turnos)].border.bottom.style == "medium"


def test_frecuencia_exacta_colorea_fila_completa():
    # La regla de frecuencia exacta (verde) y la de sobre-planificada (rojo) cubren
    # la fila entera de la asignatura (I..M), no solo la columna Asignadas, y usan
    # columnas fijadas ($L/$K) con fila relativa.
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    pares = [(str(rng.sqref), r.formula[0])
             for rng in ws.conditional_formatting
             for r in ws.conditional_formatting[rng]]
    exacta = [(rng, f) for rng, f in pares if f == "$L4=$K4"]
    sobre = [(rng, f) for rng, f in pares if f == "$L4>$K4"]
    assert exacta, pares
    assert sobre, pares
    # fixture: 2 asignaturas -> filas 4 y 5, columnas I..M
    assert exacta[0][0].startswith("I4:M")
    assert sobre[0][0].startswith("I4:M")


def test_inmoviliza_dias_y_turnos():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    # Freeze en la primera celda editable: fija la fila de dias (3) y la columna A
    assert ws.freeze_panes == L.celda_asig(0, 1)  # "B4"


def test_encabezados_con_estilo():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    # Encabezado de dia (fila 3) en negrita
    assert ws[f"{L.col_dia(0)}{L.FILA_ENCABEZADO_DIAS}"].font.bold is True
    # Cabecera de la tabla de asignaturas en negrita
    assert ws["I3"].font.bold is True
    # Etiqueta de turno en negrita
    assert ws[f"A{L.fila_asig(1)}"].font.bold is True
    # Una fila de aula intercalada (en blanco) NO recibe relleno de encabezado
    fill_aula = ws[f"A{L.fila_aula(1)}"].fill
    assert fill_aula.fgColor.rgb in (None, "00000000")


def test_columnas_ajustadas_al_contenido():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    # La columna de nombres (J) debe caber la asignatura mas larga ("Programación").
    assert ws.column_dimensions["J"].width >= len("Programación") + 2


def test_hoja_grupo_tiene_leyenda():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    textos = [c.value for row in ws.iter_rows() for c in row if isinstance(c.value, str)]
    assert any("Leyenda" in t for t in textos)
    assert any("fuera del listado" in t for t in textos)  # descripcion de aula invalida


def test_horario_rellena_celdas():
    fac, g = _facultad()
    h = Horario(grupo_id="C111")
    h.celdas[("Lunes", 1)] = Asignacion(asig="L-C", aula="Aula 1")
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=h)
    assert ws[L.celda_asig(0, 1)].value == "L-C"
    assert ws[L.celda_aula(0, 1)].value == "Aula 1"


def test_esqueleto_deja_celdas_vacias():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    assert ws[L.celda_asig(0, 1)].value is None


def test_regla_asig_desconocida_usa_rango_absoluto():
    # La regla "asignatura desconocida" se aplica sobre un sqref multi-rango que abarca
    # todas las filas de asignatura. El COUNTIF debe apuntar SIEMPRE a la tabla de ids
    # (rango absoluto $I$), o Excel lo desplaza por fila y comprueba el rango equivocado.
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    formulas = [r.formula[0]
                for rng in ws.conditional_formatting
                for r in ws.conditional_formatting[rng]]
    desconocida = [f for f in formulas if "COUNTIF($I$" in f]
    assert desconocida, f"esperaba un COUNTIF con rango absoluto, vi: {formulas}"


def test_hay_regla_de_aula_sin_asignatura():
    # Turno con aula puesta pero asignatura vacia: la formula se ancla en B4
    # (asignatura) y B5 (su aula, una fila mas abajo) y se desplaza sola al
    # resto de turnos gracias al sqref multi-rango.
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    formulas = [r.formula[0]
                for rng in ws.conditional_formatting
                for r in ws.conditional_formatting[rng]]
    assert 'AND(B4="",B5<>"")' in formulas


def test_la_regla_usa_el_color_reservado():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    reglas = [r for rng in ws.conditional_formatting
              for r in ws.conditional_formatting[rng]]
    (regla,) = [r for r in reglas if r.formula[0] == 'AND(B4="",B5<>"")']
    color = regla.dxf.fill.bgColor.rgb
    assert color.endswith(estilos.COLOR_AULA_SIN_ASIG)


def test_la_leyenda_menciona_el_caso():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    textos = [c.value for row in ws.iter_rows() for c in row if isinstance(c.value, str)]
    assert any("sin asignatura" in t for t in textos)


def test_la_hoja_de_grupo_queda_protegida():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    assert ws.protection.sheet is True


def test_la_rejilla_queda_editable():
    # B4 = asignatura del turno 1 del primer dia; B5 = su aula.
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    assert ws["B4"].protection.locked is False
    assert ws["B5"].protection.locked is False


def test_la_tabla_de_asignaturas_queda_bloqueada():
    # L4 = "Asignadas", una formula: es justo lo que el tutor borro sin querer.
    # Toda celda de openpyxl nace bloqueada (aunque la hoja no se proteja), asi
    # que B4 (la rejilla, editable) sirve de control: si tambien saliera
    # bloqueada, no probaria que proteger_hoja corrio ni que L4 quedo fuera de
    # lo editable.
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    assert ws["L4"].protection.locked is True
    assert ws["B4"].protection.locked is False


def test_la_hoja_sale_lista_para_imprimir():
    # Un horario acaba pegado en la pared: apaisado, ajustado al ancho de una
    # pagina y repitiendo la cabecera de dias en cada pagina impresa.
    fac, g = _facultad()
    ws = Workbook().active
    construir_hoja_grupo(ws, g, fac, horario=None)
    assert ws.page_setup.orientation == "landscape"
    assert ws.sheet_properties.pageSetUpPr.fitToPage is True
    assert ws.page_setup.fitToWidth == 1
    # openpyxl normaliza "1:3" a "$1:$3" al asignarlo.
    assert ws.print_title_rows == f"$1:${L.FILA_ENCABEZADO_DIAS}"


def _grupo_de(anio: int):
    """Facultad de un solo grupo del ano pedido, para comparar pestanas."""
    a = Anio(carrera="C", numero=anio, asignaturas=(Asignatura("L-C", "Lógica", 1),))
    g = Grupo("C", anio, 1, 1)
    return Facultad(aulas=("Aula 1",), dias=("Lunes",), turnos=6, grupos=(g,),
                    anios={f"C{anio}": a}), g


def _pestana(anio: int) -> str:
    fac, g = _grupo_de(anio)
    ws = Workbook().active
    construir_hoja_grupo(ws, g, fac, horario=None)
    return ws.sheet_properties.tabColor.rgb


def test_la_pestana_se_colorea_por_ano():
    # Con 22 grupos la barra de pestanas es un muro de nombres; el color por ano
    # los agrupa de un vistazo.
    assert _pestana(1).endswith(estilos.COLORES_PESTANA_ANIO[0])


def test_anos_distintos_llevan_pestanas_distintas():
    assert _pestana(1) != _pestana(2)


def test_asignadas_solo_cuenta_las_filas_de_asignatura():
    """Regresion: 'Asignadas' contaba sobre el rectangulo entero de la rejilla.

    El comentario que lo justificaba decia que los nombres de aula nunca
    coinciden con ids de asignatura, y eso no es una garantia sino una
    suposicion: nada impide un aula llamada 'EF' y una asignatura 'EF'. Al
    anadir la fila de profesor el rectangulo gana un tercer espacio de nombres y
    el choque deja de ser hipotetico.
    """
    facultad = Facultad(
        aulas=("EF", "Aula 1"),          # un aula que se llama como la asignatura
        dias=("Lunes",), turnos=2,
        grupos=(Grupo("C", 1, 1, 1),),
        anios={"C1": Anio("C", 1, (Asignatura(id="EF", nombre="Educación Física",
                                              frecuencia=1),))},
    )
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, facultad.grupos[0], facultad)
    formula = ws[L.celda_asig_tabla_asignadas(0)].value
    # Las filas de aula no entran en la cuenta.
    filas_aula = {L.fila_aula(t) for t in range(1, facultad.turnos + 1)}
    for fila in filas_aula:
        assert f"B{fila}" not in formula, formula
    # Las de asignatura, si.
    for t in range(1, facultad.turnos + 1):
        assert f"B{L.fila_asig(t)}" in formula, formula


# --- Fila de profesor (fase 3b) ----------------------------------------------

def _facultad_con_profesores():
    from horarios.modelo import Profesor, Docencia
    anio = Anio(carrera="C", numero=1, asignaturas=(
        Asignatura("L-C", "Lógica", 1), Asignatura("Pro-C", "Programación", 2)))
    g = Grupo("C", 1, 1, 1)
    return Facultad(
        aulas=("Aula 1",), dias=("Lunes", "Martes"), turnos=2, grupos=(g,),
        anios={"C1": anio},
        profesores=(Profesor(id="PIAD", nombre="Pedro", grado="Dr."),),
        docencia=(Docencia(grupo="C111", asignatura="L-C", profesor="PIAD"),),
    ), g


def test_la_fila_de_profesor_se_calcula_desde_la_docencia():
    fac, g = _facultad_con_profesores()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac)
    celda = ws[L.celda_profesor(0, 1)]
    assert str(celda.value).startswith("=")
    # La clave es el grupo (fijo en la hoja) mas la asignatura de la celda de
    # arriba: al cambiar la asignatura, el profesor la sigue.
    assert "C111" in celda.value
    assert L.celda_asig(0, 1) in celda.value


def test_la_celda_de_profesor_queda_bloqueada():
    # Es una formula, no una entrada: se decide en la hoja Docencia.
    fac, g = _facultad_con_profesores()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac)
    assert ws[L.celda_profesor(0, 1)].protection.locked is not False


def test_sin_asignatura_la_celda_de_profesor_queda_en_blanco():
    # Un turno vacio no debe mostrar 0 ni #N/D.
    fac, g = _facultad_con_profesores()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac)
    formula = ws[L.celda_profesor(0, 1)].value
    assert f'IF({L.celda_asig(0, 1)}=""' in formula
    assert 'IFERROR' in formula


def test_sin_profesores_las_filas_de_profesor_van_ocultas():
    # Un libro que no declara profesores no debe ganar una fila vacia por turno.
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac)
    assert ws.row_dimensions[L.fila_profesor(1)].hidden is True
    assert ws[L.celda_profesor(0, 1)].value is None


def test_hay_regla_de_colision_de_profesor():
    """El mismo profesor en dos grupos a la vez se resalta.

    Todas las hojas de grupo comparten geometria, asi que el mismo (dia, turno)
    es la misma direccion en todas: la regla puede contar esa celda en cada
    hoja y ver si el profesor aparece mas de una vez.
    """
    fac, g = _facultad_con_profesores()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac)
    formulas = [r.formula[0] for reglas in ws.conditional_formatting._cf_rules.values()
                for r in reglas if r.formula]
    colision = [f for f in formulas if ">1" in f and "COUNTIF" in f]
    assert colision, formulas
    # Cuenta en todas las hojas de grupo, incluida la propia.
    assert "C111" in colision[0]


def test_la_leyenda_y_las_reglas_hablan_de_los_mismos_colores():
    """Hallazgo de la revision de la fase 1: la lista de reglas y la de la
    leyenda describen lo mismo desde dos sitios sin ningun vinculo. Se podia
    borrar una regla y olvidar su entrada de leyenda, o al reves, sin que ningun
    test se enterara."""
    fac, g = _facultad_con_profesores()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac)
    de_reglas = {r.dxf.fill.bgColor.rgb[-6:]
                 for reglas in ws.conditional_formatting._cf_rules.values()
                 for r in reglas if r.dxf and r.dxf.fill}
    # Solo el bloque de la leyenda: la cabecera de la tabla de asignaturas, que
    # vive en la misma columna, tiene su propio relleno y no es un aviso.
    fila_leyenda = L.FILA_PRIMERA_ASIG + len(fac.asignaturas_de(g)) - 1 + 2
    de_leyenda = {c.fill.start_color.rgb[-6:]
                  for fila in ws.iter_rows(min_row=fila_leyenda, min_col=9, max_col=9)
                  for c in fila
                  if c.fill and c.fill.start_color.rgb not in (None, "00000000")}
    assert de_reglas == de_leyenda, (sorted(de_reglas), sorted(de_leyenda))


def test_las_reglas_siguen_al_turno_al_desplazarse():
    """Las reglas se escriben una vez, ancladas en el primer turno, y Excel y
    Calc las desplazan al resto del sqref. Con turnos de tres filas ese
    desplazamiento tiene que saltar de tres en tres: una regla anclada mal
    evaluaria la celda del turno de al lado y nadie lo notaria mirando el libro.
    """
    from openpyxl.formula.translate import Translator
    fac, g = _facultad_con_profesores()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac)

    def formulas_de(celda):
        """Lo que evalua esa celda, traducido desde el ancla de su regla."""
        fuera = []
        for cf, reglas in ws.conditional_formatting._cf_rules.items():
            partes = str(cf.sqref).split()
            if not any(celda in ws[parte][0][0].coordinate or
                       celda == ws[parte][0][0].coordinate for parte in partes):
                pass
            for parte in partes:
                if ws[parte][0][0].coordinate != celda:
                    continue
                ancla = ws[partes[0]][0][0].coordinate
                for r in reglas:
                    if r.formula:
                        fuera.append(Translator(f"={r.formula[0]}", origin=ancla)
                                     .translate_formula(celda)[1:])
        return fuera

    # Turno 2: la regla de "aula puesta sin asignatura" tiene que mirar la
    # asignatura y el aula DE ESE turno (filas 7 y 8), no las del turno 1.
    asig2, aula2 = L.celda_asig(0, 2), L.celda_aula(0, 2)
    regla = [f for f in formulas_de(asig2) if f'{asig2}=""' in f]
    assert regla, formulas_de(asig2)
    assert f'{aula2}<>""' in regla[0], regla[0]
    # Y la de aula invalida, el aula de su turno.
    assert any(f'{aula2}<>""' in f and "AulasValidas" in f
               for f in formulas_de(aula2)), formulas_de(aula2)
