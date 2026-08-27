"""Orquestador: carga config -> construye el workbook -> guarda el .xlsx."""
import datetime
from pathlib import Path

from openpyxl import Workbook

from comun.portada import (
    NOMBRE_HOJA as HOJA_PORTADA, SE_ESCRIBE, SE_CALCULA, SON_DATOS,
    construir_portada,
)
from departamento.config import cargar_departamento
from departamento.hoja_datos import (
    NOMBRE_HOJA as HOJA_AUXILIAR, construir_hoja_datos)
from departamento.hoja_asignacion import (
    NOMBRE_HOJA as HOJA_ASIGNACION, construir_hoja_asignacion)
from departamento.hoja_profesores import (
    NOMBRE_HOJA as HOJA_CLAUSTRO, construir_hoja_profesores)
from departamento.hoja_asignaturas import (
    NOMBRE_HOJA as HOJA_PLAN, construir_hoja_asignaturas)
from departamento.hoja_carga import (
    NOMBRE_HOJA as HOJA_CARGA, construir_hoja_carga)
from departamento.hoja_cobertura import (
    NOMBRE_HOJA as HOJA_COBERTURA, construir_hoja_cobertura)


# Que hay en cada hoja y si se escribe a mano, para el indice de la portada.
# `Datos` no aparece: esta oculta y solo es fontaneria de formulas.
_HOJAS_INDICE = (
    (HOJA_CLAUSTRO, "Los profesores del departamento, con su grado y su tope", SON_DATOS),
    (HOJA_PLAN, "Las asignaturas del semestre y sus horas", SON_DATOS),
    (HOJA_ASIGNACION, "Quién imparte cada conferencia y cada grupo de CP", SE_ESCRIBE),
    (HOJA_CARGA, "Cuántas horas acumula cada uno y si pasa su tope", SE_CALCULA),
    (HOJA_COBERTURA, "Quién cubre cada fila de carga y qué falta", SE_CALCULA),
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

    # La auxiliar primero: define los rangos nombrados que usan las demas hojas.
    construir_hoja_datos(wb, depto)
    # Los datos del problema (quienes son y que se imparte), antes que la hoja
    # donde se decide y que los reportes que se derivan de esa decision.
    construir_hoja_profesores(wb, depto)
    construir_hoja_asignaturas(wb, depto)
    construir_hoja_asignacion(wb, depto)
    construir_hoja_carga(wb, depto)
    construir_hoja_cobertura(wb, depto)

    # La hoja auxiliar, al final del todo.
    wb.move_sheet(HOJA_AUXILIAR, offset=len(wb.sheetnames) - 1)

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
