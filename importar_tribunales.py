"""CLI: importa los Excel de tribunales de Carmen y genera tribunal.yaml,
asignaciones.yaml y un informe de revision.

Uso:
    python importar_tribunales.py EXCEL [EXCEL ...] \
        --tribunal salida/tribunal.yaml \
        --asignaciones salida/asignaciones.yaml \
        --revision salida/revision.md
"""
import argparse

from extraccion.tribunales_excel import importar, escribir_yaml, escribir_revision


def main() -> None:
    parser = argparse.ArgumentParser(description="Importa Excel de tribunales a YAML.")
    parser.add_argument("excel", nargs="+", help="uno o varios .xlsx de tribunales")
    parser.add_argument("--tribunal", default="tribunal.yaml",
                        help="ruta del tribunal.yaml a generar")
    parser.add_argument("--asignaciones", default="asignaciones.yaml",
                        help="ruta del asignaciones.yaml a generar")
    parser.add_argument("--revision", default="revision-tribunales.md",
                        help="ruta del informe de revision a generar")
    args = parser.parse_args()

    datos = importar(args.excel)
    escribir_yaml(datos, args.tribunal, args.asignaciones)
    escribir_revision(datos, args.revision)

    fac = datos["facultad"]
    print(f"Profesores: {len(fac['profesores'])}  Estudiantes: {len(fac['estudiantes'])}  "
          f"Locales: {len(fac['locales'])}  Dias: {len(fac['dias'])}  "
          f"Tesis: {len(fac['tesis'])}  Asignaciones: {len(datos['asignaciones'])}")
    print(f"Incidencias: {len(datos['revision']['incidencias'])} (ver {args.revision})")
    print(f"Generados: {args.tribunal}, {args.asignaciones}, {args.revision}")


if __name__ == "__main__":
    main()
