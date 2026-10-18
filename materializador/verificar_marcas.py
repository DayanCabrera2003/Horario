"""Comprueba que el formato condicional de cada marca pinta las celdas que
dice el evaluador de referencia (fase 2, hueco C7).

EL PROBLEMA QUE RESUELVE

Hasta el 2026-10-18 ningun verificador miraba el color de las celdas: se
comparaban los valores y el texto de la columna de estado, que sale de otra
formula. Si el formato condicional de una marca pintara el campo
equivocado, o nada, la bateria seguia en verde.

EL PROCEDIMIENTO

LibreOffice no deja leer el resultado de un formato condicional en un libro
recalculado, pero si el de una formula. Asi que, en una COPIA del libro que
solo usa la verificacion, por cada regla de formato condicional de una hoja
de datos y cada celda de datos de su rango, se escribe en una celda de
sondeo, a la derecha de todo, la formula de la regla trasladada a esa celda
(una regla de Excel es relativa a la esquina de su rango, y openpyxl sabe
trasladarla). Despues de recalcular, la sonda vale 1 si la regla pintaria la
celda y 0 si no. Se compara con el oraculo, que dice para cada fila que
campos pinta cada marca.

Las reglas se leen del LIBRO, no del plano: asi se comprueba lo que de
verdad colorea, tambien si el materializador aplicara mal una regla. Cada
regla del libro se empareja con su marca por su rango (y su formula); una
regla sin marca, o una marca del plano sin regla en el libro, es un fallo.
Es la comprobacion de todas las marcas, sin anadir nada al libro que recibe
el usuario.
"""

from openpyxl.formula.translate import Translator
from openpyxl.utils import get_column_letter, range_boundaries


def _marcados_de(envoltura):
    """Los campos que pinta cada marca en una fila del oraculo, como dict
    marca -> lista de campos, o None si la fila no trae ese dato (un oraculo
    escrito con un formato anterior): entonces no hay con que comparar, y
    darlo por "no pinta nada" seria inventarse el oraculo."""
    if isinstance(envoltura, list) and len(envoltura) > 3:
        return {marca: datos[1] for marca, datos in (envoltura[3] or {}).items()}
    return None


def _limites(rango):
    """Los limites de RANGO como tupla: "C4:C4" y "C4" son el mismo rango,
    y el plano y openpyxl no siempre lo escriben igual."""
    return range_boundaries(rango)


def _reglas_del_libro(hoja):
    """Las reglas de formato condicional de HOJA, como (rango, formula)."""
    reglas = []
    for formato in hoja.conditional_formatting:
        for rango in str(formato.sqref).split():
            for regla in formato.rules:
                if regla.formula:
                    reglas.append((rango, regla.formula[0]))
    return reglas


def _marca_de_regla(rango, formula, reglas_del_plano):
    """La marca de la regla del libro (RANGO, FORMULA): la del plano con el
    mismo rango y la misma formula, o si la formula cambio, la del mismo
    rango. None si ninguna regla del plano cubre ese rango."""
    del_rango = [r for r in reglas_del_plano
                 if _limites(rango) in {_limites(x) for x in r["rango"].split()}]
    exacta = [r for r in del_rango if r["formula"] == formula]
    elegida = (exacta or del_rango or [None])[0]
    return elegida["estado"] if elegida else None


def preparar_sondas(libro, plano, esperado):
    """Escribe en LIBRO (una copia) las celdas de sondeo de cada regla de
    formato condicional de las hojas de datos.

    Devuelve (sondas, fallos). Cada sonda es (hoja, celda de sondeo, marca,
    campo, indice de fila en el oraculo, celda pintada, coleccion). Los
    fallos son reglas del libro sin marca y marcas del plano sin regla."""
    sondas = []
    fallos = []
    for hoja_plan in plano["hojas"]:
        coleccion = hoja_plan.get("coleccion")
        if not coleccion or coleccion not in esperado:
            continue
        reglas_del_plano = hoja_plan.get("formatos_condicionales") or []
        hoja = libro[hoja_plan["nombre"]]
        reglas = _reglas_del_libro(hoja)
        en_el_libro = {(_limites(rango), formula) for rango, formula in reglas}
        for regla in reglas_del_plano:
            for rango in regla["rango"].split():
                if (_limites(rango), regla["formula"]) not in en_el_libro:
                    fallos.append("{}: la marca {} no tiene su formato en {}".format(
                        hoja.title, regla["estado"], rango))
        campo_de_letra = {}
        for enc in hoja_plan.get("encabezados") or []:
            letra = "".join(c for c in enc["celda"] if c.isalpha())
            campo_de_letra[letra] = enc["campo"]
        # Solo las filas cuyo oraculo dice que campos pinta cada marca.
        filas = len(esperado[coleccion] or [])
        if any(_marcados_de(e) is None for e in esperado[coleccion] or []):
            continue
        primera = hoja_plan["fila_primera"]
        columna_libre = hoja.max_column + 2
        for rango, formula_regla in reglas:
            marca = _marca_de_regla(rango, formula_regla, reglas_del_plano)
            if marca is None:
                fallos.append("{}: hay un formato en {} que no es de ninguna marca".format(
                    hoja.title, rango))
                continue
            minc, minr, maxc, _ = range_boundaries(rango)
            origen = "{}{}".format(get_column_letter(minc), minr)
            for col in range(minc, maxc + 1):
                letra = get_column_letter(col)
                sonda = get_column_letter(columna_libre)
                columna_libre += 1
                for i in range(filas):
                    fila = primera + i
                    destino = "{}{}".format(letra, fila)
                    formula = Translator("=" + formula_regla, origin=origen) \
                        .translate_formula(destino)
                    celda_sonda = "{}{}".format(sonda, fila)
                    hoja[celda_sonda] = "=IF({},1,0)".format(formula[1:])
                    sondas.append((hoja_plan["nombre"], celda_sonda, marca,
                                   campo_de_letra.get(letra, letra), i, destino, coleccion))
    return sondas, fallos


def comprobar_sondas(libro, sondas, esperado):
    """Compara el valor de cada sonda en LIBRO (ya recalculado) con el
    oraculo. Devuelve (comprobadas, fallos)."""
    fallos = []
    for nombre, celda, marca, campo, indice, pintada, coleccion in sondas:
        real = libro[nombre][celda].value
        marcados = _marcados_de(esperado[coleccion][indice]) or {}
        debe = campo in marcados.get(marca, [])
        if real not in (0, 1):
            fallos.append("{}!{}: la regla de {} no se puede evaluar ({!r})".format(
                nombre, pintada, marca, real))
        elif bool(real) != debe:
            fallos.append("{}!{}: la marca {} {} pintar {} y {}".format(
                nombre, pintada, marca, "tiene que" if debe else "no tiene que",
                campo, "no lo pinta" if debe else "lo pinta"))
    return len(sondas), fallos
