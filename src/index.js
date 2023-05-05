import express from "express";
import cronJobs from "./cron/cronService.js";
import mainFlow from "./utils/mainFlow.js";
import { getSimulation } from "./utils/Simulation/getFirstSimulation.js";
import cors from "cors";

const app = express();

app.use(express.static("public"));
app.use(cors());

app.get("/projection-r", (req, res) => {
  console.log("/projection-r");
  res.download("public/results/proyR.json");
});

app.get("/projection-h", (req, res) => {
  console.log("/projection-h");
  res.download("public/results/proyH.json");
});

app.get("/projection-u", (req, res) => {
  console.log("/projection-u");
  res.download("public/results/proyU.json");
});

app.get("/projection-f", (req, res) => {
  console.log("/projection-f");
  res.download("public/results/proyF.json");
});

app.get("/get-projection-r", (req, res) => {
  console.log("/get-projection-r");
  res.download("public/results/proyR.csv");
});

app.get("/get-projection-h", (req, res) => {
  console.log("/get-projection-h");
  res.download("public/results/proyH.csv");
});

app.get("/get-projection-u", (req, res) => {
  console.log("/get-projection-u");
  res.download("public/results/proyU.csv");
});

app.get("/get-projection-f", (req, res) => {
  console.log("/get-projection-f");
  res.download("public/results/proyF.csv");
});

app.get("/get-simulation", async (req, res) => {
  console.log("/get-simulation");
  const responseData = await getSimulation(
    req.query.Rt,
    req.query.UCI_threshold,
    req.query.V_filtered,
    req.query.lambda_I_to_H
  );
  res.json(responseData);
});

app.get("/get-first-simulation", (req, res) => {
  console.log("/get-first-simulation");
  res.download("public/results/simulation.json");
});

const PORT = 3001;

app.listen(PORT, () => {
  console.log(`Running on PORT ${PORT}`);

  // en caso de necesitar un test rapido, descomentar la siguiente linea
  // mainFlow();

  cronJobs.forEach((cronJob) => {
    console.log("Inicia Proceso Recurrente");
    cronJob.start();
  });
});
