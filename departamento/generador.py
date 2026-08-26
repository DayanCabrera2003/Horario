"""Orquestador: carga config -> construye el workbook -> guarda el .xlsx."""
import datetime
from pathlib import Path

from openpyxl import Workbook

from comun.portada import NOMBRE_HOJA as HOJA_PORTADA, construir_portada
from departamento.config import cargar_departamento
from departamento.hoja_datos import construir_hoja_datos
from departamento.hoja_asignacion import construir_hoja_asignacion
from departamento.hoja_profesores import construir_hoja_profesores
from departamento.hoja_asignaturas import construir_hoja_asignaturas


# Que hay en cada hoja y si se escribe a mano, para el indice de la portada.
# `Datos` no aparece: esta oculta y solo es fontaneria de formulas.
_HOJAS_INDICE = (
    ("Asignación", "Quién imparte cada conferencia y cada grupo de CP", True),
    ("Profesores", "Cuántas horas acumula cada uno y si pasa su tope", False),
    ("Asignaturas", "Quién cubre cada fila de carga y qué falta", False),
)


def generar(config_path: Path, salida: Path,
            generado: datetime.datetime | None = None) -> Path:
    """Carga la configuracion del departamento, construye el workbook
    (Portada + Asignacion + Profesores + Asignaturas + Datos oculta) y lo guarda.

    `generado` es la fecha que muestra la portada. Se resuelve una sola vez aqui
    para que las dos hojas que la usaran nunca discrepen, y se puede fijar desde
    los tests para que la salida no dependa del reloj.
    """
    generado = generado or datetime.datetime.now()
    depto = cargar_departamento(config_path)

    wb = Workbook()
    wb.remove(wb.active)

    # Datos primero: define los rangos nombrados que usan las demas hojas.
    construir_hoja_datos(wb, depto)
    construir_hoja_asignacion(wb, depto)
    construir_hoja_profesores(wb, depto)
    construir_hoja_asignaturas(wb, depto)

    # Datos al final del todo.
    wb.move_sheet("Datos", offset=len(wb.sheetnames) - 1)

    # La portada va la ultima porque se inserta en el indice 0: asi ya sabe que
    # hojas existen y queda delante de todas.
    construir_portada(
        wb,
        titulo="Gestión del departamento",
        subtitulo=f"{depto.nombre} · Semestre {depto.semestre}",
        origen=str(config_path),
        hojas=_HOJAS_INDICE,
        generado=generado,
    )
    # El libro abre por la portada: si abriera por otra hoja nadie la leeria.
    wb.active = wb[HOJA_PORTADA]

    wb.save(salida)
    return salida
