"""Orquestador: carga config -> construye el workbook -> guarda el .xlsx."""
from pathlib import Path
from openpyxl import Workbook

from tribunales.config import cargar_facultad, cargar_asignaciones
from tribunales.hoja_datos import construir_hoja_datos
from tribunales.hoja_dia import construir_hoja_dia
from tribunales.hoja_localizar import construir_hoja_localizar


def generar(config_path: Path, asignaciones_path, salida: Path) -> Path:
    """Carga configuracion y asignaciones, construye el workbook (Datos + una
    hoja por dia + Localizar) y guarda en `salida`."""
    facultad = cargar_facultad(config_path)
    asignaciones = cargar_asignaciones(asignaciones_path, facultad)

    wb = Workbook()
    wb.remove(wb.active)

    # Datos primero: define rangos nombrados que usan las hojas de dia.
    construir_hoja_datos(wb, facultad)
    for dia in facultad.dias:
        ws = wb.create_sheet(dia.fecha)
        construir_hoja_dia(ws, dia, facultad, asignaciones=asignaciones)
    construir_hoja_localizar(wb, facultad)

    wb.save(salida)
    return salida
