import cors from "cors";
import express, { Express, NextFunction, Request, Response } from "express";
import projectionRoutes from "./routes/projectionRoutes.js";
import simulationRoutes from "./routes/simulationRoutes.js";
import { AppError, sendErrorResponse } from "./utils/errorHandler.js";
import { environment, validateEnvironment } from "./config/environment.js";

// Initialize Express app
const app: Express = express();

// Validate environment variables
validateEnvironment();

// Middleware setup
app.use(express.static("public"));
app.use(cors());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Request logging middleware
app.use((req: Request, res: Response, next: NextFunction) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.path} - ${req.ip}`);
  next();
});

// Health check endpoint
app.get("/health", (req: Request, res: Response) => {
  res.json({
    status: "OK",
    timestamp: new Date().toISOString(),
    environment: environment.NODE_ENV,
    port: environment.PORT,
  });
});

// API routes
app.use("/", projectionRoutes);
app.use("/", simulationRoutes);

// 404 handler
app.use("*", (req: Request, res: Response) => {
  res.status(404).json({
    success: false,
    error: `Route ${req.originalUrl} not found`,
    message: "The requested resource does not exist",
  });
});

// Global error handling middleware
app.use(
  (
    error: Error | AppError,
    req: Request,
    res: Response,
    next: NextFunction
  ) => {
    console.error("Global error handler:", error);

    // Handle specific error types
    if (error instanceof AppError) {
      return sendErrorResponse(res, error, error.statusCode);
    }

    // Handle validation errors
    if (error.name === "ValidationError") {
      return sendErrorResponse(res, new AppError(error.message, 400));
    }

    // Handle file system errors
    if (error.name === "ENOENT") {
      return sendErrorResponse(res, new AppError("File not found", 404));
    }

    // Default error response
    return sendErrorResponse(res, error, 500);
  }
);

// Graceful shutdown handling
process.on("SIGTERM", () => {
  console.log("SIGTERM received, shutting down gracefully");
  process.exit(0);
});

process.on("SIGINT", () => {
  console.log("SIGINT received, shutting down gracefully");
  process.exit(0);
});

// Unhandled promise rejection handler
process.on("unhandledRejection", (reason: any, promise: Promise<any>) => {
  console.error("Unhandled Rejection at:", promise, "reason:", reason);
  process.exit(1);
});

// Uncaught exception handler
process.on("uncaughtException", (error: Error) => {
  console.error("Uncaught Exception:", error);
  process.exit(1);
});

// Start server
const server = app.listen(environment.PORT, () => {
  console.log(`🚀 Server running on PORT ${environment.PORT}`);
  console.log(`🌍 Environment: ${environment.NODE_ENV}`);
  console.log(`📅 Started at: ${new Date().toISOString()}`);

  // Development mode logging
  if (environment.NODE_ENV === "development") {
    console.log(`🔗 Health check: http://localhost:${environment.PORT}/health`);
  }
});

// Export for testing purposes
export { app, server };
