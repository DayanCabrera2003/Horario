"""Tests for the generar.py CLI entry point."""
import subprocess
import sys
from pathlib import Path

# Minimal valid YAML config shared across tests.
_CFG_VALIDO = (
    "aulas: [Aula 1]\ndias: [Lunes]\nturnos: 6\n"
    "carreras:\n  C:\n    nombre: C\n    años:\n      1:\n"
    "        sesiones: { 1: { grupos: [1] } }\n"
    "        asignaturas:\n          - { id: L-C, nombre: L, frecuencia: 1 }\n"
)


def test_cli_genera_archivo(tmp_path):
    """Happy path: valid config produces an .xlsx file and exits 0."""
    cfg = tmp_path / "facultad.yaml"
    cfg.write_text(_CFG_VALIDO, encoding="utf-8")
    salida = tmp_path / "h.xlsx"
    r = subprocess.run(
        [sys.executable, "generar.py", "--config", str(cfg), "--salida", str(salida)],
        capture_output=True,
        text=True,
        cwd=Path(__file__).parent.parent,
    )
    assert r.returncode == 0, r.stderr
    assert salida.exists()


def test_cli_config_invalida_sale_con_error(tmp_path):
    """Invalid config (turnos: 0) must exit non-zero and print an error message."""
    cfg = tmp_path / "mala.yaml"
    cfg.write_text(
        "aulas: [Aula 1]\ndias: [Lunes]\nturnos: 0\n"
        "carreras: {}\n",
        encoding="utf-8",
    )
    salida = tmp_path / "no_debe_existir.xlsx"
    r = subprocess.run(
        [sys.executable, "generar.py", "--config", str(cfg), "--salida", str(salida)],
        capture_output=True,
        text=True,
        cwd=Path(__file__).parent.parent,
    )
    assert r.returncode != 0
    assert r.stderr.strip() != "", "Se esperaba un mensaje de error en stderr"
    assert "Error de configuración" in r.stderr
    assert not salida.exists()
