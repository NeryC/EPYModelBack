export("metaconstructor_datos_init")
metaconstructor_datos_init <- function(.datos_diarios, .t0, .t, .parametros_ODE, .tamano_ventana){
  
  constructor_datos_init <- function(..n_shift){

    cantidad_reportados  <- .datos_diarios$reportados
    cantidad_importados  <- .datos_diarios$importados
    cantidad_inmunizados <- .datos_diarios$inmunizados
    
    datos_init <-
      list(
        winsize = .tamano_ventana,
        t0      = .t0,
        ts      = .t,
        odeparam        = .parametros_ODE,
        data_daily      = cantidad_reportados [..n_shift + 1:.tamano_ventana],
        data_imported   = cantidad_importados [..n_shift + 1:.tamano_ventana],
        data_vaccinated = cantidad_inmunizados[..n_shift + 1:.tamano_ventana]
      )
    
    return(datos_init)
  }
  
  return(constructor_datos_init)
}
 
export("metaconstructor_datos_SEIR")
metaconstructor_datos_SEIR <- function(.datos_diarios, .t0, .t, .parametros_ODE, .tamano_ventana){
  
  constructor_datos_SEIR <- function(..n_shift, ..estado_inicial){
    
    cantidad_reportados  <- .datos_diarios$reportados
    cantidad_importados  <- .datos_diarios$importados
    cantidad_inmunizados <- .datos_diarios$inmunizados
    
    datos_SEIR <-
      list(
        winsize = .tamano_ventana,
        y0      = ..estado_inicial,
        t0      = .t0,
        ts      = .t,
        odeparam        = .parametros_ODE,
        data_daily      = cantidad_reportados [..n_shift + 1:.tamano_ventana],
        data_imported   = cantidad_importados [..n_shift + 1:.tamano_ventana],
        data_vaccinated = cantidad_inmunizados[..n_shift + 1:.tamano_ventana]
      )
    
    return(datos_SEIR)
  }
  
  return(constructor_datos_SEIR)
}


export("metaconstructor_datos_SEIRH")
metaconstructor_datos_SEIRH <- function(.datos_diarios, .t0, .t, .parametros_ODE, .tamano_ventana){
  
  constructor_datos_SEIRH <- function(..n_shift, ..estado_inicial){
    
    cantidad_reportados     <- .datos_diarios$reportados
    cantidad_hospitalizados <- .datos_diarios$hospitalizados
    cantidad_uci            <- .datos_diarios$uci
    cantidad_fallecidos     <- .datos_diarios$fallecidos
    cantidad_importados     <- .datos_diarios$importados
    cantidad_inmunizados    <- .datos_diarios$inmunizados
    
    datos_SEIRH <-
      list(
        winsize = .tamano_ventana,
        y0      = ..estado_inicial,
        t0      = .t0,
        ts      = .t,
        odeparam        = .parametros_ODE,
        data_daily      = cantidad_reportados     [..n_shift + 1:.tamano_ventana],
        data_hosp       = cantidad_hospitalizados [..n_shift + 1:.tamano_ventana],
        data_uci        = cantidad_uci            [..n_shift + 1:.tamano_ventana],
        data_dead       = cantidad_fallecidos     [..n_shift + 1:.tamano_ventana],
        data_imported   = cantidad_importados     [..n_shift + 1:.tamano_ventana],
        data_vaccinated = cantidad_inmunizados    [..n_shift + 1:.tamano_ventana]
      )
    
    return(datos_SEIRH)
  }
  
  return(constructor_datos_SEIRH)
}

export("ejecutar_inferencia_estadistica")
ejecutar_inferencia_estadistica <- function(.modelo, .datos, .chains, .warmup, .iteraciones, .refresh = 100, .adapt_delta = 0.94, .seed = NA){
  
  fitmodel <-
    rstan::sampling(
      .modelo,
      data    = .datos,
      chains  = .chains,
      warmup  = .warmup,
      iter    = .iteraciones,
      seed    = .seed,
      refresh = .refresh,
      control = list(adapt_delta = .adapt_delta, max_treedepth = 15),
      verbose = FALSE
    )
  
  return(fitmodel)
}

export("compilar_modelo")
compilar_modelo <- function(.modelo_filepath){
  
  #r <- rstan::stanc(.modelo_filepath)
  modelo <- rstan::stan_model(.modelo_filepath) # Ignorar: g++ not found.
  return(modelo)
  
}
