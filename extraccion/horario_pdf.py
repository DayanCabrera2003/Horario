"""Convierte la transcripcion del horario del PDF de Gianni al facultad.yaml y
horarios.yaml que consume el generador de horarios.

La transcripcion (celdas crudas leidas del PDF) se mantiene aparte, en un modulo
de datos; aqui va solo la logica pura: parsear cada celda, normalizar el aula,
componer el id de asignatura (con sufijo -C/-CP segun el tipo) y derivar la
frecuencia por conteo. Las anotaciones entre parentesis ('(con C211)', '(s. 1-8)')
se ignoran, como pidio Fernando.
"""
import re
from pathlib import Path

import yaml

DIAS = ("Lunes", "Martes", "Miércoles", "Jueves", "Viernes")


def quitar_anotaciones(texto: str) -> str:
    """Quita anotaciones entre parentesis y el asterisco de aula opcional."""
    return re.sub(r"\([^)]*\)", "", texto).replace("*", "").strip()


def normalizar_aula(crudo: str) -> str:
    """Normaliza el aula a una forma canonica, o "" si no se reconoce.

    'Aula 8' / '8' -> 'Aula 8'; 'Lab' -> 'Lab'; 'Lab2' -> 'Lab2';
    'SEDER' -> 'SEDER'. Fernando pidio esta 'magia': a veces el PDF escribe
    'Aula 4' y a veces solo '4'.
    """
    t = crudo.strip().rstrip("*").strip()
    if not t:
        return ""
    # 'Aula X': si X es un numero -> 'Aula N'; si es un nombre (Lab, SEDER) se
    # normaliza ese nombre ('Aula Lab' -> 'Lab').
    m = re.fullmatch(r"(?i)aula\s*(.+)", t)
    if m:
        interior = m.group(1).strip()
        return f"Aula {interior}" if interior.isdigit() else normalizar_aula(interior)
    if re.fullmatch(r"[0-9]+", t):
        return f"Aula {t}"
    if re.fullmatch(r"(?i)lab\s*[0-9]*", t):
        num = re.sub(r"(?i)lab\s*", "", t)
        return f"Lab{num}" if num else "Lab"
    if t.upper() == "SEDER":
        return "SEDER"
    # No se reconoce como aula (p. ej. resto de una celda con notacion rara): se
    # devuelve "" para que la celda quede como incidencia, no como un aula falsa.
    return ""


def id_asignatura(abrev: str, tipo: str) -> str:
    """Compone el id de la asignatura: la abreviatura, con sufijo -C (conferencia)
    o -CP (clase practica) segun el tipo marcado en la celda. Sin tipo, sin sufijo.
    Los espacios de la abreviatura ('AM I') se vuelven guiones ('AM-I')."""
    base = abrev.strip().replace(" ", "-")
    if tipo == "c":
        return f"{base}-C"
    if tipo == "cp":
        return f"{base}-CP"
    return base


def parsear_celda(crudo: str, abreviaturas) -> list:
    """Parsea una celda del grid en una lista de (id_asig, aula). Puede haber
    varias por division de semanas ('F Aula 7 (s. 1-8) / ICD Aula 7 (s. 9-16)').

    `abreviaturas` es el conjunto de abreviaturas validas de ese año (de la tabla
    de profesores); se usa para separar la abreviatura (que puede llevar espacios,
    'AM I') del resto (tipo + aula). Devuelve [] si la celda esta vacia o no se
    reconoce el aula.
    """
    if not crudo or not crudo.strip():
        return []
    salida = []
    # Solo se divide en ' / ' con espacios (division por semanas); un '/' pegado es
    # parte de la abreviatura ('SN/DN', 'c/s').
    for parte in re.split(r"\s+/\s+", crudo):
        limpio = quitar_anotaciones(parte)
        if not limpio:
            continue
        abrev = _match_abreviatura(limpio, abreviaturas)
        if abrev is None:
            continue
        resto = limpio[len(abrev):].strip()
        tipo, aula_cruda = _tipo_y_aula(resto)
        aula = normalizar_aula(aula_cruda)
        if not aula:
            continue
        salida.append((id_asignatura(abrev, tipo), aula))
    return salida


def _match_abreviatura(texto: str, abreviaturas):
    """Devuelve la abreviatura valida mas larga con la que empieza `texto`
    (para no cortar 'AM I' en 'AM'), o None."""
    candidatas = [a for a in abreviaturas if texto == a or texto.startswith(a + " ")]
    return max(candidatas, key=len) if candidatas else None


def _tipo_y_aula(resto: str) -> tuple:
    """Separa el tipo de clase ('c'/'cp') del resto (el aula). Tolera el tipo
    pegado al numero ('c6' -> 'c 6'). Sin marca de tipo, devuelve ("", resto)."""
    resto = re.sub(r"(?i)^(cp|c)(\d)", r"\1 \2", resto)   # 'c6' -> 'c 6'
    m = re.match(r"(?i)(cp|c)\s+(.+)", resto)
    if m:
        return m.group(1).lower(), m.group(2).strip()
    return "", resto


def construir(grupos: dict, tablas: dict) -> dict:
    """Construye las estructuras del YAML a partir de la transcripcion.

    - `grupos`: {grupo_id: {turno:int -> {dia -> celda cruda}}}.
    - `tablas`: {(carrera, anio): {abrev -> nombre}} con las asignaturas de cada
      año (de las tablas de profesores del PDF).

    Devuelve {"facultad": {...}, "horarios": {...}, "incidencias": [...]}. La
    frecuencia de cada asignatura se cuenta sobre las celdas planificadas.
    """
    from collections import defaultdict, Counter

    aulas = set()
    incidencias = []
    horarios = {}
    # conteo de asignaturas por (carrera, anio): id -> nº de apariciones
    frecuencias = defaultdict(Counter)
    max_turno = 0

    for grupo_id, rejilla in grupos.items():
        carrera, anio = grupo_id[0], int(grupo_id[1])
        abreviaturas = set(tablas.get((carrera, anio), {}))
        celdas = {}
        for turno, dias in rejilla.items():
            max_turno = max(max_turno, turno)
            for dia, crudo in dias.items():
                parsed = parsear_celda(crudo, abreviaturas)
                if crudo and crudo.strip() and not parsed:
                    incidencias.append(f"{grupo_id} {dia} T{turno}: sin parsear {crudo!r}")
                if not parsed:
                    continue
                id_asig, aula = parsed[0]
                if len(parsed) > 1:
                    otras = ", ".join(f"{a}@{u}" for a, u in parsed[1:])
                    incidencias.append(
                        f"{grupo_id} {dia} T{turno}: celda multiple, se toma la 1a "
                        f"({id_asig}@{aula}); se omiten: {otras}")
                celdas[(dia, turno)] = {"asig": id_asig, "aula": aula}
                aulas.add(aula)
                frecuencias[(carrera, anio)][id_asig] += 1
        if celdas:
            horarios[grupo_id] = celdas

    facultad = _construir_facultad(grupos, frecuencias, tablas, aulas, max_turno)
    horarios_yaml = _horarios_a_yaml(horarios)
    return {"facultad": facultad, "horarios": horarios_yaml, "incidencias": incidencias}


def _nombre_de_id(id_asig: str, tabla: dict) -> str:
    """Recupera el nombre legible de un id de asignatura probando los sufijos de
    tipo (sin sufijo, -C, -CP), ya que a partir del id solo no se puede distinguir
    'AM-I' (abreviatura 'AM I') de un sufijo de tipo."""
    for abrev, nombre in tabla.items():
        if id_asig in (id_asignatura(abrev, ""), id_asignatura(abrev, "c"),
                       id_asignatura(abrev, "cp")):
            return nombre
    return id_asig


def _construir_facultad(grupos, frecuencias, tablas, aulas, turnos) -> dict:
    """Arma el dict de facultad.yaml: aulas, dias, turnos y carreras/años con sus
    asignaturas (id, nombre, frecuencia) y sesiones (grupos)."""
    from collections import defaultdict

    # sesiones por (carrera, anio): sesion -> set de numeros de grupo
    sesiones = defaultdict(lambda: defaultdict(set))
    for grupo_id in grupos:
        carrera, anio, sesion, numero = grupo_id[0], int(grupo_id[1]), int(grupo_id[2]), int(grupo_id[3])
        sesiones[(carrera, anio)][sesion].add(numero)

    carreras = defaultdict(lambda: {"años": {}})
    claves = sorted(set(list(frecuencias) + list(sesiones)))
    for (carrera, anio) in claves:
        tabla = tablas.get((carrera, anio), {})
        asignaturas = [
            {"id": aid, "nombre": _nombre_de_id(aid, tabla), "frecuencia": frec}
            for aid, frec in sorted(frecuencias[(carrera, anio)].items())
        ]
        ses = {s: {"grupos": sorted(nums)} for s, nums in sorted(sesiones[(carrera, anio)].items())}
        carreras[carrera]["años"][anio] = {"asignaturas": asignaturas, "sesiones": ses}

    return {
        "turnos": turnos,
        "dias": list(DIAS),
        "aulas": sorted(aulas, key=_orden_aula),
        "carreras": {c: carreras[c] for c in sorted(carreras)},
    }


def _orden_aula(aula: str):
    """Ordena aulas: primero 'Aula N' por numero, luego el resto alfabetico."""
    m = re.fullmatch(r"Aula (\d+)", aula)
    return (0, int(m.group(1)), "") if m else (1, 0, aula)


def _horarios_a_yaml(horarios) -> dict:
    """Convierte {grupo_id: {(dia,turno): celda}} a {grupo_id: {dia: {turno: celda}}}."""
    salida = {}
    for grupo_id, celdas in horarios.items():
        por_dia = {}
        for (dia, turno), celda in celdas.items():
            por_dia.setdefault(dia, {})[turno] = celda
        # ordena dias segun DIAS y turnos ascendentes
        salida[grupo_id] = {
            dia: {t: por_dia[dia][t] for t in sorted(por_dia[dia])}
            for dia in DIAS if dia in por_dia
        }
    return salida


def escribir_yaml(datos: dict, ruta_facultad, ruta_horarios) -> None:
    """Escribe facultad.yaml y horarios.yaml a partir de `datos` (salida de
    `construir`)."""
    Path(ruta_facultad).write_text(
        yaml.safe_dump(datos["facultad"], sort_keys=False, allow_unicode=True,
                       default_flow_style=False),
        encoding="utf-8")
    Path(ruta_horarios).write_text(
        yaml.safe_dump(datos["horarios"], sort_keys=False, allow_unicode=True,
                       default_flow_style=False),
        encoding="utf-8")


def escribir_incidencias(datos: dict, ruta) -> None:
    """Escribe el informe de incidencias (celdas no parseadas, celdas multiples)
    para revisar la transcripcion a mano."""
    incidencias = datos["incidencias"]
    lineas = ["# Incidencias de la importacion del horario (PDF)", "",
              f"Total: {len(incidencias)}", ""]
    lineas.extend(f"- {inc}" for inc in incidencias)
    lineas.append("")
    Path(ruta).write_text("\n".join(lineas), encoding="utf-8")
