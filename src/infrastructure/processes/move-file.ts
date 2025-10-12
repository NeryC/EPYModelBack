import fs from 'fs';
import { pathNames } from '../../shared/constants.js';
import { getPath } from './get-script.js';
import { logger } from '../../utils/logger.js';

export const moveFile = (fileName: string): void => {
  const fromPath = getPath(pathNames.RAW_FILES, fileName);
  const toPath = getPath(pathNames.DATA_FILES, fileName);
  fs.renameSync(fromPath, toPath);
  logger.info(`${fileName} se copio a data`);
};

