import pandas as pd

# Lee el archivo CSV
data = pd.read_csv('Descargar datos_Datos completos_data.csv', sep=';')
# Convierte la columna de fecha al formato adecuado
data['Fecha Confirmacion'] = pd.to_datetime(data['Fecha Confirmacion'])

# Ordena el dataframe por la columna de fecha
data = data.sort_values('Fecha Confirmacion')

# Formatea la columna de fecha en el formato "DD/MM/YYYY"
data['Fecha Confirmacion'] = data['Fecha Confirmacion'].dt.strftime('%d/%m/%Y')

# Guarda el dataframe ordenado en un nuevo archivo CSV
data.to_csv('DatosDiario.csv', sep=';', index=False, float_format='%.0f')