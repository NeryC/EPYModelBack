import client from "prom-client";
import { NextFunction, Request, Response, Router } from "express";

const register = new client.Registry();
client.collectDefaultMetrics({ register });

export const metricsAuthMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  const metricsToken = process.env.METRICS_TOKEN;
  if (process.env.NODE_ENV === 'production' && metricsToken) {
    const authHeader = req.headers.authorization;
    if (authHeader !== `Bearer ${metricsToken}`) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
  }
  next();
};

export const metricsRouter = Router();

metricsRouter.get("/metrics", metricsAuthMiddleware, async (req: Request, res: Response) => {
  res.set("Content-Type", register.contentType);
  res.send(await register.metrics());
});

