"""CLI: genera facultad.yaml y horarios.yaml a partir de la transcripcion del PDF
de Gianni (modulo `extraccion.datos_horario_2024`), mas un informe de incidencias.

Uso:
    python importar_horario.py \
        --facultad facultad.yaml \
        --horarios horarios.yaml \
        --incidencias incidencias-horario.md
"""
import argparse

from extraccion import horario_pdf
from extraccion.datos_horario_2024 import GRUPOS, TABLAS


def main() -> None:
    parser = argparse.ArgumentParser(description="Genera el YAML del horario desde la transcripcion.")
    parser.add_argument("--facultad", default="facultad.yaml")
    parser.add_argument("--horarios", default="horarios.yaml")
    parser.add_argument("--incidencias", default="incidencias-horario.md")
    args = parser.parse_args()

    datos = horario_pdf.construir(GRUPOS, TABLAS)
    horario_pdf.escribir_yaml(datos, args.facultad, args.horarios)
    horario_pdf.escribir_incidencias(datos, args.incidencias)

    fac = datos["facultad"]
    n_asig = sum(len(a["años"][y]["asignaturas"])
                 for c, a in fac["carreras"].items() for y in a["años"])
    print(f"Carreras: {len(fac['carreras'])}  Aulas: {len(fac['aulas'])}  "
          f"Turnos: {fac['turnos']}  Asignaturas: {n_asig}  "
          f"Grupos con horario: {len(datos['horarios'])}")
    print(f"Incidencias: {len(datos['incidencias'])} (ver {args.incidencias})")
    print(f"Generados: {args.facultad}, {args.horarios}, {args.incidencias}")


if __name__ == "__main__":
    main()
