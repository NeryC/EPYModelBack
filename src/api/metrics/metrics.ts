import client from "prom-client";
import { Request, Response, Router } from "express";

const register = new client.Registry();
client.collectDefaultMetrics({ register });

export const metricsRouter = Router();

metricsRouter.get("/metrics", async (req: Request, res: Response) => {
  res.set("Content-Type", register.contentType);
  res.send(await register.metrics());
});

