from dataclasses import dataclass


@dataclass(frozen=True)
class Profesor:
    id: str
    nombre: str
    grado: str


@dataclass(frozen=True)
class Estudiante:
    id: str
    nombre: str


@dataclass(frozen=True)
class Local:
    id: str
    nombre: str


@dataclass(frozen=True)
class Momento:
    inicio: str
    fin: str

    @property
    def id(self) -> str:
        # Identificador legible del periodo, p. ej. "09:00-10:00".
        return f"{self.inicio}-{self.fin}"


@dataclass(frozen=True)
class Dia:
    fecha: str
    momentos: tuple  # tuple[Momento]


@dataclass(frozen=True)
class Tesis:
    # Una tesis lleva su tribunal. Los datos reales exigen flexibilidad:
    #  - estudiantes: normalmente uno, pero hay tesis conjuntas (dos estudiantes).
    #  - tutores: normalmente uno, pero hay co-tutorias (varios tutores).
    #  - vocal: rol adicional al tutor/oponente/presidente/secretario (opcional).
    # Se identifica por su estudiante principal (el primero de la lista).
    estudiantes: tuple     # tuple[str], 1+
    tutores: tuple         # tuple[str], 1+
    oponente: str
    presidente: str
    secretario: str
    vocal: str = ""        # opcional: "" si la tesis no tiene vocal

    @property
    def estudiante(self) -> str:
        # Estudiante principal: clave de la tesis para desplegables y asignaciones.
        return self.estudiantes[0]

    @property
    def tutor(self) -> str:
        # Tutor principal (el primero), para vistas que muestran una sola casilla.
        return self.tutores[0]

    def profesores(self) -> tuple:
        # Todos los profesores del tribunal, para el conteo de colisiones. El
        # estudiante no es profesor. El vocal solo cuenta si existe.
        roles = (*self.tutores, self.oponente, self.presidente, self.secretario)
        return (*roles, self.vocal) if self.vocal else roles


@dataclass(frozen=True)
class Asignacion:
    # Lo que se planifica: una tesis (por id de estudiante) en un local, dia y momento.
    estudiante: str
    local: str
    fecha: str
    momento: str  # id de momento, "HH:MM-HH:MM"


@dataclass(frozen=True)
class Facultad:
    # Contenedor raiz del dominio de tribunales.
    profesores: tuple      # tuple[Profesor]
    estudiantes: tuple     # tuple[Estudiante]
    locales: tuple         # tuple[Local]
    dias: tuple            # tuple[Dia]
    tesis: tuple           # tuple[Tesis]
