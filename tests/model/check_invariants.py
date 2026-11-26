"""
Ejecuta el modelo REAL (src/scripts/simulador.py) sobre un conjunto de escenarios
y verifica sus invariantes. Imprime un JSON con los resultados.

Lo usa tests/integration/simulador-model.integration.test.ts. También sirve a mano:
    .venv/Scripts/python.exe tests/model/check_invariants.py
"""
from __future__ import annotations

import contextlib
import io
import itertools
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "src", "scripts"))
import simulador  # noqa: E402

import csv  # noqa: E402

N = simulador.N
with open(os.path.join(ROOT, "public", "data", "sim_SEIRHUF.csv"), encoding="utf-8") as f:
    ROWS = list(csv.DictReader(f))
# Igual que el adaptador Node: estado del último día y fracciones promedio de 7 días
X0 = [float(ROWS[-1][k]) for k in ["S", "E", "I", "R", "H", "U", "F", "O"]]


def _avg(column: str) -> float:
    return sum(float(r[column]) for r in ROWS[-7:]) / 7


FRACCIONES = {"lambda_I_to_F": _avg("lamif"), "lambda_H_to_U": _avg("lamhu"),
              "lambda_H_to_F": _avg("lamhf"), "lambda_U_to_F": _avg("lamuf")}
TOTAL0 = X0[0] + X0[1] + X0[2] + sum(X0[4:8])
KEYS = ["susceptible", "exposed", "infectious", "cumulative", "hospitalized", "uci",
        "cumulative_deaths", "immune"]


def run(Rt, uci, V, lam):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        simulador.main([json.dumps(X0), json.dumps(Rt), json.dumps(uci), json.dumps(V),
                        json.dumps(lam), "false", json.dumps(FRACCIONES)])
    return json.loads([l for l in buf.getvalue().splitlines() if l.startswith("{")][-1])


def problems(Rt, out):
    found = []
    n = 30 * len(Rt)
    s = {k: [p["value"] for p in out[k]] for k in KEYS}
    for k in KEYS:
        if [p["day"] for p in out[k]] != list(range(n)):
            found.append(f"{k}: días incorrectos")
        if not all(math.isfinite(v) for v in s[k]):
            found.append(f"{k}: no finitos")
        elif min(s[k]) < -1:
            found.append(f"{k}: negativo")
        elif k != "cumulative" and max(s[k]) > 1.001 * N:
            found.append(f"{k}: supera N")
    for k in ["cumulative", "cumulative_deaths"]:
        if any(b < a - 1e-6 * max(1, abs(a)) for a, b in zip(s[k], s[k][1:])):
            found.append(f"{k}: decrece")
    tot = [sum(s[k][i] for k in KEYS if k != "cumulative") for i in range(n)]
    if max(abs(t - TOTAL0) for t in tot) / TOTAL0 > 1e-4:
        found.append("no conserva población")
    return found


RT_SETS = [[1.1, 1.2, 1.3, 0.8, 0.7, 0.9], [0.0], [2.0] * 12, [0.0, 2.0] * 6, [0.8] * 12,
           [round(0.1 + i * 0.17, 2) for i in range(12)]]
results = []
for Rt, uci, V, lam in itertools.product(RT_SETS, [1, 100, 2500, 5000], [1, 1000, 5000],
                                          [0.0, 0.002, 0.2, 0.5, 0.99]):
    try:
        out = run(Rt, uci, V, lam)
        results.append({"params": [Rt, uci, V, lam], "problems": problems(Rt, out),
                        "end_deaths": out["cumulative_deaths"][-1]["value"]})
    except Exception as exc:  # noqa: BLE001
        results.append({"params": [Rt, uci, V, lam], "problems": [f"excepción: {exc}"]})

# Respuestas monotónicas esperadas (manteniendo el resto fijo)
def deaths(Rt, uci, V, lam):
    return run(Rt, uci, V, lam)["cumulative_deaths"][-1]["value"]


def infectious(Rt, day):
    return run(Rt, 100, 1000, 0.002)["infectious"][day]["value"]


# Continuidad con el ajuste de R: fallecidos/día del día 0 vs los últimos días ajustados
_sim = run([1.0], 100, 1000, round(_avg("lamih"), 3))
_muertes_dia0 = _sim["cumulative_deaths"][1]["value"] - _sim["cumulative_deaths"][0]["value"]

mono = {
    "más Rt ⇒ más muertes": deaths([1.5] * 6, 100, 1000, 0.01) > deaths([1.0] * 6, 100, 1000, 0.01),
    "más λ ⇒ más muertes": deaths([1.2] * 6, 100, 1000, 0.05) > deaths([1.2] * 6, 100, 1000, 0.01),
    "más vacunación ⇒ menos muertes": deaths([1.2] * 6, 100, 5000, 0.01) < deaths([1.2] * 6, 100, 1, 0.01),
    "menos camas UCI ⇒ más muertes": deaths([1.2] * 6, 50, 1000, 0.05) > deaths([1.2] * 6, 5000, 1000, 0.05),
    # Rt efectivo: > 1 crece, < 1 decrece (medido después del transitorio inicial)
    "Rt 1.3 ⇒ los infecciosos crecen": infectious([1.3] * 3, 75) > infectious([1.3] * 3, 15),
    "Rt 0.7 ⇒ los infecciosos bajan": infectious([0.7] * 3, 75) < infectious([0.7] * 3, 15),
    # El día 0 no puede saltar un orden de magnitud respecto del ajuste (antes: ×14)
    "arranque continuo (fallecidos/día día 0 entre ½× y 2× del ajuste)":
        0.5 < _muertes_dia0 / _avg("dailyF") < 2.0,
}
print(json.dumps({"runs": results, "monotonic": mono}))
