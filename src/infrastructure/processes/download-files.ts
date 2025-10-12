import fs from 'fs';
import { getPath } from './get-script.js';
import { execSyncScript } from './exec-sync-script.js';
import { pathNames, fileNames } from '../../shared/constants.js';
import { logger } from '../../utils/logger.js';

export const downloadFiles = (): void => {
  execDownload(fileNames.DATOS_CSV, fileNames.DATOS_PY);
  execDownload(fileNames.REGISTROS_CSV, fileNames.REGISTROS_PY);
  execDownload(fileNames.FALLECIDOS_CSV, fileNames.FALLECIDOS_PY);
};

const execDownload = (csvName: string, pyScript: string): void => {
  const filePath = getPath(pathNames.RAW_FILES, csvName);
  do {
    logger.info(`Intentar descargar ${csvName}`);
    try {
      execSyncScript(pathNames.PY_DOWNLOAD_SCRIPTS, pyScript);
    } catch (error) {
      logger.error(`Fallo la descarga de ${csvName}`);
    }
    logger.info(filePath);
  } while (!fs.existsSync(filePath));
  logger.info(`${csvName} descargado`);
};

