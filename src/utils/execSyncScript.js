import { execSync } from "child_process";
import getScript from "./getScript.js";

const execSyncScript = (fileType, fileName) => {
  let script = getScript(fileType, fileName);

  if (!script) return console.log("no existe el script");

  try {
    execSync(script, {
      stdio: "inherit",
    });
    console.log(`${fileName} finalizado`);
  } catch (error) {
    console.log(error);
    console.log(`fallo ${fileName}`);
  }
};

export default execSyncScript;
