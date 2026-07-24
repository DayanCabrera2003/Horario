from pathlib import Path
import yaml
from tribunales.modelo import (
    Profesor, Estudiante, Local, Momento, Dia, Tesis, Asignacion, Facultad,
)


class ErrorConfig(Exception):
    pass


def _lista(datos, clave):
    valor = datos.get(clave)
    if not valor:
        raise ErrorConfig(f"'{clave}' no puede estar vacio")
    return valor


def cargar_facultad(ruta) -> Facultad:
    datos = yaml.safe_load(Path(ruta).read_text(encoding="utf-8"))
    if not isinstance(datos, dict):
        raise ErrorConfig("El YAML raiz debe ser un diccionario")

    profesores = tuple(
        Profesor(id=p["id"], nombre=p["nombre"], grado=p.get("grado", ""))
        for p in _lista(datos, "profesores")
    )
    estudiantes = tuple(
        Estudiante(id=e["id"], nombre=e["nombre"])
        for e in _lista(datos, "estudiantes")
    )
    locales = tuple(
        Local(id=l["id"], nombre=l["nombre"]) for l in _lista(datos, "locales")
    )

    dias = []
    for d in _lista(datos, "dias"):
        momentos = tuple(
            Momento(inicio=str(m["inicio"]), fin=str(m["fin"]))
            for m in (d.get("momentos") or [])
        )
        if not momentos:
            raise ErrorConfig(f"dia {d.get('fecha')}: faltan 'momentos'")
        dias.append(Dia(fecha=str(d["fecha"]), momentos=momentos))
    dias = tuple(dias)

    ids_prof = {p.id for p in profesores}
    ids_est = {e.id for e in estudiantes}
    tesis = []
    for t in _lista(datos, "tesis"):
        if t["estudiante"] not in ids_est:
            raise ErrorConfig(f"tesis: estudiante inexistente '{t['estudiante']}'")
        for rol in ("tutor", "oponente", "presidente", "secretario"):
            if t[rol] not in ids_prof:
                raise ErrorConfig(f"tesis {t['estudiante']}: {rol} inexistente '{t[rol]}'")
        tesis.append(Tesis(
            estudiante=t["estudiante"], tutor=t["tutor"], oponente=t["oponente"],
            presidente=t["presidente"], secretario=t["secretario"],
        ))

    return Facultad(
        profesores=profesores, estudiantes=estudiantes, locales=locales,
        dias=dias, tesis=tuple(tesis),
    )


def cargar_asignaciones(ruta, facultad: Facultad) -> tuple:
    """Devuelve tuple[Asignacion]. Valida estudiante, local, fecha y momento."""
    if ruta is None:
        return ()
    datos = yaml.safe_load(Path(ruta).read_text(encoding="utf-8")) or []
    ids_est = {e.id for e in facultad.estudiantes}
    ids_local = {l.id for l in facultad.locales}
    # {fecha: {momento_id}}
    momentos_por_fecha = {d.fecha: {m.id for m in d.momentos} for d in facultad.dias}

    asignaciones = []
    for a in datos:
        est, local = a["estudiante"], a["local"]
        fecha, momento = str(a["fecha"]), str(a["momento"])
        if est not in ids_est:
            raise ErrorConfig(f"asignacion: estudiante inexistente '{est}'")
        if local not in ids_local:
            raise ErrorConfig(f"asignacion: local inexistente '{local}'")
        if fecha not in momentos_por_fecha:
            raise ErrorConfig(f"asignacion: fecha inexistente '{fecha}'")
        if momento not in momentos_por_fecha[fecha]:
            raise ErrorConfig(f"asignacion {fecha}: momento inexistente '{momento}'")
        asignaciones.append(Asignacion(estudiante=est, local=local, fecha=fecha, momento=momento))
    return tuple(asignaciones)
