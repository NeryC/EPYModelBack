from scipy.integrate import odeint
import numpy as np
import math
import csv
import sys
import json
import os
import io

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(os.path.dirname(BASE_DIR))

# constantes
N = 7252672
alpha = 1/3
gamma = 1/7
psi = 1/180
eta = 0.9
delta_H_to_U = 1/7
delta_H_to_F = 1/9
delta_H_to_O = 1/11
phi_U_to_F = 1/11
phi_U_to_O = 1/12
lambda_I_to_F = 0.002
lambda_H_to_U = 0.2
lambda_H_to_F = 0.15
lambda_U_to_F = 0.45

def odes(x, t, Rt, UCI_threshold, V_filtered, lambda_I_to_H, lambda_H_to_O, lambda_U_to_O, lambda_I_to_O):
    # asignamos cada ODE a un elemento del vector input
    S, E, I, C, H, U, F, O = x

    # checkeamos si no nos pasamos del UCI threshold
    if U > UCI_threshold:
        lambda_H_to_F = 0.25
        lambda_U_to_F = 0.5
    else:
        lambda_H_to_F = 0.15
        lambda_U_to_F = 0.45

    # definimos beta
    if(math.floor(t/30) > len(Rt)-1):
        t=len(Rt)-1

    beta = (Rt[math.floor(t/30)] * gamma * N) / S

    # definimos cada ODE
    dSdt = - (beta * (S / N) * I) - (eta * V_filtered) + (psi * O)
    dEdt = (beta * (S / N) * I) - (alpha * E)
    dIdt = (alpha * E) - (gamma * I)
    dCdt = (gamma * I)
    dHdt = (lambda_I_to_H * gamma * I) - (lambda_H_to_U * delta_H_to_U * H) - (lambda_H_to_F * delta_H_to_F * H) - (lambda_H_to_O * delta_H_to_O * H)
    dUdt = (lambda_H_to_U * delta_H_to_U * H) - (lambda_U_to_F * phi_U_to_F * U) - (lambda_U_to_O * phi_U_to_O * U)
    dFdt = (lambda_I_to_F * gamma * I) + (lambda_H_to_F * delta_H_to_F * H) + (lambda_U_to_F * phi_U_to_F * U)
    dOdt = (lambda_I_to_O * gamma * I) + (lambda_H_to_O * delta_H_to_O * H) + (lambda_U_to_O * phi_U_to_O * U) + (eta * V_filtered) - (psi * O)

    return [dSdt, dEdt, dIdt, dCdt, dHdt, dUdt, dFdt, dOdt]

def main(params):
    x0 = json.loads(params[0])
    Rt = json.loads(params[1])
    UCI_threshold = json.loads(params[2])
    V_filtered = json.loads(params[3])
    lambda_I_to_H = json.loads(params[4])
    firstSimulation = json.loads(params[5])
    num_de_dias = (len(Rt)*30)

    lambda_H_to_O = 1 - lambda_H_to_U - lambda_H_to_F
    lambda_U_to_O = 1 - lambda_U_to_F
    lambda_I_to_O = 1 - lambda_I_to_H - lambda_I_to_F
        
    # declaramos un vector de tiempo para cada uno de los dias
    t = np.arange(0, num_de_dias)
    # usamos odeint para resolver las ecuaciones
    x = odeint(odes, x0, t, args=(Rt, UCI_threshold, V_filtered, lambda_I_to_H, lambda_H_to_O, lambda_U_to_O, lambda_I_to_O))

    # Creamos un diccionario vacío para cada variable
    susceptible_dict = []
    exposed_dict = []
    infectious_dict = []
    cumulative_dict = []
    hospitalized_dict = []
    uci_dict = []
    cumulative_deaths_dict = []
    immune_dict = []

    # Iteramos sobre t y guardamos los valores de cada variable en su respectivo diccionario
    old_int = np.float64(-1)
    for i in t:
        new_int = np.floor(i)
        if new_int != old_int:
            integer_i = int(i)
            susceptible_dict.append({"day":integer_i,"value":x[integer_i, 0]})
            exposed_dict.append({"day":integer_i,"value":x[integer_i, 1]})
            infectious_dict.append({"day":integer_i,"value":x[integer_i, 2]})
            cumulative_dict.append({"day":integer_i,"value":x[integer_i, 3]})
            hospitalized_dict.append({"day":integer_i,"value":x[integer_i, 4]})
            uci_dict.append({"day":integer_i,"value":x[integer_i, 5]})
            cumulative_deaths_dict.append({"day":integer_i,"value":x[integer_i, 6]})
            immune_dict.append({"day":integer_i,"value":x[integer_i, 7]})
            old_int = new_int

    # Creamos un diccionario final con todas las variables
    output_dict = {
        "susceptible": susceptible_dict,
        "exposed": exposed_dict,
        "infectious": infectious_dict,
        "cumulative": cumulative_dict,
        "hospitalized": hospitalized_dict,
        "uci": uci_dict,
        "cumulative_deaths": cumulative_deaths_dict,
        "immune": immune_dict
    }
    # print(json.dumps(output_dict))
    # Imprimimos el JSON resultante
    result = json.dumps(output_dict)

    if firstSimulation:
        # Save JSON file
        with open(os.path.join(ROOT_DIR, 'public/results/simulation.json'), mode='w') as jsonfile:
            jsonfile.write(result)
    else:
        print(result)



if __name__ == "__main__":
   main(sys.argv[1:])
