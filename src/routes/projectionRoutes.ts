import { Router } from "express";
import { ProjectionController } from "../controllers/projectionController.js";
import { validateQuery } from "../middleware/zodValidator.js";
import { ProjectionQuerySchema } from "../api/v1/projections/dto.js";

const router = Router();
const projectionController = new ProjectionController();

// Projection routes
router.get(
  "/projections",
  validateQuery(ProjectionQuerySchema),
  projectionController.getProjections
);

export default router;
