import { logger } from '../utils/logger.js';
import {
  downloadRawData,
  execPreProcessing,
  moveFiles,
  execTest_seirhuf_normal,
  generateGraphicFiles,
  generateSimulationFiles,
} from '../infrastructure/processes/steps.js';

export const executeMainFlow = async (): Promise<void> => {
  logger.info('********** Iniciando Actualizacion **********');

  logger.info('========= 1 - Descargar Datos =========');
  downloadRawData();

  logger.info('========= 2 - Pre Procesamiento =========');
  execPreProcessing();

  logger.info('========= 3 - Mover Archivos =========');
  moveFiles();

  logger.info('========= 4 - test_seirhuf_normal =========');
  execTest_seirhuf_normal();

  logger.info('========= 5 - Generar Archivos de Graficos =========');
  generateGraphicFiles();

  logger.info('========= 6 - Generar Archivos de Simulacion =========');
  generateSimulationFiles();

  logger.info('********** Actualizacion Finalizada **********');
};

