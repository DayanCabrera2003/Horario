"""Colores de dominio del generador de tribunales. Las primitivas de estilo
genericas se reexportan desde `comun.estilos_base`."""
from comun.estilos_base import (  # noqa: F401
    fill, regla_formula, lado_fino, lado_medio, borde_fino,
    alineacion_ajuste, fuente_encabezado,
)

COLOR_ENCABEZADO = "D9D9D9"       # gris claro neutro para cabeceras
COLOR_COLISION = "E53935"         # rojo intenso: profesor en 2+ locales a la vez
COLOR_LOCALIZADO = "FFF176"       # amarillo: momento donde participa la persona buscada

# Colores de pestana, por tipo de hoja. Son de navegacion, no de aviso: se
# eligen fuera de la gama de rojos, amarillos y verdes, que en este libro ya
# significan colision o coincidencia de busqueda. Distinguen la hoja donde se
# escribe a mano de las que solo muestran resultados, igual que hace el indice
# de la portada.
COLOR_PESTANA_ENTRADA = "90CAF9"   # azul: aqui se escribe
COLOR_PESTANA_CALCULO = "B0BEC5"   # gris azulado: esto se calcula solo
COLOR_PESTANA_DATOS = "B39DDB"     # morado: los datos del problema
