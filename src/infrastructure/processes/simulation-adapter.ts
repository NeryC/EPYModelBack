import fs from 'fs';
import { fileNames, pathNames } from '../../shared/constants.js';
import { getPath } from './get-script.js';
import { PythonShell } from 'python-shell';

export const getSimulation = async (
  default_Rt: string,
  default_UCI_threshold: number,
  default_V_filtered: number,
  default_lambda_I_to_H: number,
  isFirstSimulation = false,
): Promise<string> => {
  const SEICHUFO = JSON.stringify(getSEICHUFO());
  const params = [
    SEICHUFO,
    default_Rt,
    default_UCI_threshold.toString(),
    default_V_filtered.toString(),
    default_lambda_I_to_H.toString(),
    isFirstSimulation.toString(),
  ];
  const result = await execPythonScriptWithReturn(params);
  return result;
};

export const getFirstSimulation = (): void => {
  const default_Rt = JSON.stringify([1.1, 1.2, 1.3, 0.8, 0.7, 0.9]);
  const default_UCI_threshold = 100;
  const default_V_filtered = 1000;
  const default_lambda_I_to_H = 0.5;
  getSimulation(default_Rt, default_UCI_threshold, default_V_filtered, default_lambda_I_to_H, true);
};

const getSEICHUFO = (): number[] => {
  const csv = fs.readFileSync(getPath(pathNames.DATA_FILES, fileNames.SIM_CSV), 'utf8');
  // Split the CSV file string into an array of lines
  const lines = csv.split('\n');
  if (lines.length < 2) {
    throw new Error('CSV file is too short');
  }
  const lastLine = lines[lines.length - 2]?.split(',');
  if (!lastLine || lastLine.length < 28) {
    throw new Error('CSV line is too short');
  }
  const SEICHUFO = [
    parseFloat(lastLine[20] || '0'),
    parseFloat(lastLine[21] || '0'),
    parseFloat(lastLine[22] || '0'),
    parseFloat(lastLine[23] || '0'),
    parseFloat(lastLine[24] || '0'),
    parseFloat(lastLine[25] || '0'),
    parseFloat(lastLine[26] || '0'),
    parseFloat(lastLine[27] || '0'),
  ];
  return SEICHUFO;
};

const execPythonScriptWithReturn = async (params: string[]): Promise<string> => {
  const options = {
    mode: 'text' as const,
    scriptPath: getPath(pathNames.PY_SCRIPTS),
    args: params,
  };
  const pyshell = new PythonShell(fileNames.SIMULADOR_PY, options);

  // Captura la salida estándar y los errores
  let output = '';
  let error = '';
  pyshell.on('message', function (message) {
    output += message;
  });
  pyshell.on('error', function (err) {
    error += err;
  });

  // Crea una promesa que se resuelve cuando el proceso finaliza
  const endPromise = new Promise<string>((resolve, reject) => {
    pyshell.end(function (err, _code, _signal) {
      if (err) reject(err);
      if (error) console.error(error);
      resolve(output);
    });
  });
  return await endPromise;
};
