"""Comprueba las tablas cruzadas del libro contra el oraculo de cruces.

EL PROBLEMA QUE RESUELVE

El oraculo de valores dice que vale cada campo de cada fila, y con el se
comprueban las hojas de datos. Una tabla cruzada no es una coleccion: es una
vista, y su pestana no tiene filas con las que emparejarse. Mientras solo se
comprobaron las hojas de datos, un libro podia salir con todas sus pestanas
cruzadas vacias y pasar la verificacion entera.

LO QUE COMPRUEBA

  1. Que cada cuadrante del oraculo tiene su pestana en el libro.
  2. Que cada casilla ocupada del oraculo esta en los ejes de su pestana.
  3. Que cada casilla de la pestana, ocupada o no, vale lo que dice el
     oraculo.

Lo llama verificar.py, con el libro ya recalculado por LibreOffice.
"""


from comparar import iguales


def texto_de_casilla(valores):
    """Lo que la hoja de calculo ensena en una casilla con esos valores.

    Con un valor, el valor. Con varios -un conflicto declarado con
    :UNICA-SALVO-, los dos primeros y cuantos mas hay: es la emulacion que
    declara la arquitectura en su informe de conformidad.
    """
    if not valores:
        return ""
    if len(valores) == 1:
        return valores[0]
    texto = "{} / {}".format(valores[0], valores[1])
    if len(valores) > 2:
        texto += " (+{})".format(len(valores) - 2)
    return texto


def _ejes_de(hoja_plan):
    """Los dos ejes de una pestana cruzada, leidos del plano.

    Devuelve (filas, columnas): de numero de fila a valor del eje de filas, y
    de letra de columna a texto del eje de columnas.
    """
    columnas = {}
    for enc in hoja_plan.get("encabezados") or []:
        if enc["campo"] != "__eje__":
            letra = "".join(c for c in enc["celda"] if c.isalpha())
            columnas[letra] = enc["texto"]
    filas = {}
    for celda in hoja_plan.get("celdas") or []:
        if celda["celda"].startswith("A"):
            filas[int(celda["celda"][1:])] = celda["valor"]
    return filas, columnas


def comparar_ejes(nombre, filas, columnas, cuadrante, normalizar):
    """Compara los ejes de una pestana, en su orden, con los del oraculo.

    Con un dominio declarado hay filas y columnas sin ninguna casilla
    ocupada (el turno en que nadie hace guardia); compararlas solo por sus
    casillas no diria si estan. Devuelve (comprobadas, fallos)."""
    if "filas" not in cuadrante:
        return 0, []
    fallos = []
    leidas = [normalizar(filas[n]) for n in sorted(filas)]
    esperadas = [normalizar(v) for v in cuadrante["filas"] or []]
    if leidas != esperadas:
        fallos.append("{}: las filas son {!r} y el oraculo dice {!r}".format(
            nombre, leidas, esperadas))
    leidas = [normalizar(t) for t in columnas.values()]
    esperadas = [normalizar(v) for v in cuadrante["columnas"] or []]
    if leidas != esperadas:
        fallos.append("{}: las columnas son {!r} y el oraculo dice {!r}".format(
            nombre, leidas, esperadas))
    return 2, fallos


def verificar_cruces(plano, cruces, libro, normalizar):
    """Compara cada pestana cruzada de LIBRO con su cuadrante del oraculo.

    NORMALIZAR es la funcion con la que verificar.py iguala lo leido y lo
    esperado antes de compararlos; se recibe para que las dos comprobaciones
    usen exactamente el mismo criterio.

    Devuelve una lista de (nombre de pestana, casillas comparadas, fallos),
    con una entrada al final para los cuadrantes del oraculo que no tienen
    pestana.
    """
    esperados = {}
    for vista in cruces:
        for cuadrante in vista["cuadrantes"]:
            esperados[(vista["vista"], cuadrante["seccion"])] = cuadrante

    resultado = []
    vistos = set()

    for hoja_plan in plano["hojas"]:
        identidad = hoja_plan.get("cruce")
        if not identidad:
            continue
        clave = (identidad["vista"], identidad["seccion"])
        nombre = hoja_plan["nombre"]
        vistos.add(clave)
        comprobadas = 0
        fallos = []
        resultado.append((nombre, 0, fallos))
        if clave not in esperados:
            fallos.append("la pestana {!r} no corresponde a ningun cuadrante "
                          "del oraculo".format(nombre))
            continue
        if nombre not in libro.sheetnames:
            fallos.append("falta la hoja {!r}".format(nombre))
            continue

        hoja = libro[nombre]
        filas, columnas = _ejes_de(hoja_plan)
        cuadrante = esperados[clave]
        n, f = comparar_ejes(nombre, filas, columnas, cuadrante, normalizar)
        comprobadas += n
        fallos.extend(f)
        casillas = {}
        for casilla in cuadrante["casillas"] or []:
            casillas[(normalizar(casilla["fila"]),
                      normalizar(casilla["columna"]))] = casilla["valores"]

        en_los_ejes = set()
        for numero, valor_fila in filas.items():
            for letra, valor_columna in columnas.items():
                posicion = (normalizar(valor_fila), normalizar(valor_columna))
                en_los_ejes.add(posicion)
                esperado = normalizar(texto_de_casilla(casillas.get(posicion, [])))
                real = normalizar(hoja["{}{}".format(letra, numero)].value)
                comprobadas += 1
                if not iguales(real, esperado):
                    fallos.append(
                        "{}!{}{}  esperado {!r}  obtenido {!r}".format(
                            nombre, letra, numero, esperado, real))

        for posicion in casillas:
            if posicion not in en_los_ejes:
                fallos.append("{}: la casilla {!r} del oraculo no esta en "
                              "los ejes de la pestana".format(nombre, posicion))
        if casillas and comprobadas == 0:
            fallos.append("{}: no se comparo ninguna casilla".format(nombre))
        resultado[-1] = (nombre, comprobadas, fallos)

    sin_pestana = ["la vista {!r}, seccion {!r}, no tiene pestana en el libro"
                   .format(*clave) for clave in esperados if clave not in vistos]
    if sin_pestana:
        resultado.append(("(cuadrantes sin pestana)", 0, sin_pestana))
    return resultado
