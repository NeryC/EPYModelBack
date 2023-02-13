# model_seirh

Pasos para la ejecucion:

Instalar CRAN

Agregar los archivos de datos a la carpeta de "datx" de:
    Descargar datos_Datos completos_data.csv
    FALLECIDOS_Datos completos_data.csv
    REGISTRO DIARIO_Datos completos_data.csv

cd model_seirh
./preprocessing
cp ../datx/Descargar\ datos_Datos\ completos_data.csv ../data
cp ../datx/FALLECIDOS_Datos\ completos_data.csv ../data
cp ../datx/REGISTRO\ DIARIO_Datos\ completos_data.csv ../data
Rscript test_seirhuf_normal.R &
nohup Rscript test_seirhuf_normal.R &


install.packages("tidyverse")
install.packages("dplyr")