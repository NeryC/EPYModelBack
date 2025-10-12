import { Router } from "express";
import { SimulationController } from "../controllers/simulationController.js";
import { validateSimulationParams } from "../middleware/validationMiddleware.js";
import { validateQuery } from "../middleware/zodValidator.js";
import { SimulationQuerySchema } from "../api/v1/simulations/dto.js";

const router = Router();
const simulationController = new SimulationController();

// Simulation routes
// RESTful alias: /simulations
router.get(
  "/simulations",
  validateQuery(SimulationQuerySchema),
  simulationController.getSimulation
);
// Legacy endpoint
router.get(
  "/get-simulation",
  validateSimulationParams,
  simulationController.getSimulation
);
router.get("/get-first-simulation", simulationController.getFirstSimulation);
router.get("/get-first-simulation-data", simulationController.getFirstSimulationData);
router.get(
  "/get-first-simulation-2",
  simulationController.getFirstSimulationWithExecution
);

export default router;
