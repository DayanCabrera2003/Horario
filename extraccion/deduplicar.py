"""Deduplicador de personas: agrupa las variantes escritas del mismo nombre y les
asigna un id estable y legible. La fusion es conservadora (solo une formas muy
parecidas y con el mismo primer nombre) y deja constancia de cada fusion para que
un humano pueda revisarla, tal como se acordo."""
from collections import Counter
from difflib import SequenceMatcher

from extraccion.normalizar import (
    extraer_grado, quitar_anotaciones, quitar_acentos, clave_persona,
    normalizar_espacios,
)


class Deduplicador:
    """Acumula nombres crudos y los agrupa. Tras agregar todos, `resolver()`
    asigna ids y devuelve el mapa id -> info (nombre canonico, grado, variantes)."""

    def __init__(self, umbral: float = 0.90):
        # Cada grupo: {"clave", "primer": primer token, "variantes": Counter de
        # nombres sin grado, "grados": Counter}. El umbral controla la fusion difusa.
        self._grupos = []
        self._umbral = umbral

    def agregar(self, nombre_crudo: str):
        """Registra un nombre crudo y devuelve el indice de su grupo (o None si el
        nombre esta vacio tras limpiar)."""
        grado, resto = extraer_grado(quitar_anotaciones(nombre_crudo))
        clave = clave_persona(nombre_crudo)
        if not clave:
            return None
        idx = self._buscar(clave)
        if idx is None:
            idx = len(self._grupos)
            self._grupos.append({"clave": clave, "primer": clave.split(" ")[0],
                                 "variantes": Counter(), "grados": Counter()})
        self._grupos[idx]["variantes"][resto] += 1
        if grado:
            self._grupos[idx]["grados"][grado] += 1
        return idx

    def _buscar(self, clave: str):
        """Indice de un grupo compatible con `clave`. En orden de confianza:
        coincidencia exacta; nombre truncado (una lista de tokens es subsecuencia
        de la otra); o muy parecido (primer token compatible y ratio >= umbral)."""
        tokens = clave.split(" ")
        primer = tokens[0]
        mejor_idx, mejor_ratio = None, self._umbral
        for i, g in enumerate(self._grupos):
            if g["clave"] == clave:
                return i
            gtok = g["clave"].split(" ")
            if not _primer_token_compatible(gtok[0], primer):
                continue
            # Nombre truncado: "Roberto Marti" vs "Roberto Marti Cedeño".
            if (min(len(tokens), len(gtok)) >= 2
                    and (_es_subsecuencia(tokens, gtok) or _es_subsecuencia(gtok, tokens))):
                return i
            ratio = SequenceMatcher(None, g["clave"], clave).ratio()
            if ratio >= mejor_ratio:
                mejor_idx, mejor_ratio = i, ratio
        return mejor_idx

    def resolver(self) -> dict:
        """Asigna un id a cada grupo y devuelve {idx_grupo: {id, nombre, grado,
        variantes}}. El nombre canonico es la variante mas frecuente; el grado, el
        mas frecuente."""
        usados = set()
        salida = {}
        for idx, g in enumerate(self._grupos):
            nombre = g["variantes"].most_common(1)[0][0]
            grado = g["grados"].most_common(1)[0][0] if g["grados"] else ""
            id_ = _generar_id(nombre, usados)
            usados.add(id_)
            variantes = sorted(v for v in g["variantes"] if v != nombre)
            salida[idx] = {"id": id_, "nombre": nombre, "grado": grado,
                           "variantes": variantes}
        return salida


def _primer_token_compatible(a: str, b: str) -> bool:
    """Dos primeros nombres son compatibles si uno es prefijo del otro (p. ej.
    'ayme'/'aymee') o si se parecen mucho ('joanna'/'johanna')."""
    if a == b or a.startswith(b) or b.startswith(a):
        return True
    return SequenceMatcher(None, a, b).ratio() >= 0.85


def _es_subsecuencia(cortos: list, largos: list) -> bool:
    """True si todos los tokens de `cortos` aparecen en `largos` en el mismo orden
    (nombre truncado). Requiere que el primer token coincida exactamente."""
    if not cortos or cortos[0] != largos[0]:
        return False
    it = iter(largos)
    return all(tok in it for tok in cortos)


def _generar_id(nombre: str, usados: set) -> str:
    """Genera un id corto y legible a partir de las iniciales del nombre (sin
    acentos, mayusculas). Garantiza unicidad anadiendo un numero si hace falta."""
    tokens = [t for t in quitar_acentos(normalizar_espacios(nombre)).split(" ") if t]
    iniciales = "".join(t[0] for t in tokens).upper()
    base = (iniciales[:4] or "X").ljust(2, "X")
    if base not in usados:
        return base
    n = 2
    while f"{base}{n}" in usados:
        n += 1
    return f"{base}{n}"
