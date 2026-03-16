import {
  downloadRawData,
  execPreProcessing,
  moveFiles,
  execTest_seirhuf_normal,
  generateGraphicFiles,
  generateSimulationFiles,
} from "./steps.js";

const mainFlow = () => {
  console.log("********** Starting Update **********");
  console.log("========= 1 - Download Data =========");

  downloadRawData();

  console.log("========= 2 - Pre Processing =========");

  execPreProcessing();

  console.log("========= 3 - Move Files =========");

  moveFiles();

  console.log("========= 4 - test_seirhuf_normal =========");

  execTest_seirhuf_normal();

  console.log("========= 5 - Generate Graphic Files =========");

  generateGraphicFiles();

  console.log("========= 6 - Generate Simulation Files =========");

  generateSimulationFiles();

  console.log("********** Update Completed **********");
};

export default mainFlow;
