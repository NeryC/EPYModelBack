"""
registros-diarios.py
====================
Descarga automatizada del dataset "Registro Diario" del portal COVID-19 del MSPBS
desde Tableau Public.

Este dataset contiene el resumen estadístico diario del sistema de salud paraguayo:
  - Cantidad de pruebas diagnósticas realizadas
  - Internados generales (hospitalizados)
  - Internados en UCI/UTI
  - Entre otros indicadores de capacidad hospitalaria

Es la fuente para los datos observados de hospitalizados, UCI y capacidad de pruebas
que se muestran en las proyecciones del modelo.

Archivo descargado
------------------
  public/rawData/REGISTRO DIARIO_Datos completos_data.csv

Uso
---
  python registros-diarios.py

Dependencias
------------
  selenium, webdriver-manager (ver requirements.txt)

Notas
-----
  - Se debe ejecutar desde la raíz del proyecto (donde está la carpeta public/).
  - Este script navega al 2.° tab del dashboard Tableau ("Registro Diario")
    antes de ejecutar la descarga.
"""

import unittest
from time import sleep

from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait

from utils import cambiarIdioma, checkFile, descargarArchivo, setUpProcess

# Nombre exacto del archivo que Tableau genera al descargar en español
NOMBRE_ARCHIVO = "REGISTRO DIARIO_Datos completos_data.csv"

# XPath del 2.° tab en el layout del dashboard Tableau ("Registro Diario")
XPATH_TAB_REGISTRO_DIARIO = '//*[@id="dijit_layout_LayoutContainer_0"]/div/div[2]'


class DescargaRegistrosDiariosTest(unittest.TestCase):
    """
    Test de descarga del dataset de registros diarios de capacidad hospitalaria.

    Navega al portal Tableau del MSPBS, cambia el idioma a español,
    hace click en el tab "Registro Diario" (2.° tab) y descarga el CSV.
    """

    def setUp(self) -> None:
        """Inicializa Chrome headless y configura la carpeta de descarga."""
        setUpProcess(self)

    def test_download_registrosDiarios(self) -> None:
        """
        Descarga el CSV de registros diarios (pruebas, hospitalizados, UCI).

        Pasos:
          1. Navegar a la URL del portal Tableau del MSPBS.
          2. Cambiar idioma a Español.
          3. Esperar carga completa del dashboard (60 segundos).
          4. Cambiar al iframe del visualizador y hacer click en el tab Registro Diario.
          5. Volver al contexto principal y ejecutar el flujo de descarga.
          6. Verificar que el archivo fue descargado correctamente.
        """
        driver = self.driver
        driver.get(self.base_url)

        cambiarIdioma(self, driver)

        print("[registros-diarios] Esperando carga del dashboard Tableau...")
        sleep(60)  # Espera necesaria para que Tableau renderice el dashboard

        # Cambiar al iframe del visualizador para interactuar con los tabs
        iframe_tab = WebDriverWait(driver, 40).until(
            EC.element_to_be_clickable((By.XPATH, "//iframe[@allowtransparency='true']"))
        )
        driver.switch_to.frame(iframe_tab)

        # Hacer click en el tab "Registro Diario" (2.° div del layout)
        print("[registros-diarios] Seleccionando tab 'Registro Diario'...")
        tab_registro_diario = WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.XPATH, XPATH_TAB_REGISTRO_DIARIO))
        )
        sleep(10)  # El tab tarda en volverse interactuable
        tab_registro_diario.click()

        # Volver al contexto principal para ejecutar la descarga
        driver.switch_to.default_content()

        descargarArchivo(self, driver)

        checkFile(self, NOMBRE_ARCHIVO)

    def tearDown(self) -> None:
        """Cierra el navegador al finalizar."""
        print("[registros-diarios] Cerrando navegador.")
        self.driver.quit()


if __name__ == "__main__":
    unittest.main()
