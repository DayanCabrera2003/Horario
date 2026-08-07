"""Transcripcion del horario del Primer Periodo 2024-2025 de MATCOM (PDF de
Gianni), leida pagina por pagina. Datos puros, sin logica: la conversion a YAML la
hace `extraccion.horario_pdf`.

- TABLAS: por (carrera, año), la abreviatura de cada asignatura -> su nombre. Se usa
  la abreviatura TAL COMO aparece en la rejilla (p. ej. 'A I', 'EDA I'), que a veces
  difiere de la tabla de profesores.
- GRUPOS: por grupo, turno -> día -> celda cruda (tal cual el PDF). Las celdas
  vacias se omiten. Los numeros de turno son los impresos en el PDF.
"""

TABLAS = {
    # --- Ciencia de Datos ---
    ("D", 1): {"AL": "Álgebra Lineal", "L": "Lógica", "IP": "Introducción a la Programación",
               "ICD": "Introducción a la Ciencia de Datos", "AM I": "Análisis Matemático I",
               "F": "Filosofía", "EF": "Educación Física I"},
    ("D", 2): {"MA": "Matemática y Aplicaciones", "Prb": "Probabilidades", "BD": "Bases de Datos",
               "ED": "Estructura de Datos", "VD": "Visualización de Datos", "EP": "Economía Política",
               "EF": "Educación Física III"},
    ("D", 3): {"AE2": "Análisis Estadístico II", "MDE": "Muestreo y Diseño de Experimentos",
               "RN": "Redes Neuronales", "PL": "Procesamiento del Lenguaje",
               "PGVD": "Procesamiento de Grandes Volúmenes de Datos", "TP": "Teoría Política"},
    # --- Ciencia de la Computacion ---
    ("C", 1): {"A I": "Álgebra I", "L": "Lógica", "P": "Programación",
               "AM I": "Análisis Matemático I", "F": "Filosofía", "EF": "Educación Física I"},
    ("C", 2): {"EDA I": "Estructuras de Datos y Algoritmos I", "MD": "Matemática Discreta I",
               "AC": "Arquitectura de computadoras", "EDO": "Ecuaciones Diferenciales Ordinarias",
               "MN": "Matemática Numérica", "TP": "Teoría Política", "EF": "Educación Física III"},
    ("C", 3): {"RC": "Redes de Computadoras", "IS": "Ingeniería de Software",
               "MO": "Modelos de Optimización", "BD2": "Bases de Datos II",
               "PD": "Programación Declarativa", "Est": "Estadística"},
    ("C", 4): {"AM": "Aprendizaje de Máquinas", "DAA": "Diseño y Análisis de Algoritmos",
               "SD": "Sistemas Distribuidos", "AE": "Asignatura Electiva",
               "ECTS": "Estudios de Ciencia, Tecnología y Sociedad",
               "SN/DN": "Seguridad Nacional / Defensa Nacional"},
    ("C", 5): {"HC": "Historia de la Computación", "MI": "Metodología de la Investigación",
               "CE": "Culminación de Estudios"},
    # --- Matematica ---
    ("M", 1): {"IAM": "Introducción al Análisis Matemático", "IA": "Introducción al Álgebra",
               "GA": "Geometría Analítica", "PA": "Programación y Algoritmos",
               "IM": "Introducción a la Matemática", "F": "Filosofía", "EF": "Educación Física I"},
    ("M", 2): {"FVV": "Funciones de Varias Variables", "CAL": "Complementos de Álgebra Lineal",
               "SP2": "Seminario de Problemas II", "AE": "Asignatura Electiva I",
               "EP": "Economía Política", "EF": "Educación Física III"},
    ("M", 3): {"FVC": "Funciones de variable Compleja", "IE": "Inferencia Estadística",
               "EDO": "Ecuaciones Diferenciales Ordinarias", "MN": "Matemática Numérica",
               "OM": "Optimización Matemática I", "TP": "Teoría Política",
               "AO1": "Asignatura Optativa I"},
    ("M", 4): {"MI": "Medida e Integración", "GD": "Geometría Diferencial",
               "HM": "Historia de la Matemática", "ECTS": "ECTS",
               "AO2": "Asignatura Optativa II", "AO3": "Asignatura Optativa III"},
    ("M", 5): {"AF": "Análisis Funcional", "AO4": "Asignatura Optativa IV",
               "SI": "Seminario de Investigación", "CE": "Culminación de Estudios"},
}

GRUPOS = {
    # ===================== Ciencia de Datos =====================
    "D111": {
        1: {"Lunes": "IP Aula 8*", "Martes": "ICD Aula 7", "Miércoles": "AL Aula 7*",
            "Jueves": "AM I Aula 7*"},
        2: {"Lunes": "F Aula 7", "Martes": "AL Aula 6*", "Miércoles": "EF SEDER",
            "Jueves": "AL Aula 7*", "Viernes": "F Aula 7 (s. 1-8) / ICD Aula 7 (s. 9-16)"},
        3: {"Lunes": "L Aula 6*", "Martes": "AM I Aula 6*", "Miércoles": "AM I Aula 7*",
            "Jueves": "IP Lab*", "Viernes": "L Aula 7*"},
    },
    "D211": {
        4: {"Lunes": "ED c 2", "Martes": "BD c 2", "Miércoles": "MA (EDO) cp 6 (con C211)",
            "Jueves": "BD cp 2"},
        5: {"Lunes": "MA (EDO) c 6 (con C211)", "Martes": "EP c 3 (con M2)",
            "Miércoles": "EP c 3 (con M2, semanas 1 a la 8)", "Jueves": "Prb cp 2"},
        6: {"Lunes": "VD c 2", "Martes": "Prb c 2", "Miércoles": "EF 4:45pm a 5:35pm",
            "Jueves": "ED cp 2"},
    },
    "D311": {
        4: {"Lunes": "AE2 c 2", "Martes": "RN c 2", "Jueves": "TP 4 (con M3, s. 2, 4, 6, 8, 10)"},
        5: {"Lunes": "MDE c 2", "Martes": "PL c 2", "Miércoles": "MDE cp 2", "Jueves": "RN cp Lab2"},
        6: {"Lunes": "TP c 4 (con M3)", "Martes": "PGVD c 2", "Miércoles": "AE2 cp Lab2",
            "Jueves": "PGVD cp 7"},
    },
    # ===================== Ciencia de la Computacion =====================
    "C111": {
        1: {"Martes": "P Aula 6", "Miércoles": "A I Aula 6*", "Jueves": "AM I Aula 6*",
            "Viernes": "F Aula 6 (s. 1 a la 5)"},
        2: {"Lunes": "F Aula 6", "Martes": "A I Aula 6*", "Miércoles": "EF SEDER",
            "Jueves": "A I Aula 6*", "Viernes": "P Lab"},
        3: {"Lunes": "L Aula 6*", "Martes": "AM I Aula 6*", "Miércoles": "AM I Aula 6*",
            "Jueves": "P Aula 6", "Viernes": "L Aula 6*"},
    },
    "C112": {
        1: {"Martes": "P Aula 6", "Miércoles": "A I Aula 1", "Jueves": "AM I Aula 1",
            "Viernes": "F Aula 1 (s. 1 a la 5)"},
        2: {"Lunes": "F Aula 6", "Martes": "A I Aula 6*", "Miércoles": "EF SEDER",
            "Jueves": "P Aula 1", "Viernes": "L Aula 1"},
        3: {"Lunes": "L Aula 6*", "Martes": "AM I Aula 6*", "Miércoles": "AM I Aula 1",
            "Jueves": "A I Aula 1", "Viernes": "P Lab"},
    },
    "C121": {
        1: {"Martes": "A I Aula 5", "Miércoles": "AM I Aula 5", "Jueves": "P Lab",
            "Viernes": "L Aula 5"},
        2: {"Lunes": "L Aula 5", "Martes": "AM I Aula 5", "Miércoles": "EF SEDER",
            "Jueves": "A I Aula 5", "Viernes": "P Aula 5"},
        3: {"Lunes": "F Aula 5", "Martes": "P Aula 5", "Miércoles": "A I Aula 5",
            "Jueves": "AM I Aula 5", "Viernes": "F Aula 5 (s. 1 a la 5)"},
    },
    "C122": {
        1: {"Martes": "A I Aula 5", "Miércoles": "AM I Aula 2", "Jueves": "A I Aula 2",
            "Viernes": "P Lab"},
        2: {"Lunes": "L Aula 5", "Martes": "AM I Aula 5", "Miércoles": "EF SEDER",
            "Jueves": "AM I Aula 2", "Viernes": "L Aula 2"},
        3: {"Lunes": "F Aula 5", "Martes": "P Aula 5", "Miércoles": "A I Aula 2",
            "Jueves": "P Aula 2", "Viernes": "F Aula 2 (s. 1 a la 5)"},
    },
    "C211": {
        4: {"Lunes": "EDA I c 6", "Martes": "MD c6", "Miércoles": "EDO cp 6 (con D2)",
            "Jueves": "MN c 6", "Viernes": "MD cp 6"},
        5: {"Lunes": "EDO c 6 (con D2)", "Martes": "MN c 6", "Miércoles": "TP c 6",
            "Jueves": "TP c 6 (semanas 1 a la 8)", "Viernes": "AC lab"},
        6: {"Lunes": "AC c 6", "Martes": "EDA I cp 6", "Miércoles": "EF 4:45pm a 5:35pm"},
    },
    "C212": {
        4: {"Lunes": "EDA I c 6", "Martes": "MD c6", "Miércoles": "EDO I cp 5",
            "Jueves": "MN c 5", "Viernes": "AC lab"},
        5: {"Lunes": "EDO c 6", "Martes": "MN c 6", "Miércoles": "TP c 6",
            "Jueves": "TP c 5 (semanas 1 a la 8)", "Viernes": "MD cp 5"},
        6: {"Lunes": "AC c 6", "Martes": "EDA I cp 5", "Miércoles": "EF 4:45pm a 5:35pm"},
    },
    "C311": {
        1: {"Lunes": "Est Aula 9", "Martes": "BD2 Aula 9", "Miércoles": "PD cp Aula 9",
            "Jueves": "BD2 cp Aula 9"},
        2: {"Lunes": "IS c Aula 9", "Martes": "PD c Aula 9", "Miércoles": "Est cp Aula 9",
            "Jueves": "IS c/s Aula 9"},
        3: {"Lunes": "RC Aula 9", "Martes": "MO Aula 9", "Miércoles": "RC cp Aula 9",
            "Jueves": "MO Aula 9"},
    },
    "C312": {
        1: {"Lunes": "Est Aula 9", "Martes": "BD2 Aula 9", "Miércoles": "PD cp Aula 3",
            "Jueves": "BD2 cp Aula 3"},
        2: {"Lunes": "IS c Aula 9", "Martes": "PD c Aula 9", "Miércoles": "Est cp Aula 3",
            "Jueves": "IS c/s Aula 3"},
        3: {"Lunes": "RC Aula 9", "Martes": "MO Aula 9", "Miércoles": "RC cp Aula 3",
            "Jueves": "MO cp Aula 3"},
    },
    "C411": {
        4: {"Lunes": "AM 9", "Martes": "DAA 9", "Miércoles": "DAA 9", "Jueves": "SN/DN 9"},
        5: {"Lunes": "ECTS 9", "Martes": "SN/DN 9", "Miércoles": "AM 9",
            "Jueves": "SN/DN 9 (semana 1)"},
        6: {"Lunes": "SD 9", "Martes": "AE 9", "Miércoles": "SD 9"},
    },
    "C412": {
        4: {"Lunes": "AM 9", "Martes": "DAA 9", "Miércoles": "DAA 9", "Jueves": "SN/DN 9"},
        5: {"Lunes": "ECTS 9", "Martes": "SN/DN 9", "Miércoles": "AM 9",
            "Jueves": "SN/DN 9 (semana 1)"},
        6: {"Lunes": "SD 9", "Martes": "AE 9", "Miércoles": "SD 9"},
    },
    "C511": {
        1: {"Lunes": "MI c 3", "Martes": "MI cp 3"},
        2: {"Lunes": "HC c 3"},
    },
    "C512": {
        1: {"Lunes": "MI c 3", "Martes": "MI cp 3"},
        2: {"Lunes": "HC c 3"},
    },
    # ===================== Matematica =====================
    "M111": {
        1: {"Lunes": "PA Aula 5", "Martes": "IM Aula 8", "Miércoles": "IAM Aula 8",
            "Jueves": "IA Aula 8", "Viernes": "IA Aula 8"},
        2: {"Lunes": "GA Aula 8", "Martes": "GA Aula 8", "Miércoles": "EF SEDER",
            "Jueves": "PA Aula Lab", "Viernes": "IAM Aula 8"},
        3: {"Lunes": "IAM Aula 8", "Martes": "F Aula 8", "Miércoles": "IA Aula 8",
            "Jueves": "F Aula 8", "Viernes": "GA Aula 8"},
    },
    "M211": {
        3: {"Lunes": "CAL c 3", "Martes": "CAL c 3"},
        4: {"Lunes": "FVV c 3", "Martes": "FVV c 3", "Miércoles": "FVV cp 3", "Jueves": "CAL cp 3"},
        5: {"Lunes": "Inglés c 3", "Martes": "EP c 3 (con D2)",
            "Miércoles": "EP c 3 (con D2, semanas 1 a la 8)", "Jueves": "FVV cp 3"},
        6: {"Miércoles": "EF 4:45pm a 5:35pm", "Jueves": "SP2"},
    },
    "M311": {
        1: {"Lunes": "MN Aula 4 (s. impares)", "Martes": "EDO Aula 4", "Miércoles": "MN 4",
            "Jueves": "FVC (s. impares) 4 / TP 4 (con D3, s. 2, 4, 6, 8, 10)", "Viernes": "FVC Aula 4"},
        2: {"Lunes": "IE Aula 4", "Martes": "FVC Aula 4", "Miércoles": "EDO Aula 4",
            "Jueves": "IE Aula 4"},
        3: {"Lunes": "TP Aula 4 (con D3)", "Martes": "OM Aula 4", "Miércoles": "IE Aula 4",
            "Jueves": "OM Aula 4", "Viernes": "AO1"},
    },
    "M411": {
        4: {"Lunes": "GD 4", "Martes": "HM 4", "Miércoles": "MI 4", "Jueves": "AO2"},
        5: {"Lunes": "MI 4", "Martes": "HM 4", "Miércoles": "GD 4", "Jueves": "AO3"},
        6: {"Lunes": "ECTS 4", "Martes": "GD 4"},
    },
    "M511": {
        1: {"Martes": "AO IV"},
        2: {"Lunes": "AF c 1", "Martes": "AF cp 1"},
        3: {"Lunes": "AF c 1", "Martes": "AF cp 1"},
    },
}
