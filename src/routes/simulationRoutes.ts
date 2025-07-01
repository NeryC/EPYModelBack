import { Router } from "express";
import { SimulationController } from "../controllers/simulationController.js";
import { validateSimulationParams } from "../middleware/validationMiddleware.js";

const router = Router();
const simulationController = new SimulationController();

// Simulation routes
router.get(
  "/get-simulation",
  validateSimulationParams,
  simulationController.getSimulation
);
router.get("/get-first-simulation", simulationController.getFirstSimulation);
router.get(
  "/get-first-simulation-2",
  simulationController.getFirstSimulationWithExecution
);

export default router;
