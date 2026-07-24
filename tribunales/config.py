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
