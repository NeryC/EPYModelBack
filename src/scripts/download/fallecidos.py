"""
fallecidos.py
=============
Descarga automatizada del dataset "Fallecidos" del portal COVID-19 del MSPBS
desde Tableau Public.

Este dataset contiene el registro individual de cada fallecimiento por COVID-19
en Paraguay, con su fecha de óbito. Es la fuente para calcular la serie
temporal de fallecidos diarios (Fallecidos_diarios_revisado.csv).

Archivo descargado
------------------
  public/rawData/FALLECIDOS_Datos completos_data.csv

Uso
---
  python fallecidos.py

Dependencias
------------
  selenium, webdriver-manager (ver requirements.txt)

Notas
-----
  - Se debe ejecutar desde la raíz del proyecto (donde está la carpeta public/).
  - Este script navega al 4.° tab del dashboard Tableau ("Fallecidos")
    antes de ejecutar la descarga.
"""

import unittest
from time import sleep

from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait

from utils import cambiarIdioma, checkFile, descargarArchivo, setUpProcess

# Nombre exacto del archivo que Tableau genera al descargar en español
NOMBRE_ARCHIVO = "FALLECIDOS_Datos completos_data.csv"

# XPath del 4.° tab en el dashboard Tableau (pestaña "Fallecidos")
XPATH_TAB_FALLECIDOS = "(//div[@class='dijitTabInnerDiv'])[4]"


class DescargaFallecidosTest(unittest.TestCase):
    """
    Test de descarga del dataset de fallecidos por COVID-19.

    Navega al portal Tableau del MSPBS, cambia el idioma a español,
    hace click en el tab "Fallecidos" (4.° tab) y descarga el CSV.
    """

    def setUp(self) -> None:
        """Inicializa Chrome headless y configura la carpeta de descarga."""
        setUpProcess(self)

    def test_download_fallecidos(self) -> None:
        """
        Descarga el CSV de fallecidos (registro individual por fecha de óbito).

        Pasos:
          1. Navegar a la URL del portal Tableau del MSPBS.
          2. Cambiar idioma a Español.
          3. Esperar carga completa del dashboard (60 segundos).
          4. Cambiar al iframe del visualizador y hacer click en el tab Fallecidos.
          5. Volver al contexto principal y ejecutar el flujo de descarga.
          6. Verificar que el archivo fue descargado correctamente.
        """
        driver = self.driver
        driver.get(self.base_url)

        cambiarIdioma(self, driver)

        print("[fallecidos] Esperando carga del dashboard Tableau...")
        sleep(60)  # Espera necesaria para que Tableau renderice el dashboard

        # Cambiar al iframe del visualizador para interactuar con los tabs
        iframe_tab = WebDriverWait(driver, 40).until(
            EC.element_to_be_clickable((By.XPATH, "//iframe[@allowtransparency='true']"))
        )
        driver.switch_to.frame(iframe_tab)

        # Hacer click en el tab "Fallecidos" (4.° tab del dashboard)
        print("[fallecidos] Seleccionando tab 'Fallecidos'...")
        tab_fallecidos = WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.XPATH, XPATH_TAB_FALLECIDOS))
        )
        sleep(10)  # El tab tarda en volverse interactuable
        tab_fallecidos.click()

        # Volver al contexto principal para ejecutar la descarga
        driver.switch_to.default_content()

        descargarArchivo(self, driver)

        checkFile(self, NOMBRE_ARCHIVO)

    def tearDown(self) -> None:
        """Cierra el navegador al finalizar."""
        print("[fallecidos] Cerrando navegador.")
        self.driver.quit()


if __name__ == "__main__":
    unittest.main()
