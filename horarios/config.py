from pathlib import Path
import yaml
from horarios.modelo import Asignatura, Grupo, Anio, Asignacion, Horario, Facultad


class ErrorConfig(Exception):
    pass


def cargar_facultad(ruta) -> Facultad:
    datos = yaml.safe_load(Path(ruta).read_text(encoding="utf-8"))
    if not isinstance(datos, dict):
        raise ErrorConfig("El YAML raíz debe ser un diccionario")

    turnos = datos.get("turnos")
    if not isinstance(turnos, int) or turnos < 1:
        raise ErrorConfig("'turnos' debe ser un entero >= 1")

    aulas = tuple(datos.get("aulas") or ())
    dias = tuple(datos.get("dias") or ())
    if not aulas:
        raise ErrorConfig("'aulas' no puede estar vacío")
    if not dias:
        raise ErrorConfig("'dias' no puede estar vacío")

    grupos = []
    anios = {}
    carreras = datos.get("carreras") or {}
    for carrera, cdata in carreras.items():
        for anio_num, adata in (cdata.get("años") or {}).items():
            asigs_raw = adata.get("asignaturas")
            if not asigs_raw:
                raise ErrorConfig(f"{carrera}{anio_num}: faltan 'asignaturas'")
            asignaturas = tuple(
                Asignatura(id=a["id"], nombre=a["nombre"], frecuencia=int(a["frecuencia"]))
                for a in asigs_raw
            )
            anios[f"{carrera}{anio_num}"] = Anio(
                carrera=carrera, numero=int(anio_num), asignaturas=asignaturas
            )
            for sesion, sdata in (adata.get("sesiones") or {}).items():
                for numero in sdata.get("grupos") or []:
                    grupos.append(Grupo(
                        carrera=carrera, anio=int(anio_num),
                        sesion=int(sesion), numero=int(numero),
                    ))

    if not grupos:
        raise ErrorConfig("No se derivó ningún grupo de la configuración")

    return Facultad(
        aulas=aulas, dias=dias, turnos=turnos,
        grupos=tuple(grupos), anios=anios,
    )


def cargar_horarios(ruta, facultad: Facultad) -> dict:
    """Devuelve {grupo_id: Horario}. Valida aulas y asignaturas referenciadas."""
    if ruta is None:
        return {}
    datos = yaml.safe_load(Path(ruta).read_text(encoding="utf-8")) or {}
    ids_validos = {g.id for g in facultad.grupos}
    horarios = {}
    for grupo_id, dias in datos.items():
        if grupo_id not in ids_validos:
            raise ErrorConfig(f"Horario para grupo inexistente: {grupo_id}")
        h = Horario(grupo_id=grupo_id)
        for dia, turnos in (dias or {}).items():
            if dia not in facultad.dias:
                raise ErrorConfig(f"{grupo_id}: día desconocido '{dia}'")
            for turno, celda in (turnos or {}).items():
                turno = int(turno)
                if not (1 <= turno <= facultad.turnos):
                    raise ErrorConfig(f"{grupo_id}/{dia}: turno {turno} fuera de rango")
                if not isinstance(celda, dict) or "asig" not in celda or "aula" not in celda:
                    raise ErrorConfig(f"{grupo_id}/{dia}/{turno}: cada celda necesita 'asig' y 'aula'")
                aula = celda["aula"]
                if aula not in facultad.aulas:
                    raise ErrorConfig(f"{grupo_id}/{dia}/{turno}: aula '{aula}' no existe")
                h.celdas[(dia, turno)] = Asignacion(asig=celda["asig"], aula=aula)
        horarios[grupo_id] = h
    return horarios
