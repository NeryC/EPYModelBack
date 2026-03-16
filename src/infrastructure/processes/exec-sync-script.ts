import { execSync } from 'child_process';
import { getScript } from './get-script.js';
import { logger } from '../../utils/logger.js';

export const execSyncScript = (scriptType: string, fileName: string): void => {
  const script = getScript(scriptType, fileName);

  if (!script) {
    logger.warn('no existe el script');
    return;
  }

  try {
    execSync(script);
    logger.info(`${fileName} finalizado`);
  } catch (error) {
    logger.error({ error }, `fallo ${fileName}`);
  }
};

