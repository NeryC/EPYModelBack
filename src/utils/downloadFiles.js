import fs from "fs";
import getScript from "./getScript.js";
import execSyncScript from "./execSyncScript.js";
import { pathNames, fileNames } from "./const.js";

const downloadFiles = () => {
  execDownload(fileNames.DATOS_CSV, fileNames.DATOS_PY);
  execDownload(fileNames.REGISTROS_CSV, fileNames.REGISTROS_PY);
  execDownload(fileNames.FALLECIDOS_CSV, fileNames.FALLECIDOS_PY);
};

const execDownload = (csvName, pyScript) => {
  const filePath = getScript(pathNames.RAW_FILES, csvName);
  do {
    console.log(`Intentar descargar ${csvName}`);
    try {
      execSyncScript(pathNames.PY_DOWNLOAD_SCRIPTS, pyScript);
    } catch (error) {
      console.log(`Fallo la descarga de ${csvName}`);
    }
    console.log(filePath);
  } while (!fs.existsSync(filePath));
  console.log(`${csvName} descargado`);
};

export default downloadFiles;
