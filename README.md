## EPYModel - BackEnd

_Este es el backend de la pagina http://epymodel.uaa.edu.py/ querenderiza graficos sobre el COVID-19 en paraguay y brinda un simulador los datos proporcionados_

## Comenzando 🚀

_Estas instrucciones te permitirán obtener una copia del proyecto en funcionamiento en tu máquina local para propósitos de desarrollo._

Mira **Despliegue** para conocer como desplegar el proyecto.

### Pre-requisitos 📋

Necesitas tender instalado:

```plaintext
python
r
Google Chrome
```

### Instalación 🔧

una vez instalado python instalar los paquetes:

```plaintext
pip install -r .src/scripts/requirements.txt
```

una vez instalado r instalar los paquetes:

```plaintext
Rscript ./src/model_seirh/install_packages.R
```

Instalar last dependencies del proyecto:

```plaintext
npm install
```

### Scripts 🕹️

Estos scripts te serviran Para ejecutar etapas de la ejecucion sin el el temporizador

| **Script** | **Descripcion** |
| --- | --- |
| start-main-flow | Ejecuta todas las etapas del proyecto sin esperar el temporizador. |
| download-raw-data | Ejecuta el web scraping que descarga los archivos necesarios para la ejecucion del programa |
| pre-processing | Ejecuta el pre procesamiento de los datos descargados con el web scraping |
| test\_seirhuf | Ejecuta el código de R que procesa los datos para generar la información de los gráficos |
| generate-graphic | Genera los csv que serán usados para los gráficos |
| generate-simulation | Genera los csv que serán usados en la pagina de simulación |
| get-simulation | Te brinda una simulación a la que le faltan los parámetros de entrada.  
ej: '\[6051398.25123154, 23328.0100469225, 28866.7911822539, 2584394.19430157, 76.2346142396735, 22.9165247793871, 18986.0560013952, 1131800.13818029\]' '\[1.1, 1.2, 1.3, 0.8, 0.7, 0.9\]' 100 1000 0.5 false |

---

⌨️ con ❤️ por [Nery Cano](https://www.linkedin.com/in/nery-cano-dev/) 😊