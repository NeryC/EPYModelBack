
functions {
  real[] seirhuf(real t, real[] y, real[] theta, real[] x_r, int[] x_i) {
    real S = y[1];
    real E = y[2];
    real I = y[3];
    real R = y[4];
    real H = y[5];
    real U = y[6];
    real F = y[7];
    real lamih   = theta[1];
    real lamif   = theta[2];
    real lamhu   = theta[3];
    real lamhf   = theta[4];
    real lamuf   = theta[5];
    int  winsize = x_i[1];
    real imported[winsize] = x_r[1:winsize];
    real N       = x_r[winsize+1];
    real alpha   = x_r[winsize+2];
    real gamma   = x_r[winsize+3];
    real deltahu = x_r[winsize+4];
    real deltahf = x_r[winsize+5];
    real deltaho = x_r[winsize+6];
    real phiuf   = x_r[winsize+7];
    real phiuo   = x_r[winsize+8];
    real beta    = x_r[winsize+9];
    real dS_dt;
    real dE_dt;
    real dI_dt;
    real dR_dt;
    real dH_dt;
    real dU_dt;
    real dF_dt;
    int index = 1; while (index < t) {index = index + 1;}
    if (index > winsize) {index = winsize;}
    dS_dt = -beta * I * S / N;
    dE_dt =  beta * I * S / N - alpha * E;
    dI_dt =                     alpha * E - gamma * I;
    dR_dt =                                 gamma * I + imported[index];
    dH_dt = lamih * gamma * I - lamhu * deltahu * H - lamhf * deltahf * H - (1 - lamhu - lamhf) * deltaho * H ;
    dU_dt = lamhu * deltahu * H - lamuf * phiuf * U - (1 - lamuf) * phiuo * U;
    dF_dt = lamif * gamma * I + lamuf * phiuf * U + lamhf * deltahf * H;
    return {dS_dt, dE_dt, dI_dt, dR_dt, dH_dt, dU_dt, dF_dt};
  }
  
  real[,] extractf(real[] y0, real t0, real[] ts, real[] param, data real[] x_r, data int[] x_i) {
    int winsize = x_i[1];
    real pred[winsize,7];
    real out[winsize,3];
    pred = integrate_ode_rk45(seirhuf, y0, t0, ts, param, x_r, x_i, 1e-8, 1e-8, 1e6);
    for (n in 2:winsize) {
      out[n,1] = pred[n,5];
      out[n,2] = pred[n,6];
      out[n,3] = pred[n,7] - pred[n-1,7];
    }
    out[1,1] = pred[1,5];
    out[1,2] = pred[1,6];
    out[1,3] = pred[1,7] - y0[7];
    return out;
  }
}

data {
  int winsize;
  real y0[7];
  real t0;
  real ts[winsize];
  real odeparam[9];
  real data_imported[winsize];
  real data_hosp[winsize];
  real data_uci[winsize];
  real data_dead[winsize];
}

transformed data {
  real x_r[winsize + 9];
  int  x_i[1] = {winsize};
  x_r[1:winsize] = data_imported;
  x_r[(winsize+1):(winsize+9)] = odeparam;
}

parameters {
  real<lower=0.00,upper=0.15 > lamih;
  real<lower=0.00,upper=0.30 > lamhu;
  real<lower=0.00,upper=0.004> lamif;
  real<lower=0.00,upper=0.25 > lamhf;
  real<lower=0.20,upper=1.00 > lamuf;
  real<lower=0.0,upper=1000> sigma_h;
  real<lower=0.0,upper=200 > sigma_u;
  real<lower=0.0,upper=200 > sigma_f;
}

model {
  real pred[winsize,3];
  lamih ~ uniform(0.00,0.15 );
  lamhu ~ uniform(0.00,0.30 );
  lamif ~ uniform(0.00,0.004);
  lamhf ~ uniform(0.00,0.25 );
  lamuf ~ normal(0.4,0.1);
  pred = extractf(y0, t0, ts, {lamih,lamif,lamhu,lamhf,lamuf}, x_r, x_i);
  data_hosp  ~ normal(to_array_1d(col(to_matrix(pred), 1)), sigma_h);
  data_uci   ~ normal(to_array_1d(col(to_matrix(pred), 2)), sigma_u);
  data_dead  ~ normal(to_array_1d(col(to_matrix(pred), 3)), sigma_f);
}

