"""CLI: genera el workbook de gestion del departamento desde la linea de comandos."""
import argparse
import sys
from pathlib import Path

from departamento.config import ErrorConfig
from departamento.generador import generar


def main() -> None:
    p = argparse.ArgumentParser(
        description="Genera el workbook de gestion del departamento.")
    p.add_argument("--config", default="config/departamento.yaml", type=Path)
    p.add_argument("--salida", default="departamento.xlsx", type=Path)
    args = p.parse_args()

    try:
        ruta = generar(config_path=args.config, salida=args.salida)
    except ErrorConfig as e:
        print(f"Error de configuracion: {e}", file=sys.stderr)
        raise SystemExit(1)

    print(f"Generado: {ruta}")


if __name__ == "__main__":
    main()
