import downloadFiles from "./downloadFiles.js";
import execSyncScript from "./execSyncScript.js";
import { fileNames, pathNames } from "./const.js";
import moveFile from "./moveFile.js";
import { getFirstSimulation } from "./Simulation/getFirstSimulation.js";

export const downloadRawData = () => {
  downloadFiles();
};

export const execPreProcessing = () => {
  execSyncScript(pathNames.R_SCRIPTS, fileNames.CLEAN_V);
  execSyncScript(pathNames.R_SCRIPTS, fileNames.CLEAN_R);
  execSyncScript(pathNames.R_SCRIPTS, fileNames.CLEAN_F);
};

export const moveFiles = () => {
  moveFile(fileNames.DATOS_CSV);
  moveFile(fileNames.FALLECIDOS_CSV);
  moveFile(fileNames.REGISTROS_CSV);
};

export const execTest_seirhuf_normal = () => {
  execSyncScript(pathNames.R_SCRIPTS, fileNames.TEST_SEIRHUF);
};

export const generateGraphicFiles = () => {
  execSyncScript(pathNames.PY_SCRIPTS, fileNames.MAIN_PY);
};

export const generateSimulationFiles = () => {
  getFirstSimulation();
};
