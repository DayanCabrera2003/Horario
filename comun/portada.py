"""Hoja de portada: la primera de cada libro.

Dice de donde salio el libro, cuando, que hay en cada hoja y que hacer para
cambiar los datos. Existe porque el tutor tuvo que preguntar donde se entraban
los datos de la docencia: el libro no lo decia por ninguna parte.

La fecha de generacion se inyecta en vez de leerse del reloj para que la salida
sea reproducible y los tests puedan fijarla.
"""
import datetime

from openpyxl.utils import quote_sheetname
from openpyxl.worksheet.hyperlink import Hyperlink

from comun import formato, proteccion, vista

NOMBRE_HOJA = "Portada"

_FILA_TITULO = 2
_FILA_ORIGEN = 4
_FILA_INSTRUCCIONES = 7
_FILA_INDICE = 11

# Etiquetas del indice. Son tres y no dos porque una hoja de listado no es
# ninguna de las dos cosas de antes: no se calcula sola, pero tampoco es donde se
# planifica. Es donde estan los datos del problema, que es exactamente lo que el
# tutor no encontraba.
SE_ESCRIBE = "se escribe"
SE_CALCULA = "se calcula"
SON_DATOS = "datos del problema"

_INSTRUCCIONES = (
    "Las casillas de fondo blanco se escriben a mano. Las demás se calculan "
    "solas y están bloqueadas: si necesitas tocarlas, quita la protección de "
    "la hoja desde el menú de Excel o de Calc."
)


def _enlazar_a_hoja(celda, nombre: str) -> None:
    """Convierte `celda` en un salto a la celda A1 de la hoja `nombre`.

    Se construye un Hyperlink con `location` en vez de asignar la cadena
    "#'Hoja'!A1" a `celda.hyperlink`: esa forma abreviada la guarda openpyxl
    como relacion externa (TargetMode="External"), que no es lo que es un salto
    dentro del mismo libro. `location` produce el enlace interno del formato.
    """
    celda.hyperlink = Hyperlink(ref=celda.coordinate,
                                location=f"{quote_sheetname(nombre)}!A1")


def construir_portada(wb, titulo: str, subtitulo: str, origen: str,
                      hojas, generado: datetime.datetime,
                      instrucciones: str = _INSTRUCCIONES) -> None:
    """Crea la hoja Portada como primera del libro.

    `hojas` es un iterable de (nombre, descripcion, etiqueta) en el orden en que
    se quieren listar; `etiqueta` es una de SE_ESCRIBE, SE_CALCULA o SON_DATOS.
    `generado` se pasa siempre de forma explicita.
    """
    ws = wb.create_sheet(NOMBRE_HOJA, index=0)

    ws[f"A{_FILA_TITULO}"] = titulo
    ws[f"A{_FILA_TITULO + 1}"] = subtitulo

    ws[f"A{_FILA_ORIGEN}"] = "Generado desde"
    ws[f"B{_FILA_ORIGEN}"] = origen
    ws[f"A{_FILA_ORIGEN + 1}"] = "Fecha"
    ws[f"B{_FILA_ORIGEN + 1}"] = generado.strftime("%d/%m/%Y %H:%M")

    ws[f"A{_FILA_INSTRUCCIONES}"] = "Donde se cambian los datos"
    ws[f"A{_FILA_INSTRUCCIONES + 1}"] = instrucciones

    ws[f"A{_FILA_INDICE}"] = "Las hojas de este libro"
    for i, (nombre, descripcion, etiqueta) in enumerate(hojas):
        fila = _FILA_INDICE + 1 + i
        celda = ws[f"A{fila}"]
        celda.value = nombre
        _enlazar_a_hoja(celda, nombre)
        ws[f"B{fila}"] = descripcion
        ws[f"C{fila}"] = etiqueta

    formato.autoajustar_columnas(ws, extra=4)
    vista.ocultar_cuadricula(ws)
    # La portada no tiene nada que editar.
    proteccion.proteger_hoja(ws)
