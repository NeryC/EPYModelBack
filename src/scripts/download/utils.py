"""
utils.py
========
Utilidades compartidas para los scripts de descarga automatizada de datos
del Portal COVID-19 de Paraguay (MSPBS) publicados en Tableau Public.

URL fuente
----------
  https://public.tableau.com/app/profile/mspbs/viz/COVID19PY-Registros/Descargardatos

Flujo general de descarga
--------------------------
  1. setUp        → Inicializa Chrome en modo headless y configura la carpeta
                    de descarga (public/rawData/).
  2. cambiarIdioma → Cambia el idioma de la página a "Español" para que los
                    archivos descargados tengan el nombre en español (necesario
                    para que el pipeline de limpieza los encuentre).
  3. descargarArchivo → Abre el diálogo de descarga de Tableau, selecciona
                    la opción "Datos completos" y descarga el CSV.
  4. checkFile    → Verifica que el archivo fue descargado correctamente.

Notas importantes
-----------------
  - Los sleep() son necesarios porque Tableau usa JavaScript pesado y los
    elementos del DOM no están disponibles inmediatamente después de cargar.
  - Los XPath están ajustados a la versión actual del portal MSPBS; pueden
    cambiar si Tableau actualiza su interfaz.
  - La carpeta destino es public/rawData/ relativa al directorio de trabajo
    actual (raíz del proyecto).
"""

import os
from time import sleep

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.wait import WebDriverWait
from webdriver_manager.chrome import ChromeDriverManager

# URL del portal de datos COVID-19 del MSPBS en Tableau Public
TABLEAU_URL = (
    "https://public.tableau.com/app/profile/mspbs/viz/"
    "COVID19PY-Registros/Descargardatos"
)

# Carpeta de destino para archivos descargados (relativa a la raíz del proyecto)
DOWNLOAD_DIR = os.path.join(os.getcwd(), "public", "rawData")


def setUpProcess(self) -> None:
    """
    Inicializa el driver de Chrome en modo headless y configura la descarga.

    Configuraciones aplicadas:
      - --headless=new : ejecuta Chrome sin ventana visible (para servidores).
      - --no-sandbox   : necesario en entornos Linux con restricciones de sandboxing.
      - Page.setDownloadBehavior : fuerza que los archivos se descarguen en
        DOWNLOAD_DIR en lugar de abrirse en el navegador.
      - implicitly_wait(30): espera hasta 30 segundos por elementos del DOM.

    Parameters
    ----------
    self : Instancia del TestCase de unittest.
    """
    chrome_options = Options()
    chrome_options.add_argument("--headless=new")
    chrome_options.add_argument("--no-sandbox")
    # Suprime mensajes de log innecesarios de Chrome
    chrome_options.add_experimental_option("excludeSwitches", ["enable-logging"])

    # Instala automáticamente la versión correcta de ChromeDriver
    self.driver = webdriver.Chrome(
        service=Service(ChromeDriverManager().install()),
        options=chrome_options,
    )

    # Configura la carpeta de descarga vía CDP (Chrome DevTools Protocol)
    os.makedirs(DOWNLOAD_DIR, exist_ok=True)
    self.driver.execute_cdp_cmd(
        "Page.setDownloadBehavior",
        {"behavior": "allow", "downloadPath": DOWNLOAD_DIR},
    )

    # Espera implícita global para los elementos del DOM
    self.driver.implicitly_wait(30)

    self.base_url = TABLEAU_URL


def cambiarIdioma(self, driver: webdriver.Chrome) -> None:
    """
    Cambia el idioma de la interfaz de Tableau a "Español".

    Esto es necesario porque el nombre del archivo descargado depende del
    idioma seleccionado. El pipeline de limpieza R espera nombres en español:
      - "Descargar datos_Datos completos_data.csv"
      - "FALLECIDOS_Datos completos_data.csv"
      - "REGISTRO DIARIO_Datos completos_data.csv"

    Parameters
    ----------
    self   : Instancia del TestCase.
    driver : WebDriver activo.
    """
    print("[download] Cambiando idioma a Español...")

    # Abre el dropdown de selección de idioma en el footer de Tableau
    dropdown = WebDriverWait(driver, 20).until(
        EC.presence_of_element_located(
            (By.XPATH, '//*[@id="root"]/div/footer/div[1]/div/div/div/div')
        )
    )
    dropdown.click()

    # Selecciona "Español" de la lista de idiomas
    opcion_espanol = WebDriverWait(driver, 20).until(
        EC.presence_of_element_located(
            (By.XPATH, '//*[@id="root"]/div/footer/div[1]/div/div/div/ul/li[contains(text(),"Español")]')
        )
    )
    opcion_espanol.click()
    print("[download] Idioma cambiado a Español.")


def descargarArchivo(self, driver: webdriver.Chrome) -> None:
    """
    Ejecuta el flujo completo de descarga de datos desde Tableau.

    Flujo interno:
      1. Espera 5 segundos para que el botón de descarga sea funcional.
      2. Hace click en el botón de descarga (ícono de descarga en la barra).
      3. Espera 20 segundos y cambia al iframe del diálogo de descarga.
      4. Selecciona la opción "Datos" (segundo botón del diálogo).
      5. Cambia a la nueva ventana/tab que abre Tableau con las opciones de descarga.
      6. Selecciona "Migrated Data" (datos migrados / datos completos).
      7. Hace click en "Descargar" y espera 40 segundos para que finalice.

    Notas
    -----
    Los tiempos de espera con sleep() son elevados porque Tableau es una
    aplicación JavaScript pesada y los elementos pueden tardar en ser
    interactuables incluso después de estar presentes en el DOM.

    Parameters
    ----------
    self   : Instancia del TestCase.
    driver : WebDriver activo.
    """
    print("[download] Iniciando descarga...")

    # Paso 1: Esperar y hacer click en el botón de descarga de Tableau
    sleep(5)  # El botón tarda en volverse funcional
    boton_descarga = WebDriverWait(driver, 20).until(
        EC.element_to_be_clickable(
            (By.XPATH, '//*[@id="root"]/div/div[4]/div[1]/div/div[2]/button[4]')
        )
    )
    boton_descarga.click()

    # Paso 2: Cambiar al iframe que contiene el diálogo de opciones de descarga
    sleep(20)  # El iframe tarda en cargar
    print("[download] Seleccionando opción 'Datos' en el diálogo de descarga...")
    iframe_descarga = WebDriverWait(driver, 20).until(
        EC.presence_of_element_located(
            (By.XPATH, "//div[@id='embedded-viz-wrapper']//iframe")
        )
    )
    driver.switch_to.frame(iframe_descarga)

    sleep(5)  # El botón dentro del iframe tarda en aparecer
    opcion_datos = WebDriverWait(driver, 20).until(
        EC.presence_of_element_located(
            (By.XPATH, "//div[@id='DownloadDialog-Dialog-Body-Id']//button[2]")
        )
    )
    opcion_datos.click()
    driver.switch_to.default_content()  # Volver al contexto principal

    # Paso 3: Cambiar a la nueva ventana con las opciones de descarga de datos
    sleep(10)  # La nueva ventana/tab tarda en abrirse
    print("[download] Cambiando a la nueva ventana de descarga...")
    driver.switch_to.window(driver.window_handles[1])

    # Paso 4: Seleccionar "Migrated Data" (datos completos migrados)
    print("[download] Seleccionando 'Migrated Data'...")
    opcion_datos_completos = WebDriverWait(driver, 20).until(
        EC.presence_of_element_located((By.XPATH, "//div[@id='Migrated Data']"))
    )
    opcion_datos_completos.click()

    # Paso 5: Hacer click en el botón final de descarga
    print("[download] Descargando archivo...")
    boton_descargar = WebDriverWait(driver, 20).until(
        EC.presence_of_element_located(
            (By.XPATH, "//button[@data-tb-test-id='download-data-Button']")
        )
    )
    boton_descargar.click()

    sleep(40)  # Esperar a que el archivo termine de descargarse
    print("[download] Descarga completada.")


def checkFile(self, file_name: str) -> None:
    """
    Verifica que el archivo fue descargado correctamente en public/rawData/.

    Parameters
    ----------
    self      : Instancia del TestCase (usa self.assertTrue).
    file_name : Nombre exacto del archivo esperado (con extensión).
    """
    sleep(4)  # Pequeña espera adicional para que el sistema de archivos lo registre
    file_path = os.path.join(DOWNLOAD_DIR, file_name)
    self.assertTrue(
        os.path.exists(file_path),
        f"Archivo no encontrado: {file_path}",
    )
    print(f"[download] Archivo verificado: {file_name}")
