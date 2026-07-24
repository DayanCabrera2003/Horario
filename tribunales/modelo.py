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
    # Una tesis se identifica por su estudiante (relacion 1:1 estudiante-tesis).
    estudiante: str
    tutor: str
    oponente: str
    presidente: str
    secretario: str

    def profesores(self) -> tuple:
        # Los cuatro roles de profesor, en orden de columna. El estudiante no es profesor.
        return (self.tutor, self.oponente, self.presidente, self.secretario)


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
