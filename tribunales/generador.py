"""Orquestador: carga config -> construye el workbook -> guarda el .xlsx."""
import datetime
from pathlib import Path
from openpyxl import Workbook

from comun.portada import NOMBRE_HOJA as HOJA_PORTADA, construir_portada
from tribunales.config import cargar_facultad, cargar_asignaciones
from tribunales.hoja_datos import construir_hoja_datos
from tribunales.hoja_tribunales import construir_hoja_tribunales
from tribunales.hoja_dia import construir_hoja_dia
from tribunales.hoja_localizar import construir_hoja_localizar


def _indice(nombres_dia) -> tuple:
    """Que hay en cada hoja y si se escribe a mano, para el indice de la portada.

    Las hojas de dia se listan con el nombre con el que se crearon, no con una
    copia de las fechas: la tarea de renombrarlas no puede dejar el indice atras.
    `Datos` no aparece: esta oculta y solo es fontaneria de formulas.
    """
    return (
        ("Tribunales", "Quién forma el tribunal de cada tesis", False),
        *((nombre, "Dónde y cuándo defiende cada estudiante", True)
          for nombre in nombres_dia),
        ("Localizar", "Escribe un nombre y dice en qué momentos participa", True),
    )


def _subtitulo(facultad) -> str:
    """Resumen de tamano del libro. El dominio de tesis no tiene ni nombre de
    departamento ni semestre que poner aqui, asi que se dice cuanto abarca."""
    dias = len(facultad.dias)
    return f"{len(facultad.tesis)} tesis · {dias} día{'s' if dias != 1 else ''}"


def generar(config_path: Path, asignaciones_path, salida: Path,
            generado: datetime.datetime | None = None) -> Path:
    """Carga configuracion y asignaciones, construye el workbook (Portada +
    Datos + Tribunales + una hoja por dia + Localizar) y guarda en `salida`.

    `generado` es la fecha que muestra la portada; se puede fijar desde los
    tests para que la salida no dependa del reloj.
    """
    generado = generado or datetime.datetime.now()
    facultad = cargar_facultad(config_path)
    asignaciones = cargar_asignaciones(asignaciones_path, facultad)

    wb = Workbook()
    wb.remove(wb.active)

    # Datos primero: define rangos nombrados que usan las hojas de dia.
    construir_hoja_datos(wb, facultad)
    # Tribunales: vista legible (nombres) y primera hoja visible del libro.
    construir_hoja_tribunales(wb, facultad)
    nombres_dia = []
    for dia in facultad.dias:
        ws = wb.create_sheet(dia.nombre_hoja)
        construir_hoja_dia(ws, dia, facultad, asignaciones=asignaciones)
        nombres_dia.append(ws.title)
    construir_hoja_localizar(wb, facultad)

    # La portada va la ultima porque se inserta en el indice 0: asi ya sabe que
    # hojas existen y queda delante de todas.
    construir_portada(
        wb,
        titulo="Tribunales de tesis",
        subtitulo=_subtitulo(facultad),
        origen=str(config_path),
        hojas=_indice(nombres_dia),
        generado=generado,
    )
    # El libro abre por la portada: si abriera por otra hoja nadie la leeria.
    wb.active = wb[HOJA_PORTADA]

    wb.save(salida)
    return salida
