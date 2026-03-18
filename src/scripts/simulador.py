"""
simulador.py
============
Implementación del modelo epidemiológico SEIR-HCUFO para COVID-19 en Paraguay.

Compartimentos del modelo
--------------------------
  S  – Susceptibles     : sin inmunidad, pueden infectarse.
  E  – Expuestos        : en período de incubación (no transmiten aún).
  I  – Infecciosos      : transmiten activamente la enfermedad.
  C  – Acumulados       : total histórico de casos que pasaron por I.
  H  – Hospitalizados   : casos que requieren cama general.
  U  – UCI              : hospitalizados en unidad de cuidados intensivos.
  F  – Fallecidos       : muertes acumuladas por COVID-19.
  O  – Inmunes/Recuperados: individuos con inmunidad temporal (recuperados + vacunados).

Parámetros epidemiológicos fijos
---------------------------------
  N             Población de Paraguay (Censo 2020).
  alpha         Tasa E→I  (período de incubación ~3 días  → 1/3).
  gamma         Tasa I→*  (período infeccioso    ~7 días  → 1/7).
  psi           Tasa O→S  (inmunidad dura        ~180 días → 1/180).
  eta           Eficacia de vacuna (90 %).
  delta_H_to_U  Tasa H→U (tiempo hasta UCI       ~7 días).
  delta_H_to_F  Tasa H→F (tiempo hasta muerte desde H  ~9 días).
  delta_H_to_O  Tasa H→O (tiempo hasta recuperar desde H ~11 días).
  phi_U_to_F    Tasa U→F (tiempo hasta muerte desde UCI ~11 días).
  phi_U_to_O    Tasa U→O (tiempo hasta recuperar desde UCI ~12 días).
  lambda_I_to_F Fracción de I que muere sin hospitalizarse.
  lambda_H_to_U Fracción de H que escala a UCI.
  lambda_H_to_F Fracción de H que fallece (UCI no saturada).
  lambda_U_to_F Fracción de U que fallece (UCI no saturada).

Uso desde Node.js (python-shell)
---------------------------------
  python simulador.py '<x0>' '<Rt>' '<uci_threshold>' '<V_filtered>' '<lambda_I_to_H>' '<firstSimulation>'

  Donde cada argumento es un JSON:
    x0             : [S0, E0, I0, C0, H0, U0, F0, O0]  estado inicial.
    Rt             : [rt_mes1, rt_mes2, ...]             Rt por mes.
    uci_threshold  : número máximo de camas UCI.
    V_filtered     : nuevos vacunados/día (suavizado).
    lambda_I_to_H  : fracción de I que se hospitaliza.
    firstSimulation: true → guarda en public/results/simulation.json
                     false → imprime JSON en stdout.
"""

from __future__ import annotations

import json
import os
import sys
from typing import Any

import numpy as np
from scipy.integrate import odeint

# ---------------------------------------------------------------------------
# Rutas
# ---------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(os.path.dirname(BASE_DIR))
RESULTS_DIR = os.path.join(ROOT_DIR, "public", "results")

# ---------------------------------------------------------------------------
# Constantes epidemiológicas
# ---------------------------------------------------------------------------

# Tamaño de la población objetivo (Paraguay, Censo 2020)
N: int = 7_252_672

# Tasa de progresión E → I: período de incubación promedio = 3 días
alpha: float = 1.0 / 3.0

# Tasa de salida de I: período infeccioso promedio = 7 días
gamma: float = 1.0 / 7.0

# Tasa de pérdida de inmunidad O → S: inmunidad dura ~180 días
psi: float = 1.0 / 180.0

# Eficacia de la vacuna: fracción de vacunados que pasan a O
eta: float = 0.9

# Tiempos de transición desde H (hospitalizados generales)
delta_H_to_U: float = 1.0 / 7.0   # H → UCI:             ~7 días
delta_H_to_F: float = 1.0 / 9.0   # H → Fallecido:       ~9 días
delta_H_to_O: float = 1.0 / 11.0  # H → Recuperado:      ~11 días

# Tiempos de transición desde U (UCI)
phi_U_to_F: float = 1.0 / 11.0  # U → Fallecido:         ~11 días
phi_U_to_O: float = 1.0 / 12.0  # U → Recuperado:        ~12 días

# Fracción de infecciosos que mueren sin hospitalizar (muerte directa desde I)
lambda_I_to_F: float = 0.002

# Fracciones de H que escalan o fallecen (valores base, UCI no saturada)
lambda_H_to_U: float = 0.20  # 20 % de H van a UCI
lambda_H_to_F: float = 0.15  # 15 % de H fallecen

# Fracción de U que fallece (UCI no saturada)
lambda_U_to_F: float = 0.45  # 45 % de U fallecen

# Tasas elevadas de mortalidad cuando la UCI supera su capacidad máxima
LAMBDA_H_TO_F_SATURADO: float = 0.25  # 25 % de H (saturada)
LAMBDA_U_TO_F_SATURADO: float = 0.50  # 50 % de U (saturada)


# ---------------------------------------------------------------------------
# Sistema de ecuaciones diferenciales ordinarias (EDOs)
# ---------------------------------------------------------------------------

def odes(
    state: list[float],
    t: float,
    Rt: list[float],
    uci_threshold: float,
    V_filtered: float,
    lambda_I_to_H: float,
    lambda_H_to_O: float,
    lambda_U_to_O: float,
    lambda_I_to_O: float,
) -> list[float]:
    """
    Calcula las derivadas del sistema SEIR-HCUFO en el instante t.

    El vector Rt define la tasa de reproducción efectiva mes a mes.
    Cuando t cruza un múltiplo de 30 días, se cambia al siguiente Rt.
    Si t supera el último mes definido, se mantiene el último Rt.

    Saturación de UCI
    -----------------
    Si U > uci_threshold la capacidad UCI está superada: se aplican tasas
    de mortalidad más altas en H y U para reflejar el colapso sanitario.

    Parameters
    ----------
    state         : Vector [S, E, I, C, H, U, F, O].
    t             : Tiempo en días (continuo).
    Rt            : Lista de Rt por mes.
    uci_threshold : Capacidad máxima de camas UCI.
    V_filtered    : Vacunados por día (serie suavizada).
    lambda_I_to_H : Fracción de I que se hospitaliza.
    lambda_H_to_O : Fracción de H que se recupera (= 1 - H→U - H→F).
    lambda_U_to_O : Fracción de U que se recupera (= 1 - U→F).
    lambda_I_to_O : Fracción de I que se recupera (= 1 - I→H - I→F).

    Returns
    -------
    [dS, dE, dI, dC, dH, dU, dF, dO]
    """
    S, E, I, C, H, U, F, O = state

    # --- Tasas de mortalidad según saturación UCI ---
    if U > uci_threshold:
        # UCI saturada: mayor mortalidad
        lam_H_F = LAMBDA_H_TO_F_SATURADO
        lam_U_F = LAMBDA_U_TO_F_SATURADO
    else:
        lam_H_F = lambda_H_to_F
        lam_U_F = lambda_U_to_F

    # --- Beta (tasa de transmisión) para el mes actual ---
    # beta = Rt * gamma * N / S  (fuerza de infección efectiva por susceptible)
    # Guardia contra S → 0: si no quedan susceptibles beta es irrelevante (no hay infección).
    month_idx = min(int(np.floor(t / 30)), len(Rt) - 1)
    beta = (Rt[month_idx] * gamma * N) / S if S > 0.0 else 0.0

    # --- Ecuaciones diferenciales por compartimento ---

    # S: pierde miembros por infección y vacunación; gana por pérdida de inmunidad
    dSdt = -(beta * (S / N) * I) - (eta * V_filtered) + (psi * O)

    # E: gana desde nuevas infecciones; pierde al volverse infeccioso
    dEdt = (beta * (S / N) * I) - (alpha * E)

    # I: gana desde E; pierde al resolverse (a H, F u O)
    dIdt = (alpha * E) - (gamma * I)

    # C: contador acumulado de todos los casos que pasaron por I
    dCdt = gamma * I

    # H: gana desde I; pierde a UCI, fallecidos y recuperados
    dHdt = (
        (lambda_I_to_H * gamma * I)
        - (lambda_H_to_U * delta_H_to_U * H)
        - (lam_H_F * delta_H_to_F * H)
        - (lambda_H_to_O * delta_H_to_O * H)
    )

    # U: gana desde H (escalados); pierde a fallecidos y recuperados
    dUdt = (
        (lambda_H_to_U * delta_H_to_U * H)
        - (lam_U_F * phi_U_to_F * U)
        - (lambda_U_to_O * phi_U_to_O * U)
    )

    # F: acumula fallecidos desde I (directos), H y U
    dFdt = (
        (lambda_I_to_F * gamma * I)
        + (lam_H_F * delta_H_to_F * H)
        + (lam_U_F * phi_U_to_F * U)
    )

    # O: gana desde recuperados (I, H, U) y vacunados; pierde por pérdida de inmunidad
    dOdt = (
        (lambda_I_to_O * gamma * I)
        + (lambda_H_to_O * delta_H_to_O * H)
        + (lambda_U_to_O * phi_U_to_O * U)
        + (eta * V_filtered)
        - (psi * O)
    )

    return [dSdt, dEdt, dIdt, dCdt, dHdt, dUdt, dFdt, dOdt]


# ---------------------------------------------------------------------------
# Punto de entrada principal
# ---------------------------------------------------------------------------

def main(params: list[str]) -> None:
    """
    Parsea los parámetros CLI, ejecuta la simulación y genera el output.

    Integra el sistema de EDOs con odeint (LSODA) en pasos de 0.1 días
    y extrae solo los valores en instantes enteros (día 0, 1, 2, …).

    Parameters
    ----------
    params : sys.argv[1:] — seis argumentos JSON en orden:
             [x0, Rt, uci_threshold, V_filtered, lambda_I_to_H, firstSimulation]
    """
    if len(params) < 6:
        print(
            "Uso: python simulador.py <x0> <Rt> <uci_threshold> "
            "<V_filtered> <lambda_I_to_H> <firstSimulation>",
            file=sys.stderr,
        )
        sys.exit(1)

    # --- Parseo de argumentos ---
    x0: list[float]       = json.loads(params[0])  # Estado inicial [S, E, I, C, H, U, F, O]
    Rt: list[float]       = json.loads(params[1])  # Rt por mes
    uci_threshold: float  = json.loads(params[2])  # Capacidad máxima UCI
    V_filtered: float     = json.loads(params[3])  # Vacunados/día suavizado
    lam_I_to_H: float     = json.loads(params[4])  # Fracción I → H
    first_simulation: bool = json.loads(params[5]) # ¿Primera simulación (guardar en archivo)?

    # Duración total: 30 días por cada valor de Rt
    num_dias: int = len(Rt) * 30

    # --- Tasas complementarias (la suma de salidas de cada compartimento = 1) ---
    lam_H_to_O: float = 1.0 - lambda_H_to_U - lambda_H_to_F  # Fracción H → recuperado
    lam_U_to_O: float = 1.0 - lambda_U_to_F                  # Fracción U → recuperado
    lam_I_to_O: float = 1.0 - lam_I_to_H - lambda_I_to_F    # Fracción I → recuperado directo

    # --- Integración numérica con paso de 0.1 días ---
    t_continuo = np.arange(0, num_dias, 0.1)

    # Redirigir fd 1 (C-level stdout) a /dev/null para suprimir mensajes
    # de advertencia de LSODA (Fortran) que python-shell capturaría como JSON.
    # El try exterior protege ante entornos donde stdout no tiene fd real (fileno() lanzaría
    # io.UnsupportedOperation); en ese caso se integra igual sin supresión.
    saved_fd: int | None = None
    stdout_fd: int | None = None
    try:
        stdout_fd = sys.stdout.fileno()
        saved_fd = os.dup(stdout_fd)
        devnull_fd = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull_fd, stdout_fd)
        os.close(devnull_fd)
    except Exception:
        saved_fd = None

    try:
        solucion = odeint(
            odes,
            x0,
            t_continuo,
            args=(Rt, uci_threshold, V_filtered, lam_I_to_H, lam_H_to_O, lam_U_to_O, lam_I_to_O),
            printmessg=False,
        )
    finally:
        if saved_fd is not None and stdout_fd is not None:
            os.dup2(saved_fd, stdout_fd)
            os.close(saved_fd)

    # --- Extraer solo los valores diarios (t = 0, 1, 2, …) ---
    # Con paso 0.1, cada día entero corresponde exactamente al índice i*10 (i=0,1,...,num_dias-1).
    # Usar slicing directo es más rápido y evita errores de punto flotante de np.isclose.
    indices_diarios = np.arange(0, len(t_continuo), 10)
    dias            = np.arange(num_dias)
    solucion_diaria = solucion[indices_diarios]

    def _serie(col: int) -> list[dict[str, Any]]:
        """Convierte una columna de la solución en lista [{day, value}, ...]."""
        return [
            {"day": int(d), "value": float(v)}
            for d, v in zip(dias, solucion_diaria[:, col])
        ]

    # --- Construir resultado con nombre de cada compartimento ---
    resultado: dict[str, Any] = {
        "susceptible":       _serie(0),  # S – Susceptibles
        "exposed":           _serie(1),  # E – Expuestos
        "infectious":        _serie(2),  # I – Infecciosos activos
        "cumulative":        _serie(3),  # C – Casos acumulados
        "hospitalized":      _serie(4),  # H – Hospitalizados generales
        "uci":               _serie(5),  # U – UCI
        "cumulative_deaths": _serie(6),  # F – Fallecidos acumulados
        "immune":            _serie(7),  # O – Inmunes/Recuperados
    }

    result_json = json.dumps(resultado)

    # --- Salida: archivo (primera carga) o stdout (llamadas dinámicas de la API) ---
    if first_simulation:
        os.makedirs(RESULTS_DIR, exist_ok=True)
        output_path = os.path.join(RESULTS_DIR, "simulation.json")
        with open(output_path, mode="w", encoding="utf-8") as f:
            f.write(result_json)
    else:
        # La API Node.js captura este output desde python-shell
        print(result_json)


if __name__ == "__main__":
    main(sys.argv[1:])
