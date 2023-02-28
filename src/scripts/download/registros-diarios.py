import unittest

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

from selenium.webdriver.common.by import By
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from utils import setUpProcess, cambiarIdioma, descargarArchivo, checkFile

from time import sleep

class app_test_case(unittest.TestCase):

    def setUp(self):

        setUpProcess(self)

    def test_download_registrosDiarios(self):
        driver = self.driver
        driver.get(self.base_url)

        cambiarIdioma(self, driver)

        print('Seleccionar Registros diarios en el tab')
        # hay un tiempo hasta que el tab es funcional
        sleep(60)
        tabFrame = WebDriverWait(driver, 40).until(
            EC.element_to_be_clickable((By.XPATH, "//iframe[@allowtransparency='true']"))
        )
        driver.switch_to.frame(tabFrame)
        registroDiarioTab = WebDriverWait(driver, 20).until(
            EC.presence_of_element_located((By.XPATH, '//*[@id="dijit_layout_LayoutContainer_0"]/div/div[2]'))
        )
        # hay un tiempo hasta que el tab es funcional
        sleep(10)
        registroDiarioTab.click()
        driver.switch_to.default_content()

        descargarArchivo(self, driver)

        fileName = "REGISTRO DIARIO_Datos completos_data.csv"
        checkFile(self, fileName)

    def tearDown(self):
        print('finish')
        self.driver.quit()

if __name__ == "__main__":
    unittest.main()