"""Proteccion de hojas: bloquear lo que se calcula solo, dejar editable lo que
se llena a mano.

En OOXML toda celda nace con `locked=True`, pero ese atributo no hace nada
mientras la hoja no este protegida. Al proteger, se cierra todo de golpe; por
eso el desbloqueo de lo editable tiene que ser explicito.

Sin contrasena a proposito: el objetivo es evitar que se borre una formula sin
querer, no proteger secretos. Quien necesite tocar una celda calculada quita la
proteccion desde el menu de Excel o de Calc.
"""
from openpyxl.styles import Protection

_DESBLOQUEADA = Protection(locked=False)


def desbloquear(ws, rangos) -> None:
    """Marca como editables las celdas de `rangos`.

    Cada entrada puede ser un rango simple ("B2:C3") o varios separados por
    espacios ("B4:F4 B6:F6"), que es el formato que devuelven las funciones de
    `layout` para el formato condicional. `ws[...]` no acepta el segundo, asi
    que se parte aqui.

    Se aplica celda a celda porque en openpyxl la proteccion es un atributo de
    estilo por celda, no de rango. Asignarla no toca fuente, relleno ni borde:
    cada atributo de estilo es independiente.
    """
    for entrada in rangos:
        for rango in str(entrada).split():
            for fila in ws[rango]:
                for celda in fila:
                    celda.protection = _DESBLOQUEADA


def proteger_hoja(ws, editables=(), permitir_orden: bool = False) -> None:
    """Protege `ws` dejando editables los rangos de `editables`.

    `permitir_orden` habilita ordenar y autofiltrar. Al proteger, OOXML los
    prohibe por defecto, y en las hojas de consulta eso estorba mas de lo que
    ayuda. Cada atributo de `SheetProtection` significa "esta operacion queda
    prohibida", de ahi que habilitarlas sea ponerlas en False.
    """
    desbloquear(ws, editables)
    ws.protection.sheet = True
    if permitir_orden:
        ws.protection.sort = False
        ws.protection.autoFilter = False
