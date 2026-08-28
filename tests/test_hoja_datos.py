from openpyxl import Workbook
from horarios.modelo import Grupo, Anio, Facultad
from horarios.hoja_datos import construir_hoja_datos, _formula_firma_anio, NOMBRE_HOJA


def _fac():
    g = [Grupo("C", 1, 1, 1), Grupo("M", 1, 1, 1)]
    anios = {"C1": Anio("C", 1, ()), "M1": Anio("M", 1, ())}
    return Facultad(aulas=("Aula 1", "Lab"), dias=("Lunes",), turnos=2, grupos=tuple(g), anios=anios)


def test_crea_la_hoja_oculta():
    fac = _fac(); wb = Workbook()
    construir_hoja_datos(wb, fac)
    assert wb[NOMBRE_HOJA].sheet_state == "hidden"


def test_la_auxiliar_ya_no_copia_la_lista_de_aulas():
    # Desde la fase 3a la lista vive en la hoja visible `Aulas`, que es quien
    # define AulasValidas. Aqui solo queda lo derivado (las firmas de año).
    fac = _fac(); wb = Workbook()
    construir_hoja_datos(wb, fac)
    valores = [c.value for col in wb[NOMBRE_HOJA].iter_cols() for c in col]
    assert "Aula 1" not in valores and "Lab" not in valores
    assert "AulasValidas" not in wb.defined_names


def test_firma_usa_countif():
    fac = _fac(); wb = Workbook()
    celdas = construir_hoja_datos(wb, fac)
    # celdas: {(dia, turno, aula): direccion_de_la_firma}
    dir_firma = celdas[("Lunes", 1, "Aula 1")]   # p.ej. "Auxiliar!C1" (referencia calificada)
    ws = wb[NOMBRE_HOJA]
    coord_local = dir_firma.split("!")[1]         # indexar la hoja con la coord local, no "Auxiliar!C1"
    assert ws[coord_local].value.startswith("=")
    assert "COUNTIF" in ws[coord_local].value


def test_firma_referencia_ambos_anios_y_mix():
    # Con dos años distintos presentes, la fórmula debe referenciar las celdas-aula
    # de ambos grupos, incluir ambos códigos de año y la rama de fallback "MIX".
    fac = _fac(); wb = Workbook()
    celdas = construir_hoja_datos(wb, fac)
    ws = wb[NOMBRE_HOJA]
    coord_local = celdas[("Lunes", 1, "Aula 1")].split("!")[1]
    formula = ws[coord_local].value
    assert "C111" in formula and "M111" in formula     # celdas-aula de ambos grupos
    assert '"C1"' in formula and '"M1"' in formula      # ambos códigos de año
    assert '"MIX"' in formula                           # rama de conflicto


def test_formula_firma_anio_directo():
    # Prueba unitaria directa del helper para un montaje de 2 años.
    anios_por_codigo = {
        "C1": [Grupo("C", 1, 1, 1)],
        "M1": [Grupo("M", 1, 1, 1)],
    }
    formula = _formula_firma_anio(anios_por_codigo, 0, 1, "Aula 1")
    assert formula.startswith("=")
    assert "COUNTIF" in formula
    assert '"C1"' in formula and '"M1"' in formula
    assert '"MIX"' in formula


def test_mapa_cubre_todas_las_combinaciones():
    fac = _fac(); wb = Workbook()
    celdas = construir_hoja_datos(wb, fac)
    assert len(celdas) == len(fac.dias) * fac.turnos * len(fac.aulas)
    # y todas las direcciones son únicas
    assert len(set(celdas.values())) == len(celdas)


def test_la_hoja_de_datos_queda_protegida():
    # Nada es editable a mano en esta hoja oculta: todo son formulas de apoyo.
    fac = _fac(); wb = Workbook()
    construir_hoja_datos(wb, fac)
    ws = wb[NOMBRE_HOJA]
    assert ws.protection.sheet is True


def test_la_carga_no_deduce_la_carrera_del_id_de_grupo():
    """Hallazgo de la revision, reproducido: con una carrera de dos letras el id
    de grupo es 'CC111', y sacar la carrera con LEFT(...,1) daba 'C' y el año con
    VALUE(MID(...,2,1)) daba error. Todo el SUMIFS caia al IFERROR y los turnos
    semanales de todos los profesores salian 0, sin ningun aviso.

    La carrera y el año se leen de la hoja Grupos, que ya los tiene en columnas.
    """
    from horarios.modelo import Profesor, Docencia
    fac = Facultad(
        aulas=("Aula 1",), dias=("Lunes",), turnos=2,
        grupos=(Grupo("CC", 1, 1, 1),),
        anios={"CC1": Anio("CC", 1, ())},
        profesores=(Profesor(id="PIAD", nombre="Pedro"),),
        docencia=(Docencia(grupo="CC111", asignatura="AMI-C", profesor="PIAD"),),
    )
    wb = Workbook()
    construir_hoja_datos(wb, fac)
    formula = wb[NOMBRE_HOJA]["Z2"].value
    assert "LEFT(" not in formula, formula
    assert "MID(" not in formula, formula
    assert "GruposTabla" in formula, formula
