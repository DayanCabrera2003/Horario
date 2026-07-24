"""Colores de dominio del generador de horarios de clases. Las primitivas de
estilo genericas (fill, reglas, bordes, fuentes) viven en `comun.estilos_base`
y se reexportan aqui para no tocar el resto del paquete `horarios`."""
from comun.estilos_base import (  # noqa: F401
    fill, regla_formula, lado_fino, lado_medio, borde_fino,
    alineacion_ajuste, fuente_encabezado,
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
COLOR_ENCABEZADO = "D9D9D9"        # gris claro neutro para cabeceras
