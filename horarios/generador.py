"""Orquestador: carga config → construye el workbook → guarda el .xlsx."""
import datetime
from pathlib import Path

from openpyxl import Workbook

from comun.portada import NOMBRE_HOJA as HOJA_PORTADA, construir_portada
from horarios.config import cargar_facultad, cargar_horarios
from horarios.hoja_datos import construir_hoja_datos
from horarios.hoja_grupo import construir_hoja_grupo
from horarios.hoja_aulas import NOMBRE_HOJA as HOJA_AULAS, construir_hoja_aulas


def _indice(nombres_grupo) -> tuple:
    """Que hay en cada hoja y si se escribe a mano, para el indice de la portada.

    Las hojas de grupo se listan con el nombre con el que se crearon, no con una
    copia de los ids. `Datos` no aparece: esta oculta y solo es fontaneria.
    """
    return (
        *((nombre, "Horario semanal del grupo", True) for nombre in nombres_grupo),
        (HOJA_AULAS, "Qué aula esta ocupada en cada dia y turno", False),
    )


def _subtitulo(facultad) -> str:
    """Resumen de tamano del libro: el dominio de horarios no tiene nombre de
    facultad ni curso que poner aqui, asi que se dice cuanto abarca."""
    grupos, aulas = len(facultad.grupos), len(facultad.aulas)
    return (f"{grupos} grupo{'s' if grupos != 1 else ''} · "
            f"{aulas} aula{'s' if aulas != 1 else ''}")


def generar(
    config_path: Path,
    horarios_path: Path | None,
    salida: Path,
    generado: datetime.datetime | None = None,
) -> Path:
    """Carga la configuración, construye el workbook (Portada + Datos + grupos +
    Aulas) y guarda en salida.

    `generado` es la fecha que muestra la portada; se puede fijar desde los tests
    para que la salida no dependa del reloj.
    """
    generado = generado or datetime.datetime.now()
    facultad = cargar_facultad(config_path)
    horarios = cargar_horarios(horarios_path, facultad)

    wb = Workbook()
    # Elimina la hoja por defecto; se crearán las nuestras.
    wb.remove(wb.active)

    # Hoja Datos primero (define AulasValidas y firmas que otras hojas usan).
    firmas = construir_hoja_datos(wb, facultad)

    # Una hoja por grupo.
    nombres_grupo = []
    for grupo in facultad.grupos:
        ws = wb.create_sheet(grupo.id)
        construir_hoja_grupo(ws, grupo, facultad, horario=horarios.get(grupo.id))
        nombres_grupo.append(ws.title)

    # Hoja Aulas (usa las firmas; se inserta en índice 0).
    construir_hoja_aulas(wb, facultad, firmas)

    # La portada va la última porque se inserta en el índice 0: así ya sabe qué
    # hojas existen y queda delante de todas.
    construir_portada(
        wb,
        titulo="Horario de la facultad",
        subtitulo=_subtitulo(facultad),
        origen=str(config_path),
        hojas=_indice(nombres_grupo),
        generado=generado,
    )
    # El libro abre por la portada: si abriera por otra hoja nadie la leería.
    wb.active = wb[HOJA_PORTADA]

    wb.save(salida)
    return salida
