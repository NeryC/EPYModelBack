import fs from 'fs';
import { getPath } from './get-script.js';
import { execSyncScript } from './exec-sync-script.js';
import { pathNames, fileNames } from '../../shared/constants.js';
import { logger } from '../../utils/logger.js';

const MAX_RETRIES = 30;
const RETRY_DELAY_MS = 1000;

export const downloadFiles = async (): Promise<void> => {
  await execDownload(fileNames.DATOS_CSV, fileNames.DATOS_PY);
  await execDownload(fileNames.REGISTROS_CSV, fileNames.REGISTROS_PY);
  await execDownload(fileNames.FALLECIDOS_CSV, fileNames.FALLECIDOS_PY);
};

const execDownload = async (csvName: string, pyScript: string): Promise<void> => {
  const filePath = getPath(pathNames.RAW_FILES, csvName);
  let attempts = 0;
  while (!fs.existsSync(filePath) && attempts < MAX_RETRIES) {
    logger.info(`Attempting to download ${csvName} (attempt ${attempts + 1}/${MAX_RETRIES})`);
    try {
      execSyncScript(pathNames.PY_DOWNLOAD_SCRIPTS, pyScript);
    } catch (error) {
      logger.error(`Download failed for ${csvName}`);
    }
    if (!fs.existsSync(filePath)) {
      await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
    }
    attempts++;
  }
  if (!fs.existsSync(filePath)) {
    throw new Error(`File not available after ${MAX_RETRIES} attempts: ${filePath}`);
  }
  logger.info(`${csvName} downloaded`);
};

