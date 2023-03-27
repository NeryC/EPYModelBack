import fs from "fs";
import { fileNames, pathNames } from "../const.js";
import { getPath } from "../getScript.js";
import { PythonShell } from "python-shell";

export const getSimulation = async (
  default_Rt,
  default_UCI_threshold,
  default_V_filtered,
  default_lambda_I_to_H,
  isFirstSimulation = false
) => {
  const SEICHUFO = JSON.stringify(getSEICHUFO());
  const params = [
    SEICHUFO,
    default_Rt,
    default_UCI_threshold,
    default_V_filtered,
    default_lambda_I_to_H,
    isFirstSimulation,
  ];
  const result = await execPythonScriptWithReturn(params);
  return result;
};

export const getFirstSimulation = () => {
  const default_Rt = JSON.stringify([1.1, 1.2, 1.3, 0.8, 0.7, 0.9]);
  const default_UCI_threshold = 100;
  const default_V_filtered = 1000;
  const default_lambda_I_to_H = 0.5;
  getSimulation(
    default_Rt,
    default_UCI_threshold,
    default_V_filtered,
    default_lambda_I_to_H,
    true
  );
};

const getSEICHUFO = () => {
  const csv = fs.readFileSync(
    getPath(pathNames.DATA_FILES, fileNames.SIM_CSV),
    "utf8"
  );
  // Split the CSV file string into an array of lines
  const lines = csv.split("\n");
  const lastLine = lines[lines.length - 2].split(",");
  const SEICHUFO = [
    parseFloat(lastLine[20]),
    parseFloat(lastLine[21]),
    parseFloat(lastLine[22]),
    parseFloat(lastLine[23]),
    parseFloat(lastLine[24]),
    parseFloat(lastLine[25]),
    parseFloat(lastLine[26]),
    parseFloat(lastLine[27]),
  ];
  return SEICHUFO;
};

const execPythonScriptWithReturn = async (params) => {
  const options = {
    mode: "text",
    scriptPath: getPath(pathNames.PY_SCRIPTS),
    args: params,
  };
  const pyshell = new PythonShell(fileNames.SIMULADOR_PY, options);

  // Captura la salida estándar y los errores
  let output = "";
  let error = "";
  pyshell.on("message", function (message) {
    output += message;
  });
  pyshell.on("error", function (err) {
    error += err;
  });

  // Crea una promesa que se resuelve cuando el proceso finaliza
  const endPromise = new Promise((resolve, reject) => {
    pyshell.end(function (err, code, signal) {
      if (err) reject(err);
      if (error) console.error(error);
      resolve(output);
    });
  });
  return await endPromise;
};
