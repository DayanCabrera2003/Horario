"""Orquestador: carga config → construye el workbook → guarda el .xlsx."""
from pathlib import Path

from openpyxl import Workbook

from horarios.config import cargar_facultad, cargar_horarios
from horarios.hoja_datos import construir_hoja_datos
from horarios.hoja_grupo import construir_hoja_grupo
from horarios.hoja_aulas import construir_hoja_aulas


def generar(
    config_path: Path,
    horarios_path: Path | None,
    salida: Path,
) -> Path:
    """Carga la configuración, construye el workbook (Datos + grupos + Aulas) y guarda en salida."""
    facultad = cargar_facultad(config_path)
    horarios = cargar_horarios(horarios_path, facultad)

    wb = Workbook()
    # Elimina la hoja por defecto; se crearán las nuestras.
    wb.remove(wb.active)

    # Hoja Datos primero (define AulasValidas y firmas que otras hojas usan).
    firmas = construir_hoja_datos(wb, facultad)

    # Una hoja por grupo.
    for grupo in facultad.grupos:
        ws = wb.create_sheet(grupo.id)
        construir_hoja_grupo(ws, grupo, facultad, horario=horarios.get(grupo.id))

    # Hoja Aulas (usa las firmas; se inserta en índice 0).
    construir_hoja_aulas(wb, facultad, firmas)

    wb.save(salida)
    return salida
