import cron from "node-cron";
import * as child from "child_process";
import path from "path";
import fs from "fs";

const copyFile = (fileName) => {
  // tengo que cambiar por las direcciones finales rawData y data
  const fromPath = `${path.resolve()}\\public\\test1\\`;
  const toPath = `${path.resolve()}\\public\\test2\\`;
  fs.copyFileSync(`${fromPath}${fileName}`, `${toPath}${fileName}`);
  console.log(`${fileName} se copio a data`);
};

const projections = cron.schedule("1 * * * * *", () => {
  const descargarFileName = "Descargar datos_Datos completos_data.csv";
  const fallecidosFileName = "FALLECIDOS_Datos completos_data.csv";
  const registroFileName = "REGISTRO DIARIO_Datos completos_data.csv";

  console.log("========= Copiar Archivos =========");

  copyFile(descargarFileName);
  copyFile(fallecidosFileName);
  copyFile(registroFileName);

  console.log("========= Generar Archivos de Simulacion =========");

  const pythonProcess = child.spawn("python", [
    `${path.resolve()}\\src\\scripts\\main.py`,
  ]);

  pythonProcess.stdout.on("data", function (data) {
    console.log(data.toString());
  });

  pythonProcess.stdout.on("end", function () {
    console.log("Finished");
  });

  pythonProcess.stdin.end();
});

const cronJobs = [projections];

export default cronJobs;
