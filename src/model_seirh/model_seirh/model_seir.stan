functions {
  real[] seirhuf(real t, real[] y, real[] theta, real[] x_r, int[] x_i) {
    real S = y[1];
    real E = y[2];
    real I = y[3];
    real R = y[4];
    real O = y[5];
    real beta    = theta[1];
    int  winsize = x_i[1];
    real imported[winsize]   = x_r[1:winsize];
    real vaccinated[winsize] = x_r[(winsize+1):(2*winsize)];
    real N     = x_r[2*winsize+1];
    real alpha = x_r[2*winsize+2];
    real gamma = x_r[2*winsize+3];
    real psi   = x_r[2*winsize+4];
    real eta   = x_r[2*winsize+5];
    real dS_dt;
    real dE_dt;
    real dI_dt;
    real dR_dt;
    real dO_dt;
    int index = 1; while (index < t) {index = index + 1;}
    if (index > winsize) {index = winsize;}
    dS_dt = -beta * I * S / N + psi * O - eta * vaccinated[index] - imported[index];
    dE_dt =  beta * I * S / N - alpha * E;
    dI_dt =                     alpha * E - gamma * I;
    dR_dt =                                 gamma * I + imported[index];
    dO_dt =  gamma * I + imported[index] - psi * O + eta * vaccinated[index];
    return {dS_dt, dE_dt, dI_dt, dR_dt, dO_dt};
   }
  
  real[,] extractf(real[] y0, real t0, real[] ts, real[] param, data real[] x_r, data int[] x_i) {
    int winsize = x_i[1];
    real pred[winsize,5];
    real out[winsize,1];
    pred = integrate_ode_rk45(seirhuf, y0, t0, ts, param, x_r, x_i, 1e-8, 1e-8, 1e6);
    for (n in 2:winsize) {
      out[n,1] = pred[n,4] - pred[n-1,4];
    }
    out[1,1] = pred[1,4] - y0[4];
    return out;
  }
}

data {
  int winsize;
  real y0[5];
  real t0;
  real ts[winsize];
  real odeparam[5];
  real data_imported[winsize];
  real data_daily[winsize];
  real data_vaccinated[winsize];
}

transformed data {
  real x_r[2*winsize + 5];
  int  x_i[1] = {winsize};
  x_r[1:winsize] = data_imported;
  x_r[(winsize+1):(2*winsize)] = data_vaccinated;
  x_r[(2*winsize+1):(2*winsize+5)] = odeparam;
}

parameters {
  real<lower=0.0,upper=    0.8> beta;
  real<lower=0.0,upper=10000.0> sigma_r;
}

model {
  real pred[winsize,1];
  beta  ~ uniform(0.0,0.8);
  pred = extractf(y0, t0, ts, {beta}, x_r, x_i);
  data_daily ~ normal(to_array_1d(col(to_matrix(pred), 1)), sigma_r);
}

