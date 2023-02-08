import csv
import pandas as pd
import numpy as np
import datetime as dt


df = pd.read_csv('time_seq.csv', header=0)
#,  sep=';', lineterminator='\r'
fecha = dt.date(2020, 3, 17)
df.insert(0, "fecha", fecha)
#df['Fecha'] = df['Fecha'] + datetime.timedelta(days=df['time'])
df['fecha'] = [fecha + dt.timedelta(days=d) for d in df.time]
df['fecha'] = pd.to_datetime(df['fecha'])
df.drop('time', axis=1, inplace=True)
df.index = df['fecha']
df.drop('fecha', axis=1, inplace=True)
print(df)