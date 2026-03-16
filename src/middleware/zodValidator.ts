import { NextFunction, Request, Response } from "express";
import { ZodSchema } from "zod";
import { AppError } from "../utils/errorHandler.js";

export function validateQuery(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction) => {
    const parsed = schema.safeParse(req.query);
    if (!parsed.success) {
      const message = parsed.error.issues
        .map((i) => `${i.path.join(".")}: ${i.message}`)
        .join(", ");
      return next(new AppError(`Validation failed: ${message}`, 400));
    }
    // Assign transformed values back so controllers receive coerced types
    Object.assign(req.query, parsed.data);
    return next();
  };
}

