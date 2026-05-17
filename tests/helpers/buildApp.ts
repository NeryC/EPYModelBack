import type { Express } from 'express';
import { createApp } from '../../src/app.js';

/**
 * Builds an Express app for integration tests with rate-limiting disabled
 * and Swagger skipped. Intentionally **not** memoized — every test gets a
 * fresh instance to avoid cross-test contamination.
 */
export function buildTestApp(): Express {
  return createApp({ disableRateLimit: true, skipSwagger: true });
}
