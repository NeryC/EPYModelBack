import { Request, Response, NextFunction } from "express";
import { AppError } from "../utils/errorHandler.js";

export interface ValidationRule {
  field: string;
  required?: boolean;
  type?: "string" | "number" | "boolean";
  enum?: string[];
  minLength?: number;
  maxLength?: number;
  min?: number;
  max?: number;
}

/**
 * Validate request parameters against defined rules
 */
export function validateParams(rules: ValidationRule[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const errors: string[] = [];

    rules.forEach((rule) => {
      const value = req.params[rule.field] || req.query[rule.field];

      // Check if required
      if (
        rule.required &&
        (value === undefined || value === null || value === "")
      ) {
        errors.push(`${rule.field} is required`);
        return;
      }

      // Skip validation if value is not provided and not required
      if (value === undefined || value === null || value === "") {
        return;
      }

      // Type validation
      if (rule.type) {
        switch (rule.type) {
          case "string":
            if (typeof value !== "string") {
              errors.push(`${rule.field} must be a string`);
            }
            break;
          case "number":
            const numValue = Number(value);
            if (isNaN(numValue)) {
              errors.push(`${rule.field} must be a valid number`);
            }
            break;
          case "boolean":
            if (
              typeof value !== "boolean" &&
              !["true", "false", "0", "1"].includes(String(value))
            ) {
              errors.push(`${rule.field} must be a boolean`);
            }
            break;
        }
      }

      // Enum validation
      if (rule.enum && !rule.enum.includes(String(value))) {
        errors.push(`${rule.field} must be one of: ${rule.enum.join(", ")}`);
      }

      // Length validation for strings
      if (rule.type === "string" && typeof value === "string") {
        if (rule.minLength && value.length < rule.minLength) {
          errors.push(
            `${rule.field} must be at least ${rule.minLength} characters long`
          );
        }
        if (rule.maxLength && value.length > rule.maxLength) {
          errors.push(
            `${rule.field} must be at most ${rule.maxLength} characters long`
          );
        }
      }

      // Range validation for numbers
      if (rule.type === "number") {
        const numValue = Number(value);
        if (rule.min !== undefined && numValue < rule.min) {
          errors.push(`${rule.field} must be at least ${rule.min}`);
        }
        if (rule.max !== undefined && numValue > rule.max) {
          errors.push(`${rule.field} must be at most ${rule.max}`);
        }
      }
    });

    if (errors.length > 0) {
      throw new AppError(`Validation failed: ${errors.join(", ")}`, 400);
    }

    next();
  };
}

/**
 * Specific validation for projection format
 */
export const validateProjectionFormat = validateParams([
  {
    field: "format",
    type: "string",
    enum: ["json", "csv"],
  },
]);

/**
 * Specific validation for simulation parameters
 */
export const validateSimulationParams = validateParams([
  {
    field: "Rt",
    required: true,
    type: "string",
  },
  {
    field: "UCI_threshold",
    required: true,
    type: "number",
    min: 1,
  },
  {
    field: "V_filtered",
    required: true,
    type: "number",
    min: 1,
  },
  {
    field: "lambda_I_to_H",
    required: true,
    type: "number",
    min: 0,
    max: 1,
  },
]);
