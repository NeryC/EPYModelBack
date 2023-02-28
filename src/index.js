import express from "express";
import cronJobs from "./cron/cronService.js";
import execSyncScript from "./utils/execSyncScript.js";
import { pathNames, fileNames } from "./utils/const.js";
import mainFlow from "./utils/mainFlow.js";

const app = express();

app.use(express.static("public"));

app.get("json/projectionr", (req, res) => {
  res.download("public/proyR.json");
});

app.get("/projectionh", (req, res) => {
  res.download("public/proyH.json");
});

app.get("/projectionu", (req, res) => {
  res.download("public/proyU.json");
});

app.get("/projectionf", (req, res) => {
  res.download("public/proyF.json");
});

const PORT = 30001;

app.listen(PORT, () => {
  console.log(`Running on PORT ${PORT}`);

  // en caso de necesitar un test rapido, comentar la linea 34 y descomentar la 35

  execSyncScript(pathNames.R_SCRIPTS, fileNames.INSTALL_R);
  // mainFlow();

  cronJobs.forEach((cronJob) => {
    console.log("Inicia Proceso Recurrente");
    cronJob.start();
  });
});
