from dataclasses import dataclass, field


@dataclass(frozen=True)
class Aula:
    nombre: str


@dataclass(frozen=True)
class Asignatura:
    id: str
    nombre: str
    frecuencia: int


@dataclass(frozen=True)
class Grupo:
    carrera: str
    anio: int
    sesion: int
    numero: int

    @property
    def id(self) -> str:
        return f"{self.carrera}{self.anio}{self.sesion}{self.numero}"

    @property
    def anio_codigo(self) -> str:
        return f"{self.carrera}{self.anio}"


@dataclass(frozen=True)
class Anio:
    carrera: str
    numero: int
    asignaturas: tuple

    @property
    def codigo(self) -> str:
        return f"{self.carrera}{self.numero}"


@dataclass(frozen=True)
class Asignacion:
    asig: str
    aula: str


@dataclass
class Horario:
    grupo_id: str
    celdas: dict = field(default_factory=dict)  # {(dia, turno): Asignacion}


@dataclass(frozen=True)
class Facultad:
    aulas: tuple            # tuple[str]
    dias: tuple             # tuple[str]
    turnos: int
    grupos: tuple           # tuple[Grupo]
    anios: dict             # {codigo: Anio}

    def asignaturas_de(self, grupo: Grupo) -> tuple:
        return self.anios[grupo.anio_codigo].asignaturas
