"""Comprobaciones de tipo sobre los valores que se leen de un YAML de
configuracion. No lee archivos ni construye el modelo: cada paquete valida sus
propios campos y compone aqui solo la regla de tipo, que es la misma en los tres.
"""


def es_entero(valor) -> bool:
    """True si `valor` es un entero de verdad.

    En Python `bool` hereda de `int`, asi que `isinstance(True, int)` es True y
    un booleano se colaria por entero. En un YAML eso importa: `turnos: true`
    valdria como `turnos: 1` y el libro saldria con un solo turno sin que nadie
    avise. Se excluyen a proposito para que el error salte al cargar.

    El rango (positivo, no negativo, mayor que cero) lo comprueba cada campo por
    su cuenta: aqui solo se decide si el valor es siquiera un entero.
    """
    return isinstance(valor, int) and not isinstance(valor, bool)
