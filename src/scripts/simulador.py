"""
simulador.py
============
Implementación del modelo epidemiológico SEIR-HCUFO para COVID-19 en Paraguay.

La simulación continúa el modelo bayesiano ajustado en R/Stan
(src/model_seirh/test_seirhuf_normal.R → public/data/sim_SEIRHUF.csv):
parte de su último estado estimado y, salvo que se indique otra cosa, de las
fracciones de transición que ese ajuste estimó para las últimas semanas.

Compartimentos del modelo
--------------------------
  S  – Susceptibles     : sin inmunidad, pueden infectarse.
  E  – Expuestos        : en período de incubación (no transmiten aún).
  I  – Infecciosos      : transmiten activamente la enfermedad.
  C  – Acumulados       : total histórico de infecciones que pasaron por I
                          (estimado: incluye las no reportadas / subregistro).
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
  delta_H_to_U  Tasa H→U (tiempo hasta UCI       ~3 días).
  delta_H_to_F  Tasa H→F (tiempo hasta muerte desde H  ~9 días).
  delta_H_to_O  Tasa H→O (tiempo hasta recuperar desde H ~11 días).
  phi_U_to_F    Tasa U→F (tiempo hasta muerte desde UCI ~11 días).
  phi_U_to_O    Tasa U→O (tiempo hasta recuperar desde UCI ~12 días).

Fracciones de transición (Fracciones)
-------------------------------------
  lambda_I_to_F Fracción de I que muere sin hospitalizarse.
  lambda_H_to_U Fracción de H que escala a UCI.
  lambda_H_to_F Fracción de H que fallece (UCI no saturada).
  lambda_U_to_F Fracción de U que fallece (UCI no saturada).

  La API las toma del ajuste de R (promedio de los últimos 7 días de
  sim_SEIRHUF.csv) y las pasa como 7.º argumento. Sin ese argumento se usan
  FRACCIONES_POR_DEFECTO (valores de literatura). Antes el simulador usaba
  siempre esas fijas, ~5–18 veces mayores que las ajustadas para oct-2022:
  hospitalizados y fallecidos saltaban un orden de magnitud el día 0 y no
  coincidían con la página de proyecciones.

Rt: número reproductivo EFECTIVO al inicio de cada mes
------------------------------------------------------
  Para cada mes m se calibra la transmisión con el S al inicio del mes:

      beta_m = Rt_m · gamma · N / S(inicio del mes m)

  de modo que la fuerza de infección beta_m · (S/N) · I vale exactamente
  Rt_m · gamma · I al empezar el mes: con Rt > 1 la infección crece y con
  Rt < 1 decrece, como describe la interfaz y como estima el modelo de R
  (columna numero_reproductivo = beta/gamma · S/N). Dentro del mes el Rt
  efectivo baja naturalmente a medida que se agotan los susceptibles.
  (Antes Rt se multiplicaba por S/N ≈ 0,81: con Rt de 1,0 a 1,3 la epidemia
  decrecía aunque la interfaz dijera que se expande.)

Saturación de UCI (transición suave)
------------------------------------
  Cuando U supera las camas disponibles, la mortalidad de H y U sube. Se
  mantiene el aumento relativo del diseño original (H: 15 % → 25 %, ×5/3;
  U: 45 % → 50 %, ×10/9) aplicado a las fracciones vigentes. El cambio se
  modela con una sigmoide de ancho w = max(1, 1 % del umbral) camas:

      s(U) = 1 / (1 + exp(-(U - umbral) / w))      (0 = libre, 1 = saturada)
      λ_H→F = λ_H→F,libre + s · (λ_H→F,saturada − λ_H→F,libre)   (ídem U→F)

  Con un salto (`if U > umbral`) las ecuaciones son discontinuas: LSODA
  fallaba en algunos escenarios y devolvía valores sin sentido (~1e300), y
  cerca del umbral el sistema ni siquiera tiene solución bien definida.

Vacunación limitada por susceptibles
------------------------------------
  Se vacunan eta · V · S / (S + K_VACUNA) personas por día. Mientras S ≫ K_VACUNA
  (siempre en escenarios realistas) es eta · V; cuando ya no quedan
  susceptibles la vacunación se detiene en lugar de volver S negativo.

Uso desde Node.js (python-shell)
---------------------------------
  python simulador.py '<x0>' '<Rt>' '<uci_threshold>' '<V_filtered>' '<lambda_I_to_H>' '<firstSimulation>' ['<fracciones>']

  Donde cada argumento es un JSON:
    x0             : [S0, E0, I0, C0, H0, U0, F0, O0]  estado inicial.
    Rt             : [rt_mes1, rt_mes2, ...]             Rt efectivo por mes.
    uci_threshold  : número máximo de camas UCI.
    V_filtered     : nuevos vacunados por día.
    lambda_I_to_H  : fracción de I que se hospitaliza.
    firstSimulation: true → guarda en public/results/simulation.json
                     false → imprime JSON en stdout.
    fracciones     : (opcional) {"lambda_I_to_F", "lambda_H_to_U",
                     "lambda_H_to_F", "lambda_U_to_F"}.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
from dataclasses import asdict, dataclass
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

# Tiempos de transición desde H (hospitalizados generales).
# DEBEN coincidir con src/model_seirh/parametros.R: las fracciones λ que usa el
# simulador son las que estimó ese modelo con estas mismas tasas. (H→UCI estuvo
# en 1/3 entre mar-2026 y nov-2026; con las fracciones ajustadas eso hacía que la
# UCI se duplicara en 10 días mientras el ajuste la mostraba estable.)
delta_H_to_U: float = 1.0 / 7.0   # H → UCI:             ~7 días
delta_H_to_F: float = 1.0 / 9.0   # H → Fallecido:       ~9 días
delta_H_to_O: float = 1.0 / 11.0  # H → Recuperado:      ~11 días

# Tiempos de transición desde U (UCI)
phi_U_to_F: float = 1.0 / 11.0  # U → Fallecido:         ~11 días
phi_U_to_O: float = 1.0 / 12.0  # U → Recuperado:        ~12 días

# Aumento relativo de la mortalidad con la UCI saturada (diseño original:
# H→F 15 % → 25 %, U→F 45 % → 50 %), aplicado a las fracciones vigentes.
FACTOR_SATURACION_H_F: float = 0.25 / 0.15
FACTOR_SATURACION_U_F: float = 0.50 / 0.45

# Ancho relativo de la transición libre → saturada (fracción del umbral, mín. 1 cama)
ANCHO_SATURACION_RELATIVO: float = 0.01

# Escala de la saturación de la vacunación (personas): con S ≫ K_VACUNA no influye
K_VACUNA: float = 100.0

# Tolerancia de conservación de la población (S+E+I+H+U+F+O constante)
TOLERANCIA_CONSERVACION: float = 1e-4


@dataclass(frozen=True)
class Fracciones:
    """Fracciones de transición (UCI no saturada)."""

    lambda_I_to_F: float  # I → F sin hospitalizarse
    lambda_H_to_U: float  # H → UCI
    lambda_H_to_F: float  # H → F
    lambda_U_to_F: float  # U → F

    def saturadas(self) -> tuple[float, float]:
        """Mortalidad de H y U con la UCI saturada (acotada para que las salidas sumen ≤ 1)."""
        h_f = min(self.lambda_H_to_F * FACTOR_SATURACION_H_F, 1.0 - self.lambda_H_to_U)
        u_f = min(self.lambda_U_to_F * FACTOR_SATURACION_U_F, 1.0)
        return h_f, u_f


# Valores de literatura: solo se usan si no se pasan las fracciones ajustadas
FRACCIONES_POR_DEFECTO = Fracciones(
    lambda_I_to_F=0.002,
    lambda_H_to_U=0.07,
    lambda_H_to_F=0.15,
    lambda_U_to_F=0.45,
)


class SimulacionInvalidaError(RuntimeError):
    """La integración numérica no produjo un resultado confiable."""


# ---------------------------------------------------------------------------
# Sistema de ecuaciones diferenciales ordinarias (EDOs)
# ---------------------------------------------------------------------------

def odes(
    state: list[float],
    t: float,
    beta: float,
    uci_threshold: float,
    V_filtered: float,
    lambda_I_to_H: float,
    fr: Fracciones,
) -> list[float]:
    """
    Derivadas del sistema SEIR-HCUFO en el instante t (dentro de un mes).

    Parameters
    ----------
    state         : Vector [S, E, I, C, H, U, F, O].
    t             : Tiempo en días (no se usa: beta ya es la del mes).
    beta          : Tasa de transmisión del mes (ver docstring del módulo).
    uci_threshold : Capacidad máxima de camas UCI.
    V_filtered    : Vacunados por día.
    lambda_I_to_H : Fracción de I que se hospitaliza.
    fr            : Fracciones de transición (UCI no saturada).

    Returns
    -------
    [dS, dE, dI, dC, dH, dU, dF, dO]
    """
    S, E, I, C, H, U, F, O = state

    # --- Mortalidad según saturación UCI (transición suave) ---
    # s = 0 → UCI libre, s = 1 → UCI saturada. tanh evita overflow de exp().
    ancho = max(1.0, ANCHO_SATURACION_RELATIVO * uci_threshold)
    s = 0.5 * (1.0 + np.tanh((U - uci_threshold) / (2.0 * ancho)))
    h_f_sat, u_f_sat = fr.saturadas()
    lam_H_F = fr.lambda_H_to_F + s * (h_f_sat - fr.lambda_H_to_F)
    lam_U_F = fr.lambda_U_to_F + s * (u_f_sat - fr.lambda_U_to_F)
    # Fracciones de recuperación: las salidas de H, U e I suman 1
    lam_H_O = 1.0 - fr.lambda_H_to_U - lam_H_F
    lam_U_O = 1.0 - lam_U_F
    lam_I_O = 1.0 - lambda_I_to_H - fr.lambda_I_to_F

    S = max(S, 0.0)  # protección ante errores de redondeo del integrador

    # Nuevas infecciones por día
    infecciones = beta * (S / N) * I

    # Vacunados efectivos por día: eta·V mientras haya susceptibles, → 0 si S → 0
    vacunados = eta * V_filtered * S / (S + K_VACUNA)

    # --- Ecuaciones diferenciales por compartimento ---

    # S: pierde por infección y vacunación; gana por pérdida de inmunidad
    dSdt = -infecciones - vacunados + (psi * O)

    # E: gana desde nuevas infecciones; pierde al volverse infeccioso
    dEdt = infecciones - (alpha * E)

    # I: gana desde E; pierde al resolverse (a H, F u O)
    dIdt = (alpha * E) - (gamma * I)

    # C: contador acumulado de todos los casos que pasaron por I
    dCdt = gamma * I

    # H: gana desde I; pierde a UCI, fallecidos y recuperados
    dHdt = (
        (lambda_I_to_H * gamma * I)
        - (fr.lambda_H_to_U * delta_H_to_U * H)
        - (lam_H_F * delta_H_to_F * H)
        - (lam_H_O * delta_H_to_O * H)
    )

    # U: gana desde H (escalados); pierde a fallecidos y recuperados
    dUdt = (
        (fr.lambda_H_to_U * delta_H_to_U * H)
        - (lam_U_F * phi_U_to_F * U)
        - (lam_U_O * phi_U_to_O * U)
    )

    # F: acumula fallecidos desde I (directos), H y U
    dFdt = (
        (fr.lambda_I_to_F * gamma * I)
        + (lam_H_F * delta_H_to_F * H)
        + (lam_U_F * phi_U_to_F * U)
    )

    # O: gana desde recuperados (I, H, U) y vacunados; pierde por pérdida de inmunidad
    dOdt = (
        (lam_I_O * gamma * I)
        + (lam_H_O * delta_H_to_O * H)
        + (lam_U_O * phi_U_to_O * U)
        + vacunados
        - (psi * O)
    )

    return [dSdt, dEdt, dIdt, dCdt, dHdt, dUdt, dFdt, dOdt]


def beta_para_rt_efectivo(rt: float, S: float) -> float:
    """beta tal que el Rt efectivo (beta/gamma · S/N) sea `rt` con los susceptibles S."""
    return rt * gamma * N / max(S, 1.0)


# ---------------------------------------------------------------------------
# Huella del modelo
# ---------------------------------------------------------------------------

def _script_sha256() -> str:
    """
    SHA-256 del código fuente de este script, con finales de línea
    normalizados (CRLF → LF) para que el hash sea igual en Windows y Linux.

    Se guarda en simulation.meta.json junto a la simulación inicial; el test
    `src/scripts/simulation-freshness.test.ts` lo compara con el script actual
    para detectar un simulation.json generado por una versión vieja del modelo.
    """
    with open(os.path.abspath(__file__), "rb") as f:
        source = f.read().replace(b"\r\n", b"\n")
    return hashlib.sha256(source).hexdigest()


# ---------------------------------------------------------------------------
# Validaciones (defensa en profundidad: la API ya valida los rangos)
# ---------------------------------------------------------------------------

def leer_fracciones(raw: dict[str, Any] | None) -> Fracciones:
    """Construye y valida las Fracciones a partir del JSON opcional."""
    if raw is None:
        return FRACCIONES_POR_DEFECTO
    try:
        fr = Fracciones(**{k: float(raw[k]) for k in asdict(FRACCIONES_POR_DEFECTO)})
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(f"fracciones incompletas o inválidas: {exc}") from exc
    for nombre, valor in asdict(fr).items():
        if not np.isfinite(valor) or not 0.0 <= valor <= 1.0:
            raise ValueError(f"{nombre} debe estar entre 0 y 1")
    if fr.lambda_H_to_U + fr.lambda_H_to_F > 1.0:
        raise ValueError("lambda_H_to_U + lambda_H_to_F no puede superar 1")
    return fr


def validar_parametros(
    x0: list[float],
    Rt: list[float],
    uci_threshold: float,
    V_filtered: float,
    lam_I_to_H: float,
    fr: Fracciones,
) -> None:
    """Lanza ValueError si los parámetros no permiten una simulación con sentido."""
    if len(x0) != 8 or any(not np.isfinite(v) or v < 0 for v in x0):
        raise ValueError("x0 debe tener 8 valores finitos y no negativos")
    if len(Rt) == 0:
        raise ValueError("Rt debe tener al menos un mes")
    if any(not np.isfinite(r) or r < 0 for r in Rt):
        raise ValueError("Rt debe contener valores finitos y no negativos")
    if not np.isfinite(uci_threshold) or uci_threshold <= 0:
        raise ValueError("uci_threshold debe ser positivo")
    if not np.isfinite(V_filtered) or V_filtered < 0:
        raise ValueError("V_filtered no puede ser negativo")
    if not 0.0 <= lam_I_to_H <= 1.0 - fr.lambda_I_to_F:
        raise ValueError(
            f"lambda_I_to_H debe estar entre 0 y {1.0 - fr.lambda_I_to_F:.3f} "
            f"(el {fr.lambda_I_to_F:.2%} de I fallece sin hospitalizarse)"
        )


def verificar_solucion(solucion: np.ndarray, info: dict[str, Any], x0: list[float]) -> None:
    """
    Comprueba que la integración terminó bien y respeta los invariantes del modelo.
    Lanza SimulacionInvalidaError en caso contrario.
    """
    if not str(info.get("message", "")).startswith("Integration successful"):
        raise SimulacionInvalidaError(f"LSODA no completó la integración: {info.get('message')}")
    if not np.all(np.isfinite(solucion)):
        raise SimulacionInvalidaError("la solución contiene valores no finitos")
    # Población total (C es un contador, no un compartimento)
    idx = [0, 1, 2, 4, 5, 6, 7]
    total0 = float(np.sum(np.asarray(x0)[idx]))
    desvio = float(np.max(np.abs(solucion[:, idx].sum(axis=1) - total0))) / total0
    if desvio > TOLERANCIA_CONSERVACION:
        raise SimulacionInvalidaError(f"la población no se conserva (desvío {desvio:.2e})")
    if float(np.min(solucion)) < -1.0:
        raise SimulacionInvalidaError("la solución tiene compartimentos negativos")


# ---------------------------------------------------------------------------
# Punto de entrada principal
# ---------------------------------------------------------------------------

def main(params: list[str]) -> None:
    """
    Parsea los parámetros CLI, ejecuta la simulación y genera el output.

    Integra el sistema mes a mes con odeint (LSODA), con salida cada 0.1 días,
    y devuelve los valores en instantes enteros (día 0, 1, 2, …).

    Parameters
    ----------
    params : sys.argv[1:] — seis argumentos JSON obligatorios y uno opcional:
             [x0, Rt, uci_threshold, V_filtered, lambda_I_to_H, firstSimulation, fracciones?]
    """
    if len(params) < 6:
        print(
            "Uso: python simulador.py <x0> <Rt> <uci_threshold> "
            "<V_filtered> <lambda_I_to_H> <firstSimulation> [<fracciones>]",
            file=sys.stderr,
        )
        sys.exit(1)

    # --- Parseo de argumentos ---
    x0: list[float]       = json.loads(params[0])  # Estado inicial [S, E, I, C, H, U, F, O]
    Rt: list[float]       = json.loads(params[1])  # Rt efectivo por mes
    uci_threshold: float  = json.loads(params[2])  # Capacidad máxima UCI
    V_filtered: float     = json.loads(params[3])  # Vacunados/día
    lam_I_to_H: float     = json.loads(params[4])  # Fracción I → H
    first_simulation: bool = json.loads(params[5]) # ¿Primera simulación (guardar en archivo)?
    fr = leer_fracciones(json.loads(params[6]) if len(params) > 6 else None)

    validar_parametros(x0, Rt, uci_threshold, V_filtered, lam_I_to_H, fr)

    # Duración total: 30 días por cada valor de Rt
    num_dias: int = len(Rt) * 30

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

    # --- Integración numérica mes a mes, con paso de salida de 0.1 días ---
    # Rt cambia de golpe cada 30 días. Integrar cada mes por separado (reiniciando
    # LSODA en el borde) evita que el integrador cruce esa discontinuidad, y da
    # el S al inicio de cada mes para calibrar beta (Rt efectivo).
    tramos: list[np.ndarray] = []
    estado = np.asarray(x0, dtype=float)
    try:
        for mes, rt_mes in enumerate(Rt):
            t_mes = 30.0 * mes + np.arange(0, 301) * 0.1  # [30m, 30m+30] incluye el borde
            beta = beta_para_rt_efectivo(rt_mes, estado[0])
            solucion_mes, info = odeint(
                odes,
                estado,
                t_mes,
                args=(beta, uci_threshold, V_filtered, lam_I_to_H, fr),
                full_output=True,
                printmessg=False,
                # Margen para tramos rígidos (p. ej. vacunación que agota S en días);
                # en escenarios normales LSODA usa muchos menos pasos.
                mxstep=5000,
            )
            # Los mensajes de LSODA están silenciados (ver arriba): el fallo se
            # verifica aquí y nunca se devuelve una integración fallida como válida.
            verificar_solucion(solucion_mes, info, x0)
            tramos.append(solucion_mes[:-1:10])  # días 30m … 30m+29
            estado = solucion_mes[-1]
    finally:
        if saved_fd is not None and stdout_fd is not None:
            os.dup2(saved_fd, stdout_fd)
            os.close(saved_fd)

    # --- Valores diarios (t = 0, 1, 2, …, num_dias-1) ---
    dias            = np.arange(num_dias)
    solucion_diaria = np.vstack(tramos)

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
        "cumulative":        _serie(3),  # C – Casos acumulados (incluye no reportados)
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

        # Metadatos: qué versión del modelo y qué parámetros generaron el archivo.
        # Sin timestamp a propósito: el contenido es determinista y regenerar
        # (p. ej. al arrancar el servidor) no ensucia el árbol de git.
        meta = {
            "script_sha256": _script_sha256(),
            "params": {
                "x0": x0,
                "Rt": Rt,
                "uci_threshold": uci_threshold,
                "V_filtered": V_filtered,
                "lambda_I_to_H": lam_I_to_H,
                "fracciones": asdict(fr),
            },
        }
        meta_path = os.path.join(RESULTS_DIR, "simulation.meta.json")
        with open(meta_path, mode="w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2)
            f.write("\n")
    else:
        # La API Node.js captura este output desde python-shell
        print(result_json)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
    except (ValueError, SimulacionInvalidaError) as exc:
        # Mensaje corto en stderr + código ≠ 0: el adaptador Node lo convierte en error HTTP
        tipo = "PARAMETROS_INVALIDOS" if isinstance(exc, ValueError) else "SIMULACION_INVALIDA"
        print(f"{tipo}: {exc}", file=sys.stderr)
        sys.exit(2)
