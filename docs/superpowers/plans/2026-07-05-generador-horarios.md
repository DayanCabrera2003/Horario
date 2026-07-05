# Generador de horarios — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir un generador Python/openpyxl que, a partir de configuración YAML, produzca un workbook `.xlsx` de horarios con fórmulas vivas y formato condicional, en modo esqueleto vacío o copia fiel.

**Architecture:** Modular ligero. Un modelo de dominio puro (dataclasses) alimentado por un cargador/validador de config; un módulo `layout` como única fuente de posiciones de celda; módulos de estilos y constructores de hoja (`Datos`, grupo, `Aulas`) que solo dependen del modelo y del layout; y un orquestador + CLI. Las partes automáticas se escriben como fórmulas vivas de Excel y reglas de formato condicional, no como valores estáticos.

**Tech Stack:** Python 3.11+, openpyxl (xlsx), PyYAML (config), pytest (tests).

**Spec de referencia:** `docs/superpowers/specs/2026-07-05-generador-horarios-design.md`

---

## Estructura de archivos

```
tesis-horarios/  (raíz = repo actual)
├── pyproject.toml                 # metadata + deps + config pytest
├── generar.py                     # CLI de entrada
├── config/
│   ├── facultad.yaml              # estructura (carreras/años/grupos/asignaturas/aulas)
│   └── horarios.yaml              # asignaciones para copia fiel (opcional)
├── horarios/
│   ├── __init__.py
│   ├── modelo.py                  # dataclasses del dominio (sin lógica de Excel)
│   ├── config.py                  # YAML → modelo, con validación
│   ├── layout.py                  # mapeo único de filas/columnas
│   ├── estilos.py                 # colores por año + fábricas de reglas de formato condicional
│   ├── hoja_datos.py              # hoja oculta: lista de aulas + firmas de año
│   ├── hoja_grupo.py              # construye una hoja de grupo
│   ├── hoja_aulas.py              # construye la hoja Aulas
│   └── generador.py               # orquesta config → Workbook → .xlsx
└── tests/
    ├── test_modelo.py
    ├── test_config.py
    ├── test_layout.py
    ├── test_estilos.py
    ├── test_hoja_datos.py
    ├── test_hoja_grupo.py
    ├── test_hoja_aulas.py
    ├── test_generador.py
    └── test_cli.py
```

**Responsabilidad por archivo:**
- `modelo.py`: tipos del dominio y propiedades derivadas (`Grupo.id`, `Grupo.anio_codigo`). Cero openpyxl.
- `config.py`: leer YAML, derivar grupos, validar, construir `Facultad` y `Horario`.
- `layout.py`: funciones puras dirección-de-celda. **Único lugar** que conoce posiciones.
- `estilos.py`: `ANIO_COLOR` y funciones que devuelven objetos `Rule`/`PatternFill`.
- `hoja_datos.py` / `hoja_grupo.py` / `hoja_aulas.py`: construyen hojas sobre un `Workbook` dado.
- `generador.py`: junta todo. `generar.py`: parseo de argumentos.

---

## Task 1: Scaffolding del proyecto

**Files:**
- Create: `pyproject.toml`
- Create: `horarios/__init__.py`
- Create: `tests/__init__.py`

- [ ] **Step 1: Crear `pyproject.toml`**

```toml
[project]
name = "tesis-horarios"
version = "0.1.0"
description = "Generador de horarios de la facultad (Python + openpyxl)"
requires-python = ">=3.11"
dependencies = ["openpyxl>=3.1", "PyYAML>=6.0"]

[project.optional-dependencies]
dev = ["pytest>=8.0"]

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.setuptools.packages.find]
include = ["horarios*"]
```

- [ ] **Step 2: Crear paquetes vacíos**

Create `horarios/__init__.py` y `tests/__init__.py` (ambos vacíos).

- [ ] **Step 3: Instalar en modo editable**

Run: `python -m pip install -e ".[dev]"`
Expected: instala openpyxl, PyYAML, pytest sin error.

- [ ] **Step 4: Verificar pytest corre (sin tests aún)**

Run: `python -m pytest -q`
Expected: "no tests ran" (exit code 5) — confirma que pytest funciona.

- [ ] **Step 5: Commit**

```bash
git add pyproject.toml horarios/__init__.py tests/__init__.py
git commit -m "chore: scaffolding del proyecto (pyproject, paquetes, pytest)"
```

---

## Task 2: Modelo de dominio

**Files:**
- Create: `horarios/modelo.py`
- Test: `tests/test_modelo.py`

- [ ] **Step 1: Escribir tests que fallan**

```python
# tests/test_modelo.py
from horarios.modelo import Aula, Asignatura, Grupo, Anio, Asignacion, Horario

def test_grupo_id_se_deriva():
    assert Grupo(carrera="C", anio=1, sesion=1, numero=3).id == "C113"
    assert Grupo(carrera="N", anio=2, sesion=1, numero=3).id == "N213"

def test_grupo_anio_codigo():
    assert Grupo(carrera="C", anio=1, sesion=2, numero=1).anio_codigo == "C1"
    assert Grupo(carrera="M", anio=4, sesion=1, numero=1).anio_codigo == "M4"

def test_anio_codigo():
    a = Anio(carrera="C", numero=1, asignaturas=())
    assert a.codigo == "C1"

def test_horario_celdas_por_defecto_vacio():
    h = Horario(grupo_id="C111")
    assert h.celdas == {}
    h.celdas[("Lunes", 1)] = Asignacion(asig="L-C", aula="Aula 6")
    assert h.celdas[("Lunes", 1)].aula == "Aula 6"
```

- [ ] **Step 2: Correr y ver que falla**

Run: `python -m pytest tests/test_modelo.py -q`
Expected: FAIL (ModuleNotFoundError: horarios.modelo).

- [ ] **Step 3: Implementar `modelo.py`**

```python
# horarios/modelo.py
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
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `python -m pytest tests/test_modelo.py -q`
Expected: PASS (4 passed).

- [ ] **Step 5: Commit**

```bash
git add horarios/modelo.py tests/test_modelo.py
git commit -m "feat: modelo de dominio (Grupo/Anio/Asignatura/Horario/Facultad)"
```

---

## Task 3: Config de ejemplo + cargador/validador

**Files:**
- Create: `config/facultad.yaml`
- Create: `horarios/config.py`
- Test: `tests/test_config.py`

- [ ] **Step 1: Crear `config/facultad.yaml` inicial** (cableado, ampliable)

```yaml
aulas: [Aula 1, Aula 2, Aula 3, Aula 4, Aula 5, Aula 6, Aula 7, Aula 8, Aula 9, Lab]
dias:   [Lunes, Martes, Miércoles, Jueves, Viernes]
turnos: 6

carreras:
  C:
    nombre: Carrera C
    años:
      1:
        sesiones:
          1: { grupos: [1, 2, 3] }   # C111, C112, C113
          2: { grupos: [1, 2] }      # C121, C122
        asignaturas:
          - { id: AMI-C,  nombre: "Análisis Matemático I (Conf)", frecuencia: 1 }
          - { id: AMI-CP, nombre: "Análisis Matemático I (C.P.)", frecuencia: 2 }
          - { id: Pro-C,  nombre: "Programación (Conf)",          frecuencia: 1 }
          - { id: Pro-CP, nombre: "Programación (C.P.)",          frecuencia: 2 }
          - { id: A1-C,   nombre: "Álgebra I (Conf)",             frecuencia: 2 }
          - { id: A1-CP,  nombre: "Álgebra I (C.P.)",             frecuencia: 1 }
          - { id: F-C,    nombre: "Filosofía (Conf)",             frecuencia: 1 }
          - { id: F-CP,   nombre: "Filosofía (C.P.)",             frecuencia: 1 }
          - { id: L-C,    nombre: "Lógica (Conf)",                frecuencia: 1 }
          - { id: L-CP,   nombre: "Lógica (C.P.)",                frecuencia: 1 }
          - { id: EF,     nombre: "Educación Física",             frecuencia: 1 }
```

> Nota: esta tabla reproduce las asignaturas visibles en la demo del tutor. Se amplía con más años/carreras (M, D) en iteraciones siguientes; el generador ya las soporta.

- [ ] **Step 2: Escribir tests que fallan**

```python
# tests/test_config.py
import pytest
from pathlib import Path
from horarios.config import cargar_facultad, ErrorConfig

FIXT = Path(__file__).parent / "fixtures"

def escribir(tmp_path, texto):
    p = tmp_path / "facultad.yaml"
    p.write_text(texto, encoding="utf-8")
    return p

BASE = """
aulas: [Aula 1, Lab]
dias: [Lunes, Martes]
turnos: 6
carreras:
  C:
    nombre: Carrera C
    años:
      1:
        sesiones:
          1: { grupos: [1, 2] }
          2: { grupos: [1] }
        asignaturas:
          - { id: L-C, nombre: "Lógica", frecuencia: 1 }
"""

def test_cargar_deriva_grupos(tmp_path):
    fac = cargar_facultad(escribir(tmp_path, BASE))
    ids = sorted(g.id for g in fac.grupos)
    assert ids == ["C111", "C112", "C121"]

def test_cargar_expone_anios_con_asignaturas(tmp_path):
    fac = cargar_facultad(escribir(tmp_path, BASE))
    assert fac.anios["C1"].asignaturas[0].id == "L-C"
    assert fac.turnos == 6
    assert fac.aulas == ("Aula 1", "Lab")

def test_config_invalida_turnos_cero(tmp_path):
    mal = BASE.replace("turnos: 6", "turnos: 0")
    with pytest.raises(ErrorConfig, match="turnos"):
        cargar_facultad(escribir(tmp_path, mal))

def test_config_invalida_asignaturas_faltan(tmp_path):
    mal = BASE.replace('        asignaturas:\n          - { id: L-C, nombre: "Lógica", frecuencia: 1 }\n', "")
    with pytest.raises(ErrorConfig, match="asignaturas"):
        cargar_facultad(escribir(tmp_path, mal))
```

- [ ] **Step 3: Correr y ver que falla**

Run: `python -m pytest tests/test_config.py -q`
Expected: FAIL (ModuleNotFoundError).

- [ ] **Step 4: Implementar `config.py`**

```python
# horarios/config.py
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
                aula = celda["aula"]
                if aula not in facultad.aulas:
                    raise ErrorConfig(f"{grupo_id}/{dia}/{turno}: aula '{aula}' no existe")
                h.celdas[(dia, turno)] = Asignacion(asig=celda["asig"], aula=aula)
        horarios[grupo_id] = h
    return horarios
```

- [ ] **Step 5: Correr y ver que pasa**

Run: `python -m pytest tests/test_config.py -q`
Expected: PASS (4 passed).

- [ ] **Step 6: Commit**

```bash
git add config/facultad.yaml horarios/config.py tests/test_config.py
git commit -m "feat: cargador/validador de config YAML (facultad + horarios)"
```

---

## Task 4: Layout (mapeo de celdas)

**Files:**
- Create: `horarios/layout.py`
- Test: `tests/test_layout.py`

Convenciones (hoja de grupo): fila 1 título; fila 3 encabezado de días; turno `t` ocupa filas
`asig = 2 + 2t` (turno 1 → fila 4) y `aula = asig + 1`. Días en columnas C.. (índice 3 + i).
Tabla de asignaturas empieza en columna I (índice 9), fila de datos 4.

- [ ] **Step 1: Escribir tests que fallan**

```python
# tests/test_layout.py
from horarios import layout as L

def test_celda_asignatura():
    # turno 1, primer día (Lunes, idx 0) -> C4
    assert L.celda_asig(dia_idx=0, turno=1) == "C4"
    # turno 2, Lunes -> C6 ; aula debajo -> C7
    assert L.celda_asig(dia_idx=0, turno=2) == "C6"
    assert L.celda_aula(dia_idx=0, turno=2) == "C7"

def test_celda_dia_desplaza_columna():
    assert L.celda_asig(dia_idx=1, turno=1) == "D4"  # Martes
    assert L.celda_asig(dia_idx=4, turno=1) == "G4"  # Viernes

def test_rango_horario_cubre_todos_los_turnos():
    # 5 días, 6 turnos -> C4:G15
    assert L.rango_horario(n_dias=5, n_turnos=6) == "C4:G15"

def test_tabla_asignaturas_posiciones():
    assert L.celda_asig_tabla_id(fila_datos=0) == "I4"
    assert L.celda_asig_tabla_frec(fila_datos=0) == "K4"
    assert L.celda_asig_tabla_asignadas(fila_datos=0) == "L4"
    assert L.celda_asig_tabla_faltan(fila_datos=0) == "M4"
```

- [ ] **Step 2: Correr y ver que falla**

Run: `python -m pytest tests/test_layout.py -q`
Expected: FAIL.

- [ ] **Step 3: Implementar `layout.py`**

```python
# horarios/layout.py
from openpyxl.utils import get_column_letter

# --- Hoja de grupo ---
CELDA_GRUPO_ID = "B1"
FILA_ENCABEZADO_DIAS = 3
COL_PRIMER_DIA = 3          # C
COL_TABLA_ASIG = 9          # I
FILA_PRIMERA_ASIG = 4

def _col(idx: int) -> str:
    return get_column_letter(idx)

def col_dia(dia_idx: int) -> str:
    return _col(COL_PRIMER_DIA + dia_idx)

def fila_asig(turno: int) -> int:
    return 2 + 2 * turno            # turno 1 -> 4

def fila_aula(turno: int) -> int:
    return fila_asig(turno) + 1

def celda_asig(dia_idx: int, turno: int) -> str:
    return f"{col_dia(dia_idx)}{fila_asig(turno)}"

def celda_aula(dia_idx: int, turno: int) -> str:
    return f"{col_dia(dia_idx)}{fila_aula(turno)}"

def rango_horario(n_dias: int, n_turnos: int) -> str:
    c1 = celda_asig(0, 1)
    c2 = f"{col_dia(n_dias - 1)}{fila_aula(n_turnos)}"
    return f"{c1}:{c2}"

def rangos_filas_asig(n_dias: int, n_turnos: int) -> str:
    """sqref multi-rango que cubre solo las filas de asignatura (para formato condicional)."""
    ini, fin = COL_PRIMER_DIA, COL_PRIMER_DIA + n_dias - 1
    return " ".join(f"{_col(ini)}{fila_asig(t)}:{_col(fin)}{fila_asig(t)}"
                    for t in range(1, n_turnos + 1))

def rangos_filas_aula(n_dias: int, n_turnos: int) -> str:
    ini, fin = COL_PRIMER_DIA, COL_PRIMER_DIA + n_dias - 1
    return " ".join(f"{_col(ini)}{fila_aula(t)}:{_col(fin)}{fila_aula(t)}"
                    for t in range(1, n_turnos + 1))

# --- Tabla de asignaturas (I=id, J=nombre, K=frec, L=asignadas, M=faltan) ---
def _fila_tabla(fila_datos: int) -> int:
    return FILA_PRIMERA_ASIG + fila_datos

def celda_asig_tabla_id(fila_datos: int) -> str:      return f"I{_fila_tabla(fila_datos)}"
def celda_asig_tabla_nombre(fila_datos: int) -> str:  return f"J{_fila_tabla(fila_datos)}"
def celda_asig_tabla_frec(fila_datos: int) -> str:    return f"K{_fila_tabla(fila_datos)}"
def celda_asig_tabla_asignadas(fila_datos: int) -> str: return f"L{_fila_tabla(fila_datos)}"
def celda_asig_tabla_faltan(fila_datos: int) -> str:  return f"M{_fila_tabla(fila_datos)}"

def rango_ids_asignaturas(n_asig: int) -> str:
    return f"I{FILA_PRIMERA_ASIG}:I{FILA_PRIMERA_ASIG + n_asig - 1}"
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `python -m pytest tests/test_layout.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add horarios/layout.py tests/test_layout.py
git commit -m "feat: layout como fuente única de posiciones de celda"
```

---

## Task 5: Estilos (colores por año + fábricas de reglas)

**Files:**
- Create: `horarios/estilos.py`
- Test: `tests/test_estilos.py`

- [ ] **Step 1: Escribir tests que fallan**

```python
# tests/test_estilos.py
from horarios import estilos

def test_hay_color_para_cada_anio():
    for cod in ["C1","C2","C3","C4","M1","M2","M3","M4","D1","D2","D3","D4"]:
        assert cod in estilos.ANIO_COLOR
        assert len(estilos.ANIO_COLOR[cod]) == 6  # hex RRGGBB

def test_color_conflicto_definido():
    assert len(estilos.COLOR_CONFLICTO) == 6

def test_fill_devuelve_patternfill():
    from openpyxl.styles import PatternFill
    assert isinstance(estilos.fill(estilos.ANIO_COLOR["C1"]), PatternFill)
```

- [ ] **Step 2: Correr y ver que falla**

Run: `python -m pytest tests/test_estilos.py -q`
Expected: FAIL.

- [ ] **Step 3: Implementar `estilos.py`**

```python
# horarios/estilos.py
from openpyxl.styles import PatternFill
from openpyxl.formatting.rule import FormulaRule

# Colores por "año" (carrera+año). Fijos en código; el usuario no los cambia.
ANIO_COLOR = {
    "C1": "BBDEFB", "C2": "90CAF9", "C3": "64B5F6", "C4": "42A5F5",
    "M1": "C8E6C9", "M2": "A5D6A7", "M3": "81C784", "M4": "66BB6A",
    "D1": "FFE0B2", "D2": "FFCC80", "D3": "FFB74D", "D4": "FFA726",
}
COLOR_CONFLICTO = "E53935"   # rojo intenso: años distintos en la misma aula/turno
COLOR_AULA_INVALIDA = "FFF176"   # amarillo
COLOR_ASIG_DESCONOCIDA = "FFB74D"  # naranja
COLOR_SOBRE_PLANIFICADA = "EF9A9A"  # rojo
COLOR_FREC_EXACTA = "A5D6A7"       # verde

def fill(hex_rgb: str) -> PatternFill:
    return PatternFill(start_color=hex_rgb, end_color=hex_rgb, fill_type="solid")

def regla_formula(formula: str, color_hex: str) -> FormulaRule:
    return FormulaRule(formula=[formula], fill=fill(color_hex))
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `python -m pytest tests/test_estilos.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add horarios/estilos.py tests/test_estilos.py
git commit -m "feat: paleta de colores por año y fábricas de estilos/reglas"
```

---

## Task 6: Hoja de grupo

**Files:**
- Create: `horarios/hoja_grupo.py`
- Test: `tests/test_hoja_grupo.py`

Construye una hoja para un grupo: id, rejilla de horario (vacía o rellena desde `Horario`),
tabla de asignaturas con fórmulas `Asignadas`/`Faltan`, dropdowns de aula, y formato condicional.

- [ ] **Step 1: Escribir tests que fallan**

```python
# tests/test_hoja_grupo.py
from openpyxl import Workbook
from horarios.modelo import Grupo, Asignatura, Anio, Facultad, Horario, Asignacion
from horarios.hoja_grupo import construir_hoja_grupo
from horarios import layout as L

def _facultad():
    anio = Anio(carrera="C", numero=1, asignaturas=(
        Asignatura("L-C", "Lógica", 1),
        Asignatura("Pro-C", "Programación", 2),
    ))
    g = Grupo("C", 1, 1, 1)
    return Facultad(aulas=("Aula 1","Lab"), dias=("Lunes","Martes"),
                    turnos=6, grupos=(g,), anios={"C1": anio}), g

def test_escribe_id_y_formulas():
    fac, g = _facultad()
    wb = Workbook()
    ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    assert ws[L.CELDA_GRUPO_ID].value == "C111"
    # Asignadas de la primera asignatura = COUNTIF sobre el rango del horario
    asignadas = ws[L.celda_asig_tabla_asignadas(0)].value
    assert asignadas.startswith("=COUNTIF(")
    # fixture: 2 días, 6 turnos -> rango del horario C4:D15
    assert "C4:D15" in asignadas
    faltan = ws[L.celda_asig_tabla_faltan(0)].value
    assert faltan.startswith("=")

def test_hay_dropdowns_de_aula_y_asignatura():
    fac, g = _facultad()
    wb = Workbook(); ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    # dos validaciones de lista: aula (filas de aula) y asignatura (filas de asignatura)
    assert len(ws.data_validations.dataValidation) == 2

def test_horario_rellena_celdas():
    fac, g = _facultad()
    h = Horario(grupo_id="C111")
    h.celdas[("Lunes", 1)] = Asignacion(asig="L-C", aula="Aula 1")
    wb = Workbook(); ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=h)
    assert ws[L.celda_asig(0, 1)].value == "L-C"
    assert ws[L.celda_aula(0, 1)].value == "Aula 1"

def test_esqueleto_deja_celdas_vacias():
    fac, g = _facultad()
    wb = Workbook(); ws = wb.active
    construir_hoja_grupo(ws, g, fac, horario=None)
    assert ws[L.celda_asig(0, 1)].value is None
```

- [ ] **Step 2: Correr y ver que falla**

Run: `python -m pytest tests/test_hoja_grupo.py -q`
Expected: FAIL.

- [ ] **Step 3: Implementar `hoja_grupo.py`**

```python
# horarios/hoja_grupo.py
from openpyxl.worksheet.datavalidation import DataValidation
from horarios import layout as L
from horarios import estilos

def construir_hoja_grupo(ws, grupo, facultad, horario=None):
    ws.title = grupo.id
    ws["A1"] = "Grupo"
    ws[L.CELDA_GRUPO_ID] = grupo.id

    # Encabezado de días
    for i, dia in enumerate(facultad.dias):
        ws[f"{L.col_dia(i)}{L.FILA_ENCABEZADO_DIAS}"] = dia
    # Etiquetas de turno
    for t in range(1, facultad.turnos + 1):
        ws[f"A{L.fila_asig(t)}"] = f"Turno {t}"

    # Rejilla de horario (rellena si hay horario)
    if horario:
        for (dia, turno), asg in horario.celdas.items():
            dia_idx = facultad.dias.index(dia)
            ws[L.celda_asig(dia_idx, turno)] = asg.asig
            ws[L.celda_aula(dia_idx, turno)] = asg.aula

    # Tabla de asignaturas + fórmulas
    asignaturas = facultad.asignaturas_de(grupo)
    # Nota: 'rango' cubre filas de asignatura Y de aula; COUNTIF sobre él es correcto porque
    # los nombres de aula nunca coinciden con ids de asignatura. Si se quisiera estrictez,
    # usar L.rangos_filas_asig(...) en su lugar.
    rango = L.rango_horario(len(facultad.dias), facultad.turnos)
    ws["I3"] = "Asignatura"
    ws["J3"], ws["K3"], ws["L3"], ws["M3"] = "Nombre", "Frec", "Asignadas", "Faltan"
    for i, a in enumerate(asignaturas):
        id_cell = L.celda_asig_tabla_id(i)
        ws[id_cell] = a.id
        ws[L.celda_asig_tabla_nombre(i)] = a.nombre
        frec_cell = L.celda_asig_tabla_frec(i)
        ws[frec_cell] = a.frecuencia
        asignadas_cell = L.celda_asig_tabla_asignadas(i)
        ws[asignadas_cell] = f"=COUNTIF({rango},{id_cell})"
        ws[L.celda_asig_tabla_faltan(i)] = f"={frec_cell}-{asignadas_cell}"

    _aplicar_dropdown_aulas(ws, facultad)
    _aplicar_dropdown_asignaturas(ws, grupo, facultad)
    _aplicar_formato_condicional(ws, grupo, facultad)

def _aplicar_dropdown_aulas(ws, facultad):
    # Fuente en la hoja Datos (creada por hoja_datos). Rango nombrado 'AulasValidas'.
    # OJO: openpyxl escribe formula1 verbatim en el XML; NO lleva '=' inicial o el
    # dropdown no se puebla al abrir en Excel/LibreOffice.
    dv = DataValidation(type="list", formula1="AulasValidas", allow_blank=True)
    ws.add_data_validation(dv)
    dv.sqref = L.rangos_filas_aula(len(facultad.dias), facultad.turnos)

def _aplicar_dropdown_asignaturas(ws, grupo, facultad):
    # Fuente: los ids de la tabla de asignaturas del propio grupo (misma hoja).
    # Sin '=' inicial y con rango absoluto para que no se desplace al insertar filas.
    n_asig = len(facultad.asignaturas_de(grupo))
    rango = L.rango_ids_asignaturas(n_asig).replace("I", "$I$")   # I4:I14 -> $I$4:$I$14
    dv = DataValidation(type="list", formula1=rango, allow_blank=True)
    ws.add_data_validation(dv)
    dv.sqref = L.rangos_filas_asig(len(facultad.dias), facultad.turnos)

def _aplicar_formato_condicional(ws, grupo, facultad):
    n_dias, n_turnos = len(facultad.dias), facultad.turnos
    n_asig = len(facultad.asignaturas_de(grupo))
    rango_ids = L.rango_ids_asignaturas(n_asig)

    # Asignatura desconocida (naranja) en filas de asignatura
    sq_asig = L.rangos_filas_asig(n_dias, n_turnos)
    primera = L.celda_asig(0, 1)
    ws.conditional_formatting.add(
        sq_asig,
        estilos.regla_formula(
            f'AND({primera}<>"",COUNTIF({rango_ids},{primera})=0)',
            estilos.COLOR_ASIG_DESCONOCIDA),
    )
    # Aula inválida (amarillo) en filas de aula
    sq_aula = L.rangos_filas_aula(n_dias, n_turnos)
    primera_aula = L.celda_aula(0, 1)
    ws.conditional_formatting.add(
        sq_aula,
        estilos.regla_formula(
            f'AND({primera_aula}<>"",COUNTIF(AulasValidas,{primera_aula})=0)',
            estilos.COLOR_AULA_INVALIDA),
    )
    # Tabla de asignaturas: sobre-planificada (rojo) y frecuencia exacta (verde)
    l_ini = L.celda_asig_tabla_asignadas(0)
    l_fin = L.celda_asig_tabla_asignadas(n_asig - 1)
    k_ini = L.celda_asig_tabla_frec(0)
    rango_asignadas = f"{l_ini}:{l_fin}"
    ws.conditional_formatting.add(
        rango_asignadas,
        estilos.regla_formula(f"{l_ini}>{k_ini}", estilos.COLOR_SOBRE_PLANIFICADA),
    )
    ws.conditional_formatting.add(
        rango_asignadas,
        estilos.regla_formula(f"{l_ini}={k_ini}", estilos.COLOR_FREC_EXACTA),
    )
```

> Nota de implementación: las fórmulas de formato condicional en openpyxl son **relativas a la
> primera celda del sqref**; por eso se escribe con la primera celda (`C4`, etc.) y Excel la
> desplaza por el rango. Ajustar en Step 4 si algún test de texto exacto lo requiere.

- [ ] **Step 4: Correr y ver que pasa**

Run: `python -m pytest tests/test_hoja_grupo.py -q`
Expected: PASS. (Ajustar aserciones de texto de fórmula si el rango exacto difiere; el objetivo
es que `Asignadas` sea un `COUNTIF` sobre el rango del horario y `Faltan` una resta.)

- [ ] **Step 5: Commit**

```bash
git add horarios/hoja_grupo.py tests/test_hoja_grupo.py
git commit -m "feat: constructor de hoja de grupo (formulas vivas + formato condicional + dropdown)"
```

---

## Task 7: Hoja Datos (lista de aulas + firmas de año)

**Files:**
- Create: `horarios/hoja_datos.py`
- Test: `tests/test_hoja_datos.py`

Crea la hoja oculta `Datos`: (a) lista maestra de aulas + rango nombrado `AulasValidas`;
(b) por cada celda de `Aulas` (día×turno×aula), una **firma de año** que devuelve el código del
año único presente o `"MIX"`.

- [ ] **Step 1: Escribir tests que fallan**

```python
# tests/test_hoja_datos.py
from openpyxl import Workbook
from horarios.modelo import Grupo, Anio, Facultad
from horarios.hoja_datos import construir_hoja_datos, NOMBRE_HOJA

def _fac():
    g = [Grupo("C",1,1,1), Grupo("M",1,1,1)]
    anios = {"C1": Anio("C",1,()), "M1": Anio("M",1,())}
    return Facultad(aulas=("Aula 1","Lab"), dias=("Lunes",), turnos=2, grupos=tuple(g), anios=anios)

def test_crea_hoja_oculta_y_lista_aulas():
    fac = _fac(); wb = Workbook()
    construir_hoja_datos(wb, fac)
    ws = wb[NOMBRE_HOJA]
    assert ws.sheet_state == "hidden"
    valores = [c.value for col in ws.iter_cols() for c in col]
    assert "Aula 1" in valores and "Lab" in valores

def test_rango_nombrado_aulas_validas():
    fac = _fac(); wb = Workbook()
    construir_hoja_datos(wb, fac)
    assert "AulasValidas" in wb.defined_names

def test_firma_usa_countif():
    fac = _fac(); wb = Workbook()
    celdas = construir_hoja_datos(wb, fac)
    # celdas: {(dia, turno, aula): direccion_de_la_firma}
    dir_firma = celdas[("Lunes", 1, "Aula 1")]   # p.ej. "Datos!C1" (referencia calificada)
    ws = wb[NOMBRE_HOJA]
    coord_local = dir_firma.split("!")[1]         # indexar la hoja con la coord local, no "Datos!C1"
    assert ws[coord_local].value.startswith("=")
    assert "COUNTIF" in ws[coord_local].value
```

- [ ] **Step 2: Correr y ver que falla**

Run: `python -m pytest tests/test_hoja_datos.py -q`
Expected: FAIL.

- [ ] **Step 3: Implementar `hoja_datos.py`**

```python
# horarios/hoja_datos.py
from openpyxl.workbook.defined_name import DefinedName
from openpyxl.utils import quote_sheetname, absolute_coordinate
from horarios import layout as L

NOMBRE_HOJA = "Datos"

def construir_hoja_datos(wb, facultad):
    ws = wb.create_sheet(NOMBRE_HOJA)
    ws.sheet_state = "hidden"

    # (a) Lista maestra de aulas en columna A, con rango nombrado
    for i, aula in enumerate(facultad.aulas, start=1):
        ws[f"A{i}"] = aula
    ref = f"{quote_sheetname(NOMBRE_HOJA)}!{absolute_coordinate('A1')}:{absolute_coordinate(f'A{len(facultad.aulas)}')}"
    wb.defined_names.add(DefinedName("AulasValidas", attr_text=ref))

    # (b) Firmas de año, una por (dia, turno, aula).
    # Para cada año, presencia = suma de COUNTIF sobre las celdas-aula de los grupos de ese año.
    anios_por_codigo = {}
    for g in facultad.grupos:
        anios_por_codigo.setdefault(g.anio_codigo, []).append(g)

    celdas = {}
    fila = 1
    col_firma = "C"   # las firmas viven en columna C hacia abajo
    for dia_idx, dia in enumerate(facultad.dias):
        for turno in range(1, facultad.turnos + 1):
            for aula in facultad.aulas:
                # Para cada año, ¿hay algún grupo de ese año con esa aula en (dia,turno)?
                presencias = []       # texto de fórmula booleana por año
                etiquetas = []        # código del año
                for cod, grupos in anios_por_codigo.items():
                    partes = [
                        f'COUNTIF({quote_sheetname(g.id)}!{L.celda_aula(dia_idx, turno)},"{aula}")'
                        for g in grupos
                    ]
                    presencias.append(f'({"+".join(partes)})>0')
                    etiquetas.append(cod)
                # n_años presentes
                suma = "+".join(f"IF({p},1,0)" for p in presencias)
                # código si exactamente 1, "MIX" si >1, "" si 0
                # se construye anidando: elige el año cuyo presencia es verdadera cuando total=1
                elegir = '""'
                for p, cod in zip(reversed(presencias), reversed(etiquetas)):
                    elegir = f'IF({p},"{cod}",{elegir})'
                formula = f'=IF(({suma})=0,"",IF(({suma})=1,{elegir},"MIX"))'
                dir_firma = f"{col_firma}{fila}"
                ws[dir_firma] = formula
                celdas[(dia, turno, aula)] = f"{NOMBRE_HOJA}!{dir_firma}"
                fila += 1
    return celdas
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `python -m pytest tests/test_hoja_datos.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add horarios/hoja_datos.py tests/test_hoja_datos.py
git commit -m "feat: hoja Datos (lista de aulas + firmas de año para deteccion de conflicto)"
```

---

## Task 8: Hoja Aulas

**Files:**
- Create: `horarios/hoja_aulas.py`
- Test: `tests/test_hoja_aulas.py`

5 bloques (uno por día); columnas = aulas; filas = turnos; celda = grupos que ocupan esa
aula/turno/día (fórmula de concatenación). Formato condicional por año (usando la firma de
`Datos`) + regla de conflicto (`MIX`).

- [ ] **Step 1: Escribir tests que fallan**

```python
# tests/test_hoja_aulas.py
from openpyxl import Workbook
from horarios.modelo import Grupo, Anio, Facultad
from horarios.hoja_datos import construir_hoja_datos
from horarios.hoja_aulas import construir_hoja_aulas, NOMBRE_HOJA

def _fac():
    g = [Grupo("C",1,1,1), Grupo("C",1,1,2)]
    anios = {"C1": Anio("C",1,())}
    return Facultad(aulas=("Aula 1","Lab"), dias=("Lunes","Martes"), turnos=2, grupos=tuple(g), anios=anios)

def test_celda_ocupacion_es_formula_de_grupos():
    fac = _fac(); wb = Workbook()
    firmas = construir_hoja_datos(wb, fac)
    construir_hoja_aulas(wb, fac, firmas)
    ws = wb[NOMBRE_HOJA]
    # alguna celda del bloque debe referenciar una hoja de grupo y concatenar
    formulas = [c.value for row in ws.iter_rows() for c in row if isinstance(c.value, str) and c.value.startswith("=")]
    assert any("C111" in f for f in formulas)

def test_tiene_un_bloque_por_dia():
    fac = _fac(); wb = Workbook()
    firmas = construir_hoja_datos(wb, fac)
    construir_hoja_aulas(wb, fac, firmas)
    ws = wb[NOMBRE_HOJA]
    textos = [c.value for row in ws.iter_rows() for c in row]
    assert "Lunes" in textos and "Martes" in textos
```

- [ ] **Step 2: Correr y ver que falla**

Run: `python -m pytest tests/test_hoja_aulas.py -q`
Expected: FAIL.

- [ ] **Step 3: Implementar `hoja_aulas.py`**

```python
# horarios/hoja_aulas.py
from openpyxl.utils import get_column_letter, quote_sheetname
from horarios import layout as L
from horarios import estilos

NOMBRE_HOJA = "Aulas"

def _formula_ocupacion(facultad, dia_idx, turno, aula):
    partes = [
        f'IF({quote_sheetname(g.id)}!{L.celda_aula(dia_idx, turno)}="{aula}","{g.id} ","")'
        for g in facultad.grupos
    ]
    concat = "&".join(partes)
    return f'=SUBSTITUTE(TRIM({concat}),\" \",\",\")'

def construir_hoja_aulas(wb, facultad, firmas):
    ws = wb.create_sheet(NOMBRE_HOJA, index=0)
    fila = 1
    for dia_idx, dia in enumerate(facultad.dias):
        # Encabezado del bloque
        ws.cell(row=fila, column=1, value=dia)
        for j, aula in enumerate(facultad.aulas, start=2):
            ws.cell(row=fila, column=j, value=aula)
        fila += 1
        base_encabezado = fila - 1
        for turno in range(1, facultad.turnos + 1):
            ws.cell(row=fila, column=1, value=f"Turno {turno}")
            for j, aula in enumerate(facultad.aulas, start=2):
                celda = ws.cell(row=fila, column=j,
                                value=_formula_ocupacion(facultad, dia_idx, turno, aula))
                _formato_por_anio(ws, celda, firmas[(dia, turno, aula)])
            fila += 1
        fila += 1  # línea en blanco entre bloques

def _formato_por_anio(ws, celda, dir_firma):
    coord = celda.coordinate
    # Una regla por año: si la firma == código de año, pinta con su color
    for cod, color in estilos.ANIO_COLOR.items():
        ws.conditional_formatting.add(
            coord, estilos.regla_formula(f'{dir_firma}="{cod}"', color))
    # Conflicto: firma == "MIX"
    ws.conditional_formatting.add(
        coord, estilos.regla_formula(f'{dir_firma}="MIX"', estilos.COLOR_CONFLICTO))
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `python -m pytest tests/test_hoja_aulas.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add horarios/hoja_aulas.py tests/test_hoja_aulas.py
git commit -m "feat: hoja Aulas (ocupacion por formula + color por anio + conflicto)"
```

---

## Task 9: Generador (orquestador)

**Files:**
- Create: `horarios/generador.py`
- Test: `tests/test_generador.py`

- [ ] **Step 1: Escribir tests que fallan**

```python
# tests/test_generador.py
from openpyxl import load_workbook
from horarios.config import cargar_facultad
from horarios.generador import generar

BASE = """
aulas: [Aula 1, Lab]
dias: [Lunes, Martes]
turnos: 6
carreras:
  C:
    nombre: Carrera C
    años:
      1:
        sesiones: { 1: { grupos: [1, 2] } }
        asignaturas:
          - { id: L-C, nombre: "Lógica", frecuencia: 1 }
"""

def test_genera_workbook_con_hojas(tmp_path):
    cfg = tmp_path / "facultad.yaml"; cfg.write_text(BASE, encoding="utf-8")
    salida = tmp_path / "out.xlsx"
    generar(config_path=cfg, horarios_path=None, salida=salida)
    wb = load_workbook(salida)
    assert "Aulas" in wb.sheetnames
    assert "C111" in wb.sheetnames and "C112" in wb.sheetnames
    assert "Datos" in wb.sheetnames
    assert wb["Datos"].sheet_state == "hidden"
```

- [ ] **Step 2: Correr y ver que falla**

Run: `python -m pytest tests/test_generador.py -q`
Expected: FAIL.

- [ ] **Step 3: Implementar `generador.py`**

```python
# horarios/generador.py
from openpyxl import Workbook
from horarios.config import cargar_facultad, cargar_horarios
from horarios.hoja_datos import construir_hoja_datos
from horarios.hoja_grupo import construir_hoja_grupo
from horarios.hoja_aulas import construir_hoja_aulas

def generar(config_path, horarios_path, salida):
    facultad = cargar_facultad(config_path)
    horarios = cargar_horarios(horarios_path, facultad)

    wb = Workbook()
    # Elimina la hoja por defecto; se crearán las nuestras.
    wb.remove(wb.active)

    # Hoja Datos primero (define AulasValidas y firmas que otras hojas usan).
    firmas = construir_hoja_datos(wb, facultad)

    # Una hoja por grupo.
    for grupo in facultad.grupos:
        ws = wb.create_sheet(grupo.id)
        construir_hoja_grupo(ws, grupo, facultad, horario=horarios.get(grupo.id))

    # Hoja Aulas (usa las firmas).
    construir_hoja_aulas(wb, facultad, firmas)

    wb.save(salida)
    return salida
```

> Ajuste: `hoja_grupo.construir_hoja_grupo` asigna `ws.title = grupo.id`; aquí ya se crea la hoja
> con ese nombre. Reconciliar en Step 4 (que no falle por título duplicado): dejar que el
> constructor use el `ws` recibido y no renombrar si ya coincide.

- [ ] **Step 4: Correr y ver que pasa**

Run: `python -m pytest tests/test_generador.py -q`
Expected: PASS. Si hay choque de nombre de hoja, ajustar el orden/renombrado.

- [ ] **Step 5: Correr toda la suite**

Run: `python -m pytest -q`
Expected: todos los tests en verde.

- [ ] **Step 6: Commit**

```bash
git add horarios/generador.py tests/test_generador.py
git commit -m "feat: generador que orquesta config -> workbook -> xlsx"
```

---

## Task 10: CLI

**Files:**
- Create: `generar.py`
- Test: `tests/test_cli.py`

- [ ] **Step 1: Escribir test que falla**

```python
# tests/test_cli.py
import subprocess, sys
from pathlib import Path

def test_cli_genera_archivo(tmp_path):
    cfg = tmp_path / "facultad.yaml"
    cfg.write_text(
        "aulas: [Aula 1]\ndias: [Lunes]\nturnos: 6\n"
        "carreras:\n  C:\n    nombre: C\n    años:\n      1:\n"
        "        sesiones: { 1: { grupos: [1] } }\n"
        "        asignaturas:\n          - { id: L-C, nombre: L, frecuencia: 1 }\n",
        encoding="utf-8")
    salida = tmp_path / "h.xlsx"
    r = subprocess.run(
        [sys.executable, "generar.py", "--config", str(cfg), "--salida", str(salida)],
        capture_output=True, text=True, cwd=Path(__file__).parent.parent)
    assert r.returncode == 0, r.stderr
    assert salida.exists()
```

- [ ] **Step 2: Correr y ver que falla**

Run: `python -m pytest tests/test_cli.py -q`
Expected: FAIL.

- [ ] **Step 3: Implementar `generar.py`**

```python
# generar.py
import argparse
from pathlib import Path
from horarios.generador import generar

def main():
    p = argparse.ArgumentParser(description="Genera el workbook de horarios.")
    p.add_argument("--config", default="config/facultad.yaml", type=Path)
    p.add_argument("--horarios", default=None, type=Path,
                   help="YAML de asignaciones (copia fiel). Sin él: esqueleto vacío.")
    p.add_argument("--salida", default="horarios.xlsx", type=Path)
    args = p.parse_args()
    ruta = generar(config_path=args.config, horarios_path=args.horarios, salida=args.salida)
    print(f"Generado: {ruta}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Correr y ver que pasa**

Run: `python -m pytest tests/test_cli.py -q`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add generar.py tests/test_cli.py
git commit -m "feat: CLI generar.py"
```

---

## Task 11: Copia fiel + verificación manual en LibreOffice

**Files:**
- Create: `config/horarios.yaml` (derivado de la demo del tutor)

- [ ] **Step 1: Escribir `config/horarios.yaml`** con las asignaciones de C111/C112/C113 de la demo (`propuesta-de-horarios-2026-07-03-para-enviar.ods`).

- [ ] **Step 2: Generar la copia fiel**

Run: `python generar.py --horarios config/horarios.yaml --salida propuesta-generada.xlsx`
Expected: "Generado: propuesta-generada.xlsx".

- [ ] **Step 3: Verificación manual (fórmulas vivas)**

Abrir `propuesta-generada.xlsx` en LibreOffice y confirmar:
- `Asignadas`/`Faltan` se recalculan; `Frec` exacta → verde, sobre-planificada → rojo.
- Aula fuera de la lista → amarillo; asignatura desconocida → naranja.
- Hoja `Aulas` muestra los grupos por aula/turno/día y colorea por año; años distintos → conflicto.

Documentar en un breve `NOTAS.md` cualquier discrepancia contra la demo para el próximo batch.

- [ ] **Step 4: Commit**

```bash
git add config/horarios.yaml
git commit -m "feat: horarios de ejemplo (copia fiel de la demo del tutor)"
```

---

## Cierre

Al terminar: `python -m pytest -q` en verde y un `.xlsx` que, abierto en LibreOffice/Excel,
reproduce y mejora la prueba de concepto del tutor. Siguientes batches del tutor se implementan
extendiendo `config/*.yaml` (más años/carreras) y, si hace falta, `layout.py` (parametrización).
```
