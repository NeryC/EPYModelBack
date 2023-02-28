import unittest

from selenium.webdriver.common.by import By
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from utils import setUpProcess, cambiarIdioma, descargarArchivo, checkFile

from time import sleep

class app_test_case(unittest.TestCase):

    def setUp(self):

        setUpProcess(self)

    def test_download_datosCompletos(self):
        driver = self.driver
        driver.get(self.base_url)

        cambiarIdioma(self, driver)

        print('Seleccionar datos en el tab')
        # hay un tiempo hasta que el tab es funcional
        sleep(60)
        WebDriverWait(driver, 40).until(
            EC.element_to_be_clickable((By.XPATH, "//iframe[@allowtransparency='true']"))
        )
        # hay un tiempo hasta que el tab es funcional
        sleep(4)
        driver.switch_to.default_content()

        descargarArchivo(self, driver)

        fileName = "Descargar datos_Datos completos_data.csv"
        checkFile(self, fileName)

    def tearDown(self):
        print('finish')
        self.driver.quit()

if __name__ == "__main__":
    unittest.main()