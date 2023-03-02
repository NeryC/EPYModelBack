import os
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from webdriver_manager.chrome import ChromeDriverManager

from selenium.webdriver.common.by import By
from selenium.webdriver.support.wait import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from time import sleep

def setUpProcess(self):
  chromeOptions = Options()
  chromeOptions.add_argument("--headless=new")
  chromeOptions.add_argument("--no-sandbox")
  chromeOptions.add_experimental_option('excludeSwitches', ['enable-logging'])

  self.driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=chromeOptions)
  params = {'behavior': 'allow', 'downloadPath': os.path.join(os.getcwd(), 'public','rawData')}
  self.driver.execute_cdp_cmd('Page.setDownloadBehavior', params)
  self.driver.implicitly_wait(30)
  path = 'https://public.tableau.com/app/profile/mspbs/viz/COVID19PY-Registros/Descargardatos'
  self.base_url = path

def cambiarIdioma(self, driver):
  # esto es necesario para que el archivo sea descargado con el nombre correcto
  print('Cambiar idioma')
  dropdown = WebDriverWait(driver, 20).until(
      EC.presence_of_element_located((By.XPATH, '//*[@id="root"]/div/footer/div[1]/div/div/div/div'))
  )
  dropdown.click()
  spanishOption = WebDriverWait(driver, 20).until(
      EC.presence_of_element_located((By.XPATH, '//*[@id="root"]/div/footer/div[1]/div/div/div/ul/li[contains(text(),"Español")]'))
  )
  spanishOption.click()

def descargarArchivo(self, driver):
  print('Seleccionar boton de descarga')
  # hay un tiempo hasta que el boton es funcional
  sleep(5)
  downloadButon = WebDriverWait(driver, 20).until(
      EC.element_to_be_clickable((By.XPATH, '//*[@id="root"]/div/div[4]/div[1]/div/div[2]/button[4]'))
  )
  downloadButon.click()

  sleep(20)
  print('Seleccionar ventana de opciones de descarga')
  downloadFrame = WebDriverWait(driver, 20).until(
      EC.presence_of_element_located((By.XPATH, "//div[@id='embedded-viz-wrapper']//iframe"))
  )
  driver.switch_to.frame(downloadFrame)
  sleep(5)
  downloadFrameOptionData = WebDriverWait(driver, 20).until(
      EC.presence_of_element_located((By.XPATH, "//div[@id='DownloadDialog-Dialog-Body-Id']//button[2]"))
  )
  downloadFrameOptionData.click()
  driver.switch_to.default_content()

  print('Moviendose a la nueva ventana')
  # hay un tiempo hasta que la ventana es funcional
  sleep(10)
  driver.switch_to.window(driver.window_handles[1])
  print('Click en opcionDatosCompletos')
  opcionDatosCompletos = WebDriverWait(driver, 20).until(
      EC.presence_of_element_located((By.XPATH, "//div[@id='Migrated Data']"))
  )
  opcionDatosCompletos.click()
  print('Click en botonDescargar')
  botonDescargar = WebDriverWait(driver, 20).until(
      EC.presence_of_element_located((By.XPATH, "//button[@data-tb-test-id='download-data-Button']"))
  )
  botonDescargar.click()
  sleep(40)

def checkFile(self, fileName):
  sleep(4)
  # print(os.path.join(os.getcwd(), 'public','rawData',fileName))
  # print(os.path.exists(os.path.join(os.getcwd(), 'public','rawData',fileName)))
  self.assertTrue( os.path.exists(os.path.join(os.getcwd(), 'public','rawData',fileName)), "no existe el archivo "+ fileName)

