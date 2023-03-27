import fs from "fs";
import { pathNames } from "./const.js";
import { getPath } from "./getScript.js";

const moveFile = (fileName) => {
  const fromPath = getPath(pathNames.RAW_FILES, fileName);
  const toPath = getPath(pathNames.DATA_FILES, fileName);
  fs.renameSync(fromPath, toPath);
  console.log(`${fileName} se copio a data`);
};

export default moveFile;
