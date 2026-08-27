import pytest

from comun.validacion import es_entero


@pytest.mark.parametrize("valor", [0, 1, -3, 160])
def test_los_enteros_pasan(valor):
    assert es_entero(valor) is True


@pytest.mark.parametrize("valor", [True, False])
def test_los_booleanos_no_pasan(valor):
    # Es el caso que motiva la funcion: `bool` hereda de `int`, asi que sin esta
    # comprobacion `turnos: true` en el YAML valdria como `turnos: 1`.
    assert es_entero(valor) is False


@pytest.mark.parametrize("valor", [None, "8", 2.5, [], {}, 2.0])
def test_lo_que_no_es_entero_no_pasa(valor):
    # 2.0 tambien se rechaza: un float redondo no es un entero, y aceptarlo
    # abriria la puerta a 2.5 por la misma via.
    assert es_entero(valor) is False
