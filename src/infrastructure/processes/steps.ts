import { downloadFiles } from './download-files.js';
import { execSyncScript } from './exec-sync-script.js';
import { fileNames, pathNames } from '../../shared/constants.js';
import { moveFile } from './move-file.js';
import { getFirstSimulation } from './simulation-adapter.js';
import { assertRawDataValid } from './validate-data.js';
import { getPath } from './get-script.js';

export const downloadRawData = (): void => {
  void downloadFiles();
};

/**
 * Valida los CSV crudos (fechas día/mes/año coherentes). Lanza si detecta el
 * patrón de intercambio día/mes de jul-2023: mejor detener el pipeline que
 * ajustar el modelo y publicar gráficos con fechas equivocadas.
 */
export const validateData = (): void => {
  assertRawDataValid(getPath(pathNames.DATA_FILES));
};

export const execPreProcessing = (): void => {
  validateData();
  execSyncScript(pathNames.R_SCRIPTS, fileNames.CLEAN_V);
  execSyncScript(pathNames.R_SCRIPTS, fileNames.CLEAN_R);
  execSyncScript(pathNames.R_SCRIPTS, fileNames.CLEAN_F);
};

export const moveFiles = (): void => {
  moveFile(fileNames.DATOS_CSV);
  moveFile(fileNames.FALLECIDOS_CSV);
  moveFile(fileNames.REGISTROS_CSV);
};

export const execTest_seirhuf_normal = (): void => {
  execSyncScript(pathNames.R_SCRIPTS, fileNames.TEST_SEIRHUF);
};

export const generateGraphicFiles = (): void => {
  execSyncScript(pathNames.PY_SCRIPTS, fileNames.MAIN_PY);
};

export const generateSimulationFiles = (): void => {
  void getFirstSimulation();
};
