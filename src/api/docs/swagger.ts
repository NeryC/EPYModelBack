import swaggerJSDoc from "swagger-jsdoc";
import { Express } from "express";
import swaggerUi from "swagger-ui-express";

export function setupSwagger(app: Express) {
  const options = {
    definition: {
      openapi: "3.0.0",
      info: { title: "Epy Model API", version: "1.0.0" },
      servers: [{ url: "/api/v1" }],
      paths: {
        "/simulations": { get: { summary: "Get simulations" } },
        "/projections": { get: { summary: "Get projections" } },
      },
    },
    apis: [],
  };
  const spec = swaggerJSDoc(options);
  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(spec));
}
