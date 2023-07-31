install.packages("tidyverse", repos = "http://cran.us.r-project.org")
install.packages("dplyr", repos = "http://cran.us.r-project.org")
install.packages("rio", repos = "http://cran.us.r-project.org")
install.packages("rstan", repos = "http://cran.us.r-project.org")
install.packages("deSolve", repos = "http://cran.us.r-project.org")
install.packages("bayesplot", repos = "http://cran.us.r-project.org")
install.packages("tictoc", repos = "http://cran.us.r-project.org")
install.packages("modules", repos = "http://cran.us.r-project.org")
install.packages("roll", repos = "http://cran.us.r-project.org")
install.packages("ensurer", repos = "http://cran.us.r-project.org")
install.packages("R.utils")
install.packages("fpeek")
install.packages("glu", repos = "http://cran.us.r-project.org")

setwd(getwd())
root_path <- getwd()

installed_previously <- read.csv(paste(
    root_path,
    "/src/model_seirh/installed_previously.csv",
    sep = ""
))

base_r <- as.data.frame(installed.packages())

to_install <- setdiff(installed_previously, base_r)

install.packages(to_install, repos = "http://cran.us.r-project.org")
