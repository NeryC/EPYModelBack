import cron from "node-cron";
import mainFlow from "../utils/mainFlow.js";

// Runs on Sundays at 3 AM
const projections = cron.schedule("* 3 * * 0", () => {
  mainFlow();
});

const cronJobs = [projections];

export default cronJobs;
