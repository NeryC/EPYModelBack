import pandas as pd
import datetime as dt
import json
import os
import csv
import io

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def proyeccionr():
    print(f'Hi, {"proyection Rs"}')
    # dataset proyección
    df2 = pd.read_csv(os.path.join(BASE_DIR, 'data/proyR.csv'), header=0)
    # proyecciones anteriores
    dfant = pd.read_csv(os.path.join(BASE_DIR, 'data/sim_SEIRHUF.csv'), header=0)
    dfant.rename(columns={'date': 'fecha'}, inplace=True)
    dfant['fecha'] = pd.to_datetime(dfant['fecha'], errors='coerce')
    dfant['fecha'] = dfant['fecha'].dt.strftime('%Y-%m-%d')
    dfant = dfant[['fecha', 'dailyR']]
    # proyecciones subregistro
    dfant_sub = pd.read_csv(os.path.join(
        BASE_DIR, 'data/sim_SEIRHUF.csv'), header=0)
    dfant_sub.rename(columns={'date': 'fecha'}, inplace=True)
    dfant_sub['fecha'] = pd.to_datetime(dfant_sub['fecha'], errors='coerce')
    dfant_sub['fecha'] = dfant_sub['fecha'].dt.strftime('%Y-%m-%d')
    dfant_sub = dfant_sub[['fecha', 'dailyR_sin_subRegistro']]
    # datos ant
    dfdatos = pd.read_csv(os.path.join(BASE_DIR, 'data/confirmado_diarios_revisado.csv'), header=0)
    dfmax = pd.read_csv(os.path.join(BASE_DIR, 'data/REGISTRO_DIARIO_Datos_completos_data.csv'), header=0, sep=';')
    Cantidad_Max = dfmax['Cantidad Pruebas'].max()
    dfdatos.rename(columns={'Fecha': 'fecha',
                            'Confirmado_diario': 'Reportados'}, inplace=True)
    dfdatos['fecha'] = pd.to_datetime(dfdatos['fecha'], errors='coerce')
    dfdatos['fecha'] = dfdatos['fecha'].dt.strftime('%Y-%m-%d')
    dfdatos['fecha'] = pd.to_datetime(dfdatos['fecha'], errors='coerce')
    dfdatos['fecha'] = dfdatos['fecha'].dt.strftime('%Y-%m-%d')
    dfdatos = dfdatos[['fecha', 'Reportados']]
    # ajustes de los datasets
    df2.rename(columns={'date': 'fecha'}, inplace=True)
    df = pd.to_datetime(df2['fecha'], errors='coerce')
    df = df.dt.strftime('%Y-%m-%d')
    df = df.to_frame()
    df.insert(1, 'peor', df2['unc_h'])
    df.insert(2, 'mejor', df2['unc_l'])
    df.insert(3, 'proy', df2['proj'])
    df.insert(4, 'eq', df2['eq'])
    df.insert(5, 'X2w', df2['m2w'])
    df.insert(6, 'X4w', df2['m4w'])
    df.insert(7, 'q25', df2['q25'])
    df.insert(8, 'q75', df2['q75'])
    df.insert(9, 'X10p', df2['X10p_h'])
    df.insert(10, 'X20p', df2['X20p_l'])
    df = pd.merge(df, dfant, on='fecha', how='outer')
    df = pd.merge(df, dfant_sub, on='fecha', how='outer')
    df = pd.merge(df, dfdatos, on='fecha', how='outer')
    df.insert(13, 'CapacidadMax', Cantidad_Max)
    df.insert(14, 'FechaCapacidadMax', dfdatos['fecha'].max())
    result = df.to_json(r'results/proyR.json', orient="records")
    return


def proyeccionh():
    print(f'Hi, {"proyection H"}')
    # dataset proyección
    df2 = pd.read_csv(os.path.join(BASE_DIR, 'data/proyH.csv'), header=0)
    # proyecciones anteriores
    dfant = pd.read_csv(os.path.join(BASE_DIR, 'data/sim_SEIRHUF.csv'), header=0)
    dfant.rename(columns={'date': 'fecha'}, inplace=True)
    dfant['fecha'] = pd.to_datetime(dfant['fecha'], errors='coerce')
    dfant['fecha'] = dfant['fecha'].dt.strftime('%Y-%m-%d')
    dfant = dfant[['fecha', 'H']]
    # datos ant
    dfdatos = pd.read_csv(os.path.join(BASE_DIR, 'data/REGISTRO_DIARIO_Datos_completos_data.csv'), header=0, sep=';')
    dfdatos.rename(columns={'Fecha': 'fecha',
                            'Internados Generales': 'Hospitalizados'}, inplace=True)
    dfdatos['fecha'] = pd.to_datetime(dfdatos['fecha'],format='"%Y-%m-%d"', errors='coerce')
    dfdatos['fecha'] = dfdatos['fecha'].dt.strftime('%d-%m-%Y')
    dfdatos['fecha'] = pd.to_datetime(dfdatos['fecha'],format='"%Y-%m-%d"', errors='coerce')
    dfdatos['fecha'] = dfdatos['fecha'].dt.strftime('%Y-%m-%d')
    dfdatos = dfdatos[['fecha', 'Hospitalizados']]
    # ajustes de los datasets
    df2.rename(columns={'date': 'fecha'}, inplace=True)
    df = pd.to_datetime(df2['fecha'], errors='coerce')
    df = df.dt.strftime('%Y-%m-%d')
    df = df.to_frame()
    df.insert(1, 'peor', df2['unc_h'])
    df.insert(2, 'mejor', df2['unc_l'])
    df.insert(3, 'proy', df2['proj'])
    df.insert(4, 'eq', df2['eq'])
    df.insert(5, 'X2w', df2['m2w'])
    df.insert(6, 'X4w', df2['m4w'])
    df.insert(7, 'q25', df2['q25'])
    df.insert(8, 'q75', df2['q75'])
    df.insert(9, 'X10p', df2['X10p_h'])
    df.insert(10, 'X20p', df2['X20p_l'])
    df = pd.merge(df, dfant, on='fecha', how='outer')
    df = pd.merge(df, dfdatos, on='fecha', how='outer')
    df.insert(13, 'CapacidadMax', 1319)
    df.insert(14, 'FechaCapacidadMax', '2020-12-31')
    result = df.to_json(r'results/proyH.json', orient="records")
    return


def proyeccionu():
    print(f'Hi, {"proyection U"}')
    ##fecha inicial
    fecha = dt.date(2020, 3, 6)
    # dataset proyección
    df2 = pd.read_csv(os.path.join(BASE_DIR, 'data/proyU.csv'), header=0)
    # proyecciones anteriores
    dfant = pd.read_csv(os.path.join(BASE_DIR, 'data/sim_SEIRHUF.csv'), header=0)
    dfant.rename(columns={'date': 'fecha'}, inplace=True)
    dfant['fecha'] = pd.to_datetime(dfant['fecha'], errors='coerce')
    dfant['fecha'] = dfant['fecha'].dt.strftime('%Y-%m-%d')
    dfant = dfant[['fecha', 'U']]
    # datos ant
    dfdatos = pd.read_csv(os.path.join(BASE_DIR, 'data/REGISTRO_DIARIO_Datos_completos_data.csv'), header=0, sep=';')
    dfdatos.rename(columns={'Fecha': 'fecha',
                            'Internados UTI': 'UTI'}, inplace=True)
    dfdatos['fecha'] = pd.to_datetime(dfdatos['fecha'],format='"%Y-%m-%d"', errors='coerce')
    dfdatos['fecha'] = dfdatos['fecha'].dt.strftime('%d-%m-%Y')
    dfdatos['fecha'] = pd.to_datetime(dfdatos['fecha'],format='"%Y-%m-%d"', errors='coerce')
    dfdatos['fecha'] = dfdatos['fecha'].dt.strftime('%Y-%m-%d')
    dfdatos = dfdatos[['fecha', 'UTI']]
    # ajustes de los datasets
    df2.rename(columns={'date': 'fecha'}, inplace=True)
    df = pd.to_datetime(df2['fecha'], errors='coerce')
    df = df.dt.strftime('%Y-%m-%d')
    df = df.to_frame()
    df.insert(1, 'peor', df2['unc_h'])
    df.insert(2, 'mejor', df2['unc_l'])
    df.insert(3, 'proy', df2['proj'])
    df.insert(4, 'eq', df2['eq'])
    df.insert(5, 'X2w', df2['m2w'])
    df.insert(6, 'X4w', df2['m4w'])
    df.insert(7, 'q25', df2['q25'])
    df.insert(8, 'q75', df2['q75'])
    df.insert(9, 'X10p', df2['X10p_h'])
    df.insert(10, 'X20p', df2['X20p_l'])
    df = pd.merge(df, dfant, on='fecha', how='outer')
    df = pd.merge(df, dfdatos, on='fecha', how='outer')
    df.insert(13, 'CapacidadMax', 461)
    df.insert(14, 'FechaCapacidadMax', '2020-12-31')
    result = df.to_json(r'results/proyU.json', orient="records")
    return


def proyeccionf():
    print(f'Hi, {"proyection R"}')
    ##fecha inicial
    fecha = dt.date(2020, 3, 6)
    # dataset proyección
    df2 = pd.read_csv(os.path.join(BASE_DIR, 'data/proyF.csv'), header=0)
    # proyecciones anteriores
    dfant = pd.read_csv(os.path.join(BASE_DIR, 'data/sim_SEIRHUF.csv'), header=0)
    dfant.rename(columns={'date': 'fecha'}, inplace=True)
    dfant['fecha'] = pd.to_datetime(dfant['fecha'], errors='coerce')
    dfant['fecha'] = dfant['fecha'].dt.strftime('%Y-%m-%d')
    dfant = dfant[['fecha', 'dailyF']]
    # datos ant
    dfdatos = pd.read_csv(os.path.join(BASE_DIR, 'data/REGISTRO_DIARIO_Datos_completos_data.csv'), header=0, sep=';')
    Cantidad_Max = dfdatos['Cantidad Pruebas'].max()
    dfdatosF = pd.read_csv(os.path.join(BASE_DIR, 'data/Fallecidos_diarios_revisado.csv'), header=0)
    dfdatosF.rename(columns={'Fecha': 'fecha',
                             'Fallecido_diario': 'Fallecidos'}, inplace=True)
    dfdatosF['fecha'] = pd.to_datetime(dfdatosF['fecha'], errors='coerce')
    dfdatosF['fecha'] = dfdatosF['fecha'].dt.strftime('%Y-%m-%d')
    # dfdatosF['fecha'] = dfdatosF['fecha'].dt.strftime('%d-%m-%Y')
    dfdatosF['fecha'] = pd.to_datetime(dfdatosF['fecha'], errors='coerce')
    dfdatosF = dfdatosF[['fecha', 'Fallecidos']]
    # ajustes de los datasets
    df2.rename(columns={'date': 'fecha'}, inplace=True)
    df = pd.to_datetime(df2['fecha'], errors='coerce')
    df = df.dt.strftime('%Y-%m-%d')
    df = df.to_frame()
    df.insert(1, 'peor', df2['unc_h'])
    df.insert(2, 'mejor', df2['unc_l'])
    df.insert(3, 'proy', df2['proj'])
    df.insert(4, 'eq', df2['eq'])
    df.insert(5, 'X2w', df2['m2w'])
    df.insert(6, 'X4w', df2['m4w'])
    df.insert(7, 'q25', df2['q25'])
    df.insert(8, 'q75', df2['q75'])
    df.insert(9, 'X10p', df2['X10p_h'])
    df.insert(10, 'X20p', df2['X20p_l'])
    df = pd.merge(df, dfant, on='fecha', how='outer')
    dfdatosF['fecha'] = dfdatosF['fecha'].astype(str).tolist()
    df = pd.merge(df, dfdatosF, on='fecha', how='outer')
    df.insert(13, 'CapacidadMax', Cantidad_Max)
    df.insert(14, 'FechaCapacidadMax', dfdatosF['fecha'].max())
    result = df.to_json(r'results/proyF.json', orient="records")
    return


