import express from "express";
import cronJobs from "./cron/cronService.js";

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
  cronJobs.forEach((cronJob) => {
    cronJob.start();
  });
});
