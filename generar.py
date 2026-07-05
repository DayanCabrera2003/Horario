"""CLI entry point: genera el workbook de horarios desde la línea de comandos."""
import argparse
import sys
from pathlib import Path

from horarios.config import ErrorConfig
from horarios.generador import generar


def main() -> None:
    """Parsea argumentos, llama a generar() e imprime la ruta del archivo generado."""
    p = argparse.ArgumentParser(description="Genera el workbook de horarios.")
    p.add_argument("--config", default="config/facultad.yaml", type=Path)
    p.add_argument(
        "--horarios",
        default=None,
        type=Path,
        help="YAML de asignaciones (copia fiel). Sin él: esqueleto vacío.",
    )
    p.add_argument("--salida", default="horarios.xlsx", type=Path)
    args = p.parse_args()

    try:
        ruta = generar(config_path=args.config, horarios_path=args.horarios, salida=args.salida)
    except ErrorConfig as e:
        print(f"Error de configuración: {e}", file=sys.stderr)
        raise SystemExit(1)

    print(f"Generado: {ruta}")


if __name__ == "__main__":
    main()
