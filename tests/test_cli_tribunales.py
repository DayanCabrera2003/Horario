import subprocess, sys
from pathlib import Path


def test_cli_genera_archivo(tmp_path):
    cfg = tmp_path / "tribunal.yaml"
    cfg.write_text("""
profesores:
  - {id: PIAD, nombre: "Pedro", grado: "Dr."}
  - {id: MARA, nombre: "Maria", grado: "MSc."}
  - {id: LGOM, nombre: "Luis", grado: "Dr."}
  - {id: ANSU, nombre: "Ana", grado: "MSc."}
estudiantes:
  - {id: JPER, nombre: "Juan"}
locales:
  - {id: POST, nombre: "Postgrado"}
dias:
  - fecha: 2026-07-27
    momentos:
      - {inicio: "09:00", fin: "10:00"}
tesis:
  - {estudiante: JPER, tutor: PIAD, oponente: MARA, presidente: LGOM, secretario: ANSU}
""", encoding="utf-8")
    salida = tmp_path / "tesis.xlsx"
    raiz = Path(__file__).resolve().parents[1]
    r = subprocess.run(
        [sys.executable, "generar_tribunales.py", "--config", str(cfg), "--salida", str(salida)],
        cwd=raiz, capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    assert salida.exists()
