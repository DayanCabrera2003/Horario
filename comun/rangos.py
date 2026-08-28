"""Rangos nombrados que crecen solos con los datos.

Un rango fijo obliga a elegir entre dos males: si abarca solo lo escrito, anadir
una fila no la mete en el desplegable; si abarca la reserva, el desplegable
muestra las filas vacias. `OFFSET(...COUNTA(...))` resuelve las dos: se ancla en
la primera fila de datos y se dimensiona con cuantas hay escritas.

Comprobado en LibreOffice Calc antes de usarlo (tarea 3a.1 del plan): el texto
sobrevive al round-trip tal cual, `ROWS` del rango da las filas escritas y no la
capacidad, y al escribir en la primera fila libre el rango crece.

**Ojo con las columnas de formulas:** `COUNTA` cuenta celdas no vacias, y una
formula que devuelve "" ocupa celda. Un rango anclado en una columna calculada
abarca siempre toda su capacidad; da igual para BUSCARV y SUMAR.SI, pero no
sirve para dimensionar nada.

**La trampa, tambien comprobada:** `COUNTA` cuenta celdas no vacias, no filas
ocupadas. Una fila en blanco en medio del listado no reduce la cuenta, pero
desplaza el final del rango: con un hueco, la ultima entrada escrita queda fuera
y en su lugar entra una celda vacia. Por eso las guias piden no dejar huecos.
"""
from openpyxl.utils import quote_sheetname

# Filas de reserva minimas de un listado. Con pocos datos, el 50% se queda en
# nada (dos profesores darian una sola fila libre), asi que manda este minimo.
CAPACIDAD_MINIMA = 20


def capacidad_para(n_filas: int) -> int:
    """Cuantas filas reservar para un listado que hoy trae `n_filas`.

    La mitad de lo declarado, con un minimo: crecer un 50% sin regenerar cubre
    el curso siguiente en la practica, y el minimo cubre los listados pequenos.
    """
    return n_filas + max(CAPACIDAD_MINIMA, n_filas // 2)


def rango_dinamico(hoja: str, columna: str, fila_inicial: int,
                   capacidad: int, columnas: int = 1) -> str:
    """Texto del rango nombrado que cubre las filas escritas de `columna`.

    `capacidad` es cuantas filas abarca la ventana en la que se cuenta, es decir
    los datos mas la reserva. `columnas` ensancha el rango a la derecha, para los
    que alimentan un BUSCARV y no solo un desplegable; la cuenta se hace siempre
    sobre la primera columna, que es la que decide cuantas filas hay.

    El resultado va tal cual a `DefinedName.attr_text`, sin '=' delante: openpyxl
    lo escribe verbatim.
    """
    h = quote_sheetname(hoja)
    fila_final = fila_inicial + capacidad - 1
    return (f"OFFSET({h}!${columna}${fila_inicial},0,0,"
            f"COUNTA({h}!${columna}${fila_inicial}:${columna}${fila_final}),"
            f"{columnas})")
