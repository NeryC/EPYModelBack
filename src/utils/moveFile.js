import fs from "fs";
import { pathNames } from "./const.js";
import getScript from "./getScript.js";

const moveFile = (fileName) => {
  const fromPath = getScript(pathNames.RAW_FILES, fileName);
  const toPath = getScript(pathNames.DATA_FILES, fileName);
  fs.renameSync(fromPath, toPath);
  console.log(`${fileName} se copio a data`);
};

export default moveFile;
