import { pathNames } from "./const.js";
import path from "path";

const getScript = (fileType, fileName) => {
  switch (fileType) {
    case pathNames.PY_SCRIPTS:
      console.log(path.join(path.resolve(), pathNames.PY_SCRIPTS, fileName));
      return `python3 ${path.join(
        path.resolve(),
        pathNames.PY_SCRIPTS,
        fileName
      )}`;

    case pathNames.R_SCRIPTS:
      return `Rscript ${path.resolve()}${pathNames.R_SCRIPTS}${fileName}`;

    case pathNames.PY_DOWNLOAD_SCRIPTS:
      console.log(
        path.join(path.resolve(), pathNames.PY_DOWNLOAD_SCRIPTS, fileName)
      );
      return `python3 ${path.join(
        path.resolve(),
        pathNames.PY_DOWNLOAD_SCRIPTS,
        fileName
      )}`;

    case pathNames.RAW_FILES:
      return `${path.resolve()}${pathNames.RAW_FILES}${fileName}`;

    case pathNames.DATA_FILES:
      return `${path.resolve()}${pathNames.DATA_FILES}${fileName}`;

    default:
      return "";
  }
};

export default getScript;
