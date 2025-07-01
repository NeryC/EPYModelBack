import { Router } from "express";
import { ProjectionController } from "../controllers/projectionController.js";
import { validateProjectionFormat } from "../middleware/validationMiddleware.js";

const router = Router();
const projectionController = new ProjectionController();

// Projection routes
router.get(
  "/projections",
  validateProjectionFormat,
  projectionController.getProjections
);

export default router;
