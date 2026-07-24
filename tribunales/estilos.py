"""Colores de dominio del generador de tribunales. Las primitivas de estilo
genericas se reexportan desde `comun.estilos_base`."""
from comun.estilos_base import (  # noqa: F401
    fill, regla_formula, lado_fino, lado_medio, borde_fino,
    alineacion_ajuste, fuente_encabezado,
)

COLOR_ENCABEZADO = "D9D9D9"       # gris claro neutro para cabeceras
COLOR_COLISION = "E53935"         # rojo intenso: profesor en 2+ locales a la vez
COLOR_LOCALIZADO = "FFF176"       # amarillo: momento donde participa la persona buscada
