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
  logger.info('********** Starting Update **********');

  logger.info('========= 1 - Download Data =========');
  downloadRawData();

  logger.info('========= 2 - Pre Processing =========');
  execPreProcessing();

  logger.info('========= 3 - Move Files =========');
  moveFiles();

  logger.info('========= 4 - test_seirhuf_normal =========');
  execTest_seirhuf_normal();

  logger.info('========= 5 - Generate Graphic Files =========');
  generateGraphicFiles();

  logger.info('========= 6 - Generate Simulation Files =========');
  generateSimulationFiles();

  logger.info('********** Update Completed **********');
};

