import cron from "node-cron";
import * as child from "child_process";
import path from "path";

const projections = cron.schedule("1 * * * * *", () => {
  console.log("Started");
  console.log(path.resolve());
  const pythonProcess = child.spawn("python", [
    `${path.resolve()}\\src\\scripts\\main.py`,
  ]);

  pythonProcess.stdout.on("data", function (data) {
    console.log(data.toString());
  });

  pythonProcess.stdout.on("end", function () {
    console.log("Finished");
  });

  pythonProcess.stdin.write("backendi");

  pythonProcess.stdin.end();
});

const cronJobs = [projections];

export default cronJobs;
