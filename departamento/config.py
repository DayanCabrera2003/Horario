"""Carga y validacion del YAML de gestion del departamento.

Devuelve el modelo de dominio ya validado; cualquier inconsistencia se informa
como ErrorConfig con un mensaje que ubica el problema (id de la entidad).
"""
from pathlib import Path

import yaml

from comun.validacion import es_entero
from departamento.modelo import Profesor, Asignatura, Departamento

FILAS_POR_PROFESOR_DEFECTO = 10


class ErrorConfig(Exception):
    pass


def _lista(datos, clave):
    valor = datos.get(clave)
    if not valor:
        raise ErrorConfig(f"'{clave}' no puede estar vacio")
    return valor


def _campo(d, clave, contexto):
    if clave not in d or d[clave] is None:
        raise ErrorConfig(f"{contexto}: falta '{clave}'")
    return d[clave]


def _tope(d, contexto):
    """Lee un 'tope_horas' opcional; si aparece debe ser un entero positivo."""
    tope = d.get("tope_horas")
    if tope is None:
        return None
    if not es_entero(tope) or tope <= 0:
        raise ErrorConfig(f"{contexto}: 'tope_horas' debe ser un entero positivo")
    return tope


def _sin_duplicados(ids, contexto):
    vistos = set()
    for i in ids:
        if i in vistos:
            raise ErrorConfig(f"{contexto}: id duplicado '{i}'")
        vistos.add(i)


def _cargar_asignatura(a) -> Asignatura:
    ctx = f"asignatura {a.get('id', '?')}"
    horas_conf = _campo(a, "horas_conf", ctx)
    horas_cp = _campo(a, "horas_cp", ctx)
    grupos_cp = _campo(a, "grupos_cp", ctx)
    for clave, valor in (("horas_conf", horas_conf), ("horas_cp", horas_cp),
                         ("grupos_cp", grupos_cp)):
        if not es_entero(valor) or valor < 0:
            # El mensaje cubre las tres formas de fallar (negativo, texto y
            # booleano), no solo el signo: en YAML 'no' se lee como False.
            raise ErrorConfig(f"{ctx}: '{clave}' debe ser un entero no negativo")
    if grupos_cp and not horas_cp:
        raise ErrorConfig(f"{ctx}: hay grupos de CP pero 'horas_cp' es 0")
    if not horas_conf and not grupos_cp:
        raise ErrorConfig(f"{ctx}: sin carga (ni Conf ni grupos de CP)")
    return Asignatura(id=_campo(a, "id", ctx), nombre=_campo(a, "nombre", ctx),
                      carrera=_campo(a, "carrera", ctx), horas_conf=horas_conf,
                      horas_cp=horas_cp, grupos_cp=grupos_cp)


def cargar_departamento(ruta) -> Departamento:
    datos = yaml.safe_load(Path(ruta).read_text(encoding="utf-8"))
    if not isinstance(datos, dict):
        raise ErrorConfig("El YAML raiz debe ser un diccionario")

    cabecera = datos.get("departamento") or {}
    nombre = _campo(cabecera, "nombre", "departamento")
    semestre = str(_campo(cabecera, "semestre", "departamento"))
    tope = _tope(cabecera, "departamento")
    filas_prof = cabecera.get("filas_por_profesor", FILAS_POR_PROFESOR_DEFECTO)
    if not es_entero(filas_prof) or filas_prof <= 0:
        raise ErrorConfig("departamento: 'filas_por_profesor' debe ser un entero positivo")

    profesores = tuple(
        Profesor(id=_campo(p, "id", "profesor"), nombre=_campo(p, "nombre", "profesor"),
                 grado=p.get("grado", ""), tope_horas=_tope(p, f"profesor {p.get('id', '?')}"))
        for p in _lista(datos, "profesores")
    )
    _sin_duplicados([p.id for p in profesores], "profesores")

    asignaturas = tuple(_cargar_asignatura(a) for a in _lista(datos, "asignaturas"))
    _sin_duplicados([a.id for a in asignaturas], "asignaturas")

    return Departamento(nombre=nombre, semestre=semestre, tope_horas=tope,
                        filas_por_profesor=filas_prof, profesores=profesores,
                        asignaturas=asignaturas)
