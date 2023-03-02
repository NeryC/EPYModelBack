import express from "express";
import cronJobs from "./cron/cronService.js";
import mainFlow from "./utils/mainFlow.js";

const app = express();

app.use(express.static("public"));

app.get("json/projectionr", (req, res) => {
  res.download("public/results/proyR.json");
});

app.get("/projectionh", (req, res) => {
  res.download("public/results/proyH.json");
});

app.get("/projectionu", (req, res) => {
  res.download("public/results/proyU.json");
});

app.get("/projectionf", (req, res) => {
  res.download("public/results/proyF.json");
});

const PORT = 30001;

app.listen(PORT, () => {
  console.log(`Running on PORT ${PORT}`);

  // en caso de necesitar un test rapido, descomentar la siguiente linea
  // mainFlow();

  cronJobs.forEach((cronJob) => {
    console.log("Inicia Proceso Recurrente");
    cronJob.start();
  });
});
