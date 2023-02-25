import express from "express";
import cronJobs from "./cron/cronService.js";
import { execSync } from "child_process";
import path from "path";

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

  try {
    execSync(`Rscript ${path.resolve()}/src/model_seirh/install_packages.R`, {
      stdio: "inherit",
    });
  } catch (error) {
    console.log(error);
  }

  cronJobs.forEach((cronJob) => {
    console.log("Inicia Proceso Recurrente");
    cronJob.start();
  });
});
