import {
  downloadRawData,
  execPreProcessing,
  moveFiles,
  execTest_seirhuf_normal,
  generateGraphicFiles,
  generateSimulationFiles,
} from "./steps.js";

const mainFlow = () => {
  console.log("********** Iniciando Actualizacion **********");
  console.log("========= 1 - Descargar Datos =========");

  downloadRawData();

  console.log("========= 2 - Pre Procesamiento =========");

  execPreProcessing();

  console.log("========= 3 - Mover Archivos =========");

  moveFiles();

  console.log("========= 4 - test_seirhuf_normal =========");

  execTest_seirhuf_normal();

  console.log("========= 5 - Generar Archivos de Gaficos =========");

  generateGraphicFiles();

  console.log("========= 6 - Generar Archivos de Simulacion =========");

  generateSimulationFiles();

  console.log("********** Actualizacion Finalizada **********");
};

export default mainFlow;
