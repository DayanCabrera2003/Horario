"""Modelo de dominio de la gestion del departamento.

La unidad central es la "fila de carga": cada asignatura se expande a una fila
de conferencia (si tiene horas de Conf) mas una fila por cada grupo de clase
practica. Cada fila la imparte exactamente un profesor; esa decision se toma
dentro del Excel generado, no aqui.
"""
from dataclasses import dataclass


@dataclass(frozen=True)
class Profesor:
    id: str
    nombre: str
    grado: str
    # Tope de horas propio. None = usar el tope global del departamento.
    tope_horas: int | None = None


@dataclass(frozen=True)
class Asignatura:
    # Las horas de CP son POR GRUPO: cada grupo recibe el programa completo, asi
    # que `grupos_cp` grupos suponen `grupos_cp * horas_cp` horas de trabajo.
    id: str
    nombre: str
    carrera: str
    horas_conf: int
    horas_cp: int
    grupos_cp: int


@dataclass(frozen=True)
class FilaCarga:
    # Unidad minima asignable a un profesor: la Conf completa de una asignatura
    # o un grupo concreto de CP. `grupo` es None en las filas de conferencia.
    asignatura: Asignatura
    tipo: str          # "Conf" o "CP"
    grupo: int | None
    horas: int


def filas_de_carga(asignaturas: tuple) -> tuple:
    """Expande las asignaturas a sus filas de carga, en el orden declarado:
    primero la Conf (si existe), despues un grupo de CP por fila."""
    filas = []
    for a in asignaturas:
        if a.horas_conf:
            filas.append(FilaCarga(asignatura=a, tipo="Conf", grupo=None,
                                   horas=a.horas_conf))
        for g in range(1, a.grupos_cp + 1):
            filas.append(FilaCarga(asignatura=a, tipo="CP", grupo=g,
                                   horas=a.horas_cp))
    return tuple(filas)


@dataclass(frozen=True)
class Departamento:
    # Contenedor raiz: identidad del semestre, topes y las dos listas maestras.
    nombre: str
    semestre: str
    tope_horas: int | None        # tope global; None = sin alerta de sobrecarga
    filas_por_profesor: int       # filas reservadas por bloque en la hoja Profesores
    profesores: tuple             # tuple[Profesor]
    asignaturas: tuple            # tuple[Asignatura]

    def tope_efectivo(self, profesor: Profesor) -> int | None:
        """Tope de horas que aplica a `profesor`: el suyo propio si lo declara,
        el global del departamento en caso contrario."""
        return profesor.tope_horas if profesor.tope_horas is not None else self.tope_horas

    def filas(self) -> tuple:
        """Filas de carga de todas las asignaturas del departamento."""
        return filas_de_carga(self.asignaturas)
