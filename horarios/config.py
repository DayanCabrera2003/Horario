from pathlib import Path
import yaml
from comun.validacion import es_entero
from horarios.modelo import (
    Asignatura, Grupo, Anio, Asignacion, Horario, Facultad, Profesor, Docencia,
)


class ErrorConfig(Exception):
    pass


def cargar_facultad(ruta) -> Facultad:
    datos = yaml.safe_load(Path(ruta).read_text(encoding="utf-8"))
    if not isinstance(datos, dict):
        raise ErrorConfig("El YAML raíz debe ser un diccionario")

    turnos = datos.get("turnos")
    if not es_entero(turnos) or turnos < 1:
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

    profesores = _cargar_profesores(datos)
    docencia = _cargar_docencia(datos, grupos, anios, profesores)

    return Facultad(
        aulas=aulas, dias=dias, turnos=turnos,
        grupos=tuple(grupos), anios=anios,
        profesores=profesores, docencia=docencia,
    )


def _cargar_profesores(datos) -> tuple:
    """Lee la seccion 'profesores'. Es opcional: sin ella la facultad se
    describe igual, que es como estaban todos los YAML antes de la fase 2."""
    profesores = []
    vistos = set()
    for p in datos.get("profesores") or ():
        pid = p["id"]
        if pid in vistos:
            raise ErrorConfig(f"profesores: id duplicado '{pid}'")
        vistos.add(pid)
        tope = p.get("tope_turnos")
        if tope is not None and (not es_entero(tope) or tope <= 0):
            raise ErrorConfig(
                f"profesor {pid}: 'tope_turnos' debe ser un entero positivo")
        profesores.append(Profesor(id=pid, nombre=p["nombre"],
                                   grado=p.get("grado", ""), tope_turnos=tope))
    return tuple(profesores)


def _cargar_docencia(datos, grupos, anios, profesores) -> tuple:
    """Lee la seccion 'docencia': {grupo: {asignatura: profesor}}.

    Valida las tres referencias. La de la asignatura se comprueba contra las del
    **ano del grupo**, no contra todas: asignarle a un grupo de primero algo que
    solo existe en cuarto es el error que esta validacion existe para cazar.
    """
    ids_prof = {p.id for p in profesores}
    grupo_por_id = {g.id: g for g in grupos}
    docencia = []
    for grupo_id, asignaturas in (datos.get("docencia") or {}).items():
        if grupo_id not in grupo_por_id:
            raise ErrorConfig(f"docencia: grupo inexistente '{grupo_id}'")
        del_anio = {a.id for a in anios[grupo_por_id[grupo_id].anio_codigo].asignaturas}
        for asig_id, profesor_id in (asignaturas or {}).items():
            if asig_id not in del_anio:
                raise ErrorConfig(
                    f"docencia {grupo_id}: asignatura '{asig_id}' no es de su año")
            if profesor_id not in ids_prof:
                raise ErrorConfig(
                    f"docencia {grupo_id}/{asig_id}: profesor inexistente '{profesor_id}'")
            docencia.append(Docencia(grupo=grupo_id, asignatura=asig_id,
                                     profesor=profesor_id))
    return tuple(docencia)


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
