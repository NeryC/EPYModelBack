import { execSync } from "child_process";
import { getScript } from "./getScript.js";

// execSyncScript(pathNames.PY_DOWNLOAD_SCRIPTS, pyScript);
const execSyncScript = (scriptType, fileName) => {
  const script = getScript(scriptType, fileName);

  if (!script) return console.log("no existe el script");
  try {
    execSync(script);
    console.log(`${fileName} finalizado`);
  } catch (error) {
    console.log(error);
    console.log(`fallo ${fileName}`);
  }
};

export default execSyncScript;
