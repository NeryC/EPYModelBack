import cron from "node-cron";
import mainFlow from "../utils/mainFlow.js";

// se ejecuta los domingos a las 3 de la mañana
const projections = cron.schedule("* 3 * * 0", () => {
  mainFlow();
});

const cronJobs = [projections];

export default cronJobs;
