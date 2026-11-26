import { pathNames } from '../../shared/constants.js';
import { environment } from '../../config/environment.js';
import path from 'path';

/** Comando para ejecutar un script del pipeline (Python o R). */
export const getScript = (scriptType: string, fileName: string): string => {
  // Mismo intérprete que el simulador (PYTHON_PATH → .venv → python/python3 según SO).
  // Antes era `python` fijo: en la imagen Docker (Ubuntu) solo existe `python3`.
  const python = JSON.stringify(environment.PYTHON_PATH);
  const commands: Record<string, string> = {
    [pathNames.PY_SCRIPTS]: `${python} ${path.join(path.resolve(), pathNames.PY_SCRIPTS, fileName)}`,
    [pathNames.R_SCRIPTS]: `Rscript ${path.join(path.resolve(), pathNames.R_SCRIPTS, fileName)}`,
    [pathNames.PY_DOWNLOAD_SCRIPTS]: `${python} ${path.join(
      path.resolve(),
      pathNames.PY_DOWNLOAD_SCRIPTS,
      fileName,
    )}`,
  };

  return commands[scriptType] ?? '';
};

export const getPath = (pathType: string, file?: string): string => {
  const fileName = file || '';
  const commands: Record<string, string> = {
    [pathNames.PY_SCRIPTS]: `${path.join(path.resolve(), pathNames.PY_SCRIPTS, fileName)}`,
    [pathNames.RAW_FILES]: path.join(path.resolve(), pathNames.RAW_FILES, fileName),
    [pathNames.DATA_FILES]: path.join(path.resolve(), pathNames.DATA_FILES, fileName),
  };
  return commands[pathType] ?? '';
};
