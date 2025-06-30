from scipy.integrate import odeint
import numpy as np
import json
import os
import sys

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
    S, E, I, C, H, U, F, O = x

    # checkeamos si no nos pasamos del UCI threshold
    if U > UCI_threshold:
        lambda_H_to_F_ = 0.25
        lambda_U_to_F_ = 0.5
    else:
        lambda_H_to_F_ = 0.15
        lambda_U_to_F_ = 0.45

    # definimos beta
    t_idx = int(np.floor(t/30))
    if t_idx > len(Rt)-1:
        t_idx = len(Rt)-1
    beta = (Rt[t_idx] * gamma * N) / S

    dSdt = - (beta * (S / N) * I) - (eta * V_filtered) + (psi * O)
    dEdt = (beta * (S / N) * I) - (alpha * E)
    dIdt = (alpha * E) - (gamma * I)
    dCdt = (gamma * I)
    dHdt = (lambda_I_to_H * gamma * I) - (lambda_H_to_U * delta_H_to_U * H) - (lambda_H_to_F_ * delta_H_to_F * H) - (lambda_H_to_O * delta_H_to_O * H)
    dUdt = (lambda_H_to_U * delta_H_to_U * H) - (lambda_U_to_F_ * phi_U_to_F * U) - (lambda_U_to_O * phi_U_to_O * U)
    dFdt = (lambda_I_to_F * gamma * I) + (lambda_H_to_F_ * delta_H_to_F * H) + (lambda_U_to_F_ * phi_U_to_F * U)
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

    t = np.arange(0, num_de_dias, 0.1)
    x = odeint(odes, x0, t, args=(Rt, UCI_threshold, V_filtered, lambda_I_to_H, lambda_H_to_O, lambda_U_to_O, lambda_I_to_O))

    # Extraer solo los valores diarios (índices donde t es entero)
    daily_indices = np.where(np.isclose(t, np.round(t)))[0]
    days = np.round(t[daily_indices]).astype(int)
    x_daily = x[daily_indices]

    output_dict = {
        "susceptible": [{"day": int(day), "value": float(val)} for day, val in zip(days, x_daily[:, 0])],
        "exposed": [{"day": int(day), "value": float(val)} for day, val in zip(days, x_daily[:, 1])],
        "infectious": [{"day": int(day), "value": float(val)} for day, val in zip(days, x_daily[:, 2])],
        "cumulative": [{"day": int(day), "value": float(val)} for day, val in zip(days, x_daily[:, 3])],
        "hospitalized": [{"day": int(day), "value": float(val)} for day, val in zip(days, x_daily[:, 4])],
        "uci": [{"day": int(day), "value": float(val)} for day, val in zip(days, x_daily[:, 5])],
        "cumulative_deaths": [{"day": int(day), "value": float(val)} for day, val in zip(days, x_daily[:, 6])],
        "immune": [{"day": int(day), "value": float(val)} for day, val in zip(days, x_daily[:, 7])],
    }
    result = json.dumps(output_dict)

    if firstSimulation:
        with open(os.path.join(ROOT_DIR, 'public/results/simulation.json'), mode='w') as jsonfile:
            jsonfile.write(result)
    else:
        print(result)

if __name__ == "__main__":
    main(sys.argv[1:])
