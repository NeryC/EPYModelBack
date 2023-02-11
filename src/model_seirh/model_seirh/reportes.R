import("grDevices", "pdf", "dev.off")
import("graphics", "pairs")
import("rstan", "traceplot")

# print(traceplot(...)) se explica en R FAQs [https://cran.r-project.org/doc/FAQ/R-FAQ.html#Why-do-lattice_002ftrellis-graphics-not-work_003f]

graficar_parametros_vs_iteraciones <- function(.fitmodel, .parametros) {
  
  if(missing(.parametros)) {
    print(traceplot(.fitmodel))
  }else{
    print(traceplot(.fitmodel, pars = .parametros))
  }
  
}

graficar_pares_entre_parametros <- function(.fitmodel, .parametros) {
  
  if(missing(.parametros)) {
    pairs(.fitmodel)
  }else{
    pairs(.fitmodel, pars = .parametros)
  }
  
}

export('graficar_parametros_vs_iteraciones_en_pdf')
graficar_parametros_vs_iteraciones_en_pdf <- function(.filepath, .fitmodel, .parametros){
  
  pdf(file = .filepath)
  graficar_parametros_vs_iteraciones(.fitmodel, .parametros)
  dev.off()
  
}

export("graficar_pares_entre_parametros_en_pdf")
graficar_pares_entre_parametros_en_pdf <- function(.filepath, .fitmodel, .parametros){
  
  pdf(file = .filepath)
  graficar_pares_entre_parametros(.fitmodel, .parametros)
  dev.off()
  
}