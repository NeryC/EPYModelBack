"""
main.py
=======
Punto de entrada del pipeline de post-procesamiento de proyecciones.

Este script ejecuta las cuatro funciones de proyección en secuencia:
  1. proyeccionF() — Fallecidos diarios
  2. proyeccionR() — Casos reportados diarios
  3. proyeccionU() — UCI ocupados
  4. proyeccionH() — Hospitalizados generales

Cada función combina las proyecciones del modelo R/Stan con los datos
observados reales y exporta el resultado como JSON y CSV en public/results/.

Uso
---
  python main.py

Se ejecuta típicamente de forma programada (cron) después de que el modelo
bayesiano R/Stan (test_seirhuf_normal.R + projection_at_time.R) haya
generado los archivos proyR/H/U/F.csv actualizados.
"""

from cron import proyeccionF, proyeccionH, proyeccionR, proyeccionU

if __name__ == "__main__":
    proyeccionF()
    proyeccionR()
    proyeccionU()
    proyeccionH()
