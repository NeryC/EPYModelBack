import { Response } from "express";
import { ApiResponse } from "../types/index.js";

/**
 * Custom error class for application-specific errors
 */
export class AppError extends Error {
  public readonly statusCode: number;
  public readonly isOperational: boolean;

  constructor(
    message: string,
    statusCode: number = 500,
    isOperational: boolean = true
  ) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;

    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Sends a standardized error response
 */
export function sendErrorResponse(
  res: Response,
  error: Error | AppError,
  statusCode: number = 500
): void {
  const isAppError = error instanceof AppError;
  const finalStatusCode = isAppError ? error.statusCode : statusCode;

  const response: ApiResponse = {
    success: false,
    error: error.message,
    message: "An error occurred while processing your request",
  };

  res.status(finalStatusCode).json(response);
}

/**
 * Sends a standardized success response
 */
export function sendSuccessResponse<T>(
  res: Response,
  data: T,
  message: string = "Operation completed successfully",
  statusCode: number = 200
): void {
  const response: ApiResponse<T> = {
    success: true,
    data,
    message,
  };

  res.status(statusCode).json(response);
}

/**
 * Async error wrapper for route handlers
 */
export function asyncHandler<T extends any[]>(
  fn: (...args: T) => Promise<any>
): (...args: T) => Promise<void> {
  return async (...args: T): Promise<void> => {
    try {
      await fn(...args);
    } catch (error) {
      const res = args[1] as Response;
      sendErrorResponse(res, error as Error);
    }
  };
}

/**
 * Validates required query parameters
 */
export function validateQueryParams(
  query: Record<string, any>,
  requiredParams: string[]
): void {
  const missingParams = requiredParams.filter((param) => !query[param]);

  if (missingParams.length > 0) {
    throw new AppError(
      `Missing required query parameters: ${missingParams.join(", ")}`,
      400
    );
  }
}
