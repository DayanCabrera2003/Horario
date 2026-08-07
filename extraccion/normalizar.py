"""Funciones puras de normalizacion de texto para la importacion de datos reales.

No conocen el dominio ni leen archivos: reciben cadenas sucias (nombres con grado
y erratas, locales con variantes, horas ambiguas) y devuelven versiones limpias o
sus partes. Se prueban de forma aislada."""
import re
import unicodedata
import datetime

# Grados academicos reconocidos, en el orden en que se intentan (los mas largos
# primero para no cortar "DraC." como "Dra."). La clave es la forma canonica.
_GRADOS = [
    ("DraC.", ("drac.", "dra.c.", "dra c.")),
    ("DrC.", ("drc.", "dr.c.", "dr c.")),
    ("Dra.", ("dra.", "dra")),
    ("Dr.", ("dr.", "dr")),
    ("MSc.", ("msc.", "msc", "ms.", "m.sc.")),
    ("Lic.", ("lic.", "lic")),
    ("Ing.", ("ing.", "ing")),
    ("Tit.", ("tit.", "tit")),
    ("Aux.", ("aux.", "aux")),
    ("Asist.", ("asist.", "asist")),
    ("Inst.", ("inst.", "inst")),
    ("Prof.", ("prof.", "prof")),
]


def quitar_acentos(texto: str) -> str:
    """Quita los diacriticos (acentos, dieresis) de `texto`, conservando la ene."""
    # La ene se preserva descomponiendo, filtrando marcas y recomponiendo: se
    # protege sustituyendola antes y restaurandola despues.
    protegido = texto.replace("ñ", "\0").replace("Ñ", "\1")
    descompuesto = unicodedata.normalize("NFD", protegido)
    sin_marcas = "".join(c for c in descompuesto if unicodedata.category(c) != "Mn")
    return sin_marcas.replace("\0", "ñ").replace("\1", "Ñ")


def normalizar_espacios(texto: str) -> str:
    """Colapsa espacios repetidos y recorta los extremos."""
    return re.sub(r"\s+", " ", texto).strip()


def quitar_anotaciones(texto: str) -> str:
    """Elimina anotaciones entre parentesis, p. ej. '(Graduada de CC)'. Fernando
    pidio explicitamente ignorar las anotaciones."""
    return normalizar_espacios(re.sub(r"\([^)]*\)", "", texto))


def _separar_grado_pegado(texto: str) -> str:
    """Inserta un espacio cuando un grado con punto queda pegado al nombre
    ('Dr.Alberto' -> 'Dr. Alberto') y colapsa puntos repetidos ('Dr..' -> 'Dr.')."""
    alt = "|".join(re.escape(v) for _c, vs in _GRADOS for v in vs if v.endswith("."))
    texto = re.sub(r"\.{2,}", ".", texto)
    return re.sub(rf"(?i)({alt})(?=[^\s.])", r"\1 ", texto)


def extraer_grado(nombre: str) -> tuple:
    """Separa el grado inicial del nombre. Devuelve (grado_canonico, resto). Si no
    hay grado reconocido, grado es "" y resto es el nombre limpio. Tolera grados
    repetidos por errata ('Lic. Lic. Alejandro') y pegados ('Dr.Alberto')."""
    resto = normalizar_espacios(_separar_grado_pegado(nombre))
    grado = ""
    # Consume grados iniciales de forma repetida: se queda con el primero.
    while True:
        primera = resto.split(" ", 1)[0]
        clave = primera.lower()
        encontrado = next((canon for canon, variantes in _GRADOS if clave in variantes), None)
        if encontrado is None:
            break
        grado = grado or encontrado
        partes = resto.split(" ", 1)
        resto = partes[1] if len(partes) > 1 else ""
    return grado, normalizar_espacios(resto)


# Formas de grado con punto, para detectar limites de persona ("... Velarde. Lic.
# Deborah") y grados repetidos por errata ("Lic. Lic. Nombre").
_GRADOS_PUNTO = [v for _c, vs in _GRADOS for v in vs if v.endswith(".")]
_GRADOS_ALT = "|".join(re.escape(v) for v in _GRADOS_PUNTO)


def _colapsar_grados_repetidos(texto: str) -> str:
    """Elimina un grado seguido inmediatamente de otro grado ('Lic. Lic.' ->
    'Lic.'): siempre es la misma persona con el grado escrito dos veces."""
    patron = rf"(?i)\b(?:{_GRADOS_ALT})\s+(?=(?:{_GRADOS_ALT})\b)"
    previo = None
    while previo != texto:
        previo = texto
        texto = re.sub(patron, "", texto)
    return texto


def separar_personas(celda: str) -> list:
    """Divide una celda con varias personas en una lista de nombres crudos.

    Los separadores son la coma, ' y ' y un punto seguido de un nuevo grado (un
    punto tras un grado, como en 'Dr. Nombre', NO separa). Los grados repetidos se
    colapsan antes, para no crear un fragmento vacio."""
    if not celda:
        return []
    texto = _colapsar_grados_repetidos(_separar_grado_pegado(str(celda)))
    # Punto que precede a un nuevo grado -> separador (evita cortar "Dr. Nombre").
    # Sin \b tras el grado: como termina en '.', el limite de palabra no se cumple.
    texto = re.sub(rf"\.\s+(?=({_GRADOS_ALT}))", "|", texto, flags=re.IGNORECASE)
    partes = re.split(r"\s*,\s*|\s+y\s+|\s*\|\s*", texto)
    return [normalizar_espacios(p) for p in partes if normalizar_espacios(p)]


def clave_persona(nombre: str) -> str:
    """Clave de comparacion de un nombre (sin grado, sin anotaciones, sin acentos,
    en minusculas y sin puntuacion). Dos formas del mismo nombre que solo difieran
    en acentos, mayusculas o espacios comparten clave."""
    _grado, resto = extraer_grado(quitar_anotaciones(nombre))
    plano = quitar_acentos(resto).lower()
    plano = re.sub(r"[.\-,]", " ", plano)
    return normalizar_espacios(plano)


# Locales: cada clave normalizada mapea a un nombre canonico. La clave se obtiene
# con quitar_acentos + minusculas + espacios colapsados.
_LOCALES_CANON = {
    "postgrado": "Postgrado",
    "posgrado": "Postgrado",
    "salon decanato": "Salón del decanato",
    "salon del decanato": "Salón del decanato",
    "francofonia": "Francofonía",
    "francofomia": "Francofonía",
    "aula de laptop (laboratorio)": "Aula de laptop (Laboratorio)",
    "aula de las laptop laboratorio": "Aula de laptop (Laboratorio)",
    "aula de laptop laboratorio": "Aula de laptop (Laboratorio)",
    "virtual": "Virtual",
}


def normalizar_local(celda) -> str:
    """Devuelve el nombre canonico del local, o "" si la celda no es un local
    (esta vacia o contiene una anotacion larga, no un nombre de sala)."""
    if not celda:
        return ""
    limpio = quitar_anotaciones(str(celda))
    clave = normalizar_espacios(quitar_acentos(limpio).lower())
    if clave in _LOCALES_CANON:
        return _LOCALES_CANON[clave]
    # 'virtual ...' -> Virtual (la anotacion de coordinacion ya se quito arriba).
    if clave.startswith("virtual"):
        return "Virtual"
    # Frases largas (notas de coordinacion) no son un local: se descartan.
    if len(clave.split()) > 5:
        return ""
    # Local desconocido pero corto: se conserva con espacios normalizados.
    return normalizar_espacios(limpio)


def parsear_hora(valor) -> str:
    """Normaliza la hora de inicio a 'HH:MM' en formato 24h. Las horas < 8 se
    interpretan como tarde (+12), porque las defensas van de 9:00 a 17:00. Devuelve
    "" si la celda no es una hora (None, 'pendiente', texto no reconocible)."""
    if valor is None:
        return ""
    if isinstance(valor, datetime.time):
        h, m = valor.hour, valor.minute
    elif isinstance(valor, datetime.datetime):
        h, m = valor.hour, valor.minute
    else:
        texto = normalizar_espacios(str(valor))
        m_match = re.match(r"^(\d{1,2})[:\s]+(\d{2})$", texto)
        if not m_match:
            return ""
        h, m = int(m_match.group(1)), int(m_match.group(2))
    if h < 8:            # 1:30 -> 13:30, 2:00 -> 14:00 (defensas de tarde)
        h += 12
    return f"{h:02d}:{m:02d}"


def sumar_minutos(hora: str, minutos: int) -> str:
    """Suma `minutos` a una hora 'HH:MM' y devuelve la hora resultante 'HH:MM'."""
    h, m = map(int, hora.split(":"))
    total = (h * 60 + m + minutos) % (24 * 60)
    return f"{total // 60:02d}:{total % 60:02d}"
