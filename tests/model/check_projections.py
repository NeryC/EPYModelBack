"""
Ejecuta el post-procesamiento de proyecciones (src/scripts/cron.py) en un
directorio temporal y verifica que las fechas de los datos OBSERVADOS se
conserven: cada valor tiene que quedar en su fecha real.

Motivo: con pandas 2, `pd.to_datetime(..., errors="coerce")` sin formato
interpretaba "04/01/2020" (4 de enero, día/mes/año) como 1 de abril y
descartaba las fechas con día > 12. Al regenerar proyH/proyU se perdían 628
de 1030 días y 367 quedaban con día y mes intercambiados.

Imprime un JSON con los problemas encontrados por archivo. Lo usa
tests/integration/projections-pipeline.integration.test.ts.
"""
from __future__ import annotations

import csv
import json
import os
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "src", "scripts"))
import cron  # noqa: E402

DATA = os.path.join(ROOT, "public", "data")


def _registro_diario(columna: str) -> dict[str, float]:
    """Serie del REGISTRO DIARIO leída a mano como día/mes/año."""
    with open(os.path.join(DATA, "REGISTRO DIARIO_Datos completos_data.csv"), encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f, delimiter=";"))
    out = {}
    for r in rows:
        d, m, y = r["Fecha"].split("/")
        out[f"{y}-{int(m):02d}-{int(d):02d}"] = float(r[columna])
    return out


def _revisado(archivo: str, columna: str) -> dict[str, float]:
    with open(os.path.join(DATA, archivo), encoding="utf-8") as f:
        return {r["Fecha"]: float(r[columna]) for r in csv.DictReader(f)}


ESPERADO = {
    "proyH": ("Hospitalizados", _registro_diario("Internados Generales")),
    "proyU": ("UTI", _registro_diario("Internados UTI")),
    "proyR": ("Reportados", _revisado("confirmado_diarios_revisado.csv", "Confirmado_diario")),
    "proyF": ("Fallecidos", _revisado("Fallecidos_diarios_revisado.csv", "Fallecido_diario")),
}

with tempfile.TemporaryDirectory() as tmp:
    cron.RESULTS_DIR = tmp
    import contextlib
    import io
    with contextlib.redirect_stdout(io.StringIO()):
        cron.proyeccionF(); cron.proyeccionR(); cron.proyeccionU(); cron.proyeccionH()
    reporte = {}
    for nombre, (col, fuente) in ESPERADO.items():
        with open(os.path.join(tmp, f"{nombre}.json"), encoding="utf-8") as f:
            filas = json.load(f)
        fechas = [r.get("fecha") for r in filas]
        sin_fecha = sum(1 for x in fechas if x is None)
        duplicadas = len(fechas) - sin_fecha - len({x for x in fechas if x is not None})
        observados = {r["fecha"]: r[col] for r in filas if r.get("fecha") and r.get(col) is not None}
        mal_ubicados = [k for k, v in observados.items() if k in fuente and fuente[k] != v]
        faltantes = [k for k in fuente if k not in observados]
        reporte[nombre] = {
            "filas": len(filas),
            "sin_fecha": sin_fecha,
            "fechas_duplicadas": duplicadas,
            "observados": len(observados),
            "en_fuente": len(fuente),
            "valor_en_fecha_equivocada": len(mal_ubicados),
            "dias_de_la_fuente_perdidos": len(faltantes),
            "ejemplos": mal_ubicados[:3] + faltantes[:3],
        }
print(json.dumps(reporte))
