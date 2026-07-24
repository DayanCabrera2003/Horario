"""CLI: genera el workbook de tribunales de tesis desde la linea de comandos."""
import argparse
import sys
from pathlib import Path

from tribunales.config import ErrorConfig
from tribunales.generador import generar


def main() -> None:
    p = argparse.ArgumentParser(description="Genera el workbook de tribunales de tesis.")
    p.add_argument("--config", default="config/tribunal.yaml", type=Path)
    p.add_argument("--asignaciones", default=None, type=Path,
                   help="YAML de asignaciones (copia fiel). Sin el: esqueleto vacio.")
    p.add_argument("--salida", default="tesis.xlsx", type=Path)
    args = p.parse_args()

    try:
        ruta = generar(config_path=args.config, asignaciones_path=args.asignaciones,
                       salida=args.salida)
    except ErrorConfig as e:
        print(f"Error de configuracion: {e}", file=sys.stderr)
        raise SystemExit(1)

    print(f"Generado: {ruta}")


if __name__ == "__main__":
    main()
