"""Orquestador: carga config -> construye el workbook -> guarda el .xlsx."""
from pathlib import Path

from openpyxl import Workbook

from departamento.config import cargar_departamento
from departamento.hoja_datos import construir_hoja_datos
from departamento.hoja_asignacion import construir_hoja_asignacion
from departamento.hoja_profesores import construir_hoja_profesores
from departamento.hoja_asignaturas import construir_hoja_asignaturas


def generar(config_path: Path, salida: Path) -> Path:
    """Carga la configuracion del departamento, construye el workbook
    (Asignacion + Profesores + Asignaturas + Datos oculta) y lo guarda."""
    depto = cargar_departamento(config_path)

    wb = Workbook()
    wb.remove(wb.active)

    # Datos primero: define los rangos nombrados que usan las demas hojas.
    construir_hoja_datos(wb, depto)
    construir_hoja_asignacion(wb, depto)
    construir_hoja_profesores(wb, depto)
    construir_hoja_asignaturas(wb, depto)

    # Datos al final y Asignacion como primera hoja visible y activa.
    wb.move_sheet("Datos", offset=len(wb.sheetnames) - 1)
    wb.active = wb["Asignación"]

    wb.save(salida)
    return salida
