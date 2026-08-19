import subprocess
import sys
from pathlib import Path

CONFIG = """
departamento:
  nombre: Matemática Aplicada
  semestre: "2026-2027 / 1"
profesores:
  - {id: PIAD, nombre: "Pedro I. Alonso", grado: "Dr."}
asignaturas:
  - {id: EST-CC, nombre: "Estadística (CC)", carrera: "CC",
     horas_conf: 32, horas_cp: 32, grupos_cp: 2}
"""


def _correr(tmp_path, texto):
    cfg = tmp_path / "departamento.yaml"
    cfg.write_text(texto, encoding="utf-8")
    salida = tmp_path / "gestion.xlsx"
    raiz = Path(__file__).resolve().parents[1]
    r = subprocess.run(
        [sys.executable, "generar_departamento.py",
         "--config", str(cfg), "--salida", str(salida)],
        cwd=raiz, capture_output=True, text=True)
    return r, salida


def test_cli_genera_archivo(tmp_path):
    r, salida = _correr(tmp_path, CONFIG)
    assert r.returncode == 0, r.stderr
    assert salida.exists()


def test_cli_error_de_config(tmp_path):
    r, salida = _correr(tmp_path, CONFIG.replace("profesores:", "profesores: []\nx:"))
    assert r.returncode == 1
    assert "Error de configuracion" in r.stderr
    assert not salida.exists()
