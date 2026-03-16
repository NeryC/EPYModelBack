"""
datos-completos.py
==================
Descarga automatizada del dataset "Datos Completos" del portal COVID-19 del MSPBS
(Ministerio de Salud Pública y Bienestar Social de Paraguay) desde Tableau Public.

Este dataset contiene el registro individual de cada caso confirmado de COVID-19
en Paraguay, con su fecha de confirmación. Es la fuente principal para calcular
la serie temporal de casos confirmados diarios (confirmado_diarios_revisado.csv).

Archivo descargado
------------------
  public/rawData/Descargar datos_Datos completos_data.csv

Uso
---
  python datos-completos.py

Dependencias
------------
  selenium, webdriver-manager (ver requirements.txt)

Notas
-----
  - Se debe ejecutar desde la raíz del proyecto (donde está la carpeta public/).
  - Los tiempos de espera (sleep) son altos por la naturaleza de la app Tableau.
  - Este script usa unittest como framework porque originalmente se diseñó como
    test de integración; la lógica principal está en setUp/test/tearDown.
"""

import unittest
from time import sleep

from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait

from utils import cambiarIdioma, checkFile, descargarArchivo, setUpProcess

# Nombre exacto del archivo que Tableau genera al descargar en español
NOMBRE_ARCHIVO = "Descargar datos_Datos completos_data.csv"


class DescargaDatosCompletosTest(unittest.TestCase):
    """
    Test de descarga del dataset de datos completos (casos confirmados).

    Navega al portal Tableau del MSPBS, cambia el idioma a español,
    permanece en el tab por defecto (Datos completos) y descarga el CSV.
    """

    def setUp(self) -> None:
        """Inicializa Chrome headless y configura la carpeta de descarga."""
        setUpProcess(self)

    def test_download_datosCompletos(self) -> None:
        """
        Descarga el CSV de datos completos (casos confirmados por fecha).

        Pasos:
          1. Navegar a la URL del portal Tableau del MSPBS.
          2. Cambiar idioma a Español (para nombre de archivo correcto).
          3. Esperar a que el iframe con el dashboard cargue completamente.
          4. Ejecutar el flujo de descarga de datos (descargarArchivo).
          5. Verificar que el archivo existe en public/rawData/.
        """
        driver = self.driver
        driver.get(self.base_url)

        # Cambiar idioma para que el archivo tenga el nombre esperado en español
        cambiarIdioma(self, driver)

        print("[datos-completos] Esperando carga del dashboard Tableau...")
        # Espera larga porque Tableau renderiza el dashboard con JavaScript pesado
        sleep(60)

        # Esperar al iframe del visualizador (indica que el tab activo está listo)
        WebDriverWait(driver, 40).until(
            EC.element_to_be_clickable((By.XPATH, "//iframe[@allowtransparency='true']"))
        )
        sleep(4)  # Espera adicional antes de volver al contexto principal

        # Volver al contexto del documento principal (fuera de iframes)
        driver.switch_to.default_content()

        # Ejecutar el flujo de descarga de Tableau
        descargarArchivo(self, driver)

        # Verificar que el archivo fue descargado correctamente
        checkFile(self, NOMBRE_ARCHIVO)

    def tearDown(self) -> None:
        """Cierra el navegador al finalizar."""
        print("[datos-completos] Cerrando navegador.")
        self.driver.quit()


if __name__ == "__main__":
    unittest.main()
