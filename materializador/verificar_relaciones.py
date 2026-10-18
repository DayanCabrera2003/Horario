"""Comprueba las hojas auxiliares de las relaciones uno a muchos.

Una relacion uno a muchos se emula en la hoja de calculo con una hoja aparte:
por cada fila padre, un bloque de lineas reservadas que buscan sus filas
relacionadas. El oraculo dice, para cada fila padre, cuantas relacionadas
trae. Aqui se cuenta, bloque por bloque, cuantas lineas ocupadas tiene el
libro recalculado, y se compara.

Si hay mas relacionadas que lineas reservadas, la ultima linea no busca: dice
cuantas sobran, "(+N mas)". Es la emulacion que declara la arquitectura.
"""

from openpyxl.utils import column_index_from_string, get_column_letter


def _linea_ocupada(hoja, fila, primera_columna, ancho):
    """Cierto si alguna celda de la linea FILA del bloque tiene contenido."""
    for i in range(ancho):
        valor = hoja["{}{}".format(get_column_letter(primera_columna + i), fila)].value
        if valor not in (None, ""):
            return True
    return False


def verificar_relacion(hoja_plan, hoja, esperado):
    """Compara los bloques de una hoja de relacion con el oraculo.

    Devuelve (comprobadas, fallos).
    """
    relacion = hoja_plan["relacion"]
    filas_padre = esperado.get(relacion["coleccion"])
    if filas_padre is None:
        return 0, ["{}: el oraculo no trae la coleccion {!r}".format(
            hoja.title, relacion["coleccion"])]

    primera = column_index_from_string(relacion["columna"])
    ancho = relacion["ancho"]
    capacidad = relacion["capacidad"]
    bloques = relacion["bloques"] or []
    fallos = []
    if len(bloques) != len(filas_padre):
        fallos.append("{}: hay {} bloques y el oraculo trae {} filas en {}".format(
            hoja.title, len(bloques), len(filas_padre), relacion["coleccion"]))

    comprobadas = 0
    for bloque, envoltura in zip(bloques, filas_padre):
        valores = envoltura[0] if isinstance(envoltura, list) else envoltura
        cuantas = int(valores.get(relacion["campo"]) or 0)
        lineas = [bloque["fila"] + i for i in range(1, capacidad + 1)]
        comprobadas += 1
        if cuantas > capacidad:
            aviso = hoja["{}{}".format(relacion["columna"], lineas[-1])].value
            esperado_aviso = "(+{} mas)".format(cuantas - (capacidad - 1))
            ocupadas = sum(1 for f in lineas[:-1]
                           if _linea_ocupada(hoja, f, primera, ancho))
            if aviso != esperado_aviso or ocupadas != capacidad - 1:
                fallos.append("{}: el bloque de {!r} deberia llenar {} lineas y "
                              "avisar {!r}; tiene {} y {!r}".format(
                                  hoja.title, bloque["clave"], capacidad - 1,
                                  esperado_aviso, ocupadas, aviso))
        else:
            ocupadas = sum(1 for f in lineas if _linea_ocupada(hoja, f, primera, ancho))
            if ocupadas != cuantas:
                fallos.append("{}: el bloque de {!r} tiene {} lineas ocupadas y el "
                              "oraculo dice {}".format(hoja.title, bloque["clave"],
                                                       ocupadas, cuantas))
    return comprobadas, fallos
