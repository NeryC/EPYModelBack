import cron from "node-cron";
import { execSync } from "child_process";
import path from "path";
import fs from "fs";

const moveFile = (fileName) => {
  const fromPath = `${path.resolve()}/public/rawData/${fileName}`;
  const toPath = `${path.resolve()}/public/data/${fileName}`;
  fs.renameSync(fromPath, toPath);
  console.log(`${fileName} se copio a data`);
};
const execSyncRscript = (fileName) => {
  try {
    execSync(`Rscript ${path.resolve()}/src/model_seirh/${fileName}`, {
      stdio: "inherit",
    });
    console.log(`${fileName} finalizado`);
  } catch (error) {
    console.log(error);
    console.log(`fallo ${fileName}`);
  }
};
const execSyncPython = (file) => {
  execSync(`python3 ${path.resolve()}/src/scripts/${file}`, {
    stdio: "inherit",
  });
};

const downloadFiles = () => {
  downloadDatosCompletos();
  downloadFallecidos();
  downloadRegistroDiario();
};

const downloadDatosCompletos = () => {
  const filePath = `${path.resolve()}/public/rawData/Descargar datos_Datos completos_data.csv`;
  do {
    console.log("Intentar descargar Datos completos");
    try {
      execSyncPython("download/datos-completos.py");
    } catch (error) {
      console.log("Fallo la descarga de Datos completos");
    }
  } while (!fs.existsSync(filePath));
  console.log("Datos completos descargado");
};

const downloadFallecidos = () => {
  const filePath = `${path.resolve()}/public/rawData/FALLECIDOS_Datos completos_data.csv`;
  do {
    console.log("Intentar descargar Fallecidos");
    try {
      execSyncPython("download/fallecidos.py");
    } catch (error) {
      console.log("Fallo la descarga de Fallecidos");
    }
  } while (!fs.existsSync(filePath));
  console.log("Fallecidos descargado");
};

const downloadRegistroDiario = () => {
  const filePath = `${path.resolve()}/public/rawData/REGISTRO DIARIO_Datos completos_data.csv`;
  do {
    console.log("Intentar descargar Registro diario");
    try {
      execSyncPython("download/registros-diarios.py");
    } catch (error) {
      console.log("Fallo la descarga de Registro diario");
    }
  } while (!fs.existsSync(filePath));
  console.log("Registro diario descargado");
};

// se ejecuta los domingos a las 3 de la mañana
const projections = cron.schedule("* 3 * * 0", () => {
  const descargarFileName = "Descargar datos_Datos completos_data.csv";
  const fallecidosFileName = "FALLECIDOS_Datos completos_data.csv";
  const registroFileName = "REGISTRO DIARIO_Datos completos_data.csv";
  const clean_V = "clean_V.R";
  const clean_R = "clean_R.R";
  const clean_F = "clean_F.R";
  const test_seirhuf_normal = "test_seirhuf_normal.R";

  console.log("********** Iniciando Actualizacion **********");
  console.log("========= 1 - Descargar Datos =========");

  downloadFiles();

  console.log("========= 2 - Pre Procesamiento =========");

  execSyncRscript(clean_V);
  execSyncRscript(clean_R);
  execSyncRscript(clean_F);

  console.log("========= 3 - Copiar Archivos =========");

  moveFile(descargarFileName);
  moveFile(fallecidosFileName);
  moveFile(registroFileName);

  console.log("========= 4 - test_seirhuf_normal =========");

  execSyncRscript(test_seirhuf_normal);

  console.log("========= 5 - Generar Archivos de Simulacion =========");

  execSyncPython("main.py");

  console.log("********** Actualizacion Finalizada **********");
});

const cronJobs = [projections];

export default cronJobs;
