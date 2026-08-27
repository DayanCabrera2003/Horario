from dataclasses import dataclass, field


@dataclass(frozen=True)
class Aula:
    nombre: str


@dataclass(frozen=True)
class Profesor:
    # Mismo trio de datos que en el generador del departamento: el tutor pidio
    # "solamente el grado y la cantidad de horas maxima".
    id: str
    nombre: str
    grado: str = ""
    # Tope de horas propio; None = sin tope declarado.
    tope_horas: int | None = None


@dataclass(frozen=True)
class Docencia:
    # Quien imparte una asignatura en un grupo concreto. La clave es el par: las
    # asignaturas cuelgan del ano, no del grupo, asi que el mismo AMI-CP lo puede
    # dar un profesor distinto en cada grupo.
    grupo: str
    asignatura: str
    profesor: str


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
    # Las dos secciones que la fase 2 anadio al YAML. Opcionales: una facultad
    # puede describirse sin decir quien imparte que.
    profesores: tuple = ()  # tuple[Profesor]
    docencia: tuple = ()    # tuple[Docencia]

    def asignaturas_de(self, grupo: Grupo) -> tuple:
        return self.anios[grupo.anio_codigo].asignaturas

    def profesor_de(self, grupo_id: str, asignatura_id: str) -> str:
        """Id del profesor que imparte esa asignatura en ese grupo, o "" si no
        se ha declarado. Devuelve cadena vacia y no None porque el consumidor es
        una celda de Excel, donde el hueco se escribe en blanco."""
        for d in self.docencia:
            if d.grupo == grupo_id and d.asignatura == asignatura_id:
                return d.profesor
        return ""
