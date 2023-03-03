import { fileNames, pathNames } from "./const.js";
import execSyncScript from "./execSyncScript.js";
import downloadFiles from "./downloadFiles.js";
import moveFile from "./moveFile.js";

const mainFlow = () => {
  console.log("********** Iniciando Actualizacion **********");
  console.log("========= 1 - Descargar Datos =========");

  downloadFiles();

  console.log("========= 2 - Pre Procesamiento =========");

  // execSyncScript(pathNames.R_SCRIPTS, fileNames.CLEAN_V);
  // execSyncScript(pathNames.R_SCRIPTS, fileNames.CLEAN_R);
  // execSyncScript(pathNames.R_SCRIPTS, fileNames.CLEAN_F);

  console.log("========= 3 - Copiar Archivos =========");

  moveFile(fileNames.DATOS_CSV);
  moveFile(fileNames.FALLECIDOS_CSV);
  moveFile(fileNames.REGISTROS_CSV);

  console.log("========= 4 - test_seirhuf_normal =========");

  // execSyncScript(pathNames.R_SCRIPTS, fileNames.TEST_SEIRHUF);

  console.log("========= 5 - Generar Archivos de Simulacion =========");

  execSyncScript(pathNames.PY_SCRIPTS, fileNames.MAIN_PY);

  console.log("********** Actualizacion Finalizada **********");
};

export default mainFlow;
