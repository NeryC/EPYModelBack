functions {
  real[] sir(real t, real[] y, real[] theta, real[] x_r, int[] x_i) {
    real S = y[1];
    real E = y[2];
    real I = y[3];
    real R = y[4];
    real O = y[5];
    int winsize = x_i[1];
    real N      = x_r[2*winsize+1];
    real alpha  = x_r[2*winsize+2];
    real gamma  = x_r[2*winsize+3];
    real psi    = x_r[2*winsize+4];
    real eta    = x_r[2*winsize+5];
    real beta   = theta[1];
    real imported[winsize];
    real vaccinated[winsize];
    real dS_dt;
    real dE_dt;
    real dI_dt;
    real dR_dt;
    real dO_dt;
    int index = 1; while (index < t) {index = index + 1;}
    if (index > winsize) {index = winsize;}
    imported   = x_r[1:winsize];
    vaccinated = x_r[(winsize+1):(2*winsize)];
    dS_dt = -beta * I * S / N + psi * O - eta * vaccinated[index] - imported[index];
    dE_dt =  beta * I * S / N - alpha * E;
    dI_dt =                     alpha * E - gamma * I;
    dR_dt =                                 gamma * I + imported[index];
    dO_dt =  gamma * I + imported[index] - psi * O + eta * vaccinated[index];
    return {dS_dt, dE_dt, dI_dt, dR_dt, dO_dt};
  }
  
  real[] extracti(real t0, real[] ts, real[] param, data real[] x_r, data int[] x_i) {
    real e0 = param[1];
    real i0 = param[2];
    real beta = param[3];
    int winsize = x_i[1];
    real N  = x_r[2*winsize + 1];
    real r0 = x_r[2*winsize + 6];
    real y0[5] = {N - e0 - i0 - r0, e0, i0, r0, r0};
    real pred[winsize,5];
    real dr[winsize];
    pred = integrate_ode_rk45(sir, y0, t0, ts, {beta}, x_r, x_i);
    for (n in 2:winsize) {
      dr[n] = pred[n,4] - pred[n-1,4];
    }
    dr[1] = pred[1,4] - y0[4];
    return dr;
  }
}

data {
  int winsize;
  real t0;
  real ts[winsize];
  real odeparam[6];
  real data_daily[winsize];
  real data_imported[winsize];
  real data_vaccinated[winsize];
}

transformed data {
  real x_r[2*winsize + 6];
  int  x_i[1] = {winsize};
  x_r[1:winsize] = data_imported;
  x_r[(winsize+1):(2*winsize)] = data_vaccinated;
  x_r[(2*winsize+1):(2*winsize+6)] = odeparam;
}

parameters {
  real<lower= 0.0,upper=1000> sigma_r;
  real<lower= 0.0,upper=1000> i0;
  real<lower= 0.0,upper=1000> e0;
  real<lower=0,upper=0.8> beta;
}

model {
  e0 ~ uniform(0, 1000);
  i0 ~ uniform(0, 1000);
  beta ~ uniform(0, 0.8);
  data_daily ~ normal(extracti(t0, ts, {e0, i0, beta}, x_r, x_i), sigma_r);
}

