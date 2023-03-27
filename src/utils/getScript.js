import { pathNames } from "./const.js";
import path from "path";

export const getScript = (scriptType, fileName) => {
  const commands = {
    [pathNames.PY_SCRIPTS]: `python ${path.join(
      path.resolve(),
      pathNames.PY_SCRIPTS,
      fileName
    )}`,
    [pathNames.R_SCRIPTS]: `Rscript ${path.join(
      path.resolve(),
      pathNames.R_SCRIPTS,
      fileName
    )}`,
    [pathNames.PY_DOWNLOAD_SCRIPTS]: `python ${path.join(
      path.resolve(),
      pathNames.PY_DOWNLOAD_SCRIPTS,
      fileName
    )}`,
  };

  return commands[scriptType] ?? "";
};

export const getPath = (pathType, file) => {
  const fileName = file || "";
  const commands = {
    [pathNames.PY_SCRIPTS]: `${path.join(
      path.resolve(),
      pathNames.PY_SCRIPTS,
      fileName
    )}`,
    [pathNames.RAW_FILES]: path.join(
      path.resolve(),
      pathNames.RAW_FILES,
      fileName
    ),
    [pathNames.DATA_FILES]: path.join(
      path.resolve(),
      pathNames.DATA_FILES,
      fileName
    ),
  };
  return commands[pathType] ?? "";
};
