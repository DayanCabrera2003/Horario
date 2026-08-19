"""Colores de dominio del generador de gestion del departamento. Las primitivas
de estilo genericas se reexportan desde `comun.estilos_base`. La paleta coincide
con la de los otros generadores para que las alertas se lean igual en todos."""
from comun.estilos_base import (  # noqa: F401
    fill, regla_formula, lado_fino, lado_medio, borde_fino,
    alineacion_ajuste, alineacion_padding, fuente_encabezado,
)

# Alto de fila (puntos) de las tablas: parte del padding aproximado para Calc,
# junto con la sangria y el centrado vertical de `alineacion_padding`.
ALTO_FILA = 22

COLOR_ENCABEZADO = "D9D9D9"            # gris claro neutro para cabeceras
COLOR_SIN_PROFESOR = "FFF176"          # amarillo: fila de carga sin profesor
COLOR_PROFESOR_DESCONOCIDO = "FFB74D"  # ambar: id fuera de la lista de profesores
COLOR_SOBRECARGA = "EF9A9A"            # rojo: profesor por encima de su tope
COLOR_COMPLETA = "A5D6A7"              # verde: asignatura con todo asignado
COLOR_INCOMPLETA = "FFCC80"            # naranja: asignatura con filas sin profesor
