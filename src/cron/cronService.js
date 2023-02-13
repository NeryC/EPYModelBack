import cron from "node-cron";
import { execSync } from "child_process";
import path from "path";
import fs from "fs";

const copyFile = (fileName) => {
  const fromPath = `${path.resolve()}/public/rawData/`;
  const toPath = `${path.resolve()}/public/data/`;
  fs.copyFileSync(`${fromPath}${fileName}`, `${toPath}${fileName}`);
  console.log(`${fileName} se copio a data`);
};
const execSyncRscript = (fileName) => {
  execSync(`Rscript ${path.resolve()}/src/model_seirh/${fileName}`, {
    stdio: "inherit",
  });

  console.log(`${fileName} finalizado`);
};
const execSyncPython = () => {
  execSync(`python ${path.resolve()}/src/scripts/main.py`, {
    stdio: "inherit",
  });
  console.log(`${fileName} finalizado`);
};

const projections = cron.schedule("1 * * * * *", () => {
  const descargarFileName = "Descargar datos_Datos completos_data.csv";
  const fallecidosFileName = "FALLECIDOS_Datos completos_data.csv";
  const registroFileName = "REGISTRO DIARIO_Datos completos_data.csv";
  const clean_V = "clean_V.R";
  const clean_R = "clean_R.R";
  const clean_F = "clean_F.R";
  const test_seirhuf_normal = "test_seirhuf_normal.R";

  console.log("********** Iniciando Actualizacion **********");
  console.log("========= 1 - Descargar Datos =========");
  console.log("========= 2 - Pre Procesamiento =========");

  execSyncRscript(clean_V);
  execSyncRscript(clean_R);
  execSyncRscript(clean_F);

  console.log("========= 3 - Copiar Archivos =========");

  copyFile(descargarFileName);
  copyFile(fallecidosFileName);
  copyFile(registroFileName);

  console.log("========= 4 - test_seirhuf_normal =========");

  execSyncRscript(test_seirhuf_normal);

  console.log("========= 5 - Generar Archivos de Simulacion =========");

  execSyncPython();

  console.log("********** Actualizacion Finalizada **********");
});

const cronJobs = [projections];

export default cronJobs;
