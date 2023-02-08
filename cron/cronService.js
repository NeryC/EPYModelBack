import cron from "node-cron";
const spawn = require("child_process").spawn;

const projectionR = cron.schedule("0 0 * * *", () => {
  const pythonProcess = spawn("python", ["comentado.script_python.py"]);
  let pythonResponse = "";

  pythonProcess.stdout.on("data", function (data) {
    pythonResponse += data.toString();
  });

  pythonProcess.stdout.on("end", function () {
    console.log(pythonResponse);
  });

  pythonProcess.stdin.write("backendi");

  pythonProcess.stdin.end();
  //transform csv file into another csv file
  //una vez al dia a las 00
});

const projectionH = cron.schedule("0 1 * * *", () => {
  //transform csv file into another csv file
  //una vez al dia a las 01
});

const projectionU = cron.schedule("0 2 * * *", () => {
  //transform csv file into another csv file
  //una vez al dia a las 00
});

const projectionF = cron.schedule("0 3 * * *", () => {
  //transform csv file into another csv file
  //una vez al dia a las 00
});

const cronJobs = [projectionR, projectionH, projectionU, projectionF];

export default cronJobs;
