"""Colores de dominio del generador de horarios de clases. Las primitivas de
estilo genericas (fill, reglas, bordes, fuentes) viven en `comun.estilos_base`
y se reexportan aqui para no tocar el resto del paquete `horarios`."""
from comun.estilos_base import (  # noqa: F401
    fill, regla_formula, lado_fino, lado_medio, lado_grueso, borde_fino,
    alineacion_ajuste, alineacion_padding, fuente_encabezado,
)

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
# Rojo intermedio: turno con aula puesta pero sin asignatura. Elegido para no
# confundirse con COLOR_SOBRE_PLANIFICADA (rosado) ni con COLOR_CONFLICTO
# (rojo oscuro), que son los otros dos rojos de la paleta.
COLOR_AULA_SIN_ASIG = "EF5350"
COLOR_ENCABEZADO = "D9D9D9"        # gris claro neutro para cabeceras
COLOR_FONDO_AULA = "ECEFF1"        # gris azulado muy claro: marca donde van las aulas

# Colores de pestana, por ano. Son de navegacion, no de aviso: se eligen fuera
# de la gama de rojos, amarillos y verdes, que en este libro ya significan
# conflicto, falta o frecuencia exacta. Se recorren ciclicamente si hubiera mas
# anos que colores.
COLORES_PESTANA_ANIO = (
    "90CAF9",   # azul
    "B39DDB",   # morado
    "80CBC4",   # verde azulado
    "9FA8DA",   # indigo
    "BCAAA4",   # marron grisaceo
    "B0BEC5",   # gris azulado
)


def color_pestana_anio(anio: int) -> str:
    """Color de pestana que le toca al ano `anio` (base 1)."""
    return COLORES_PESTANA_ANIO[(anio - 1) % len(COLORES_PESTANA_ANIO)]
