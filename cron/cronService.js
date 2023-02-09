import cron from "node-cron";
const spawn = require("child_process").spawn;

const projections = cron.schedule("10 0 * * * *", () => {
  console.log("started");
  const pythonProcess = spawn("python", [
    "C:\\Users\\albert\\Documents\\Projects\\epimodel\\newBack\\pythonProject\\main.py",
  ]);
  let pythonResponse = "";

  pythonProcess.stdout.on("data", function (data) {
    pythonResponse += "x= " + data.toString();
  });

  pythonProcess.stdout.on("end", function () {
    console.log(pythonResponse);
  });

  pythonProcess.stdin.write("backendi");

  pythonProcess.stdin.end();
  //transform csv file into another csv file
  //una vez al dia a las 00
});

const cronJobs = [projections];

export default cronJobs;
