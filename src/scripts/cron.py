"""
cron.py
=======
Post-procesamiento de proyecciones del modelo SEIR-HCUFO.

Este módulo combina tres fuentes de datos para cada variable epidemiológica:
  1. Proyección futura (generada por el modelo R/Stan, archivos proyX.csv).
  2. Simulación histórica ajustada (sim_SEIRHUF.csv, salida del modelo bayesiano).
  3. Datos observados reales (REGISTRO DIARIO, confirmados, fallecidos).

El resultado final se exporta como JSON y CSV en public/results/ para ser
consumido por el frontend (Next.js).

Funciones exportadas
---------------------
  proyeccionR()  – Casos reportados diarios (R).
  proyeccionH()  – Hospitalizados generales (H).
  proyeccionU()  – UCI ocupados (U).
  proyeccionF()  – Fallecidos diarios (F).

Columnas de salida (todas las proyecciones)
--------------------------------------------
  fecha           Fecha en formato YYYY-MM-DD.
  peor            Banda superior de incertidumbre (unc_h).
  mejor           Banda inferior de incertidumbre (unc_l).
  proy            Proyección central.
  eq              Escenario de equilibrio (R ~ 1).
  X2w             Proyección a 2 semanas.
  X4w             Proyección a 4 semanas.
  q25             Percentil 25 de la proyección.
  q75             Percentil 75 de la proyección.
  X10p            Banda +10 %.
  X20p            Banda -20 %.
  <variable>      Simulación histórica del modelo (dailyR, H, U, dailyF).
  <observado>     Dato observado real (Reportados, Hospitalizados, UTI, Fallecidos).
  CapacidadMax    Capacidad máxima histórica del sistema de salud.
  FechaCapacidadMax Fecha en que se alcanzó esa capacidad máxima.
"""

import os

import pandas as pd

# ---------------------------------------------------------------------------
# Rutas de directorios
# ---------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(os.path.dirname(BASE_DIR))

DATA_DIR    = os.path.join(ROOT_DIR, "public", "data")
RESULTS_DIR = os.path.join(ROOT_DIR, "public", "results")

# ---------------------------------------------------------------------------
# Constantes de capacidad máxima histórica del sistema de salud paraguayo
# Estos valores reflejan los picos históricos durante la pandemia de COVID-19
# ---------------------------------------------------------------------------
CAPACIDAD_MAX_HOSPITALIZADOS = 1_319   # Pico máximo de camas generales (~2020-12-31)
CAPACIDAD_MAX_UCI = 461                # Pico máximo de camas UCI (~2020-12-31)
FECHA_CAPACIDAD_MAX_HISTORICA = "2020-12-31"

# Nombre del archivo con la simulación SEIRHUF ajustada (salida del modelo bayesiano R/Stan)
ARCHIVO_SIMULACION = os.path.join(DATA_DIR, "sim_SEIRHUF.csv")

# Archivo de registros diarios oficiales (datos observados del MSPBS)
ARCHIVO_REGISTRO_DIARIO = os.path.join(DATA_DIR, "REGISTRO DIARIO_Datos completos_data.csv")


# ---------------------------------------------------------------------------
# Helpers internos
# ---------------------------------------------------------------------------

def _normalizar_fecha(df: pd.DataFrame, col: str = "fecha") -> pd.DataFrame:
    """
    Convierte una columna de fechas a formato string 'YYYY-MM-DD'.

    Acepta cualquier formato que pandas pueda parsear (incluyendo timestamps).

    Parameters
    ----------
    df  : DataFrame a modificar (in-place).
    col : Nombre de la columna de fechas.

    Returns
    -------
    El mismo DataFrame con la columna convertida.
    """
    df[col] = pd.to_datetime(df[col], errors="coerce").dt.strftime("%Y-%m-%d")
    return df


def _cargar_simulacion_historica(columna: str) -> pd.DataFrame:
    """
    Carga la columna de la simulación SEIRHUF ajustada del modelo bayesiano R/Stan.

    El archivo sim_SEIRHUF.csv contiene las trayectorias del modelo ajustadas
    a los datos observados. Se usa para mostrar la trayectoria histórica
    junto con la proyección futura.

    Parameters
    ----------
    columna : Nombre de la columna a extraer (p.ej. 'dailyR', 'H', 'U', 'dailyF').

    Returns
    -------
    DataFrame con columnas ['fecha', columna].
    """
    df = pd.read_csv(ARCHIVO_SIMULACION, header=0)
    df.rename(columns={"date": "fecha"}, inplace=True)
    df = _normalizar_fecha(df)
    return df[["fecha", columna]]


def _construir_proyeccion(archivo_proyeccion: str) -> pd.DataFrame:
    """
    Construye el DataFrame de proyección con todas las bandas de incertidumbre.

    Lee el archivo proyX.csv generado por projection_at_time.R y renombra
    las columnas al esquema estándar del frontend.

    Mapeo de columnas
    -----------------
      date   → fecha
      unc_h  → peor   (banda superior de incertidumbre)
      unc_l  → mejor  (banda inferior de incertidumbre)
      proj   → proy   (proyección central)
      eq     → eq     (escenario de equilibrio Rt=1)
      m2w    → X2w    (media de 2 semanas)
      m4w    → X4w    (media de 4 semanas)
      q25    → q25    (percentil 25)
      q75    → q75    (percentil 75)
      X10p_h → X10p   (+10 % sobre el escenario central)
      X20p_l → X20p   (-20 % sobre el escenario central)

    Parameters
    ----------
    archivo_proyeccion : Ruta al archivo proyX.csv.

    Returns
    -------
    DataFrame con fecha normalizada y las 10 columnas de proyección.
    """
    df_raw = pd.read_csv(archivo_proyeccion, header=0)
    df_raw.rename(columns={"date": "fecha"}, inplace=True)

    # Convertir fechas a string YYYY-MM-DD
    df = pd.to_datetime(df_raw["fecha"], errors="coerce").dt.strftime("%Y-%m-%d").to_frame()

    # Insertar columnas de proyección en orden fijo (requerido por el frontend)
    df.insert(1,  "peor",  df_raw["unc_h"])   # Banda superior
    df.insert(2,  "mejor", df_raw["unc_l"])   # Banda inferior
    df.insert(3,  "proy",  df_raw["proj"])    # Proyección central
    df.insert(4,  "eq",    df_raw["eq"])      # Escenario equilibrio
    df.insert(5,  "X2w",   df_raw["m2w"])     # Media 2 semanas
    df.insert(6,  "X4w",   df_raw["m4w"])     # Media 4 semanas
    df.insert(7,  "q25",   df_raw["q25"])     # Percentil 25
    df.insert(8,  "q75",   df_raw["q75"])     # Percentil 75
    df.insert(9,  "X10p",  df_raw["X10p_h"]) # +10 %
    df.insert(10, "X20p",  df_raw["X20p_l"]) # -20 %

    return df


def _exportar(df: pd.DataFrame, nombre: str) -> None:
    """
    Guarda el DataFrame resultante como JSON y CSV en public/results/.

    Parameters
    ----------
    df     : DataFrame final con todas las columnas.
    nombre : Nombre base del archivo (sin extensión), p.ej. 'proyR'.
    """
    os.makedirs(RESULTS_DIR, exist_ok=True)
    df.to_json(os.path.join(RESULTS_DIR, f"{nombre}.json"), orient="records")
    df.to_csv(os.path.join(RESULTS_DIR,  f"{nombre}.csv"),  index=False)


# ---------------------------------------------------------------------------
# Funciones de proyección por variable
# ---------------------------------------------------------------------------

def proyeccionR() -> None:
    """
    Genera la proyección de casos reportados diarios (R).

    Combina:
    - Proyección: proyR.csv  (generado por projection_at_time.R)
    - Sim. hist.: sim_SEIRHUF.csv → columna 'dailyR'  (con subregistro)
    - Sim. hist.: sim_SEIRHUF.csv → columna 'dailyR_sin_subRegistro'
    - Observados: confirmado_diarios_revisado.csv → 'Reportados'
    - Capacidad:  max de 'Cantidad Pruebas' en registros diarios

    Salidas: public/results/proyR.json, public/results/proyR.csv
    """
    # 1. Proyección futura del modelo
    df = _construir_proyeccion(os.path.join(DATA_DIR, "proyR.csv"))

    # 2. Trayectoria histórica del modelo ajustado (con subregistro)
    df_sim = _cargar_simulacion_historica("dailyR")

    # 3. Trayectoria histórica sin corrección de subregistro
    df_sim_sin_sub = _cargar_simulacion_historica("dailyR_sin_subRegistro")

    # 4. Datos observados reales (confirmados diarios revisados)
    df_obs = pd.read_csv(
        os.path.join(DATA_DIR, "confirmado_diarios_revisado.csv"), header=0
    )
    df_obs.rename(columns={"Fecha": "fecha", "Confirmado_diario": "Reportados"}, inplace=True)
    df_obs = _normalizar_fecha(df_obs)[["fecha", "Reportados"]]

    # 5. Capacidad máxima de pruebas diagnósticas (para referencia en el gráfico)
    df_registro = pd.read_csv(ARCHIVO_REGISTRO_DIARIO, header=0, sep=";")
    capacidad_max = df_registro["Cantidad Pruebas"].max()
    fecha_capacidad_max = df_obs["fecha"].max()  # Última fecha observada

    # 6. Merge de todas las fuentes sobre el eje de fechas
    df = (
        df
        .merge(df_sim,         on="fecha", how="outer")
        .merge(df_sim_sin_sub, on="fecha", how="outer")
        .merge(df_obs,         on="fecha", how="outer")
    )

    # 7. Metadatos de capacidad máxima histórica
    df.insert(13, "CapacidadMax",      capacidad_max)
    df.insert(14, "FechaCapacidadMax", fecha_capacidad_max)

    _exportar(df, "proyR")
    print("Proyeccion R completada.")


def proyeccionH() -> None:
    """
    Genera la proyección de hospitalizados generales (H).

    Combina:
    - Proyección: proyH.csv
    - Sim. hist.: sim_SEIRHUF.csv → columna 'H'
    - Observados: REGISTRO DIARIO → 'Internados Generales'
    - Capacidad:  1319 camas (pico histórico ~2020-12-31)

    Salidas: public/results/proyH.json, public/results/proyH.csv
    """
    # 1. Proyección futura del modelo
    df = _construir_proyeccion(os.path.join(DATA_DIR, "proyH.csv"))

    # 2. Trayectoria histórica del modelo ajustado
    df_sim = _cargar_simulacion_historica("H")

    # 3. Datos observados reales (internados generales)
    df_obs = pd.read_csv(ARCHIVO_REGISTRO_DIARIO, header=0, sep=";")
    df_obs.rename(
        columns={"Fecha": "fecha", "Internados Generales": "Hospitalizados"}, inplace=True
    )
    df_obs = _normalizar_fecha(df_obs)[["fecha", "Hospitalizados"]]

    # 4. Merge
    df = (
        df
        .merge(df_sim, on="fecha", how="outer")
        .merge(df_obs, on="fecha", how="outer")
    )

    # 5. Capacidad máxima histórica de camas generales
    df.insert(13, "CapacidadMax",      CAPACIDAD_MAX_HOSPITALIZADOS)
    df.insert(14, "FechaCapacidadMax", FECHA_CAPACIDAD_MAX_HISTORICA)

    _exportar(df, "proyH")
    print("Proyeccion H completada.")


def proyeccionU() -> None:
    """
    Genera la proyección de ocupación de UCI (U).

    Combina:
    - Proyección: proyU.csv
    - Sim. hist.: sim_SEIRHUF.csv → columna 'U'
    - Observados: REGISTRO DIARIO → 'Internados UTI'
    - Capacidad:  461 camas UCI (pico histórico ~2020-12-31)

    Salidas: public/results/proyU.json, public/results/proyU.csv
    """
    # 1. Proyección futura del modelo
    df = _construir_proyeccion(os.path.join(DATA_DIR, "proyU.csv"))

    # 2. Trayectoria histórica del modelo ajustado
    df_sim = _cargar_simulacion_historica("U")

    # 3. Datos observados reales (internados en UTI)
    df_obs = pd.read_csv(ARCHIVO_REGISTRO_DIARIO, header=0, sep=";")
    df_obs.rename(columns={"Fecha": "fecha", "Internados UTI": "UTI"}, inplace=True)
    df_obs = _normalizar_fecha(df_obs)[["fecha", "UTI"]]

    # 4. Merge
    df = (
        df
        .merge(df_sim, on="fecha", how="outer")
        .merge(df_obs, on="fecha", how="outer")
    )

    # 5. Capacidad máxima histórica de camas UCI
    df.insert(13, "CapacidadMax",      CAPACIDAD_MAX_UCI)
    df.insert(14, "FechaCapacidadMax", FECHA_CAPACIDAD_MAX_HISTORICA)

    _exportar(df, "proyU")
    print("Proyeccion U completada.")


def proyeccionF() -> None:
    """
    Genera la proyección de fallecidos diarios (F).

    Combina:
    - Proyección: proyF.csv
    - Sim. hist.: sim_SEIRHUF.csv → columna 'dailyF'
    - Observados: Fallecidos_diarios_revisado.csv → 'Fallecidos'
    - Capacidad:  max de 'Cantidad Pruebas' (para referencia en el gráfico)

    Salidas: public/results/proyF.json, public/results/proyF.csv
    """
    # 1. Proyección futura del modelo
    df = _construir_proyeccion(os.path.join(DATA_DIR, "proyF.csv"))

    # 2. Trayectoria histórica del modelo ajustado
    df_sim = _cargar_simulacion_historica("dailyF")

    # 3. Datos observados de fallecidos (serie revisada)
    df_obs = pd.read_csv(
        os.path.join(DATA_DIR, "Fallecidos_diarios_revisado.csv"), header=0
    )
    df_obs.rename(columns={"Fecha": "fecha", "Fallecido_diario": "Fallecidos"}, inplace=True)
    df_obs = _normalizar_fecha(df_obs)[["fecha", "Fallecidos"]]

    # 4. Capacidad máxima de pruebas (usada como referencia en el gráfico de fallecidos)
    df_registro = pd.read_csv(ARCHIVO_REGISTRO_DIARIO, header=0, sep=";")
    capacidad_max = df_registro["Cantidad Pruebas"].max()
    fecha_capacidad_max = df_obs["fecha"].max()

    # 5. Merge
    df = (
        df
        .merge(df_sim, on="fecha", how="outer")
        .merge(df_obs, on="fecha", how="outer")
    )

    # 6. Metadatos de capacidad
    df.insert(13, "CapacidadMax",      capacidad_max)
    df.insert(14, "FechaCapacidadMax", fecha_capacidad_max)

    _exportar(df, "proyF")
    print("Proyeccion F completada.")
