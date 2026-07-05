# Notas de la copia fiel (Task 11)

## Cómo generar

```bash
# Esqueleto vacío (todas las hojas + fórmulas + formato, horario sin llenar):
python generar.py --salida esqueleto.xlsx

# "Copia fiel" (con el horario de ejemplo cargado):
python generar.py --horarios config/horarios.yaml --salida propuesta-generada.xlsx
```

## Qué contiene el ejemplo (`config/horarios.yaml`)

Horario coherente para **C111, C112, C113** (los 3 grupos de C1 sesión 1):
- Las **conferencias** (`-C`) son compartidas por los 3 grupos en **Aula 1**.
- Las **clases prácticas** (`-CP`) y **EF** van en el aula propia de cada grupo (Aula 2 / 3 / 4 / Lab).
- Cada asignatura se planifica **exactamente su frecuencia**, así toda la tabla de asignaturas
  queda en verde.

## Verificación automática (LibreOffice headless + recálculo)

Se regeneró el archivo, se recalculó con `libreoffice --headless --convert-to xlsx` y se leyeron
los valores cacheados. Resultado:

- **Tabla de asignaturas de C111**: las 11 asignaturas dan `Asignadas == Frec` y `Faltan == 0`
  (el `COUNTIF` y la resta evalúan correctamente).
- **Hoja `Aulas`** (ocupación calculada cruzando las hojas de grupo):
  - `Aula 1` / Lunes T1 → `C111,C112,C113` (conferencia compartida, los 3 concatenados con coma).
  - `Aula 2` / `Aula 3` / `Aula 4` / Lunes T2 → `C111` / `C112` / `C113` (prácticas separadas).
  - `Lab` / Viernes T2 → `C111,C112,C113` (EF compartida).

Es decir: las **fórmulas vivas** (Asignadas/Faltan, ocupación de aulas) funcionan de punta a punta.

## Verificación manual pendiente (paso humano)

Abrir `propuesta-generada.xlsx` en LibreOffice/Excel y confirmar visualmente:
- Tabla de asignaturas en **verde** (frecuencia exacta). Para ver **rojo** (sobre-planificada),
  duplicar a mano una asignatura por encima de su frecuencia; para ver **naranja**, escribir una
  abreviatura que no exista; para ver **amarillo**, poner un aula que no esté en la lista.
- Hoja `Aulas`: color por "año" (todo C1 → un mismo color).
- Dropdowns de aula y asignatura al hacer clic en las celdas del horario.

## Limitaciones conocidas / próximos pasos

- **Conflicto entre años (`MIX`)** no se puede demostrar todavía: `config/facultad.yaml` solo tiene
  la carrera C, año 1. La detección de conflicto (aula compartida por años distintos → rojo intenso)
  requiere tener grupos de años/carreras distintos en la config. Se activará al ir llenando la
  facultad completa (C2–C4, M, D) en los próximos "batches" del tutor.
- **Longitud de fórmulas a escala**: la firma de año (hoja `Datos`) tiene un `COUNTIF` por grupo y
  por año en cada celda, y la ocupación (hoja `Aulas`) un `IF` por grupo. Con la config actual (una
  carrera, un año) es trivial, pero al llenar la facultad completa (C2–C4, M, D → decenas de grupos)
  las fórmulas de firma pueden acercarse al límite de Excel (~8192 caracteres por celda). A vigilar
  cuando el tutor cargue más años; si hiciera falta, se optimiza la firma (p. ej. `SUMPRODUCT` o
  celdas auxiliares por año).
- El horario de ejemplo está **normalizado** al esquema limpio de `config/facultad.yaml`. La prueba
  de concepto original del tutor (`.ods`) usaba abreviaturas e identificadores de aula inconsistentes
  (p. ej. `AM1-C` vs `AMI-C`, aulas como `6` en vez de `Aula 6`); se optó por un ejemplo coherente
  en vez de reproducir ese ruido. Si se quiere una réplica exacta de celdas concretas de la demo,
  se ajusta puntualmente.
